# scripts/climax/BakunawaNightfall.gd
extends Node2D

# Game references
@onready var ground = $Ground
@onready var player_container = $PlayerContainer
@onready var nuno_container = $NunoContainer
@onready var obstacle_spawner = $ObstacleSpawner
@onready var speed_controller = $SpeedController

# Role-specific views
@onready var detective_view = $DetectiveView  # Normal visibility
@onready var sidekick_view = $SidekickView    # Black screen with audio UI
@onready var fog_overlay = $FogOverlay        # For detective's "Third Eye" effect

# UI Elements
@onready var distance_label = $UI/DistanceLabel
@onready var danger_meter = $UI/DangerMeter
@onready var audio_cue_indicator = $UI/AudioCueIndicator

# Game constants
const BASE_SPEED: float = 200.0          # Starting scroll speed
const MAX_SPEED: float = 600.0           # Maximum speed
const SPAWN_DISTANCE: float = 800.0      # How far ahead to spawn obstacles
const DESPAWN_DISTANCE: float = -100.0   # When to remove obstacles
const GOAL_DISTANCE: float = 5000.0      # Distance to reach Altar

# Game state
var current_speed: float = BASE_SPEED
var distance_traveled: float = 0.0
var game_active: bool = false
var nuno_list: Array = []
var obstacle_list: Array = []
var player_node: CharacterBody2D = null

# Pacing control - players tap/hold to speed up, release to slow down
var is_sprinting: bool = false
var sprint_multiplier: float = 1.0

func _ready():
	_setup_role_specific_view()
	_spawn_player()
	_start_game()

func _setup_role_specific_view():
	if GameState.local_role == GameState.Role.DETECTIVE:
		# Detective sees the world with "Third Eye" - glowing path, visible Nuno
		detective_view.show()
		sidekick_view.hide()
		fog_overlay.modulate = Color(1, 1, 1, 0.3)  # Slight fog, but visible
		
		# Add glowing effect to Nuno sa Punso (they glow red)
		_apply_third_eye_vision()
	else:
		# Sidekick sees ONLY black screen
		detective_view.hide()
		sidekick_view.show()
		fog_overlay.modulate = Color(0, 0, 0, 1)  # Total blackout
		
		# Setup audio-based navigation UI
		_setup_audio_navigation()

func _apply_third_eye_vision():
	# Make Nuno sa Punso glow for detective
	for nuno in nuno_container.get_children():
		nuno.modulate = Color(1, 0.2, 0.2)  # Red glow
		nuno.energy = 2.0  # Glow effect
	
	# Path glows slightly
	ground.modulate = Color(0.8, 0.9, 1.0)

func _setup_audio_navigation():
	# Sidekick gets stereo audio cues
	# Left/Right audio based on obstacle position
	# Pitch increases as obstacles get closer
	pass

func _spawn_player():
	# Spawn the appropriate player character
	if GameState.local_role == GameState.Role.DETECTIVE:
		player_node = preload("res://scenes/players/PlayerHost.tscn").instantiate()
	else:
		player_node = preload("res://scenes/players/PlayerSidekick.tscn").instantiate()
	
	player_node.position = Vector2(100, 300)  # Ground level
	player_container.add_child(player_node)
	
	# Connect input for speed control
	player_node.sprint_started.connect(_on_sprint_started)
	player_node.sprint_ended.connect(_on_sprint_ended)
	player_node.jump_pressed.connect(_on_player_jump)

func _start_game():
	game_active = true
	_start_spawning()
	AudioManager.play_music("bakunawa_chase")

func _physics_process(delta):
	if not game_active:
		return
	
	_update_game_speed(delta)
	_move_world(delta)
	_check_collisions()
	_update_ui()
	_check_win_condition()

func _update_game_speed(delta):
	# Speed is controlled by player input (sprinting)
	if is_sprinting:
		sprint_multiplier = lerp(sprint_multiplier, 2.0, delta * 2)
	else:
		sprint_multiplier = lerp(sprint_multiplier, 1.0, delta * 2)
	
	# Nuno speed is LINKED to player speed - if you run fast, they chase fast
	current_speed = BASE_SPEED * sprint_multiplier
	
	# Clamp speed
	current_speed = clamp(current_speed, BASE_SPEED * 0.5, MAX_SPEED)

func _move_world(delta):
	# Move ground and obstacles left (side-scrolling effect)
	var move_amount = current_speed * delta
	
	# Scroll ground texture
	ground.scroll_base_offset.x -= move_amount * 0.1
	
	# Move obstacles
	for obstacle in obstacle_list:
		obstacle.position.x -= move_amount
		
		# Remove if off-screen
		if obstacle.position.x < DESPAWN_DISTANCE:
			_remove_obstacle(obstacle)
	
	# Move Nuno sa Punso (they chase from behind AND spawn ahead)
	for nuno in nuno_list:
		# Nuno moves at same speed as world + slight chase speed
		var nuno_speed = current_speed + (50 if nuno.is_chasing else 0)
		nuno.position.x -= nuno_speed * delta
		
		# If Nuno catches up to player from behind = game over
		if nuno.position.x < player_node.position.x - 50:
			_trigger_nuno_catch(nuno)
	
	distance_traveled += move_amount / 10  # Scale to meaningful number

func _start_spawning():
	# Spawn obstacles and Nuno at intervals
	var spawn_timer = Timer.new()
	spawn_timer.wait_time = 2.0 / sprint_multiplier  # Faster spawn when sprinting
	spawn_timer.timeout.connect(_spawn_obstacle_pattern)
	add_child(spawn_timer)
	spawn_timer.start()

