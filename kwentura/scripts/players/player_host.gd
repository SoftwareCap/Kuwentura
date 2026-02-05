extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D

@export var speed = 350
@export var jump_force = -700
var is_host = false

func _process(_delta):
	# Movement logic (handled by _input)
	move_and_slide()

var touch_left = false
var touch_right = false

func _input(event):
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_touch(event)  # Dragging should also control movement

func handle_touch(event):
	var screen_size = DisplayServer.screen_get_size()
	var zone_height_threshold = screen_size.y * 0.8
	
	if event.position.y <= zone_height_threshold:
		return  # Not in control zone
	
	if event.position.x < screen_size.x * 0.2:
		touch_left = event.pressed
	elif event.position.x > screen_size.x * 0.8:
		touch_right = event.pressed
	
	# Update velocity based on touch state
	if touch_left and not touch_right:
		velocity.x = -speed
	elif touch_right and not touch_left:
		velocity.x = speed
	else:
		velocity.x = 0

func _physics_process(delta):
	var direction := Input.get_axis("ui_left", "ui_right")
	
	# Only apply keyboard if no touch is active (or use a flag system)
	if direction != 0:
		velocity.x = direction * speed
	# else: touch controls handle velocity.x
	
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()
	
	# Animation
	if velocity.x == 0:
		sprite.play("idle")
	else:
		sprite.play("walk")
		sprite.flip_h = velocity.x < 0
