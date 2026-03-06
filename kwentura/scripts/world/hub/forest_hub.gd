extends Node2D

## Forest Hub - Main world scene with zone portals and player spawning

# Preload both player scenes
@onready var player_host_scene: PackedScene = preload("res://scenes/players/PlayerHost.tscn")
@onready var player_sidekick_scene: PackedScene = preload("res://scenes/players/PlayerSidekick.tscn")

# Scale configuration for Forest Hub
# Adjusted to match the re-designed scene UI scales
@export var detective_scale: Vector2 = Vector2(0.2, 0.2)
@export var sidekick_scale: Vector2 = Vector2(0.2, 0.2)
@export var ground_y: float = 650.0

@onready var spawn_points: Node2D = $SpawnPoints
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue

# User Profile UI
@onready var view_user_profile_button: Button = $PauseCanvasLayer/InGamePausePanel/ViewUserProfile
@onready var user_profile_panel: Panel = $PauseCanvasLayer/InGamePausePanel/UserProfile
@onready var user_profile_back_button: TouchScreenButton = $PauseCanvasLayer/InGamePausePanel/UserProfile/BackToPrevious
@onready var avatar_texture: TextureRect = $PauseCanvasLayer/InGamePausePanel/UserProfile/UserContent/AvatarTexture
@onready var display_name_label: Label = $PauseCanvasLayer/InGamePausePanel/UserProfile/UserContent/UserInfo/DisplayName
@onready var provider_label: Label = $PauseCanvasLayer/InGamePausePanel/UserProfile/UserContent/UserInfo/ProviderLabel
@onready var sign_in_button: Button = $PauseCanvasLayer/InGamePausePanel/UserProfile/AuthButtons/SignInButton
@onready var guest_button: Button = $PauseCanvasLayer/InGamePausePanel/UserProfile/AuthButtons/GuestButton
@onready var link_google_button: Button = $PauseCanvasLayer/InGamePausePanel/UserProfile/AuthButtons/LinkGoogleButton

@onready var map_panel: Panel = get_node_or_null("SidekickLayer/MapPanel")

# Ledger, Briefcase, and Map panels
@onready var sidekick_layer: CanvasLayer = $SidekickLayer
@onready var ledger_panel: Panel = $SidekickLayer/LedgerPanel
@onready var briefcase_panel: Panel = $SidekickLayer/BriefcasePanel

# Room Code Label (Host only)
@onready var room_code_label: Label = $RoomCode

# Track spawned players
var _spawned_players: Dictionary = {}

# Track local player role
var _is_sidekick: bool = false

# Track currently open panel (for toggle behavior)
var _current_open_panel: String = ""  # "ledger", "briefcase", "map", or ""


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
	
	# Connect touch controls signals
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
		
		# Connect map signal (available to both)
		if touch_controls.has_signal("map_pressed"):
			print("[ForestHub] TouchControls has map_pressed signal, connecting...")
			if not touch_controls.map_pressed.is_connected(_on_map_button_pressed):
				touch_controls.map_pressed.connect(_on_map_button_pressed)
				print("[ForestHub] Connected map_pressed signal to _on_map_button_pressed")
			else:
				print("[ForestHub] map_pressed already connected")
		else:
			print("[ForestHub] TouchControls does NOT have map_pressed signal")
		
		# Connect ledger and briefcase signals (sidekick only)
		if touch_controls.has_signal("ledger_pressed"):
			if not touch_controls.ledger_pressed.is_connected(_on_ledger_button_pressed):
				touch_controls.ledger_pressed.connect(_on_ledger_button_pressed)
				print("[ForestHub] Connected ledger_pressed signal")
		if touch_controls.has_signal("briefcase_pressed"):
			if not touch_controls.briefcase_pressed.is_connected(_on_briefcase_button_pressed):
				touch_controls.briefcase_pressed.connect(_on_briefcase_button_pressed)
				print("[ForestHub] Connected briefcase_pressed signal")
		
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
		
		# Initialize user profile panel (hide initially)
		if user_profile_panel:
			user_profile_panel.visible = false
			print("[ForestHub] User profile panel initialized")
		
		# Connect user profile signals (only if in tree)
		if is_inside_tree():
			_connect_user_profile_signals()
			_update_user_ui()
	else:
		push_error("[ForestHub] InGamePausePanel not found!")
	
	# Spawn local player
	_spawn_local_player()
	
	# Determine if local player is sidekick (peer_id != 1 means sidekick)
	_is_sidekick = multiplayer.get_unique_id() != 1
	print("[ForestHub] Local player is sidekick: ", _is_sidekick)
	
	# Setup room code label - only visible for host (detective)
	_setup_room_code_label()
	
	# Initialize panels (hide initially)
	
	# Initialize panels (hide initially)
	if ledger_panel:
		ledger_panel.visible = false
		# Allow panel and its buttons to process while game is paused
		ledger_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		_set_buttons_process_mode(ledger_panel, Node.PROCESS_MODE_ALWAYS)
		# Make panel pass input through so we can detect clicks outside
		ledger_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		print("[ForestHub] Ledger panel initialized")
	if briefcase_panel:
		briefcase_panel.visible = false
		# Allow panel and its buttons to process while game is paused
		briefcase_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		_set_buttons_process_mode(briefcase_panel, Node.PROCESS_MODE_ALWAYS)
		# Make panel pass input through so we can detect clicks outside
		briefcase_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		print("[ForestHub] Briefcase panel initialized")
	if map_panel:
		map_panel.visible = false
		# Allow panel and its buttons to process while game is paused
		map_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		_set_buttons_process_mode(map_panel, Node.PROCESS_MODE_ALWAYS)
		# Make panel pass input through so we can detect clicks outside
		map_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		print("[ForestHub] Map panel initialized")
	
	# Setup button visibility based on role
	if touch_controls:
		# Pause button visible for both
		touch_controls.set_pause_enabled(true)
		print("[ForestHub] Pause button enabled")
		
		# Map button visible for both (or set to _is_sidekick if only sidekick should see it)
		touch_controls.set_map_enabled(true)
		print("[ForestHub] Map button enabled")
		
		# Only sidekick can see ledger and briefcase buttons
		touch_controls.set_ledger_enabled(_is_sidekick)
		touch_controls.set_briefcase_enabled(_is_sidekick)
		print("[ForestHub] Ledger/Briefcase buttons enabled for sidekick: ", _is_sidekick)
	
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


