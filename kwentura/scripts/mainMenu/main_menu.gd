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
	NetworkManager.room_code_generated.connect(_on_room_code_generated)

func _on_host_pressed() -> void:
	print("Hosting game...")
	
	# Check if authenticated
	if NetworkManager._auth_token.is_empty():
		_show_status("Waiting for authentication...")
		# Wait up to 5 seconds for auth
		var attempts = 0
		while NetworkManager._auth_token.is_empty() and attempts < 50:
			await get_tree().create_timer(0.1).timeout
			attempts += 1
		
		if NetworkManager._auth_token.is_empty():
			_show_status("Not authenticated! Please wait and try again.")
			return
	
	_show_status("Creating world...")
	
	# Step 1: Create world (doesn't start session yet)
	var result = await NetworkManager.create_world("Game")
	if result.has("error"):
		_show_status("Failed to create world: " + result.get("error", "Unknown error"))
		return
	
	print("World created! Invite code: ", result.get("invite_code", ""))
	
	# Step 2: Go to lobby immediately
	# The lobby will poll for sidekick and show the start button when ready
	get_tree().change_scene_to_file("res://scenes/mainMenu/detective_lobby.tscn")

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
	
	_show_status("Joining world...")
	
	# Step 1: Join the world (sidekick)
	var result = await NetworkManager.join_world(code)
	if result.has("error"):
		_show_status("Failed to join: " + result.get("error", "Unknown error"))
		_show_join_popup()
		return
	
	print("Joined world! Partner: ", result.get("partner_name", "Unknown"))
	print("World status: ", result.get("status", "unknown"))
	
	# Step 2: Go to lobby and wait for detective to start
	get_tree().change_scene_to_file("res://scenes/mainMenu/detective_lobby.tscn")

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

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_player_joined(_peer_id: int, role):
	print("Player joined as ", role)

func _show_status(text: String):
	if status_label:
		status_label.text = text
		status_label.show()
	print("Status: ", text)
