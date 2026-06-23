extends Control
## Sidekick Waiting Lobby - Costume Selection & Connection
## Handles costume selection UI and connection to host for sidekick player

# CONSTANTS
const ANIMATION_DURATION := 0.15
const ARROW_SCALE_DEFAULT := Vector2(0.28, 0.28)
const ARROW_SCALE_PRESSED := Vector2(0.24, 0.24)
const AVATAR_BOUNCE_HEIGHT := 10.0
const FADE_DURATION := 0.2
const SETTINGS_FILE := "user://settings.json"
const SCENE_MAIN_MENU := "res://scenes/mainMenu/MainMenu.tscn"
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const SCENE_BAKUNAWA := "res://scenes/world/climax/Bakunawa.tscn"
const SCENE_OPENING_CUTSCENE := "res://scenes/cutscenes/opening/OpeningCutscene.tscn"
const SCENE_MOBILE_OPENING_CUTSCENE := "res://scenes/cutscenes/opening/MobileOpeningCutscene.tscn"
const DEV_SKIP_OPENING_CUTSCENE := false

# UI colors
const COLOR_NORMAL := Color(1, 1, 1, 1)
const COLOR_CONFIRMED := Color(1, 0.95, 0.8, 1)
const COLOR_UNCONFIRMED := Color(0.8, 0.8, 0.8, 1)
const COLOR_FLASH_GREEN := Color(0.5, 1, 0.5, 1)
const COLOR_SUCCESS := Color(0, 1, 0, 1)
const COLOR_WARNING := Color(1, 1, 0, 1)
const COLOR_ERROR := Color(1, 0, 0, 1)

# NODE REFERENCES
@onready var status_label: Label = $StatusLabel
@onready var cancel_button: TextureButton = %CancelButton
@onready var connection_indicator: Panel = get_node_or_null("ConnectionIndicator")

# Detective Area
@onready var detective_area: Control = $DetectiveArea
@onready var detective_left_btn: TextureButton = get_node_or_null("DetectiveArea/DetectiveLeftBtn")
@onready var detective_right_btn: TextureButton = get_node_or_null("DetectiveArea/DetectiveRightBtn")
@onready var detective_select_btn: Button = get_node_or_null("DetectiveArea/DetectiveSelectBtn")
@onready var player_host: CharacterBody2D = $DetectiveArea/PlayerHost
@onready var detective_sprite: AnimatedSprite2D = $DetectiveArea/PlayerHost/AnimatedSprite2D
@onready var detective_name_label: Label = $DetectiveArea/PlayerHost/DetectiveName
@onready var detective_costume_label:Label = %DetectiveCostumeName

# Sidekick Area
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
@onready var settings_panel: Panel = $SettingsLayer/SettingsPanel
@onready var volume_slider: HSlider = $SettingsLayer/SettingsPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $SettingsLayer/SettingsPanel/VolumeSliderControl/VolumeValue
@onready var input_blocker: ColorRect = $InputBlockerLayer/InputBlocker
@onready var view_user_profile_button: Button = $SettingsLayer/SettingsPanel/ViewUserProfile
@onready var user_section: Panel = $SettingsLayer/SettingsPanel/UserSection
@onready var user_section_back_button: TouchScreenButton = $SettingsLayer/SettingsPanel/UserSection/Back

# STATE
var _sidekick_costume_index: int = 0
var _sidekick_costumes: Array = []
var _host_connected: bool = false
var _is_leaving: bool = false


# LIFECYCLE
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

	_update_costume_display()
	_update_connection_indicator()
	_call_join_if_playing()


func _exit_tree() -> void:
	_is_leaving = true
	_disconnect_signals()


# SETUP
func _setup_audio() -> void:
	"""Ensure main menu music is playing."""
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)