## Open the pause panel (called when touch controls pause button is pressed)
func _on_pause_button_pressed() -> void:
	print("[ForestHub] ========== PAUSE BUTTON PRESSED ==========")
	# Open pause locally only - do not sync to other peer
	_open_pause_panel()


## RPC to request pause from any peer to all peers - REMOVED (pause is now local only)
# Note: Kept for compatibility but no longer called
@rpc("any_peer", "reliable")
func _request_pause_rpc() -> void:
	pass  # No-op: pause is now local only


## Open the pause panel locally
func _open_pause_panel() -> void:
	if in_game_pause_panel:
		in_game_pause_panel.visible = true
		# Hide option sub-panel when opening pause
		if option_sub_panel:
			option_sub_panel.visible = false
		# Hide the pause button while pause panel is open (like settings button in main menu)
		if touch_controls:
			touch_controls.set_pause_enabled(false)
		print("[ForestHub] Pause panel opened for peer: ", multiplayer.get_unique_id())
		# Pause the game
		get_tree().paused = true
	else:
		push_error("[ForestHub] Cannot open pause - in_game_pause_panel is null!")


## Resume button pressed - closes pause panel and resumes game
func _on_resume_play_button_pressed() -> void:
	print("[ForestHub] Resume button pressed - resuming game")
	# Close pause locally only - do not sync to other peer
	_close_pause_panel()


## RPC to request resume from any peer to all peers - REMOVED (resume is now local only)
# Note: Kept for compatibility but no longer called
@rpc("any_peer", "reliable")
func _request_resume_rpc() -> void:
	pass  # No-op: resume is now local only


## Close the pause panel locally
func _close_pause_panel() -> void:
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
	if option_sub_panel:
		option_sub_panel.visible = false
	# Show the pause button again when closing pause panel
	if touch_controls:
		touch_controls.set_pause_enabled(true)
	get_tree().paused = false
	print("[ForestHub] Game RESUMED for peer: ", multiplayer.get_unique_id())


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
	# Notify other peer that we're exiting (they should close their pause panel too)
	_request_resume_rpc.rpc()
	
	# Unpause before leaving
	get_tree().paused = false
	
	# Show the pause button again when exiting to main menu
	if touch_controls:
		touch_controls.set_pause_enabled(true)
	
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


# =============================================================================
# LEDGER AND BRIEFCASE PANELS (SIDEKICK ONLY)
# =============================================================================

## Ledger button pressed - toggles the ledger panel (Sidekick only)
func _on_ledger_button_pressed() -> void:
	print("[ForestHub] Ledger button pressed")
	if not _is_sidekick:
		print("[ForestHub] Ledger is only accessible to sidekick")
		return
	
	if _current_open_panel == "ledger":
		# Toggle off - close ledger
		_close_all_panels()
	else:
		# Open ledger with overlay
		_show_panel_with_overlay(ledger_panel, "ledger")


