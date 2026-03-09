extends Control

const ANIMATION_DURATION := 0.15
const ARROW_SCALE_DEFAULT := Vector2(0.28, 0.28)
const ARROW_SCALE_PRESSED := Vector2(0.24, 0.24)
const AVATAR_BOUNCE_HEIGHT := 10.0

# Settings keys
const SETTINGS_FILE = "user://settings.json"

@onready var settings_control: CanvasLayer = $SettingsControl
@onready var settings_panel: Panel = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $SettingsPanel/VolumeSliderControl/VolumeValue
@onready var back_button_settings: TouchScreenButton = $SettingsPanel/Back
@onready var view_user_profile_button: Button = $SettingsPanel/ViewUserProfile
@onready var user_profile_panel: Panel = $SettingsPanel/UserProfile
@onready var user_profile_back_button: TouchScreenButton = $SettingsPanel/UserProfile/BackToPrevious

# User Auth UI (inside UserProfile panel)
@onready var avatar_texture: TextureRect = $SettingsPanel/UserProfile/UserContent/AvatarTexture
@onready var display_name_label: Label = $SettingsPanel/UserProfile/UserContent/UserInfo/DisplayName
@onready var provider_label: Label = $SettingsPanel/UserProfile/UserContent/UserInfo/ProviderLabel
@onready var sign_in_button: Button = $SettingsPanel/UserProfile/AuthButtons/SignInButton
@onready var guest_button: Button = $SettingsPanel/UserProfile/AuthButtons/GuestButton
@onready var link_google_button: Button = $SettingsPanel/UserProfile/AuthButtons/LinkGoogleButton

@onready var start_button: Button = %StartButton
@onready var back_button: TextureButton = %BackButton
@onready var room_code_label: Label = $RoomCode
@onready var status_label: Label = $StatusLabel
@onready var connection_indicator: Panel = get_node_or_null("ConnectionIndicator")

# Detective Area
@onready var detective_area: Control = $DetectiveArea
@onready var detective_left_btn: TextureButton = %DetectiveLeftBtn
@onready var detective_right_btn: TextureButton = %DetectiveRightBtn
@onready var detective_select_btn: Button = %DetectiveSelectBtn
@onready var detective_costume_label: Label = %DetectiveCostumeName
@onready var player_host: CharacterBody2D = $DetectiveArea/PlayerHost
@onready var detective_sprite: AnimatedSprite2D = $DetectiveArea/PlayerHost/AnimatedSprite2D
@onready var detective_name_label: Label = $DetectiveArea/PlayerHost/DetectiveName

# Sidekick Area
@onready var sidekick_area: Control = $SidekickArea
@onready var sidekick_left_btn: TextureButton = %SidekickLeftBtn
@onready var sidekick_right_btn: TextureButton = %SidekickRightBtn
@onready var sidekick_select_btn: Button = %SidekickSelectBtn
@onready var sidekick_costume_label: Label = %SidekickCostumeName
@onready var player_sidekick: CharacterBody2D = $SidekickArea/PlayerSidekick
@onready var sidekick_sprite: AnimatedSprite2D = $SidekickArea/PlayerSidekick/AnimatedSprite2D
@onready var sidekick_name_label: Label = $SidekickArea/PlayerSidekick/SidekickName


var sidekick_connected: bool = false
var _detective_costume_index: int = 0
var _sidekick_costume_index: int = 0
var _detective_costumes: Array = []
var _sidekick_costumes: Array = []
var _is_leaving: bool = false  # Prevents RPCs when changing scenes


func _ready() -> void:
	_setup_audio()
	_setup_avatars()
	_setup_costume_data()
	_setup_ui_visibility()
	_connect_signals()
	_setup_button_animations()
	
	# Load saved settings
	_load_settings()
	
	# Initialize User Auth UI
	_connect_auth_signals()
	_update_user_ui()
	
	# Initial UI update
	_update_costume_display("detective")
	_update_costume_display("sidekick")
	_update_connection_indicator()


