extends Control

@onready var host_button: TextureButton = $HostButton
@onready var join_button: TextureButton = $JoinButton
@onready var exit_button = $ExitButton
@onready var status_label = $StatusLabel
@onready var settings_control: CanvasLayer = $SettingsControl
@onready var settings_panel: Panel = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $SettingsPanel/VolumeSliderControl/VolumeValue
@onready var back_button: TouchScreenButton = $SettingsPanel/Back

# User Auth
@onready var sign_in_button: Button = $SettingsPanel/UserSection/AuthButtons/SignInButton
@onready var guest_button: Button = $SettingsPanel/UserSection/AuthButtons/GuestButton
@onready var link_google_button: Button = $SettingsPanel/UserSection/AuthButtons/LinkGoogleButton

# Sidekick Join Popup nodes
@onready var sidekick_popup: Panel = $SidekickPopup
@onready var code_input: LineEdit = $SidekickPopup/VBoxContainer/LineEdit
@onready var join_code_ok_button: Button = $SidekickPopup/VBoxContainer/HBoxContainer/Button
@onready var join_code_cancel_button: Button = $SidekickPopup/VBoxContainer/HBoxContainer/Button2

var is_joining: bool = false

# Settings keys
const SETTINGS_FILE = "user://settings.json"


func _ready():
	# Ensure main menu music is playing
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)
	
	# Load saved settings
	_load_settings()
	
	# Connect button signals
	if not host_button.pressed.is_connected(_on_host_pressed):
		host_button.pressed.connect(_on_host_pressed)
	if not join_button.pressed.is_connected(_on_join_pressed):
		join_button.pressed.connect(_on_join_pressed)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)

	# Connect settings signals
	if settings_control and not settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.connect(_on_settings_pressed)
	
	# Connect settings panel signals
	if back_button and not back_button.pressed.is_connected(_on_back_settings_pressed):
		back_button.pressed.connect(_on_back_settings_pressed)
	if volume_slider and not volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.connect(_on_volume_changed)
	
	# Connect sidekick popup signals
	if join_code_ok_button and not join_code_ok_button.pressed.is_connected(_on_join_code_ok_pressed):
		join_code_ok_button.pressed.connect(_on_join_code_ok_pressed)
	if join_code_cancel_button and not join_code_cancel_button.pressed.is_connected(_on_join_code_cancel_pressed):
		join_code_cancel_button.pressed.connect(_on_join_code_cancel_pressed)
	if code_input and not code_input.text_changed.is_connected(_on_code_text_changed):
		code_input.text_changed.connect(_on_code_text_changed)

	# Connect to network signals
	if not NetworkManager.connection_established.is_connected(_on_connection_established):
		NetworkManager.connection_established.connect(_on_connection_established)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)
	if not NetworkManager.player_joined.is_connected(_on_player_joined):
		NetworkManager.player_joined.connect(_on_player_joined)
	if not NetworkManager.role_assignment_received.is_connected(_on_role_assigned):
		NetworkManager.role_assignment_received.connect(_on_role_assigned)
	if not NetworkManager.room_code_generated.is_connected(_on_room_code_generated):
		NetworkManager.room_code_generated.connect(_on_room_code_generated)
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)


func _on_settings_pressed() -> void:
	print("[MainMenu] Opening settings panel")
	if settings_panel:
		settings_panel.visible = true
		# Update slider to current volume
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(volume_slider.value)) + "%"


func _on_back_settings_pressed() -> void:
	print("[MainMenu] Closing settings panel")
	if settings_panel:
		settings_panel.visible = false
	_save_settings()


func _on_volume_changed(value: float) -> void:
	var volume = value / 100.0
	MusicController.set_volume(volume)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"
	print("[MainMenu] Volume changed to: ", volume)


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		if file:
			var json = JSON.new()
			var error = json.parse(file.get_as_text())
			if error == OK:
				var data = json.get_data()
				if data is Dictionary:
					if data.has("volume"):
						var volume = float(data["volume"])
						MusicController.set_volume(volume)
						if volume_slider:
							volume_slider.value = volume * 100
					print("[MainMenu] Settings loaded successfully")
			else:
				push_warning("[MainMenu] Failed to parse settings file")
			file.close()
	else:
		print("[MainMenu] No settings file found, using defaults")


