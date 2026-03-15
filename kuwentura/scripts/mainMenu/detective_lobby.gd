extends Control
## Detective Lobby - Costume Selection & Matchmaking
## Handles costume selection UI, network synchronization, and game start

# ============================================================================
# CONSTANTS
# ============================================================================
const ANIMATION_DURATION := 0.15
const ARROW_SCALE_DEFAULT := Vector2(0.28, 0.28)
const ARROW_SCALE_PRESSED := Vector2(0.24, 0.24)
const AVATAR_BOUNCE_HEIGHT := 10.0
const SETTINGS_FILE = "user://settings.json"

# ============================================================================
# NODE REFERENCES - UI Elements
# ============================================================================
@onready var start_button: Button = %StartButton
@onready var back_button: TextureButton = %BackButton
@onready var room_code_label: Label = $RoomCode
@onready var status_label: Label = $StatusLabel
@onready var connection_indicator: Panel = get_node_or_null("ConnectionIndicator")

# Settings
@onready var settings_control: CanvasLayer = $SettingsControl
@onready var settings_panel: Panel = $SettingsLayer/SettingsPanel
@onready var volume_slider: HSlider = $SettingsLayer/SettingsPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $SettingsLayer/SettingsPanel/VolumeSliderControl/VolumeValue
@onready var settings_back_button: TouchScreenButton = $SettingsLayer/SettingsPanel/Back
@onready var input_blocker: ColorRect = $InputBlockerLayer/InputBlocker

# User Profile
@onready var view_user_profile_button: Button = $SettingsLayer/SettingsPanel/ViewUserProfile
@onready var user_section: Panel = $SettingsLayer/SettingsPanel/UserSection
@onready var user_section_back_button: TouchScreenButton = $SettingsLayer/SettingsPanel/UserSection/Back

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

# ============================================================================
# STATE VARIABLES
# ============================================================================
var sidekick_connected: bool = false
var _detective_costume_index: int = 0
var _sidekick_costume_index: int = 0
var _detective_costumes: Array = []
var _sidekick_costumes: Array = []
var _is_leaving: bool = false  # Prevents RPCs when changing scenes

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	_setup_audio()
	_setup_avatars()
	_setup_costume_data()
	_setup_ui_visibility()
	_connect_signals()
	_setup_button_animations()
	_setup_settings()
	
	# Initial UI update
	_update_costume_display("detective")
	_update_costume_display("sidekick")
	_update_connection_indicator()


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
		room_code_label.text = "Code: %s" % invite_code if not invite_code.is_empty() else "Code: ???"
		status_label.text = "Waiting for Sidekick..."
		status_label.modulate = Color(1, 1, 1)
		
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
	
	# Disconnect settings signals
	if settings_control and settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.disconnect(_on_settings_pressed)
	
	# Disconnect button handlers
	if is_instance_valid(detective_left_btn) and detective_left_btn.pressed.is_connected(_on_detective_left_pressed):
		detective_left_btn.pressed.disconnect(_on_detective_left_pressed)
	if is_instance_valid(detective_right_btn) and detective_right_btn.pressed.is_connected(_on_detective_right_pressed):
		detective_right_btn.pressed.disconnect(_on_detective_right_pressed)
	if is_instance_valid(detective_select_btn) and detective_select_btn.pressed.is_connected(_on_detective_select_pressed):
		detective_select_btn.pressed.disconnect(_on_detective_select_pressed)
	if is_instance_valid(sidekick_left_btn) and sidekick_left_btn.pressed.is_connected(_on_sidekick_left_pressed):
		sidekick_left_btn.pressed.disconnect(_on_sidekick_left_pressed)
	if is_instance_valid(sidekick_right_btn) and sidekick_right_btn.pressed.is_connected(_on_sidekick_right_pressed):
		sidekick_right_btn.pressed.disconnect(_on_sidekick_right_pressed)
	if is_instance_valid(sidekick_select_btn) and sidekick_select_btn.pressed.is_connected(_on_sidekick_select_pressed):
		sidekick_select_btn.pressed.disconnect(_on_sidekick_select_pressed)


