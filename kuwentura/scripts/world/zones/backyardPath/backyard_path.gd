extends Node2D

## Backyard Path - Test zone with position save/restore

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton

var clue_collected: bool = false

@onready var pina_spirit = $RoleLayer/Control/DetectiveOverlays/Pina
@onready var pineapple = $RoleLayer/Control/SidekickOverlays/PineapplePlant

@onready var input_field = $PuzzleBoard/LineEdit
@onready var submit_button = $PuzzleBoard/SubmitButton
@onready var feedback = $PuzzleBoard/FeedbackLabel

@onready var fog = $FogOverlay

# Pause UI references
@onready var inside_zone_control: CanvasLayer = $InsideZoneControl
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var pause_overlay: ColorRect = $PauseCanvasLayer/PauseOverlay
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue

var max_time = 300
var remaining_time = 300

var darkness = 0.0

var puzzle_data : Dictionary
var solution : int

func _ready():
	print("[BackyardPath] Scene loaded!")
	
	puzzle_data = PuzzleManager.get_puzzle("backyard_path")
	
	start_timer()

	solution = puzzle_data["solution"]

	var spirit_height = puzzle_data["spirit_height"]
	var plant_dali = puzzle_data["plant_dali"]

	$PuzzleBoard/HeightLabel.text = str(plant_dali) + " Dali"
	
	var role_text = "Unknown"
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"
	
	role_label.text = "Role: " + role_text
	print("[BackyardPath] Local role: ", role_text, " | Peer ID: ", multiplayer.get_unique_id())
	
	if GameState.local_role == GameState.Role.DETECTIVE:
		input_field.editable = false
		submit_button.disabled = true
	
	var saved_pos = GameState.get_spawn_position(multiplayer.get_unique_id())
	if saved_pos != Vector2.ZERO:
		print("[BackyardPath] Will return to Forest Hub at position: ", saved_pos)
	
	GameState.clue_collected.connect(_on_clue_collected)
	
	# Setup pause system
	_setup_pause_system()

func setup_role_visibility():

	match GameState.local_role:

		GameState.Role.DETECTIVE:
			pina_spirit.visible = true
			pineapple.visible = false

		GameState.Role.SIDEKICK:
			pina_spirit.visible = false
			pineapple.visible = true


func _on_back_pressed():
	print("[BackyardPath] Returning to Forest Hub...")
	_return_to_forest()


func _on_clue_collected(zone_id: String, _clue_data: Dictionary):
	if zone_id == "backyard_path" and not clue_collected:
		clue_collected = true
		print("[BackyardPath] Clue collected! Auto-returning in 3 seconds...")
		role_label.text = "Clue collected! Returning..."
		await get_tree().create_timer(3.0).timeout
		_return_to_forest()

func _on_submit_pressed():

	var answer = input_field.text.strip_edges()

	if not answer.is_valid_int():
		DialogueSystems.play("backyard_invalid",
		[
			{"speaker":"detective","text":"Answers should only be in numbers."},
			{"speaker":"detective","text":"Let's try again."}
		])
		apply_wrong_penalty()
		return

	var value = int(answer)

	if value == solution:
		solve_puzzle()

	else:
		feedback.text = "Incorrect!"
		apply_wrong_penalty()

func solve_puzzle():

	print("Puzzle solved!")

	GameState.mark_puzzle_solved("backyard_path")

	GameState.emit_clue_collected(
		"backyard_path",
		{
			"name":"Pina's Fate",
			"description":"Pina has become the pineapple plant."
		}
	)

func start_timer():

	while remaining_time > 0:

		await get_tree().create_timer(1.0).timeout

		remaining_time -= 1

		var progress = 1.0 - float(remaining_time) / float(max_time)

		fog.modulate.a = progress * 0.7

	if remaining_time <= 0:
		kick_player_out()
		
func apply_wrong_penalty():

	darkness += 0.1
	remaining_time -= 30

	if darkness > 1.0:
		darkness = 1.0

	fog.modulate.a = darkness
	
func kick_player_out():

	print("Players took too long. Tikbalang fog consumed the area.")

	DialogueSystems.play("fog_fail",
	[
		{"speaker":"narrator","text":"The fog grows too thick..."},
		{"speaker":"narrator","text":"You can no longer see anything."}
	])

	await get_tree().create_timer(3).timeout

	_return_to_forest()

func _on_board_path_button_pressed():
	$PuzzleBoard.visible = true

func _return_to_forest():
	print("[BackyardPath] Teleporting back to Forest Hub")
	# Ensure pause is fully reset before leaving
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


