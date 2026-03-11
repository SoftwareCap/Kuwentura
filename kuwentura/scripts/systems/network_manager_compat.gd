extends Node

## Network Manager Compatibility Wrapper
##
## This wrapper provides backward compatibility for code that uses the old
## NetworkManager API. It maps old function calls to the new OfflineNetworkManager.
##
## DEPRECATED: Update your code to use OfflineNetworkManager directly.
## This wrapper is temporary and will be removed in a future version.

# Re-export all signals from OfflineNetworkManager
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
signal game_resumed
signal host_discovered(host_info: Dictionary)
signal discovery_started
signal discovery_stopped
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

# Forward properties to OfflineNetworkManager
var enable_prediction: bool = true:
	get: return OfflineNetworkManager.enable_prediction if OfflineNetworkManager else true
	set(value): 
		if OfflineNetworkManager:
			OfflineNetworkManager.enable_prediction = value

var enable_interpolation: bool = true:
	get: return OfflineNetworkManager.enable_interpolation if OfflineNetworkManager else true
	set(value):
		if OfflineNetworkManager:
			OfflineNetworkManager.enable_interpolation = value


func _ready():
	print("[NetworkManagerCompat] Compatibility wrapper initialized")
	print("[NetworkManagerCompat] WARNING: Update code to use OfflineNetworkManager directly")
	
	# Connect to OfflineNetworkManager signals
	if OfflineNetworkManager:
		OfflineNetworkManager.connection_state_changed.connect(_on_connection_state_changed)
		OfflineNetworkManager.connection_established.connect(_on_connection_established)
		OfflineNetworkManager.connection_failed.connect(_on_connection_failed)
		OfflineNetworkManager.player_connected.connect(_on_player_connected)
		OfflineNetworkManager.player_disconnected.connect(_on_player_disconnected)
		OfflineNetworkManager.player_joined.connect(_on_player_joined)
		OfflineNetworkManager.player_left.connect(_on_player_left)
		OfflineNetworkManager.partner_connected.connect(_on_partner_connected)
		OfflineNetworkManager.partner_disconnected.connect(_on_partner_disconnected)
		OfflineNetworkManager.game_started.connect(_on_game_started)
		OfflineNetworkManager.game_paused.connect(_on_game_paused)
		OfflineNetworkManager.game_resumed.connect(_on_game_resumed)
		OfflineNetworkManager.host_info_updated.connect(_on_host_info_updated)
		OfflineNetworkManager.role_assignment_received.connect(_on_role_assignment_received)
		OfflineNetworkManager.discovery_started.connect(_on_discovery_started)
		OfflineNetworkManager.discovery_stopped.connect(_on_discovery_stopped)
		OfflineNetworkManager.host_discovered.connect(_on_host_discovered)
		OfflineNetworkManager.session_started.connect(_on_session_started)
		OfflineNetworkManager.spawn_player_requested.connect(_on_spawn_player_requested)
		OfflineNetworkManager.despawn_player_requested.connect(_on_despawn_player_requested)


# ============================================================================
# API FORWARDING
# ============================================================================

func is_host() -> bool:
	return OfflineNetworkManager.is_host() if OfflineNetworkManager else false


func is_playing() -> bool:
	return OfflineNetworkManager.is_playing() if OfflineNetworkManager else false


func get_state() -> int:
	return OfflineNetworkManager.get_state() if OfflineNetworkManager else ConnectionState.DISCONNECTED


func get_my_role() -> String:
	return OfflineNetworkManager.get_my_role() if OfflineNetworkManager else "none"


func get_invite_code() -> String:
	return OfflineNetworkManager.get_invite_code() if OfflineNetworkManager else ""


func get_room_code() -> String:
	return OfflineNetworkManager.get_room_code() if OfflineNetworkManager else ""


func has_active_connection() -> bool:
	return OfflineNetworkManager.has_active_connection() if OfflineNetworkManager else false


func is_network_connected() -> bool:
	return OfflineNetworkManager.is_network_connected() if OfflineNetworkManager else false


func is_partner_connected() -> bool:
	return OfflineNetworkManager.is_partner_connected() if OfflineNetworkManager else false


func get_partner_state(peer_id: int) -> Dictionary:
	return OfflineNetworkManager.get_partner_state(peer_id) if OfflineNetworkManager else {}


func resume_game() -> bool:
	return OfflineNetworkManager.resume_game() if OfflineNetworkManager else false


# ============================================================================
# HOSTING / JOINING
# ============================================================================

func host_game() -> Dictionary:
	if OfflineNetworkManager:
		var result = await OfflineNetworkManager.host_game()
		if result.success:
			emit_signal("room_code_generated", result.get("invite_code", ""))
		return result
	return {"success": false, "error": "OfflineNetworkManager not available"}


func join_game_with_code(invite_code: String) -> Dictionary:
	# Forward to OfflineNetworkManager which now has working discovery
	if OfflineNetworkManager:
		return await OfflineNetworkManager.join_game_with_code(invite_code)
	return {"success": false, "error": "OfflineNetworkManager not available"}


func join_game_with_ip(host_ip: String, code: String = "") -> Dictionary:
	if OfflineNetworkManager:
		return await OfflineNetworkManager.join_with_ip(host_ip, code)
	return {"success": false, "error": "OfflineNetworkManager not available"}


# ============================================================================
# GAME SESSION
# ============================================================================

func start_game() -> bool:
	return OfflineNetworkManager.start_game() if OfflineNetworkManager else false


func disconnect_network():
	if OfflineNetworkManager:
		OfflineNetworkManager.disconnect_network()


func disconnect_from_session():
	disconnect_network()


# ============================================================================
# LEGACY DISCOVERY (DEPRECATED - NO-OP)
# ============================================================================

func start_discovery():
	push_warning("[NetworkManagerCompat] LAN discovery is deprecated. Use direct IP connection.")


func stop_discovery():
	if OfflineNetworkManager:
		OfflineNetworkManager.stop_discovery()


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
