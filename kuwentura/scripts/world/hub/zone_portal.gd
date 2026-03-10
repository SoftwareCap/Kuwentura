extends Area2D

@export var zone_name : String
@export var scene_path : String

# Track which peers are on this portal (server authoritative)
var _detective_present: bool = false
var _sidekick_present: bool = false
var _detective_peer_id: int = 0
var _sidekick_peer_id: int = 0

# Track if players have clicked the enter button (ready to enter)
var _detective_ready: bool = false
var _sidekick_ready: bool = false

# Reference to the enter button (set via inspector or found dynamically)
var _enter_button: Button = null


func _ready() -> void:
	print("[ZonePortal] ", zone_name, " READY")
	
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	
	# Find the enter button (expected naming: "Enter[ZoneName]Button")
	_enter_button = _find_enter_button()
	if _enter_button:
		_enter_button.visible = false  # Start invisible
		_enter_button.pressed.connect(_on_enter_button_pressed)
		print("[ZonePortal] ", zone_name, " found button: ", _enter_button.name)
	else:
		push_warning("[ZonePortal] " + zone_name + " could not find enter button!")


## Find the enter button - looks for Button child or common naming patterns
func _find_enter_button() -> Button:
	# First, check for a Button child directly
	for child in get_children():
		if child is Button:
			return child
	
	# Second, try common naming pattern
	var button_name = "Enter" + zone_name.to_pascal_case() + "Button"
	var button = get_node_or_null(button_name)
	if button is Button:
		return button
	
	# Third, check parent for a button with zone reference
	var parent = get_parent()
	if parent:
		button = parent.get_node_or_null(button_name)
		if button is Button:
			return button
	
	return null


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
		_update_button_visibility()
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
			_detective_ready = false  # Reset ready state when leaving
		else:
			_sidekick_present = false
			_sidekick_peer_id = 0
			_sidekick_ready = false  # Reset ready state when leaving
		
		_update_button_visibility()
		_sync_ready_state.rpc(_detective_ready, _sidekick_ready)  # Sync reset state
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
	_update_button_visibility()
	
	# If both players are now present, update button text immediately
	if _detective_present and _sidekick_present:
		_update_button_text()


@rpc("any_peer", "reliable")
func _report_exited(peer_id: int):
	if not multiplayer.is_server():
		return
	
	if peer_id == 1:
		_detective_present = false
		_detective_peer_id = 0
		_detective_ready = false
	else:
		_sidekick_present = false
		_sidekick_peer_id = 0
		_sidekick_ready = false
	
	_update_button_visibility()


## Update button visibility - only visible when BOTH players are present
func _update_button_visibility():
	var both_present = _detective_present and _sidekick_present
	
	# Update local button
	if _enter_button:
		_enter_button.visible = both_present
	
	# Reset ready states if not both present
	if not both_present:
		_detective_ready = false
		_sidekick_ready = false
		_update_button_text()
	
	# Sync visibility to all clients
	_sync_button_visibility.rpc(both_present, _detective_ready, _sidekick_ready)
	
	print("[ZonePortal] ", zone_name, " button visible: ", both_present)


## Sync button visibility and ready state to all clients
@rpc("authority", "reliable")
func _sync_button_visibility(visible: bool, detective_ready: bool, sidekick_ready: bool):
	# Update button visibility on client
	if _enter_button:
		_enter_button.visible = visible
	
	# On client, track presence based on visibility (both present = visible)
	if visible:
		_detective_present = true
		_sidekick_present = true
	else:
		_detective_present = false
		_sidekick_present = false
	
	# Update ready states
	_detective_ready = detective_ready
	_sidekick_ready = sidekick_ready
	
	# Update button text to show status
	_update_button_text()
	
	print("[ZonePortal] ", zone_name, " client synced - visible: ", visible, " ready D:", detective_ready, " S:", sidekick_ready)


