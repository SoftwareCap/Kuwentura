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

# ============================================================================
# NODE REFERENCES
# ============================================================================
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


func _setup_button_animations() -> void:
	"""Setup button press animations for sidekick arrows."""
	var arrow_buttons := [sidekick_left_btn, sidekick_right_btn]
	
	for btn in arrow_buttons:
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
