extends Control

@onready var start_button = $Button
@onready var back_button = $Button2
@onready var room_code_label = $RoomCode
@onready var status_label = $StatusLabel
@onready var player_host = $PlayerHost
@onready var player_sidekick = $PlayerSidekick
@onready var detective_sprite = $PlayerHost/AnimatedSprite2D
@onready var sidekick_sprite = $PlayerSidekick/AnimatedSprite2D
@onready var sidekick_name_label = $PlayerSidekick/SidekickName

var sidekick_connected: bool = false


func _ready():
	# Ensure main menu music continues playing in lobby
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)
	
	# Disable physics for lobby avatars - they're just for display
	# We keep animations but stop gravity/physics
	if player_host:
		player_host.set_physics_process(false)
	if player_sidekick:
		player_sidekick.set_physics_process(false)
	
	if detective_sprite:
		detective_sprite.play("idle")
	if sidekick_sprite:
		sidekick_sprite.play("idle")

	# Determine role and setup UI accordingly
	if NetworkManager.get_my_role() == "detective":
		_setup_host_view()
	else:
		_setup_sidekick_view()

	# Connect signals (check if not already connected)
	if not NetworkManager.room_code_generated.is_connected(_on_room_code_generated):
		NetworkManager.room_code_generated.connect(_on_room_code_generated)
	if not NetworkManager.partner_connected.is_connected(_on_partner_connected):
		NetworkManager.partner_connected.connect(_on_partner_connected)
	if not NetworkManager.partner_disconnected.is_connected(_on_partner_disconnected):
		NetworkManager.partner_disconnected.connect(_on_partner_disconnected)
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)


func _setup_host_view():
	# Host (Detective) setup
	start_button.visible = false
	start_button.disabled = true

	# Get invite code from NetworkManager
	var invite_code = NetworkManager.get_invite_code()
	if not invite_code.is_empty():
		_show_room_code(invite_code)
	else:
		room_code_label.text = "Code: ???"

	# Sidekick elements hidden initially
	if sidekick_sprite:
		sidekick_sprite.visible = false
	if sidekick_name_label:
		sidekick_name_label.visible = false

	# Waiting message with instructions
	status_label.text = "Waiting for Sidekick...\n(Code is being broadcast on LAN)"
	status_label.modulate = Color(1, 1, 1)

	print("[Lobby] Host waiting. Code: ", invite_code)
	print("[Lobby] Make sure both devices are on the same Wi-Fi network")


func _setup_sidekick_view():
	# Sidekick setup
	start_button.visible = false
	room_code_label.visible = false

	# Sidekick sees both characters
	if sidekick_sprite:
		sidekick_sprite.visible = true
	if sidekick_name_label:
		sidekick_name_label.visible = true
	if detective_sprite:
		detective_sprite.visible = true

	status_label.text = "Connected! Waiting for Detective to start..."
	status_label.modulate = Color(0, 1, 0)


func _show_room_code(code: String):
	room_code_label.text = "Code: " + code
	room_code_label.modulate = Color(1, 0.9, 0.2)  # Gold


func _on_room_code_generated(code: String):
	if NetworkManager.get_my_role() == "detective":
		_show_room_code(code)


func _on_partner_connected(data: Dictionary):
	sidekick_connected = true

	if NetworkManager.get_my_role() == "detective":
		var partner_name = data.get("display_name", "Sidekick")
		print("[Lobby] Sidekick joined: ", partner_name)

		status_label.text = "Sidekick connected!\nClick START when ready!"
		status_label.modulate = Color(1, 1, 0)  # Yellow while connecting

		# Show start button
		start_button.visible = true
		start_button.disabled = false

		# Show sidekick sprite with fade in
		if sidekick_sprite:
			sidekick_sprite.visible = true
			sidekick_sprite.modulate = Color(1, 1, 1, 0)
			var tween = create_tween()
			tween.tween_property(sidekick_sprite, "modulate", Color(1, 1, 1, 1), 0.5)

		# Show sidekick name
		if sidekick_name_label:
			sidekick_name_label.visible = true
			sidekick_name_label.text = partner_name

	else:
		# Sidekick sees they're connected
		status_label.text = "Connected! Waiting for host to start..."
		status_label.modulate = Color(0, 1, 0)


func _on_partner_disconnected(_data: Dictionary):
	sidekick_connected = false

	if NetworkManager.get_my_role() == "detective":
		status_label.text = "Sidekick disconnected!\nWaiting..."
		status_label.modulate = Color(1, 0, 0)

		start_button.visible = false
		start_button.disabled = true

		if sidekick_sprite:
			sidekick_sprite.visible = false

		if sidekick_name_label:
			sidekick_name_label.visible = false
		
		print("[Lobby] Sidekick left the lobby")


func _on_start_pressed() -> void:
	print("[Lobby] Start button pressed!")
	print("[Lobby] My role: ", NetworkManager.get_my_role())
	print("[Lobby] Sidekick connected: ", sidekick_connected)
	
	if NetworkManager.get_my_role() != "detective":
		print("[Lobby] ERROR: Not detective, cannot start")
		return  # Only host can start

	if not sidekick_connected:
		print("[Lobby] ERROR: Waiting for sidekick to connect...")
		return

	print("[Lobby] Calling NetworkManager.start_game()...")
	start_button.disabled = true
	status_label.text = "Starting game..."

	# Start the session
	var success = NetworkManager.start_game()
	print("[Lobby] start_game() returned: ", success)
	if not success:
		status_label.text = "Failed to start game"
		start_button.disabled = false
	else:
		status_label.text = "Game starting!"


func _on_back_pressed() -> void:
	# Notify sidekick that host is leaving before disconnecting
	if sidekick_connected:
		_notify_sidekick_host_leaving.rpc()
	
	NetworkManager.disconnect_network()
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")


@rpc("authority", "reliable")
func _notify_sidekick_host_leaving():
	# This RPC is received by the sidekick
	pass


# for testing of zones, change the file path
func _on_game_started(_checkpoint: String = ""):
	print("[Lobby] _on_game_started called! Changing to ForestHub...")
	# Both players fade out and go to game
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished
	print("[Lobby] Fade complete, changing scene now!")
	# change this file into res://scenes/cutscenes/OpeningCutscene.tscn
	var err = get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
	if err != OK:
		print("[Lobby] ERROR: Failed to change scene! Error code: ", err)
	else:
		print("[Lobby] Scene change initiated successfully")


func _on_connection_failed(error: String):
	status_label.text = "Connection failed: " + error
	status_label.modulate = Color(1, 0, 0)
