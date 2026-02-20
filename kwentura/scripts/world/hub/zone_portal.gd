extends Node

@export var zone_name : String
var is_player_on_door : bool
var is_sidekick_on_door: bool
@export var scene_path : String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("body_entered", detect_player)
	connect("body_exited", detect_player_out)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_jump"):
		change_scene()

func detect_player(body: Node2D):
	if body is Player:
		is_player_on_door = true
	elif body is Sidekick:
		is_sidekick_on_door = true

func detect_player_out(body: Node2D):
	if body is Player:
		is_player_on_door = false
	else:
		is_sidekick_on_door = false
		
func change_scene():
	# do something for animation
	
	if is_player_on_door and is_sidekick_on_door:
		print("changing scene")
		get_tree().change_scene_to_file(scene_path)
	else:
		print("bawal")
