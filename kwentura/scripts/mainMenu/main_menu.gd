extends Control

@onready var host_button = $VBoxContainer/Button
@onready var join_button = $VBoxContainer/Button2
@onready var exit_button = $VBoxContainer/Button3
@onready var status_label = $StatusLabel 

var join_popup: PopupPanel = null

func _ready():
	# Connect button signals
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Connect to network signals
	NetworkManager.connection_established.connect(_on_connection_established)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.role_assignment_received.connect(_on_role_assigned)

func _on_host_pressed() -> void:
	print("Hosting game...")
	
	if NetworkManager.host_game():
		get_tree().change_scene_to_file("res://scenes/mainMenu/detective_lobby.tscn")
	else:
		_show_status("Failed to create server!")

func _on_join_pressed() -> void:
	print("Opening join popup...")
	_show_join_popup()

func _show_join_popup():
	var popup_scene = preload("res://scenes/mainMenu/sidekickJoinCode_popup.tscn")
	join_popup = popup_scene.instantiate()
	add_child(join_popup)
	
	join_popup.code_submitted.connect(_on_code_entered)
	join_popup.cancelled.connect(_on_join_cancelled)
	
	join_popup.popup_centered()

func _on_code_entered(code: String):
	print("Code entered: ", code)
	
	if join_popup:
		join_popup.queue_free()
		join_popup = null
	
	if NetworkManager.join_game_with_code(code):
		# Wait a moment for connection, then go to SAME lobby as host
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scenes/mainMenu/detective_lobby.tscn")
	else:
		print("Failed to start connection!")
		_show_join_popup()

func _on_join_cancelled():
	print("Join cancelled")
	if join_popup:
		join_popup.queue_free()
		join_popup = null

func _on_connection_established(peer_id: int):
	print("Connected! Peer ID: ", peer_id)

func _on_connection_failed(error: String):
	print("Connection failed: " + error)

func _on_role_assigned(role: GameState.Role):
	print("Role assigned: ", GameState.Role.keys()[role])

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_player_joined(_peer_id: int, role: GameState.Role):
	print("Player joined as ", GameState.Role.keys()[role])

func _show_status(text: String):
	if status_label:
		status_label.text = text
		status_label.show()
	print("Status: ", text)
