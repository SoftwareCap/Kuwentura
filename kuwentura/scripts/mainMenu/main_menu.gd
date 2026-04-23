extends Control

# CONSTANTS
const SETTINGS_FILE := "user://settings.json"
const SCENE_DETECTIVE_LOBBY := "res://scenes/mainMenu/DetectiveLobby.tscn"
const SCENE_SIDEKICK_WAITING := "res://scenes/mainMenu/SidekickWaiting.tscn"
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"

const BUTTON_SCALE_PRESSED := Vector2(0.9, 0.9)
const BUTTON_SCALE_NORMAL := Vector2(1.0, 1.0)
const BUTTON_ANIM_DURATION := 0.1

# NODE REFERENCES
@onready var host_button: TextureButton = $HostButton
@onready var join_button: TextureButton = $JoinButton
@onready var status_label: Label = $StatusLabel

# Settings
@onready var settings_control: CanvasLayer = $SettingsControl
@onready var settings_panel: Panel = $SettingsLayer/SettingsPanel
@onready var volume_slider: HSlider = $SettingsLayer/SettingsPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $SettingsLayer/SettingsPanel/VolumeSliderControl/VolumeValue
@onready var back_button: TouchScreenButton = $SettingsLayer/SettingsPanel/Back
@onready var view_user_profile_button: Button = $SettingsLayer/SettingsPanel/ViewUserProfile
@onready var user_section: Panel = $SettingsLayer/SettingsPanel/UserSection
@onready var user_section_back_button: TouchScreenButton = $SettingsLayer/SettingsPanel/UserSection/Back
@onready var sign_in_button: Button = $SettingsLayer/SettingsPanel/UserSection/AuthButtons/SignInButton
@onready var guest_button: Button = $SettingsLayer/SettingsPanel/UserSection/AuthButtons/GuestButton
@onready var link_google_button: Button = $SettingsLayer/SettingsPanel/UserSection/AuthButtons/LinkGoogleButton

# Join popup
@onready var sidekick_popup: Panel = $PopupLayer/SidekickPopup
@onready var code_input: LineEdit = $PopupLayer/SidekickPopup/VBoxContainer/LineEdit
@onready var join_code_ok_button: Button = $PopupLayer/SidekickPopup/VBoxContainer/HBoxContainer/JoinButton
@onready var join_code_cancel_button: Button = $PopupLayer/SidekickPopup/VBoxContainer/HBoxContainer/CancelButton

@onready var input_blocker: ColorRect = $InputBlockerLayer/InputBlocker

# STATE
var is_joining: bool = false


# LIFECYCLE
func _ready() -> void:
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)
	
		# Force hide settings on startup
	if settings_panel:
		settings_panel.get_parent().visible = false
		settings_panel.visible = false
		
	_load_settings()
	_setup_main_buttons()
	_connect_signals()


func _exit_tree() -> void:
	_disconnect_signals()


# SETUP
func _setup_main_buttons() -> void:
	"""Configure visual feedback and connect action handlers for host/join buttons."""
	for btn in [host_button, join_button]:
		_setup_button_visuals(btn)

	_connect_texture_button(host_button, _on_host_pressed)
	_connect_texture_button(join_button, _on_join_pressed)


func _setup_button_visuals(button: TextureButton) -> void:
	"""Attach scale-press animation to a TextureButton."""
	if not button:
		push_warning("[MainMenu] Button is null, cannot setup visuals")
		return
	button.pivot_offset = button.size / 2
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _connect_texture_button(button: TextureButton, callback: Callable) -> void:
	"""Connect a TextureButton's pressed signal safely."""
	if not button:
		push_warning("[MainMenu] Cannot connect null button")
		return
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _connect_signals() -> void:
	"""Connect all UI and network signals."""
	var signal_pairs := [
		[NetworkManager.connection_established, _on_connection_established],
		[NetworkManager.connection_failed, _on_connection_failed],
		[NetworkManager.player_joined, _on_player_joined],
		[NetworkManager.role_assignment_received, _on_role_assigned],
		[NetworkManager.room_code_generated, _on_room_code_generated],
		[NetworkManager.game_started, _on_game_started],
		[NetworkManager.rejoin_game_requested, _on_rejoin_game_requested],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if not sig.is_connected(cb):
			sig.connect(cb)

	if settings_control and not settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.connect(_on_settings_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_settings_pressed):
		back_button.pressed.connect(_on_back_settings_pressed)
	if volume_slider and not volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.connect(_on_volume_changed)
	if view_user_profile_button and not view_user_profile_button.pressed.is_connected(_on_view_user_profile_pressed):
		view_user_profile_button.pressed.connect(_on_view_user_profile_pressed)
	if user_section_back_button and not user_section_back_button.pressed.is_connected(_on_back_from_profile_pressed):
		user_section_back_button.pressed.connect(_on_back_from_profile_pressed)
	if join_code_ok_button and not join_code_ok_button.pressed.is_connected(_on_join_code_ok_pressed):
		join_code_ok_button.pressed.connect(_on_join_code_ok_pressed)
	if join_code_cancel_button and not join_code_cancel_button.pressed.is_connected(_on_join_code_cancel_pressed):
		join_code_cancel_button.pressed.connect(_on_join_code_cancel_pressed)
	if code_input and not code_input.text_changed.is_connected(_on_code_text_changed):
		code_input.text_changed.connect(_on_code_text_changed)


func _disconnect_signals() -> void:
	"""Disconnect all signals to prevent callbacks after scene change."""
	var signal_pairs := [
		[NetworkManager.connection_established, _on_connection_established],
		[NetworkManager.connection_failed, _on_connection_failed],
		[NetworkManager.player_joined, _on_player_joined],
		[NetworkManager.role_assignment_received, _on_role_assigned],
		[NetworkManager.room_code_generated, _on_room_code_generated],
		[NetworkManager.game_started, _on_game_started],
		[NetworkManager.rejoin_game_requested, _on_rejoin_game_requested],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)

	if settings_control and settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.disconnect(_on_settings_pressed)


# BUTTON ANIMATIONS
func _on_button_down(button: TextureButton) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", BUTTON_SCALE_PRESSED, BUTTON_ANIM_DURATION)


func _on_button_up(button: TextureButton) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", BUTTON_SCALE_NORMAL, BUTTON_ANIM_DURATION)


# SETTINGS
func _on_settings_pressed() -> void:
	_set_input_blocked(true)
	if settings_panel:
		settings_panel.get_parent().visible = true
		settings_panel.visible = true
		if user_section:
			user_section.visible = false
		if view_user_profile_button:
			view_user_profile_button.visible = true
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(volume_slider.value)) + "%"
	if settings_control:
		settings_control.hide_button()


