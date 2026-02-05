extends Node2D

@onready var detective_view = $DetectiveView  # Can see glowing path and Nuno
@onready var sidekick_view = $SidekickView    # Black screen, relies on audio
@onready var nuno_spawners = $NunoSpawners
@onready var path_waypoints = $PathWaypoints
@onready var players_container = $Players

const NUNO_SPEED_BASE: float = 50.0
const NUNO_SPEED_INCREMENT: float = 20.0

var nuno_instances: Array = []
var player_nodes: Dictionary = {}  # peer_id -> player_node
var game_active: bool = true
var nuno_speed: float = NUNO_SPEED_BASE

func _ready():
	_setup_role_specific_views()
	_spawn_nunos()
	_start_nuno_movement()
	
	# Connect player inputs
	if GameState.local_role == GameState.Role.DETECTIVE:
		_setup_detective_controls()
	else:
		_setup_sidekick_controls()

func _setup_role_specific_views():
	if GameState.local_role == GameState.Role.DETECTIVE:
		detective_view.show()
		sidekick_view.hide()
		# Detective sees glowing path and Nuno sa Punso (mound spirits)
		_draw_glowing_path()
		_highlight_nunos()
	else:
		detective_view.hide()
		sidekick_view.show()
		# Sidekick sees black screen with audio cues only
		_setup_audio_navigation()

func _draw_glowing_path():
	# Visual glowing path for detective to guide sidekick
	var path_line = $DetectiveView/PathLine
	path_line.points = path_waypoints.get_children().map(func(node): return node.position)

func _highlight_nunos():
	# Make Nuno sa Punso visible to detective (glowing red mounds)
	for spawner in nuno_spawners.get_children():
		var nuno = spawner.instantiate_nuno()
		nuno.modulate = Color(1, 0.2, 0.2, 0.8)  # Glowing red
		nuno_instances.append(nuno)

func _setup_audio_navigation():
	# Sidekick relies on stereo audio cues from detective
	AudioManager.play_ambient("wind_howling")
	# Detective's voice/commands would come through network voice or text

func _spawn_nunos():
	# Spawn Nuno sa Punso at random positions along potential paths
	var spawn_points = nuno_spawners.get_children()
	for point in spawn_points:
		var nuno = preload("res://scenes/characters/NunoSaPunso.tscn").instantiate()
		nuno.position = point.position
		nuno.player_touched.connect(_on_nuno_touched)
		add_child(nuno)
		nuno_instances.append(nuno)

func _start_nuno_movement():
	# Nunos move towards players at increasing speed
	var tween = create_tween()
	tween.set_loops()
	tween.tween_callback(_move_nunos)
	tween.tween_interval(0.5)  # Update every 0.5 seconds

func _move_nunos():
	if not game_active:
		return
	
	# Increase speed over time (players control pacing by moving)
	nuno_speed += NUNO_SPEED_INCREMENT * 0.01
	
	for nuno in nuno_instances:
		# Move towards nearest player
		var nearest_player = _get_nearest_player(nuno.position)
		if nearest_player:
			var direction = (nearest_player.position - nuno.position).normalized()
			nuno.position += direction * nuno_speed * 0.5

func _get_nearest_player(nuno_pos: Vector2) -> Node2D:
	var nearest = null
	var min_dist = INF
	
	for player in players_container.get_children():
		var dist = nuno_pos.distance_to(player.position)
		if dist < min_dist:
			min_dist = dist
			nearest = player
	
	return nearest

func _on_nuno_touched(player_node):
	if not game_active:
		return
	
	# Nuno catches player!
	game_active = false
	AudioManager.play_sfx("nuno_curse")
	
	# Visual effect - eyes glowing in dark
	_show_nuno_eyes()
	
	await get_tree().create_timer(2.0).timeout
	
	# Penalty: Lose all clues, reset to forest
	GameState.reset_game_after_nightfall()
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")

func _show_nuno_eyes():
	var eyes = $NunoEyes
	eyes.show()
	var tween = create_tween()
	tween.tween_property(eyes, "modulate", Color(1, 0, 0, 1), 0.5)
	tween.tween_property(eyes, "modulate", Color(1, 0, 0, 0), 0.5)
	tween.set_loops(3)

func _setup_detective_controls():
	# Detective uses touch/click to guide sidekick
	# Can place waypoints or send audio cues
	pass

func _setup_sidekick_controls():
	# Sidekick moves blindly based on detective's guidance
	# Simple left/right/jump controls with haptic feedback
	pass

func _on_reached_altar():
	game_active = false
	get_tree().change_scene_to_file("res://scenes/world/climax/AltarDeduction.tscn")
