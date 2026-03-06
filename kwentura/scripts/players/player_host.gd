extends CharacterBody2D

class_name Player

@onready var sprite = $AnimatedSprite2D

@export var speed = 350
@export var jump_force = -700
@export var role: String = "Detective"
@export var avatar_scale: Vector2 = Vector2(1.0, 1.0)
@export var sync_interval: float = 0.05  # Sync 20 times per second

var is_host = false

var _is_in_lobby = false
var _sync_timer: float = 0.0
var _last_sent_position: Vector2 = Vector2.ZERO
var _last_sent_animation: String = ""
var _remote_animation: String = ""


func _ready():
	_is_in_lobby = get_parent() is Control
	
	# Only check multiplayer authority if we have a valid multiplayer peer
	if multiplayer.has_multiplayer_peer():
		z_index = 10 if is_multiplayer_authority() else 0
	else:
		z_index = 10  # Default to local player visuals if no multiplayer
	
	if not _is_in_lobby:
		scale = avatar_scale
		# Scale floor snap length proportionally to avatar scale to prevent sinking
		# Base snap length of 32.0 at scale 1.0, scaled down for smaller avatars
		floor_snap_length = 32.0 * avatar_scale.y
		floor_max_angle = deg_to_rad(60.0)
		floor_block_on_wall = true
		floor_stop_on_slope = true
		motion_mode = MOTION_MODE_GROUNDED
		# Increase safe margin slightly for better collision at small scales
		safe_margin = 0.08


func _process(_delta):
	if _is_in_lobby:
		if velocity.x == 0:
			sprite.play("idle")
		else:
			sprite.play("walk")
			sprite.flip_h = velocity.x < 0
		return
	
	# Skip if no multiplayer peer available
	if not multiplayer.has_multiplayer_peer():
		return
	
	# If not authority, update from network
	if not is_multiplayer_authority():
		_update_from_network_state()


func _try_jump():
	if is_on_floor():
		velocity.y = jump_force


func _update_from_network_state():
	var peer_id = int(str(name))
	if peer_id == 0:
		return
	
	var state = NetworkManager.get_partner_state(peer_id)
	if state.is_empty():
		return
	
	# Update position
	var target_pos = state.get("position", global_position)
	global_position = global_position.lerp(target_pos, 0.3)
	
	# Update facing
	var facing = state.get("facing", "right")
	sprite.flip_h = (facing == "left")
	
	# Update animation (only if changed to avoid resetting animation frame)
	var anim = state.get("animation", "idle")
	if anim != _remote_animation:
		_remote_animation = anim
		if anim == "walk":
			sprite.play("walk")
		else:
			sprite.play("idle")


func _physics_process(delta):
	if _is_in_lobby:
		return
	
	# Only process input if we have authority (this is our local player)
	if is_multiplayer_authority():
		# Local movement input - ONLY for authority player
		var direction := Input.get_axis("game_left", "game_right")
		velocity.x = direction * speed

		# Gravity
		if not is_on_floor():
			velocity += get_gravity() * delta
		elif velocity.y > 0:
			velocity.y = 0

		# Jump
		if Input.is_action_just_pressed("game_jump"):
			_try_jump()

		move_and_slide()
		
		# Local animation
		var current_anim = "idle"
		if velocity.x == 0:
			sprite.play("idle")
		else:
			sprite.play("walk")
			sprite.flip_h = velocity.x < 0
			current_anim = "walk"
		
		# Sync to network
		_sync_timer += delta
		var pos_changed = global_position.distance_to(_last_sent_position) > 0.5
		var anim_changed = current_anim != _last_sent_animation
		
		if _sync_timer >= sync_interval and (pos_changed or anim_changed):
			_sync_timer = 0.0
			_last_sent_position = global_position
			_last_sent_animation = current_anim
			NetworkManager.sync_player_state.rpc(
				global_position,
				velocity,
				"left" if sprite.flip_h else "right",
				current_anim
			)
	else:
		# Remote player - just apply gravity and move_and_slide for collision
		# Position is updated from network in _process
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
