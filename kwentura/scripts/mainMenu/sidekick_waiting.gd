extends Control
## Sidekick Waiting Lobby - Costume Selection & Connection
## Handles costume selection UI and connection to host for sidekick player


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

# User Auth UI
@onready var avatar_texture: TextureRect = $SettingsPanel/UserSection/UserContent/AvatarTexture
@onready var display_name_label: Label = $SettingsPanel/UserSection/UserContent/UserInfo/DisplayName
@onready var provider_label: Label = $SettingsPanel/UserSection/UserContent/UserInfo/ProviderLabel
@onready var sign_in_button: Button = $SettingsPanel/UserSection/AuthButtons/SignInButton
@onready var guest_button: Button = $SettingsPanel/UserSection/AuthButtons/GuestButton
@onready var link_google_button: Button = $SettingsPanel/UserSection/AuthButtons/LinkGoogleButton

@onready var status_label: Label = $StatusLabel
@onready var cancel_button: Button = %CancelButton
@onready var connection_indicator: Panel = get_node_or_null("ConnectionIndicator")

# Detective Area (Hidden controls)
@onready var detective_area: Control = $DetectiveArea
@onready var player_host: CharacterBody2D = $DetectiveArea/PlayerHost
@onready var detective_sprite: AnimatedSprite2D = $DetectiveArea/PlayerHost/AnimatedSprite2D
@onready var detective_name_label: Label = $DetectiveArea/PlayerHost/DetectiveName
@onready var detective_costume_label: Label = %DetectiveCostumeName

# Sidekick Area (Active controls)
@onready var sidekick_area: Control = $SidekickArea
@onready var sidekick_left_btn: TextureButton = %SidekickLeftBtn
@onready var sidekick_right_btn: TextureButton = %SidekickRightBtn
@onready var sidekick_select_btn: Button = %SidekickSelectBtn
@onready var sidekick_costume_label: Label = %SidekickCostumeName
@onready var player_sidekick: CharacterBody2D = $SidekickArea/PlayerSidekick
@onready var sidekick_sprite: AnimatedSprite2D = $SidekickArea/PlayerSidekick/AnimatedSprite2D
@onready var sidekick_name_label: Label = $SidekickArea/PlayerSidekick/SidekickName


var _sidekick_costume_index: int = 0
var _sidekick_costumes: Array = []
var _host_connected: bool = false
var _is_leaving: bool = false  # Prevents RPCs when changing scenes


func _ready() -> void:
	if not status_label:
		return
	
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
	_update_costume_display()
	_update_connection_indicator()
	
	# Check for rejoin scenario
	_call_join_if_playing()


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
	_sidekick_costumes = GameState.get_costumes_for_role("sidekick")


func _setup_ui_visibility() -> void:
	"""Show/hide UI based on sidekick role."""
	# Detective area: Hide ALL controls, show only avatar + "?"
	_detective_set_controls_visible(false)
	
	# Sidekick area: Show all controls
	_sidekick_set_controls_visible(true)


func _detective_set_controls_visible(controls_visible: bool) -> void:
	"""Set visibility of detective costume controls.
	Costume label hidden until host connects, controls only for local player."""
	# Controls hidden for partner
	var detective_btns = [$DetectiveArea/DetectiveLeftBtn, $DetectiveArea/DetectiveRightBtn, $DetectiveArea/DetectiveSelectBtn]
	for btn in detective_btns:
		if is_instance_valid(btn):
			btn.visible = controls_visible
	
	# Costume label hidden until host connects (synced with sprite visibility)
	var label: Label = $DetectiveArea/DetectiveCostumeName
	if is_instance_valid(label):
		label.visible = _host_connected


func _sidekick_set_controls_visible(controls_visible: bool) -> void:
	"""Set visibility of sidekick costume controls.
	Costume label is always visible, but controls only for local player."""
	# Controls only visible for local player
	if is_instance_valid(sidekick_left_btn):
		sidekick_left_btn.visible = controls_visible
	if is_instance_valid(sidekick_right_btn):
		sidekick_right_btn.visible = controls_visible
	if is_instance_valid(sidekick_select_btn):
		sidekick_select_btn.visible = controls_visible
	# Costume label always visible
	if is_instance_valid(sidekick_costume_label):
		sidekick_costume_label.visible = true


