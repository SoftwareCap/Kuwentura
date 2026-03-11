extends Node2D

## Forest Hub - Main world scene with zone portals and player spawning

# Preload both player scenes
@onready var player_host_scene: PackedScene = preload("res://scenes/players/PlayerHost.tscn")
@onready var player_sidekick_scene: PackedScene = preload("res://scenes/players/PlayerSidekick.tscn")

# Scale configuration for Forest Hub
@export var detective_scale: Vector2 = Vector2(0.2, 0.2)
@export var sidekick_scale: Vector2 = Vector2(0.2, 0.2)
@export var ground_y: float = 750.0

@onready var spawn_points: Node2D = $SpawnPoints
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue

# Track spawned players
var _spawned_players: Dictionary = {}

# Panel management
var _current_open_panel: String = ""  # "map", "ledger", "briefcase", or ""
var _is_animating: bool = false

# Animation constants
const PANEL_ANIMATION_DURATION: float = 0.4
const LEDGER_OPEN_SCALE: Vector2 = Vector2(1.0, 1.0)
const LEDGER_CLOSED_SCALE: Vector2 = Vector2(0.1, 1.0)
const BRIEFCASE_OPEN_SCALE: Vector2 = Vector2(1.0, 1.0)
const BRIEFCASE_CLOSED_SCALE: Vector2 = Vector2(1.0, 0.1)

# Sidekick UI elements
@onready var sidekick_layer: CanvasLayer = $SidekickLayer
@onready var ledger_panel: Panel = $SidekickLayer/Ledger
@onready var briefcase_panel: Panel = $SidekickLayer/Briefcase

# Map panel (accessible by both)
@onready var map_layer: CanvasLayer = $MapLayer
@onready var map_panel: Panel = $MapLayer/Map

# Portal references
@onready var portals: Node2D = $"Zone Portals"

# Room code label (only visible to host, follows camera via CanvasLayer)
@onready var room_code_label: Label = $HUDLayer/RoomCode


func _ready():
	# Setup room code label - only visible to host
	_setup_room_code_label()
	
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
	
	# Connect to rejoin signal for position sync
	if not NetworkManager.rejoin_game_requested.is_connected(_on_rejoin_game_requested):
		NetworkManager.rejoin_game_requested.connect(_on_rejoin_game_requested)
	
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
	
	# Setup UI controls (Map, Ledger, Briefcase buttons)
	_setup_ui_controls()
	
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
		
		# Clear saved spawn positions after all players have been spawned
		# This prevents positions from being used for lobby/rejoin spawns
		await get_tree().create_timer(0.5).timeout
		GameState.clear_spawn_position(1)
		for peer_id in multiplayer.get_peers():
			GameState.clear_spawn_position(peer_id)


