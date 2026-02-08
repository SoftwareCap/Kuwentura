extends Control

@onready var title_label = $TitleLabel
@onready var restart_button = $VBoxContainer/RestartButton
@onready var disconnect_button = $VBoxContainer/DisconnectButton
@onready var exit_button = $VBoxContainer/ExitButton
@onready var status_label = $StatusLabel
@onready var book_closed_sprite = $BookClosedSprite

var is_host: bool = false


func _ready():
	# Determine if we're host (detective) or client (sidekick)
	is_host = GameState.is_host

	_setup_ui()
	_connect_signals()

	# Fade in
	modulate = Color(0, 0, 0, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 1.0)


func _setup_ui():
	title_label.text = "THE END"

	# Show completion status
	if GameState.game_completed:
		status_label.text = "Mystery Solved! All clues collected."
	else:
		status_label.text = "Journey ended."

	# Button labels based on role
	if is_host:
		restart_button.text = "Play Again (Host New Game)"
	else:
		restart_button.text = "Ready for Next Story"

	# Only host can restart - sidekick waits
	if not is_host:
		restart_button.disabled = true
		status_label.text += "\nWaiting for Detective to choose..."


func _connect_signals():
	restart_button.pressed.connect(_on_restart_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Network signals
	NetworkManager.player_left.connect(_on_peer_disconnected)
	NetworkManager.game_started.connect(_on_restart_confirmed)


func _on_restart_pressed():
	if not is_host:
		return

	status_label.text = "Asking partner to play again..."

	# Notify other player via game_started signal
	NetworkManager.start_game()


func _on_disconnect_pressed():
	# Disconnect from network but keep game running
	status_label.text = "Disconnecting..."

	NetworkManager.disconnect_network()

	# Return to main menu (single player effectively)
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")


func _on_exit_pressed():
	# Full exit - disconnect and quit
	NetworkManager.disconnect_network()
	get_tree().quit()


func _on_peer_disconnected(_peer_id: int = 0):
	# Other player left
	status_label.text = "Partner disconnected. Return to menu?"
	restart_button.disabled = true

	# Show popup or update UI
	var dialog = AcceptDialog.new()
	dialog.title = "Partner Left"
	dialog.dialog_text = "The other player has disconnected."
	dialog.ok_button_text = "Return to Menu"
	dialog.canceled.connect(
		func(): get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")
	)
	add_child(dialog)
	dialog.popup_centered()


func _on_restart_confirmed(_checkpoint: String = ""):
	# Both agreed to restart - fade out and go to cutscene
	status_label.text = "Starting new story..."

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished

	_reset_game_state()
	get_tree().change_scene_to_file("res://scenes/cutscenes/OpeningCutscene.tscn")


func _reset_game_state():
	# Reset progression but keep connection
	GameState.climax_triggered = false
	GameState.game_completed = false
	GameState.nightfall_attempts = 0

	# Reset clues
	for zone_id in GameState.collected_clues.keys():
		GameState.collected_clues[zone_id].collected = false

	# Generate new puzzle seeds (fresh numbers)
	GameState._initialize_puzzle_seeds()

	# Reset position
	GameState.current_zone = "forest_hub"
	GameState.ledger_entries.clear()
