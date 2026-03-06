extends Control

@onready var host_button: TextureButton = $HostButton
@onready var join_button: TextureButton = $JoinButton
@onready var exit_button: TextureButton = $ExitButton
@onready var status_label = $StatusLabel
@onready var settings_control: CanvasLayer = $SettingsControl
@onready var settings_panel: Panel = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $SettingsPanel/VolumeSliderControl/VolumeValue
@onready var back_button: TouchScreenButton = $SettingsPanel/Back
@onready var view_user_profile_button: Button = $SettingsPanel/ViewUserProfile
@onready var user_profile_panel: Panel = $SettingsPanel/UserProfile
@onready var back_from_profile_button: TouchScreenButton = $SettingsPanel/UserProfile/BackToPrevious

# User Auth UI (inside UserProfile panel)
@onready var avatar_texture: TextureRect = $SettingsPanel/UserProfile/UserContent/AvatarTexture
@onready var display_name_label: Label = $SettingsPanel/UserProfile/UserContent/UserInfo/DisplayName
@onready var provider_label: Label = $SettingsPanel/UserProfile/UserContent/UserInfo/ProviderLabel
@onready var sign_in_button: Button = $SettingsPanel/UserProfile/AuthButtons/SignInButton
@onready var guest_button: Button = $SettingsPanel/UserProfile/AuthButtons/GuestButton
@onready var link_google_button: Button = $SettingsPanel/UserProfile/AuthButtons/LinkGoogleButton

# Sidekick Join Popup nodes
@onready var sidekick_popup: Panel = $SidekickPopup
@onready var code_input: LineEdit = $SidekickPopup/VBoxContainer/LineEdit
@onready var join_code_cancel_button: Button = $SidekickPopup/VBoxContainer/HBoxContainer/Cancel
@onready var join_code_ok_button: Button = $SidekickPopup/VBoxContainer/HBoxContainer/Join

var is_joining: bool = false

# Settings keys
const SETTINGS_FILE = "user://settings.json"


func _ready():
	# Ensure main menu music is playing
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)
	
	# Load saved settings
	_load_settings()
	
	# Setup visual feedback for main menu buttons
	_setup_button_visuals(host_button)
	_setup_button_visuals(join_button)
	_setup_button_visuals(exit_button)
	
	# Connect button signals (use button_down/button_up for visuals, pressed for action)
	_connect_texture_button(host_button, _on_host_pressed)
	_connect_texture_button(join_button, _on_join_pressed)
	_connect_texture_button(exit_button, _on_exit_pressed)

	# Connect settings signals
	if settings_control and not settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.connect(_on_settings_pressed)
	
	# Connect settings panel signals
	# TouchScreenButton uses "pressed" signal but it's different from TextureButton
	if back_button and not back_button.pressed.is_connected(_on_back_settings_pressed):
		back_button.pressed.connect(_on_back_settings_pressed)
	
	if volume_slider and not volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.connect(_on_volume_changed)
	
	# Connect View User Profile button
	if view_user_profile_button and not view_user_profile_button.pressed.is_connected(_on_view_user_profile_pressed):
		view_user_profile_button.pressed.connect(_on_view_user_profile_pressed)
	
	# Connect back from profile button
	if back_from_profile_button and not back_from_profile_button.pressed.is_connected(_on_back_from_profile_pressed):
		back_from_profile_button.pressed.connect(_on_back_from_profile_pressed)
	
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
	
	# Connect User Auth signals
	_connect_auth_signals()
	
	# Initialize User Auth UI
	_update_user_ui()


# NEW: Setup visual pressed feedback for buttons
func _setup_button_visuals(button: TextureButton):
	if not button:
		push_warning("Button is null, cannot setup visuals")
		return
	
	# Make sure pivot is centered for scaling
	button.pivot_offset = button.size / 2
	
	# Connect visual feedback signals
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _on_button_down(button: TextureButton):
	# Scale down when pressed (like touch feedback)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.1)


func _on_button_up(button: TextureButton):
	# Scale back up when released
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)


