extends Node2D

## Forest Hub - Main world scene with zone portals and player spawning

# Preload both player scenes
@onready var player_host_scene: PackedScene = preload("res://scenes/players/PlayerHost.tscn")
@onready var player_sidekick_scene: PackedScene = preload("res://scenes/players/PlayerSidekick.tscn")

# Scale configuration for Forest Hub (different from lobby's 0.7)
@export var detective_scale: Vector2 = Vector2(0.3, 0.3)
@export var sidekick_scale: Vector2 = Vector2(0.3, 0.3)

# Ground Y position - adjust this in inspector to match your terrain
@export var ground_y: float = 750.0

@onready var spawn_points: Node2D = $SpawnPoints

# Track spawned players
var _spawned_players: Dictionary = {}


func _ready():
	print("[ForestHub] Initializing...")
	
	# Connect to network signals
	if not NetworkManager.player_connected.is_connected(_on_player_connected):
		NetworkManager.player_connected.connect(_on_player_connected)
	if not NetworkManager.player_disconnected.is_connected(_on_player_disconnected):
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# Spawn local player
	_spawn_local_player()
	
	# Server tells all clients about existing players
	if multiplayer.is_server():
		# Wait a frame to ensure local player is spawned
		await get_tree().process_frame
		for peer_id in multiplayer.get_peers():
			if peer_id != multiplayer.get_unique_id():
				# Tell the new peer to spawn the host (ID 1)
				_rpc_spawn_player.rpc_id(peer_id, 1, true)


func _spawn_local_player():
	var peer_id: int = multiplayer.get_unique_id()
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
	
	if is_detective:
		player = player_host_scene.instantiate()
		spawn_marker = spawn_points.get_node("DetectiveSpawn")
		player.role = "Detective"
		player.avatar_scale = detective_scale
		print("[ForestHub] Spawning Detective (ID: ", peer_id, ")")
	else:
		player = player_sidekick_scene.instantiate()
		spawn_marker = spawn_points.get_node("SidekickSpawn")
		player.role = "Sidekick"
		player.avatar_scale = sidekick_scale
		print("[ForestHub] Spawning Sidekick (ID: ", peer_id, ")")
	
	player.name = str(peer_id)
	
	# Get spawn position - use as final position
	if spawn_marker:
		spawn_pos = spawn_marker.global_position
	else:
		spawn_pos = Vector2(400 if is_detective else 200, ground_y)
	
	# Position player at spawn point (final position, no falling)
	player.global_position = spawn_pos
	
	# Set multiplayer authority
	player.set_multiplayer_authority(peer_id)
	
	# Track and add to scene
	_spawned_players[peer_id] = player
	add_child(player, true)
	
	# Use call_deferred to ensure physics is ready before snapping to ground
	call_deferred("_snap_player_to_ground", player)
	
	print("[ForestHub] Spawned ", player.role, " at position ", player.global_position)


@rpc("authority", "reliable")
func _rpc_spawn_player(peer_id: int, is_detective_role: bool) -> void:
	# Client receives this from server to spawn a remote player
	if _spawned_players.has(peer_id):
		return
	
	if peer_id == multiplayer.get_unique_id():
		# Don't spawn ourselves via RPC
		return
	
	var player: CharacterBody2D
	var spawn_marker: Marker2D
	
	if is_detective_role:
		player = player_host_scene.instantiate()
		spawn_marker = spawn_points.get_node("DetectiveSpawn")
		player.role = "Detective"
		player.avatar_scale = detective_scale
	else:
		player = player_sidekick_scene.instantiate()
		spawn_marker = spawn_points.get_node("SidekickSpawn")
		player.role = "Sidekick"
		player.avatar_scale = sidekick_scale
	
	player.name = str(peer_id)
	
	if spawn_marker:
		player.global_position = spawn_marker.global_position
	else:
		player.global_position = Vector2(400 if is_detective_role else 200, ground_y)
	
	player.set_multiplayer_authority(peer_id)
	_spawned_players[peer_id] = player
	add_child(player, true)
	
	# Snap to ground after physics is ready
	call_deferred("_snap_player_to_ground", player)
	
	print("[ForestHub] RPC Spawned ", player.role, " (ID: ", peer_id, ") at ", player.global_position)


func _on_player_connected(peer_id: int) -> void:
	print("[ForestHub] Player connected: ", peer_id)
	# Server tells all clients to spawn this player
	if multiplayer.is_server():
		var is_detective = (peer_id == 1)
		
		# Server (host) spawns the new player locally FIRST
		if not _spawned_players.has(peer_id):
			_spawn_player_for_peer(peer_id)
		
		# Tell all other peers (except the new one and server) to spawn this player
		for other_peer in multiplayer.get_peers():
			if other_peer != peer_id and other_peer != multiplayer.get_unique_id():
				_rpc_spawn_player.rpc_id(other_peer, peer_id, is_detective)
		
		# Tell the new peer to spawn existing players (the host)
		_rpc_spawn_player.rpc_id(peer_id, 1, true)


func _on_player_disconnected(peer_id: int) -> void:
	print("[ForestHub] Player disconnected: ", peer_id)
	
	# Remove the player's character
	var player_node: Node = get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
	
	_spawned_players.erase(peer_id)
	
	# Tell all clients to remove this player
	if multiplayer.is_server():
		_rpc_despawn_player.rpc(peer_id)


@rpc("authority", "reliable")
func _rpc_despawn_player(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	var player_node: Node = get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
	_spawned_players.erase(peer_id)


func _snap_player_to_ground(player: CharacterBody2D) -> void:
	# Player stays at spawn point position - no falling
	# Just ensure physics is stable
	player.velocity = Vector2.ZERO
	player.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	
	# Wait one frame for physics to initialize
	await get_tree().physics_frame
	
	print("[ForestHub] Player ", player.role, " positioned at spawn point: ", player.global_position)


func _exit_tree():
	if NetworkManager.player_connected.is_connected(_on_player_connected):
		NetworkManager.player_connected.disconnect(_on_player_connected)
	if NetworkManager.player_disconnected.is_connected(_on_player_disconnected):
		NetworkManager.player_disconnected.disconnect(_on_player_disconnected)
