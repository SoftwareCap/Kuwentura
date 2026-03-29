extends Node

## Network Manager - LAN Listen Server with Code-Based Discovery
##
## Host broadcasts on port 17778 (no bind), client listens on port 17779.
## Separate sockets prevent port conflicts when both run on the same machine.

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	HOSTING,
	CONNECTED,
	PLAYING,
	DISCONNECTING,
}

enum Role { NONE, DETECTIVE, SIDEKICK }

const DEFAULT_PORT: int = 17777
const MAX_PLAYERS: int = 2
const BROADCAST_PORT: int = 17778
const LISTEN_PORT: int = 17779
const DISCOVERY_BROADCAST_INTERVAL: float = 0.5
const DISCOVERY_TIMEOUT: float = 5.0

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

var _state: ConnectionState = ConnectionState.DISCONNECTED
var _multiplayer_peer: ENetMultiplayerPeer = null

var _broadcast_socket: PacketPeerUDP = null
var _listen_socket: PacketPeerUDP = null
var _discovery_broadcast_timer: float = 0.0
var _is_discovering: bool = false
var _discovery_targets: Dictionary = {}
var _target_code: String = ""

var _local_role: Role = Role.NONE
var _local_peer_id: int = 0
var _partner_peer_id: int = 0

var _invite_code: String = ""
var _session_seed: int = 0
var _is_host: bool = false
var _world_progress: Dictionary = {}
var _partner_states: Dictionary = {}


func is_host() -> bool:
	return _is_host

func is_playing() -> bool:
	return _state == ConnectionState.PLAYING

func get_state() -> ConnectionState:
	return _state

func get_my_role() -> String:
	match _local_role:
		Role.DETECTIVE: return "detective"
		Role.SIDEKICK: return "sidekick"
		_: return "none"

func get_invite_code() -> String:
	return _invite_code

func has_active_connection() -> bool:
	return _state in [ConnectionState.PLAYING, ConnectionState.HOSTING, ConnectionState.CONNECTED]

func is_partner_connected() -> bool:
	return _partner_peer_id != 0 and _state in [ConnectionState.PLAYING, ConnectionState.HOSTING]

func _has_peers() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0

func get_partner_state(peer_id: int) -> Dictionary:
	return _partner_states.get(str(peer_id), {})

func clear_partner_state(peer_id: int) -> void:
	_partner_states.erase(str(peer_id))

func resume_game() -> bool:
	if _state != ConnectionState.PLAYING:
		push_warning("Cannot resume: game is not in PLAYING state")
		return false
	if _is_host:
		_game_resumed_rpc.rpc()
	else:
		_request_resume_rpc.rpc_id(1)
	game_resumed.emit()
	return true

func is_rejoining() -> bool:
	return _state == ConnectionState.PLAYING


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if _is_discovering and _listen_socket:
		_poll_discovery()
	if _is_host and _state == ConnectionState.HOSTING:
		_discovery_broadcast_timer += delta
		if _discovery_broadcast_timer >= DISCOVERY_BROADCAST_INTERVAL:
			_discovery_broadcast_timer = 0.0
			_broadcast_host_presence()


func _exit_tree() -> void:
	disconnect_network()


func host_game() -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		return {"error": "Already connected", "success": false}

	_change_state(ConnectionState.CONNECTING)
	_multiplayer_peer = ENetMultiplayerPeer.new()
	var error := _multiplayer_peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
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
		"session_seed": _session_seed,
	}
	GameState.set_session_seed(_session_seed)
	_start_broadcasting()
	_change_state(ConnectionState.HOSTING)

	connection_established.emit(_local_peer_id)
	role_assignment_received.emit(Role.DETECTIVE)
	room_code_generated.emit(_invite_code)

	return {
		"success": true,
		"invite_code":_invite_code,
		"host_ip": _get_host_ip(),
		"port": DEFAULT_PORT,
	}


func _start_broadcasting() -> void:
	_broadcast_socket = PacketPeerUDP.new()
	_broadcast_socket.set_broadcast_enabled(true)


func _broadcast_host_presence() -> void:
	if not _broadcast_socket or _invite_code.is_empty():
		return
	var broadcast_data := {
		"game": "kwentura",
		"version": "1.0.0",
		"code": _invite_code,
		"host_ip": _get_host_ip(),
		"port": DEFAULT_PORT,
		"host_name": _get_device_name(),
		"timestamp": Time.get_unix_time_from_system(),
	}
	var packet := JSON.stringify(broadcast_data).to_utf8_buffer()
	_broadcast_socket.set_dest_address("255.255.255.255", LISTEN_PORT)
	_broadcast_socket.put_packet(packet)


