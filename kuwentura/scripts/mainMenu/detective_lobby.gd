extends Control
## Detective Lobby - Costume Selection & Matchmaking
## Handles costume selection UI, network synchronization, and game start

# CONSTANTS
const ANIMATION_DURATION := 0.15
const ARROW_SCALE_DEFAULT := Vector2(0.28, 0.28)
const ARROW_SCALE_PRESSED := Vector2(0.24, 0.24)
const AVATAR_BOUNCE_HEIGHT := 10.0
const FADE_DURATION := 0.2
const SETTINGS_FILE := "user://settings.json"
const SCENE_MAIN_MENU := "res://scenes/mainMenu/MainMenu.tscn"
const SCENE_OPENING_CUTSCENE := "res://scenes/cutscenes/opening/OpeningCutscene.tscn"

# UI colors — named so intent is visible at every call site
const COLOR_NORMAL := Color(1, 1, 1, 1)
const COLOR_CONFIRMED := Color(1, 0.95, 0.8, 1)
const COLOR_UNCONFIRMED := Color(0.8, 0.8, 0.8, 1)
const COLOR_FLASH_GREEN := Color(0.5, 1, 0.5, 1)
const COLOR_SUCCESS := Color(0, 1, 0, 1)
const COLOR_WARNING = Color(1, 1, 0, 1)
const COLOR_ERROR := Color(1, 0, 0, 1)

# NODE REFERENCES
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
@onready var view_user_profile_button:Button = $SettingsLayer/SettingsPanel/ViewUserProfile
@onready var user_section: Panel = $SettingsLayer/SettingsPanel/UserSection
@onready var user_section_back_button:TouchScreenButton = $SettingsLayer/SettingsPanel/UserSection/Back

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

# STATE
var sidekick_connected: bool = false
var _detective_costume_index: int = 0
var _sidekick_costume_index: int = 0
var _detective_costumes: Array = []
var _sidekick_costumes: Array = []
var _is_leaving: bool = false

# Resolved per-role node sets — used by _set_role_controls_visible and _update_costume_display
# Populated in _ready() once @onready vars are available.
var _role_nodes: Dictionary = {}

# Navigation buttons tracked for bulk disconnect
var _nav_buttons: Array = []


# LIFECYCLE
func _ready() -> void:
	_role_nodes = {
		"detective": {
			"left_btn": detective_left_btn,
			"right_btn": detective_right_btn,
			"select_btn": detective_select_btn,
			"costume_label": detective_costume_label,
			"avatar": player_host,
			"sprite": detective_sprite,
			"name_label": detective_name_label,
			"costumes": func(): return _detective_costumes,
			"index": func(): return _detective_costume_index,
			"set_index": func(v): _detective_costume_index = v,
		},
		"sidekick": {
			"left_btn": sidekick_left_btn,
			"right_btn": sidekick_right_btn,
			"select_btn": sidekick_select_btn,
			"costume_label": sidekick_costume_label,
			"avatar": player_sidekick,
			"sprite": sidekick_sprite,
			"name_label": sidekick_name_label,
			"costumes": func(): return _sidekick_costumes,
			"index": func(): return _sidekick_costume_index,
			"set_index": func(v): _sidekick_costume_index = v,
		},
	}

	_setup_audio()
	_setup_avatars()
	_setup_costume_data()
	_setup_ui_visibility()
	_connect_signals()
	_setup_button_animations()
	_setup_settings()

	_update_costume_display("detective")
	_update_costume_display("sidekick")
	_update_connection_indicator()


func _exit_tree() -> void:
	_is_leaving = true
	_disconnect_signals()


# SETUP
func _setup_audio() -> void:
	"""Ensure main menu music is playing."""
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)


func _setup_avatars() -> void:
	"""Configure avatar sprites for display mode."""
	for role in _role_nodes:
		var nodes: Dictionary = _role_nodes[role]
		if nodes.avatar:
			nodes.avatar.set_physics_process(false)
		if nodes.sprite:
			nodes.sprite.play("idle")


func _setup_costume_data() -> void:
	"""Initialize costume arrays from GameState."""
	_detective_costumes = GameState.get_costumes_for_role("detective")
	_sidekick_costumes = GameState.get_costumes_for_role("sidekick")


