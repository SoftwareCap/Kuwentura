extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D

@export var speed = 350
@export var jump_force = -700
@export var role: String = "Detective"
@export var avatar_scale: Vector2 = Vector2(1.0, 1.0)
var is_host = false

# Movement state
var touch_left = false
var touch_right = false
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


func _input(event):
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)


func handle_touch(event):
	var screen_size = DisplayServer.screen_get_size()
	var zone_height_threshold = screen_size.y * 0.8

	if event.position.y <= zone_height_threshold:
		return

	if event.position.x < screen_size.x * 0.2:
		touch_left = event.pressed
	elif event.position.x > screen_size.x * 0.8:
		touch_right = event.pressed

	_update_velocity()


func handle_drag(event):
	var screen_size = DisplayServer.screen_get_size()
	var zone_height_threshold = screen_size.y * 0.8

	if event.position.y <= zone_height_threshold:
		return

	if event.position.x < screen_size.x * 0.2:
		touch_left = true
		touch_right = false
	elif event.position.x > screen_size.x * 0.8:
		touch_left = false
		touch_right = true
	else:
		touch_left = false
		touch_right = false

	_update_velocity()


func _update_velocity():
	if touch_left and not touch_right:
		velocity.x = -speed
	elif touch_right and not touch_left:
		velocity.x = speed
	else:
		velocity.x = 0


func _physics_process(delta):
	# Skip physics in lobby
	if _is_in_lobby:
		return

	var direction := Input.get_axis("ui_left", "ui_right")

	# Apply keyboard input only if no touch is active
	if direction != 0 and not touch_left and not touch_right:
		velocity.x = direction * speed
	elif not touch_left and not touch_right:
		velocity.x = 0

	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		# On floor - keep Y velocity at 0 to prevent sliding
		velocity.y = 0

	# Move and slide
	move_and_slide()

	# Animation
	if velocity.x == 0:
		sprite.play("idle")
	else:
		sprite.play("walk")
		sprite.flip_h = velocity.x < 0
