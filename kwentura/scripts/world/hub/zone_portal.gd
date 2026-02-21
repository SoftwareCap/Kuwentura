extends Area2D

@export var zone_name : String
@export var scene_path : String
var is_player_on_door : bool = false
var is_sidekick_on_door: bool = false

# Track which bodies are on the portal
var player_body: Node2D = null
var sidekick_body: Node2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("body_entered", detect_player)
	connect("body_exited", detect_player_out)
	print("[ZonePortal] Ready: ", zone_name, " at ", global_position)

func detect_player(body: Node2D):
	print("[ZonePortal] Body entered: ", body.name, " (", body.get_class(), ")")
	
	# Detective is peer 1, Sidekick is the other peer
	var body_peer_id = int(body.name) if body.name.is_valid_int() else 0
	
	if body_peer_id == 1:
		is_player_on_door = true
		player_body = body
		print("[ZonePortal] ", zone_name, " - Player (Detective) entered")
	elif body_peer_id > 1:
		is_sidekick_on_door = true
		sidekick_body = body
		print("[ZonePortal] ", zone_name, " - Sidekick entered")
	
	print("[ZonePortal] Status - Player: ", is_player_on_door, ", Sidekick: ", is_sidekick_on_door)

func detect_player_out(body: Node2D):
	print("[ZonePortal] Body exited: ", body.name)
	
	var body_peer_id = int(body.name) if body.name.is_valid_int() else 0
	
	if body_peer_id == 1:
		is_player_on_door = false
		player_body = null
		print("[ZonePortal] ", zone_name, " - Player (Detective) exited")
	elif body_peer_id > 1:
		is_sidekick_on_door = false
		sidekick_body = null
		print("[ZonePortal] ", zone_name, " - Sidekick exited")
	
	print("[ZonePortal] Status - Player: ", is_player_on_door, ", Sidekick: ", is_sidekick_on_door)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_jump"):
		print("[ZonePortal] Jump pressed on ", zone_name, " - Player: ", is_player_on_door, ", Sidekick: ", is_sidekick_on_door)
		change_scene()

func change_scene():
	if is_player_on_door and is_sidekick_on_door:
		print("[ZonePortal] Both players detected! Changing to: ", scene_path)
		
		# Save positions and sync before changing scene
		_save_and_sync_positions()
		
		get_tree().change_scene_to_file(scene_path)
	else:
		print("[ZonePortal] bawal - Need both players. Player: ", is_player_on_door, ", Sidekick: ", is_sidekick_on_door)


func _save_and_sync_positions():
	"""Save all player positions and sync between clients."""
	var local_peer_id = multiplayer.get_unique_id()
	
	print("[ZonePortal] Saving positions - local peer: ", local_peer_id)
	
	# Host (Detective) collects and broadcasts positions
	if multiplayer.is_server():
		# Get detective position
		if player_body:
			GameState.save_spawn_position(1, player_body.global_position, "forest_hub")
			GameState._broadcast_position_rpc.rpc(1, player_body.global_position)
			print("[ZonePortal] Host saved detective position: ", player_body.global_position)
		
		# Get sidekick position if available locally
		if sidekick_body:
			var sidekick_id = int(sidekick_body.name)
			GameState.save_spawn_position(sidekick_id, sidekick_body.global_position, "forest_hub")
			GameState._broadcast_position_rpc.rpc(sidekick_id, sidekick_body.global_position)
			print("[ZonePortal] Host saved sidekick position: ", sidekick_body.global_position)
	else:
		# Client reports their position to host
		if sidekick_body and local_peer_id != 1:
			GameState._report_position_to_host_rpc.rpc_id(1, local_peer_id, sidekick_body.global_position)
			GameState.save_spawn_position(local_peer_id, sidekick_body.global_position, "forest_hub")
			print("[ZonePortal] Client reported position: ", sidekick_body.global_position)