func start_discovery_for_code(target_code: String) -> bool:
	if _is_discovering:
		return true
	_target_code = target_code.to_upper()
	_discovery_targets.clear()

	_listen_socket = PacketPeerUDP.new()
	_listen_socket.set_broadcast_enabled(true)
	var error := _listen_socket.bind(LISTEN_PORT)
	if error != OK:
		push_warning("[NetworkManager] Failed to bind listen socket: " + str(error))
		_listen_socket = null
		return false

	_is_discovering = true
	discovery_started.emit()
	return true


func get_discovered_host(code: String) -> Dictionary:
	return _discovery_targets.get(code.to_upper(), {})


func join_game_with_code(invite_code: String) -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		return {"error": "Already connected", "success": false}

	var target_code := invite_code.to_upper()
	if not start_discovery_for_code(target_code):
		return {"error": "Failed to start discovery - port may be in use. Try restarting the app.", "success": false}

	var attempts := 0
	var host_info := {}
	while attempts < 20:
		await get_tree().create_timer(0.5).timeout
		host_info = get_discovered_host(target_code)
		if not host_info.is_empty():
			break
		attempts += 1

	stop_discovery()

	if host_info.is_empty():
		return {
			"error": "Could not find game with code: " + target_code + "\n\nTroubleshooting:\n• Both devices on same Wi-Fi\n• Disable Windows Firewall\n• Try 'LOCAL' code for same-PC test",
			"success": false,
		}
	return await _connect_to_host(host_info.get("host_ip", ""), target_code)


func join_game_with_ip(host_ip: String, code: String = "") -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		return {"error": "Already connected", "success": false}
	return await _connect_to_host(host_ip, code)


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
		_discovery_targets[code] = {
			"ip": from_ip,
			"host_ip": data.get("host_ip", from_ip),
			"port": data.get("port", DEFAULT_PORT),
			"code": code,
			"host_name": data.get("host_name", "Unknown"),
			"last_seen": Time.get_unix_time_from_system(),
		}
		host_discovered.emit(_discovery_targets[code])


func _cleanup_old_discovery_targets() -> void:
	var current_time := Time.get_unix_time_from_system()
	var to_remove: Array = []
	for code in _discovery_targets:
		if current_time - _discovery_targets[code].get("last_seen", 0) > 30.0:
			to_remove.append(code)
	for code in to_remove:
		_discovery_targets.erase(code)


func stop_discovery() -> void:
	_is_discovering = false
	if _listen_socket:
		_listen_socket.close()
		_listen_socket = null
	discovery_stopped.emit()


func _connect_to_host(host_ip: String, code: String) -> Dictionary:
	_change_state(ConnectionState.CONNECTING)
	_multiplayer_peer = ENetMultiplayerPeer.new()
	var error := _multiplayer_peer.create_client(host_ip, DEFAULT_PORT)
	if error != OK:
		_change_state(ConnectionState.DISCONNECTED)
		return {"error": "Failed to create client: " + str(error), "success": false}

	multiplayer.multiplayer_peer = _multiplayer_peer
	_local_role = Role.SIDEKICK
	_invite_code = code
	GameState.assign_role(GameState.Role.SIDEKICK)

	var attempts := 0
	while attempts < 30:
		await get_tree().create_timer(0.1).timeout
		if _state == ConnectionState.CONNECTED or _state == ConnectionState.PLAYING:
			return {"success": true}
		if _state == ConnectionState.DISCONNECTED:
			return {"error": "Connection failed. Check:\n• Same Wi-Fi network\n• Firewall settings", "success": false}
		attempts += 1

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
	game_started.emit("forest_hub")
	return true


func disconnect_network() -> void:
	if _state == ConnectionState.DISCONNECTED:
		return
	_change_state(ConnectionState.DISCONNECTING)
	stop_discovery()
	if _broadcast_socket:
		_broadcast_socket.close()
		_broadcast_socket = null
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_cleanup()
	_change_state(ConnectionState.DISCONNECTED)


func disconnect_from_session() -> void:
	disconnect_network()


func report_position(peer_id: int, pos: Vector2) -> void:
	if _has_peers():
		GameState._report_position_to_host_rpc.rpc_id(1, peer_id, pos)


