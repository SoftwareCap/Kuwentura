extends Node

#==============================================================================
# NETWORK MANAGER - LAN Listen Server with Code-Based Discovery
#==============================================================================
# FIXED: Proper UDP broadcast that doesn't conflict on port binding
# Host broadcasts on port 17778, Client listens on port 17779
#==============================================================================

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	HOSTING,
	CONNECTED,
	PLAYING,
	DISCONNECTING
}

enum Role { NONE, DETECTIVE, SIDEKICK }

const DEFAULT_PORT: int = 17777
const MAX_PLAYERS: int = 2
const BROADCAST_PORT: int = 17778  # Host broadcasts here, Client listens here
const DISCOVERY_BROADCAST_INTERVAL: float = 0.3  # More frequent for mobile
const DISCOVERY_TIMEOUT: float = 5.0

# Signals
signal connection_state_changed(new_state: int, old_state: int)
signal connection_established(peer_id: int)
signal connection_failed(error: String)
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal player_joined(peer_id: int, role: Role)
signal player_left(peer_id: int)
signal partner_connected(player_data: Dictionary)
signal partner_disconnected(player_data: Dictionary)
signal session_started(world_data: Dictionary)
signal game_started(checkpoint: String)
signal game_paused(reason: String)
signal game_resumed
signal host_discovered(host_info: Dictionary)
signal discovery_started
signal discovery_stopped
signal spawn_player_requested(peer_id: int, is_detective: bool)
signal despawn_player_requested(peer_id: int)
signal role_assignment_received(role: int)
signal room_code_generated(code: String)

@export var enable_prediction: bool = true
@export var enable_interpolation: bool = true

# State
var _state: ConnectionState = ConnectionState.DISCONNECTED
var _multiplayer_peer: ENetMultiplayerPeer = null

# Discovery - FIXED: Separate sockets for broadcast and listen
var _broadcast_socket: PacketPeerUDP = null  # Host uses this to broadcast
var _discovery_response_socket: PacketPeerUDP = null  # Host uses this to respond to discovery requests
var _listen_socket: PacketPeerUDP = null     # Client uses this to listen
var _discovery_broadcast_timer: float = 0.0
var _is_discovering: bool = false
var _discovery_targets: Dictionary = {}
var _target_code: String = ""

# Player
var _local_role: Role = Role.NONE
var _local_peer_id: int = 0
var _partner_peer_id: int = 0

# Session
var _invite_code: String = ""
var _session_seed: int = 0
var _is_host: bool = false
var _world_progress: Dictionary = {}
var _partner_states: Dictionary = {}

#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

func is_host() -> bool:
	return _is_host

func is_playing() -> bool:
	return _state == ConnectionState.PLAYING

func get_state() -> ConnectionState:
	return _state

func get_my_role() -> String:
	return "detective" if _local_role == Role.DETECTIVE else "sidekick" if _local_role == Role.SIDEKICK else "none"

func get_invite_code() -> String:
	return _invite_code

func get_room_code() -> String:
	return _invite_code

func has_active_connection() -> bool:
	return _state == ConnectionState.PLAYING or _state == ConnectionState.HOSTING or _state == ConnectionState.CONNECTED

func is_network_connected() -> bool:
	return has_active_connection()

func is_partner_connected() -> bool:
	return _partner_peer_id != 0 and (_state == ConnectionState.PLAYING or _state == ConnectionState.HOSTING)


func get_partner_state(peer_id: int) -> Dictionary:
	return _partner_states.get(str(peer_id), {})

func resume_game() -> bool:
	if _state != ConnectionState.PLAYING:
		push_warning("Cannot resume: game is not in PLAYING state")
		return false
	
	# Notify all peers that game has resumed
	if _is_host:
		_game_resumed_rpc.rpc()
	else:
		# Client requests resume, host will broadcast
		_request_resume_rpc.rpc_id(1)
	
	emit_signal("game_resumed")
	print("[Network] Game resumed")
	return true

#------------------------------------------------------------------------------
# Godot Lifecycle
#------------------------------------------------------------------------------

func _ready():
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float):
	if _is_discovering and _listen_socket:
		_poll_discovery()
	
	if _is_host:
		_discovery_broadcast_timer += delta
		if _discovery_broadcast_timer >= DISCOVERY_BROADCAST_INTERVAL:
			_discovery_broadcast_timer = 0.0
			_broadcast_host_presence()
		
		# Also listen for and respond to discovery requests
		_poll_discovery_requests()