func _setup_avatars() -> void:
	"""Configure avatar sprites for display mode."""
	for player in [player_host, player_sidekick]:
		if player:
			player.set_physics_process(false)

	for sprite in [detective_sprite, sidekick_sprite]:
		if sprite:
			sprite.play("idle")
			sprite.visible = true

	for label in [detective_name_label, sidekick_name_label]:
		if label:
			label.visible = true


func _setup_costume_data() -> void:
	"""Initialize costume array from GameState."""
	_sidekick_costumes = GameState.get_costumes_for_role("sidekick")


func _setup_ui_visibility() -> void:
	"""Hide detective controls; show all sidekick controls."""
	_set_controls_visible(
		[detective_left_btn, detective_right_btn, detective_select_btn], false
	)
	_set_controls_visible(
		[sidekick_left_btn, sidekick_right_btn, sidekick_select_btn], true
	)
	if is_instance_valid(detective_costume_label):
		detective_costume_label.visible = true
	if is_instance_valid(sidekick_costume_label):
		sidekick_costume_label.visible = true


func _set_controls_visible(buttons: Array, value: bool) -> void:
	"""Set visibility on a list of buttons, guarding each for validity."""
	for btn in buttons:
		if is_instance_valid(btn):
			btn.visible = value


func _connect_signals() -> void:
	"""Connect all necessary signals."""
	var signal_pairs := [
		[GameState.costume_changed, _on_costume_changed],
		[GameState.costume_confirmed, _on_costume_confirmed],
		[NetworkManager.game_started, _on_game_started],
		[NetworkManager.connection_failed, _on_connection_failed],
		[NetworkManager.partner_disconnected, _on_host_disconnected],
		[NetworkManager.partner_connected, _on_partner_connected],
		[NetworkManager.connection_established, _on_connection_established],
		[NetworkManager.connection_state_changed, _on_connection_state_changed],
		[NetworkManager.rejoin_game_requested, _on_rejoin_game_requested],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if not sig.is_connected(cb):
			sig.connect(cb)

	if not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)

	if settings_control and not settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.connect(_on_settings_pressed)


func _disconnect_signals() -> void:
	"""Disconnect all signals to prevent callbacks after scene change."""
	var signal_pairs := [
		[GameState.costume_changed, _on_costume_changed],
		[GameState.costume_confirmed, _on_costume_confirmed],
		[NetworkManager.game_started, _on_game_started],
		[NetworkManager.connection_failed, _on_connection_failed],
		[NetworkManager.partner_disconnected, _on_host_disconnected],
		[NetworkManager.partner_connected, _on_partner_connected],
		[NetworkManager.connection_established, _on_connection_established],
		[NetworkManager.connection_state_changed, _on_connection_state_changed],
		[NetworkManager.rejoin_game_requested, _on_rejoin_game_requested],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)

	if settings_control and settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.disconnect(_on_settings_pressed)

	for btn in [sidekick_left_btn, sidekick_right_btn, sidekick_select_btn]:
		if is_instance_valid(btn):
			btn.pressed.disconnect(_on_navigate_costume if btn != sidekick_select_btn else _on_sidekick_select_pressed)


func _setup_button_animations() -> void:
	"""Connect arrow animation callbacks and navigation handlers."""
	for dir in [[sidekick_left_btn, -1], [sidekick_right_btn, 1]]:
		var btn: TextureButton = dir[0]
		var direction: int = dir[1]
		if is_instance_valid(btn):
			btn.pressed.connect(_on_navigate_costume.bind(direction))
			btn.button_down.connect(_on_arrow_down.bind(btn))
			btn.button_up.connect(_on_arrow_up.bind(btn))

	if is_instance_valid(sidekick_select_btn):
		sidekick_select_btn.pressed.connect(_on_sidekick_select_pressed)


# ANIMATION
func _on_arrow_down(btn: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "scale", ARROW_SCALE_PRESSED, ANIMATION_DURATION * 0.5)


func _on_arrow_up(btn: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "scale", ARROW_SCALE_DEFAULT, ANIMATION_DURATION * 0.5)


