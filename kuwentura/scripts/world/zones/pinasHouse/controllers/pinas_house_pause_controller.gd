extends RefCounted

var zone

# Track pause state for the zone
var _is_paused := false

func setup(owner) -> void:
	zone = owner

	if zone.inside_zone_control and zone.inside_zone_control.has_signal("pause_pressed"):
		if not zone.inside_zone_control.pause_pressed.is_connected(zone._on_pause_button_pressed):
			zone.inside_zone_control.pause_pressed.connect(zone._on_pause_button_pressed)

	if is_instance_valid(zone.in_game_pause_panel):
		zone.in_game_pause_panel.visible = false

	if is_instance_valid(zone.option_sub_panel):
		zone.option_sub_panel.visible = false

	if is_instance_valid(zone.volume_slider):
		zone.volume_slider.value = MusicController.get_volume() * 100
		if not zone.volume_slider.value_changed.is_connected(zone._on_in_game_volume_changed):
			zone.volume_slider.value_changed.connect(zone._on_in_game_volume_changed)

	if is_instance_valid(zone.volume_value_label):
		zone.volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"

	# Ensure pause UI can process while game is paused
	if is_instance_valid(zone.pause_canvas_layer):
		zone.pause_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(zone.in_game_pause_panel):
		zone.in_game_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(zone.option_sub_panel):
		zone.option_sub_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect pause panel buttons
	_connect_pause_buttons()


func _connect_pause_buttons() -> void:
	# Connect Resume button
	var resume_button = zone.get_node_or_null("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton")
	if is_instance_valid(resume_button):
		if not resume_button.pressed.is_connected(zone._on_resume_play_button_pressed):
			resume_button.pressed.connect(zone._on_resume_play_button_pressed)
			print("[PinasHousePauseController] Connected Resume button")

	# Connect Option button
	var option_button = zone.get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionButton")
	if is_instance_valid(option_button):
		if not option_button.pressed.is_connected(zone._on_option_button_pressed):
			option_button.pressed.connect(zone._on_option_button_pressed)
			print("[PinasHousePauseController] Connected Option button")

	# Connect Exit button
	var exit_button = zone.get_node_or_null("PauseCanvasLayer/InGamePausePanel/ExitButton")
	if is_instance_valid(exit_button):
		if not exit_button.pressed.is_connected(zone._on_exit_to_main_menu_button_pressed):
			exit_button.pressed.connect(zone._on_exit_to_main_menu_button_pressed)
			print("[PinasHousePauseController] Connected Exit button")

	# Connect Back button (from options sub-panel)
	var back_button = zone.get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/BackToPrevious")
	if is_instance_valid(back_button):
		if not back_button.pressed.is_connected(zone._on_in_game_option_back_pressed):
			back_button.pressed.connect(zone._on_in_game_option_back_pressed)
			print("[PinasHousePauseController] Connected Back button")


func cleanup() -> void:
	if zone.inside_zone_control and zone.inside_zone_control.has_signal("pause_pressed"):
		if zone.inside_zone_control.pause_pressed.is_connected(zone._on_pause_button_pressed):
			zone.inside_zone_control.pause_pressed.disconnect(zone._on_pause_button_pressed)

	if is_instance_valid(zone.volume_slider):
		if zone.volume_slider.value_changed.is_connected(zone._on_in_game_volume_changed):
			zone.volume_slider.value_changed.disconnect(zone._on_in_game_volume_changed)

	# Disconnect buttons
	var resume_button = zone.get_node_or_null("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton")
	if is_instance_valid(resume_button) and resume_button.pressed.is_connected(zone._on_resume_play_button_pressed):
		resume_button.pressed.disconnect(zone._on_resume_play_button_pressed)

	var option_button = zone.get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionButton")
	if is_instance_valid(option_button) and option_button.pressed.is_connected(zone._on_option_button_pressed):
		option_button.pressed.disconnect(zone._on_option_button_pressed)

	var exit_button = zone.get_node_or_null("PauseCanvasLayer/InGamePausePanel/ExitButton")
	if is_instance_valid(exit_button) and exit_button.pressed.is_connected(zone._on_exit_to_main_menu_button_pressed):
		exit_button.pressed.disconnect(zone._on_exit_to_main_menu_button_pressed)

	var back_button = zone.get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/BackToPrevious")
	if is_instance_valid(back_button) and back_button.pressed.is_connected(zone._on_in_game_option_back_pressed):
		back_button.pressed.disconnect(zone._on_in_game_option_back_pressed)