func _connect_signals() -> void:
	"""Connect all necessary signals."""
	# GameState signals
	if not GameState.costume_changed.is_connected(_on_costume_changed):
		GameState.costume_changed.connect(_on_costume_changed)
	if not GameState.costume_confirmed.is_connected(_on_costume_confirmed):
		GameState.costume_confirmed.connect(_on_costume_confirmed)
	
	# NetworkManager signals
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)
	if not NetworkManager.partner_disconnected.is_connected(_on_host_disconnected):
		NetworkManager.partner_disconnected.connect(_on_host_disconnected)
	if not NetworkManager.partner_connected.is_connected(_on_partner_connected):
		NetworkManager.partner_connected.connect(_on_partner_connected)
	if not NetworkManager.connection_established.is_connected(_on_connection_established):
		NetworkManager.connection_established.connect(_on_connection_established)
	if not NetworkManager.connection_state_changed.is_connected(_on_connection_state_changed):
		NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
	
	if not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Settings signals
	if settings_control and not settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.connect(_on_settings_pressed)
	
	# Settings panel signals
	if back_button_settings and not back_button_settings.pressed.is_connected(_on_back_settings_pressed):
		back_button_settings.pressed.connect(_on_back_settings_pressed)
	
	if volume_slider and not volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.connect(_on_volume_changed)


func _disconnect_signals() -> void:
	"""Disconnect all signals."""
	var signals := [
		[GameState.costume_changed, _on_costume_changed],
		[GameState.costume_confirmed, _on_costume_confirmed],
		[NetworkManager.game_started, _on_game_started],
		[NetworkManager.connection_failed, _on_connection_failed],
		[NetworkManager.partner_disconnected, _on_host_disconnected],
		[NetworkManager.partner_connected, _on_partner_connected],
		[NetworkManager.connection_established, _on_connection_established],
		[NetworkManager.connection_state_changed, _on_connection_state_changed]
	]
	
	for sig_data in signals:
		var sig: Signal = sig_data[0]
		var callback: Callable = sig_data[1]
		if sig.is_connected(callback):
			sig.disconnect(callback)
	
	# Disconnect settings signals
	if settings_control and settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.disconnect(_on_settings_pressed)
	if back_button_settings and back_button_settings.pressed.is_connected(_on_back_settings_pressed):
		back_button_settings.pressed.disconnect(_on_back_settings_pressed)
	if volume_slider and volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.disconnect(_on_volume_changed)


func _on_settings_pressed() -> void:
	print("[SidekickWaiting] Opening settings panel")
	if settings_panel:
		settings_panel.visible = true
		# Update slider to current volume
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(volume_slider.value)) + "%"


func _on_back_settings_pressed() -> void:
	print("[SidekickWaiting] Closing settings panel")
	if settings_panel:
		settings_panel.visible = false
	_save_settings()


func _on_volume_changed(value: float) -> void:
	var volume = value / 100.0
	MusicController.set_volume(volume)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"
	print("[SidekickWaiting] Volume changed to: ", volume)


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
					print("[SidekickWaiting] Settings loaded successfully")
			else:
				push_warning("[SidekickWaiting] Failed to parse settings file")
			file.close()
	else:
		print("[SidekickWaiting] No settings file found, using defaults")


func _save_settings() -> void:
	var data = {
		"volume": MusicController.get_volume()
	}
	
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("[SidekickWaiting] Settings saved successfully")
	else:
		push_warning("[SidekickWaiting] Failed to save settings file")


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


func _on_sign_in_pressed() -> void:
	print("[SidekickWaiting] Sign in button pressed")
	FirebaseAuth.sign_in_with_google()


func _on_guest_pressed() -> void:
	print("[SidekickWaiting] Guest button pressed")


