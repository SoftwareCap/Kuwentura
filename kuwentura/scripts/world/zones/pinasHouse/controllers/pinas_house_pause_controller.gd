extends RefCounted

## Pause Controller - Manages in-zone pause panel for Pina's House.

const SCENE_MAIN_MENU := "res://scenes/mainMenu/MainMenu.tscn"
const SETTINGS_FILE := "user://settings.json"

var zone: Node

var _is_paused := false

# [node_path, signal, callback] — used for both connect and disconnect
var _button_pairs: Array = []


func setup(owner: Node) -> void:
	zone = owner

	if zone.inside_zone_control and zone.inside_zone_control.has_signal("pause_pressed"):
		if not zone.inside_zone_control.pause_pressed.is_connected(zone._on_pause_button_pressed):
			zone.inside_zone_control.pause_pressed.connect(zone._on_pause_button_pressed)

	for node in [zone.in_game_pause_panel, zone.option_sub_panel]:
		if is_instance_valid(node):
			node.visible = false

	_sync_volume_ui()

	if is_instance_valid(zone.volume_slider) and not zone.volume_slider.value_changed.is_connected(zone._on_in_game_volume_changed):
		zone.volume_slider.value_changed.connect(zone._on_in_game_volume_changed)

	for node in [zone.pause_canvas_layer, zone.in_game_pause_panel, zone.option_sub_panel]:
		if is_instance_valid(node):
			node.process_mode = Node.PROCESS_MODE_ALWAYS

	_connect_pause_buttons()


func _connect_pause_buttons() -> void:
	_button_pairs = [
		["PauseCanvasLayer/InGamePausePanel/Resume_PlayButton", zone._on_resume_play_button_pressed],
		["PauseCanvasLayer/InGamePausePanel/OptionButton", zone._on_option_button_pressed],
		["PauseCanvasLayer/InGamePausePanel/ExitButton", zone._on_exit_to_main_menu_button_pressed],
		["PauseCanvasLayer/InGamePausePanel/OptionSubPanel/BackToPrevious", zone._on_in_game_option_back_pressed],
	]
	for pair in _button_pairs:
		var btn := zone.get_node_or_null(pair[0]) as Button
		if is_instance_valid(btn) and not btn.pressed.is_connected(pair[1]):
			btn.pressed.connect(pair[1])


func cleanup() -> void:
	if zone.inside_zone_control and zone.inside_zone_control.has_signal("pause_pressed"):
		if zone.inside_zone_control.pause_pressed.is_connected(zone._on_pause_button_pressed):
			zone.inside_zone_control.pause_pressed.disconnect(zone._on_pause_button_pressed)

	if is_instance_valid(zone.volume_slider) and zone.volume_slider.value_changed.is_connected(zone._on_in_game_volume_changed):
		zone.volume_slider.value_changed.disconnect(zone._on_in_game_volume_changed)

	for pair in _button_pairs:
		var btn := zone.get_node_or_null(pair[0]) as Button
		if is_instance_valid(btn) and btn.pressed.is_connected(pair[1]):
			btn.pressed.disconnect(pair[1])


func _sync_volume_ui() -> void:
	if is_instance_valid(zone.volume_slider):
		zone.volume_slider.value = MusicController.get_volume() * 100
	if is_instance_valid(zone.volume_value_label):
		zone.volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


func _set_pause_ui_visible(visible: bool) -> void:
	if is_instance_valid(zone.in_game_pause_panel):
		zone.in_game_pause_panel.visible = visible
	if is_instance_valid(zone.option_sub_panel):
		zone.option_sub_panel.visible = false
	if is_instance_valid(zone.inside_zone_control):
		zone.inside_zone_control.visible = not visible


func on_pause_button_pressed() -> void:
	_is_paused = true
	_set_pause_ui_visible(true)
	MusicController.pause_music()
	_pause_zone_systems()
	zone.get_tree().paused = true


func on_resume_play_button_pressed() -> void:
	_is_paused = false
	_set_pause_ui_visible(false)
	zone.get_tree().paused = false
	MusicController.resume_music()
	_resume_zone_systems()


func _pause_zone_systems() -> void:
	if "_shake_timer" in zone and is_instance_valid(zone._shake_timer):
		zone._shake_timer.paused = true


func _resume_zone_systems() -> void:
	if is_instance_valid(zone._shake_timer):
		zone._shake_timer.paused = false


func on_option_button_pressed() -> void:
	if is_instance_valid(zone.option_sub_panel):
		zone.option_sub_panel.visible = true
	_sync_volume_ui()


func on_in_game_option_back_pressed() -> void:
	if is_instance_valid(zone.option_sub_panel) and zone.option_sub_panel.visible:
		zone.option_sub_panel.visible = false


func on_exit_to_main_menu_button_pressed() -> void:
	_is_paused = false
	zone.get_tree().paused = false
	_resume_zone_systems()
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await zone.get_tree().create_timer(0.2).timeout
	save_settings()
	if zone.is_inside_tree():
		zone.get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func on_in_game_volume_changed(value: float) -> void:
	MusicController.set_volume(value / 100.0)
	if is_instance_valid(zone.volume_value_label):
		zone.volume_value_label.text = str(int(value)) + "%"


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"volume": MusicController.get_volume()}))
		file.close()


func is_paused() -> bool:
	return _is_paused
