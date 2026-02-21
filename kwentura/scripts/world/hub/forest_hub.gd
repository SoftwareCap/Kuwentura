extends Node2D

## Forest Hub - Main world scene with zone portals and player spawning

# Preload both player scenes
@onready var player_host_scene: PackedScene = preload("res://scenes/players/PlayerHost.tscn")
@onready var player_sidekick_scene: PackedScene = preload("res://scenes/players/PlayerSidekick.tscn")

# Scale configuration for Forest Hub
@export var detective_scale: Vector2 = Vector2(0.3, 0.3)
@export var sidekick_scale: Vector2 = Vector2(0.3, 0.3)
@export var ground_y: float = 750.0

@onready var spawn_points: Node2D = $SpawnPoints
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeValue

# Track spawned players
var _spawned_players: Dictionary = {}


func _ready():
	# Verify required nodes exist
	if spawn_points == null:
		push_error("[ForestHub] SpawnPoints node not found! Creating fallback spawn points.")
		spawn_points = Node2D.new()
		spawn_points.name = "SpawnPoints"
		add_child(spawn_points)
		
		# Create default spawn markers
		var detective_spawn = Marker2D.new()
		detective_spawn.name = "DetectiveSpawn"
		detective_spawn.position = Vector2(400, ground_y)
		spawn_points.add_child(detective_spawn)
		
		var sidekick_spawn = Marker2D.new()
		sidekick_spawn.name = "SidekickSpawn"
		sidekick_spawn.position = Vector2(600, ground_y)
		spawn_points.add_child(sidekick_spawn)
	
	# Play forest hub music
	MusicController.play_track(MusicController.MusicTrack.FOREST_HUB)
	
	print("[ForestHub] Initializing... Multiplayer ID: ", multiplayer.get_unique_id())
	print("[ForestHub] Peers: ", multiplayer.get_peers())
	
	# Connect to network signals
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.partner_disconnected.connect(_on_partner_disconnected)
	
	# Connect to spawn signals from NetworkManager (RPCs now handled there)
	if not NetworkManager.spawn_player_requested.is_connected(_on_spawn_player_requested):
		NetworkManager.spawn_player_requested.connect(_on_spawn_player_requested)
	if not NetworkManager.despawn_player_requested.is_connected(_on_despawn_player_requested):
		NetworkManager.despawn_player_requested.connect(_on_despawn_player_requested)
	
	# Connect touch controls pause button
	print("[ForestHub] Setting up touch controls...")
	if touch_controls:
		print("[ForestHub] TouchControls found")
		# Connect to the pause_pressed signal from TouchControls
		if touch_controls.has_signal("pause_pressed"):
			print("[ForestHub] TouchControls has pause_pressed signal")
			if not touch_controls.pause_pressed.is_connected(_on_pause_button_pressed):
				touch_controls.pause_pressed.connect(_on_pause_button_pressed)
				print("[ForestHub] Connected pause_pressed signal")
		else:
			print("[ForestHub] TouchControls does NOT have pause_pressed signal")
	else:
		push_error("[ForestHub] TouchControls not found!")
	
	# Initialize pause panel
	print("[ForestHub] Initializing pause panel...")
	if in_game_pause_panel:
		print("[ForestHub] Pause panel found, setting invisible")
		in_game_pause_panel.visible = false
		# Set initial volume slider value
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
			print("[ForestHub] Volume slider set to: ", volume_slider.value)
		if volume_value_label:
			volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"
	else:
		push_error("[ForestHub] InGamePausePanel not found!")
	
	# Spawn local player
	_spawn_local_player()
	
	# Spawn already connected peers (both server and client)
	for peer_id in multiplayer.get_peers():
		if peer_id != multiplayer.get_unique_id() and not _spawned_players.has(peer_id):
			print("[ForestHub] Spawning already connected peer: ", peer_id)
			_spawn_player_for_peer(peer_id)
	
	# Server tells all clients about existing players
	if multiplayer.is_server():
		await get_tree().process_frame
		# Tell each peer to spawn all other players (including the host)
		for peer_id in multiplayer.get_peers():
			if peer_id != multiplayer.get_unique_id():
				# Tell this peer to spawn the host (ID 1)
				print("[ForestHub] Telling peer ", peer_id, " to spawn host")
				NetworkManager.request_spawn_player(peer_id, 1, true)
				# Tell all other peers to spawn this peer
				for other_peer in multiplayer.get_peers():
					if other_peer != peer_id and other_peer != multiplayer.get_unique_id():
						print("[ForestHub] Telling peer ", other_peer, " to spawn peer ", peer_id)
						NetworkManager.request_spawn_player(other_peer, peer_id, false)


