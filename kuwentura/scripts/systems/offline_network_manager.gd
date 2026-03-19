extends Node

## Offline Network Manager - LAN Multiplayer without requiring same Wi-Fi
## 
## Supports multiple connection modes:
## 1. Direct IP - Enter host's IP address directly (works on any network)
## 2. Hotspot Mode - Host creates mobile hotspot, client connects to it
## 3. QR Code - Scan QR code to auto-connect
##
## This replaces the old LAN-only discovery system with a more flexible
## approach that works in truly offline scenarios.

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	HOSTING,
	CONNECTED,
	PLAYING,
	DISCONNECTING
}

enum Role { NONE, DETECTIVE, SIDEKICK }

# Network Configuration
const DEFAULT_PORT: int = 17777
const MAX_PLAYERS: int = 2
const CONNECTION_TIMEOUT_SEC: float = 10.0
const RECONNECT_ATTEMPTS: int = 3

# Signals
signal connection_state_changed(new_state: int, old_state: int)
signal connection_established(peer_id: int, role: Role)
signal connection_failed(error: String)
signal player_connected(peer_id: int, role: Role)
signal player_disconnected(peer_id: int)
signal player_joined(peer_id: int, role: Role)
signal player_left(peer_id: int)
signal partner_connected(player_data: Dictionary)
signal partner_disconnected(reason: String)
signal game_started(checkpoint: String)
signal game_paused(reason: String)
signal game_resumed
signal host_info_updated(info: Dictionary)
signal role_assignment_received(role: Role)
signal room_code_generated(code: String)
signal rejoin_game_requested(world_state: Dictionary)
signal spawn_player_requested(peer_id: int, is_detective: bool)
signal despawn_player_requested(peer_id: int)

# State
var _state: ConnectionState = ConnectionState.DISCONNECTED
var _multiplayer_peer: ENetMultiplayerPeer = null
var _local_role: Role = Role.NONE
var _local_peer_id: int = 0
var _partner_peer_id: int = 0
var _is_host: bool = false
var _invite_code: String = ""
var _session_seed: int = 0

# Connection info (for display/sharing)
var _host_ip: String = ""
var _world_progress: Dictionary = {}
var _partner_states: Dictionary = {}

# Track if game has been started (for rejoin detection)
var _has_game_started: bool = false

# Track if sidekick is rejoining an active game session
var _is_rejoining: bool = false

# Store current player positions for rejoin sync
var _last_known_positions: Dictionary = {}  # peer_id -> {"position": Vector2, "timestamp": int}

# Discovery (UDP Broadcast for room code joining)
var _broadcast_socket: PacketPeerUDP = null
var _listen_socket: PacketPeerUDP = null
var _discovery_timer: float = 0.0
const DISCOVERY_BROADCAST_INTERVAL: float = 0.5
const DISCOVERY_PORT: int = 17778
const DISCOVERY_TIMEOUT: float = 10.0
var _is_listening: bool = false
var _target_code: String = ""

# Settings
var enable_prediction: bool = true
var enable_interpolation: bool = true


func _ready():
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Connect to GameState signals to keep world_progress in sync
	if GameState:
		GameState.clue_collected.connect(_on_clue_collected)
		GameState.zone_completed.connect(_on_zone_completed)
	
	print("[OfflineNetwork] Initialized")


func _exit_tree():
	disconnect_network()


func _on_clue_collected(_zone_id: String, _clue_data: Dictionary) -> void:
	"""Update world progress when a clue is collected."""
	if _is_host:
		sync_world_progress_from_gamestate()


func _on_zone_completed(_zone_id: String) -> void:
	"""Update world progress when a zone is completed."""
	if _is_host:
		sync_world_progress_from_gamestate()


## Report position to host (called by local player)
func report_position(peer_id: int, position: Vector2) -> void:
	"""Clients report their position to host, host stores it for rejoin sync."""
	if not _is_host:
		# Client sends position to host via RPC
		_report_position_to_host_rpc.rpc_id(1, peer_id, position)
	else:
		# Host stores its own position directly
		_store_position(peer_id, position)


func _store_position(peer_id: int, position: Vector2) -> void:
	"""Store position for a player (host only)."""
	if not _is_host:
		return
	_last_known_positions[str(peer_id)] = {
		"position": {"x": position.x, "y": position.y},
		"timestamp": Time.get_unix_time_from_system()
	}


@rpc("any_peer", "unreliable")
func _report_position_to_host_rpc(peer_id: int, position: Vector2) -> void:
	"""RPC for clients to report their position to host."""
	if not multiplayer.is_server():
		return
	_store_position(peer_id, position)


func _process(delta: float):
	# Handle discovery broadcasting (host)
	# Broadcast in both HOSTING and PLAYING states so reconnecting sidekicks can find us
	if _is_host and (_state == ConnectionState.HOSTING or _state == ConnectionState.PLAYING):
		_discovery_timer += delta
		if _discovery_timer >= DISCOVERY_BROADCAST_INTERVAL:
			_discovery_timer = 0.0
			_broadcast_presence()
	
	# Handle discovery listening (client)
	if _is_listening and _listen_socket:
		_poll_discovery()