func _exit_tree() -> void:
	_is_leaving = true
	_disconnect_signals()


func _setup_audio() -> void:
	"""Ensure main menu music is playing."""
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)


func _setup_avatars() -> void:
	"""Configure avatar sprites for display mode."""
	if player_host:
		player_host.set_physics_process(false)
	if player_sidekick:
		player_sidekick.set_physics_process(false)
	
	if detective_sprite:
		detective_sprite.play("idle")
	if sidekick_sprite:
		sidekick_sprite.play("idle")


func _setup_costume_data() -> void:
	"""Initialize costume arrays from GameState."""
	_detective_costumes = GameState.get_costumes_for_role("detective")
	_sidekick_costumes = GameState.get_costumes_for_role("sidekick")


func _setup_ui_visibility() -> void:
	"""Show/hide UI based on player role."""
	var my_role := NetworkManager.get_my_role()
	
	if my_role == "detective":
		_setup_detective_ui()
	else:
		_setup_sidekick_ui()
	
	_setup_base_lobby_ui()


func _setup_detective_ui() -> void:
	"""Configure UI for Detective player."""
	# Show detective controls
	_detective_set_controls_visible(true)
	# Hide sidekick controls, show only avatar + "?"
	_sidekick_set_controls_visible(false)


func _setup_sidekick_ui() -> void:
	"""Configure UI for Sidekick player."""
	# Hide detective controls, show only avatar + "?"
	_detective_set_controls_visible(false)
	# Show sidekick controls
	_sidekick_set_controls_visible(true)


func _detective_set_controls_visible(controls_visible: bool) -> void:
	"""Set visibility of detective costume controls.
	Costume label is always visible, but controls only for local player."""
	# Controls only visible for local player
	if is_instance_valid(detective_left_btn):
		detective_left_btn.visible = controls_visible
	if is_instance_valid(detective_right_btn):
		detective_right_btn.visible = controls_visible
	if is_instance_valid(detective_select_btn):
		detective_select_btn.visible = controls_visible
	# Costume label always visible
	if is_instance_valid(detective_costume_label):
		detective_costume_label.visible = true


func _sidekick_set_controls_visible(controls_visible: bool) -> void:
	"""Set visibility of sidekick costume controls.
	Costume label hidden until partner connects, controls only for local player."""
	# Controls only visible for local player
	if is_instance_valid(sidekick_left_btn):
		sidekick_left_btn.visible = controls_visible
	if is_instance_valid(sidekick_right_btn):
		sidekick_right_btn.visible = controls_visible
	if is_instance_valid(sidekick_select_btn):
		sidekick_select_btn.visible = controls_visible
	# Costume label hidden until partner connects (synced with sprite visibility)
	if is_instance_valid(sidekick_costume_label):
		sidekick_costume_label.visible = sidekick_connected


func _setup_base_lobby_ui() -> void:
	"""Configure base lobby elements based on role."""
	if NetworkManager.get_my_role() == "detective":
		start_button.visible = false
		start_button.disabled = true
		
		var invite_code := NetworkManager.get_invite_code()
		
		# Only show room code, NOT the IP (for security and cleaner UI)
		if not invite_code.is_empty():
			room_code_label.text = "Code: %s" % invite_code
		else:
			room_code_label.text = "Code: ???"
		
		print("[DetectiveLobby] Room Code: ", invite_code)
		
		# Sidekick elements hidden initially
		if sidekick_sprite:
			sidekick_sprite.visible = false
		if sidekick_name_label:
			sidekick_name_label.visible = false
	else:
		start_button.visible = false
		room_code_label.visible = false
		status_label.text = "Connected! Waiting for Detective to start..."