func _animate_avatar_bounce() -> void:
	"""Animate avatar bounce when costume changes."""
	if not player_sidekick:
		return
	var original_y: float = player_sidekick.position.y
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(player_sidekick, "position:y", original_y - AVATAR_BOUNCE_HEIGHT, 0.1)
	tween.tween_property(player_sidekick, "position:y", original_y, 0.3)


func _animate_costume_confirmed() -> void:
	"""Flash label and pulse select button on confirmation."""
	if not is_instance_valid(sidekick_costume_label) or not is_instance_valid(sidekick_select_btn):
		return

	var tween := create_tween()
	tween.tween_property(sidekick_costume_label, "modulate", COLOR_FLASH_GREEN, 0.2)
	tween.tween_property(sidekick_costume_label, "modulate", COLOR_NORMAL, 0.2)

	var btn_tween := create_tween()
	btn_tween.set_trans(Tween.TRANS_BACK)
	btn_tween.set_ease(Tween.EASE_OUT)
	btn_tween.tween_property(sidekick_select_btn, "scale", Vector2(0.95, 0.95), 0.1)
	btn_tween.tween_property(sidekick_select_btn, "scale", Vector2.ONE, 0.2)


# COSTUME SELECTION
func _on_navigate_costume(direction: int) -> void:
	"""Navigate sidekick costume in given direction (-1 left, +1 right)."""
	if GameState.is_costume_confirmed("sidekick"):
		GameState.confirm_costume_selection("sidekick", false)

	if _sidekick_costumes.size() <= 1:
		return

	_sidekick_costume_index = wrapi(
		_sidekick_costume_index + direction, 0, _sidekick_costumes.size()
	)
	_change_costume(_sidekick_costume_index)


func _on_sidekick_select_pressed() -> void:
	_confirm_costume()


func _change_costume(index: int) -> void:
	"""Change costume selection and sync to network."""
	if index < 0 or index >= _sidekick_costumes.size():
		return

	var costume: Dictionary = _sidekick_costumes[index]
	GameState.set_selected_costume("sidekick", costume.id)

	if GameState.is_costume_confirmed("sidekick"):
		GameState.confirm_costume_selection("sidekick", false)

	_update_costume_display()
	_animate_avatar_bounce()

	if _is_network_available():
		NetworkManager.sync_costume_preview("sidekick", costume.id)


func _confirm_costume() -> void:
	"""Confirm costume selection and sync to network."""
	if GameState.is_costume_confirmed("sidekick"):
		return

	GameState.confirm_costume_selection("sidekick", true)

	if _is_network_available():
		NetworkManager.sync_costume_confirmed("sidekick", GameState.get_selected_costume("sidekick"))

	_animate_costume_confirmed()
	_update_costume_display()


func _update_costume_display() -> void:
	"""Update costume labels and select button for both roles."""
	if not is_instance_valid(self) or not is_inside_tree():
		return

	if is_instance_valid(sidekick_costume_label):
		sidekick_costume_label.visible = true
	if is_instance_valid(detective_costume_label):
		detective_costume_label.visible = true

	# Local player (sidekick)
	var costume_id := GameState.get_selected_costume("sidekick")
	var costume := GameState.get_costume_by_id("sidekick", costume_id)
	var is_confirmed := GameState.is_costume_confirmed("sidekick")

	if is_instance_valid(sidekick_costume_label):
		sidekick_costume_label.text = costume.get("name", "Classic Outfit")
		sidekick_costume_label.modulate = COLOR_NORMAL

	if is_instance_valid(sidekick_select_btn):
		sidekick_select_btn.text = "âœ“ Selected!" if is_confirmed else "Select Costume"
		sidekick_select_btn.disabled = is_confirmed

	# Partner (detective) â€” read-only display
	var partner_id := GameState.get_selected_costume("detective")
	var partner_costume := GameState.get_costume_by_id("detective", partner_id)
	var partner_confirmed := GameState.is_costume_confirmed("detective")

	if is_instance_valid(detective_costume_label):
		if partner_confirmed:
			detective_costume_label.text = partner_costume.get("name", "Classic Outfit")
			detective_costume_label.modulate = COLOR_CONFIRMED
		else:
			detective_costume_label.text = "Classic Outfit"
			detective_costume_label.modulate = COLOR_UNCONFIRMED


