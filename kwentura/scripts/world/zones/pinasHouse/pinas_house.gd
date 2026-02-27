extends Node2D

## Pina's House - Indoor zone with pause functionality + role-based note boards

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton

# Pause / settings UI (teammate)
@onready var inside_zone_control: CanvasLayer = $InsideZoneControl
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeValue

# Role overlays + boards (you)
@onready var detective_overlays: Node = $RoleLayer/Control/DetectiveOverlays
@onready var sidekick_overlays: Node = $RoleLayer/Control/SidekickOverlays

@onready var detective_board: Control = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective
@onready var sidekick_board: Control = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick

@onready var detective_text: Label = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/DetectiveText

@onready var detective_close: Button = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/Close
@onready var sidekick_close: Button = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick/SidekickNote/Close

@onready var note_btn: TextureButton = $RoleLayer/Control/NoteTapButton

# Flag to track if clue was collected (for auto-return)
var clue_collected: bool = false


func _ready() -> void:
	print("[PinasHouse] Scene loaded!")

	# Teammate: Play Pina's House background music
	if Engine.has_singleton("MusicController") or MusicController:
		MusicController.play_track(MusicController.MusicTrack.PINAS_HOUSE)

	# Show saved position info (teammate)
	var saved_pos = GameState.get_spawn_position(multiplayer.get_unique_id())
	if saved_pos != Vector2.ZERO:
		print("[PinasHouse] Will return to Forest Hub at position: ", saved_pos)

	# Signals: clue + role assigned (merge-safe guarded connections)
	if not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)
	if not GameState.player_role_assigned.is_connected(_on_role_assigned):
		GameState.player_role_assigned.connect(_on_role_assigned)

	# Teammate: Setup pause functionality
	_setup_pause_controls()

	# You: role label + overlays
	_update_role_label()
	update_role_visibility()

	# You: hide boards by default
	if is_instance_valid(detective_board):
		detective_board.visible = false
	if is_instance_valid(sidekick_board):
		sidekick_board.visible = false

	# You: connect close buttons (guarded)
	if is_instance_valid(detective_close) and not detective_close.pressed.is_connected(_close_boards):
		detective_close.pressed.connect(_close_boards)
	if is_instance_valid(sidekick_close) and not sidekick_close.pressed.is_connected(_close_boards):
		sidekick_close.pressed.connect(_close_boards)

	# Back button (guarded)
	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	# Note tap opens board (guarded)
	if is_instance_valid(note_btn) and not note_btn.pressed.is_connected(_on_note_pressed):
		note_btn.pressed.connect(_on_note_pressed)

	# Listen for sidekick solving
	if is_instance_valid(sidekick_board) and sidekick_board.has_signal("solved"):
		if not sidekick_board.solved.is_connected(_on_sidekick_solved):
			sidekick_board.solved.connect(_on_sidekick_solved)

	# Prepare detective text on load (equations view)
	if GameState.is_puzzle_solved("pinas_house"):
		_apply_solved_text()
		if is_instance_valid(sidekick_board) and sidekick_board.has_method("apply_solved_view"):
			sidekick_board.apply_solved_view()
	else:
		_apply_unsolved_text()


func _setup_pause_controls():
	# Connect inside zone control pause button
	if inside_zone_control:
		if inside_zone_control.has_signal("pause_pressed"):
			if not inside_zone_control.pause_pressed.is_connected(_on_pause_button_pressed):
				inside_zone_control.pause_pressed.connect(_on_pause_button_pressed)

	# Initialize pause panel
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
		if option_sub_panel:
			option_sub_panel.visible = false
		# Set initial volume slider value
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


## Open the pause panel
func _on_pause_button_pressed() -> void:
	print("[PinasHouse] Pause button pressed")
	if in_game_pause_panel:
		in_game_pause_panel.visible = true
		if option_sub_panel:
			option_sub_panel.visible = false
	get_tree().paused = true


## Resume button pressed
func _on_resume_play_button_pressed() -> void:
	print("[PinasHouse] Resume button pressed")
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
	if option_sub_panel:
		option_sub_panel.visible = false
	get_tree().paused = false


## Option button pressed
func _on_option_button_pressed() -> void:
	print("[PinasHouse] Option button pressed")
	if option_sub_panel:
		option_sub_panel.visible = true
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


## Back button from options
func _on_in_game_option_back_pressed() -> void:
	print("[PinasHouse] Back from options")
	if option_sub_panel:
		option_sub_panel.visible = false


