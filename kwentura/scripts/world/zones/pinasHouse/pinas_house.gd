extends Node2D

## Pina's House - Indoor zone with pause functionality

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton
@onready var inside_zone_control: CanvasLayer = $InsideZoneControl
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeValue

# Flag to track if clue was collected (for auto-return)
var clue_collected: bool = false


func _ready():
	print("[PinasHouse] Scene loaded!")
	
	# Play Pina's House background music
	MusicController.play_track(MusicController.MusicTrack.PINAS_HOUSE)
	
	# Display role for testing
	var role_text = "Unknown"
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"
	
	role_label.text = "Role: " + role_text
	print("[PinasHouse] Local role: ", role_text, " | Peer ID: ", multiplayer.get_unique_id())
	
	# Show saved position info
	var saved_pos = GameState.get_spawn_position(multiplayer.get_unique_id())
	if saved_pos != Vector2.ZERO:
		print("[PinasHouse] Will return to Forest Hub at position: ", saved_pos)
	
	# Connect to clue collection signal for auto-return
	GameState.clue_collected.connect(_on_clue_collected)
	
	# Setup pause functionality
	_setup_pause_controls()


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
	if inside_zone_control and inside_zone_control.pause_pressed.is_connected(_on_pause_button_pressed):
		inside_zone_control.pause_pressed.disconnect(_on_pause_button_pressed)


func _on_back_pressed():
	print("[PinasHouse] Returning to Forest Hub...")
	_return_to_forest()


func _on_clue_collected(zone_id: String, _clue_data: Dictionary):
	# Check if this is the clue for Pina's House
	if zone_id == "pinas_house" and not clue_collected:
		clue_collected = true
		print("[PinasHouse] Clue collected! Auto-returning to Forest Hub in 3 seconds...")
		
		# Update UI to show returning
		role_label.text = "Clue collected! Returning..."
		
		# Wait for the collection effect to show, then return
		await get_tree().create_timer(3.0).timeout
		_return_to_forest()


func _return_to_forest():
	"""Return to Forest Hub using saved positions."""
	print("[PinasHouse] Teleporting back to Forest Hub at saved position")
	
	# The spawn positions are already saved in GameState from when we entered
	# ForestHub._spawn_player_for_peer will use them automatically
	
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
