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

# Track if players are in "confirming" state (first click - showing "Cancel")
var _detective_confirming: bool = false
var _sidekick_confirming: bool = false

# Store individual player positions when they entered the portal area
var _detective_entry_position: Vector2 = Vector2.ZERO
var _sidekick_entry_position: Vector2 = Vector2.ZERO

# Reference to the enter button (set via inspector or found dynamically)
var _enter_button: Button = null

# Store the original button text
var _base_button_text: String = "Enter Zone"


func _ready() -> void:
	print("[ZonePortal] ", zone_name, " READY")
	
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	
	# Find the enter button (expected naming: "Enter[ZoneName]Button")
	_enter_button = _find_enter_button()
	if _enter_button:
		_base_button_text = _enter_button.text
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
	
	# Safety check - don't process if scene is changing or multiplayer not available
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	
	if multiplayer.is_server():
		if peer_id == 1:
			_detective_present = true
			_detective_peer_id = peer_id
			_detective_entry_position = body.global_position
		else:
			_sidekick_present = true
			_sidekick_peer_id = peer_id
			_sidekick_entry_position = body.global_position
		
		print("[ZonePortal] Server state: D=", _detective_present, " S=", _sidekick_present)
		_update_button_visibility()
	else:
		# Client reports to server with position
		_report_entered.rpc_id(1, peer_id, body.global_position)


func _on_body_exited(body: Node2D):
	if not body is CharacterBody2D:
		return
	
	var peer_id = int(body.name) if body.name.is_valid_int() else 0
	if peer_id <= 0:
		return
	
	print("[ZonePortal] ", zone_name, " EXITED: ", peer_id)
	
	# Safety check - don't process if scene is changing or multiplayer not available
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	
	if multiplayer.is_server():
		if peer_id == 1:
			_detective_present = false
			_detective_peer_id = 0
			_detective_ready = false  # Reset ready state when leaving
			_detective_entry_position = Vector2.ZERO  # Clear stored position
		else:
			_sidekick_present = false
			_sidekick_peer_id = 0
			_sidekick_ready = false  # Reset ready state when leaving
			_sidekick_entry_position = Vector2.ZERO  # Clear stored position
		
		_update_button_visibility()
	else:
		_report_exited.rpc_id(1, peer_id)


@rpc("any_peer", "reliable")
func _report_entered(peer_id: int, entry_position: Vector2 = Vector2.ZERO):
	if not is_inside_tree() or multiplayer == null:
		return
	if not multiplayer.is_server():
		return
	
	if peer_id == 1:
		_detective_present = true
		_detective_peer_id = peer_id
		_detective_entry_position = entry_position
	else:
		_sidekick_present = true
		_sidekick_peer_id = peer_id
		_sidekick_entry_position = entry_position
	
	print("[ZonePortal] Server got ENTER from ", peer_id, " at position ", entry_position, " -> D:", _detective_present, " S:", _sidekick_present)
	_update_button_visibility()
	
	# If both players are now present, update button text immediately
	if _detective_present and _sidekick_present:
		_update_button_text()


@rpc("any_peer", "reliable")
func _report_exited(peer_id: int):
	if not is_inside_tree() or multiplayer == null:
		return
	if not multiplayer.is_server():
		return
	
	if peer_id == 1:
		_detective_present = false
		_detective_peer_id = 0
		_detective_ready = false
		_detective_entry_position = Vector2.ZERO
	else:
		_sidekick_present = false
		_sidekick_peer_id = 0
		_sidekick_ready = false
		_sidekick_entry_position = Vector2.ZERO
	
	_update_button_visibility()


## Update button visibility - only visible when BOTH players are present
func _update_button_visibility():
	# Safety check - don't sync if scene is changing
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	
	var both_present = _detective_present and _sidekick_present
	
	# Update local button
	if _enter_button:
		_enter_button.visible = both_present
	
	# Reset all states if not both present
	if not both_present:
		_detective_ready = false
		_sidekick_ready = false
		_detective_confirming = false
		_sidekick_confirming = false
		_update_button_text()
	
	# Sync visibility to all clients
	_sync_button_visibility.rpc(both_present, _detective_ready, _sidekick_ready)
	
	print("[ZonePortal] ", zone_name, " button visible: ", both_present)


## Sync button visibility and ready state to all clients
@rpc("authority", "reliable")
func _sync_button_visibility(button_visible: bool, detective_ready: bool, sidekick_ready: bool):
	# Safety check - node might have been destroyed
	if not is_inside_tree():
		return
	
	# Update button visibility on client
	if _enter_button:
		_enter_button.visible = button_visible
	
	# On client, track presence based on visibility (both present = visible)
	if button_visible:
		_detective_present = true
		_sidekick_present = true
	else:
		_detective_present = false
		_sidekick_present = false
		# Reset confirming states when players leave
		_detective_confirming = false
		_sidekick_confirming = false
	
	# Update ready states
	_detective_ready = detective_ready
	_sidekick_ready = sidekick_ready
	
	# Update button text to show status
	_update_button_text()
	
	print("[ZonePortal] ", zone_name, " client synced - visible: ", button_visible, " ready D:", detective_ready, " S:", sidekick_ready)