func _connect_signals() -> void:
	"""Connect all necessary signals."""
	# GameState signals
	if not GameState.costume_changed.is_connected(_on_costume_changed):
		GameState.costume_changed.connect(_on_costume_changed)
	if not GameState.costume_confirmed.is_connected(_on_costume_confirmed):
		GameState.costume_confirmed.connect(_on_costume_confirmed)
	
	# NetworkManager signals
	if not NetworkManager.room_code_generated.is_connected(_on_room_code_generated):
		NetworkManager.room_code_generated.connect(_on_room_code_generated)
	if not NetworkManager.partner_connected.is_connected(_on_partner_connected):
		NetworkManager.partner_connected.connect(_on_partner_connected)
	if not NetworkManager.partner_disconnected.is_connected(_on_partner_disconnected):
		NetworkManager.partner_disconnected.connect(_on_partner_disconnected)
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)
	
	# Settings signals
	if settings_control and not settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.connect(_on_settings_pressed)
	
	# Settings panel signals
	if back_button_settings and not back_button_settings.pressed.is_connected(_on_back_settings_pressed):
		back_button_settings.pressed.connect(_on_back_settings_pressed)
	
	if volume_slider and not volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.connect(_on_volume_changed)
	
	# View User Profile button
	if view_user_profile_button and not view_user_profile_button.pressed.is_connected(_on_view_user_profile_pressed):
		view_user_profile_button.pressed.connect(_on_view_user_profile_pressed)
	
	# Back from profile button
	if user_profile_back_button and not user_profile_back_button.pressed.is_connected(_on_back_from_profile_pressed):
		user_profile_back_button.pressed.connect(_on_back_from_profile_pressed)


func _disconnect_signals() -> void:
	"""Disconnect all signals to prevent callbacks after scene change."""
	var signals := [
		[GameState.costume_changed, _on_costume_changed],
		[GameState.costume_confirmed, _on_costume_confirmed],
		[NetworkManager.room_code_generated, _on_room_code_generated],
		[NetworkManager.partner_connected, _on_partner_connected],
		[NetworkManager.partner_disconnected, _on_partner_disconnected],
		[NetworkManager.game_started, _on_game_started],
		[NetworkManager.connection_failed, _on_connection_failed]
	]
	
	for sig_data in signals:
		var sig: Signal = sig_data[0]
		var callback: Callable = sig_data[1]
		if sig.is_connected(callback):
			sig.disconnect(callback)
	
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


func _setup_button_animations() -> void:
	"""Setup button press animations."""
	var arrow_buttons := [detective_left_btn, detective_right_btn, sidekick_left_btn, sidekick_right_btn]
	
	for btn in arrow_buttons:
		btn.pressed.connect(_on_arrow_pressed.bind(btn))
		btn.button_down.connect(_on_arrow_down.bind(btn))
		btn.button_up.connect(_on_arrow_up.bind(btn))


# ============================================
# USER AUTH FUNCTIONS
# ============================================

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
		var display_text = user_data.display_name if not user_data.display_name.is_empty() else "Guest"
		if FirebaseAuth.TEST_MODE:
			display_text += " [TEST]"
		display_name_label.text = display_text
	
	# Update provider label and button visibility
	if provider_label:
		var provider_text = ""
		match user_data.provider:
			"google":
				provider_text = "Google Account"
				if link_google_button:
					link_google_button.visible = false
				if sign_in_button:
					sign_in_button.visible = false
				if guest_button:
					guest_button.visible = false
			"anonymous":
				provider_text = "Guest"
				if FirebaseAuth.TEST_MODE:
					provider_text += " (Test Mode)"
				if link_google_button:
					link_google_button.visible = true
				if sign_in_button:
					sign_in_button.visible = true
				if guest_button:
					guest_button.visible = true
		provider_label.text = provider_text
	
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


func _on_sign_in_pressed() -> void:
	print("[DetectiveLobby] Sign in button pressed")
	FirebaseAuth.sign_in_with_google()


func _on_guest_pressed() -> void:
	print("[DetectiveLobby] Guest button pressed - starting anonymous login")
	FirebaseAuth.anonymous_login()


func _on_link_google_pressed() -> void:
	print("[DetectiveLobby] Link Google button pressed")
	if not FirebaseAuth.is_authenticated:
		return
	
	# Store current anonymous UID before linking
	UserManager.update_user_data({"anonymous_uid": FirebaseAuth.current_user_id})
	
	# Start Google sign-in flow for linking
	FirebaseAuth.link_with_google()


