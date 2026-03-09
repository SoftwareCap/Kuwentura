extends Area2D

signal both_players_entered(zone_name: String)
signal both_players_exited(zone_name: String)
signal player_entered_portal(zone_name: String, is_detective: bool)
signal player_exited_portal(zone_name: String, is_detective: bool)

@export var zone_name : String
@export var scene_path : String
var is_player_on_door : bool = false
var is_sidekick_on_door: bool = false

# Track which bodies are on the portal
var player_body: Node2D = null
var sidekick_body: Node2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add to zone_portals group for easy discovery
	add_to_group("zone_portals")
	
	connect("body_entered", detect_player)
	connect("body_exited", detect_player_out)
	
	# Connect enter button if it exists
	_connect_enter_button()
	
	print("[ZonePortal] Ready: ", zone_name, " at ", global_position)

func _connect_enter_button() -> void:
	"""Find and connect the enter button if it exists."""
	var enter_button = _find_enter_button()
	if enter_button:
		enter_button.visible = false  # Hide by default
		# Use call_deferred to ensure button is ready
		call_deferred("_deferred_connect_button", enter_button)
	else:
		print("[ZonePortal] No enter button found for ", zone_name)


func _deferred_connect_button(enter_button: Button) -> void:
	"""Connect button signal after scene is fully loaded."""
	if not enter_button.pressed.is_connected(_on_enter_button_pressed):
		enter_button.pressed.connect(_on_enter_button_pressed)
		print("[ZonePortal] Connected enter button for ", zone_name)


func _find_enter_button() -> Button:
	"""Find the enter button as a child of this portal."""
	for child in get_children():
		if child is Button and child.name.begins_with("Enter"):
			return child
		# Also check for TouchScreenButton
		if child is TouchScreenButton and child.name.begins_with("Enter"):
			return child
	return null


func _on_enter_button_pressed() -> void:
	"""Handle enter button press."""
	print("[ZonePortal] Enter button pressed for ", zone_name)
	change_scene()


func _update_enter_button_visibility() -> void:
	"""Show/hide enter button based on player presence."""
	var enter_button = _find_enter_button()
	if enter_button:
		enter_button.visible = is_player_on_door and is_sidekick_on_door
		if enter_button.visible:
			print("[ZonePortal] Enter button VISIBLE for ", zone_name)
		else:
			print("[ZonePortal] Enter button HIDDEN for ", zone_name)


func detect_player(body: Node2D):
	print("[ZonePortal] Body entered: ", body.name, " (", body.get_class(), ")")
	
	# Detective is peer 1, Sidekick is the other peer
	var body_peer_id = int(body.name) if body.name.is_valid_int() else 0
	
	if body_peer_id == 1:
		is_player_on_door = true
		player_body = body
		print("[ZonePortal] ", zone_name, " - Player (Detective) entered")
		player_entered_portal.emit(zone_name, true)
	elif body_peer_id > 1:
		is_sidekick_on_door = true
		sidekick_body = body
		print("[ZonePortal] ", zone_name, " - Sidekick entered")
		player_entered_portal.emit(zone_name, false)
	
	print("[ZonePortal] Status - Player: ", is_player_on_door, ", Sidekick: ", is_sidekick_on_door)
	
	# Check if both players are now in this zone
	if is_player_on_door and is_sidekick_on_door:
		print("[ZonePortal] Both players in ", zone_name, "! Emitting both_players_entered")
		both_players_entered.emit(zone_name)
	
	# Update enter button visibility
	_update_enter_button_visibility()

func detect_player_out(body: Node2D):
	print("[ZonePortal] Body exited: ", body.name)
	
	var body_peer_id = int(body.name) if body.name.is_valid_int() else 0
	
	var was_both_in = is_player_on_door and is_sidekick_on_door
	
	if body_peer_id == 1:
		is_player_on_door = false
		player_body = null
		print("[ZonePortal] ", zone_name, " - Player (Detective) exited")
		player_exited_portal.emit(zone_name, true)
	elif body_peer_id > 1:
		is_sidekick_on_door = false
		sidekick_body = null
		print("[ZonePortal] ", zone_name, " - Sidekick exited")
		player_exited_portal.emit(zone_name, false)
	
	print("[ZonePortal] Status - Player: ", is_player_on_door, ", Sidekick: ", is_sidekick_on_door)
	
	# If both were in but now one exited, emit both_players_exited
	if was_both_in and not (is_player_on_door and is_sidekick_on_door):
		print("[ZonePortal] Both players no longer in ", zone_name, "! Emitting both_players_exited")
		both_players_exited.emit(zone_name)
	
	# Update enter button visibility
	_update_enter_button_visibility()

func _input(_event: InputEvent) -> void:
	# Jump no longer triggers zone entry - use Enter button instead
	pass


## Called by ForestHub when enter button is pressed
func on_enter_pressed() -> void:
	print("[ZonePortal] Enter pressed on ", zone_name, " - Player: ", is_player_on_door, ", Sidekick: ", is_sidekick_on_door)
	change_scene()

func change_scene() -> void:
	# Server-authoritative entry
	_try_enter_zone()

	# If client presses jump, do nothing except request (optional)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		print("[ZonePortal] Client pressed enter; waiting for server decision.")

func _save_and_sync_positions():
	"""Save all player positions and sync between clients."""
	var local_peer_id = multiplayer.get_unique_id()
	
	print("[ZonePortal] Saving positions - local peer: ", local_peer_id)
	
	# Host (Detective) collects and broadcasts positions
	if multiplayer.is_server():
		# Get detective position
		if player_body:
			GameState.save_spawn_position(1, player_body.global_position, "forest_hub")
			GameState._broadcast_position_rpc.rpc(1, player_body.global_position)
			print("[ZonePortal] Host saved detective position: ", player_body.global_position)
		
		# Get sidekick position if available locally
		if sidekick_body:
			var sidekick_id = int(sidekick_body.name)
			GameState.save_spawn_position(sidekick_id, sidekick_body.global_position, "forest_hub")
			GameState._broadcast_position_rpc.rpc(sidekick_id, sidekick_body.global_position)
			print("[ZonePortal] Host saved sidekick position: ", sidekick_body.global_position)
	else:
		# Client reports their position to host
		if sidekick_body and local_peer_id != 1:
			GameState._report_position_to_host_rpc.rpc_id(1, local_peer_id, sidekick_body.global_position)
			GameState.save_spawn_position(local_peer_id, sidekick_body.global_position, "forest_hub")
			print("[ZonePortal] Client reported position: ", sidekick_body.global_position)

func _try_enter_zone() -> void:
	# Need both players on the door
	if not (is_player_on_door and is_sidekick_on_door):
		print("[ZonePortal] bawal - Need both players. Player:", is_player_on_door, " Sidekick:", is_sidekick_on_door)
		return

	# Only server decides (offline allowed)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		print("[ZonePortal] Client pressed jump; server must approve.")
		return

	var zid := zone_name.strip_edges()

	if GameState.is_zone_locked_temp(zid):
		var rem: int = GameState.get_zone_lock_remaining(zid)
		print("[ZonePortal] DENIED:", zid, "locked. Remaining=", rem, "s")
		return

	print("[ZonePortal] ALLOWED: entering ", zid, " -> ", scene_path)

	_save_and_sync_positions()
	rpc_enter_zone.rpc(scene_path)


@rpc("any_peer", "reliable", "call_local")
func rpc_enter_zone(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _zone_id() -> String:
	return zone_name.strip_edges()
