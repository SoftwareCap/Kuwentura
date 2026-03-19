extends Node

## Network Manager Compatibility Wrapper
##
## This wrapper provides backward compatibility for code that uses the old
## NetworkManager API. It maps old function calls to the new NetworkManager.
##
## DEPRECATED: Update your code to use NetworkManager directly.
## This wrapper is temporary and will be removed in a future version.

# Re-export all signals from NetworkManager
signal connection_state_changed(new_state: int, old_state: int)
signal connection_established(peer_id: int)
signal connection_failed(error: String)
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal player_joined(peer_id: int, role: int)
signal player_left(peer_id: int)
signal partner_connected(player_data: Dictionary)
signal partner_disconnected(player_data: Dictionary)
signal session_started(world_data: Dictionary)
signal game_started(checkpoint: String)
signal game_paused(reason: String)
signal game_resumed()
signal host_discovered(host_info: Dictionary)
signal discovery_started()
signal discovery_stopped()
signal role_assignment_received(role: int)
signal room_code_generated(code: String)

# Re-export enums
enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	HOSTING,
	CONNECTED,
	PLAYING,
	DISCONNECTING
}

enum Role { NONE, DETECTIVE, SIDEKICK }

# Constants
const DEFAULT_PORT: int = 17777
const MAX_PLAYERS: int = 2

# Forward properties to NetworkManager
var enable_prediction: bool = true:
	get: return NetworkManager.enable_prediction if NetworkManager else true
	set(value): 
		if NetworkManager:
			NetworkManager.enable_prediction = value

var enable_interpolation: bool = true:
	get: return NetworkManager.enable_interpolation if NetworkManager else true
	set(value):
		if NetworkManager:
			NetworkManager.enable_interpolation = value


func _ready():
	print("[NetworkManagerCompat] Compatibility wrapper initialized")
	print("[NetworkManagerCompat] WARNING: Update code to use NetworkManager directly")
	
	# Connect to NetworkManager signals
	if NetworkManager:
		NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
		NetworkManager.connection_established.connect(_on_connection_established)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		NetworkManager.player_joined.connect(_on_player_joined)
		NetworkManager.player_left.connect(_on_player_left)
		NetworkManager.partner_connected.connect(_on_partner_connected)
		NetworkManager.partner_disconnected.connect(_on_partner_disconnected)
		NetworkManager.game_started.connect(_on_game_started)
		NetworkManager.game_paused.connect(_on_game_paused)
		NetworkManager.game_resumed.connect(_on_game_resumed)
		NetworkManager.host_info_updated.connect(_on_host_info_updated)
		NetworkManager.role_assignment_received.connect(_on_role_assignment_received)
		NetworkManager.discovery_started.connect(_on_discovery_started)
		NetworkManager.discovery_stopped.connect(_on_discovery_stopped)
		NetworkManager.host_discovered.connect(_on_host_discovered)
		NetworkManager.session_started.connect(_on_session_started)
		NetworkManager.spawn_player_requested.connect(_on_spawn_player_requested)
		NetworkManager.despawn_player_requested.connect(_on_despawn_player_requested)


# ============================================================================
# API FORWARDING
# ============================================================================

func is_host() -> bool:
	return NetworkManager.is_host() if NetworkManager else false


func is_playing() -> bool:
	return NetworkManager.is_playing() if NetworkManager else false


func get_state() -> int:
	return NetworkManager.get_state() if NetworkManager else ConnectionState.DISCONNECTED


func get_my_role() -> String:
	return NetworkManager.get_my_role() if NetworkManager else "none"


func get_invite_code() -> String:
	return NetworkManager.get_invite_code() if NetworkManager else ""


func get_room_code() -> String:
	return NetworkManager.get_room_code() if NetworkManager else ""


func has_active_connection() -> bool:
	return NetworkManager.has_active_connection() if NetworkManager else false


func is_network_connected() -> bool:
	return NetworkManager.is_network_connected() if NetworkManager else false


func is_partner_connected() -> bool:
	return NetworkManager.is_partner_connected() if NetworkManager else false