## Open the pause panel (called when touch controls option button is pressed)
func _on_pause_button_pressed() -> void:
	print("[ForestHub] ========== PAUSE BUTTON PRESSED ==========")
	if in_game_pause_panel:
		in_game_pause_panel.visible = true
		# Hide option sub-panel when opening pause
		if option_sub_panel:
			option_sub_panel.visible = false
		print("[ForestHub] Pause panel visible: ", in_game_pause_panel.visible)
		print("[ForestHub] In-game pause panel OPENED")
		# Pause the game
		get_tree().paused = true
	else:
		push_error("[ForestHub] Cannot open pause - in_game_pause_panel is null!")


## Resume button pressed - closes pause panel and resumes game
func _on_resume_play_button_pressed() -> void:
	print("[ForestHub] Resume button pressed - resuming game")
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
	if option_sub_panel:
		option_sub_panel.visible = false
	get_tree().paused = false
	print("[ForestHub] Game RESUMED")


## Option button pressed - opens the option sub-panel
func _on_option_button_pressed() -> void:
	print("[ForestHub] Option button pressed - opening options")
	if option_sub_panel:
		option_sub_panel.visible = true
		# Update slider to current volume
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"
		print("[ForestHub] Option sub-panel OPENED")
	else:
		push_error("[ForestHub] Cannot open options - option_sub_panel is null!")


## Back button pressed (BackToPrevious on option sub-panel) - returns to pause panel
func _on_in_game_option_back_pressed() -> void:
	print("[ForestHub] Back button pressed")
	if option_sub_panel and option_sub_panel.visible:
		# If option panel is open, close it and return to pause panel
		option_sub_panel.visible = false
		print("[ForestHub] Option sub-panel closed, back to pause panel")


## Exit to Main Menu button pressed
func _on_exit_to_main_menu_button_pressed() -> void:
	print("[ForestHub] Exit to Main Menu button pressed")
	# Unpause before leaving
	get_tree().paused = false
	
	# Disconnect from network if connected
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		# Small delay to ensure disconnect is processed
		await get_tree().create_timer(0.2).timeout
	
	# Save settings
	_save_pause()
	
	# Return to main menu (check if still in tree after delay)
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _on_in_game_volume_changed(value: float) -> void:
	var volume = value / 100.0
	MusicController.set_volume(volume)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"
	print("[ForestHub] Volume changed to: ", volume)