## Setup room code label - only visible to host
func _setup_room_code_label() -> void:
	if not room_code_label:
		return
	
	# Only show room code to the host (Detective)
	if multiplayer.is_server():
		var room_code = NetworkManager.get_room_code()
		if room_code.is_empty():
			room_code = "N/A"
		room_code_label.text = "Code: " + room_code
		room_code_label.visible = true
		print("[ForestHub] Room code displayed for host: ", room_code)
	else:
		# Hide from sidekick
		room_code_label.visible = false
		print("[ForestHub] Room code hidden for sidekick")


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
		player.role = "Detective"
		player.avatar_scale = detective_scale
		print("[ForestHub] Instantiated Detective scene")
	else:
		player = player_sidekick_scene.instantiate()
		player.role = "Sidekick"
		player.avatar_scale = sidekick_scale
		print("[ForestHub] Instantiated Sidekick scene")
	
	player.name = str(peer_id)
	
	# Get spawn position
	# Check if player has a saved position (from returning from a zone)
	var saved_pos = GameState.get_spawn_position(peer_id)
	var has_saved_pos = saved_pos != Vector2.ZERO
	
	if has_saved_pos:
		# Player is returning from a zone - use their saved position
		spawn_pos = saved_pos
		# Don't clear here - clear after all players are spawned to avoid race conditions
		print("[ForestHub] Using saved return position for ", "Detective" if is_detective else "Sidekick", ": ", spawn_pos)
	else:
		# First time spawn or rejoin - use initial spawn markers
		if is_detective:
			spawn_marker = spawn_points.get_node_or_null("DetectiveSpawn")
		else:
			spawn_marker = spawn_points.get_node_or_null("SidekickSpawn")
		
		if spawn_marker:
			spawn_pos = spawn_marker.global_position
			print("[ForestHub] Using spawn marker for ", "Detective" if is_detective else "Sidekick", " at: ", spawn_pos)
		else:
			# FIXED: Detective on LEFT (200), Sidekick on RIGHT (600) to match spawn marker layout
			spawn_pos = Vector2(200 if is_detective else 600, ground_y)
			push_warning("[ForestHub] Spawn marker not found for " + ("Detective" if is_detective else "Sidekick") + ", using default position: " + str(spawn_pos))
	
	player.global_position = spawn_pos
	
	# Stabilize physics immediately to prevent sliding
	_stabilize_player_physics(player)
	
	# Set multiplayer authority
	player.set_multiplayer_authority(peer_id)
	
	# Track and add to scene
	_spawned_players[peer_id] = player
	add_child(player, true)
	
	# Force visibility and re-stabilize after adding to tree
	_force_visibility_recursive(player)
	_call_stabilize_after_frame(player)
	
	# Deferred visibility check to ensure it sticks
	_call_deferred_visibility_check(player)
	
	print("[ForestHub] === SPAWNED ", player.role, " (ID: ", peer_id, ") at ", spawn_pos, " visible=", player.visible, " in_tree=", player.is_inside_tree())


func _on_player_connected(peer_id: int, _role: int = 0) -> void:
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
			# Ensure the player is visible after spawning
			_ensure_player_visible(peer_id)
		
		# Tell the new peer to spawn the host (ID 1)
		print("[ForestHub] Telling peer ", peer_id, " to spawn host (ID 1)")
		NetworkManager.request_spawn_player(peer_id, 1, true)
		
		# Tell all existing peers (including server) about the new player
		for other_peer in multiplayer.get_peers():
			if other_peer != peer_id:
				print("[ForestHub] Telling peer ", other_peer, " to spawn new player ", peer_id)
				NetworkManager.request_spawn_player(other_peer, peer_id, false)
				# Ensure visibility on the remote peer's side as well
				_ensure_player_visible_on_peer.rpc_id(other_peer, peer_id)


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
func _on_partner_disconnected(reason: String) -> void:
	print("[ForestHub] Partner disconnected, reason: ", reason)
	
	# Only go back to main menu if WE are the sidekick and the HOST disconnected
	# The host (detective) should stay in the game when sidekick disconnects
	var my_role = NetworkManager.get_my_role()
	
	# Host disconnected → sidekick goes back to menu
	# Sidekick disconnected → host stays in game (can wait for rejoin)
	if reason == "host_disconnected" or (not NetworkManager.has_active_connection() and my_role != "detective"):
		print("[ForestHub] Host disconnected! Returning to main menu...")
		
		# Unpause before leaving
		get_tree().paused = false
		
		# Ensure network is fully disconnected
		NetworkManager.disconnect_network()
		
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
	var spawn_pos: Vector2
	
	if is_detective_role:
		player = player_host_scene.instantiate()
		player.role = "Detective"
		player.avatar_scale = detective_scale
		print("[ForestHub] RPC: Instantiated Detective")
	else:
		player = player_sidekick_scene.instantiate()
		player.role = "Sidekick"
		player.avatar_scale = sidekick_scale
		print("[ForestHub] RPC: Instantiated Sidekick")
	
	player.name = str(peer_id)
	
	# Check for saved position (from returning from a zone)
	var saved_pos = GameState.get_spawn_position(peer_id)
	var has_saved_pos = saved_pos != Vector2.ZERO
	
	if has_saved_pos:
		# Player is returning from a zone - use their saved position
		spawn_pos = saved_pos
		# Don't clear here - server clears after all players are spawned
		print("[ForestHub] RPC: Using saved return position for ", "Detective" if is_detective_role else "Sidekick", ": ", spawn_pos)
	else:
		# Use initial spawn markers
		if is_detective_role:
			spawn_marker = spawn_points.get_node_or_null("DetectiveSpawn")
		else:
			spawn_marker = spawn_points.get_node_or_null("SidekickSpawn")
		
		if spawn_marker:
			spawn_pos = spawn_marker.global_position
			print("[ForestHub] RPC: Using spawn marker for ", "Detective" if is_detective_role else "Sidekick", " at: ", spawn_pos)
		else:
			# FIXED: Detective on LEFT (200), Sidekick on RIGHT (600) to match spawn marker layout
			spawn_pos = Vector2(200 if is_detective_role else 600, ground_y)
			push_warning("[ForestHub] RPC: Spawn marker not found for " + ("Detective" if is_detective_role else "Sidekick") + ", using default position: " + str(spawn_pos))
	
	player.global_position = spawn_pos
	
	# Stabilize physics to prevent sliding
	_stabilize_player_physics(player)
	
	player.set_multiplayer_authority(peer_id)
	_force_visibility_recursive(player)
	_spawned_players[peer_id] = player
	add_child(player, true)
	
	# Stabilize after adding to tree
	_call_stabilize_after_frame(player)
	
	# Deferred visibility check
	_call_deferred_visibility_check(player)
	
	print("[ForestHub] === RPC SPAWNED ", player.role, " (ID: ", peer_id, ") at ", player.global_position, " visible=", player.visible)