func _on_google_auth_success(user_data: Dictionary) -> void:
	print("[DetectiveLobby] Google sign-in success: ", user_data.get("display_name", "Unknown"))
	
	# Update UserManager
	UserManager.update_user_data(user_data)
	
	# Save to Firestore (skip in test mode)
	if not FirebaseAuth.TEST_MODE:
		FirebaseFirestore.save_user_profile(user_data.user_id, user_data)
	
	# Load profile picture if available
	if not user_data.photo_url.is_empty():
		UserManager.load_profile_picture(user_data.photo_url)
	
	# Update UI
	_update_user_ui()


func _on_google_auth_failed(error: String) -> void:
	print("[DetectiveLobby] Google sign-in failed: ", error)


func _on_account_linked(user_data: Dictionary) -> void:
	print("[DetectiveLobby] Account linked successfully")
	
	# Update with linked status
	user_data["is_linked"] = true
	UserManager.update_user_data(user_data)
	
	# Save to Firestore
	FirebaseFirestore.save_user_profile(user_data.user_id, user_data)
	
	# Update UI
	_update_user_ui()


func _on_link_failed(error: String) -> void:
	print("[DetectiveLobby] Account link failed: ", error)


func _on_anonymous_auth_success(user_id: String, _token: String) -> void:
	print("[DetectiveLobby] Anonymous auth success: ", user_id)
	
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
	print("[DetectiveLobby] Anonymous auth failed: ", error)


func _set_main_buttons_visible(show_buttons: bool) -> void:
	"""Toggle visibility of main lobby buttons.
	In DetectiveLobby, only the Back button needs to be hidden when settings opens.
	The settings button is handled by settings_control.hide_button()/show_button().
	"""
	if back_button:
		back_button.visible = show_buttons


func _on_settings_pressed() -> void:
	print("[DetectiveLobby] Opening settings panel")
	if settings_panel:
		settings_panel.visible = true
		# Hide back button when settings panel opens
		_set_main_buttons_visible(false)
		# Hide the settings button when panel is open
		if settings_control:
			settings_control.hide_button()
		# Make sure user profile panel is hidden when opening settings
		if user_profile_panel:
			user_profile_panel.visible = false
		# Show view user profile button
		if view_user_profile_button:
			view_user_profile_button.visible = true
		# Update slider to current volume
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(volume_slider.value)) + "%"


func _on_back_settings_pressed() -> void:
	print("[DetectiveLobby] Closing settings panel")
	if settings_panel:
		settings_panel.visible = false
	# Also hide user profile panel
	if user_profile_panel:
		user_profile_panel.visible = false
	# Show back button again when settings panel closes
	_set_main_buttons_visible(true)
	# Show the settings button again when panel is closed
	if settings_control:
		settings_control.show_button()
	_save_settings()


func _on_view_user_profile_pressed() -> void:
	print("[DetectiveLobby] Opening user profile panel")
	if user_profile_panel:
		user_profile_panel.visible = true
	# Hide the view user profile button while in profile view
	if view_user_profile_button:
		view_user_profile_button.visible = false


func _on_back_from_profile_pressed() -> void:
	print("[DetectiveLobby] Closing user profile panel")
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
	print("[DetectiveLobby] Volume changed to: ", volume)


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
					print("[DetectiveLobby] Settings loaded successfully")
			else:
				push_warning("[DetectiveLobby] Failed to parse settings file")
			file.close()
	else:
		print("[DetectiveLobby] No settings file found, using defaults")


func _save_settings() -> void:
	var data = {
		"volume": MusicController.get_volume()
	}
	
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("[DetectiveLobby] Settings saved successfully")
	else:
		push_warning("[DetectiveLobby] Failed to save settings file")