func _on_costume_changed(_role: String, _costume_id: String) -> void:
	_update_costume_display()


func _on_costume_confirmed(_role: String, _confirmed: bool) -> void:
	_update_costume_display()


# NETWORK HELPERS
func _is_network_available() -> bool:
	return not _is_leaving \
		and multiplayer.has_multiplayer_peer() \
		and multiplayer.get_peers().size() > 0 \
		and is_inside_tree()


func _update_connection_indicator() -> void:
	if not is_instance_valid(connection_indicator):
		return
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.9, 0.2) if _host_connected else Color(0.9, 0.2, 0.2)
	stylebox.corner_radius_top_left = 30
	stylebox.corner_radius_top_right = 30
	stylebox.corner_radius_bottom_right = 30
	stylebox.corner_radius_bottom_left = 30
	connection_indicator.add_theme_stylebox_override("panel", stylebox)


func _on_host_connected_state() -> void:
	"""Shared state update when any host-connected signal arrives."""
	_host_connected = true
	_update_connection_indicator()
	if is_instance_valid(status_label):
		status_label.text = "Connected!\nWaiting for Detective to start..."
		status_label.modulate = COLOR_SUCCESS


# CONNECTION & GAME START
func _get_scene_for_checkpoint(checkpoint: String) -> String:
	match checkpoint:
		GameState.START_CHECKPOINT_FOREST_HUB:
			return SCENE_FOREST_HUB
		GameState.START_CHECKPOINT_BAKUNAWA:
			return SCENE_BAKUNAWA
		_:
			return _get_opening_cutscene_scene()


func _get_rejoin_checkpoint(world_state: Dictionary = {}) -> String:
	var start_checkpoint: String = str(world_state.get("start_checkpoint", ""))
	if not start_checkpoint.is_empty():
		return start_checkpoint
	var current_zone: String = str(world_state.get("current_zone", GameState.current_zone))
	if current_zone == GameState.START_CHECKPOINT_BAKUNAWA:
		return GameState.START_CHECKPOINT_BAKUNAWA
	return GameState.START_CHECKPOINT_FOREST_HUB


func _call_join_if_playing() -> void:
	"""Check if game is already in progress (rejoining scenario)."""
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if NetworkManager.is_playing():
		_change_to_game(_get_rejoin_checkpoint())
		return

	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	if NetworkManager.is_playing():
		_change_to_game(_get_rejoin_checkpoint())
		return

	_host_connected = NetworkManager.has_active_connection()
	_update_connection_indicator()
	_update_costume_display()

	if _host_connected:
		status_label.text = "Connected to Host!"
		status_label.modulate = COLOR_SUCCESS
	else:
		status_label.text = "Waiting for Host..."
		status_label.modulate = COLOR_WARNING


func _on_connection_established(_peer_id: int, _role: int = 0) -> void:
	_on_host_connected_state()

	if is_instance_valid(sidekick_sprite):
		sidekick_sprite.visible = true
		sidekick_sprite.modulate = Color(1, 1, 1, 0)
		var tween := create_tween()
		tween.tween_property(sidekick_sprite, "modulate", COLOR_NORMAL, 0.5)

	if is_instance_valid(sidekick_name_label):
		sidekick_name_label.visible = true
	if is_instance_valid(detective_costume_label):
		detective_costume_label.visible = true

	_update_costume_display()


func _on_partner_connected(_data: Dictionary) -> void:
	_on_host_connected_state()

	for sprite in [sidekick_sprite, detective_sprite]:
		if is_instance_valid(sprite):
			sprite.visible = true
			sprite.play("idle")