func _setup_ui_visibility() -> void:
	"""Show/hide UI based on player role."""
	var my_role := NetworkManager.get_my_role()
	_set_role_controls_visible("detective", my_role == "detective")
	_set_role_controls_visible("sidekick", my_role == "sidekick")
	_setup_base_lobby_ui()


func _set_role_controls_visible(role: String, controls_visible: bool) -> void:
	"""Set visibility of costume navigation controls for the given role."""
	var nodes: Dictionary = _role_nodes[role]
	for key in ["left_btn", "right_btn", "select_btn"]:
		var btn = nodes[key]
		if is_instance_valid(btn):
			btn.visible = controls_visible

	var label = nodes.costume_label
	if is_instance_valid(label):
		label.visible = true if role == "detective" else sidekick_connected


func _setup_base_lobby_ui() -> void:
	"""Configure base lobby elements based on role."""
	if NetworkManager.get_my_role() == "detective":
		start_button.visible = false
		start_button.disabled = true

		var invite_code := NetworkManager.get_invite_code()
		room_code_label.text = "Code: %s" % invite_code if not invite_code.is_empty() else "Code: ???"
		status_label.text = "Waiting for Sidekick..."
		status_label.modulate = COLOR_NORMAL

		var sk_nodes: Dictionary = _role_nodes["sidekick"]
		if sk_nodes.sprite:
			sk_nodes.sprite.visible = false
		if sk_nodes.name_label:
			sk_nodes.name_label.visible = false
	else:
		start_button.visible = false
		room_code_label.visible = false
		status_label.text = "Connected! Waiting for Detective to start..."


