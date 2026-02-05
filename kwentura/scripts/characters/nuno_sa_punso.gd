extends Area2D

signal player_touched(nuno)

var is_obstacle: bool = true
var is_chasing: bool = false
var disguised: bool = false

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	# Visual setup
	if disguised:
		# add nuno sa punso asset here
		sprite.texture = preload("")
	else:
		sprite.texture = preload("")
	
	# Connect collision
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and is_obstacle:
		emit_signal("player_touched", self)
		
		# Visual feedback - eyes open
		_reveal_true_form()

func _reveal_true_form():
	# Show Nuno's true form when touched - add asset here
	sprite.texture = preload("")
	modulate = Color(1, 0, 0, 1)
	
	# Scale up animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
