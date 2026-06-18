##game.gd 
extends Node2D

@export var player_scene: PackedScene

var spawn_index := 0


func _ready():
	# Connect to NetworkManager's player connection signal
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# If we're already in a game, spawn existing players
	if NetworkManager.is_playing():
		_spawn_local_player()


func _on_player_connected(peer_id: int):
	print("[Game] Player connected: ", peer_id)
	# Only server spawns players
	if multiplayer.is_server():
		_spawn_player_for_peer(peer_id)


func _on_player_disconnected(peer_id: int):
	print("[Game] Player disconnected: ", peer_id)
	# Remove player's character
	var player_node = get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()


func _spawn_local_player():
	# Spawn the local player
	var peer_id = multiplayer.get_unique_id()
	if multiplayer.is_server():
		_spawn_player_for_peer(peer_id)


func _spawn_player_for_peer(peer_id: int):
	if not player_scene:
		return
	
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	
	# Get spawn point
	var spawn_point = $SpawnPoints.get_child(spawn_index % $SpawnPoints.get_child_count())
	player.global_position = spawn_point.global_position
	
	# Assign role based on who is host
	if peer_id == 1:  # Host is always ID 1
		player.role = "Detective"
	else:
		player.role = "Sidekick"
	
	spawn_index += 1
	add_child(player, true)
	
	print("[Game] Spawned player ", peer_id, " as ", player.role)


func spawn_players():
	# Legacy function - kept for compatibility
	_spawn_local_player()