## Stabilize player physics to prevent sliding after spawn
func _stabilize_player_physics(player: CharacterBody2D) -> void:
	"""Set physics properties to ensure player stays grounded."""
	# Reset velocity to prevent any inherited motion
	player.velocity = Vector2.ZERO
	
	# Ensure player is grounded by adjusting position slightly if needed
	# This is done before adding to tree, so we set a flag for post-add stabilization
	player.set_meta("_needs_grounding", true)


## Call stabilization after player is added to scene tree
func _call_stabilize_after_frame(player: CharacterBody2D) -> void:
	"""Stabilize player after they've been added to the scene tree."""
	# Wait for physics to settle - multiple frames for safety
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if not is_instance_valid(player):
		return
	
	# Reset velocity to zero
	player.velocity = Vector2.ZERO
	
	# Force the player onto the floor
	if player.has_method("_force_grounded"):
		player._force_grounded()
	
	# Additional safety: wait another frame and verify grounded
	await get_tree().physics_frame
	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		if player.has_method("_force_grounded"):
			player._force_grounded()


## Force visibility on a player and all its children recursively
func _force_visibility_recursive(node: Node) -> void:
	if node is CanvasItem:
		node.visible = true
		if node is AnimatedSprite2D:
			node.play("idle")
	for child in node.get_children():
		_force_visibility_recursive(child)


## Deferred visibility check to ensure player stays visible
func _call_deferred_visibility_check(player: CharacterBody2D) -> void:
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(player):
		_force_visibility_recursive(player)
		print("[ForestHub] Deferred visibility check for player ", player.name)


## Ensure a player is visible (called after spawning)
func _ensure_player_visible(peer_id: int) -> void:
	var player_node = get_node_or_null(str(peer_id))
	if not player_node:
		return
	
	_force_visibility_recursive(player_node)
	print("[ForestHub] Ensured visibility for player ", peer_id)