# NEW: Helper to connect texture button signals safely
func _connect_texture_button(button: TextureButton, callback: Callable):
	if not button:
		push_warning("Cannot connect null button")
		return
	
	# TextureButton uses pressed signal (not property)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _connect_auth_signals() -> void:
	"""Connect authentication related signals."""
	# Connect auth buttons
	if sign_in_button and not sign_in_button.pressed.is_connected(_on_sign_in_pressed):
		sign_in_button.pressed.connect(_on_sign_in_pressed)
	if guest_button and not guest_button.pressed.is_connected(_on_guest_pressed):
		guest_button.pressed.connect(_on_guest_pressed)
	if link_google_button and not link_google_button.pressed.is_connected(_on_link_google_pressed):
		link_google_button.pressed.connect(_on_link_google_pressed)
	
	# Connect to UserManager signals
	if not UserManager.user_data_changed.is_connected(_on_user_data_changed):
		UserManager.user_data_changed.connect(_on_user_data_changed)
	if not UserManager.profile_picture_loaded.is_connected(_on_profile_picture_loaded):
		UserManager.profile_picture_loaded.connect(_on_profile_picture_loaded)
	
	# Connect to FirebaseAuth signals
	if not FirebaseAuth.google_auth_success.is_connected(_on_google_auth_success):
		FirebaseAuth.google_auth_success.connect(_on_google_auth_success)
	if not FirebaseAuth.google_auth_failed.is_connected(_on_google_auth_failed):
		FirebaseAuth.google_auth_failed.connect(_on_google_auth_failed)
	if not FirebaseAuth.account_linked_success.is_connected(_on_account_linked):
		FirebaseAuth.account_linked_success.connect(_on_account_linked)
	if not FirebaseAuth.account_link_failed.is_connected(_on_link_failed):
		FirebaseAuth.account_link_failed.connect(_on_link_failed)
	# Connect anonymous auth signals
	if not FirebaseAuth.auth_success.is_connected(_on_anonymous_auth_success):
		FirebaseAuth.auth_success.connect(_on_anonymous_auth_success)
	if not FirebaseAuth.auth_failed.is_connected(_on_anonymous_auth_failed):
		FirebaseAuth.auth_failed.connect(_on_anonymous_auth_failed)


func _update_user_ui() -> void:
	"""Update the user profile UI based on current auth state."""
	var user_data = UserManager.get_user_data()
	
	# Update display name
	if display_name_label:
		display_name_label.text = user_data.display_name if not user_data.display_name.is_empty() else "Guest"
	
	# Update provider label and button visibility
	if provider_label:
		match user_data.provider:
			"google":
				provider_label.text = "Google Account"
				if link_google_button:
					link_google_button.visible = false
				if sign_in_button:
					sign_in_button.visible = false
				if guest_button:
					guest_button.visible = false
			"anonymous":
				provider_label.text = "Guest"
				if link_google_button:
					link_google_button.visible = true
				if sign_in_button:
					sign_in_button.visible = true
				if guest_button:
					guest_button.visible = true
	
	# Update avatar
	if avatar_texture:
		var cached = UserManager.get_cached_profile_texture()
		if cached:
			avatar_texture.texture = cached
		elif not user_data.photo_url.is_empty():
			UserManager.load_profile_picture(user_data.photo_url)
		else:
			avatar_texture.texture = preload("res://assets/sprites/userIcon.png")


func _on_user_data_changed(_data: Dictionary) -> void:
	_update_user_ui()


func _on_profile_picture_loaded(texture: Texture2D) -> void:
	if texture and avatar_texture:
		avatar_texture.texture = texture


# ============================================
# AUTH BUTTON HANDLERS
# ============================================

func _on_sign_in_pressed() -> void:
	print("[MainMenu] Sign in button pressed")
	FirebaseAuth.sign_in_with_google()
	_show_status("Opening Google Sign-In...")


func _on_guest_pressed() -> void:
	print("[MainMenu] Guest button pressed - starting anonymous login")
	_show_status("Continuing as Guest...")
	FirebaseAuth.anonymous_login()