## Called when the enter button is pressed
func _on_enter_button_pressed():
	var my_peer_id = multiplayer.get_unique_id()
	
	if multiplayer.is_server():
		# Host (Detective) clicked
		if _detective_present:
			_detective_ready = true
			print("[ZonePortal] Detective is ready to enter ", zone_name)
			_check_and_enter()
			_sync_ready_state.rpc(_detective_ready, _sidekick_ready)
	else:
		# Client (Sidekick) clicked - notify server
		_player_ready_rpc.rpc_id(1, my_peer_id)
		# Update local UI immediately for responsiveness
		_sidekick_ready = true
		_update_button_text()


## Client notifies server that they clicked the button
@rpc("any_peer", "reliable")
func _player_ready_rpc(peer_id: int):
	if not multiplayer.is_server():
		return
	
	if peer_id == 1:
		_detective_ready = true
	else:
		_sidekick_ready = true
	
	print("[ZonePortal] Player ", peer_id, " is ready to enter ", zone_name)
	_update_button_text()
	_sync_ready_state.rpc(_detective_ready, _sidekick_ready)
	_check_and_enter()


## Sync ready state to all clients for UI updates
@rpc("authority", "reliable")
func _sync_ready_state(detective_ready: bool, sidekick_ready: bool):
	_detective_ready = detective_ready
	_sidekick_ready = sidekick_ready
	_update_button_text()


## Update button text to show ready status
func _update_button_text():
	if not _enter_button:
		return
	
	# Get original button text (strip any ready indicators)
	var base_text = _enter_button.text.replace(" ✓", "").split(" (")[0]
	
	# Only update text if both are present
	if not (_detective_present and _sidekick_present):
		_enter_button.text = base_text
		return
	
	if _detective_ready and _sidekick_ready:
		_enter_button.text = base_text + " (Entering...)"
	elif _detective_ready:
		_enter_button.text = base_text + " (Waiting for Sidekick...)"
	elif _sidekick_ready:
		_enter_button.text = base_text + " (Waiting for Detective...)"
	else:
		_enter_button.text = base_text


## Check if both players are ready and enter the zone
func _check_and_enter():
	if not multiplayer.is_server():
		return
	
	if not (_detective_ready and _sidekick_ready):
		print("[ZonePortal] Not ready yet. D:", _detective_ready, " S:", _sidekick_ready)
		return
	
	if not (_detective_present and _sidekick_present):
		print("[ZonePortal] Both players must be present to enter")
		return
	
	# Check if zone is locked
	var zid := zone_name.strip_edges()
	if GameState.is_zone_locked_temp(zid):
		var rem: int = GameState.get_zone_lock_remaining(zid)
		print("[ZonePortal] DENIED:", zid, " locked. Remaining=", rem, "s")
		return
	
	print("[ZonePortal] BOTH PLAYERS READY - ENTERING ", zone_name)
	_enter_zone()


## Perform the actual zone entry
func _enter_zone():
	_save_positions()
	rpc_enter_zone.rpc(scene_path)


func _save_positions():
	var return_marker = get_node_or_null("ReturnMarker")
	var return_pos = return_marker.global_position if return_marker else global_position + Vector2(0, 100)
	
	if _detective_present:
		GameState.save_spawn_position(1, return_pos, "forest_hub")
	if _sidekick_present:
		GameState.save_spawn_position(_sidekick_peer_id, return_pos, "forest_hub")


@rpc("any_peer", "reliable", "call_local")
func rpc_enter_zone(path: String):
	print("[ZonePortal] Changing scene to: ", path)
	get_tree().change_scene_to_file(path)


# Legacy methods for backward compatibility
func can_enter() -> bool:
	if multiplayer.is_server():
		return _detective_present and _sidekick_present
	return false


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
		print("[ZonePortal] DENIED:", zid, " locked. Remaining=", rem, "s")
		return false
	
	print("[ZonePortal] ENTERING ", zone_name)
	_save_positions()
	rpc_enter_zone.rpc(scene_path)
	return true