# ============================================================================
# PAUSE SYSTEM
# ============================================================================

func _setup_pause_system() -> void:
	"""Initialize pause panel and connect signals."""
	# Connect to InsideZoneControl pause signal
	if inside_zone_control and inside_zone_control.has_signal("pause_pressed"):
		if not inside_zone_control.pause_pressed.is_connected(_on_pause_button_pressed):
			inside_zone_control.pause_pressed.connect(_on_pause_button_pressed)
	
	# Initialize pause UI visibility
	if pause_overlay:
		pause_overlay.visible = false
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
	if option_sub_panel:
		option_sub_panel.visible = false
	
	# Set initial volume slider value
	if volume_slider:
		volume_slider.value = MusicController.get_volume() * 100
		if not volume_slider.value_changed.is_connected(_on_in_game_volume_changed):
			volume_slider.value_changed.connect(_on_in_game_volume_changed)
	
	if volume_value_label:
		volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"
	
	# Ensure pause UI can process while game is paused
	if pause_canvas_layer:
		pause_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_overlay:
		pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if in_game_pause_panel:
		in_game_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	if option_sub_panel:
		option_sub_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect pause panel buttons
	_connect_pause_buttons()


func _connect_pause_buttons() -> void:
	# Connect Resume button
	var resume_button = get_node_or_null("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton")
	if is_instance_valid(resume_button):
		if not resume_button.pressed.is_connected(_on_resume_play_button_pressed):
			resume_button.pressed.connect(_on_resume_play_button_pressed)
	
	# Connect Option button
	var option_button = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionButton")
	if is_instance_valid(option_button):
		if not option_button.pressed.is_connected(_on_option_button_pressed):
			option_button.pressed.connect(_on_option_button_pressed)
	
	# Connect Exit button
	var exit_button = get_node_or_null("PauseCanvasLayer/InGamePausePanel/ExitButton")
	if is_instance_valid(exit_button):
		if not exit_button.pressed.is_connected(_on_exit_to_main_menu_button_pressed):
			exit_button.pressed.connect(_on_exit_to_main_menu_button_pressed)
	
	# Connect Back button (from options sub-panel)
	var back_button_node = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/BackToPrevious")
	if is_instance_valid(back_button_node):
		if not back_button_node.pressed.is_connected(_on_in_game_option_back_pressed):
			back_button_node.pressed.connect(_on_in_game_option_back_pressed)


func _on_pause_button_pressed() -> void:
	print("[BackyardPath] Pause button pressed")
	
	if pause_overlay:
		pause_overlay.visible = true
	if in_game_pause_panel:
		in_game_pause_panel.visible = true
	if option_sub_panel:
		option_sub_panel.visible = false
	
	# Hide the pause button while paused
	if inside_zone_control:
		inside_zone_control.visible = false
	
	# Pause the background music
	MusicController.pause_music()
	
	# Pause the game
	get_tree().paused = true


func _on_resume_play_button_pressed() -> void:
	print("[BackyardPath] Resume button pressed")
	
	if pause_overlay:
		pause_overlay.visible = false
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
	if option_sub_panel:
		option_sub_panel.visible = false
	
	get_tree().paused = false
	
	# Show the pause button again
	if inside_zone_control:
		inside_zone_control.visible = true
	
	# Resume the background music
	MusicController.resume_music()


func _on_option_button_pressed() -> void:
	print("[BackyardPath] Option button pressed")
	
	if option_sub_panel:
		option_sub_panel.visible = true
	
	if volume_slider:
		volume_slider.value = MusicController.get_volume() * 100
	
	if volume_value_label:
		volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


func _on_in_game_option_back_pressed() -> void:
	print("[BackyardPath] Back from options")
	
	if option_sub_panel and option_sub_panel.visible:
		option_sub_panel.visible = false


func _on_exit_to_main_menu_button_pressed() -> void:
	print("[BackyardPath] Exit to main menu")
	
	# Unpause before leaving
	get_tree().paused = false
	
	# Disconnect from network if connected
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout
	
	# Save settings
	_save_pause_settings()
	
	# Return to main menu
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _on_in_game_volume_changed(value: float) -> void:
	var volume = value / 100.0
	MusicController.set_volume(volume)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"
	print("[BackyardPath] Volume changed to: ", volume)
	_save_pause_settings()


func _save_pause_settings() -> void:
	const OPTION_FILE = "user://settings.json"
	var data = {
		"volume": MusicController.get_volume()
	}
	
	var file = FileAccess.open(OPTION_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("[BackyardPath] Settings saved successfully")