## RPC to ensure player visibility on a specific peer
@rpc("authority", "reliable")
func _ensure_player_visible_on_peer(peer_id: int) -> void:
	var player_node = get_node_or_null(str(peer_id))
	if not player_node:
		return
	
	_force_visibility_recursive(player_node)
	print("[ForestHub] Ensured visibility on peer for player ", peer_id)


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
	if NetworkManager.rejoin_game_requested.is_connected(_on_rejoin_game_requested):
		NetworkManager.rejoin_game_requested.disconnect(_on_rejoin_game_requested)


## Handle rejoin game - update detective position if already in forest
func _on_rejoin_game_requested(rejoin_data: Dictionary) -> void:
	print("[ForestHub] Rejoin data received, updating player positions...")
	
	var player_positions = rejoin_data.get("player_positions", {})
	
	# Update detective position if they're already spawned
	var detective_node = get_node_or_null("1")
	if detective_node and str(detective_node.name) == "1":
		var host_pos_data = player_positions.get("1", {})
		if host_pos_data is Dictionary and host_pos_data.has("position"):
			var pos = Vector2(host_pos_data.position.x, host_pos_data.position.y)
			detective_node.global_position = pos
			print("[ForestHub] Updated detective position to: ", pos)
	
	# Spawn any missing players and ensure visibility
	for peer_id_str in player_positions.keys():
		var peer_id = int(peer_id_str)
		if peer_id != multiplayer.get_unique_id() and not _spawned_players.has(peer_id):
			print("[ForestHub] Spawning missing player from rejoin: ", peer_id)
			if peer_id == 1:
				_rpc_spawn_player(peer_id, true)  # Detective
			else:
				_rpc_spawn_player(peer_id, false)  # Sidekick
			# Ensure visibility after spawn
			_ensure_player_visible(peer_id)


func _process(_delta):
	# Button positions are now controlled via Inspector - no dynamic updates needed
	pass


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


# ============================================================================
# PANEL MANAGEMENT (Map, Ledger, Briefcase)
# ============================================================================
func _setup_ui_controls() -> void:
	"""Setup UI controls visibility based on role and connect signals."""
	var my_role := NetworkManager.get_my_role()
	var is_sidekick := (my_role != "detective")
	
	print("[ForestHub] Setting up UI controls for role: ", my_role)
	
	# Connect to TouchControls signals
	if touch_controls:
		if not touch_controls.map_pressed.is_connected(_on_map_button_pressed):
			touch_controls.map_pressed.connect(_on_map_button_pressed)
		if not touch_controls.ledger_pressed.is_connected(_on_ledger_button_pressed):
			touch_controls.ledger_pressed.connect(_on_ledger_button_pressed)
		if not touch_controls.briefcase_pressed.is_connected(_on_briefcase_button_pressed):
			touch_controls.briefcase_pressed.connect(_on_briefcase_button_pressed)
		
		# Set visibility based on role
		if touch_controls.map_button:
			touch_controls.map_button.visible = true  # Map is visible to both
		if touch_controls.ledger_button:
			touch_controls.ledger_button.visible = is_sidekick  # Ledger only for sidekick
		if touch_controls.briefcase_button:
			touch_controls.briefcase_button.visible = is_sidekick  # Briefcase only for sidekick
	
	# Initialize panels as hidden
	_close_all_panels(false)


func _on_map_button_pressed() -> void:
	"""Toggle map panel."""
	if _is_animating:
		return
	
	if _current_open_panel == "map":
		_close_all_panels()
	else:
		_close_all_panels(false)
		_open_panel("map")


func _on_ledger_button_pressed() -> void:
	"""Toggle ledger panel with book opening animation."""
	if _is_animating:
		return
	
	if _current_open_panel == "ledger":
		_close_all_panels()
	else:
		_close_all_panels(false)
		_open_panel("ledger")


func _on_briefcase_button_pressed() -> void:
	"""Toggle briefcase panel with opening animation."""
	if _is_animating:
		return
	
	if _current_open_panel == "briefcase":
		_close_all_panels()
	else:
		_close_all_panels(false)
		_open_panel("briefcase")