func get_partner_state(peer_id: int) -> Dictionary:
	return NetworkManager.get_partner_state(peer_id) if NetworkManager else {}


func clear_partner_state(peer_id: int) -> void:
	if NetworkManager:
		NetworkManager.clear_partner_state(peer_id)


func resume_game() -> bool:
	return NetworkManager.resume_game() if NetworkManager else false


# ============================================================================
# HOSTING / JOINING
# ============================================================================

func host_game() -> Dictionary:
	if NetworkManager:
		var result = await NetworkManager.host_game()
		if result.success:
			emit_signal("room_code_generated", result.get("invite_code", ""))
		return result
	return {"success": false, "error": "NetworkManager not available"}


func join_game_with_code(invite_code: String) -> Dictionary:
	# Forward to NetworkManager which now has working discovery
	if NetworkManager:
		return await NetworkManager.join_game_with_code(invite_code)
	return {"success": false, "error": "NetworkManager not available"}


func join_game_with_ip(host_ip: String, code: String = "") -> Dictionary:
	if NetworkManager:
		return await NetworkManager.join_with_ip(host_ip, code)
	return {"success": false, "error": "NetworkManager not available"}


# ============================================================================
# GAME SESSION
# ============================================================================

func start_game() -> bool:
	return NetworkManager.start_game() if NetworkManager else false


func disconnect_network():
	if NetworkManager:
		NetworkManager.disconnect_network()


func disconnect_from_session():
	disconnect_network()


# ============================================================================
# LEGACY DISCOVERY (DEPRECATED - NO-OP)
# ============================================================================

func start_discovery():
	push_warning("[NetworkManagerCompat] LAN discovery is deprecated. Use direct IP connection.")


func stop_discovery():
	if NetworkManager:
		NetworkManager.stop_discovery()


# ============================================================================
# SIGNAL FORWARDING
# ============================================================================

func _on_connection_state_changed(new_state, old_state):
	emit_signal("connection_state_changed", new_state, old_state)


func _on_connection_established(peer_id, role):
	emit_signal("connection_established", peer_id)
	emit_signal("role_assignment_received", role)


func _on_connection_failed(error):
	emit_signal("connection_failed", error)


func _on_player_connected(peer_id, role):
	emit_signal("player_connected", peer_id)


func _on_player_disconnected(peer_id):
	emit_signal("player_disconnected", peer_id)


func _on_player_joined(peer_id, role):
	emit_signal("player_joined", peer_id, role)


func _on_player_left(peer_id):
	emit_signal("player_left", peer_id)
	emit_signal("partner_disconnected", {"reason": "disconnected"})


func _on_partner_connected(player_data):
	emit_signal("partner_connected", player_data)


func _on_partner_disconnected(reason):
	emit_signal("partner_disconnected", {"reason": reason})
	emit_signal("game_paused", reason)


func _on_game_started(checkpoint):
	emit_signal("game_started", checkpoint)
	emit_signal("session_started", {
		"checkpoint": checkpoint,
		"world_progress": {},
		"your_role": get_my_role()
	})


func _on_game_paused(reason):
	emit_signal("game_paused", reason)


func _on_game_resumed():
	emit_signal("game_resumed")


func _on_host_info_updated(info):
	emit_signal("room_code_generated", info.get("code", ""))
	emit_signal("host_discovered", {
		"ip": info.get("host_ip", ""),
		"port": info.get("port", 17777),
		"code": info.get("invite_code", ""),
		"invite_code": info.get("invite_code", "")
	})


func _on_role_assignment_received(role):
	emit_signal("role_assignment_received", role)


func _on_discovery_started():
	emit_signal("discovery_started")


func _on_discovery_stopped():
	emit_signal("discovery_stopped")


func _on_host_discovered(host_info):
	emit_signal("host_discovered", host_info)


func _on_session_started(world_data):
	emit_signal("session_started", world_data)


func _on_spawn_player_requested(peer_id, is_detective):
	emit_signal("spawn_player_requested", peer_id, is_detective)


func _on_despawn_player_requested(peer_id):
	emit_signal("despawn_player_requested", peer_id)
