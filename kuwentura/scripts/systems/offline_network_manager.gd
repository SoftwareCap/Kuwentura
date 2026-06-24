extends Node

## Offline Network Manager - LAN Multiplayer without requiring same Wi-Fi
##
## Supports multiple connection modes:
## 1. Hotspot - Host creates mobile hotspot, client connects to it
## 2. Room Code - UDP broadcast discovery on the same network

enum ConnectionState {
	DISCONNECTED, CONNECTING, HOSTING, CONNECTED, PLAYING, DISCONNECTING,
}
enum Role { NONE, DETECTIVE, SIDEKICK }

const DEFAULT_PORT: int = 17777
const MAX_PLAYERS: int = 2
const CONNECTION_TIMEOUT_SEC: float = 10.0
const DISCOVERY_BROADCAST_INTERVAL: float = 0.5
const DISCOVERY_PORT: int = 17778
const DISCOVERY_TIMEOUT: float = 10.0

# IP priority list for host selection â€” checked in order, first match wins
const IP_PRIORITY: Array = [
	"192.168.43.", "192.168.44.", # Android hotspot
	"172.20.10.", # iOS hotspot
	"192.168.", # Common home Wi-Fi
	"10.", "172.", # Other private ranges
]

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

var _state: ConnectionState = ConnectionState.DISCONNECTED
var _multiplayer_peer: ENetMultiplayerPeer = null
var _local_role: Role = Role.NONE
var _local_peer_id: int = 0
var _partner_peer_id: int = 0
var _is_host: bool = false
var _invite_code: String = ""
var _session_seed: int = 0
var _host_ip: String = ""
var _world_progress: Dictionary = {}
var _partner_states: Dictionary = {}
var _has_game_started: bool = false
var _is_rejoining: bool = false
var _last_known_positions: Dictionary = {}
var _last_discovered_host: Dictionary = {}

var _broadcast_socket: PacketPeerUDP = null
var _listen_socket: PacketPeerUDP = null
var _discovery_timer: float = 0.0
var _is_listening: bool = false
var _target_code: String = ""

var enable_prediction: bool = true
var enable_interpolation: bool = true


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if GameState:
		GameState.clue_collected.connect(_on_progress_changed)
		GameState.zone_completed.connect(_on_progress_changed)


func _exit_tree() -> void:
	disconnect_network()


func _process(delta: float) -> void:
	if _is_host and (_state == ConnectionState.HOSTING or _state == ConnectionState.PLAYING):
		_discovery_timer += delta
		if _discovery_timer >= DISCOVERY_BROADCAST_INTERVAL:
			_discovery_timer = 0.0
			_broadcast_presence()
	if _is_listening and _listen_socket:
		_poll_discovery()


func _on_progress_changed(_a: Variant = null, _b: Variant = null) -> void:
	"""Sync world progress whenever a clue or zone changes (host only)."""
	if _is_host:
		sync_world_progress_from_gamestate()


func _has_peers() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0


func report_position(peer_id: int, position: Vector2) -> void:
	if not _is_host:
		_report_position_to_host_rpc.rpc_id(1, peer_id, position)
	else:
		_store_position(peer_id, position)


func _store_position(peer_id: int, position: Vector2) -> void:
	if not _is_host:
		return
	_last_known_positions[str(peer_id)] = {
		"position": {"x": position.x, "y": position.y},
		"timestamp": int(Time.get_unix_time_from_system()),
	}


@rpc("any_peer", "unreliable")
func _report_position_to_host_rpc(peer_id: int, position: Vector2) -> void:
	if multiplayer.is_server():
		_store_position(peer_id, position)


func _start_discovery_broadcast() -> void:
	_broadcast_socket = PacketPeerUDP.new()
	_broadcast_socket.set_broadcast_enabled(true)
	# No bind â€” socket is send-only


