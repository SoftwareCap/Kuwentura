extends Control

@onready var status_label = $Label2
@onready var cancel_button = $Button


func _ready():
	if status_label == null:
		print("ERROR: Label2 not found!")
		return

	# Connect signals
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.partner_disconnected.connect(_on_host_disconnected)
	NetworkManager.partner_connected.connect(_on_partner_connected)

	cancel_button.pressed.connect(_on_cancel_pressed)

	# Update status
	status_label.text = "Connected to Detective!\nWaiting for game to start..."
	status_label.modulate = Color(0, 1, 0)  # Green


func _on_partner_connected(_data: Dictionary):
	status_label.text = "Connected!\nWaiting for Detective to start..."
	status_label.modulate = Color(0, 1, 0)


func _on_game_started(_checkpoint: String = ""):
	status_label.text = "Starting game..."

	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished

	# Go to opening cutscene
	get_tree().change_scene_to_file("res://scenes/cutscenes/OpeningCutscene.tscn")


func _on_connection_failed(error: String):
	var error_msg = "Cannot connect to game.\n\nPlease check:\n"
	error_msg += "• Both devices on same Wi-Fi\n"
	error_msg += "• Room code is correct\n"
	error_msg += "• Detective is hosting\n"
	error_msg += "\nError: " + error
	
	status_label.text = error_msg
	status_label.modulate = Color(1, 0, 0)

	# Auto-return to menu
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")


func _on_host_disconnected():
	status_label.text = "Detective disconnected!"
	status_label.modulate = Color(1, 0, 0)

	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")


func _on_cancel_pressed():
	NetworkManager.disconnect_network()
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")