# ============================================================================
# DISCOVERY SYSTEM (UDP Broadcast)
# ============================================================================

func _start_discovery_broadcast():
	"""Host starts broadcasting presence via UDP"""
	_broadcast_socket = PacketPeerUDP.new()
	_broadcast_socket.set_broadcast_enabled(true)
	# Don't bind, just use for sending
	print("[OfflineNetwork] Started discovery broadcast on port ", DISCOVERY_PORT)


func _broadcast_presence():
	"""Send broadcast packet with room info to all network interfaces"""
	if not _broadcast_socket or _invite_code.is_empty():
		print("[OfflineNetwork] Cannot broadcast: socket=", _broadcast_socket != null, ", code=", _invite_code)
		return
	
	var broadcast_data = {
		"game": "kwentura",
		"version": "1.0.0",
		"code": _invite_code,
		"host_ip": _host_ip,
		"port": DEFAULT_PORT,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var packet = JSON.stringify(broadcast_data).to_utf8_buffer()
	
	print("[OfflineNetwork] Broadcasting presence... Host IP: ", _host_ip, ", Code: ", _invite_code)
	
	# Send to global broadcast address
	_broadcast_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	var err = _broadcast_socket.put_packet(packet)
	
	if err == OK:
		print("[OfflineNetwork] ✓ Broadcast sent to 255.255.255.255")
	else:
		print("[OfflineNetwork] ✗ Broadcast to 255.255.255.255 failed: ", err)
	
	# Also send to common subnet broadcast addresses for better reliability
	var subnets = ["192.168.1.255", "192.168.0.255", "192.168.43.255", "172.20.10.255"]
	for subnet in subnets:
		_broadcast_socket.set_dest_address(subnet, DISCOVERY_PORT)
		var subnet_err = _broadcast_socket.put_packet(packet)
		if subnet_err != OK:
			print("[OfflineNetwork] ✗ Broadcast to ", subnet, " failed: ", subnet_err)


func _start_discovery_listen(target_code: String) -> Dictionary:
	"""Client starts listening for host broadcasts"""
	_target_code = target_code.to_upper()
	
	print("[OfflineNetwork] Starting discovery listen for code: ", target_code)
	print("[OfflineNetwork] Discovery port: ", DISCOVERY_PORT)
	
	_listen_socket = PacketPeerUDP.new()
	_listen_socket.set_broadcast_enabled(true)
	
	# Must bind to DISCOVERY_PORT to receive broadcasts from host
	# Try binding to any available address on the discovery port
	var error = _listen_socket.bind(DISCOVERY_PORT, "0.0.0.0")
	if error != OK:
		push_warning("[OfflineNetwork] Failed to bind discovery socket to 0.0.0.0: " + str(error))
		# Try with reuse enabled (if supported)
		_listen_socket = PacketPeerUDP.new()
		_listen_socket.set_broadcast_enabled(true)
		error = _listen_socket.bind(DISCOVERY_PORT)
		if error != OK:
			_listen_socket = null
			print("[OfflineNetwork] CRITICAL: Failed to bind discovery socket: ", error)
			return {"success": false, "error": "Cannot bind to port " + str(DISCOVERY_PORT) + " (code: " + str(error) + ")"}
	
	_is_listening = true
	print("[OfflineNetwork] ✓ Listening for discovery on port ", DISCOVERY_PORT, " for code: ", _target_code)
	return {"success": true}


func _poll_discovery():
	"""Poll for incoming discovery packets"""
	if not _listen_socket:
		return
	
	while _listen_socket.get_available_packet_count() > 0:
		var packet = _listen_socket.get_packet()
		var from_ip = _listen_socket.get_packet_ip()
		
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if data == null or not data is Dictionary:
			print("[OfflineNetwork] Received invalid packet from ", from_ip)
			continue
		
		if data.get("game") != "kwentura":
			print("[OfflineNetwork] Received packet from wrong game: ", data.get("game"))
			continue
		
		var code = data.get("code", "")
		# Use the packet's source IP as the host IP (more reliable than broadcast data)
		var host_ip = from_ip
		if host_ip.is_empty():
			host_ip = data.get("host_ip", "")
		
		print("[OfflineNetwork] Received broadcast from ", host_ip, " with code: ", code, " (looking for: ", _target_code, ")")
		
		if code == _target_code:
			print("[OfflineNetwork] ✓ MATCH! Discovered host at: ", host_ip)
			# Store discovery result
			_last_discovered_host = {
				"ip": host_ip,
				"port": data.get("port", DEFAULT_PORT),
				"code": code
			}


var _last_discovered_host: Dictionary = {}

func _wait_for_discovery(target_code: String) -> Dictionary:
	"""Wait for discovery with timeout"""
	var elapsed: float = 0.0
	_last_discovered_host = {}
	
	print("[OfflineNetwork] Waiting for discovery... timeout: ", DISCOVERY_TIMEOUT, "s")
	
	while elapsed < DISCOVERY_TIMEOUT:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		
		# Log progress every 2 seconds
		if int(elapsed * 10) % 20 == 0:
			print("[OfflineNetwork] Still searching... (", int(elapsed), "s elapsed)")
		
		if not _last_discovered_host.is_empty() and _last_discovered_host.code == target_code:
			print("[OfflineNetwork] Discovery successful! Found host at ", _last_discovered_host.ip)
			return _last_discovered_host
	
	print("[OfflineNetwork] Discovery timeout - no host found with code ", target_code)
	return {}


func _stop_discovery_listen():
	"""Stop listening for discovery"""
	_is_listening = false
	if _listen_socket:
		_listen_socket.close()
		_listen_socket = null


# ============================================================================
# PUBLIC API - State Queries
# ============================================================================

func is_host() -> bool:
	return _is_host


func is_playing() -> bool:
	return _state == ConnectionState.PLAYING


func is_rejoining() -> bool:
	"""Check if sidekick is rejoining an active game session."""
	return _is_rejoining


func get_state() -> ConnectionState:
	return _state


func get_state_name() -> String:
	match _state:
		ConnectionState.DISCONNECTED: return "DISCONNECTED"
		ConnectionState.CONNECTING: return "CONNECTING"
		ConnectionState.HOSTING: return "HOSTING"
		ConnectionState.CONNECTED: return "CONNECTED"
		ConnectionState.PLAYING: return "PLAYING"
		ConnectionState.DISCONNECTING: return "DISCONNECTING"
		_: return "UNKNOWN"


func get_my_role() -> String:
	match _local_role:
		Role.DETECTIVE: return "detective"
		Role.SIDEKICK: return "sidekick"
		_: return "none"


func get_my_role_enum() -> Role:
	return _local_role


func get_invite_code() -> String:
	return _invite_code


func get_room_code() -> String:
	return _invite_code


func get_host_ip() -> String:
	return _host_ip


func has_active_connection() -> bool:
	return _state in [ConnectionState.PLAYING, ConnectionState.HOSTING, ConnectionState.CONNECTED]


func is_network_connected() -> bool:
	return has_active_connection()


func is_partner_connected() -> bool:
	return _partner_peer_id != 0 and _state in [ConnectionState.PLAYING, ConnectionState.HOSTING]


func get_partner_state(peer_id: int) -> Dictionary:
	return _partner_states.get(str(peer_id), {})


func clear_partner_state(peer_id: int) -> void:
	"""Clear stored partner state to prevent interpolation from old position."""
	_partner_states.erase(str(peer_id))


# ============================================================================
# HOSTING - Create a game (Detective)
# ============================================================================

## Host a game
## Works in any network configuration - host just needs to share their IP
func host_game() -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		# Force cleanup if in unexpected state
		if multiplayer.multiplayer_peer:
			multiplayer.multiplayer_peer.close()
			multiplayer.multiplayer_peer = null
		_cleanup()
		_state = ConnectionState.DISCONNECTED
	
	_change_state(ConnectionState.CONNECTING)
	
	# Create ENet server
	_multiplayer_peer = ENetMultiplayerPeer.new()
	var error = _multiplayer_peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	
	if error != OK:
		_change_state(ConnectionState.DISCONNECTED)
		return {"success": false, "error": "Failed to create server: " + str(error)}
	
	multiplayer.multiplayer_peer = _multiplayer_peer
	
	_local_peer_id = 1
	_is_host = true
	_local_role = Role.DETECTIVE
	GameState.assign_role(GameState.Role.DETECTIVE)
	
	emit_signal("role_assignment_received", Role.DETECTIVE)
	
	_invite_code = _generate_invite_code()
	_session_seed = randi()
	_host_ip = _get_best_host_ip()
	
	# Initialize world progress
	_world_progress = {
		"collected_clues": {},
		"zones_status": GameState.zones_status.duplicate(),
		"current_zone": "forest_hub",
		"session_seed": _session_seed
	}
	
	# Reset game started flag for new session
	_has_game_started = false
	
	GameState.set_session_seed(_session_seed)
	
	_change_state(ConnectionState.HOSTING)
	
	print("[OfflineNetwork] ============================================")
	print("[OfflineNetwork] HOST STARTED SUCCESSFULLY")
	print("[OfflineNetwork] IP Address: ", _host_ip)
	print("[OfflineNetwork] Room Code: ", _invite_code)
	print("[OfflineNetwork] Port: ", DEFAULT_PORT)
	print("[OfflineNetwork] ============================================")
	
	var host_info = {
		"success": true,
		"invite_code": _invite_code,
		"host_ip": _host_ip,
		"port": DEFAULT_PORT,
		"qr_data": _generate_qr_data(),
		"connection_instructions": _get_host_instructions()
	}
	
	emit_signal("connection_established", _local_peer_id, Role.DETECTIVE)
	emit_signal("host_info_updated", host_info)
	emit_signal("room_code_generated", _invite_code)
	
	# Start broadcasting presence for discovery
	_start_discovery_broadcast()
	
	print("[OfflineNetwork] Hosting on ", _host_ip, ":", DEFAULT_PORT)
	print("[OfflineNetwork] Invite code: ", _invite_code)
	
	return host_info


## Get current host connection info for sharing
func get_host_connection_info() -> Dictionary:
	return {
		"ip": _host_ip,
		"port": DEFAULT_PORT,
		"code": _invite_code,
		"qr_string": _generate_qr_data()
	}


# ============================================================================
# JOINING - Connect to a host (Sidekick)
# ============================================================================

## Join a game using direct IP address
## This is the primary connection method - works across any network
func join_with_ip(host_ip: String, code: String = "") -> Dictionary:
	# Force cleanup if in any state other than DISCONNECTED
	if _state != ConnectionState.DISCONNECTED:
		force_reset_for_reconnection()
	
	if host_ip.is_empty():
		return {"success": false, "error": "IP address is required"}
	
	# Validate IP format (basic check)
	if not _is_valid_ip(host_ip) and host_ip != "localhost":
		return {
			"success": false, 
			"error": "Invalid IP address format. Expected: xxx.xxx.xxx.xxx (e.g., 192.168.1.5)"
		}
	
	print("[OfflineNetwork] Connecting to ", host_ip, ":", DEFAULT_PORT)
	_change_state(ConnectionState.CONNECTING)
	
	_multiplayer_peer = ENetMultiplayerPeer.new()
	var error = _multiplayer_peer.create_client(host_ip, DEFAULT_PORT)
	
	if error != OK:
		_change_state(ConnectionState.DISCONNECTED)
		return {"success": false, "error": "Failed to create client: " + str(error)}
	
	multiplayer.multiplayer_peer = _multiplayer_peer
	_local_role = Role.SIDEKICK
	GameState.assign_role(GameState.Role.SIDEKICK)
	emit_signal("role_assignment_received", Role.SIDEKICK)
	_invite_code = code
	
	# Wait for connection with timeout
	var result = await _wait_for_connection()
	
	if not result.success:
		_cleanup()
		_change_state(ConnectionState.DISCONNECTED)
		
		# Provide helpful error message based on context
		var error_msg = result.error
		if error_msg.contains("timeout"):
			error_msg += _get_connection_troubleshooting_tips()
		
		return {"success": false, "error": error_msg}
	
	return {"success": true}


## Join using QR code data
func join_with_qr(qr_string: String) -> Dictionary:
	var data = parse_qr_data(qr_string)
	
	if data.has("error"):
		return {"success": false, "error": data.error}
	
	return await join_with_ip(data.ip, data.code)


## Join a game using room code with UDP discovery
## This works on hotspot networks and same Wi-Fi
func join_game_with_code(invite_code: String) -> Dictionary:
	print("[OfflineNetwork] Starting discovery for code: ", invite_code)
	
	# Force cleanup if in any state other than DISCONNECTED
	if _state != ConnectionState.DISCONNECTED:
		force_reset_for_reconnection()
	
	var target_code = invite_code.to_upper()
	var discovery = _start_discovery_listen(target_code)
	
	if not discovery.success:
		return {"success": false, "error": "Failed to start discovery: " + discovery.error}
	
	# Wait for discovery with timeout
	print("[OfflineNetwork] Listening for host broadcasts...")
	var host_info = await _wait_for_discovery(target_code)
	
	_stop_discovery_listen()
	
	if host_info.is_empty():
		return {
			"success": false, 
			"error": "Could not find game with code: " + target_code + "\n\nConnection Options:\n1. Same Wi-Fi: Connect both devices to same network\n2. Hotspot Mode: Host enables mobile hotspot, Sidekick connects to it\n\nThen:\n• Host must be in lobby\n• Room code must match"
		}
	
	print("[OfflineNetwork] Found host at: ", host_info.ip)
	
	# Connect to discovered host
	return await join_with_ip(host_info.ip, target_code)


## DEPRECATED: Alias for join_with_ip for backward compatibility
func join_game_with_ip(host_ip: String, code: String = "") -> Dictionary:
	return await join_with_ip(host_ip, code)


## Parse QR code string
## Format: KWENTURA|IP|PORT|CODE
func parse_qr_data(qr_string: String) -> Dictionary:
	var parts = qr_string.split("|")
	
	if parts.size() < 4:
		return {"error": "Invalid QR code format (too few parts)"}
	
	if parts[0] != "KWENTURA":
		return {"error": "Invalid QR code protocol (expected KWENTURA)"}
	
	var port = parts[2].to_int()
	if port == 0:
		port = DEFAULT_PORT
	
	return {
		"ip": parts[1],
		"port": port,
		"code": parts[3]
	}


## Test connection to a specific IP (for connection testing)
func test_connection(host_ip: String) -> Dictionary:
	# Quick ping-like test
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(host_ip, DEFAULT_PORT)
	
	if error != OK:
		return {"reachable": false, "error": "Cannot create connection"}
	
	# Wait a short time for connection attempt
	await get_tree().create_timer(2.0).timeout
	
	var connected = peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	peer.close()
	
	return {
		"reachable": connected,
		"error": "" if connected else "Host not reachable"
	}


# ============================================================================
# GAME SESSION MANAGEMENT
# ============================================================================

## Start the game (host only)
func start_game() -> bool:
	if not _is_host:
		push_warning("[OfflineNetwork] Only host can start the game")
		return false
	
	if _state != ConnectionState.HOSTING or _partner_peer_id == 0:
		push_warning("[OfflineNetwork] No partner connected")
		return false
	
	# Update world progress before starting
	sync_world_progress_from_gamestate()
	
	# Sync world state to client
	_rpc_sync_world_state.rpc(_world_progress)
	
	_change_state(ConnectionState.PLAYING)
	_has_game_started = true
	
	# Notify all clients
	_game_started_rpc.rpc("forest_hub")
	
	emit_signal("game_started", "forest_hub")
	
	print("[OfflineNetwork] Game started")
	return true


## Resume game after pause
func resume_game() -> bool:
	if _state != ConnectionState.PLAYING:
		push_warning("[OfflineNetwork] Cannot resume: not in PLAYING state")
		return false
	
	if _is_host:
		_game_resumed_rpc.rpc()
	else:
		_request_resume_rpc.rpc_id(1)
	
	emit_signal("game_resumed")
	return true


## Sync world progress from GameState (call this when game state changes)
func sync_world_progress_from_gamestate() -> void:
	"""Update _world_progress with current GameState data."""
	_world_progress = {
		"collected_clues": GameState.collected_clues.duplicate(true),
		"zones_status": GameState.zones_status.duplicate(true),
		"current_zone": GameState.current_zone,
		"session_seed": _session_seed,
		"climax_triggered": GameState.climax_triggered,
		"game_completed": GameState.game_completed
	}


## Disconnect from current session
func disconnect_network():
	if _state == ConnectionState.DISCONNECTED:
		return
	
	_change_state(ConnectionState.DISCONNECTING)
	
	# Notify partner if we're host
	if _is_host and _partner_peer_id != 0:
		_notify_host_leaving.rpc()
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	_cleanup()
	_change_state(ConnectionState.DISCONNECTED)
	
	print("[OfflineNetwork] Disconnected")


## Force reset network state for reconnection
func force_reset_for_reconnection():
	"""Force cleanup all network state to ensure clean reconnection."""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_cleanup()
	_state = ConnectionState.DISCONNECTED
	print("[OfflineNetwork] Force reset for reconnection")


func disconnect_from_session():
	disconnect_network()


# ============================================================================
# RPC FUNCTIONS
# ============================================================================

@rpc("authority", "reliable")
func _assign_role_rpc(role: Role, invite_code: String, session_seed: int):
	_local_role = role
	_session_seed = session_seed
	_invite_code = invite_code
	
	GameState.assign_role(GameState.Role.SIDEKICK)
	GameState.set_session_seed(_session_seed)
	
	print("[OfflineNetwork] Assigned role: SIDEKICK, session seed: ", _session_seed)
	emit_signal("connection_established", _local_peer_id, Role.SIDEKICK)
	emit_signal("role_assignment_received", Role.SIDEKICK)


@rpc("authority", "reliable")
func _game_started_rpc(checkpoint: String):
	_change_state(ConnectionState.PLAYING)
	emit_signal("game_started", checkpoint)


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
	var synced_seed = world_state.get("session_seed", 0)
	if synced_seed != 0 and synced_seed != _session_seed:
		_session_seed = synced_seed
		GameState.set_session_seed(_session_seed)


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


@rpc("authority", "reliable")
func _notify_host_leaving():
	emit_signal("game_paused", "host_leaving")


@rpc("authority", "reliable")
func _rejoin_game_rpc(rejoin_data: Dictionary):
	"""Called on sidekick when joining an active game session."""
	print("[OfflineNetwork] Rejoining active game session")
	_is_rejoining = true
	
	var world_state = rejoin_data.get("world_progress", {})
	var player_positions = rejoin_data.get("player_positions", {})
	
	_world_progress = world_state
	
	# Update GameState with host's world progress
	if world_state.has("collected_clues"):
		GameState.collected_clues = world_state.collected_clues.duplicate(true)
	if world_state.has("zones_status"):
		GameState.zones_status = world_state.zones_status.duplicate(true)
	if world_state.has("current_zone"):
		GameState.current_zone = world_state.current_zone
	
	# Store ONLY the detective (host) position for spawning on sidekick's screen
	# Sidekick should spawn fresh at spawn point, not at their last known position
	for peer_id_str in player_positions.keys():
		var peer_id = int(peer_id_str)
		# Only store position for host (peer_id == 1) - this is the detective's position
		if peer_id == 1:
			var pos_data = player_positions[peer_id_str]
			if pos_data is Dictionary and pos_data.has("position"):
				var pos = Vector2(pos_data.position.x, pos_data.position.y)
				GameState.save_spawn_position(peer_id, pos, "forest_hub")
				print("[OfflineNetwork] Stored detective rejoin position: ", pos)
	
	emit_signal("rejoin_game_requested", rejoin_data)


# ============================================================================
# MULTIPLAYER EVENT HANDLERS
# ============================================================================

func _on_multiplayer_peer_connected(peer_id: int):
	print("[OfflineNetwork] Peer connected: ", peer_id)
	emit_signal("player_connected", peer_id, Role.SIDEKICK if _is_host else Role.DETECTIVE)
	
	if _is_host:
		_partner_peer_id = peer_id
		_assign_role_rpc.rpc_id(peer_id, Role.SIDEKICK, _invite_code, _session_seed)
		
		emit_signal("partner_connected", {
			"player_id": str(peer_id),
			"display_name": "Sidekick",
			"role": "sidekick"
		})
		emit_signal("player_joined", peer_id, Role.SIDEKICK)
		
		# If host has already started a game (or is currently playing), notify sidekick to rejoin directly
		if _state == ConnectionState.PLAYING or _has_game_started:
			print("[OfflineNetwork] Game already started - sending rejoin signal to sidekick")
			# Ensure we have the latest world state before sending
			sync_world_progress_from_gamestate()
			# Include current player positions for proper sync
			var rejoin_data = {
				"world_progress": _world_progress,
				"player_positions": _last_known_positions.duplicate(true)
			}
			# Wait a moment for sidekick to load their scene before sending rejoin signal
			await get_tree().create_timer(0.5).timeout
			if multiplayer.get_peers().has(peer_id):
				_rejoin_game_rpc.rpc_id(peer_id, rejoin_data)
	else:
		emit_signal("player_joined", peer_id, Role.DETECTIVE)


func _on_multiplayer_peer_disconnected(peer_id: int):
	print("[OfflineNetwork] Peer disconnected: ", peer_id)
	emit_signal("player_disconnected", peer_id)
	
	if peer_id == _partner_peer_id:
		_partner_peer_id = 0
		emit_signal("partner_disconnected", "partner_disconnected")
		emit_signal("game_paused", "partner_disconnected")
		emit_signal("player_left", peer_id)
		
		if _is_host and _state == ConnectionState.PLAYING:
			_change_state(ConnectionState.HOSTING)


func _on_connected_to_server():
	print("[OfflineNetwork] Connected to server")
	_local_peer_id = multiplayer.get_unique_id()
	_change_state(ConnectionState.CONNECTED)


func _on_connection_failed():
	push_error("[OfflineNetwork] Connection failed")
	_change_state(ConnectionState.DISCONNECTED)
	emit_signal("connection_failed", "Failed to connect to host")
	_cleanup()


func _on_server_disconnected():
	print("[OfflineNetwork] Server disconnected")
	emit_signal("partner_disconnected", "host_disconnected")
	emit_signal("game_paused", "host_disconnected")
	_change_state(ConnectionState.DISCONNECTED)
	_cleanup()


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _change_state(new_state: ConnectionState):
	if _state == new_state:
		return
	var old_state := _state
	_state = new_state
	emit_signal("connection_state_changed", new_state, old_state)
	print("[OfflineNetwork] State: ", _state_name(old_state), " -> ", _state_name(new_state))


func _state_name(s: int) -> String:
	match s:
		ConnectionState.DISCONNECTED: return "DISCONNECTED"
		ConnectionState.CONNECTING: return "CONNECTING"
		ConnectionState.HOSTING: return "HOSTING"
		ConnectionState.CONNECTED: return "CONNECTED"
		ConnectionState.PLAYING: return "PLAYING"
		ConnectionState.DISCONNECTING: return "DISCONNECTING"
		_: return "UNKNOWN"


func _cleanup():
	_is_host = false
	_local_peer_id = 0
	_partner_peer_id = 0
	_local_role = Role.NONE
	_invite_code = ""
	_world_progress.clear()
	_partner_states.clear()
	_is_rejoining = false
	
	# Ensure multiplayer peer is fully cleaned up
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Force clear multiplayer peer reference
	multiplayer.multiplayer_peer = null
	_multiplayer_peer = null
	
	# Clean up discovery sockets
	if _broadcast_socket:
		_broadcast_socket.close()
		_broadcast_socket = null
	_stop_discovery_listen()
	
	# Reset discovery target
	_target_code = ""
	_last_discovered_host = {}


func _wait_for_connection() -> Dictionary:
	var attempts: int = 0
	var max_attempts: int = int(CONNECTION_TIMEOUT_SEC * 10.0)
	
	while attempts < max_attempts:
		await get_tree().create_timer(0.1).timeout
		
		if _state == ConnectionState.CONNECTED:
			return {"success": true}
		
		if _state == ConnectionState.DISCONNECTED:
			return {"success": false, "error": "Connection failed"}
		
		attempts += 1
	
	return {"success": false, "error": "Connection timeout"}


func _generate_invite_code() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # Removed confusing chars (I, O, 0, 1)
	var code = ""
	var random_seed = hash(str(randi()) + str(Time.get_unix_time_from_system()))
	for i in range(6):
		random_seed = (random_seed * 9301 + 49297) % 233280
		code += chars[random_seed % chars.length()]
	return code


func _generate_qr_data() -> String:
	"""Generate QR code string: KWENTURA|IP|PORT|CODE"""
	return "KWENTURA|%s|%d|%s" % [_host_ip, DEFAULT_PORT, _invite_code]


func _get_best_host_ip() -> String:
	"""Get the best IP address for hosting (prioritizes hotspot IPs)"""
	var ips = IP.get_local_addresses()
	print("[OfflineNetwork] Available IPs: ", ips)
	
	# Priority 1: Android Hotspot (most common)
	for ip in ips:
		if ip.begins_with("192.168.43.") or ip.begins_with("192.168.44."):
			print("[OfflineNetwork] Selected Android Hotspot IP: ", ip)
			return ip
	
	# Priority 2: iOS Personal Hotspot
	for ip in ips:
		if ip.begins_with("172.20.10."):
			print("[OfflineNetwork] Selected iOS Hotspot IP: ", ip)
			return ip
	
	# Priority 3: Common private networks
	for ip in ips:
		if ip.begins_with("192.168.") and not ip.begins_with("127."):
			print("[OfflineNetwork] Selected Local Network IP: ", ip)
			return ip
	
	# Priority 4: Other private ranges
	for ip in ips:
		if (ip.begins_with("10.") or ip.begins_with("172.")) and not ip.begins_with("127."):
			print("[OfflineNetwork] Selected Private Network IP: ", ip)
			return ip
	
	# Fallback: Any valid IPv4 (excluding loopback)
	for ip in ips:
		if "." in ip and not ip.begins_with("127.") and not ip.begins_with("0."):
			print("[OfflineNetwork] Selected Fallback IP: ", ip)
			return ip
	
	# Last resort: localhost (for single-device testing)
	print("[OfflineNetwork] Using localhost fallback (127.0.0.1)")
	return "127.0.0.1"


func _is_valid_ip(ip: String) -> bool:
	"""Basic IP address validation"""
	var parts = ip.split(".")
	if parts.size() != 4:
		return false
	
	for part in parts:
		if not part.is_valid_int():
			return false
		var num = part.to_int()
		if num < 0 or num > 255:
			return false
	
	return true


func _get_host_instructions() -> Array:
	"""Get instructions for the host to share connection info"""
	return [
		"Your IP Address: " + _host_ip,
		"Room Code: " + _invite_code,
		"",
		"Share these with your partner:",
		"1. Same Wi-Fi: Give them your IP",
		"2. Hotspot Mode: Enable hotspot, share password + IP",
		"3. QR Code: Show them the QR code to scan"
	]


func _get_connection_troubleshooting_tips() -> String:
	"""Get helpful troubleshooting tips for connection failures"""
	return """

Troubleshooting:
• Verify the IP address is correct
• Ensure both devices are on the same network
• Try Hotspot Mode (host enables mobile hotspot)
• Disable mobile data on client device
• Check firewall settings (allow port 17777)"""


# ============================================================================
# PUBLIC UTILITY FUNCTIONS
# ============================================================================

## Get connection instructions for UI display
func get_connection_instructions() -> Dictionary:
	if _is_host:
		return {
			"title": "Host Instructions",
			"mode": "host",
			"ip": _host_ip,
			"code": _invite_code,
			"qr_data": _generate_qr_data(),
			"steps": [
				"📱 HOST (No Internet Required!)",
				"",
				"Your IP: " + _host_ip,
				"Code: " + _invite_code,
				"",
				"Share with Sidekick:",
				"1. Same Wi-Fi: Give them room code",
				"2. Hotspot: Enable mobile hotspot, share code",
				"3. QR Code: Show them the QR code"
			],
			"troubleshooting": [
				"💡 Works WITHOUT internet!",
				"• Same Wi-Fi router (router can be offline)",
				"• Mobile Hotspot (easiest, guaranteed)",
				"• Check firewall allows port 17777"
			]
		}
	else:
		return {
			"title": "Connection Options",
			"mode": "client",
			"options": [
				{
					"name": "Direct IP",
					"description": "Enter host's IP address directly",
					"best_for": "Same Wi-Fi network"
				},
				{
					"name": "Hotspot Mode",
					"description": "Connect to host's mobile hotspot",
					"best_for": "No Wi-Fi router available"
				},
				{
					"name": "QR Code",
					"description": "Scan host's QR code",
					"best_for": "Quick connection"
				}
			],
			"tips": [
				"Ask host for their IP address",
				"Common formats: 192.168.x.x or 172.20.x.x",
				"If connection fails, try hotspot mode"
			]
		}


## Get local IP addresses for display
func get_local_ips() -> Array:
	var all_ips = IP.get_local_addresses()
	var valid_ips = []
	
	for ip in all_ips:
		# Skip loopback and invalid
		if ip.begins_with("127.") or not "." in ip:
			continue
		
		var type = "other"
		if ip.begins_with("192.168.43.") or ip.begins_with("192.168.44."):
			type = "android_hotspot"
		elif ip.begins_with("172.20.10."):
			type = "ios_hotspot"
		elif ip.begins_with("192.168."):
			type = "wifi"
		elif ip.begins_with("10.") or ip.begins_with("172."):
			type = "network"
		
		valid_ips.append({"ip": ip, "type": type})
	
	return valid_ips


## Check if we are likely in hotspot mode
func is_likely_hotspot() -> bool:
	var ip = _host_ip
	return ip.begins_with("192.168.43.") or ip.begins_with("192.168.44.") or ip.begins_with("172.20.10.")


# ============================================================================
# BACKWARD COMPATIBILITY FUNCTIONS
# ============================================================================

## DEPRECATED: Discovery is no longer supported
func start_discovery_for_code(target_code: String) -> bool:
	push_warning("[OfflineNetwork] Discovery is deprecated. Use direct IP connection.")
	return false


## DEPRECATED: Discovery is no longer supported  
func stop_discovery():
	push_warning("[OfflineNetwork] stop_discovery is deprecated.")


## DEPRECATED: Discovery is no longer supported
func get_discovered_host(_code: String) -> Dictionary:
	return {}


## Notify sidekick that host is leaving
func notify_host_leaving() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_notify_host_leaving.rpc()


## Notify host that sidekick is leaving (called before disconnect)
func notify_sidekick_leaving() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_notify_sidekick_leaving.rpc_id(1)  # Send to host (peer ID 1)


@rpc("any_peer", "reliable")
func _notify_sidekick_leaving() -> void:
	# Host receives this
	var peer_id = multiplayer.get_remote_sender_id()
	print("[OfflineNetwork] Sidekick ", peer_id, " is leaving")
	if peer_id == _partner_peer_id:
		_partner_peer_id = 0
		emit_signal("partner_disconnected", {
			"player_id": str(peer_id),
			"reason": "left"
		})


## Request spawn player on specific peer
func request_spawn_player(target_peer: int, peer_id: int, is_detective: bool) -> void:
	_rpc_request_spawn_player.rpc_id(target_peer, peer_id, is_detective)


## Request despawn player
func request_despawn_player(peer_id: int) -> void:
	_rpc_request_despawn_player.rpc(peer_id)


## Send costume state to a specific client
func send_costume_state_to_client(target_peer: int) -> void:
	_rpc_send_full_costume_state.rpc_id(target_peer,
		GameState.selected_costumes["detective"],
		GameState.selected_costumes["sidekick"],
		GameState._costume_confirmed_status["detective"],
		GameState._costume_confirmed_status["sidekick"]
	)


## Sync costume preview to all peers
func sync_costume_preview(role: String, costume_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_sync_costume_preview.rpc(role, costume_id)


## Sync costume confirmation to all peers
func sync_costume_confirmed(role: String, costume_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_sync_costume_confirmed.rpc(role, costume_id)


# ============================================================================
# RPC FUNCTIONS - Costume & Spawn
# ============================================================================

@rpc("authority", "reliable")
func _rpc_request_spawn_player(peer_id: int, is_detective_role: bool):
	emit_signal("spawn_player_requested", peer_id, is_detective_role)


@rpc("authority", "reliable")
func _rpc_request_despawn_player(peer_id: int):
	emit_signal("despawn_player_requested", peer_id)


@rpc("any_peer", "reliable")
func _rpc_sync_costume_preview(role: String, costume_id: String) -> void:
	if multiplayer.get_remote_sender_id() == 0:
		return
	GameState.selected_costumes[role] = costume_id
	GameState.emit_signal("costume_changed", role, costume_id)


@rpc("any_peer", "reliable")
func _rpc_sync_costume_confirmed(role: String, costume_id: String) -> void:
	if multiplayer.get_remote_sender_id() == 0:
		return
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
