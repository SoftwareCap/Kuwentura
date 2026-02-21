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

	# Check if game is already in progress (rejoining scenario)
	# Use a deferred check to ensure NetworkManager has processed any pending RPCs
	_call_join_if_playing()


## Deferred check to see if we should join immediately
func _call_join_if_playing():
	await get_tree().process_frame
	
	if not is_inside_tree():
		return
	
	if NetworkManager.is_playing():
		print("[SidekickWaiting] Game already in progress, joining immediately...")
		get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
		return
	
	# If we're connected but not playing yet, the host will send game_started soon
	# Also check after a short delay in case the RPC is delayed
	await get_tree().create_timer(0.5).timeout
	
	if not is_inside_tree():
		return
		
	if NetworkManager.is_playing():
		print("[SidekickWaiting] Game started during wait, joining now...")
		get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")

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


func _exit_tree():
	# Disconnect all signals to prevent callbacks after scene change
	if NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.disconnect(_on_game_started)
	if NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.disconnect(_on_connection_failed)
	if NetworkManager.partner_disconnected.is_connected(_on_host_disconnected):
		NetworkManager.partner_disconnected.disconnect(_on_host_disconnected)
	if NetworkManager.partner_connected.is_connected(_on_partner_connected):
		NetworkManager.partner_connected.disconnect(_on_partner_connected)
	if NetworkManager.connection_established.is_connected(_on_connection_established):
		NetworkManager.connection_established.disconnect(_on_connection_established)
	if NetworkManager.connection_state_changed.is_connected(_on_connection_state_changed):
		NetworkManager.connection_state_changed.disconnect(_on_connection_state_changed)


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
	print("[SidekickWaiting] Game started signal received!")
	
	# Prevent duplicate scene changes
	if not is_inside_tree():
		print("[SidekickWaiting] Not in tree, ignoring game_started")
		return
	
	status_label.text = "Starting game..."

	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished
	
	# Safety check: ensure node is still valid and in tree before changing scene
	if not is_instance_valid(self) or not is_inside_tree():
		print("[SidekickWaiting] Node no longer valid, skipping scene change")
		return
	
	var tree = get_tree()
	if tree == null:
		print("[SidekickWaiting] SceneTree is null, cannot change scene")
		return

	# Go to game
	tree.change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


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
	
	# Safety check: ensure node is still valid and in tree before changing scene
	if not is_instance_valid(self) or not is_inside_tree():
		print("[SidekickWaiting] Node no longer valid, skipping scene change")
		return
	
	var tree = get_tree()
	if tree == null:
		print("[SidekickWaiting] SceneTree is null, cannot change scene")
		return
	
	tree.change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _on_host_disconnected(_data: Dictionary = {}):
	status_label.text = "Detective disconnected!\nReturning to menu..."
	status_label.modulate = Color(1, 0, 0)

	await get_tree().create_timer(2.0).timeout
	
	# Safety check: ensure node is still valid and in tree before changing scene
	if not is_instance_valid(self) or not is_inside_tree():
		print("[SidekickWaiting] Node no longer valid, skipping scene change")
		return
	
	var tree = get_tree()
	if tree == null:
		print("[SidekickWaiting] SceneTree is null, cannot change scene")
		return
	
	tree.change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _on_connection_state_changed(new_state: int, _old_state: int):
	# If we get disconnected while in lobby, return to main menu
	# ConnectionState.DISCONNECTED = 0
	if new_state == 0:
		status_label.text = "Connection lost!\nReturning to menu..."
		status_label.modulate = Color(1, 0, 0)
		
		await get_tree().create_timer(2.0).timeout
		
		# Safety check: ensure node is still valid and in tree before changing scene
		if not is_instance_valid(self) or not is_inside_tree():
			print("[SidekickWaiting] Node no longer valid, skipping scene change")
			return
		
		var tree = get_tree()
		if tree == null:
			print("[SidekickWaiting] SceneTree is null, cannot change scene")
			return
		
		tree.change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _on_cancel_pressed():
	NetworkManager.disconnect_network()
	
	# Safety check: ensure node is still in tree before changing scene
	if not is_inside_tree():
		return
	
	var tree = get_tree()
	if tree == null:
		return
	
	tree.change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")