func on_pause_button_pressed() -> void:
	print("[PinasHouse] Pause button pressed")

	_is_paused = true

	if is_instance_valid(zone.in_game_pause_panel):
		zone.in_game_pause_panel.visible = true

	if is_instance_valid(zone.option_sub_panel):
		zone.option_sub_panel.visible = false

	# Hide the pause button while paused
	if is_instance_valid(zone.inside_zone_control):
		zone.inside_zone_control.visible = false

	# Pause the background music
	MusicController.pause_music()

	# Pause the zone's timers and systems
	_pause_zone_systems()

	zone.get_tree().paused = true


func on_resume_play_button_pressed() -> void:
	print("[PinasHouse] Resume button pressed")

	_is_paused = false

	if is_instance_valid(zone.in_game_pause_panel):
		zone.in_game_pause_panel.visible = false

	if is_instance_valid(zone.option_sub_panel):
		zone.option_sub_panel.visible = false

	zone.get_tree().paused = false

	# Show the pause button again
	if is_instance_valid(zone.inside_zone_control):
		zone.inside_zone_control.visible = true

	# Resume the background music
	MusicController.resume_music()

	# Resume the zone's timers and systems
	_resume_zone_systems()


func _pause_zone_systems() -> void:
	print("[PinasHouse] Pausing zone systems")

	# Pause consequence timers
	if is_instance_valid(zone._tick_timer):
		zone._tick_timer.paused = true

	if is_instance_valid(zone._attack_timer):
		zone._attack_timer.paused = true

	if is_instance_valid(zone._first_attack_timer):
		zone._first_attack_timer.paused = true

	# Pause shake timer
	if is_instance_valid(zone._shake_timer):
		zone._shake_timer.paused = true


func _resume_zone_systems() -> void:
	print("[PinasHouse] Resuming zone systems")

	# Resume consequence timers (only if zone hasn't failed)
	if not zone._failed:
		if is_instance_valid(zone._tick_timer):
			zone._tick_timer.paused = false

		if is_instance_valid(zone._attack_timer):
			zone._attack_timer.paused = false

		if is_instance_valid(zone._first_attack_timer):
			zone._first_attack_timer.paused = false

	# Resume shake timer
	if is_instance_valid(zone._shake_timer):
		zone._shake_timer.paused = false


func on_option_button_pressed() -> void:
	print("[PinasHouse] Option button pressed")

	if is_instance_valid(zone.option_sub_panel):
		zone.option_sub_panel.visible = true

	if is_instance_valid(zone.volume_slider):
		zone.volume_slider.value = MusicController.get_volume() * 100

	if is_instance_valid(zone.volume_value_label):
		zone.volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


func on_in_game_option_back_pressed() -> void:
	print("[PinasHouse] Back from options")

	if is_instance_valid(zone.option_sub_panel) and zone.option_sub_panel.visible:
		zone.option_sub_panel.visible = false
		print("[PinasHouse] Option sub-panel closed, back to pause panel")


func on_exit_to_main_menu_button_pressed() -> void:
	print("[PinasHouse] Exit to main menu")
	_is_paused = false
	zone.get_tree().paused = false

	# Resume systems before exiting
	_resume_zone_systems()

	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await zone.get_tree().create_timer(0.2).timeout

	save_settings()

	if zone.is_inside_tree():
		zone.get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func on_in_game_volume_changed(value: float) -> void:
	var volume := value / 100.0
	MusicController.set_volume(volume)

	if is_instance_valid(zone.volume_value_label):
		zone.volume_value_label.text = str(int(value)) + "%"


func save_settings() -> void:
	const OPTION_FILE := "user://settings.json"

	var data := {
		"volume": MusicController.get_volume()
	}

	var file := FileAccess.open(OPTION_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


# Public method to check if game is paused
func is_paused() -> bool:
	return _is_paused