func _save_pause() -> void:
	const OPTION_FILE = "user://settings.json"
	var data = {
		"volume": MusicController.get_volume()
	}
	
	var file = FileAccess.open(OPTION_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("[ForestHub] Pause saved successfully")


func _on_spawn_player_requested(peer_id: int, is_detective: bool):
	print("[ForestHub] Spawn requested via NetworkManager: peer_id=", peer_id, " is_detective=", is_detective)
	_rpc_spawn_player(peer_id, is_detective)


func _on_despawn_player_requested(peer_id: int):
	print("[ForestHub] Despawn requested via NetworkManager: peer_id=", peer_id)
	_rpc_despawn_player(peer_id)


func _spawn_local_player():
	var peer_id: int = multiplayer.get_unique_id()
	print("[ForestHub] Spawning local player, peer_id: ", peer_id)
	_spawn_player_for_peer(peer_id)


func _spawn_player_for_peer(peer_id: int) -> void:
	# Prevent duplicate spawns
	if _spawned_players.has(peer_id):
		print("[ForestHub] Player ", peer_id, " already spawned, skipping")
		return
	
	var is_detective: bool = (peer_id == 1)
	
	var player: CharacterBody2D
	var spawn_marker: Marker2D
	var spawn_pos: Vector2
	
	print("[ForestHub] === SPAWNING peer_id=", peer_id, " is_detective=", is_detective, " my_id=", multiplayer.get_unique_id())
	
	if is_detective:
		player = player_host_scene.instantiate()
		spawn_marker = spawn_points.get_node_or_null("DetectiveSpawn")
		player.role = "Detective"
		player.avatar_scale = detective_scale
		print("[ForestHub] Instantiated Detective scene")
	else:
		player = player_sidekick_scene.instantiate()
		spawn_marker = spawn_points.get_node_or_null("SidekickSpawn")
		player.role = "Sidekick"
		player.avatar_scale = sidekick_scale
		print("[ForestHub] Instantiated Sidekick scene")
	
	player.name = str(peer_id)
	
	# Get spawn position - use saved position if returning from a zone
	var saved_pos = GameState.get_spawn_position(peer_id)
	if saved_pos != Vector2.ZERO:
		# Use saved position from before entering zone
		spawn_pos = saved_pos
		GameState.clear_spawn_position(peer_id)  # Clear after using
		print("[ForestHub] Using saved spawn position for ", "Detective" if is_detective else "Sidekick", ": ", spawn_pos)
	elif spawn_marker:
		spawn_pos = spawn_marker.global_position
	else:
		spawn_pos = Vector2(400 if is_detective else 200, ground_y)
		push_warning("[ForestHub] Spawn marker not found for " + ("Detective" if is_detective else "Sidekick") + ", using default position")
	
	player.global_position = spawn_pos
	
	# Set multiplayer authority
	player.set_multiplayer_authority(peer_id)
	
	# Track and add to scene
	_spawned_players[peer_id] = player
	add_child(player, true)
	
	# Force visibility
	player.visible = true
	
	print("[ForestHub] === SPAWNED ", player.role, " (ID: ", peer_id, ") at ", spawn_pos, " visible=", player.visible, " in_tree=", player.is_inside_tree())


func _on_player_connected(peer_id: int) -> void:
	print("[ForestHub] Player connected signal: ", peer_id)
	
	if multiplayer.is_server():
		# Clean up any existing player node for this peer (in case of reconnection)
		var existing_node = get_node_or_null(str(peer_id))
		if existing_node:
			print("[ForestHub] Removing existing player node for peer ", peer_id)
			existing_node.queue_free()
			_spawned_players.erase(peer_id)
		
		# Also clean up any other sidekick nodes (in case peer_id changed on reconnect)
		# This prevents duplicate sidekick avatars
		for child in get_children():
			if child is CharacterBody2D:
				var child_peer_id = int(child.name)
				if child_peer_id > 1 and child_peer_id != peer_id:  # Not host and not the new peer
					if not multiplayer.get_peers().has(child_peer_id):
						print("[ForestHub] Cleaning up old sidekick node: ", child.name)
						child.queue_free()
		
		# Server spawns the new player locally
		if not _spawned_players.has(peer_id):
			_spawn_player_for_peer(peer_id)
		
		# Tell the new peer to spawn the host (ID 1)
		print("[ForestHub] Telling peer ", peer_id, " to spawn host (ID 1)")
		NetworkManager.request_spawn_player(peer_id, 1, true)
		
		# Tell all existing peers (including server) about the new player
		for other_peer in multiplayer.get_peers():
			if other_peer != peer_id:
				print("[ForestHub] Telling peer ", other_peer, " to spawn new player ", peer_id)
				NetworkManager.request_spawn_player(other_peer, peer_id, false)


func _on_player_disconnected(peer_id: int) -> void:
	print("[ForestHub] Player disconnected: ", peer_id)
	
	# Remove the player node if it exists
	var player_node: Node = get_node_or_null(str(peer_id))
	if player_node:
		print("[ForestHub] Removing player node for peer ", peer_id)
		player_node.queue_free()
	
	_spawned_players.erase(peer_id)
	
	# Tell all clients to remove this player
	if multiplayer.is_server():
		NetworkManager.request_despawn_player(peer_id)
		
		# Also clean up any orphaned sidekick nodes (in case of quick reconnect with new peer_id)
		_cleanup_orphaned_players()


## Called when partner disconnects (host disconnected for sidekick, or sidekick disconnected for host)
func _on_partner_disconnected(player_data: Dictionary) -> void:
	print("[ForestHub] Partner disconnected: ", player_data)
	
	# Get the reason for disconnection
	var reason = player_data.get("reason", "")
	
	# If host disconnected (detected via reason or by checking if we were the sidekick)
	# Host disconnection can be detected by reason or by having no active connection
	if reason == "host_disconnected" or not NetworkManager.has_active_connection():
		print("[ForestHub] Host disconnected! Returning to main menu...")
		
		# Unpause before leaving
		get_tree().paused = false
		
		# Show a message to the player (optional - could add a popup here)
		
		# Return to main menu after a short delay to allow cleanup
		await get_tree().create_timer(0.5).timeout
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


## Clean up orphaned player nodes (for reconnection scenarios)
func _cleanup_orphaned_players() -> void:
	# Get list of currently connected peers
	var connected_peers = multiplayer.get_peers()
	
	# Check all children for player nodes that shouldn't exist
	for child in get_children():
		# Check if this is a player node (CharacterBody2D with name as number)
		if child is CharacterBody2D:
			var peer_id = int(child.name)
			if peer_id > 0:  # Valid peer ID
				# If this peer is not in our spawned list and not in connected peers, remove it
				if not _spawned_players.has(peer_id) and not connected_peers.has(peer_id):
					print("[ForestHub] Cleaning up orphaned player node: ", child.name)
					child.queue_free()


## Spawn player via NetworkManager signal (not direct RPC)
func _rpc_spawn_player(peer_id: int, is_detective_role: bool) -> void:
	print("[ForestHub] === RPC SPAWN peer_id=", peer_id, " is_detective=", is_detective_role, " my_id=", multiplayer.get_unique_id())
	
	if _spawned_players.has(peer_id):
		print("[ForestHub] Player ", peer_id, " already exists, skipping")
		return
	
	if peer_id == multiplayer.get_unique_id():
		print("[ForestHub] Not spawning self")
		return
	
	# Remove any existing node with this name (in case of cleanup issues)
	var existing_node = get_node_or_null(str(peer_id))
	if existing_node:
		print("[ForestHub] Removing existing node with name ", peer_id)
		existing_node.queue_free()
	
	var player: CharacterBody2D
	var spawn_marker: Marker2D
	
	if is_detective_role:
		player = player_host_scene.instantiate()
		spawn_marker = spawn_points.get_node_or_null("DetectiveSpawn")
		player.role = "Detective"
		player.avatar_scale = detective_scale
		print("[ForestHub] RPC: Instantiated Detective")
	else:
		player = player_sidekick_scene.instantiate()
		spawn_marker = spawn_points.get_node_or_null("SidekickSpawn")
		player.role = "Sidekick"
		player.avatar_scale = sidekick_scale
		print("[ForestHub] RPC: Instantiated Sidekick")
	
	player.name = str(peer_id)
	
	# Check for saved position (returning from zone)
	var saved_pos = GameState.get_spawn_position(peer_id)
	if saved_pos != Vector2.ZERO:
		player.global_position = saved_pos
		print("[ForestHub] RPC: Using saved position for ", "Detective" if is_detective_role else "Sidekick", ": ", saved_pos)
	elif spawn_marker:
		player.global_position = spawn_marker.global_position
	else:
		player.global_position = Vector2(400 if is_detective_role else 200, ground_y)
		push_warning("[ForestHub] RPC: Spawn marker not found, using default position")
	
	player.set_multiplayer_authority(peer_id)
	player.visible = true
	_spawned_players[peer_id] = player
	add_child(player, true)
	
	print("[ForestHub] === RPC SPAWNED ", player.role, " (ID: ", peer_id, ") at ", player.global_position, " visible=", player.visible)


func _rpc_despawn_player(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	var player_node: Node = get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
	_spawned_players.erase(peer_id)


func _exit_tree():
	if NetworkManager.player_connected.is_connected(_on_player_connected):
		NetworkManager.player_connected.disconnect(_on_player_connected)
	if NetworkManager.player_disconnected.is_connected(_on_player_disconnected):
		NetworkManager.player_disconnected.disconnect(_on_player_disconnected)
	if NetworkManager.partner_disconnected.is_connected(_on_partner_disconnected):
		NetworkManager.partner_disconnected.disconnect(_on_partner_disconnected)
	if NetworkManager.spawn_player_requested.is_connected(_on_spawn_player_requested):
		NetworkManager.spawn_player_requested.disconnect(_on_spawn_player_requested)
	if NetworkManager.despawn_player_requested.is_connected(_on_despawn_player_requested):
		NetworkManager.despawn_player_requested.disconnect(_on_despawn_player_requested)


func _input(event):
	# Debug: Press F1 to list all players
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		print("[ForestHub] === DEBUG: Spawned players ===")
		for peer_id in _spawned_players:
			var p = _spawned_players[peer_id]
			print("  Player ", peer_id, ": role=", p.role, " pos=", p.global_position, " visible=", p.visible)
		print("[ForestHub] === Scene children ===")
		for child in get_children():
			if child is CharacterBody2D:
				print("  Node: ", child.name, " role=", child.role, " pos=", child.global_position)