func _save_settings() -> void:
	var data = {
		"volume": MusicController.get_volume()
	}
	
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("[MainMenu] Settings saved successfully")
	else:
		push_warning("[MainMenu] Failed to save settings file")


func _on_host_pressed() -> void:
	print("Hosting game...")
	_show_status("Creating game...")

	var result = NetworkManager.host_game()
	
	if not result.success:
		var error_msg = result.get("error", "Unknown error")
		_show_status("Failed to host: " + error_msg)
		return

	print("Game hosted! Invite code: ", result.get("invite_code", ""))
	_show_status("Room created! Code: " + result.get("invite_code", ""))

	get_tree().change_scene_to_file("res://scenes/mainMenu/DetectiveLobby.tscn")


func _on_join_pressed() -> void:
	print("[MainMenu] Opening join popup")
	if sidekick_popup:
		sidekick_popup.visible = true
		if code_input:
			code_input.text = ""
			code_input.grab_focus()


func _on_join_code_ok_pressed() -> void:
	if not code_input:
		return
	
	var code = code_input.text.strip_edges().to_upper()
	
	if code.length() != 6:
		_show_join_error("Please enter 6-character code!")
		return
	
	# Hide popup and process the code
	sidekick_popup.visible = false
	_process_join_code(code)


func _on_join_code_cancel_pressed() -> void:
	print("[MainMenu] Join cancelled")
	sidekick_popup.visible = false


func _on_code_text_changed(new_text: String) -> void:
	if code_input:
		code_input.text = new_text.to_upper()
		code_input.caret_column = code_input.text.length()


func _process_join_code(code: String) -> void:
	print("[MainMenu] Code entered: ", code)
	
	# DEBUG: Special "LOCAL" code for same-PC testing
	if code == "LOCAL":
		print("[MainMenu] DEBUG MODE: Connecting to localhost")
		_show_status("Debug: Connecting to localhost...")
		
		var local_result = await NetworkManager.join_game_with_ip("127.0.0.1", "LOCAL")
		
		if not local_result.success:
			_show_status("Failed to join localhost: " + local_result.get("error", "Unknown"))
			return
		
		get_tree().change_scene_to_file("res://scenes/mainMenu/SidekickWaiting.tscn")
		return
	
	_show_status("Searching for game with code: " + code + "...")
	print("[MainMenu] Starting discovery for code: ", code)
	
	var result = await NetworkManager.join_game_with_code(code)
	
	print("[MainMenu] Join result: ", result)
	
	if not result.success:
		print("[MainMenu] Join failed: ", result.get("error", "Unknown"))
		_show_status("Failed to join: " + result.get("error", "Unknown error"))
		return
	
	print("[MainMenu] Connected to host!")
	_show_status("Connected! Waiting for game to start...")
	
	get_tree().change_scene_to_file("res://scenes/mainMenu/SidekickWaiting.tscn")


func _show_join_error(message: String) -> void:
	print("Error: ", message)
	_show_status(message)
	# Shake animation
	if code_input:
		var tween = create_tween()
		tween.tween_property(code_input, "position:x", code_input.position.x + 5, 0.05)
		tween.tween_property(code_input, "position:x", code_input.position.x - 5, 0.05)
		tween.tween_property(code_input, "position:x", code_input.position.x, 0.05)


func _on_connection_established(peer_id: int):
	print("Connected! Peer ID: ", peer_id)


func _on_connection_failed(error: String):
	print("Connection failed: " + error)
	_show_status("Connection failed: " + error)


func _on_room_code_generated(code: String):
	print("Room code generated: ", code)


func _on_role_assigned(role):
	print("Role assigned: ", role)


func _on_game_started(checkpoint: String):
	print("Game started at: ", checkpoint)
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_player_joined(_peer_id: int, role):
	print("Player joined as ", role)


func _show_status(text: String):
	if status_label:
		status_label.text = text
		status_label.show()
	print("Status: ", text)


func _input(event):
	# DEBUG: Press F12 to auto-connect to localhost for same-PC testing
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		print("[DEBUG] F12 pressed - auto-connecting to localhost")
		if sidekick_popup:
			sidekick_popup.visible = false
		_process_join_code("LOCAL")