func _broadcast_presence() -> void:
	if not _broadcast_socket or _invite_code.is_empty():
		return
	var broadcast_data := {
		"game": "kwentura",
		"version": "1.0.0",
		"code": _invite_code,
		"host_ip": _host_ip,
		"port": DEFAULT_PORT,
		"timestamp": Time.get_unix_time_from_system(),
	}
	var packet := JSON.stringify(broadcast_data).to_utf8_buffer()
	var targets := ["255.255.255.255", "192.168.1.255", "192.168.0.255", "192.168.43.255", "172.20.10.255"]
	for addr in targets:
		_broadcast_socket.set_dest_address(addr, DISCOVERY_PORT)
		_broadcast_socket.put_packet(packet)


func _start_discovery_listen(target_code: String) -> Dictionary:
	_target_code = target_code.to_upper()
	_listen_socket = PacketPeerUDP.new()
	_listen_socket.set_broadcast_enabled(true)
	var error := _listen_socket.bind(DISCOVERY_PORT, "0.0.0.0")
	if error != OK:
		_listen_socket = PacketPeerUDP.new()
		_listen_socket.set_broadcast_enabled(true)
		error = _listen_socket.bind(DISCOVERY_PORT)
		if error != OK:
			_listen_socket = null
			return {"success": false, "error": "Cannot bind to port " + str(DISCOVERY_PORT) + " (code: " + str(error) + ")"}
	_is_listening = true
	return {"success": true}


func _poll_discovery() -> void:
	if not _listen_socket:
		return
	while _listen_socket.get_available_packet_count() > 0:
		var packet := _listen_socket.get_packet()
		var from_ip := _listen_socket.get_packet_ip()
		var data: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if data == null or not data is Dictionary:
			continue
		if data.get("game") != "kwentura":
			continue
		var code: String = data.get("code", "")
		var host_ip: String = from_ip if not from_ip.is_empty() else data.get("host_ip", "")
		if code == _target_code:
			_last_discovered_host = {
				"ip": host_ip,
				"port": data.get("port", DEFAULT_PORT),
				"code": code,
			}


func _wait_for_discovery(target_code: String) -> Dictionary:
	var elapsed := 0.0
	_last_discovered_host = {}
	while elapsed < DISCOVERY_TIMEOUT:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if not _last_discovered_host.is_empty() and _last_discovered_host.code == target_code:
			return _last_discovered_host
	return {}


func _stop_discovery_listen() -> void:
	_is_listening = false
	if _listen_socket:
		_listen_socket.close()
		_listen_socket = null


func is_host() -> bool:
	return _is_host

func is_playing() -> bool:
	return _state == ConnectionState.PLAYING

func is_rejoining() -> bool:
	return _is_rejoining

func get_state() -> ConnectionState:
	return _state

func get_state_name() -> String:
	return _state_name(_state)

func get_my_role() -> String:
	match _local_role:
		Role.DETECTIVE: return "detective"
		Role.SIDEKICK: return "sidekick"
		_: return "none"

func get_my_role_enum() -> Role:
	return _local_role

func get_invite_code() -> String:
	return _invite_code

func get_host_ip() -> String:
	return _host_ip

func has_active_connection() -> bool:
	return _state in [ConnectionState.PLAYING, ConnectionState.HOSTING, ConnectionState.CONNECTED]

func is_partner_connected() -> bool:
	return _partner_peer_id != 0 and _state in [ConnectionState.PLAYING, ConnectionState.HOSTING]

func get_partner_state(peer_id: int) -> Dictionary:
	return _partner_states.get(str(peer_id), {})

func get_partner_peer_id() -> int:
	return _partner_peer_id

func clear_partner_state(peer_id: int) -> void:
	_partner_states.erase(str(peer_id))