## Called when the enter button is pressed
func _on_enter_button_pressed():
	# Safety check
	if not is_inside_tree() or multiplayer == null:
		return
	
	var my_peer_id = multiplayer.get_unique_id()
	
	if multiplayer.is_server():
		# Host (Detective) clicked
		if _detective_present:
			if _detective_confirming:
				# Second click - cancel
				_detective_confirming = false
				_detective_ready = false
				print("[ZonePortal] Detective cancelled entering ", zone_name)
			else:
				# First click - confirm
				_detective_confirming = true
				_detective_ready = true
				print("[ZonePortal] Detective is ready to enter ", zone_name)
				_check_and_enter()
			_sync_confirming_state.rpc(_detective_confirming, _sidekick_confirming)
			_update_button_text()
	else:
		# Client (Sidekick) clicked - notify server
		if _sidekick_confirming:
			# Second click - cancel
			_player_cancel_rpc.rpc_id(1, my_peer_id)
			_sidekick_confirming = false
			_sidekick_ready = false
		else:
			# First click - confirm
			_player_confirm_rpc.rpc_id(1, my_peer_id)
			_sidekick_confirming = true
			_sidekick_ready = true
		_update_button_text()


## Client notifies server that they confirmed (first click)
@rpc("any_peer", "reliable")
func _player_confirm_rpc(peer_id: int):
	if not is_inside_tree() or multiplayer == null:
		return
	if not multiplayer.is_server():
		return
	
	if peer_id == 1:
		_detective_confirming = true
		_detective_ready = true
	else:
		_sidekick_confirming = true
		_sidekick_ready = true
	
	print("[ZonePortal] Player ", peer_id, " confirmed entering ", zone_name)
	_update_button_text()
	_sync_confirming_state.rpc(_detective_confirming, _sidekick_confirming)
	_check_and_enter()


## Client notifies server that they cancelled (second click)
@rpc("any_peer", "reliable")
func _player_cancel_rpc(peer_id: int):
	if not is_inside_tree() or multiplayer == null:
		return
	if not multiplayer.is_server():
		return
	
	if peer_id == 1:
		_detective_confirming = false
		_detective_ready = false
	else:
		_sidekick_confirming = false
		_sidekick_ready = false
	
	print("[ZonePortal] Player ", peer_id, " cancelled entering ", zone_name)
	_update_button_text()
	_sync_confirming_state.rpc(_detective_confirming, _sidekick_confirming)


## Sync confirming state to all clients for UI updates
@rpc("authority", "reliable")
func _sync_confirming_state(detective_confirming: bool, sidekick_confirming: bool):
	if not is_inside_tree():
		return
	_detective_confirming = detective_confirming
	_sidekick_confirming = sidekick_confirming
	# Update ready states based on confirming states
	_detective_ready = detective_confirming
	_sidekick_ready = sidekick_confirming
	_update_button_text()


## Update button text to show ready status
func _update_button_text():
	if not _enter_button:
		return
	
	# Safety check for multiplayer
	if not is_inside_tree() or multiplayer == null:
		return
	
	var my_peer_id = multiplayer.get_unique_id()
	var is_detective = (my_peer_id == 1)
	
	# Only update text if both are present
	if not (_detective_present and _sidekick_present):
		_enter_button.text = _base_button_text
		return
	
	# Check if local player is confirming (show "Cancel")
	if is_detective:
		if _detective_confirming:
			_enter_button.text = "Cancel"
			return
	else:
		if _sidekick_confirming:
			_enter_button.text = "Cancel"
			return
	
	# Local player not confirming - show waiting message only if local player is ready
	if _detective_ready and _sidekick_ready:
		_enter_button.text = _base_button_text + " (Entering...)"
	elif is_detective and _detective_ready:
		# Detective is ready, waiting for sidekick
		_enter_button.text = _base_button_text + " (Waiting for Sidekick...)"
	elif not is_detective and _sidekick_ready:
		# Sidekick is ready, waiting for detective
		_enter_button.text = _base_button_text + " (Waiting for Detective...)"
	else:
		# Local player not ready, show default text
		_enter_button.text = _base_button_text


## Check if both players are ready and enter the zone
func _check_and_enter():
	# Safety check
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return
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
	# Safety check
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	
	# Clear any previously saved spawn positions before saving new ones
	# This ensures we're starting fresh and prevents stale position data
	if multiplayer.is_server():
		print("[ZonePortal] Clearing old positions before entering ", zone_name)
		GameState.clear_spawn_position(1)  # Clear detective
		for peer_id in multiplayer.get_peers():
			GameState.clear_spawn_position(peer_id)  # Clear all sidekicks
	
	# Capture positions BEFORE any RPC calls (they get cleared on scene change)
	var detective_pos = _detective_entry_position
	var sidekick_pos = _sidekick_entry_position
	var sidekick_pid = _sidekick_peer_id
	
	print("[ZonePortal] Captured positions for zone entry - Detective: ", detective_pos, " Sidekick: ", sidekick_pos)
	
	# Save positions immediately on server
	_save_positions_direct(detective_pos, sidekick_pos, sidekick_pid)
	
	# RPC with captured positions to ensure clients get correct data
	rpc_enter_zone_with_positions.rpc(scene_path, detective_pos, sidekick_pos, sidekick_pid)


