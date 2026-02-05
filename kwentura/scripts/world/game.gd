extends Node2D

@export var player_scene: PackedScene

var spawn_index := 0

func _ready():
	NetworkManager.player_connected.connect(_spawn_player)

func _spawn_player(peer_id):
	if not multiplayer.is_server():
		return

	var player = player_scene.instantiate()
	player.name = str(peer_id)

	var spawn_point = $SpawnPoints.get_child(spawn_index)
	player.global_position = spawn_point.global_position

	if spawn_index == 0:
		player.role = "Detective"
	else:
		player.role = "Sidekick"

	spawn_index += 1
	add_child(player, true)

func spawn_players():
	var host = preload("res://scenes/players/PlayerHost.tscn").instantiate()
	host.is_host = true
	add_child(host)