func _on_game_started(checkpoint: String = "") -> void:
	if not is_inside_tree():
		return
	status_label.text = "Starting game..."
	await _transition_to_game(checkpoint)


func _on_rejoin_game_requested(world_state: Dictionary) -> void:
	if not is_inside_tree():
		return
	await _transition_to_game(_get_rejoin_checkpoint(world_state))


func _transition_to_game(checkpoint: String = GameState.START_CHECKPOINT_OPENING) -> void:
	"""Hide settings UI, fade out, and change to game scene."""
	_is_leaving = true
	if settings_control:
		settings_control.hide_button()
	if settings_panel:
		settings_panel.visible = false
	if input_blocker:
		input_blocker.visible = false

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, FADE_DURATION)
	await tween.finished
	_change_to_game(checkpoint)


func _change_to_game(checkpoint: String = GameState.START_CHECKPOINT_OPENING) -> void:
	"""Safely change to game scene."""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	get_tree().change_scene_to_file(_get_scene_for_checkpoint(checkpoint))


func _get_opening_cutscene_scene() -> String:
	if DEV_SKIP_OPENING_CUTSCENE and OS.is_debug_build():
		return SCENE_FOREST_HUB
	return SCENE_OPENING_CUTSCENE


func _on_connection_failed(error: String) -> void:
	var msg := "Cannot connect to game.\n\nPlease check:\n"
	msg += "â€¢ Both devices on same Wi-Fi\n"
	msg += "â€¢ Room code is correct\n"
	msg += "â€¢ Detective is hosting\n"
	msg += "\nError: %s" % error
	status_label.text = msg
	status_label.modulate = COLOR_ERROR

	await get_tree().create_timer(5.0).timeout
	_return_to_menu()


func _on_host_disconnected(_data: Dictionary = {}) -> void:
	_is_leaving = true
	status_label.text = "Detective disconnected!\nReturning to menu..."
	status_label.modulate = COLOR_ERROR
	await get_tree().create_timer(2.0).timeout
	_return_to_menu()


func _on_connection_state_changed(new_state: int, _old_state: int) -> void:
	if new_state == 0:
		_is_leaving = true
		status_label.text = "Connection lost!\nReturning to menu..."
		status_label.modulate = COLOR_ERROR
		await get_tree().create_timer(2.0).timeout
		_return_to_menu()


func _on_cancel_pressed() -> void:
	_is_leaving = true
	NetworkManager.notify_sidekick_leaving()
	await get_tree().create_timer(0.1).timeout

	NetworkManager.disconnect_network()
	GameState.set_selected_costume("sidekick", "default")
	GameState.confirm_costume_selection("sidekick", false)

	await get_tree().create_timer(0.5).timeout
	_return_to_menu()


func _return_to_menu() -> void:
	"""Safely return to main menu."""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


# SETTINGS
func _setup_settings() -> void:
	"""Setup settings panel and load saved state."""
	_load_settings()
	if volume_slider:
		volume_slider.value = MusicController.get_volume() * 100
	if volume_value_label:
		volume_value_label.text = str(int(volume_slider.value)) + "%"


func _on_settings_pressed() -> void:
	if input_blocker:
		input_blocker.visible = true
	if settings_panel:
		settings_panel.visible = true
		if user_section:
			user_section.visible = false
		if view_user_profile_button:
			view_user_profile_button.visible = true
	if settings_control:
		settings_control.hide_button()


func _on_back_settings_pressed() -> void:
	if settings_panel:
		settings_panel.visible = false
	if input_blocker:
		input_blocker.visible = false
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
		push_warning("[SidekickWaiting] Failed to open settings file for reading")
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_warning("[SidekickWaiting] Failed to parse settings file")
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
		push_warning("[SidekickWaiting] Failed to open settings file for writing")
		return
	file.store_string(JSON.stringify({ "volume": MusicController.get_volume() }))
	file.close()