func host_game() -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		_cleanup()
		_state = ConnectionState.DISCONNECTED

	_change_state(ConnectionState.CONNECTING)
	_multiplayer_peer = ENetMultiplayerPeer.new()
	var error := _multiplayer_peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if error != OK:
		_change_state(ConnectionState.DISCONNECTED)
		return {"success": false, "error": "Failed to create server: " + str(error)}

	multiplayer.multiplayer_peer = _multiplayer_peer
	_local_peer_id = 1
	_is_host = true
	_local_role = Role.DETECTIVE
	_has_game_started = false
	GameState.assign_role(GameState.Role.DETECTIVE)
	role_assignment_received.emit(Role.DETECTIVE)

	_invite_code = _generate_invite_code()
	_session_seed = randi()
	_host_ip = _get_best_host_ip()
	GameState.set_session_seed(_session_seed)
	sync_world_progress_from_gamestate()
	_world_progress["start_checkpoint"] = GameState.START_CHECKPOINT_OPENING
	_change_state(ConnectionState.HOSTING)

	var host_info := {
		"success": true,
		"invite_code": _invite_code,
		"host_ip": _host_ip,
		"port": DEFAULT_PORT,
		"connection_instructions": _get_host_instructions(),
	}
	connection_established.emit(_local_peer_id, Role.DETECTIVE)
	host_info_updated.emit(host_info)
	room_code_generated.emit(_invite_code)
	_start_discovery_broadcast()
	return host_info



func _connect_to_host(host_ip: String, code: String = "") -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		force_reset_for_reconnection()
	if host_ip.is_empty():
		return {"success": false, "error": "IP address is required"}
	if not _is_valid_ip(host_ip) and host_ip != "localhost":
		return {"success": false, "error": "Invalid IP address format. Expected: xxx.xxx.xxx.xxx (e.g., 192.168.1.5)"}

	_change_state(ConnectionState.CONNECTING)
	_multiplayer_peer = ENetMultiplayerPeer.new()
	var error := _multiplayer_peer.create_client(host_ip, DEFAULT_PORT)
	if error != OK:
		_change_state(ConnectionState.DISCONNECTED)
		return {"success": false, "error": "Failed to create client: " + str(error)}

	multiplayer.multiplayer_peer = _multiplayer_peer
	_local_role = Role.SIDEKICK
	_invite_code = code
	GameState.assign_role(GameState.Role.SIDEKICK)
	role_assignment_received.emit(Role.SIDEKICK)

	var result := await _wait_for_connection()
	if not result.success:
		_cleanup()
		_change_state(ConnectionState.DISCONNECTED)
		var error_msg: String = result.error
		if error_msg.contains("timeout"):
			error_msg += _get_connection_troubleshooting_tips()
		return {"success": false, "error": error_msg}
	return {"success": true}



func join_game_with_code(invite_code: String) -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		force_reset_for_reconnection()
	var target_code := invite_code.to_upper()
	var discovery: Dictionary = _start_discovery_listen(target_code)
	if not discovery.success:
		return {"success": false, "error": "Failed to start discovery: " + discovery.error}
	var host_info := await _wait_for_discovery(target_code)
	_stop_discovery_listen()
	if host_info.is_empty():
		return {
			"success": false,
			"error": "Could not find game with code: " + target_code + "\n\nConnection Options:\n1. Same Wi-Fi: Connect both devices to same network\n2. Hotspot Mode: Host enables mobile hotspot, Sidekick connects to it\n\nThen:\nâ€¢ Host must be in lobby\nâ€¢ Room code must match",
		}
	return await _connect_to_host(host_info.ip, target_code)




func start_game(checkpoint: String = GameState.START_CHECKPOINT_OPENING) -> bool:
	if not _is_host:
		push_warning("[OfflineNetwork] Only host can start the game")
		return false
	if _state != ConnectionState.HOSTING or _partner_peer_id == 0:
		push_warning("[OfflineNetwork] No partner connected")
		return false
	sync_world_progress_from_gamestate()
	_world_progress["start_checkpoint"] = checkpoint
	_rpc_sync_world_state.rpc(_world_progress)
	_change_state(ConnectionState.PLAYING)
	_has_game_started = true
	_game_started_rpc.rpc(checkpoint)
	game_started.emit(checkpoint)
	return true