func _on_back_settings_pressed() -> void:
	if settings_panel:
		settings_panel.get_parent().visible = false
		settings_panel.visible = false
	_set_input_blocked(false)
	if settings_control:
		settings_control.show_button()
	_save_settings()


func _on_view_user_profile_pressed() -> void:
	if user_section:
		user_section.visible = true
	if view_user_profile_button:
		view_user_profile_button.visible = false


func _on_back_from_profile_pressed() -> void:
	if user_section:
		user_section.visible = false
	if view_user_profile_button:
		view_user_profile_button.visible = true


func _on_volume_changed(value: float) -> void:
	MusicController.set_volume(value / 100.0)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		return
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if not file:
		push_warning("[MainMenu] Failed to open settings file for reading")
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_warning("[MainMenu] Failed to parse settings file")
		return
	var data = json.get_data()
	if data is Dictionary and data.has("volume"):
		var volume := float(data["volume"])
		MusicController.set_volume(volume)
		if volume_slider:
			volume_slider.value = volume * 100


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if not file:
		push_warning("[MainMenu] Failed to open settings file for writing")
		return
	file.store_string(JSON.stringify({ "volume": MusicController.get_volume() }))
	file.close()


# HOST / JOIN
func _on_host_pressed() -> void:
	_show_status("Creating game...")
	GameState.reset_all_progress()

	var result := NetworkManager.host_game()
	if not result.success:
		_show_status("Failed to host: " + result.get("error", "Unknown error"))
		return

	_show_status("Room created! Code: " + result.get("invite_code", ""))
	get_tree().change_scene_to_file(SCENE_DETECTIVE_LOBBY)


func _on_join_pressed() -> void:
	_set_input_blocked(true)
	if sidekick_popup:
		sidekick_popup.visible = true
		if code_input:
			code_input.text = ""
			code_input.placeholder_text = "Enter Room Code"
			code_input.grab_focus()


func _on_join_code_ok_pressed() -> void:
	if not code_input:
		return
	var code := code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		_show_join_error("Please enter 6-character code!")
		return
	sidekick_popup.visible = false
	_set_input_blocked(false)
	_process_join_code(code)


func _on_join_code_cancel_pressed() -> void:
	sidekick_popup.visible = false
	_set_input_blocked(false)


func _on_code_text_changed(new_text: String) -> void:
	if code_input:
		code_input.text = new_text.to_upper()
		code_input.caret_column = code_input.text.length()


func _process_join_code(code: String) -> void:
	_show_status("Searching for host...\nCode: " + code + "\n\n• Ensure host is in lobby\n• Same Wi-Fi or Hotspot mode")

	var result := await NetworkManager.join_game_with_code(code)

	if not result.success:
		_show_status("Failed to join:\n" + result.get("error", "Unknown error"))
		return

	GameState.reset_all_progress()
	await get_tree().create_timer(0.5).timeout

	if not is_inside_tree():
		return

	if NetworkManager.is_rejoining():
		get_tree().change_scene_to_file(SCENE_FOREST_HUB)
		return

	_show_status("Connected!\nWaiting for Detective to start...")
	get_tree().change_scene_to_file(SCENE_SIDEKICK_WAITING)


func _show_join_error(message: String) -> void:
	_show_status(message)
	if code_input:
		var tween := create_tween()
		tween.tween_property(code_input, "position:x", code_input.position.x + 5, 0.05)
		tween.tween_property(code_input, "position:x", code_input.position.x - 5, 0.05)
		tween.tween_property(code_input, "position:x", code_input.position.x, 0.05)


# NETWORK CALLBACKS
func _on_connection_established(_peer_id: int, _role: int = 0) -> void:
	pass


func _on_connection_failed(error: String) -> void:
	_show_status("Connection failed: " + error)


func _on_room_code_generated(_code: String) -> void:
	pass


func _on_role_assigned(_role: int) -> void:
	pass


func _on_game_started(_checkpoint: String) -> void:
	get_tree().change_scene_to_file(SCENE_FOREST_HUB)


func _on_rejoin_game_requested(_world_state: Dictionary) -> void:
	get_tree().change_scene_to_file(SCENE_FOREST_HUB)


func _on_player_joined(_peer_id: int, _role: int) -> void:
	pass


# HELPERS
func _set_input_blocked(blocked: bool) -> void:
	if input_blocker:
		input_blocker.visible = blocked


func _show_status(text: String) -> void:
	if status_label:
		status_label.text = text
		status_label.show()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		if sidekick_popup:
			sidekick_popup.visible = false
		_process_join_code("LOCAL")
