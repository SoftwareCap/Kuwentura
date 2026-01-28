extends CharacterBody2D

@export var speed = 350
@export var jump_force = -700
var is_host = false

func _process(_delta):
	# Movement logic (handled by _input)
	move_and_slide()

func _input(event):
	if event is InputEventScreenTouch:
		var screen_size = DisplayServer.screen_get_size()
		var screen_width = screen_size.x
		var screen_height = screen_size.y
		
		# Left zone: bottom-left 20% of screen width
		if event.position.x < screen_width * 0.2 and event.position.y > screen_height * 0.8:
			if event.pressed:
				velocity.x = -speed
			else:
				# velocity.x = 0
				pass
				
		# Right zone: bottom-right 20% of screen width  
		elif event.position.x > screen_width * 0.8 and event.position.y > screen_height * 0.8:
			if event.pressed:
				velocity.x = speed
			else:
				# velocity.x = 0
				pass
				
		# Center zone: bottom-center for action
		elif abs(event.position.x - screen_width/2) < 100 and event.position.y > screen_height * 0.8:
			if event.pressed and is_on_floor():
				velocity.y = jump_force

func _physics_process(delta):
	# Apply gravity (optional but recommended for jumps)
	if not is_on_floor():
		velocity.y += 1000 * delta  # Adjust gravity strength as needed
	move_and_slide()
