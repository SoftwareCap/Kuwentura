extends CharacterBody2D

class_name Player

# CONSTANTS

# Network interpolation thresholds
const TELEPORT_THRESHOLD := 100.0
const LERP_DIST_FAR := 50.0
const LERP_DIST_NEAR := 10.0
const LERP_FACTOR_FAR := 0.5
const LERP_FACTOR_MID := 0.3
const LERP_FACTOR_DEFAULT := 0.15

# Sync
const POSITION_CHANGED_THRESHOLD := 0.5

# Physics
const FLOOR_MAX_ANGLE_DEG := 60.0
const FLOOR_SAFE_MARGIN := 0.05
const GROUNDING_VELOCITY := 100.0

# NODE REFERENCES
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var location_diamond: Node = $LocationDiamond

# EXPORTS
@export var speed: float = 350.0
@export var jump_force: float = -700.0
@export var role: String = "Detective"
@export var avatar_scale: Vector2 = Vector2(1.0, 1.0)
@export var sync_interval: float = 0.05

# STATE
var is_host: bool = false

var _is_in_lobby: bool = false
var _sync_timer: float = 0.0
var _last_sent_position: Vector2 = Vector2.ZERO
var _last_sent_animation: String = ""
var _remote_animation: String = ""
var _was_on_floor: bool = true
var _intended_x_position: float = 0.0
var _movement_locked: bool = false
# Defaults to true so all existing scenes (forest hub, lobby, etc.) work normally
# without needing to call initialize_spawn(). Bakunawa sets this to false via
# prepare_deferred_spawn() before add_child(), then calls initialize_spawn() after.
var _spawn_initialized: bool = true


# LIFECYCLE
func _ready() -> void:
	_is_in_lobby = get_parent() is Control

	if _is_in_lobby:
		if is_instance_valid(location_diamond):
			location_diamond.visible = false

	if multiplayer.has_multiplayer_peer():
		z_index = 10 if is_multiplayer_authority() else 0
	else:
		z_index = 10

	if not _is_in_lobby:
		_configure_physics()
		scale = avatar_scale
		# NOTE: _intended_x_position is NOT set here anymore.
		# It is set in initialize_spawn() after the scene assigns global_position,
		# so it never incorrectly captures x=0.
		force_update_transform()

		if _is_local_player():
			_last_sent_position = global_position
			_last_sent_animation = "idle"

		if role == "Detective":
			add_to_group("host_player")
		else:
			add_to_group("sidekick_player")

	if is_instance_valid(location_diamond):
		location_diamond.visible = false


# ---------------------------------------------------------------------------
# Call this BEFORE add_child() in scenes that assign position after _ready()
# (currently only Bakunawa). All other scenes skip this and work normally
# because _spawn_initialized defaults to true.
# ---------------------------------------------------------------------------
func prepare_deferred_spawn() -> void:
	_spawn_initialized = false

# ---------------------------------------------------------------------------
# Call this AFTER add_child() and after awaiting one frame so _ready() has
# already run. Sets position and _intended_x_position together so the player
# never snaps back to x=0.
# ---------------------------------------------------------------------------
func initialize_spawn(pos: Vector2) -> void:
	global_position        = pos
	_intended_x_position   = pos.x   # critical — must match the spawn position
	velocity               = Vector2.ZERO
	_spawn_initialized     = true

	if _is_local_player():
		_last_sent_position = pos


func _update_diamond_visibility() -> void:
	if not is_instance_valid(location_diamond):
		return
	if _is_in_lobby:
		location_diamond.visible = false
		return
	if multiplayer.has_multiplayer_peer():
		location_diamond.visible = is_multiplayer_authority()
	else:
		location_diamond.visible = true


func _process(_delta: float) -> void:
	if _is_in_lobby:
		_update_animation()
		return

	_update_diamond_visibility()

	if not multiplayer.has_multiplayer_peer():
		return

	if not is_multiplayer_authority():
		_update_from_network_state()


func set_movement_locked(locked: bool) -> void:
	_movement_locked = locked


func _physics_process(delta: float) -> void:
	if _movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _is_in_lobby:
		return

	# Don't process movement until initialize_spawn() has been called.
	# This prevents the player from falling or drifting before the scene
	# has positioned them at the spawn marker.
	if not _spawn_initialized and not _is_in_lobby:
		return

	if not multiplayer.has_multiplayer_peer():
		_process_local_movement(delta)
		return

	if is_multiplayer_authority():
		_process_local_movement(delta)
		var current_anim := _update_animation()
		_sync_state(delta, current_anim)
	else:
		velocity = Vector2.ZERO


