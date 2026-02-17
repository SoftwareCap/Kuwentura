extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D

@export var speed = 350
@export var jump_force = -700
@export var role: String = "Sidekick"
@export var avatar_scale: Vector2 = Vector2(1.0, 1.0)
var is_host = false

var _is_in_lobby = false


func _ready():
	# Check if we're in a lobby (Control parent) or gameplay (Node2D parent)
	_is_in_lobby = get_parent() is Control
	
	# Only apply avatar_scale if we're in a gameplay scene
	if not _is_in_lobby:
		scale = avatar_scale
		# Configure floor detection for better stability
		floor_snap_length = 32.0
		floor_max_angle = deg_to_rad(60.0)
		floor_block_on_wall = true
		floor_stop_on_slope = true
		motion_mode = MOTION_MODE_GROUNDED


func _process(_delta):
	# In lobby, just update animation, no physics
	if _is_in_lobby:
		if velocity.x == 0:
			sprite.play("idle")
		else:
			sprite.play("walk")
			sprite.flip_h = velocity.x < 0


func _try_jump():
	if is_on_floor():
		velocity.y = jump_force


func _physics_process(delta):
	# Skip physics in lobby
	if _is_in_lobby:
		return

	# Get movement input from TouchScreenButtons or keyboard
	var direction := Input.get_axis("game_left", "game_right")
	velocity.x = direction * speed

	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		# On floor - keep Y velocity at 0 to prevent sliding
		if velocity.y > 0:
			velocity.y = 0

	# Handle jump input
	if Input.is_action_just_pressed("game_jump"):
		_try_jump()

	# Move and slide
	move_and_slide()

	# Animation
	if velocity.x == 0:
		sprite.play("idle")
	else:
		sprite.play("walk")
		sprite.flip_h = velocity.x < 0
