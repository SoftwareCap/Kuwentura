extends Control

@onready var host_button = $VBoxContainer/Button
@onready var join_button = $VBoxContainer/Button2
@onready var exit_button = $VBoxContainer/Button3
@onready var status_label = $StatusLabel

var join_popup: PopupPanel = null


func _ready():
	# Ensure main menu music is playing
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)
	
	# Connect button signals (check if not already connected)
	if not host_button.pressed.is_connected(_on_host_pressed):
		host_button.pressed.connect(_on_host_pressed)
	if not join_button.pressed.is_connected(_on_join_pressed):
		join_button.pressed.connect(_on_join_pressed)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)

	# Connect to network signals (check if not already connected)
	if not NetworkManager.connection_established.is_connected(_on_connection_established):
		NetworkManager.connection_established.connect(_on_connection_established)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)
	if not NetworkManager.player_joined.is_connected(_on_player_joined):
		NetworkManager.player_joined.connect(_on_player_joined)
	if not NetworkManager.role_assignment_received.is_connected(_on_role_assigned):
		NetworkManager.role_assignment_received.connect(_on_role_assigned)
	if not NetworkManager.room_code_generated.is_connected(_on_room_code_generated):
		NetworkManager.room_code_generated.connect(_on_room_code_generated)
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)


func _on_host_pressed() -> void:
	print("Hosting game...")
	_show_status("Creating game...")

	# Host the game (LAN mode)
	var result = NetworkManager.host_game()
	
	if not result.success:
		var error_msg = result.get("error", "Unknown error")
		_show_status("Failed to host: " + error_msg)
		return

	print("Game hosted! Invite code: ", result.get("invite_code", ""))
	_show_status("Room created! Code: " + result.get("invite_code", ""))

	# Go to detective lobby to wait for sidekick
	get_tree().change_scene_to_file("res://scenes/mainMenu/detective_lobby.tscn")


func _on_join_pressed() -> void:
	print("Opening join popup...")
	_show_join_popup()


func _show_join_popup():
	var popup_scene_file = preload("res://scenes/mainMenu/sidekickJoinCode_popup.tscn")
	join_popup = popup_scene_file.instantiate()
	add_child(join_popup)

	join_popup.code_submitted.connect(_on_code_entered)
	join_popup.cancelled.connect(_on_join_cancelled)

	join_popup.popup_centered()


func _on_code_entered(code: String):
	print("[MainMenu] Code entered: ", code)

	if join_popup:
		join_popup.queue_free()
		join_popup = null

	# DEBUG: Special "LOCAL" code for same-PC testing (F12 key)
	if code == "LOCAL":
		print("[MainMenu] DEBUG MODE: Connecting to localhost")
		_show_status("Debug: Connecting to localhost...")
		
		var local_result = await NetworkManager.join_game_with_ip("127.0.0.1", "LOCAL")
		
		if not local_result.success:
			_show_status("Failed to join localhost: " + local_result.get("error", "Unknown"))
			await get_tree().create_timer(2.0).timeout
			_show_join_popup()
			return
		
		get_tree().change_scene_to_file("res://scenes/mainMenu/sidekick_waiting.tscn")
		return

	_show_status("Searching for game with code: " + code + "...")
	print("[MainMenu] Starting discovery for code: ", code)

	# Join the game using code (discovery happens automatically)
	var result = await NetworkManager.join_game_with_code(code)
	
	print("[MainMenu] Join result: ", result)
	
	if not result.success:
		print("[MainMenu] Join failed: ", result.get("error", "Unknown"))
		_show_status("Failed to join: " + result.get("error", "Unknown error"))
		await get_tree().create_timer(2.0).timeout
		_show_join_popup()
		return

	print("[MainMenu] Connected to host!")
	_show_status("Connected! Waiting for game to start...")

	# Go to waiting lobby
	get_tree().change_scene_to_file("res://scenes/mainMenu/sidekick_waiting.tscn")


func _on_join_cancelled():
	print("Join cancelled")
	if join_popup:
		join_popup.queue_free()
		join_popup = null


func _on_room_code_generated(code: String):
	print("Room code generated: ", code)


func _on_connection_established(peer_id: int):
	print("Connected! Peer ID: ", peer_id)


func _on_connection_failed(error: String):
	print("Connection failed: " + error)
	_show_status("Connection failed: " + error)


func _on_role_assigned(role):
	print("Role assigned: ", role)


func _on_game_started(checkpoint: String):
	print("Game started at: ", checkpoint)
	# Transition to game scene
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_player_joined(_peer_id: int, role):
	print("Player joined as ", role)


func _show_status(text: String):
	if status_label:
		status_label.text = text
		status_label.show()
	print("Status: ", text)