func _on_link_google_pressed() -> void:
	print("[MainMenu] Link Google button pressed")
	if not FirebaseAuth.is_authenticated:
		_show_status("Please sign in anonymously first")
		return
	
	# Store current anonymous UID before linking
	UserManager.update_user_data({"anonymous_uid": FirebaseAuth.current_user_id})
	
	# Start Google sign-in flow for linking
	FirebaseAuth.link_with_google()
	_show_status("Linking Google account...")


# ============================================
# FIREBASE AUTH CALLBACKS
# ============================================

func _on_google_auth_success(user_data: Dictionary) -> void:
	print("[MainMenu] Google sign-in success")
	_show_status("Signed in successfully!")
	
	# Update UserManager
	UserManager.update_user_data(user_data)
	
	# Save to Firestore
	FirebaseFirestore.save_user_profile(user_data.user_id, user_data)
	
	# Load profile picture if available
	if not user_data.photo_url.is_empty():
		UserManager.load_profile_picture(user_data.photo_url)
	
	# Update UI
	_update_user_ui()


func _on_google_auth_failed(error: String) -> void:
	print("[MainMenu] Google sign-in failed: ", error)
	_show_status("Sign in failed: " + error)


func _on_account_linked(user_data: Dictionary) -> void:
	print("[MainMenu] Account linked successfully")
	_show_status("Account linked successfully!")
	
	# Update with linked status
	user_data["is_linked"] = true
	UserManager.update_user_data(user_data)
	
	# Save to Firestore
	FirebaseFirestore.save_user_profile(user_data.user_id, user_data)
	
	# Update UI
	_update_user_ui()


func _on_link_failed(error: String) -> void:
	print("[MainMenu] Account link failed: ", error)
	_show_status("Linking failed: " + error)


func _on_anonymous_auth_success(user_id: String, _token: String) -> void:
	print("[MainMenu] Anonymous auth success: ", user_id)
	_show_status("Playing as Guest")
	
	# Update UserManager with guest data
	var user_data = {
		"user_id": user_id,
		"display_name": "Guest",
		"email": "",
		"photo_url": "",
		"provider": "anonymous",
		"is_linked": false
	}
	UserManager.update_user_data(user_data)
	_update_user_ui()


func _on_anonymous_auth_failed(error: String) -> void:
	print("[MainMenu] Anonymous auth failed: ", error)
	_show_status("Guest login failed: " + error)


func _set_main_buttons_visible(show_buttons: bool) -> void:
	"""Toggle visibility of main menu buttons."""
	if host_button:
		host_button.visible = show_buttons
	if join_button:
		join_button.visible = show_buttons
	if exit_button:
		exit_button.visible = show_buttons


func _on_settings_pressed() -> void:
	print("[MainMenu] Opening settings panel")
	if settings_panel:
		settings_panel.visible = true
		# Hide main menu buttons when panel is open
		_set_main_buttons_visible(false)
		# Hide the settings button when panel is open
		if settings_control:
			settings_control.hide_button()
		# Make sure user profile panel is hidden when opening settings
		if user_profile_panel:
			user_profile_panel.visible = false
		# Update slider to current volume
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(volume_slider.value)) + "%"


func _on_back_settings_pressed() -> void:
	print("[MainMenu] Closing settings panel")
	if settings_panel:
		settings_panel.visible = false
	# Show main menu buttons again when panel is closed
	_set_main_buttons_visible(true)
	# Show the settings button again when panel is closed
	if settings_control:
		settings_control.show_button()
	_save_settings()


func _on_view_user_profile_pressed() -> void:
	print("[MainMenu] Opening user profile panel")
	if user_profile_panel:
		user_profile_panel.visible = true
	# Hide the view user profile button while in profile view
	if view_user_profile_button:
		view_user_profile_button.visible = false