func _on_link_google_pressed() -> void:
	print("[SidekickWaiting] Link Google button pressed")
	if not FirebaseAuth.is_authenticated:
		return
	
	# Store current anonymous UID before linking
	UserManager.update_user_data({"anonymous_uid": FirebaseAuth.current_user_id})
	
	# Start Google sign-in flow for linking
	FirebaseAuth.link_with_google()


func _on_google_auth_success(user_data: Dictionary) -> void:
	print("[SidekickWaiting] Google sign-in success")
	
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
	print("[SidekickWaiting] Google sign-in failed: ", error)


func _on_account_linked(user_data: Dictionary) -> void:
	print("[SidekickWaiting] Account linked successfully")
	
	# Update with linked status
	user_data["is_linked"] = true
	UserManager.update_user_data(user_data)
	
	# Save to Firestore
	FirebaseFirestore.save_user_profile(user_data.user_id, user_data)
	
	# Update UI
	_update_user_ui()


func _on_link_failed(error: String) -> void:
	print("[SidekickWaiting] Account link failed: ", error)


func _setup_button_animations() -> void:
	"""Setup button press animations for sidekick arrows."""
	var arrow_buttons := [sidekick_left_btn, sidekick_right_btn]
	
	for btn in arrow_buttons:
		btn.button_down.connect(_on_arrow_down.bind(btn))
		btn.button_up.connect(_on_arrow_up.bind(btn))


func _on_arrow_down(btn: TextureButton) -> void:
	"""Visual feedback when arrow is held down."""
	var tween := create_tween()
	tween.tween_property(btn, "scale", ARROW_SCALE_PRESSED, ANIMATION_DURATION * 0.5)


func _on_arrow_up(btn: TextureButton) -> void:
	"""Visual feedback when arrow is released."""
	var tween := create_tween()
	tween.tween_property(btn, "scale", ARROW_SCALE_DEFAULT, ANIMATION_DURATION * 0.5)


func _animate_avatar_bounce() -> void:
	"""Animate avatar bounce when costume changes."""
	if not player_sidekick:
		return
	
	var original_y := player_sidekick.position.y
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(player_sidekick, "position:y", original_y - AVATAR_BOUNCE_HEIGHT, 0.1)
	tween.tween_property(player_sidekick, "position:y", original_y, 0.3)


func _animate_costume_confirmed() -> void:
	"""Animate costume confirmation visual feedback."""
	# Flash the label
	var tween := create_tween()
	tween.tween_property(sidekick_costume_label, "modulate", Color(0.5, 1, 0.5), 0.2)
	tween.tween_property(sidekick_costume_label, "modulate", Color(1, 1, 1), 0.2)
	
	# Scale button
	var btn_tween := create_tween()
	btn_tween.set_trans(Tween.TRANS_BACK)
	btn_tween.set_ease(Tween.EASE_OUT)
	btn_tween.tween_property(sidekick_select_btn, "scale", Vector2(0.95, 0.95), 0.1)
	btn_tween.tween_property(sidekick_select_btn, "scale", Vector2(1, 1), 0.2)


func _on_sidekick_left_pressed() -> void:
	# Reset confirmation when trying to change costume
	if GameState.is_costume_confirmed("sidekick"):
		GameState.confirm_costume_selection("sidekick", false)
	
	if _sidekick_costumes.size() <= 1:
		return
	_sidekick_costume_index = wrapi(_sidekick_costume_index - 1, 0, _sidekick_costumes.size())
	_change_costume(_sidekick_costume_index)


func _on_sidekick_right_pressed() -> void:
	# Reset confirmation when trying to change costume
	if GameState.is_costume_confirmed("sidekick"):
		GameState.confirm_costume_selection("sidekick", false)
	
	if _sidekick_costumes.size() <= 1:
		return
	_sidekick_costume_index = wrapi(_sidekick_costume_index + 1, 0, _sidekick_costumes.size())
	_change_costume(_sidekick_costume_index)


func _on_sidekick_select_pressed() -> void:
	_confirm_costume()