func _on_arrow_pressed(btn: TextureButton) -> void:
	"""Animate arrow button press."""
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", ARROW_SCALE_PRESSED, ANIMATION_DURATION)
	tween.tween_property(btn, "scale", ARROW_SCALE_DEFAULT, ANIMATION_DURATION)


func _on_arrow_down(btn: TextureButton) -> void:
	"""Visual feedback when arrow is held down."""
	var tween := create_tween()
	tween.tween_property(btn, "scale", ARROW_SCALE_PRESSED, ANIMATION_DURATION * 0.5)


func _on_arrow_up(btn: TextureButton) -> void:
	"""Visual feedback when arrow is released."""
	var tween := create_tween()
	tween.tween_property(btn, "scale", ARROW_SCALE_DEFAULT, ANIMATION_DURATION * 0.5)


func _animate_avatar_bounce(role: String) -> void:
	"""Animate avatar bounce when costume changes."""
	var avatar := player_host if role == "detective" else player_sidekick
	if not avatar:
		return
	
	var original_y := avatar.position.y
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(avatar, "position:y", original_y - AVATAR_BOUNCE_HEIGHT, 0.1)
	tween.tween_property(avatar, "position:y", original_y, 0.3)


func _animate_costume_confirmed(role: String) -> void:
	"""Animate costume confirmation visual feedback."""
	var label := detective_costume_label if role == "detective" else sidekick_costume_label
	var btn := detective_select_btn if role == "detective" else sidekick_select_btn
	
	# Flash the label
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color(0.5, 1, 0.5), 0.2)
	tween.tween_property(label, "modulate", Color(1, 1, 1), 0.2)
	
	# Scale button down then up
	var btn_tween := create_tween()
	btn_tween.set_trans(Tween.TRANS_BACK)
	btn_tween.set_ease(Tween.EASE_OUT)
	btn_tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	btn_tween.tween_property(btn, "scale", Vector2(1, 1), 0.2)


func _on_detective_left_pressed() -> void:
	# Reset confirmation when trying to change costume
	if GameState.is_costume_confirmed("detective"):
		GameState.confirm_costume_selection("detective", false)
	
	if _detective_costumes.size() <= 1:
		return
	_detective_costume_index = wrapi(_detective_costume_index - 1, 0, _detective_costumes.size())
	_change_costume("detective", _detective_costume_index)


func _on_detective_right_pressed() -> void:
	# Reset confirmation when trying to change costume
	if GameState.is_costume_confirmed("detective"):
		GameState.confirm_costume_selection("detective", false)
	
	if _detective_costumes.size() <= 1:
		return
	_detective_costume_index = wrapi(_detective_costume_index + 1, 0, _detective_costumes.size())
	_change_costume("detective", _detective_costume_index)


func _on_detective_select_pressed() -> void:
	_confirm_costume("detective")


func _on_sidekick_left_pressed() -> void:
	if _sidekick_costumes.size() <= 1:
		return
	_sidekick_costume_index = wrapi(_sidekick_costume_index - 1, 0, _sidekick_costumes.size())
	_change_costume("sidekick", _sidekick_costume_index)


func _on_sidekick_right_pressed() -> void:
	if _sidekick_costumes.size() <= 1:
		return
	_sidekick_costume_index = wrapi(_sidekick_costume_index + 1, 0, _sidekick_costumes.size())
	_change_costume("sidekick", _sidekick_costume_index)


func _on_sidekick_select_pressed() -> void:
	_confirm_costume("sidekick")


func _change_costume(role: String, index: int) -> void:
	"""Change costume selection and sync to network."""
	var costumes := _detective_costumes if role == "detective" else _sidekick_costumes
	if index < 0 or index >= costumes.size():
		return
	
	var costume: Dictionary = costumes[index]
	GameState.set_selected_costume(role, costume.id)
	
	# Reset confirmation when changing costume (player needs to confirm new selection)
	if GameState.is_costume_confirmed(role):
		GameState.confirm_costume_selection(role, false)
	
	_update_costume_display(role)
	_animate_avatar_bounce(role)
	
	# Sync to network (safely)
	if _is_network_available():
		NetworkManager.sync_costume_preview(role, costume.id)