func _exit_tree():
	disconnect_network()

#------------------------------------------------------------------------------
# Hosting
#------------------------------------------------------------------------------

func host_game() -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		return {"error": "Already connected", "success": false}
	
	_change_state(ConnectionState.CONNECTING)
	
	_multiplayer_peer = ENetMultiplayerPeer.new()
	var error = _multiplayer_peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	
	if error != OK:
		_change_state(ConnectionState.DISCONNECTED)
		return {"error": "Failed to create server: " + str(error), "success": false}
	
	multiplayer.multiplayer_peer = _multiplayer_peer
	
	_local_peer_id = 1
	_is_host = true
	_local_role = Role.DETECTIVE
	GameState.assign_role(GameState.Role.DETECTIVE)
	
	_invite_code = _generate_invite_code()
	_session_seed = randi()
	
	_world_progress = {
		"collected_clues": {},
		"zones_status": GameState.zones_status.duplicate(),
		"current_zone": "forest_hub",
		"session_seed": _session_seed
	}
	
	# Initialize GameState with session seed (derives zone seeds)
	GameState.set_session_seed(_session_seed)
	
	# Start broadcasting presence
	_start_broadcasting()
	
	_change_state(ConnectionState.HOSTING)
	
	emit_signal("connection_established", _local_peer_id)
	emit_signal("role_assignment_received", Role.DETECTIVE)
	emit_signal("room_code_generated", _invite_code)
	
	print("[Network] Hosting game. Code: ", _invite_code)
	
	return {
		"success": true,
		"invite_code": _invite_code,
		"port": DEFAULT_PORT
	}


#------------------------------------------------------------------------------
# FIXED: Broadcasting - don't bind, just send
#------------------------------------------------------------------------------

func _start_broadcasting():
	_broadcast_socket = PacketPeerUDP.new()
	_broadcast_socket.set_broadcast_enabled(true)
	# Don't bind! Just use it to send broadcasts
	print("[Network] Started broadcasting code: ", _invite_code)
	
	# Send initial burst of broadcasts for better discovery
	for i in range(3):
		_broadcast_host_presence()
		await get_tree().create_timer(0.1).timeout


