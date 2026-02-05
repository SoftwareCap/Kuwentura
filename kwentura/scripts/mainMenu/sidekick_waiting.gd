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
	NetworkManager.peer_disconnected.connect(_on_host_disconnected)
	
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Update status
	status_label.text = "Connecting to Detective..."
	
	# Check if already connected
	if NetworkManager.connection_state == NetworkManager.ConnectionState.CONNECTED:
		_on_connected()

func _on_connected():
	status_label.text = "Connected! Waiting for Detective to start..."
	status_label.modulate = Color(0, 1, 0)  # Green
	
	# Optional: Show "Connected" animation or icon
	var tween = create_tween()
	tween.tween_property(status_label, "scale", Vector2(1.1, 1.1), 0.3)
	tween.tween_property(status_label, "scale", Vector2(1.0, 1.0), 0.3)

func _on_game_started():
	status_label.text = "Starting game..."
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished
	
	# Go to opening cutscene
	get_tree().change_scene_to_file("res://scenes/cutscenes/OpeningCutscene.tscn")

func _on_connection_failed(error: String):
	status_label.text = "Connection failed: " + error
	status_label.modulate = Color(1, 0, 0)  # Red
	
	# Show retry button or auto-return
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")

func _on_host_disconnected():
	status_label.text = "Detective disconnected!"
	status_label.modulate = Color(1, 0, 0)
	
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")

func _on_cancel_pressed():
	NetworkManager.disconnect_network()
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")