## Briefcase button pressed - toggles the briefcase panel (Sidekick only)
func _on_briefcase_button_pressed() -> void:
	print("[ForestHub] Briefcase button pressed")
	if not _is_sidekick:
		print("[ForestHub] Briefcase is only accessible to sidekick")
		return
	
	if _current_open_panel == "briefcase":
		# Toggle off - close briefcase
		_close_all_panels()
	else:
		# Open briefcase with overlay
		_show_panel_with_overlay(briefcase_panel, "briefcase")


## Close ledger panel - kept for compatibility but not used
func _on_ledger_close_pressed() -> void:
	_close_all_panels()


## Close briefcase panel - kept for compatibility but not used
func _on_briefcase_close_pressed() -> void:
	_close_all_panels()


# =============================================================================
# MAP PANEL (Available to both Host and Sidekick)
# =============================================================================

## Map button pressed - toggles the map panel (Available to both)
func _on_map_button_pressed() -> void:
	print("[ForestHub] ========== MAP BUTTON HANDLER CALLED ==========")
	print("[ForestHub] _current_open_panel = ", _current_open_panel)
	print("[ForestHub] map_panel = ", map_panel)
	
	if _current_open_panel == "map":
		# Toggle off - close map
		print("[ForestHub] Toggling map OFF")
		_close_all_panels()
	else:
		# Open map with overlay
		print("[ForestHub] Toggling map ON")
		_show_panel_with_overlay(map_panel, "map")
		print("[ForestHub] Map panel should be visible now: ", map_panel.visible if map_panel else "N/A")


## Close map panel - kept for compatibility but not used
func _on_map_close_pressed() -> void:
	_close_all_panels()


## Close all panels and reset tracking
func _close_all_panels() -> void:
	_hide_panel_overlay()
	if ledger_panel:
		ledger_panel.visible = false
	if briefcase_panel:
		briefcase_panel.visible = false
	if map_panel:
		map_panel.visible = false
	_current_open_panel = ""
	print("[ForestHub] All panels CLOSED")


## Show a specific panel with an overlay behind it
func _show_panel_with_overlay(panel: Control, panel_name: String) -> void:
	_close_all_panels()
	if panel:
		_create_overlay()
		panel.visible = true
		_current_open_panel = panel_name
		print("[ForestHub] ", panel_name, " panel OPENED")


## Create a full-screen overlay that closes panels when clicked
func _create_overlay() -> void:
	_hide_panel_overlay()
	
	var overlay = ColorRect.new()
	overlay.name = "PanelOverlay"
	overlay.color = Color(0, 0, 0, 0.001)  # Almost transparent
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.z_index = -1  # Behind panels but above game
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to game
	
	# Connect click to close panels
	overlay.gui_input.connect(_on_overlay_clicked)
	
	# Add to the same parent as the panels
	if sidekick_layer:
		sidekick_layer.add_child(overlay)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)


## Hide the overlay
func _hide_panel_overlay() -> void:
	var overlay = get_node_or_null("SidekickLayer/PanelOverlay")
	if overlay:
		overlay.queue_free()


## Handle overlay click
func _on_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[ForestHub] Overlay clicked, closing panels")
		_close_all_panels()


## Handle debug input
func _input(_event: InputEvent) -> void:
	# Handle debug F1 key
	if _event is InputEventKey and _event.pressed and _event.keycode == KEY_F1:
		print("[ForestHub] === DEBUG: Spawned players ===")
		for peer_id in _spawned_players:
			var p = _spawned_players[peer_id]
			print("  Player ", peer_id, ": role=", p.role, " pos=", p.global_position, " visible=", p.visible)
		print("[ForestHub] === Scene children ===")
		for child in get_children():
			if child is CharacterBody2D:
				print("  Node: ", child.name, " role=", child.role, " pos=", child.global_position)


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
	
	# Disconnect Firebase auth signals
	if FirebaseAuth.google_auth_success.is_connected(_on_google_auth_success):
		FirebaseAuth.google_auth_success.disconnect(_on_google_auth_success)
	if FirebaseAuth.google_auth_failed.is_connected(_on_google_auth_failed):
		FirebaseAuth.google_auth_failed.disconnect(_on_google_auth_failed)
	if FirebaseAuth.account_linked_success.is_connected(_on_account_linked):
		FirebaseAuth.account_linked_success.disconnect(_on_account_linked)
	if FirebaseAuth.account_link_failed.is_connected(_on_link_failed):
		FirebaseAuth.account_link_failed.disconnect(_on_link_failed)
	if FirebaseAuth.auth_success.is_connected(_on_anonymous_auth_success):
		FirebaseAuth.auth_success.disconnect(_on_anonymous_auth_success)
	if FirebaseAuth.auth_failed.is_connected(_on_anonymous_auth_failed):
		FirebaseAuth.auth_failed.disconnect(_on_anonymous_auth_failed)
	
	# Disconnect UserManager signals
	if UserManager.user_data_changed.is_connected(_on_user_data_changed):
		UserManager.user_data_changed.disconnect(_on_user_data_changed)
	if UserManager.profile_picture_loaded.is_connected(_on_profile_picture_loaded):
		UserManager.profile_picture_loaded.disconnect(_on_profile_picture_loaded)