func resume_game() -> bool:
	if _state != ConnectionState.PLAYING:
		push_warning("[OfflineNetwork] Cannot resume: not in PLAYING state")
		return false
	if _is_host:
		_game_resumed_rpc.rpc()
	else:
		_request_resume_rpc.rpc_id(1)
	game_resumed.emit()
	return true


func sync_world_progress_from_gamestate() -> void:
	var start_checkpoint: String = str(_world_progress.get("start_checkpoint", GameState.START_CHECKPOINT_OPENING))
	_world_progress = {
		"collected_clues": GameState.collected_clues.duplicate(true),
		"zones_status": GameState.zones_status.duplicate(true),
		"visited_zones": GameState.visited_zones.duplicate(true),
		"ledger_entries": GameState.ledger_entries.duplicate(true),
		"solved_puzzles": GameState.solved_puzzles.duplicate(true),
		"current_zone": GameState.current_zone,
		"session_seed": _session_seed,
		"climax_triggered": GameState.climax_triggered,
		"game_completed": GameState.game_completed,
		"start_checkpoint": start_checkpoint,
	}


func _apply_world_state_to_gamestate(world_state: Dictionary) -> void:
	if world_state.has("collected_clues"):
		GameState.collected_clues = world_state.collected_clues.duplicate(true)
	if world_state.has("zones_status"):
		GameState.zones_status = world_state.zones_status.duplicate(true)
	if world_state.has("visited_zones"):
		GameState.visited_zones = world_state.visited_zones.duplicate(true)
	if world_state.has("ledger_entries"):
		GameState.ledger_entries = world_state.ledger_entries.duplicate(true)
	if world_state.has("solved_puzzles"):
		GameState.solved_puzzles = world_state.solved_puzzles.duplicate(true)
	if world_state.has("current_zone"):
		GameState.current_zone = world_state.current_zone
	if world_state.has("climax_triggered"):
		GameState.climax_triggered = world_state.climax_triggered
	if world_state.has("game_completed"):
		GameState.game_completed = world_state.game_completed
	GameState.briefcase_updated.emit()


func disconnect_network() -> void:
	if _state == ConnectionState.DISCONNECTED:
		return
	_change_state(ConnectionState.DISCONNECTING)
	if _is_host and _partner_peer_id != 0:
		_notify_host_leaving.rpc()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_cleanup()
	_change_state(ConnectionState.DISCONNECTED)


func force_reset_for_reconnection() -> void:
	_cleanup()
	_state = ConnectionState.DISCONNECTED


func disconnect_from_session() -> void:
	disconnect_network()


@rpc("authority", "reliable")
func _assign_role_rpc(role: Role, invite_code: String, session_seed: int) -> void:
	_local_role = role
	_session_seed = session_seed
	_invite_code = invite_code
	GameState.assign_role(GameState.Role.SIDEKICK)
	GameState.set_session_seed(_session_seed)
	connection_established.emit(_local_peer_id, Role.SIDEKICK)
	role_assignment_received.emit(Role.SIDEKICK)


@rpc("authority", "reliable")
func _game_started_rpc(checkpoint: String) -> void:
	_change_state(ConnectionState.PLAYING)
	game_started.emit(checkpoint)


@rpc("any_peer", "reliable")
func _request_resume_rpc() -> void:
	if multiplayer.is_server():
		_game_resumed_rpc.rpc()


@rpc("authority", "reliable")
func _game_resumed_rpc() -> void:
	game_resumed.emit()


@rpc("any_peer", "reliable")
func _rpc_sync_world_state(world_state: Dictionary) -> void:
	_world_progress = world_state
	var synced_seed: int = world_state.get("session_seed", 0)
	if synced_seed != 0 and synced_seed != _session_seed:
		_session_seed = synced_seed
		GameState.set_session_seed(_session_seed)
	_apply_world_state_to_gamestate(world_state)


