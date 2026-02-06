extends Control

@onready var start_button = $Button
@onready var back_button = $Button2
@onready var room_code_label = $RoomCode
@onready var status_label = $StatusLabel
@onready var sidekick_label = $SidekickLabel

@onready var detective_sprite = $PlayerHost/AnimatedSprite2D
@onready var sidekick_sprite = $PlayerSidekick/AnimatedSprite2D

var sidekick_connected: bool = false

func _ready():
	if detective_sprite:
		detective_sprite.play("idle")
	if sidekick_sprite:
		sidekick_sprite.play("idle")
	
	# Determine role and setup UI accordingly
	if GameState.local_role == GameState.Role.DETECTIVE:
		_setup_host_view()
	else:
		_setup_sidekick_view()
	
	# Connect signals (both roles need these)
	NetworkManager.room_code_generated.connect(_on_room_code_generated)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.connection_failed.connect(_on_connection_failed)

func _setup_host_view():
	# Host (Detective) setup
	start_button.visible = false
	start_button.disabled = true
	
	# Show room code
	if NetworkManager.is_hosting and not NetworkManager.current_room_code.is_empty():
		_show_room_code(NetworkManager.current_room_code)
	else:
		room_code_label.text = "Generating Code..."
		status_label.text = "Creating room..."
	
	# Sidekick sprite hidden initially (will appear when connected)
	if sidekick_sprite:
		sidekick_sprite.visible = false
	sidekick_label.visible = false
	
	status_label.text = "Waiting for Sidekick..."

func _setup_sidekick_view():
	# Sidekick setup - different UI
	start_button.visible = false  # Sidekick can't start game
	room_code_label.visible = false  # Sidekick doesn't see code
	
	# Position sidekick sprite on right
	if sidekick_sprite:
		sidekick_sprite.visible = true
		# Don't change position here - it's set in the scene
	
	# Detective sprite on left (host is there)
	if detective_sprite:
		detective_sprite.visible = true
	
	status_label.text = "Connected to Detective!"

func _show_room_code(code: String):
	room_code_label.text = "Code: " + code
	room_code_label.modulate = Color(1, 0.9, 0.2)  # Gold

func _on_room_code_generated(code: String):
	if GameState.local_role == GameState.Role.DETECTIVE:
		_show_room_code(code)

func _on_player_joined(_peer_id: int, _role: GameState.Role):
	sidekick_connected = true
	
	if GameState.local_role == GameState.Role.DETECTIVE:
		# Host sees sidekick joined
		status_label.text = "Sidekick Connected! Ready to start!"
		status_label.modulate = Color(0, 1, 0)
		
		# Show start button
		start_button.visible = true
		start_button.disabled = false
		
		# Show sidekick sprite with fade in
		if sidekick_sprite:
			sidekick_sprite.visible = true
			sidekick_sprite.modulate = Color(1, 1, 1, 0)  # Start transparent
			var tween = create_tween()
			tween.tween_property(sidekick_sprite, "modulate", Color(1, 1, 1, 1), 0.5)
	else:
		# Sidekick sees they're connected
		status_label.text = "Connected! Waiting for host..."
		status_label.modulate = Color(0, 1, 0)

func _on_start_pressed() -> void:
	if GameState.local_role != GameState.Role.DETECTIVE:
		return  # Only host can start
	
	if not sidekick_connected:
		print("Waiting for sidekick to connect...")
		return
	
	print("Starting game...")
	NetworkManager.start_game()

func _on_back_pressed() -> void:
	NetworkManager.disconnect_network()
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")

func _on_game_started():
	# Both players fade out and go to game
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/cutscenes/OpeningCutscene.tscn")

func _on_connection_failed(error: String):
	status_label.text = "Connection failed: " + error
	status_label.modulate = Color(1, 0, 0)
