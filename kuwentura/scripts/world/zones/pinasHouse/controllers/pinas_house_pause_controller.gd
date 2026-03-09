extends RefCounted

var zone

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


func cleanup() -> void:
	if zone.inside_zone_control and zone.inside_zone_control.has_signal("pause_pressed"):
		if zone.inside_zone_control.pause_pressed.is_connected(zone._on_pause_button_pressed):
			zone.inside_zone_control.pause_pressed.disconnect(zone._on_pause_button_pressed)

	if is_instance_valid(zone.volume_slider):
		if zone.volume_slider.value_changed.is_connected(zone._on_in_game_volume_changed):
			zone.volume_slider.value_changed.disconnect(zone._on_in_game_volume_changed)


func on_pause_button_pressed() -> void:
	print("[PinasHouse] Pause button pressed")

	if is_instance_valid(zone.in_game_pause_panel):
		zone.in_game_pause_panel.visible = true

	if is_instance_valid(zone.option_sub_panel):
		zone.option_sub_panel.visible = false

	zone.get_tree().paused = true


func on_resume_play_button_pressed() -> void:
	print("[PinasHouse] Resume button pressed")

	if is_instance_valid(zone.in_game_pause_panel):
		zone.in_game_pause_panel.visible = false

	if is_instance_valid(zone.option_sub_panel):
		zone.option_sub_panel.visible = false

	zone.get_tree().paused = false


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
	zone.get_tree().paused = false

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