func _on_back_from_profile_pressed() -> void:
	print("[MainMenu] Closing user profile panel")
	if user_profile_panel:
		user_profile_panel.visible = false
	# Show the view user profile button again
	if view_user_profile_button:
		view_user_profile_button.visible = true


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
	
	# NOTE: Removed automatic IP detection - only room codes are used
	# This prevents confusion and forces the discovery-based connection flow
	# If direct IP is needed for debugging, use the "LOCAL" code instead
	
	_show_status("Searching for game with code: " + code + "...")
	print("[MainMenu] Starting discovery for code: ", code)
	
	var result = await NetworkManager.join_game_with_code(code)
	
	print("[MainMenu] Join result: ", result)
	
	if not result.success:
		print("[MainMenu] Join failed: ", result.get("error", "Unknown"))
		
		# Show error popup with retry option
		_show_join_error_with_retry(result.get("error", "Unknown error"), code)
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


func _show_join_error_with_retry(error_msg: String, code: String) -> void:
	"""Show join error with option to retry."""
	print("[MainMenu] Showing error with retry: ", error_msg)
	
	# Show popup again with error message
	if sidekick_popup:
		sidekick_popup.visible = true
	
	if code_input:
		code_input.text = code
		code_input.placeholder_text = "Try again or check Wi-Fi"
		code_input.grab_focus()
	
	# Show helpful error message
	var helpful_error = error_msg + "\n\nTips:\n• Ensure both devices on same Wi-Fi\n• Try re-entering the code\n• Ask host to restart hosting"
	_show_status(helpful_error)
	
	# Shake the popup
	if sidekick_popup:
		var tween = create_tween()
		tween.tween_property(sidekick_popup, "position:x", sidekick_popup.position.x + 10, 0.05)
		tween.tween_property(sidekick_popup, "position:x", sidekick_popup.position.x - 10, 0.05)
		tween.tween_property(sidekick_popup, "position:x", sidekick_popup.position.x, 0.05)


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


func _exit_tree() -> void:
	"""Clean up signals when leaving the scene."""
	# Disconnect network signals
	if NetworkManager.connection_established.is_connected(_on_connection_established):
		NetworkManager.connection_established.disconnect(_on_connection_established)
	if NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.disconnect(_on_connection_failed)
	if NetworkManager.player_joined.is_connected(_on_player_joined):
		NetworkManager.player_joined.disconnect(_on_player_joined)
	if NetworkManager.role_assignment_received.is_connected(_on_role_assigned):
		NetworkManager.role_assignment_received.disconnect(_on_role_assigned)
	if NetworkManager.room_code_generated.is_connected(_on_room_code_generated):
		NetworkManager.room_code_generated.disconnect(_on_room_code_generated)
	if NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.disconnect(_on_game_started)
	
	# Disconnect auth signals
	if FirebaseAuth.google_auth_success.is_connected(_on_google_auth_success):
		FirebaseAuth.google_auth_success.disconnect(_on_google_auth_success)
	if FirebaseAuth.google_auth_failed.is_connected(_on_google_auth_failed):
		FirebaseAuth.google_auth_failed.disconnect(_on_google_auth_failed)
	if FirebaseAuth.account_linked_success.is_connected(_on_account_linked):
		FirebaseAuth.account_linked_success.disconnect(_on_account_linked)
	if FirebaseAuth.account_link_failed.is_connected(_on_link_failed):
		FirebaseAuth.account_link_failed.disconnect(_on_link_failed)
	if FirebaseAuth.auth_success.is_connected(_on_anonymous_auth_success):
		FirebaseAuth.auth_success.disconnect(_on_anonymous_auth_success)
	if FirebaseAuth.auth_failed.is_connected(_on_anonymous_auth_failed):
		FirebaseAuth.auth_failed.disconnect(_on_anonymous_auth_failed)
	
	# Disconnect UserManager signals
	if UserManager.user_data_changed.is_connected(_on_user_data_changed):
		UserManager.user_data_changed.disconnect(_on_user_data_changed)
	if UserManager.profile_picture_loaded.is_connected(_on_profile_picture_loaded):
		UserManager.profile_picture_loaded.disconnect(_on_profile_picture_loaded)