func _confirm_costume(role: String) -> void:
	"""Confirm costume selection."""
	if GameState.is_costume_confirmed(role):
		return
	
	GameState.confirm_costume_selection(role, true)
	
	# Sync confirmation (safely)
	if _is_network_available():
		NetworkManager.sync_costume_confirmed(role, GameState.get_selected_costume(role))
	
	_animate_costume_confirmed(role)
	_update_costume_display(role)


func _update_costume_display(role: String) -> void:
	"""Update costume display for the given role."""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	var my_role := NetworkManager.get_my_role()
	var is_local_player := (role == my_role)
	
	var costume_id := GameState.get_selected_costume(role)
	var costume := GameState.get_costume_by_id(role, costume_id)
	var is_confirmed := GameState.is_costume_confirmed(role)
	
	if is_local_player:
		# Show full controls for local player
		if role == "detective":
			if is_instance_valid(detective_costume_label):
				detective_costume_label.text = costume.get("name", "Classic Outfit")
				detective_costume_label.modulate = Color(1, 1, 1, 1)
			if is_instance_valid(detective_select_btn):
				detective_select_btn.text = "✓ Selected!" if is_confirmed else "Select Costume"
				detective_select_btn.disabled = is_confirmed
		else:
			if is_instance_valid(sidekick_costume_label):
				sidekick_costume_label.text = costume.get("name", "Classic Outfit")
				sidekick_costume_label.modulate = Color(1, 1, 1, 1)
			if is_instance_valid(sidekick_select_btn):
				sidekick_select_btn.text = "✓ Selected!" if is_confirmed else "Select Costume"
				sidekick_select_btn.disabled = is_confirmed
	else:
		# Show only costume name for partner (no controls)
		if role == "detective":
			if is_instance_valid(detective_costume_label):
				if is_confirmed:
					detective_costume_label.text = costume.get("name", "Classic Outfit")
					detective_costume_label.modulate = Color(1, 0.95, 0.8, 1)
				else:
					detective_costume_label.text = "Classic Outfit"
					detective_costume_label.modulate = Color(0.8, 0.8, 0.8, 1)
		else:
			if is_instance_valid(sidekick_costume_label):
				if is_confirmed:
					sidekick_costume_label.text = costume.get("name", "Classic Outfit")
					sidekick_costume_label.modulate = Color(1, 0.95, 0.8, 1)
				else:
					sidekick_costume_label.text = "Classic Outfit"
					sidekick_costume_label.modulate = Color(0.8, 0.8, 0.8, 1)


func _on_costume_changed(_role: String, _costume_id: String) -> void:
	_update_costume_display("detective")
	_update_costume_display("sidekick")


func _on_costume_confirmed(_role: String, _confirmed: bool) -> void:
	_update_costume_display("detective")
	_update_costume_display("sidekick")


func _is_network_available() -> bool:
	"""Check if network is available for RPC calls."""
	return not _is_leaving and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0 and is_inside_tree()


func _update_connection_indicator() -> void:
	"""Update the connection status indicator color."""
	if not is_instance_valid(connection_indicator):
		return
	
	var stylebox := StyleBoxFlat.new()
	if sidekick_connected:
		stylebox.bg_color = Color(0.2, 0.9, 0.2)  # Green
	else:
		stylebox.bg_color = Color(0.9, 0.2, 0.2)  # Red
	stylebox.corner_radius_top_left = 30
	stylebox.corner_radius_top_right = 30
	stylebox.corner_radius_bottom_right = 30
	stylebox.corner_radius_bottom_left = 30
	connection_indicator.add_theme_stylebox_override("panel", stylebox)


func _on_room_code_generated(code: String) -> void:
	if NetworkManager.get_my_role() == "detective":
		# Only show room code, NOT the IP
		room_code_label.text = "Code: %s" % code
		room_code_label.modulate = Color(1, 0.9, 0.2)
		print("[DetectiveLobby] Room Code: ", code)