@rpc("any_peer", "reliable")
func submit_puzzle_solution(puzzle_id: String, solution: Variant, _attempt_time_ms: int) -> void:
	if multiplayer.is_server():
		var result: Dictionary = PuzzleManager.validate_puzzle(puzzle_id, solution)
		_puzzle_result_rpc.rpc_id(multiplayer.get_remote_sender_id(), puzzle_id, result)


@rpc("authority", "reliable")
func _puzzle_result_rpc(_puzzle_id: String, _result: Dictionary) -> void:
	pass


@rpc("any_peer", "unreliable_ordered")
func sync_player_state(position: Vector2, velocity: Vector2, facing: String, animation_state: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	print("[NET] sync_player_state received, sender_id=", sender_id)
	_partner_states[str(multiplayer.get_remote_sender_id())] = {
		"position": position,
		"velocity": velocity,
		"facing": facing,
		"animation": animation_state,
		"timestamp": Time.get_unix_time_from_system(),
	}


@rpc("authority", "reliable")
func trigger_clue_collection(zone_id: String, _clue_data: Dictionary) -> void:
	GameState.collect_clue(zone_id)


@rpc("authority", "reliable")
func _notify_host_leaving() -> void:
	game_paused.emit("host_leaving")


@rpc("authority", "reliable")
func _rejoin_game_rpc(rejoin_data: Dictionary) -> void:
	"""Called on sidekick when joining an active game session."""
	_is_rejoining = true
	var world_state: Dictionary = rejoin_data.get("world_progress", {})
	var player_positions: Dictionary = rejoin_data.get("player_positions", {})
	_world_progress = world_state
	_apply_world_state_to_gamestate(world_state)
	for peer_id_str in player_positions:
		var pid := int(peer_id_str)
		if pid == 1:
			var pos_data: Variant = player_positions[peer_id_str]
			if pos_data is Dictionary and pos_data.has("position"):
				var pos := Vector2(pos_data.position.x, pos_data.position.y)
				GameState.save_spawn_position(pid, pos, "forest_hub")
	rejoin_game_requested.emit(rejoin_data)


func _on_multiplayer_peer_connected(peer_id: int) -> void:
	player_connected.emit(peer_id, Role.SIDEKICK if _is_host else Role.DETECTIVE)
	if _is_host:
		_partner_peer_id = peer_id
		_assign_role_rpc.rpc_id(peer_id, Role.SIDEKICK, _invite_code, _session_seed)
		partner_connected.emit({"player_id": str(peer_id), "display_name": "Sidekick", "role": "sidekick"})
		player_joined.emit(peer_id, Role.SIDEKICK)
		if _state == ConnectionState.PLAYING or _has_game_started:
			sync_world_progress_from_gamestate()
			var rejoin_data := {
				"world_progress": _world_progress,
				"player_positions":_last_known_positions.duplicate(true),
			}
			await get_tree().create_timer(0.5).timeout
			if multiplayer.get_peers().has(peer_id):
				_rejoin_game_rpc.rpc_id(peer_id, rejoin_data)
	else:
		player_joined.emit(peer_id, Role.DETECTIVE)


func _on_multiplayer_peer_disconnected(peer_id: int) -> void:
	player_disconnected.emit(peer_id)
	if peer_id == _partner_peer_id:
		_partner_peer_id = 0
		partner_disconnected.emit("partner_disconnected")
		game_paused.emit("partner_disconnected")
		player_left.emit(peer_id)
		if _is_host and _state == ConnectionState.PLAYING:
			_change_state(ConnectionState.HOSTING)


func _on_connected_to_server() -> void:
	_local_peer_id = multiplayer.get_unique_id()
	_partner_peer_id = 1
	_change_state(ConnectionState.CONNECTED)


func _on_connection_failed() -> void:
	push_error("[OfflineNetwork] Connection failed")
	_change_state(ConnectionState.DISCONNECTED)
	connection_failed.emit("Failed to connect to host")
	_cleanup()


func _on_server_disconnected() -> void:
	partner_disconnected.emit("host_disconnected")
	game_paused.emit("host_disconnected")
	_change_state(ConnectionState.DISCONNECTED)
	_cleanup()


func _change_state(new_state: ConnectionState) -> void:
	if _state == new_state:
		return
	var old_state := _state
	_state = new_state
	connection_state_changed.emit(new_state, old_state)


func _state_name(s: int) -> String:
	match s:
		ConnectionState.DISCONNECTED: return "DISCONNECTED"
		ConnectionState.CONNECTING: return "CONNECTING"
		ConnectionState.HOSTING: return "HOSTING"
		ConnectionState.CONNECTED: return "CONNECTED"
		ConnectionState.PLAYING: return "PLAYING"
		ConnectionState.DISCONNECTING: return "DISCONNECTING"
		_: return "UNKNOWN"


func _cleanup() -> void:
	_is_host = false
	_local_peer_id = 0
	_partner_peer_id = 0
	_local_role = Role.NONE
	_invite_code = ""
	_is_rejoining = false
	_world_progress.clear()
	_partner_states.clear()
	_target_code = ""
	_last_discovered_host = {}
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_multiplayer_peer = null
	if _broadcast_socket:
		_broadcast_socket.close()
		_broadcast_socket = null
	_stop_discovery_listen()


func _wait_for_connection() -> Dictionary:
	var attempts := 0
	var max_attempts := int(CONNECTION_TIMEOUT_SEC * 10.0)
	while attempts < max_attempts:
		await get_tree().create_timer(0.1).timeout
		if _state == ConnectionState.CONNECTED:
			return {"success": true}
		if _state == ConnectionState.DISCONNECTED:
			return {"success": false, "error": "Connection failed"}
		attempts += 1
	return {"success": false, "error": "Connection timeout"}


func _generate_invite_code() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	var _rng := hash(str(randi()) + str(Time.get_unix_time_from_system()))
	for i in range(6):
		_rng = (_rng * 9301 + 49297) % 233280
		code += chars[_rng % chars.length()]
	return code



func _get_best_host_ip() -> String:
	var ips := IP.get_local_addresses()
	for prefix in IP_PRIORITY:
		for ip in ips:
			if ip.begins_with(prefix) and not ip.begins_with("127."):
				return ip
	for ip in ips:
		if "." in ip and not ip.begins_with("127.") and not ip.begins_with("0."):
			return ip
	return "127.0.0.1"


func _is_valid_ip(ip: String) -> bool:
	var parts := ip.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
		var num := part.to_int()
		if num < 0 or num > 255:
			return false
	return true


func _get_host_instructions() -> Array:
	return [
		"Your IP Address: " + _host_ip,
		"Room Code: " + _invite_code,
		"", "Share these with your partner:",
		"1. Same Wi-Fi: Give them your IP",
		"2. Hotspot Mode: Enable hotspot, share password + IP",
	]


func _get_connection_troubleshooting_tips() -> String:
	return "\n\nTroubleshooting:\nâ€¢ Verify the IP address is correct\nâ€¢ Ensure both devices are on the same network\nâ€¢ Try Hotspot Mode (host enables mobile hotspot)\nâ€¢ Disable mobile data on client device\nâ€¢ Check firewall settings (allow port 17777)"


func get_connection_instructions() -> Dictionary:
	if _is_host:
		return {
			"title": "Host Instructions", "mode": "host",
			"steps": [
				"Your IP: " + _host_ip, "Code: " + _invite_code, "",
				"Share with Sidekick:",
				"1. Same Wi-Fi: Give them room code",
				"2. Hotspot: Enable mobile hotspot, share code",
			],
		}
	return {
		"title": "Connection Options", "mode": "client",
		"options": [
			{"name": "Hotspot Mode", "description": "Connect to host's mobile hotspot", "best_for": "No Wi-Fi router available"},
		],
	}


func get_local_ips() -> Array:
	var result: Array = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("127.") or not "." in ip:
			continue
		var type := "other"
		if ip.begins_with("192.168.43.") or ip.begins_with("192.168.44."): type = "android_hotspot"
		elif ip.begins_with("172.20.10."): type = "ios_hotspot"
		elif ip.begins_with("192.168."): type = "wifi"
		elif ip.begins_with("10.") or ip.begins_with("172."): type = "network"
		result.append({"ip": ip, "type": type})
	return result


func is_likely_hotspot() -> bool:
	return _host_ip.begins_with("192.168.43.") or _host_ip.begins_with("192.168.44.") or _host_ip.begins_with("172.20.10.")


func notify_host_leaving() -> void:
	if _has_peers():
		_notify_host_leaving.rpc()


func notify_sidekick_leaving() -> void:
	if _has_peers():
		_notify_sidekick_leaving.rpc_id(1)


@rpc("any_peer", "reliable")
func _notify_sidekick_leaving() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == _partner_peer_id:
		_partner_peer_id = 0
		partner_disconnected.emit("left")


func request_spawn_player(target_peer: int, peer_id: int, is_detective: bool) -> void:
	_rpc_request_spawn_player.rpc_id(target_peer, peer_id, is_detective)

func request_despawn_player(peer_id: int) -> void:
	_rpc_request_despawn_player.rpc(peer_id)

func send_costume_state_to_client(target_peer: int) -> void:
	_rpc_send_full_costume_state.rpc_id(target_peer,
		GameState.selected_costumes["detective"],
		GameState.selected_costumes["sidekick"],
		GameState._costume_confirmed_status["detective"],
		GameState._costume_confirmed_status["sidekick"]
	)

func sync_costume_preview(role: String, costume_id: String) -> void:
	if _has_peers():
		_rpc_sync_costume_preview.rpc(role, costume_id)

func sync_costume_confirmed(role: String, costume_id: String) -> void:
	if _has_peers():
		_rpc_sync_costume_confirmed.rpc(role, costume_id)


@rpc("authority", "reliable")
func _rpc_request_spawn_player(peer_id: int, is_detective_role: bool) -> void:
	spawn_player_requested.emit(peer_id, is_detective_role)

@rpc("authority", "reliable")
func _rpc_request_despawn_player(peer_id: int) -> void:
	despawn_player_requested.emit(peer_id)

@rpc("any_peer", "reliable")
func _rpc_sync_costume_preview(role: String, costume_id: String) -> void:
	if multiplayer.get_remote_sender_id() == 0:
		return
	GameState.set_selected_costume(role, costume_id)

@rpc("any_peer", "reliable")
func _rpc_sync_costume_confirmed(role: String, costume_id: String) -> void:
	if multiplayer.get_remote_sender_id() == 0:
		return
	GameState.set_selected_costume(role, costume_id)
	GameState.confirm_costume_selection(role, true)

@rpc("authority", "reliable")
func _rpc_send_full_costume_state(detective_costume: String, sidekick_costume: String,
		detective_confirmed: bool, sidekick_confirmed: bool) -> void:
	GameState.set_selected_costume("detective", detective_costume)
	GameState.set_selected_costume("sidekick", sidekick_costume)
	GameState.confirm_costume_selection("detective", detective_confirmed)
	GameState.confirm_costume_selection("sidekick", sidekick_confirmed)


func start_discovery_for_code(_code: String) -> bool:
	push_warning("[OfflineNetwork] start_discovery_for_code() is deprecated. Use join_game_with_code().")
	return false

func stop_discovery() -> void:
	push_warning("[OfflineNetwork] stop_discovery() is deprecated.")

func get_discovered_host(_code: String) -> Dictionary:
	return {}