func _connect_signals() -> void:
	"""Connect all necessary signals."""
	var signal_pairs := [
		[GameState.costume_changed, _on_costume_changed],
		[GameState.costume_confirmed, _on_costume_confirmed],
		[NetworkManager.room_code_generated, _on_room_code_generated],
		[NetworkManager.partner_connected, _on_partner_connected],
		[NetworkManager.partner_disconnected, _on_partner_disconnected],
		[NetworkManager.game_started, _on_game_started],
		[NetworkManager.connection_failed, _on_connection_failed],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if not sig.is_connected(cb):
			sig.connect(cb)

	if settings_control and not settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.connect(_on_settings_pressed)


func _disconnect_signals() -> void:
	"""Disconnect all signals to prevent callbacks after scene change."""
	var signal_pairs := [
		[GameState.costume_changed, _on_costume_changed],
		[GameState.costume_confirmed, _on_costume_confirmed],
		[NetworkManager.room_code_generated, _on_room_code_generated],
		[NetworkManager.partner_connected, _on_partner_connected],
		[NetworkManager.partner_disconnected, _on_partner_disconnected],
		[NetworkManager.game_started, _on_game_started],
		[NetworkManager.connection_failed, _on_connection_failed],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)

	if settings_control and settings_control.settings_pressed.is_connected(_on_settings_pressed):
		settings_control.settings_pressed.disconnect(_on_settings_pressed)

	for btn in _nav_buttons:
		if is_instance_valid(btn):
			btn.pressed.disconnect(_on_navigate_costume)
			if btn is TextureButton:
				btn.button_down.disconnect(_on_arrow_down)
				btn.button_up.disconnect(_on_arrow_up)

	for role in ["detective", "sidekick"]:
		var select_btn = _role_nodes[role].select_btn
		if is_instance_valid(select_btn) and select_btn.pressed.is_connected(_on_select_costume):
			select_btn.pressed.disconnect(_on_select_costume)


func _setup_button_animations() -> void:
	"""Connect arrow animation callbacks and all navigation button handlers."""
	_nav_buttons.clear()

	for role in ["detective", "sidekick"]:
		var nodes: Dictionary = _role_nodes[role]

		for dir in [["left_btn", -1], ["right_btn", 1]]:
			var btn: TextureButton = nodes[dir[0]]
			var direction: int = dir[1]
			if is_instance_valid(btn):
				_nav_buttons.append(btn)
				btn.pressed.connect(_on_navigate_costume.bind(role, direction))
				btn.button_down.connect(_on_arrow_down.bind(btn))
				btn.button_up.connect(_on_arrow_up.bind(btn))

		var select_btn: Button = nodes.select_btn
		if is_instance_valid(select_btn) and not select_btn.pressed.is_connected(_on_select_costume):
			select_btn.pressed.connect(_on_select_costume.bind(role))


# ANIMATION
func _on_arrow_down(btn: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "scale", ARROW_SCALE_PRESSED, ANIMATION_DURATION * 0.5)


func _on_arrow_up(btn: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "scale", ARROW_SCALE_DEFAULT, ANIMATION_DURATION * 0.5)


func _animate_avatar_bounce(role: String) -> void:
	"""Animate avatar bounce when costume changes."""
	var avatar = _role_nodes[role].avatar
	if not avatar:
		return
	var original_y : float = avatar.position.y
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(avatar, "position:y", original_y - AVATAR_BOUNCE_HEIGHT, 0.1)
	tween.tween_property(avatar, "position:y", original_y, 0.3)


func _animate_costume_confirmed(role: String) -> void:
	"""Flash label green and pulse select button on confirmation."""
	var label = _role_nodes[role].costume_label
	var btn = _role_nodes[role].select_btn

	var tween := create_tween()
	tween.tween_property(label, "modulate", COLOR_FLASH_GREEN, 0.2)
	tween.tween_property(label, "modulate", COLOR_NORMAL, 0.2)

	var btn_tween := create_tween()
	btn_tween.set_trans(Tween.TRANS_BACK)
	btn_tween.set_ease(Tween.EASE_OUT)
	btn_tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	btn_tween.tween_property(btn, "scale", Vector2.ONE, 0.2)


# COSTUME SELECTION
func _on_navigate_costume(role: String, direction: int) -> void:
	"""Navigate costume in given direction (-1 left, +1 right)."""
	if GameState.is_costume_confirmed(role):
		GameState.confirm_costume_selection(role, false)

	var costumes: Array = _role_nodes[role].costumes.call()
	if costumes.size() <= 1:
		return

	var new_index: int = wrapi(_role_nodes[role].index.call() + direction, 0, costumes.size())
	_role_nodes[role].set_index.call(new_index)
	_change_costume(role, new_index)


func _on_select_costume(role: String) -> void:
	_confirm_costume(role)


func _change_costume(role: String, index: int) -> void:
	"""Change costume selection and sync to network."""
	var costumes: Array = _role_nodes[role].costumes.call()
	if index < 0 or index >= costumes.size():
		return

	var costume: Dictionary = costumes[index]
	GameState.set_selected_costume(role, costume.id)

	if GameState.is_costume_confirmed(role):
		GameState.confirm_costume_selection(role, false)

	_update_costume_display(role)
	_animate_avatar_bounce(role)

	if _is_network_available():
		NetworkManager.sync_costume_preview(role, costume.id)


func _confirm_costume(role: String) -> void:
	"""Confirm costume selection and sync to network."""
	if GameState.is_costume_confirmed(role):
		return

	GameState.confirm_costume_selection(role, true)

	if _is_network_available():
		NetworkManager.sync_costume_confirmed(role, GameState.get_selected_costume(role))

	_animate_costume_confirmed(role)
	_update_costume_display(role)


func _update_costume_display(role: String) -> void:
	"""Update costume label and select button for the given role."""
	if not is_instance_valid(self) or not is_inside_tree():
		return

	var is_local: bool = (role == NetworkManager.get_my_role())
	var costume_id: String = GameState.get_selected_costume(role)
	var costume: Dictionary = GameState.get_costume_by_id(role, costume_id)
	var is_confirmed:bool = GameState.is_costume_confirmed(role)
	var label = _role_nodes[role].costume_label
	var select_btn = _role_nodes[role].select_btn

	if not is_instance_valid(label):
		return

	if is_local:
		label.text = costume.get("name", "Classic Outfit")
		label.modulate = COLOR_NORMAL
		if is_instance_valid(select_btn):
			select_btn.text = "✓ Selected!" if is_confirmed else "Select Costume"
			select_btn.disabled = is_confirmed
	else:
		if is_confirmed:
			label.text = costume.get("name", "Classic Outfit")
			label.modulate = COLOR_CONFIRMED
		else:
			label.text = "Classic Outfit"
			label.modulate = COLOR_UNCONFIRMED


func _on_costume_changed(_role: String, _costume_id: String) -> void:
	_update_costume_display("detective")
	_update_costume_display("sidekick")


func _on_costume_confirmed(_role: String, _confirmed: bool) -> void:
	_update_costume_display("detective")
	_update_costume_display("sidekick")


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
	stylebox.bg_color = Color(0.2, 0.9, 0.2) if sidekick_connected else Color(0.9, 0.2, 0.2)
	stylebox.corner_radius_top_left = 30
	stylebox.corner_radius_top_right = 30
	stylebox.corner_radius_bottom_right = 30
	stylebox.corner_radius_bottom_left = 30
	connection_indicator.add_theme_stylebox_override("panel", stylebox)


# NETWORK CALLBACKS
func _on_room_code_generated(code: String) -> void:
	if NetworkManager.get_my_role() == "detective":
		room_code_label.text = "Code: %s" % code
		room_code_label.modulate = COLOR_WARNING


func _on_partner_connected(data: Dictionary) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return

	sidekick_connected = true
	_update_connection_indicator()

	if NetworkManager.get_my_role() == "detective":
		var partner_name: String = data.get("display_name", "Sidekick")
		var sk: Dictionary = _role_nodes["sidekick"]

		if is_instance_valid(status_label):
			status_label.text = "Sidekick connected!"
			status_label.modulate = COLOR_WARNING

		if is_instance_valid(start_button):
			start_button.visible = true
			start_button.disabled = false

		if is_instance_valid(sk.sprite):
			sk.sprite.visible = true
			sk.sprite.modulate = Color(1, 1, 1, 0)
			var tween := create_tween()
			tween.tween_property(sk.sprite, "modulate", COLOR_NORMAL, 0.5)

		if is_instance_valid(sk.name_label):
			sk.name_label.visible = true
			sk.name_label.text = partner_name

		if is_instance_valid(sk.costume_label):
			sk.costume_label.visible = true

		_send_costume_state_with_delay()
	else:
		if is_instance_valid(status_label):
			status_label.text = "Connected! Waiting for host to start..."
			status_label.modulate = COLOR_SUCCESS


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
		var sk: Dictionary = _role_nodes["sidekick"]

		if is_instance_valid(status_label):
			status_label.text = "Sidekick disconnected!\nWaiting..."
			status_label.modulate = COLOR_ERROR

		if is_instance_valid(start_button):
			start_button.visible = false
			start_button.disabled = true

		for node in [sk.sprite, sk.name_label, sk.costume_label]:
			if is_instance_valid(node):
				node.visible = false

		_set_role_controls_visible("sidekick", false)
		GameState.set_selected_costume("sidekick", "default")
		GameState.confirm_costume_selection("sidekick", false)
		_update_costume_display("sidekick")


func _on_start_pressed() -> void:
	if NetworkManager.get_my_role() != "detective" or not sidekick_connected:
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

	if sidekick_connected:
		NetworkManager.notify_host_leaving()
		await get_tree().create_timer(0.2).timeout

	NetworkManager.disconnect_network()
	await get_tree().create_timer(0.5).timeout

	if is_inside_tree():
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)


# ── INSTANT transition: no fade, change scene immediately ──────────────────
func _on_game_started(_checkpoint: String = "") -> void:
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

	if not is_instance_valid(self) or not is_inside_tree():
		return
	get_tree().change_scene_to_file(SCENE_OPENING_CUTSCENE)


func _on_connection_failed(error: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = "Connection failed: %s" % error
		status_label.modulate = COLOR_ERROR


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
		push_warning("[DetectiveLobby] Failed to open settings file for reading")
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_warning("[DetectiveLobby] Failed to parse settings file")
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
		push_warning("[DetectiveLobby] Failed to open settings file for writing")
		return
	file.store_string(JSON.stringify({ "volume": MusicController.get_volume() }))
	file.close()