func _setup_button_animations() -> void:
	"""Setup button press animations and connect button handlers."""
	# Arrow buttons with animations
	var arrow_buttons := [detective_left_btn, detective_right_btn, sidekick_left_btn, sidekick_right_btn]
	
	for btn in arrow_buttons:
		if is_instance_valid(btn):
			btn.pressed.connect(_on_arrow_pressed.bind(btn))
			btn.button_down.connect(_on_arrow_down.bind(btn))
			btn.button_up.connect(_on_arrow_up.bind(btn))
	
	# Connect costume selection button handlers
	if is_instance_valid(detective_left_btn) and not detective_left_btn.pressed.is_connected(_on_detective_left_pressed):
		detective_left_btn.pressed.connect(_on_detective_left_pressed)
	if is_instance_valid(detective_right_btn) and not detective_right_btn.pressed.is_connected(_on_detective_right_pressed):
		detective_right_btn.pressed.connect(_on_detective_right_pressed)
	if is_instance_valid(detective_select_btn) and not detective_select_btn.pressed.is_connected(_on_detective_select_pressed):
		detective_select_btn.pressed.connect(_on_detective_select_pressed)
	
	if is_instance_valid(sidekick_left_btn) and not sidekick_left_btn.pressed.is_connected(_on_sidekick_left_pressed):
		sidekick_left_btn.pressed.connect(_on_sidekick_left_pressed)
	if is_instance_valid(sidekick_right_btn) and not sidekick_right_btn.pressed.is_connected(_on_sidekick_right_pressed):
		sidekick_right_btn.pressed.connect(_on_sidekick_right_pressed)
	if is_instance_valid(sidekick_select_btn) and not sidekick_select_btn.pressed.is_connected(_on_sidekick_select_pressed):
		sidekick_select_btn.pressed.connect(_on_sidekick_select_pressed)


# ============================================================================
# ANIMATION FUNCTIONS
# ============================================================================
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


# ============================================================================
# COSTUME SELECTION HANDLERS
# ============================================================================
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
	if sidekick_connected:
		stylebox.bg_color = Color(0.2, 0.9, 0.2)  # Green
	else:
		stylebox.bg_color = Color(0.9, 0.2, 0.2)  # Red
	stylebox.corner_radius_top_left = 30
	stylebox.corner_radius_top_right = 30
	stylebox.corner_radius_bottom_right = 30
	stylebox.corner_radius_bottom_left = 30
	connection_indicator.add_theme_stylebox_override("panel", stylebox)





# ============================================================================
# NETWORK CALLBACKS
# ============================================================================
func _on_room_code_generated(code: String) -> void:
	if NetworkManager.get_my_role() == "detective":
		room_code_label.text = "Code: %s" % code
		room_code_label.modulate = Color(1, 0.9, 0.2)


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


func _on_partner_disconnected(data: Dictionary) -> void:
	print("[DetectiveLobby] Partner disconnected: ", data)
	sidekick_connected = false
	_update_connection_indicator()
	
	if NetworkManager.get_my_role() == "detective":
		if is_instance_valid(status_label):
			status_label.text = "Sidekick disconnected!\nWaiting..."
			status_label.modulate = Color(1, 0, 0)
		
		if is_instance_valid(start_button):
			start_button.visible = false
			start_button.disabled = true
		
		# Hide sidekick avatar and all related UI
		if is_instance_valid(sidekick_sprite):
			sidekick_sprite.visible = false
		if is_instance_valid(sidekick_name_label):
			sidekick_name_label.visible = false
		if is_instance_valid(sidekick_costume_label):
			sidekick_costume_label.visible = false
		
		# Reset sidekick costume controls visibility
		_sidekick_set_controls_visible(false)
		
		# Reset sidekick costume for next connection
		GameState.set_selected_costume("sidekick", "default")
		GameState.confirm_costume_selection("sidekick", false)
		_update_costume_display("sidekick")
		
		print("[DetectiveLobby] Sidekick UI hidden and costume reset")


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
	
	# Hide settings button, panel, and input blocker during transition
	if settings_control:
		settings_control.hide_button()
	if settings_panel:
		settings_panel.visible = false
	if input_blocker:
		input_blocker.visible = false
	
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
	print("[DetectiveLobby] Opening settings panel")
	# Block input to underlying elements
	if input_blocker:
		input_blocker.visible = true
	if settings_panel:
		settings_panel.visible = true
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
	print("[DetectiveLobby] Closing settings panel")
	if settings_panel:
		settings_panel.visible = false
	# Unblock input when settings is closed
	if input_blocker:
		input_blocker.visible = false
	# Show settings button again
	if settings_control:
		settings_control.show_button()
	_save_settings()


func _on_view_user_profile_pressed() -> void:
	print("[DetectiveLobby] Opening user profile")
	if user_section:
		user_section.visible = true
	if view_user_profile_button:
		view_user_profile_button.visible = false


func _on_back_from_profile_pressed() -> void:
	print("[DetectiveLobby] Back from user profile to settings")
	if user_section:
		user_section.visible = false
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