func _change_costume(index: int) -> void:
	"""Change costume selection and sync to network."""
	if index < 0 or index >= _sidekick_costumes.size():
		return
	
	var costume: Dictionary = _sidekick_costumes[index]
	GameState.set_selected_costume("sidekick", costume.id)
	
	# Reset confirmation when changing costume (player needs to confirm new selection)
	if GameState.is_costume_confirmed("sidekick"):
		GameState.confirm_costume_selection("sidekick", false)
	
	_update_costume_display()
	_animate_avatar_bounce()
	
	# Sync to network
	if _is_network_available():
		NetworkManager.sync_costume_preview("sidekick", costume.id)


func _confirm_costume() -> void:
	"""Confirm costume selection."""
	if GameState.is_costume_confirmed("sidekick"):
		return
	
	GameState.confirm_costume_selection("sidekick", true)
	
	if _is_network_available():
		NetworkManager.sync_costume_confirmed("sidekick", GameState.get_selected_costume("sidekick"))
	
	_animate_costume_confirmed()
	_update_costume_display()


func _update_costume_display() -> void:
	"""Update costume display for sidekick and show partner's costume."""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	# Update local player (sidekick) display
	var costume_id := GameState.get_selected_costume("sidekick")
	var costume := GameState.get_costume_by_id("sidekick", costume_id)
	var is_confirmed := GameState.is_costume_confirmed("sidekick")
	
	if is_instance_valid(sidekick_costume_label):
		sidekick_costume_label.text = costume.get("name", "Classic Outfit")
		sidekick_costume_label.modulate = Color(1, 1, 1, 1)
	
	if is_instance_valid(sidekick_select_btn):
		sidekick_select_btn.text = "✓ Selected!" if is_confirmed else "Select Costume"
		sidekick_select_btn.disabled = is_confirmed
	
	# Update partner (detective) display - show costume name if confirmed
	var partner_costume_id := GameState.get_selected_costume("detective")
	var partner_costume := GameState.get_costume_by_id("detective", partner_costume_id)
	var partner_confirmed := GameState.is_costume_confirmed("detective")
	
	if is_instance_valid(detective_costume_label):
		if partner_confirmed:
			detective_costume_label.text = partner_costume.get("name", "Classic Outfit")
			detective_costume_label.modulate = Color(1, 0.95, 0.8, 1)  # Gold tint for confirmed
		else:
			detective_costume_label.text = "Classic Outfit"  # Default before selection
			detective_costume_label.modulate = Color(0.8, 0.8, 0.8, 1)  # Gray for unconfirmed


func _on_costume_changed(_role: String, _costume_id: String) -> void:
	_update_costume_display()


func _on_costume_confirmed(_role: String, _confirmed: bool) -> void:
	_update_costume_display()


func _is_network_available() -> bool:
	"""Check if network is available for RPC calls."""
	return not _is_leaving and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0 and is_inside_tree()


func _update_connection_indicator() -> void:
	"""Update the connection status indicator color."""
	if not is_instance_valid(connection_indicator):
		return
	
	var stylebox := StyleBoxFlat.new()
	if _host_connected:
		stylebox.bg_color = Color(0.2, 0.9, 0.2)  # Green
	else:
		stylebox.bg_color = Color(0.9, 0.2, 0.2)  # Red
	stylebox.corner_radius_top_left = 30
	stylebox.corner_radius_top_right = 30
	stylebox.corner_radius_bottom_right = 30
	stylebox.corner_radius_bottom_left = 30
	connection_indicator.add_theme_stylebox_override("panel", stylebox)