func _spawn_obstacle_pattern():
	if not game_active:
		return
	
	# Spawn pattern based on difficulty/progression
	var pattern = randi() % 3
	
	match pattern:
		0: _spawn_single_nuno()
		1: _spawn_nuno_jump_pattern()
		2: _spawn_ground_nuno()
	
	# Respawn timer with variable timing based on speed
	var next_spawn = randf_range(1.5, 3.0) / (sprint_multiplier * 0.8)
	$SpawnTimer.start(next_spawn)

func _spawn_single_nuno():
	# add nuno sprite here
	var nuno = preload("res://scenes/characters/NunoSaPunso.tscn").instantiate()
	nuno.position = Vector2(SPAWN_DISTANCE, 320)  # Ground level
	nuno.scale = Vector2(0.5, 0.5)  # Small mound
	
	# Nuno properties
	nuno.is_obstacle = true
	nuno.player_touched.connect(_on_nuno_touched)
	
	nuno_container.add_child(nuno)
	nuno_list.append(nuno)
	
	# Visual setup based on role
	if GameState.local_role == GameState.Role.DETECTIVE:
		nuno.modulate = Color(1, 0.3, 0.3)  # Visible red glow
	else:
		nuno.visible = false  # Sidekick can't see it at all

func _spawn_nuno_jump_pattern():
	# Spawn multiple Nuno that require jumping over
	for i in range(3):
		# add nuno sprite here
		var nuno = preload("res://scenes/characters/NunoSaPunso.tscn").instantiate()
		nuno.position = Vector2(SPAWN_DISTANCE + (i * 150), 320)
		nuno.scale = Vector2(0.6, 0.6)
		nuno.player_touched.connect(_on_nuno_touched)
		
		nuno_container.add_child(nuno)
		nuno_list.append(nuno)

func _spawn_ground_nuno():
	# Nuno that appears as a "safe spot" but is actually dangerous
	# Only detective can see the true nature
	# add nuno sprite here
	var nuno = preload("res://scenes/characters/NunoSaPunso.tscn").instantiate()
	nuno.position = Vector2(SPAWN_DISTANCE, 320)
	nuno.disguised = true  # Looks like a rock to sidekick (if they could see)
	nuno.player_touched.connect(_on_nuno_touched)
	
	nuno_container.add_child(nuno)
	nuno_list.append(nuno)

func _on_sprint_started():
	is_sprinting = true
	# Visual feedback - player runs faster animation
	player_node.speed_up()

func _on_sprint_ended():
	is_sprinting = false
	player_node.slow_down()

func _on_player_jump():
	# Jump over obstacles
	player_node.velocity.y = -400

func _check_collisions():
	# Check if player touches any Nuno
	for nuno in nuno_list:
		if player_node.global_position.distance_to(nuno.global_position) < 30:
			_on_nuno_touched(nuno)

func _on_nuno_touched(nuno):
	# INSTANT DEATH - Nuno sa Punso catches you
	game_active = false
	
	# Visual effect - Nuno eyes glow
	_show_nuno_eyes_effect(nuno)
	
	# Audio - curse sound
	AudioManager.play_sfx("nuno_curse")
	
	# Wait for effect
	await get_tree().create_timer(1.5).timeout
	
	# PUNISHMENT: Reset everything
	_execute_game_reset()

func _show_nuno_eyes_effect(nuno):
	# head appear in the dark
	var head = Sprite2D.new()
	# add nuno head sprite here
	head.texture = preload("res://assets/sprites/nuno_head.png")
	head.position = nuno.position
	head.modulate = Color(1, 0, 0, 0)
	add_child(head)
	
	var tween = create_tween()
	tween.tween_property(head, "modulate", Color(1, 0, 0, 1), 0.3)
	tween.tween_property(head, "modulate", Color(1, 0, 0, 0), 0.3)
	tween.set_loops(3)

func _execute_game_reset():
	print("💀 Nuno sa Punso caught you! Resetting game...")
	
	# 1. Lose ALL clues
	GameState.reset_game_after_nightfall()
	
	# 2. Show failure screen
	_show_failure_screen()
	
	await get_tree().create_timer(3.0).timeout
	
	# 3. Return to Forest Hub (starting point)
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")

func _show_failure_screen():
	var fail_screen = $FailureScreen
	fail_screen.text = """
	Nuno sa Punso has caught you!
	
	All clues have been lost...
	The story fades back into darkness.
	
	Returning to the Forest...
	"""
	fail_screen.show()
	
	# Fade in red
	var tween = create_tween()
	tween.tween_property(fail_screen, "modulate", Color(1, 0, 0, 1), 0.5)

func _update_ui():
	# Show distance to goal
	var remaining = GOAL_DISTANCE - distance_traveled
	distance_label.text = "Distance to Altar: %dm" % int(remaining / 10)
	
	# Danger meter shows how close Nuno are behind
	var nearest_nuno_dist = INF
	for nuno in nuno_list:
		if nuno.position.x < player_node.position.x:
			var dist = player_node.position.x - nuno.position.x
			if dist < nearest_nuno_dist:
				nearest_nuno_dist = dist
	
	if nearest_nuno_dist < INF:
		var danger = 1.0 - clamp(nearest_nuno_dist / 200.0, 0.0, 1.0)
		danger_meter.value = danger * 100

func _check_win_condition():
	if distance_traveled >= GOAL_DISTANCE:
		_reach_altar()

func _reach_altar():
	game_active = false
	AudioManager.play_sfx("success_jingle")
	
	# Victory transition
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 2.0)
	await tween.finished
	
	# Go to final deduction scene
	get_tree().change_scene_to_file("res://scenes/world/climax/AltarDeduction.tscn")