func apply_pushback(force: Vector2) -> void:
	velocity += force


# SETUP
func _configure_physics() -> void:
	floor_constant_speed = false
	floor_stop_on_slope = true
	floor_block_on_wall = true
	floor_max_angle = deg_to_rad(FLOOR_MAX_ANGLE_DEG)
	floor_snap_length = 0.0
	motion_mode = MOTION_MODE_GROUNDED
	safe_margin = FLOOR_SAFE_MARGIN
	up_direction = Vector2.UP


# MOVEMENT
func _process_local_movement(delta: float) -> void:
	var direction := Input.get_axis("game_left", "game_right")

	# Only lock the intended x when standing still on the floor.
	if direction == 0 and is_on_floor():
		_intended_x_position = global_position.x

	velocity.x = direction * speed

	if not is_on_floor():
		velocity += get_gravity() * delta
		_was_on_floor = false
	else:
		# FIX: always clear any downward velocity the moment we're on the floor,
		# regardless of _was_on_floor state. This stops the slide-down bug when
		# pressing left or right along a flat surface.
		if velocity.y > 0:
			velocity.y = 0
		_was_on_floor = true

	if Input.is_action_just_pressed("game_jump"):
		_try_jump()

	move_and_slide()

	# Snap x position when idle to prevent floating-point drift.
	if is_on_floor() and direction == 0:
		global_position.x = _intended_x_position


func _try_jump() -> void:
	if is_on_floor():
		velocity.y = jump_force


# ANIMATION
func _update_animation() -> String:
	if velocity.x == 0:
		sprite.play("idle")
		return "idle"
	sprite.play("walk")
	sprite.flip_h = velocity.x < 0
	return "walk"


# NETWORK — LOCAL PLAYER
func _is_local_player() -> bool:
	return multiplayer.has_multiplayer_peer() and is_multiplayer_authority()


func _sync_state(delta: float, current_anim: String) -> void:
	_sync_timer += delta
	var pos_changed := global_position.distance_to(_last_sent_position) > POSITION_CHANGED_THRESHOLD
	var anim_changed := current_anim != _last_sent_animation

	if _sync_timer >= sync_interval and (pos_changed or anim_changed):
		_sync_timer = 0.0
		_last_sent_position = global_position
		_last_sent_animation = current_anim
		_send_state(current_anim)


func _send_state(animation: String) -> void:
	var facing := "left" if sprite.flip_h else "right"
	NetworkManager.sync_player_state.rpc(global_position, velocity, facing, animation)
	NetworkManager.report_position(multiplayer.get_unique_id(), global_position)


# NETWORK — REMOTE PLAYER
func _update_from_network_state() -> void:
	var peer_id: int = NetworkManager.get_partner_peer_id()
	print("[SYNC] partner_peer_id=", peer_id)
	if peer_id == 0:
		return

	var state := NetworkManager.get_partner_state(peer_id)
	print("[SYNC] state empty=", state.is_empty(), " keys=", NetworkManager._partner_states.keys())
	if state.is_empty():
		return

	var target_pos := state.get("position", global_position) as Vector2
	var distance := global_position.distance_to(target_pos)

	if distance > TELEPORT_THRESHOLD:
		global_position = target_pos
		return

	var lerp_factor := LERP_FACTOR_DEFAULT
	if distance > LERP_DIST_FAR:
		lerp_factor = LERP_FACTOR_FAR
	elif distance > LERP_DIST_NEAR:
		lerp_factor = LERP_FACTOR_MID

	global_position = global_position.lerp(target_pos, lerp_factor)
	sprite.flip_h = (state.get("facing", "right") == "left")

	var anim := state.get("animation", "idle") as String
	if anim != _remote_animation:
		_remote_animation = anim
		sprite.play(anim)


# PUBLIC API
func _force_grounded() -> void:
	velocity = Vector2.ZERO
	if not is_on_floor():
		velocity.y = GROUNDING_VELOCITY
		move_and_slide()
	velocity = Vector2.ZERO


func _force_initial_sync() -> void:
	if not _is_local_player():
		return
	_send_state("idle")