func _on_partner_connected(data: Dictionary) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	sidekick_connected = true
	_update_connection_indicator()
	
	if NetworkManager.get_my_role() == "detective":
		var partner_name: String = data.get("display_name", "Sidekick")
		
		if is_instance_valid(status_label):
			status_label.text = "Sidekick connected!"
			status_label.modulate = Color(1, 1, 0)
		
		if is_instance_valid(start_button):
			start_button.visible = true
			start_button.disabled = false
		
		# Show sidekick sprite and costume label with fade in
		if is_instance_valid(sidekick_sprite):
			sidekick_sprite.visible = true
			sidekick_sprite.modulate = Color(1, 1, 1, 0)
			var tween := create_tween()
			tween.tween_property(sidekick_sprite, "modulate", Color(1, 1, 1, 1), 0.5)
		
		if is_instance_valid(sidekick_name_label):
			sidekick_name_label.visible = true
			sidekick_name_label.text = partner_name
		
		if is_instance_valid(sidekick_costume_label):
			sidekick_costume_label.visible = true
		
		# Send costume state to new sidekick via NetworkManager
		_send_costume_state_with_delay()
	else:
		if is_instance_valid(status_label):
			status_label.text = "Connected! Waiting for host to start..."
			status_label.modulate = Color(0, 1, 0)


func _send_costume_state_with_delay() -> void:
	"""Send costume state to client after a short delay to ensure scene is loaded."""
	await get_tree().create_timer(0.5).timeout
	
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	var peers := multiplayer.get_peers()
	if peers.size() > 0:
		NetworkManager.send_costume_state_to_client(peers[0])


func _on_partner_disconnected(_data: Dictionary) -> void:
	sidekick_connected = false
	_update_connection_indicator()
	
	if NetworkManager.get_my_role() == "detective":
		if is_instance_valid(status_label):
			status_label.text = "Sidekick disconnected!\nWaiting..."
			status_label.modulate = Color(1, 0, 0)
		
		if is_instance_valid(start_button):
			start_button.visible = false
			start_button.disabled = true
		
		if is_instance_valid(sidekick_sprite):
			sidekick_sprite.visible = false
		if is_instance_valid(sidekick_name_label):
			sidekick_name_label.visible = false
		if is_instance_valid(sidekick_costume_label):
			sidekick_costume_label.visible = false


func _on_start_pressed() -> void:
	if NetworkManager.get_my_role() != "detective":
		return
	
	if not sidekick_connected:
		return
	
	if is_instance_valid(start_button):
		start_button.disabled = true
	if is_instance_valid(status_label):
		status_label.text = "Starting game..."
	
	var success := NetworkManager.start_game()
	
	if not success:
		if is_instance_valid(status_label):
			status_label.text = "Failed to start game"
		if is_instance_valid(start_button):
			start_button.disabled = false
	else:
		if is_instance_valid(status_label):
			status_label.text = "Game starting!"


func _on_back_pressed() -> void:
	_is_leaving = true
	
	# Hide settings button and panel during transition
	if settings_control:
		settings_control.hide_button()
	if settings_panel:
		settings_panel.visible = false
	
	# Notify sidekick before disconnecting
	if sidekick_connected:
		NetworkManager.notify_host_leaving()
		# Wait for RPC to be sent
		await get_tree().create_timer(0.2).timeout
	
	# Disconnect first to stop any further RPC processing
	NetworkManager.disconnect_network()
	
	# Wait for any in-flight RPCs to be processed before changing scene
	await get_tree().create_timer(0.5).timeout
	
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _on_game_started(_checkpoint: String = "") -> void:
	_is_leaving = true
	
	# Hide settings button and panel during transition
	if settings_control:
		settings_control.hide_button()
	if settings_panel:
		settings_panel.visible = false
	
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished
	
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	var tree := get_tree()
	if tree == null:
		return
	
	tree.change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


func _on_connection_failed(error: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = "Connection failed: %s" % error
		status_label.modulate = Color(1, 0, 0)
