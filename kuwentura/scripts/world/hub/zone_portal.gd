extends Area2D

@export var zone_name : String
@export var scene_path : String

# Track which peers are on this portal (server authoritative)
var _detective_present: bool = false
var _sidekick_present: bool = false
var _detective_peer_id: int = 0
var _sidekick_peer_id: int = 0

func _ready() -> void:
	print("[ZonePortal] ", zone_name, " READY")
	
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)


func _on_body_entered(body: Node2D):
	if not body is CharacterBody2D:
		return
	
	var peer_id = int(body.name) if body.name.is_valid_int() else 0
	if peer_id <= 0:
		return
	
	print("[ZonePortal] ", zone_name, " ENTERED: ", peer_id)
	
	if multiplayer.is_server():
		if peer_id == 1:
			_detective_present = true
			_detective_peer_id = peer_id
		else:
			_sidekick_present = true
			_sidekick_peer_id = peer_id
		
		print("[ZonePortal] Server state: D=", _detective_present, " S=", _sidekick_present)
	else:
		# Client reports to server
		_report_entered.rpc_id(1, peer_id)


func _on_body_exited(body: Node2D):
	if not body is CharacterBody2D:
		return
	
	var peer_id = int(body.name) if body.name.is_valid_int() else 0
	if peer_id <= 0:
		return
	
	print("[ZonePortal] ", zone_name, " EXITED: ", peer_id)
	
	if multiplayer.is_server():
		if peer_id == 1:
			_detective_present = false
			_detective_peer_id = 0
		else:
			_sidekick_present = false
			_sidekick_peer_id = 0
	else:
		_report_exited.rpc_id(1, peer_id)


@rpc("any_peer", "reliable")
func _report_entered(peer_id: int):
	if not multiplayer.is_server():
		return
	
	if peer_id == 1:
		_detective_present = true
		_detective_peer_id = peer_id
	else:
		_sidekick_present = true
		_sidekick_peer_id = peer_id
	
	print("[ZonePortal] Server got ENTER from ", peer_id, " -> D:", _detective_present, " S:", _sidekick_present)


@rpc("any_peer", "reliable")
func _report_exited(peer_id: int):
	if not multiplayer.is_server():
		return
	
	if peer_id == 1:
		_detective_present = false
		_detective_peer_id = 0
	else:
		_sidekick_present = false
		_sidekick_peer_id = 0


# Call this to check if zone can be entered
func can_enter() -> bool:
	if multiplayer.is_server():
		return _detective_present and _sidekick_present
	return false


# Called by external systems to trigger zone entry
func try_enter() -> bool:
	if not multiplayer.is_server():
		print("[ZonePortal] Only server can initiate zone entry")
		return false
	
	if not (_detective_present and _sidekick_present):
		print("[ZonePortal] Cannot enter - need both players. D:", _detective_present, " S:", _sidekick_present)
		return false
	
	var zid := zone_name.strip_edges()
	if GameState.is_zone_locked_temp(zid):
		var rem: int = GameState.get_zone_lock_remaining(zid)
		print("[ZonePortal] DENIED:", zid, "locked. Remaining=", rem, "s")
		return false
	
	print("[ZonePortal] ENTERING ", zone_name)
	_save_positions()
	rpc_enter_zone.rpc(scene_path)
	return true


func _save_positions():
	var return_marker = get_node_or_null("ReturnMarker")
	var return_pos = return_marker.global_position if return_marker else global_position + Vector2(0, 100)
	
	if _detective_present:
		GameState.save_spawn_position(1, return_pos, "forest_hub")
	if _sidekick_present:
		GameState.save_spawn_position(_sidekick_peer_id, return_pos, "forest_hub")


@rpc("any_peer", "reliable", "call_local")
func rpc_enter_zone(path: String):
	get_tree().change_scene_to_file(path)