func _on_multiplayer_peer_connected(peer_id: int) -> void:
	player_connected.emit(peer_id)
	if _is_host:
		_partner_peer_id = peer_id
		_assign_role_rpc.rpc_id(peer_id, Role.SIDEKICK, _invite_code, _session_seed)
		partner_connected.emit({"player_id": str(peer_id), "display_name": "Sidekick", "role": "sidekick"})
		player_joined.emit(peer_id, Role.SIDEKICK)
		if _state == ConnectionState.PLAYING:
			_game_started_rpc.rpc_id(peer_id, "forest_hub")
	else:
		player_joined.emit(peer_id, Role.DETECTIVE)


func _on_multiplayer_peer_disconnected(peer_id: int) -> void:
	player_disconnected.emit(peer_id)
	if peer_id == _partner_peer_id:
		_partner_peer_id = 0
		partner_disconnected.emit({"player_id": str(peer_id), "reason": "disconnected"})
		game_paused.emit("partner_disconnected")
		player_left.emit(peer_id)
	if _is_host and _state == ConnectionState.PLAYING:
		_change_state(ConnectionState.HOSTING)


func _on_connected_to_server() -> void:
	_local_peer_id = multiplayer.get_unique_id()
	_change_state(ConnectionState.CONNECTED)


func _on_connection_failed() -> void:
	push_error("[NetworkManager] Connection failed")
	_change_state(ConnectionState.DISCONNECTED)
	connection_failed.emit("Failed to connect to host")
	_cleanup()


func _on_server_disconnected() -> void:
	partner_disconnected.emit({"reason": "host_disconnected"})
	game_paused.emit("host_disconnected")
	_change_state(ConnectionState.DISCONNECTED)
	_cleanup()


@rpc("authority", "reliable")
func _assign_role_rpc(role: Role, invite_code: String, session_seed: int) -> void:
	_local_role = role
	_session_seed = session_seed
	_invite_code = invite_code
	GameState.assign_role(GameState.Role.SIDEKICK)
	GameState.set_session_seed(_session_seed)
	connection_established.emit(_local_peer_id)
	role_assignment_received.emit(Role.SIDEKICK)


@rpc("authority", "reliable")
func _game_started_rpc(checkpoint: String) -> void:
	_change_state(ConnectionState.PLAYING)
	game_started.emit(checkpoint)
	session_started.emit({
		"checkpoint": checkpoint,
		"world_progress": _world_progress,
		"your_role": "sidekick",
		"partner": {"player_id": str(_partner_peer_id), "role": "detective"},
	})


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
func _rpc_request_spawn_player(peer_id: int, is_detective_role: bool) -> void:
	spawn_player_requested.emit(peer_id, is_detective_role)


@rpc("authority", "reliable")
func _rpc_request_despawn_player(peer_id: int) -> void:
	despawn_player_requested.emit(peer_id)


func request_spawn_player(target_peer: int, peer_id: int, is_detective: bool) -> void:
	_rpc_request_spawn_player.rpc_id(target_peer, peer_id, is_detective)


func request_despawn_player(peer_id: int) -> void:
	_rpc_request_despawn_player.rpc(peer_id)


func sync_costume_preview(role: String, costume_id: String) -> void:
	if _has_peers():
		_rpc_sync_costume_preview.rpc(role, costume_id)


func sync_costume_confirmed(role: String, costume_id: String) -> void:
	if _has_peers():
		_rpc_sync_costume_confirmed.rpc(role, costume_id)


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


func notify_host_leaving() -> void:
	if _has_peers():
		_rpc_notify_host_leaving.rpc()


@rpc("authority", "reliable")
func _rpc_notify_host_leaving() -> void:
	game_paused.emit("host_leaving")


func notify_sidekick_leaving() -> void:
	if _has_peers():
		_rpc_notify_sidekick_leaving.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_notify_sidekick_leaving() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == _partner_peer_id:
		_partner_peer_id = 0
		partner_disconnected.emit({"player_id": str(peer_id), "reason": "left"})


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


func _generate_invite_code() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	var _rng := hash(str(randi()) + str(Time.get_unix_time_from_system()))
	for i in range(6):
		_rng = (_rng * 9301 + 49297) % 233280
		code += chars[_rng % chars.length()]
	return code


func _get_host_ip() -> String:
	var ips := IP.get_local_addresses()
	for ip in ips:
		if ip.begins_with("192.168.") and "." in ip:
			return ip
	for ip in ips:
		if not ip.begins_with("127.") and "." in ip and not ip.begins_with("0."):
			return ip
	return "localhost"


func _get_device_name() -> String:
	var env := OS.get_environment("COMPUTERNAME")
	return env if not env.is_empty() else OS.get_name() + " Player"


func _cleanup() -> void:
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
