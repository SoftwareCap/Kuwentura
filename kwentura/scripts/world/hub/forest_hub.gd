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
@onready var in_game_settings_panel: Panel = $InGameSettingsPanel
@onready var volume_slider: HSlider = $InGameSettingsPanel/HBoxContainer/VolumeSlider
@onready var volume_value_label: Label = $InGameSettingsPanel/HBoxContainer/VolumeValue

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
	
	# Connect to spawn signals from NetworkManager (RPCs now handled there)
	if not NetworkManager.spawn_player_requested.is_connected(_on_spawn_player_requested):
		NetworkManager.spawn_player_requested.connect(_on_spawn_player_requested)
	if not NetworkManager.despawn_player_requested.is_connected(_on_despawn_player_requested):
		NetworkManager.despawn_player_requested.connect(_on_despawn_player_requested)
	
	# Connect touch controls settings button
	if touch_controls:
		# Check if touch_controls has the signal (it should emit settings_pressed)
		if touch_controls.has_signal("settings_pressed"):
			if not touch_controls.settings_pressed.is_connected(_on_settings_button_pressed):
				touch_controls.settings_pressed.connect(_on_settings_button_pressed)
		# Also check for the settings button directly
		var settings_btn = touch_controls.get_node_or_null("Settings")
		if settings_btn and settings_btn is TouchScreenButton:
			if not settings_btn.is_connected("pressed", _on_settings_button_pressed):
				settings_btn.pressed.connect(_on_settings_button_pressed)
	
	# Initialize settings panel
	if in_game_settings_panel:
		in_game_settings_panel.visible = false
		# Set initial volume slider value
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"
	
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


func _on_settings_button_pressed() -> void:
	print("[ForestHub] Settings button pressed")
	if in_game_settings_panel:
		in_game_settings_panel.visible = true
		# Update slider to current volume
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"
		print("[ForestHub] In-game settings panel opened")


func _on_in_game_settings_back_pressed() -> void:
	print("[ForestHub] Closing in-game settings panel")
	if in_game_settings_panel:
		in_game_settings_panel.visible = false
		_save_settings()


func _on_in_game_volume_changed(value: float) -> void:
	var volume = value / 100.0
	MusicController.set_volume(volume)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"
	print("[ForestHub] Volume changed to: ", volume)


func _save_settings() -> void:
	const SETTINGS_FILE = "user://settings.json"
	var data = {
		"volume": MusicController.get_volume()
	}
	
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("[ForestHub] Settings saved successfully")


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
	
	# Get spawn position
	if spawn_marker:
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
	
	var player_node: Node = get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
	
	_spawned_players.erase(peer_id)
	
	# Tell all clients to remove this player
	if multiplayer.is_server():
		NetworkManager.request_despawn_player(peer_id)


## Spawn player via NetworkManager signal (not direct RPC)
func _rpc_spawn_player(peer_id: int, is_detective_role: bool) -> void:
	print("[ForestHub] === RPC SPAWN peer_id=", peer_id, " is_detective=", is_detective_role, " my_id=", multiplayer.get_unique_id())
	
	if _spawned_players.has(peer_id):
		print("[ForestHub] Player ", peer_id, " already exists, skipping")
		return
	
	if peer_id == multiplayer.get_unique_id():
		print("[ForestHub] Not spawning self")
		return
	
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
	
	if spawn_marker:
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