## Save positions using captured values (not instance variables that may be cleared)
func _save_positions_direct(detective_pos: Vector2, sidekick_pos: Vector2, sidekick_pid: int):
	print("[ZonePortal] _save_positions_direct() called for zone: ", zone_name)
	print("[ZonePortal] Detective pos: ", detective_pos, " Sidekick pos: ", sidekick_pos, " sidekick_pid: ", sidekick_pid)
	
	# Save detective position
	if detective_pos != Vector2.ZERO:
		GameState.save_spawn_position(1, detective_pos, "forest_hub")
		print("[ZonePortal] ✓ Saved detective (peer 1) return position: ", detective_pos)
	else:
		# Fallback to ReturnMarker if position wasn't recorded
		var return_marker = get_node_or_null("ReturnMarker")
		var fallback_pos = return_marker.global_position if return_marker else global_position + Vector2(0, 100)
		GameState.save_spawn_position(1, fallback_pos, "forest_hub")
		push_warning("[ZonePortal] Detective entry position was ZERO, using fallback: " + str(fallback_pos))
	
	# Save sidekick position
	if sidekick_pid > 0:
		if sidekick_pos != Vector2.ZERO:
			GameState.save_spawn_position(sidekick_pid, sidekick_pos, "forest_hub")
			print("[ZonePortal] ✓ Saved sidekick (peer ", sidekick_pid, ") return position: ", sidekick_pos)
			
			# SYNC TO CLIENT: Send the sidekick's position to their client so they can save it locally
			# This ensures they spawn at the correct position when returning from the zone
			_sync_spawn_position_to_client.rpc_id(sidekick_pid, sidekick_pid, sidekick_pos, "forest_hub")
			print("[ZonePortal] → Synced sidekick position to client peer ", sidekick_pid)
		else:
			# Fallback to ReturnMarker
			var return_marker = get_node_or_null("ReturnMarker")
			var fallback_pos = return_marker.global_position if return_marker else global_position + Vector2(-50, 100)
			GameState.save_spawn_position(sidekick_pid, fallback_pos, "forest_hub")
			push_warning("[ZonePortal] Sidekick entry position was ZERO, using fallback: " + str(fallback_pos))
			
			# Still need to sync to client
			_sync_spawn_position_to_client.rpc_id(sidekick_pid, sidekick_pid, fallback_pos, "forest_hub")


# Legacy _save_positions() for backward compatibility
func _save_positions():
	_save_positions_direct(_detective_entry_position, _sidekick_entry_position, _sidekick_peer_id)


@rpc("any_peer", "reliable", "call_local")
func rpc_enter_zone(path: String):
	# Safety check - scene might already be changing
	if not is_inside_tree():
		return
	print("[ZonePortal] Changing scene to: ", path)
	get_tree().change_scene_to_file(path)


## RPC to enter zone with explicit positions (fixes position loss during scene change)
@rpc("authority", "reliable", "call_local")
func rpc_enter_zone_with_positions(path: String, detective_pos: Vector2, sidekick_pos: Vector2, sidekick_pid: int):
	print("[ZonePortal] rpc_enter_zone_with_positions called - path: ", path, " my_id=", multiplayer.get_unique_id())
	
	var my_id = multiplayer.get_unique_id()
	
	# Save positions on ALL clients BEFORE scene change
	# This ensures both players have their positions saved locally for when they return
	
	# Always save detective position on all clients
	if detective_pos != Vector2.ZERO:
		GameState.save_spawn_position(1, detective_pos, "forest_hub")
		print("[ZonePortal] Saved detective (peer 1) position: ", detective_pos)
	
	# Save sidekick position on all clients (each client saves their own if they're the sidekick)
	if sidekick_pid > 0 and sidekick_pos != Vector2.ZERO:
		GameState.save_spawn_position(sidekick_pid, sidekick_pos, "forest_hub")
		print("[ZonePortal] Saved sidekick (peer ", sidekick_pid, ") position: ", sidekick_pos, " my_id=", my_id)
	
	# Now change scene
	if is_inside_tree():
		print("[ZonePortal] Changing scene to: ", path)
		get_tree().change_scene_to_file(path)


## Sync spawn position from server to client
# This ensures the client has their return position saved locally for when they exit the zone
@rpc("authority", "reliable")
func _sync_spawn_position_to_client(peer_id: int, position: Vector2, zone: String):
	if not is_inside_tree():
		return
	
	# Only save if this is for us (safety check)
	if peer_id == multiplayer.get_unique_id():
		GameState.save_spawn_position(peer_id, position, zone)
		print("[ZonePortal] ← Client received spawn position sync: ", position, " for zone: ", zone)


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
