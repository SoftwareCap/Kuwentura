extends Control
## Sidekick Waiting Lobby - Costume Selection & Connection
## Handles costume selection UI and connection to host for sidekick player

# ============================================================================
# CONSTANTS
# ============================================================================
const ANIMATION_DURATION := 0.15
const ARROW_SCALE_DEFAULT := Vector2(0.28, 0.28)
const ARROW_SCALE_PRESSED := Vector2(0.24, 0.24)
const AVATAR_BOUNCE_HEIGHT := 10.0
const SETTINGS_FILE = "user://settings.json"

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var status_label: Label = $StatusLabel
@onready var cancel_button: TextureButton = %CancelButton
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

# Settings
@onready var settings_control: CanvasLayer = $SettingsControl
@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_overlay: ColorRect = $SettingsOverlay
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $SettingsPanel/VolumeSliderControl/VolumeValue

# User Profile
@onready var view_user_profile_button: Button = $SettingsPanel/ViewUserProfile
@onready var user_section: Panel = $SettingsPanel/UserSection
@onready var user_section_back_button: TouchScreenButton = $SettingsPanel/UserSection/Back

# ============================================================================
# STATE VARIABLES
# ============================================================================
var _sidekick_costume_index: int = 0
var _sidekick_costumes: Array = []
var _host_connected: bool = false
var _is_leaving: bool = false  # Prevents RPCs when changing scenes

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	if not status_label:
		return
	
	_setup_audio()
	_setup_avatars()
	_setup_costume_data()
	_setup_ui_visibility()
	_connect_signals()
	_setup_button_animations()
	_setup_settings()
	
	# Initial UI update
	_update_costume_display()
	_update_connection_indicator()
	
	# Check for rejoin scenario
	_call_join_if_playing()


func _exit_tree() -> void:
	_is_leaving = true
	_disconnect_signals()


# ============================================================================
# SETUP FUNCTIONS
# ============================================================================
func _setup_audio() -> void:
	"""Ensure main menu music is playing."""
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)


func _setup_avatars() -> void:
	"""Configure avatar sprites for display mode."""
	if player_host:
		player_host.set_physics_process(false)
	if player_sidekick:
		player_sidekick.set_physics_process(false)
	
	# Make avatars visible by default
	if detective_sprite:
		detective_sprite.play("idle")
		detective_sprite.visible = true
	if sidekick_sprite:
		sidekick_sprite.play("idle")
		sidekick_sprite.visible = true
	
	# Make name labels visible
	if detective_name_label:
		detective_name_label.visible = true
	if sidekick_name_label:
		sidekick_name_label.visible = true


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
	Costume label always visible to show detective's costume selection."""
	# Controls hidden for partner (detective controls on sidekick screen)
	var detective_left = get_node_or_null("DetectiveArea/DetectiveLeftBtn")
	var detective_right = get_node_or_null("DetectiveArea/DetectiveRightBtn")
	var detective_select = get_node_or_null("DetectiveArea/DetectiveSelectBtn")
	
	var detective_btns = [detective_left, detective_right, detective_select]
	for btn in detective_btns:
		if is_instance_valid(btn):
			btn.visible = controls_visible
	
	# Costume label always visible to show detective's costume name
	var label: Label = get_node_or_null("DetectiveArea/DetectiveCostumeName")
	if is_instance_valid(label):
		label.visible = true


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
	if not NetworkManager.rejoin_game_requested.is_connected(_on_rejoin_game_requested):
		NetworkManager.rejoin_game_requested.connect(_on_rejoin_game_requested)
	
	if not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Sidekick costume selection buttons
	if sidekick_left_btn and not sidekick_left_btn.pressed.is_connected(_on_sidekick_left_pressed):
		sidekick_left_btn.pressed.connect(_on_sidekick_left_pressed)
	if sidekick_right_btn and not sidekick_right_btn.pressed.is_connected(_on_sidekick_right_pressed):
		sidekick_right_btn.pressed.connect(_on_sidekick_right_pressed)
	if sidekick_select_btn and not sidekick_select_btn.pressed.is_connected(_on_sidekick_select_pressed):
		sidekick_select_btn.pressed.connect(_on_sidekick_select_pressed)


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
		[NetworkManager.connection_state_changed, _on_connection_state_changed],
		[NetworkManager.rejoin_game_requested, _on_rejoin_game_requested]
	]
	
	for sig_data in signals:
		var sig: Signal = sig_data[0]
		var callback: Callable = sig_data[1]
		if sig.is_connected(callback):
			sig.disconnect(callback)
	
	# Disconnect settings signals
	if settings_control and settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.disconnect(_on_settings_pressed)
	
	# Disconnect sidekick button signals
	if sidekick_left_btn and sidekick_left_btn.pressed.is_connected(_on_sidekick_left_pressed):
		sidekick_left_btn.pressed.disconnect(_on_sidekick_left_pressed)
	if sidekick_right_btn and sidekick_right_btn.pressed.is_connected(_on_sidekick_right_pressed):
		sidekick_right_btn.pressed.disconnect(_on_sidekick_right_pressed)
	if sidekick_select_btn and sidekick_select_btn.pressed.is_connected(_on_sidekick_select_pressed):
		sidekick_select_btn.pressed.disconnect(_on_sidekick_select_pressed)


func _setup_button_animations() -> void:
	"""Setup button press animations for sidekick arrows."""
	if not sidekick_left_btn or not sidekick_right_btn:
		push_warning("[SidekickWaiting] Arrow buttons not found!")
		return
	
	var arrow_buttons := [sidekick_left_btn, sidekick_right_btn]
	
	for btn in arrow_buttons:
		if is_instance_valid(btn):
			btn.button_down.connect(_on_arrow_down.bind(btn))
			btn.button_up.connect(_on_arrow_up.bind(btn))