func _call_join_if_playing() -> void:
	"""Check if game is already in progress (rejoining scenario)."""
	await get_tree().process_frame
	
	if not is_inside_tree():
		return
	
	if NetworkManager.is_playing():
		_change_to_game()
		return
	
	await get_tree().create_timer(0.5).timeout
	
	if not is_inside_tree():
		return
	
	if NetworkManager.is_playing():
		_change_to_game()
		return
	
	# Connection established - show both avatars and costume labels
	_host_connected = true
	_update_connection_indicator()
	
	if detective_sprite:
		detective_sprite.visible = true
		detective_sprite.play("idle")
	if detective_name_label:
		detective_name_label.visible = true
	if detective_costume_label:
		detective_costume_label.visible = true
	
	if sidekick_sprite:
		sidekick_sprite.visible = true
		sidekick_sprite.play("idle")
	if sidekick_name_label:
		sidekick_name_label.visible = true
	
	status_label.text = "Connected to Host!"
	status_label.modulate = Color(1, 1, 0)


func _on_connection_established(_peer_id: int) -> void:
	_host_connected = true
	_update_connection_indicator()
	
	status_label.text = "Connected!\nWaiting for Detective to start..."
	status_label.modulate = Color(0, 1, 0)
	
	if sidekick_sprite:
		sidekick_sprite.visible = true
		sidekick_sprite.play("idle")
		sidekick_sprite.modulate = Color(1, 1, 1, 0)
		var tween := create_tween()
		tween.tween_property(sidekick_sprite, "modulate", Color(1, 1, 1, 1), 0.5)
	
	if sidekick_name_label:
		sidekick_name_label.visible = true
	
	# Note: Detective avatar and costume label visibility is handled by _call_join_if_playing


func _on_partner_connected(_data: Dictionary) -> void:
	_host_connected = true
	_update_connection_indicator()
	status_label.text = "Connected!\nWaiting for Detective to start..."
	status_label.modulate = Color(0, 1, 0)


func _on_game_started(_checkpoint: String = "") -> void:
	if not is_inside_tree():
		return
	
	_is_leaving = true
	status_label.text = "Starting game..."
	
	# Hide settings button and panel during transition
	if settings_control:
		settings_control.hide_button()
	if settings_panel:
		settings_panel.visible = false
	
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished
	
	_change_to_game()


func _change_to_game() -> void:
	"""Safely change to game scene."""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	var tree := get_tree()
	if tree == null:
		return
	
	tree.change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


func _on_connection_failed(error: String) -> void:
	var error_msg := "Cannot connect to game.\n\nPlease check:\n"
	error_msg += "• Both devices on same Wi-Fi\n"
	error_msg += "• Room code is correct\n"
	error_msg += "• Detective is hosting\n"
	error_msg += "\nError: %s" % error
	
	status_label.text = error_msg
	status_label.modulate = Color(1, 0, 0)
	
	await get_tree().create_timer(5.0).timeout
	_return_to_menu()


func _on_host_disconnected(_data: Dictionary = {}) -> void:
	_is_leaving = true
	status_label.text = "Detective disconnected!\nReturning to menu..."
	status_label.modulate = Color(1, 0, 0)
	
	# Hide settings button and panel during transition
	if settings_control:
		settings_control.hide_button()
	if settings_panel:
		settings_panel.visible = false
	
	await get_tree().create_timer(2.0).timeout
	_return_to_menu()


func _on_connection_state_changed(new_state: int, _old_state: int) -> void:
	if new_state == 0:  # DISCONNECTED
		_is_leaving = true
		status_label.text = "Connection lost!\nReturning to menu..."
		status_label.modulate = Color(1, 0, 0)
		
		# Hide settings button and panel during transition
		if settings_control:
			settings_control.hide_button()
		if settings_panel:
			settings_panel.visible = false
		
		await get_tree().create_timer(2.0).timeout
		_return_to_menu()


func _on_cancel_pressed() -> void:
	_is_leaving = true
	
	# Hide settings button and panel during transition
	if settings_control:
		settings_control.hide_button()
	if settings_panel:
		settings_panel.visible = false
	
	NetworkManager.disconnect_network()
	
	# Wait for disconnect and any in-flight RPCs to be processed
	await get_tree().create_timer(0.5).timeout
	
	_return_to_menu()


func _return_to_menu() -> void:
	"""Safely return to main menu."""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	var tree := get_tree()
	if tree == null:
		return
	
	tree.change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")