## Exit to Main Menu
func _on_exit_to_main_menu_button_pressed() -> void:
	print("[PinasHouse] Exit to main menu")
	get_tree().paused = false

	# Disconnect from network
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout

	# Save settings
	_save_settings()

	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


## Volume changed
func _on_in_game_volume_changed(value: float) -> void:
	var volume = value / 100.0
	MusicController.set_volume(volume)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"


func _save_settings() -> void:
	const OPTION_FILE = "user://settings.json"
	var data = {
		"volume": MusicController.get_volume()
	}

	var file = FileAccess.open(OPTION_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _exit_tree():
	# Cleanup signal connections
	if inside_zone_control and inside_zone_control.has_signal("pause_pressed"):
		if inside_zone_control.pause_pressed.is_connected(_on_pause_button_pressed):
			inside_zone_control.pause_pressed.disconnect(_on_pause_button_pressed)


func _on_note_pressed() -> void:
	_on_note_interacted()


func _on_note_interacted() -> void:
	# Close both first
	_close_boards()

	if GameState.local_role == GameState.Role.DETECTIVE:
		detective_board.visible = true
		if GameState.is_puzzle_solved("pinas_house"):
			_apply_solved_text()
		else:
			_apply_unsolved_text()
	elif GameState.local_role == GameState.Role.SIDEKICK:
		sidekick_board.visible = true
		if sidekick_board.has_method("open_board"):
			sidekick_board.open_board()


func _close_boards() -> void:
	if is_instance_valid(detective_board):
		detective_board.visible = false
	if is_instance_valid(sidekick_board):
		sidekick_board.visible = false


func _apply_unsolved_text() -> void:
	var p := PuzzleManager.get_puzzle_for_zone("pinas_house")
	var eqs: Array = p.get("equations", [])
	var txt := "Cooking Tools Inventory\n\n"
	for e in eqs:
		txt += str(e) + "\n"

	if is_instance_valid(detective_text):
		detective_text.text = txt


func _apply_solved_text() -> void:
	var p := PuzzleManager.get_puzzle_for_zone("pinas_house")
	var sol: Dictionary = p.get("solution", {})

	var x := int(sol.get("x", 0))
	var y := int(sol.get("y", 0))
	var z := int(sol.get("z", 0))

	if is_instance_valid(detective_text):
		detective_text.text = (
			"Cooking Tools Inventory \n\n"
			+ "Pot (z) = %d\nPan (y) = %d\nLadle (x) = %d" % [z, y, x]
		)


func _on_sidekick_solved() -> void:
	# Sidekick got it correct → update both peers immediately
	rpc_pinas_house_solved.rpc()

	# Also ensure clue collection happens
	if multiplayer.is_server():
		GameState.collect_clue("pinas_house")
	else:
		NetworkManager.trigger_clue_collection.rpc("pinas_house", {})


@rpc("any_peer", "reliable", "call_local")
func rpc_pinas_house_solved() -> void:
	GameState.set_puzzle_solved("pinas_house", true)
	_apply_solved_text()

	# Sidekick board needs to show the solved values on reopen too
	if is_instance_valid(sidekick_board) and sidekick_board.has_method("apply_solved_view"):
		sidekick_board.apply_solved_view()


func update_role_visibility() -> void:
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			detective_overlays.visible = true
			sidekick_overlays.visible = false
		GameState.Role.SIDEKICK:
			detective_overlays.visible = false
			sidekick_overlays.visible = true
		_:
			detective_overlays.visible = false
			sidekick_overlays.visible = false


func _on_role_assigned(_role) -> void:
	GameState.local_role = _role
	update_role_visibility()
	_update_role_label()


func _update_role_label() -> void:
	var role_text := "Unknown"
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"

	role_label.text = "Role: " + role_text
	print("[PinasHouse] Local role: ", role_text, " | Peer ID: ", multiplayer.get_unique_id())


func _on_back_pressed() -> void:
	print("[PinasHouse] Returning to Forest Hub...")
	_return_to_forest()


func _on_clue_collected(zone_id: String, _clue_data: Dictionary) -> void:
	if zone_id == "pinas_house" and not clue_collected:
		clue_collected = true
		print("[PinasHouse] Clue collected! Auto-returning in 3s...")

		# Update UI to show returning
		role_label.text = "Clue collected! Returning..."

		await get_tree().create_timer(3.0).timeout
		_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