func _open_panel(panel_name: String) -> void:
	"""Open a specific panel with animation."""
	match panel_name:
		"map":
			_open_map()
		"ledger":
			_open_ledger()
		"briefcase":
			_open_briefcase()
	
	_current_open_panel = panel_name
	print("[ForestHub] Opened panel: ", panel_name)


func _close_all_panels(animate: bool = true) -> void:
	"""Close all panels."""
	if _current_open_panel == "":
		return
	
	match _current_open_panel:
		"map":
			_close_map(animate)
		"ledger":
			_close_ledger(animate)
		"briefcase":
			_close_briefcase(animate)
	
	_current_open_panel = ""


# ============================================================================
# MAP PANEL
# ============================================================================
func _open_map() -> void:
	if not map_panel:
		return
	
	map_panel.visible = true
	map_panel.modulate = Color(1, 1, 1, 0)
	map_panel.scale = Vector2(0.8, 0.8)
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(map_panel, "modulate", Color(1, 1, 1, 1), PANEL_ANIMATION_DURATION)
	tween.parallel().tween_property(map_panel, "scale", Vector2(1, 1), PANEL_ANIMATION_DURATION)


func _close_map(animate: bool = true) -> void:
	if not map_panel or not map_panel.visible:
		return
	
	if animate:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(map_panel, "modulate", Color(1, 1, 1, 0), PANEL_ANIMATION_DURATION * 0.5)
		tween.parallel().tween_property(map_panel, "scale", Vector2(0.8, 0.8), PANEL_ANIMATION_DURATION * 0.5)
		tween.tween_callback(func(): map_panel.visible = false)
	else:
		map_panel.visible = false


# ============================================================================
# LEDGER PANEL (Book Opening Animation)
# ============================================================================
func _open_ledger() -> void:
	if not ledger_panel:
		return
	
	_is_animating = true
	ledger_panel.visible = true
	ledger_panel.scale = LEDGER_CLOSED_SCALE
	ledger_panel.pivot_offset = ledger_panel.size / 2
	
	# Book opening animation (scale X from 0.1 to 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ledger_panel, "scale", LEDGER_OPEN_SCALE, PANEL_ANIMATION_DURATION)
	tween.tween_callback(func(): _is_animating = false)


func _close_ledger(animate: bool = true) -> void:
	if not ledger_panel or not ledger_panel.visible:
		return
	
	if animate:
		_is_animating = true
		# Book closing animation
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(ledger_panel, "scale", LEDGER_CLOSED_SCALE, PANEL_ANIMATION_DURATION * 0.5)
		tween.tween_callback(func(): 
			ledger_panel.visible = false
			_is_animating = false
		)
	else:
		ledger_panel.visible = false
		ledger_panel.scale = LEDGER_CLOSED_SCALE


# ============================================================================
# BRIEFCASE PANEL (Case Opening Animation)
# ============================================================================
func _open_briefcase() -> void:
	if not briefcase_panel:
		return
	
	_is_animating = true
	briefcase_panel.visible = true
	briefcase_panel.scale = BRIEFCASE_CLOSED_SCALE
	briefcase_panel.pivot_offset = Vector2(briefcase_panel.size.x / 2, 0)  # Pivot at top
	
	# Briefcase opening animation (scale Y from 0.1 to 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(briefcase_panel, "scale", BRIEFCASE_OPEN_SCALE, PANEL_ANIMATION_DURATION)
	tween.tween_callback(func(): _is_animating = false)


func _close_briefcase(animate: bool = true) -> void:
	if not briefcase_panel or not briefcase_panel.visible:
		return
	
	if animate:
		_is_animating = true
		# Briefcase closing animation
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(briefcase_panel, "scale", BRIEFCASE_CLOSED_SCALE, PANEL_ANIMATION_DURATION * 0.5)
		tween.tween_callback(func(): 
			briefcase_panel.visible = false
			_is_animating = false
		)
	else:
		briefcase_panel.visible = false
		briefcase_panel.scale = BRIEFCASE_CLOSED_SCALE