func _on_back_pressed() -> void:
	pass # Replace with function body.


## Helper to set process_mode for all buttons in a container
func _set_buttons_process_mode(container: Node, mode: Node.ProcessMode) -> void:
	for child in container.get_children():
		if child is TouchScreenButton or child is Button:
			child.process_mode = mode
		# Recursively set for nested children
		if child.get_child_count() > 0:
			_set_buttons_process_mode(child, mode)


## Setup room code label with retry logic
func _setup_room_code_label() -> void:
	if not room_code_label:
		return
	
	if _is_sidekick:
		# Sidekick - hide room code label
		room_code_label.visible = false
		print("[ForestHub] Room code label hidden for sidekick")
		return
	
	# Host - try to get room code with retry
	var invite_code = NetworkManager.get_invite_code()
	print("[ForestHub] Retrieved invite code from NetworkManager: '", invite_code, "'")
	
	if not invite_code.is_empty():
		room_code_label.text = "Room Code: %s" % invite_code
		room_code_label.visible = true
		print("[ForestHub] Room code displayed for host: ", invite_code)
	else:
		# Try again after a short delay (NetworkManager might still be initializing)
		room_code_label.text = "Room Code: ..."
		room_code_label.visible = true
		await get_tree().create_timer(0.5).timeout
		
		if not is_inside_tree():
			return
			
		invite_code = NetworkManager.get_invite_code()
		print("[ForestHub] Retry invite code: '", invite_code, "'")
		
		if not invite_code.is_empty():
			room_code_label.text = "Room Code: %s" % invite_code
			print("[ForestHub] Room code displayed for host (retry): ", invite_code)
		else:
			room_code_label.text = "Room Code: N/A"
			print("[ForestHub] No room code available - displaying N/A")


# =============================================================================
# USER PROFILE FUNCTIONS
# =============================================================================

func _connect_user_profile_signals() -> void:
	"""Connect authentication related signals."""
	# Connect view user profile button
	if view_user_profile_button and not view_user_profile_button.pressed.is_connected(_on_view_user_profile_pressed):
		view_user_profile_button.pressed.connect(_on_view_user_profile_pressed)
		print("[ForestHub] Connected ViewUserProfile button")
	
	# Connect back from profile button
	if user_profile_back_button and not user_profile_back_button.pressed.is_connected(_on_back_from_profile_pressed):
		user_profile_back_button.pressed.connect(_on_back_from_profile_pressed)
		print("[ForestHub] Connected UserProfile back button")
	
	# Connect auth buttons
	if sign_in_button and not sign_in_button.pressed.is_connected(_on_sign_in_pressed):
		sign_in_button.pressed.connect(_on_sign_in_pressed)
	if guest_button and not guest_button.pressed.is_connected(_on_guest_pressed):
		guest_button.pressed.connect(_on_guest_pressed)
	if link_google_button and not link_google_button.pressed.is_connected(_on_link_google_pressed):
		link_google_button.pressed.connect(_on_link_google_pressed)
	
	# Connect to FirebaseAuth signals
	if not FirebaseAuth.google_auth_success.is_connected(_on_google_auth_success):
		FirebaseAuth.google_auth_success.connect(_on_google_auth_success)
	if not FirebaseAuth.google_auth_failed.is_connected(_on_google_auth_failed):
		FirebaseAuth.google_auth_failed.connect(_on_google_auth_failed)
	if not FirebaseAuth.account_linked_success.is_connected(_on_account_linked):
		FirebaseAuth.account_linked_success.connect(_on_account_linked)
	if not FirebaseAuth.account_link_failed.is_connected(_on_link_failed):
		FirebaseAuth.account_link_failed.connect(_on_link_failed)
	# Connect anonymous auth signals
	if not FirebaseAuth.auth_success.is_connected(_on_anonymous_auth_success):
		FirebaseAuth.auth_success.connect(_on_anonymous_auth_success)
	if not FirebaseAuth.auth_failed.is_connected(_on_anonymous_auth_failed):
		FirebaseAuth.auth_failed.connect(_on_anonymous_auth_failed)
	
	# Connect to UserManager signals
	if not UserManager.user_data_changed.is_connected(_on_user_data_changed):
		UserManager.user_data_changed.connect(_on_user_data_changed)
	if not UserManager.profile_picture_loaded.is_connected(_on_profile_picture_loaded):
		UserManager.profile_picture_loaded.connect(_on_profile_picture_loaded)