# ============================================================================
# ANIMATION FUNCTIONS
# ============================================================================
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
	if not is_instance_valid(sidekick_costume_label) or not is_instance_valid(sidekick_select_btn):
		return
	
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


# ============================================================================
# COSTUME SELECTION HANDLERS
# ============================================================================
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
	
	# Ensure labels are visible
	if is_instance_valid(sidekick_costume_label):
		sidekick_costume_label.visible = true
	if is_instance_valid(detective_costume_label):
		detective_costume_label.visible = true
	
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


# ============================================================================
# NETWORK FUNCTIONS
# ============================================================================
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


# ============================================================================
# CONNECTION & GAME START
# ============================================================================
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
	
	# Sidekick screen always shows avatars immediately (no need to wait for connection)
	# Connection status is shown via the connection indicator
	_host_connected = NetworkManager.has_active_connection()
	_update_connection_indicator()
	
	# Ensure avatars are visible
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
	
	# Update costume display to show both players' selections
	_update_costume_display()
	
	# Update status based on connection
	if _host_connected:
		status_label.text = "Connected to Host!"
		status_label.modulate = Color(0, 1, 0)
	else:
		status_label.text = "Waiting for Host..."
		status_label.modulate = Color(1, 1, 0)


func _on_connection_established(_peer_id: int, _role: int = 0) -> void:
	_host_connected = true
	_update_connection_indicator()
	
	if is_instance_valid(status_label):
		status_label.text = "Connected!\nWaiting for Detective to start..."
		status_label.modulate = Color(0, 1, 0)
	
	if is_instance_valid(sidekick_sprite):
		sidekick_sprite.visible = true
		sidekick_sprite.play("idle")
		sidekick_sprite.modulate = Color(1, 1, 1, 0)
		var tween := create_tween()
		tween.tween_property(sidekick_sprite, "modulate", Color(1, 1, 1, 1), 0.5)
	
	if is_instance_valid(sidekick_name_label):
		sidekick_name_label.visible = true
	
	# Show detective costume label and update display
	if is_instance_valid(detective_costume_label):
		detective_costume_label.visible = true
	
	# Update costume display to show detective's selection
	_update_costume_display()


func _on_partner_connected(_data: Dictionary) -> void:
	_host_connected = true
	_update_connection_indicator()
	if is_instance_valid(status_label):
		status_label.text = "Connected!\nWaiting for Detective to start..."
		status_label.modulate = Color(0, 1, 0)
	
	# Ensure avatars are visible on partner connect
	if is_instance_valid(sidekick_sprite):
		sidekick_sprite.visible = true
		sidekick_sprite.play("idle")
	if is_instance_valid(detective_sprite):
		detective_sprite.visible = true
		detective_sprite.play("idle")


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
	if settings_overlay:
		settings_overlay.visible = false
	
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished
	
	_change_to_game()


func _on_rejoin_game_requested(_world_state: Dictionary) -> void:
	"""Called when sidekick needs to rejoin an active game session."""
	print("[SidekickWaiting] Rejoining active game session, going directly to forest...")
	
	if not is_inside_tree():
		return
	
	_is_leaving = true
	
	# Hide settings button and panel during transition
	if settings_control:
		settings_control.hide_button()
	if settings_panel:
		settings_panel.visible = false
	if settings_overlay:
		settings_overlay.visible = false
	
	# Same fade transition as regular game start
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
	
	await get_tree().create_timer(2.0).timeout
	_return_to_menu()


func _on_connection_state_changed(new_state: int, _old_state: int) -> void:
	if new_state == 0:  # DISCONNECTED
		_is_leaving = true
		status_label.text = "Connection lost!\nReturning to menu..."
		status_label.modulate = Color(1, 0, 0)
		
		await get_tree().create_timer(2.0).timeout
		_return_to_menu()


func _on_cancel_pressed() -> void:
	_is_leaving = true
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


# ============================================================================
# SETTINGS FUNCTIONS
# ============================================================================
func _setup_settings() -> void:
	"""Setup settings panel and signals."""
	# Connect settings signals
	if settings_control and not settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.connect(_on_settings_pressed)
	
	# Load saved settings
	_load_settings()
	
	# Update slider to current volume
	if volume_slider:
		volume_slider.value = MusicController.get_volume() * 100
	if volume_value_label:
		volume_value_label.text = str(int(volume_slider.value)) + "%"


func _on_settings_pressed() -> void:
	print("[SidekickWaiting] Opening settings panel")
	if settings_panel:
		settings_panel.visible = true
	if settings_overlay:
		settings_overlay.visible = true
		# Hide user section when opening settings
	if user_section:
		user_section.visible = false
		# Show view user profile button when opening settings
	if view_user_profile_button:
		view_user_profile_button.visible = true
	# Hide settings button
	if settings_control:
		settings_control.hide_button()


func _on_back_settings_pressed() -> void:
	print("[SidekickWaiting] Closing settings panel")
	if settings_panel:
		settings_panel.visible = false
	if settings_overlay:
		settings_overlay.visible = false
	# Show settings button again
	if settings_control:
		settings_control.show_button()
	_save_settings()


func _on_view_user_profile_pressed() -> void:
	print("[SidekickWaiting] Opening user profile")
	if user_section:
		user_section.visible = true
	if view_user_profile_button:
		view_user_profile_button.visible = false


func _on_back_from_profile_pressed() -> void:
	print("[SidekickWaiting] Back from user profile to settings")
	if user_section:
		user_section.visible = false
	if view_user_profile_button:
		view_user_profile_button.visible = true


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