func _broadcast_host_presence():
	if not _broadcast_socket or _invite_code.is_empty():
		return
	
	var host_ip = _get_host_ip()
	
	var broadcast_data = {
		"game": "kwentura",
		"version": "1.0.0",
		"code": _invite_code,
		"host_ip": host_ip,  # The actual IP to connect to
		"port": DEFAULT_PORT,
		"host_name": _get_device_name(),
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var packet = JSON.stringify(broadcast_data).to_utf8_buffer()
	
	# Send to multiple broadcast addresses for better coverage
	var broadcast_addresses = [
		"255.255.255.255",  # Global broadcast
		_get_subnet_broadcast(host_ip),  # Subnet broadcast
		"224.0.0.1"  # Multicast (all hosts)
	]
	
	for address in broadcast_addresses:
		if not address.is_empty():
			_broadcast_socket.set_dest_address(address, BROADCAST_PORT)
			var err = _broadcast_socket.put_packet(packet)
			if err != OK and err != 0:  # 0 is OK for some Godot versions
				print("[Network] Broadcast to ", address, " failed: ", err)


func _get_subnet_broadcast(ip: String) -> String:
	"""Calculate subnet broadcast address from IP."""
	var parts = ip.split(".")
	if parts.size() != 4:
		return "255.255.255.255"
	
	# Assume /24 subnet (255.255.255.0) for common WiFi networks
	return "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]


## Poll for and respond to discovery requests (Host only)
func _poll_discovery_requests():
	if not _is_host or _invite_code.is_empty():
		return
	
	# Initialize response socket if needed
	if not _discovery_response_socket:
		_discovery_response_socket = PacketPeerUDP.new()
		_discovery_response_socket.set_broadcast_enabled(true)
		var err = _discovery_response_socket.bind(BROADCAST_PORT)
		if err != OK:
			_discovery_response_socket = null
			return
	
	# Check for discovery requests
	while _discovery_response_socket.get_available_packet_count() > 0:
		var packet = _discovery_response_socket.get_packet()
		var from_ip = _discovery_response_socket.get_packet_ip()
		var from_port = _discovery_response_socket.get_packet_port()
		
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if data == null or not data is Dictionary:
			continue
		
		# Check if this is a discovery request for our code
		if data.get("request") == "discover" and data.get("code") == _invite_code:
			# Send direct response to the requester
			var response = {
				"game": "kwentura",
				"version": "1.0.0",
				"code": _invite_code,
				"host_ip": _get_host_ip(),
				"port": DEFAULT_PORT,
				"response": true
			}
			
			_discovery_response_socket.set_dest_address(from_ip, from_port)
			_discovery_response_socket.put_packet(JSON.stringify(response).to_utf8_buffer())
			print("[Network] Responded to discovery request from ", from_ip)


#------------------------------------------------------------------------------
# Joining with Code Discovery - FIXED: Listen on different port
#------------------------------------------------------------------------------

func start_discovery_for_code(target_code: String) -> bool:
	if _is_discovering:
		return true
	
	_target_code = target_code.to_upper()
	_discovery_targets.clear()
	
	_listen_socket = PacketPeerUDP.new()
	_listen_socket.set_broadcast_enabled(true)
	
	# Try to bind to BROADCAST_PORT first (for receiving broadcasts)
	# On mobile, if this fails, try binding to any available port
	var error = _listen_socket.bind(BROADCAST_PORT)
	if error != OK:
		print("[Network] Failed to bind to port ", BROADCAST_PORT, ", trying any port...")
		error = _listen_socket.bind(0)  # Bind to any available port
		if error != OK:
			push_warning("[Network] Failed to bind listen socket: " + str(error))
			_listen_socket = null
			return false
		print("[Network] Bound to random port for listening")
	
	_is_discovering = true
	emit_signal("discovery_started")
	
	print("[Network] Listening for code: ", _target_code)
	print("[Network] Local IP: ", _get_host_ip())
	print("[Network] Make sure host is broadcasting on same Wi-Fi network")
	
	return true


func get_discovered_host(code: String) -> Dictionary:
	return _discovery_targets.get(code.to_upper(), {})


## Join using code (with discovery)
func join_game_with_code(invite_code: String) -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		return {"error": "Already connected", "success": false}
	
	var target_code = invite_code.to_upper()
	
	# Start discovery
	print("[Network] =============================================")
	print("[Network] Searching for game with code: ", target_code)
	print("[Network] Local device IP: ", _get_host_ip())
	print("[Network] Make sure both devices are on the SAME Wi-Fi network")
	print("[Network] =============================================")
	
	var discovery_active = start_discovery_for_code(target_code)
	
	if not discovery_active:
		return {"error": "Failed to start discovery - port " + str(BROADCAST_PORT) + " may be in use", "success": false}
	
	# Wait for discovery with timeout - longer for mobile networks
	var attempts = 0
	var max_attempts = 30  # 15 seconds total for mobile
	var host_info = {}
	
	# Create a discovery request socket to actively ping for hosts
	var discovery_socket = PacketPeerUDP.new()
	discovery_socket.set_broadcast_enabled(true)
	discovery_socket.bind(0)  # Any available port
	
	while attempts < max_attempts:
		# Poll multiple times during each wait period
		for poll in range(5):  # 5 polls per second
			_poll_discovery()
			
			# Also check for direct responses
			while discovery_socket.get_available_packet_count() > 0:
				var packet = discovery_socket.get_packet()
				var data = JSON.parse_string(packet.get_string_from_utf8())
				if data is Dictionary and data.get("game") == "kwentura":
					var code = data.get("code", "")
					if code == target_code:
						host_info = {
							"host_ip": data.get("host_ip", ""),
							"port": data.get("port", DEFAULT_PORT),
							"code": code
						}
						print("[Network] Found host via direct response: ", host_info)
						break
			
			if not host_info.is_empty():
				break
				
			await get_tree().create_timer(0.2).timeout
		
		if not host_info.is_empty():
			break
		
		# Send discovery request to broadcast addresses
		var local_ip = _get_host_ip()
		var broadcast_addresses = ["255.255.255.255", _get_subnet_broadcast(local_ip)]
		var request_data = JSON.stringify({"request": "discover", "code": target_code}).to_utf8_buffer()
		
		for address in broadcast_addresses:
			if not address.is_empty():
				discovery_socket.set_dest_address(address, BROADCAST_PORT)
				discovery_socket.put_packet(request_data)
		
		host_info = get_discovered_host(target_code)
		if not host_info.is_empty():
			print("[Network] Found host via broadcast: ", host_info)
			break
		
		attempts += 1
		if attempts % 5 == 0:  # Print every 5 attempts (about 2.5 seconds)
			print("[Network] Discovery attempt ", attempts, "/", max_attempts)
	
	discovery_socket.close()
	_stop_discovery()
	
	if host_info.is_empty():
		# Try last resort: scan common local IP ranges
		print("[Network] Broadcast discovery failed, trying IP scan...")
		print("[Network] This may take a few seconds...")
		host_info = await _scan_local_network(target_code)
		
		if host_info.is_empty():
			print("[Network] =============================================")
			print("[Network] TROUBLESHOOTING TIPS:")
			print("[Network] 1. Check both devices are on SAME Wi-Fi")
			print("[Network] 2. Disable mobile data on both devices")
			print("[Network] 3. Check router 'AP Isolation' is OFF")
			print("[Network] 4. Try restarting the Wi-Fi router")
			print("[Network] 5. Use 'Direct IP' option if available")
			print("[Network] =============================================")
			return {
				"error": "Could not find game with code: " + target_code + "\n\nTroubleshooting:\n1. Same Wi-Fi network\n2. Disable mobile data\n3. Check router settings\n4. Restart router\n5. Try Direct IP connect", 
				"success": false
			}
	
	# Connect to discovered host
	var host_ip = host_info.get("host_ip", "")
	print("[Network] Connecting to host at: ", host_ip)
	
	return await _connect_to_host(host_ip, target_code)


## Last resort: Scan common local IP ranges
func _scan_local_network(target_code: String) -> Dictionary:
	"""Scan local network for host as fallback when broadcast fails."""
	var local_ip = _get_host_ip()
	var base_ip = local_ip.rsplit(".", false, 1)[0]  # Get first 3 octets
	
	print("[Network] Scanning range: ", base_ip, ".x")
	
	# Scan .1 to .254 (skip .255 broadcast and .0 network)
	for i in range(1, 255):
		var test_ip = base_ip + "." + str(i)
		if test_ip == local_ip:
			continue  # Skip self
		
		# Quick connection test
		var test_socket = PacketPeerUDP.new()
		var err = test_socket.bind(0)  # Bind to any available port
		if err != OK:
			continue
		
		test_socket.set_dest_address(test_ip, DEFAULT_PORT)
		
		# Try to send a ping
		var ping_data = JSON.stringify({"ping": target_code}).to_utf8_buffer()
		test_socket.put_packet(ping_data)
		
		# Wait a tiny bit for response
		await get_tree().create_timer(0.01).timeout
		
		if test_socket.get_available_packet_count() > 0:
			var packet = test_socket.get_packet()
			var data = JSON.parse_string(packet.get_string_from_utf8())
			if data is Dictionary and data.get("code") == target_code:
				test_socket.close()
				print("[Network] Found host via scan at: ", test_ip)
				return {
					"host_ip": test_ip,
					"port": DEFAULT_PORT,
					"code": target_code
				}
		
		test_socket.close()
		
		# Every 50 IPs, yield to prevent freezing
		if i % 50 == 0:
			await get_tree().process_frame
	
	return {}


## Try common IP patterns for mobile hotspots
func _try_common_ip_fallback(target_code: String) -> Dictionary:
	"""Try common IP patterns when broadcast discovery fails.
	This helps with mobile hotspots that may block broadcasts."""
	
	var local_ip = _get_host_ip()
	print("[Network] Trying common IP fallback for local IP: ", local_ip)
	
	# Get the subnet base
	var base_ip = local_ip.rsplit(".", false, 1)[0]  # e.g., "192.168.1"
	
	# Common IPs that mobile hotspots use (in order of likelihood)
	var common_ips = [
		base_ip + ".1",    # Most routers/hotspots use .1
		base_ip + ".100",  # Some Android hotspots
		base_ip + ".50",   # Some iOS hotspots
		base_ip + ".2",    # Alternative gateway
		base_ip + ".254",  # Some networks use .254
		base_ip + ".10",   # Common alternative
	]
	
	# Also try the most common mobile hotspot ranges
	if local_ip.begins_with("192.168."):
		# Add other common 192.168.x subnets
		for subnet in ["43", "44", "137", "142"]:
			common_ips.append("192.168." + subnet + ".1")
	
	for test_ip in common_ips:
		if test_ip == local_ip:
			continue  # Skip self
		
		print("[Network] Trying direct connect to: ", test_ip)
		
		# Try a quick ENet connection test
		var test_peer = ENetMultiplayerPeer.new()
		var err = test_peer.create_client(test_ip, DEFAULT_PORT)
		
		if err == OK:
			# Wait briefly for connection
			var attempts = 0
			while attempts < 10:  # 1 second max per IP
				await get_tree().create_timer(0.1).timeout
				
				var conn_status = test_peer.get_connection_status()
				if conn_status == MultiplayerPeer.CONNECTION_CONNECTED:
					# Success! Clean up and return this IP
					test_peer.close()
					print("[Network] Found host via fallback at: ", test_ip)
					return {"host_ip": test_ip, "port": DEFAULT_PORT, "code": target_code}
				elif conn_status == MultiplayerPeer.CONNECTION_DISCONNECTED:
					# Failed, move to next
					break
				
				attempts += 1
			
			test_peer.close()
	
	return {}


## Join directly with IP (for testing or when discovery fails)
func join_game_with_ip(host_ip: String, code: String = "") -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		return {"error": "Already connected", "success": false}
	
	print("[Network] Direct connect to IP: ", host_ip)
	return await _connect_to_host(host_ip, code)


func _poll_discovery():
	if not _listen_socket:
		return
	
	# Poll multiple times per frame to catch all packets
	var poll_count = 0
	var max_polls = 10  # Prevent infinite loop
	
	while _listen_socket.get_available_packet_count() > 0 and poll_count < max_polls:
		poll_count += 1
		var packet = _listen_socket.get_packet()
		var from_ip = _listen_socket.get_packet_ip()
		
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if data == null or not data is Dictionary:
			continue
		
		if data.get("game") != "kwentura":
			continue
		
		var code = data.get("code", "")
		# CRITICAL FIX: Always use the host_ip from the broadcast data, not from_ip
		# from_ip can be 255.255.255.255 or incorrect on some mobile devices
		var host_ip = data.get("host_ip", "")
		if host_ip.is_empty():
			host_ip = from_ip  # Fallback only if host_ip not in data
		
		print("[Network] Discovered broadcast - Code: ", code, " | Host IP from packet: ", host_ip, " | From IP: ", from_ip)
		
		# Store discovery info - use host_ip as the primary IP for connection
		_discovery_targets[code] = {
			"ip": host_ip,  # This is what we'll use to connect
			"host_ip": host_ip,
			"port": data.get("port", DEFAULT_PORT),
			"code": code,
			"host_name": data.get("host_name", "Unknown"),
			"last_seen": Time.get_unix_time_from_system()
		}
		
		emit_signal("host_discovered", _discovery_targets[code])


func _cleanup_old_discovery_targets() -> void:
	var current_time = Time.get_unix_time_from_system()
	var to_remove = []
	for code in _discovery_targets:
		var target = _discovery_targets[code]
		if current_time - target.get("last_seen", 0) > 30.0:
			to_remove.append(code)
	for code in to_remove:
		_discovery_targets.erase(code)


func stop_discovery():
	_stop_discovery()


func _stop_discovery():
	_is_discovering = false
	if _listen_socket:
		_listen_socket.close()
		_listen_socket = null
	emit_signal("discovery_stopped")


#------------------------------------------------------------------------------
# Connection
#------------------------------------------------------------------------------

func _connect_to_host(host_ip: String, code: String) -> Dictionary:
	_change_state(ConnectionState.CONNECTING)
	
	_multiplayer_peer = ENetMultiplayerPeer.new()
	var error = _multiplayer_peer.create_client(host_ip, DEFAULT_PORT)
	
	if error != OK:
		_change_state(ConnectionState.DISCONNECTED)
		return {"error": "Failed to create client: " + str(error), "success": false}
	
	multiplayer.multiplayer_peer = _multiplayer_peer
	_local_role = Role.SIDEKICK
	GameState.assign_role(GameState.Role.SIDEKICK)
	_invite_code = code
	
	print("[Network] Connecting to ", host_ip, ":", DEFAULT_PORT)
	
	# Wait for connection with timeout
	var attempts = 0
	var max_attempts = 30  # 3 seconds
	
	while attempts < max_attempts:
		await get_tree().create_timer(0.1).timeout
		
		if _state == ConnectionState.CONNECTED or _state == ConnectionState.PLAYING:
			return {"success": true}
		
		# Check if connection failed during wait
		if _state == ConnectionState.DISCONNECTED:
			return {"error": "Connection failed. Check:\n• Same Wi-Fi network\n• Firewall settings", "success": false}
		
		attempts += 1
	
	# Timeout
	_cleanup()
	_change_state(ConnectionState.DISCONNECTED)
	return {"error": "Connection timeout. Check:\n• Same Wi-Fi network\n• Firewall settings", "success": false}


func start_game() -> bool:
	if not _is_host:
		push_warning("Only host can start the game")
		return false
	
	if _state != ConnectionState.HOSTING or _partner_peer_id == 0:
		push_warning("No partner connected")
		return false
	
	_rpc_sync_world_state.rpc(_world_progress)
	
	_change_state(ConnectionState.PLAYING)
	
	_game_started_rpc.rpc("forest_hub")
	
	emit_signal("game_started", "forest_hub")
	
	return true


func disconnect_network():
	if _state == ConnectionState.DISCONNECTED:
		return
	
	_change_state(ConnectionState.DISCONNECTING)
	
	_stop_discovery()
	
	if _broadcast_socket:
		_broadcast_socket.close()
		_broadcast_socket = null
	
	if _discovery_response_socket:
		_discovery_response_socket.close()
		_discovery_response_socket = null
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	_cleanup()
	_change_state(ConnectionState.DISCONNECTED)
	
	print("[Network] Disconnected")


func disconnect_from_session():
	disconnect_network()

#------------------------------------------------------------------------------
# Multiplayer Handlers
#------------------------------------------------------------------------------

func _on_multiplayer_peer_connected(peer_id: int):
	print("[Network] Peer connected: ", peer_id)
	emit_signal("player_connected", peer_id)
	
	if _is_host:
		_partner_peer_id = peer_id
		_assign_role_rpc.rpc_id(peer_id, Role.SIDEKICK, _invite_code, _session_seed)
		
		emit_signal("partner_connected", {
			"player_id": str(peer_id),
			"display_name": "Sidekick",
			"role": "sidekick"
		})
		emit_signal("player_joined", peer_id, Role.SIDEKICK)
		
		# If host is already playing, immediately tell the new sidekick to start the game
		if _state == ConnectionState.PLAYING:
			print("[Network] Host is already playing, sending game_started to new sidekick")
			_game_started_rpc.rpc_id(peer_id, "forest_hub")
	else:
		emit_signal("player_joined", peer_id, Role.DETECTIVE)


func _on_multiplayer_peer_disconnected(peer_id: int):
	print("[Network] Peer disconnected: ", peer_id)
	emit_signal("player_disconnected", peer_id)
	
	if peer_id == _partner_peer_id:
		_partner_peer_id = 0
		emit_signal("partner_disconnected", {
			"player_id": str(peer_id),
			"reason": "disconnected"
		})
		emit_signal("game_paused", "partner_disconnected")
		emit_signal("player_left", peer_id)
	
	if _is_host and _state == ConnectionState.PLAYING:
		_change_state(ConnectionState.HOSTING)


func _on_connected_to_server():
	print("[Network] Connected to server")
	_local_peer_id = multiplayer.get_unique_id()
	_change_state(ConnectionState.CONNECTED)


func _on_connection_failed():
	push_error("[Network] Connection failed")
	_change_state(ConnectionState.DISCONNECTED)
	emit_signal("connection_failed", "Failed to connect to host")
	_cleanup()


func _on_server_disconnected():
	print("[Network] Server disconnected")
	emit_signal("partner_disconnected", {"reason": "host_disconnected"})
	emit_signal("game_paused", "host_disconnected")
	_change_state(ConnectionState.DISCONNECTED)
	_cleanup()

#------------------------------------------------------------------------------
# RPC Functions
#------------------------------------------------------------------------------

@rpc("authority", "reliable")
func _assign_role_rpc(role: Role, invite_code: String, session_seed: int):
	_local_role = role
	_session_seed = session_seed
	_invite_code = invite_code
	
	GameState.assign_role(GameState.Role.SIDEKICK)
	
	# Initialize GameState with synced session seed (derives zone seeds)
	GameState.set_session_seed(_session_seed)
	
	print("[Network] Assigned role: SIDEKICK, session seed: ", _session_seed)
	
	emit_signal("connection_established", _local_peer_id)
	emit_signal("role_assignment_received", Role.SIDEKICK)


@rpc("authority", "reliable")
func _game_started_rpc(checkpoint: String):
	_change_state(ConnectionState.PLAYING)
	emit_signal("game_started", checkpoint)
	emit_signal("session_started", {
		"checkpoint": checkpoint,
		"world_progress": _world_progress,
		"your_role": "sidekick",
		"partner": {
			"player_id": str(_partner_peer_id),
			"role": "detective"
		}
	})


@rpc("any_peer", "reliable")
func _request_resume_rpc():
	if multiplayer.is_server():
		_game_resumed_rpc.rpc()


@rpc("authority", "reliable")
func _game_resumed_rpc():
	emit_signal("game_resumed")


@rpc("any_peer", "reliable")
func _rpc_sync_world_state(world_state: Dictionary):
	_world_progress = world_state
	# Sync session seed if provided (for nightfall resets)
	var synced_seed = world_state.get("session_seed", 0)
	if synced_seed != 0 and synced_seed != _session_seed:
		_session_seed = synced_seed
		GameState.set_session_seed(_session_seed)
		print("[Network] Synced new session seed: ", _session_seed)


@rpc("any_peer", "reliable")
func submit_puzzle_solution(puzzle_id: String, solution: Variant, _attempt_time_ms: int):
	if multiplayer.is_server():
		var result = PuzzleManager.validate_puzzle(puzzle_id, solution)
		_puzzle_result_rpc.rpc_id(multiplayer.get_remote_sender_id(), puzzle_id, result)


@rpc("authority", "reliable")
func _puzzle_result_rpc(_puzzle_id: String, _result: Dictionary):
	pass


@rpc("any_peer", "unreliable_ordered")
func sync_player_state(position: Vector2, velocity: Vector2, facing: String, animation_state: String):
	var sender_id = multiplayer.get_remote_sender_id()
	_partner_states[str(sender_id)] = {
		"position": position,
		"velocity": velocity,
		"facing": facing,
		"animation": animation_state,
		"timestamp": Time.get_unix_time_from_system()
	}


@rpc("authority", "reliable")
func trigger_clue_collection(zone_id: String, _clue_data: Dictionary):
	GameState.collect_clue(zone_id)


#------------------------------------------------------------------------------
# Player Spawn/Despawn RPCs (moved here from ForestHub to ensure node exists)
#------------------------------------------------------------------------------

@rpc("authority", "reliable")
func _rpc_request_spawn_player(peer_id: int, is_detective_role: bool):
	# Emit signal that ForestHub (or any scene) can connect to
	emit_signal("spawn_player_requested", peer_id, is_detective_role)


@rpc("authority", "reliable")
func _rpc_request_despawn_player(peer_id: int):
	emit_signal("despawn_player_requested", peer_id)


## Call this to request a player spawn on a specific peer
func request_spawn_player(target_peer: int, peer_id: int, is_detective: bool):
	_rpc_request_spawn_player.rpc_id(target_peer, peer_id, is_detective)


## Call this to request player despawn on all peers
func request_despawn_player(peer_id: int):
	_rpc_request_despawn_player.rpc(peer_id)

#------------------------------------------------------------------------------
# COSTUME SYNC RPCs (moved here to work across different scenes)
#------------------------------------------------------------------------------

## Sync costume preview to all peers (called from lobby scenes)
func sync_costume_preview(role: String, costume_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_sync_costume_preview.rpc(role, costume_id)


## Sync costume confirmation to all peers (called from lobby scenes)
func sync_costume_confirmed(role: String, costume_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_sync_costume_confirmed.rpc(role, costume_id)


## Send full costume state to a specific peer (called when new player joins)
func send_costume_state_to_client(target_peer: int) -> void:
	_rpc_send_full_costume_state.rpc_id(target_peer,
		GameState.selected_costumes["detective"],
		GameState.selected_costumes["sidekick"],
		GameState._costume_confirmed_status["detective"],
		GameState._costume_confirmed_status["sidekick"]
	)


@rpc("any_peer", "reliable")
func _rpc_sync_costume_preview(role: String, costume_id: String) -> void:
	if multiplayer.get_remote_sender_id() == 0:
		return  # Invalid sender
	GameState.selected_costumes[role] = costume_id
	GameState.emit_signal("costume_changed", role, costume_id)


@rpc("any_peer", "reliable")
func _rpc_sync_costume_confirmed(role: String, costume_id: String) -> void:
	if multiplayer.get_remote_sender_id() == 0:
		return  # Invalid sender
	GameState.selected_costumes[role] = costume_id
	GameState._costume_confirmed_status[role] = true
	GameState.emit_signal("costume_confirmed", role, true)


@rpc("authority", "reliable")
func _rpc_send_full_costume_state(detective_costume: String, sidekick_costume: String,
									  detective_confirmed: bool, sidekick_confirmed: bool) -> void:
	GameState.selected_costumes["detective"] = detective_costume
	GameState.selected_costumes["sidekick"] = sidekick_costume
	GameState._costume_confirmed_status["detective"] = detective_confirmed
	GameState._costume_confirmed_status["sidekick"] = sidekick_confirmed
	GameState.emit_signal("costume_changed", "detective", detective_costume)
	GameState.emit_signal("costume_changed", "sidekick", sidekick_costume)


## Notify sidekick that host is leaving (called before disconnect)
func notify_host_leaving() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_notify_host_leaving.rpc()


@rpc("authority", "reliable")
func _rpc_notify_host_leaving() -> void:
	# Sidekick receives this - could emit a signal if needed
	emit_signal("game_paused", "host_leaving")

#------------------------------------------------------------------------------
# Helpers
#------------------------------------------------------------------------------

func _change_state(new_state: ConnectionState):
	if _state == new_state:
		return
	var old_state := _state
	_state = new_state
	emit_signal("connection_state_changed", new_state, old_state)
	print("[Network] State: ", _state_name(old_state), " -> ", _state_name(new_state))


func _state_name(s: int) -> String:
	match s:
		ConnectionState.DISCONNECTED: return "DISCONNECTED"
		ConnectionState.CONNECTING: return "CONNECTING"
		ConnectionState.HOSTING: return "HOSTING"
		ConnectionState.CONNECTED: return "CONNECTED"
		ConnectionState.PLAYING: return "PLAYING"
		ConnectionState.DISCONNECTING: return "DISCONNECTING"
		_: return "UNKNOWN"


func _generate_invite_code() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code = ""
	var random_seed = hash(str(randi()) + str(Time.get_unix_time_from_system()))
	for i in range(6):
		random_seed = (random_seed * 9301 + 49297) % 233280
		code += chars[random_seed % chars.length()]
	return code


func _get_host_ip() -> String:
	var ips = IP.get_local_addresses()
	var best_ip = ""
	print("[Network] Available IPs: ", ips)
	
	for ip in ips:
		if ip.begins_with("127."):
			continue
		if ip.begins_with("0."):
			continue
		# Prefer 192.168.x.x or 10.x.x.x (private networks)
		if "." in ip:
			if ip.begins_with("192.168.") or ip.begins_with("10."):
				print("[Network] Found private IP: ", ip)
				return ip
			if best_ip.is_empty():
				best_ip = ip
	
	if not best_ip.is_empty():
		print("[Network] Using IP: ", best_ip)
		return best_ip
		
	print("[Network] Warning: No suitable IP found, using localhost")
	return "localhost"


## Get network diagnostics for debugging
func get_network_diagnostics() -> Dictionary:
	var result = {
		"local_ips": IP.get_local_addresses(),
		"selected_ip": _get_host_ip(),
		"is_host": _is_host,
		"state": _state_name(_state),
		"invite_code": _invite_code,
		"port": DEFAULT_PORT,
		"broadcast_port": BROADCAST_PORT
	}
	
	if _is_host and _multiplayer_peer:
		result["hosting_on"] = _get_host_ip() + ":" + str(DEFAULT_PORT)
	
	return result


## Print network diagnostics to console
func print_network_diagnostics() -> void:
	var diag = get_network_diagnostics()
	print("\n=== NETWORK DIAGNOSTICS ===")
	print("Local IPs: ", diag.local_ips)
	print("Selected IP: ", diag.selected_ip)
	print("State: ", diag.state)
	print("Is Host: ", diag.is_host)
	print("Port: ", diag.port)
	print("Broadcast Port: ", diag.broadcast_port)
	print("==========================\n")


func _get_device_name() -> String:
	var player_name = OS.get_name() + " Player"
	var env = OS.get_environment("COMPUTERNAME")
	if not env.is_empty():
		player_name = env
	return player_name


func _cleanup():
	_is_host = false
	_local_peer_id = 0
	_partner_peer_id = 0
	_local_role = Role.NONE
	_invite_code = ""
	_world_progress.clear()
	_partner_states.clear()
	_discovery_targets.clear()
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
