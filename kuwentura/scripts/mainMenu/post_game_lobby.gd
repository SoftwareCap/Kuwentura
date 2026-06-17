extends Control

# CONSTANTS
const SCENE_MAIN_MENU := "res://scenes/mainMenu/MainMenu.tscn"
const SCENE_OPENING_CUTSCENE := "res://scenes/cutscenes/opening/OpeningCutscene.tscn"
const SCENE_MOBILE_OPENING_CUTSCENE := "res://scenes/cutscenes/opening/MobileOpeningCutscene.tscn"
const FADE_DURATION := 1.0

# NODE REFERENCES
@onready var title_label: Label = $TitleLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var disconnect_button: Button = $VBoxContainer/DisconnectButton
@onready var exit_button: Button = $VBoxContainer/ExitButton
@onready var status_label: Label = $StatusLabel
@onready var book_closed_sprite: Sprite2D = $BookClosedSprite

# STATE
var is_host: bool = false


# LIFECYCLE
func _ready() -> void:
	is_host = GameState.is_host
	_setup_ui()
	_connect_signals()
	modulate = Color.TRANSPARENT
	await _fade(Color.WHITE, FADE_DURATION)


func _exit_tree() -> void:
	_disconnect_signals()


# SETUP
func _setup_ui() -> void:
	"""Configure all UI elements based on role and completion state."""
	title_label.text = "THE END"
	_setup_status_label()
	_setup_restart_button()


func _setup_status_label() -> void:
	"""Set status text based on game completion and role."""
	status_label.text = "Mystery Solved! All clues collected." \
		if GameState.game_completed else "Journey ended."

	if not is_host:
		status_label.text += "\nWaiting for Detective to choose..."


func _setup_restart_button() -> void:
	"""Configure restart button label and enabled state based on role."""
	restart_button.text = "Play Again (Host New Game)" if is_host else "Ready for Next Story"
	restart_button.disabled = not is_host


func _connect_signals() -> void:
	"""Connect all button and network signals."""
	restart_button.pressed.connect(_on_restart_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	var signal_pairs := [
		[NetworkManager.player_left, _on_peer_disconnected],
		[NetworkManager.game_started, _on_restart_confirmed],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if not sig.is_connected(cb):
			sig.connect(cb)


func _disconnect_signals() -> void:
	"""Disconnect network signals to prevent callbacks after scene change."""
	var signal_pairs := [
		[NetworkManager.player_left, _on_peer_disconnected],
		[NetworkManager.game_started, _on_restart_confirmed],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)


# BUTTON HANDLERS
func _on_restart_pressed() -> void:
	if not is_host:
		return
	status_label.text = "Asking partner to play again..."
	NetworkManager.start_game()


func _on_disconnect_pressed() -> void:
	status_label.text = "Disconnecting..."
	NetworkManager.disconnect_network()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _on_exit_pressed() -> void:
	NetworkManager.disconnect_network()
	get_tree().quit()


# NETWORK CALLBACKS
func _on_peer_disconnected(_peer_id: int = 0) -> void:
	status_label.text = "Partner disconnected. Return to menu?"
	restart_button.disabled = true
	_show_partner_left_dialog()


func _on_restart_confirmed(_checkpoint: String = "") -> void:
	status_label.text = "Starting new story..."
	await _fade(Color.TRANSPARENT, FADE_DURATION)
	GameState.reset_all_progress()
	get_tree().change_scene_to_file(_get_opening_cutscene_scene())


# HELPERS
func _fade(target: Color, duration: float) -> void:
	"""Tween self modulate to target color over duration and await completion."""
	var tween := create_tween()
	tween.tween_property(self, "modulate", target, duration)
	await tween.finished


func _get_opening_cutscene_scene() -> String:
	if CutsceneHelper.is_mobile_platform():
		return SCENE_MOBILE_OPENING_CUTSCENE
	return SCENE_OPENING_CUTSCENE


func _show_partner_left_dialog() -> void:
	"""Show an AcceptDialog informing the player their partner disconnected."""
	var dialog := AcceptDialog.new()
	dialog.title = "Partner Left"
	dialog.dialog_text = "The other player has disconnected."
	dialog.ok_button_text = "Return to Menu"
	dialog.confirmed.connect(
		func(): get_tree().change_scene_to_file(SCENE_MAIN_MENU)
	)
	add_child(dialog)
	dialog.popup_centered()