func _update_user_ui() -> void:
	"""Update the user profile UI based on current auth state."""
	var user_data = UserManager.get_user_data()
	
	# Update display name
	if display_name_label:
		display_name_label.text = user_data.display_name if not user_data.display_name.is_empty() else "Guest"
	
	# Update provider label and button visibility
	if provider_label:
		match user_data.provider:
			"google":
				provider_label.text = "Google Account"
				if link_google_button:
					link_google_button.visible = false
				if sign_in_button:
					sign_in_button.visible = false
				if guest_button:
					guest_button.visible = false
			"anonymous":
				provider_label.text = "Guest"
				if link_google_button:
					link_google_button.visible = true
				if sign_in_button:
					sign_in_button.visible = true
				if guest_button:
					guest_button.visible = true
	
	# Update avatar
	if avatar_texture:
		var cached = UserManager.get_cached_profile_texture()
		if cached:
			avatar_texture.texture = cached
		elif not user_data.photo_url.is_empty():
			UserManager.load_profile_picture(user_data.photo_url)
		else:
			avatar_texture.texture = preload("res://assets/sprites/userIcon.png")


func _on_view_user_profile_pressed() -> void:
	print("[ForestHub] Opening user profile panel")
	if user_profile_panel:
		user_profile_panel.visible = true
	if view_user_profile_button:
		view_user_profile_button.visible = false


func _on_back_from_profile_pressed() -> void:
	print("[ForestHub] Closing user profile panel")
	if user_profile_panel:
		user_profile_panel.visible = false
	if view_user_profile_button:
		view_user_profile_button.visible = true


func _on_sign_in_pressed() -> void:
	print("[ForestHub] Sign in button pressed")
	FirebaseAuth.sign_in_with_google()


func _on_guest_pressed() -> void:
	print("[ForestHub] Guest button pressed - starting anonymous login")
	# Call Firebase anonymous login
	FirebaseAuth.anonymous_login()


func _on_link_google_pressed() -> void:
	print("[ForestHub] Link Google button pressed")
	if not FirebaseAuth.is_authenticated:
		return
	
	# Store current anonymous UID before linking
	UserManager.update_user_data({"anonymous_uid": FirebaseAuth.current_user_id})
	
	# Start Google sign-in flow for linking
	FirebaseAuth.link_with_google()


func _on_google_auth_success(user_data: Dictionary) -> void:
	print("[ForestHub] Google sign-in success")
	
	# Update UserManager
	UserManager.update_user_data(user_data)
	
	# Save to Firestore
	FirebaseFirestore.save_user_profile(user_data.user_id, user_data)
	
	# Load profile picture if available
	if not user_data.photo_url.is_empty():
		UserManager.load_profile_picture(user_data.photo_url)
	
	# Update UI
	_update_user_ui()


func _on_google_auth_failed(error: String) -> void:
	print("[ForestHub] Google sign-in failed: ", error)


func _on_account_linked(user_data: Dictionary) -> void:
	print("[ForestHub] Account linked successfully")
	
	# Update with linked status
	user_data["is_linked"] = true
	UserManager.update_user_data(user_data)
	
	# Save to Firestore
	FirebaseFirestore.save_user_profile(user_data.user_id, user_data)
	
	# Update UI
	_update_user_ui()


func _on_link_failed(error: String) -> void:
	print("[ForestHub] Account link failed: ", error)


func _on_user_data_changed(_data: Dictionary) -> void:
	_update_user_ui()


func _on_profile_picture_loaded(texture: Texture2D) -> void:
	if texture and avatar_texture:
		avatar_texture.texture = texture


func _on_anonymous_auth_success(user_id: String, token: String) -> void:
	print("[ForestHub] Anonymous auth success: ", user_id)
	# Update UserManager with guest data
	var user_data = {
		"user_id": user_id,
		"display_name": "Guest",
		"email": "",
		"photo_url": "",
		"provider": "anonymous",
		"is_linked": false
	}
	UserManager.update_user_data(user_data)
	_update_user_ui()


func _on_anonymous_auth_failed(error: String) -> void:
	print("[ForestHub] Anonymous auth failed: ", error)
