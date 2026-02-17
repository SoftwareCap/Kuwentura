extends Control

@onready var status_label: Label = $StatusLabel
@onready var cancel_button: Button = $CancelButton

@onready var player_host = $PlayerHost
@onready var player_sidekick = $PlayerSidekick
@onready var detective_sprite: AnimatedSprite2D = $PlayerHost/AnimatedSprite2D
@onready var detective_name_label: Label = $PlayerHost/DetectiveName
@onready var sidekick_sprite: AnimatedSprite2D = $PlayerSidekick/AnimatedSprite2D
@onready var sidekick_name_label: Label = $PlayerSidekick/SidekickName


func _ready():
	# Ensure main menu music continues playing in lobby
	MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)
	
	if status_label == null:
		print("ERROR: StatusLabel not found!")
		return
	
	# Disable physics for lobby avatars - they're just for display
	if player_host:
		player_host.set_physics_process(false)
	if player_sidekick:
		player_sidekick.set_physics_process(false)

	# Connect signals (check if not already connected)
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

	# Show both avatars immediately
	# Detective (host) on the left
	if detective_sprite:
		detective_sprite.visible = true
		detective_sprite.play("idle")
	if detective_name_label:
		detective_name_label.visible = true
	
	# Sidekick (self) on the right - always visible in lobby
	if sidekick_sprite:
		sidekick_sprite.visible = true
		sidekick_sprite.play("idle")
	if sidekick_name_label:
		sidekick_name_label.visible = true

	# Update status
	status_label.text = "Connected to Host!"
	status_label.modulate = Color(1, 1, 0)  # Yellow while connecting


func _on_connection_established(peer_id: int):
	print("[SidekickLobby] Connected! Peer ID: ", peer_id)
	
	status_label.text = "Connected!\nWaiting for Detective to start..."
	status_label.modulate = Color(0, 1, 0)  # Green
	
	# Show sidekick avatar with fade in
	if sidekick_sprite:
		sidekick_sprite.visible = true
		sidekick_sprite.play("idle")
		sidekick_sprite.modulate = Color(1, 1, 1, 0)
		var tween = create_tween()
		tween.tween_property(sidekick_sprite, "modulate", Color(1, 1, 1, 1), 0.5)
	
	if sidekick_name_label:
		sidekick_name_label.visible = true


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
	# change this file into res://scenes/cutscenes/OpeningCutscene.tscn
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


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
	status_label.text = "Detective disconnected!\nReturning to menu..."
	status_label.modulate = Color(1, 0, 0)

	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")


func _on_connection_state_changed(new_state: int, _old_state: int):
	# If we get disconnected while in lobby, return to main menu
	# ConnectionState.DISCONNECTED = 0
	if new_state == 0:
		status_label.text = "Connection lost!\nReturning to menu..."
		status_label.modulate = Color(1, 0, 0)
		
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")


func _on_cancel_pressed():
	NetworkManager.disconnect_network()
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")
