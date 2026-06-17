extends CharacterBody2D

# Kapre - Filipino Tree Giant
# A tall, dark-skinned creature with glowing red eyes

enum KapreState {
	IDLE,
	MANIFESTING,
	STALKING,
	ATTACKING,
	VANISHING
}

@export var state: KapreState = KapreState.IDLE
@export var move_speed: float = 120.0
@export var manifestation_time: float = 2.0
@export var stalking_radius: float = 300.0

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var eye_glow: PointLight2D = $EyeGlow
@onready var shadow: Sprite2D = $Shadow
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var smoke_particles: CPUParticles2D = $SmokeParticles

# State tracking
var is_active: bool = false
var manifestation_progress: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var stalking_timer: float = 0.0
var is_visible: bool = true

const AMBIENT_SFX_PATH := "res://assets/audios/sfx/kapre_ambient.wav"
const ROAR_SFX_PATH := "res://assets/audios/sfx/kapre_roar.wav"

# Signals
signal manifestation_started
signal manifestation_complete
signal kapre_attacked
signal kapre_vanished

func _ready() -> void:
	_setup_animations()
	_setup_eye_glow()
	_play_ambient_sound()
	
	# Start hidden
	sprite.visible = false
	shadow.visible = false
	eye_glow.energy = 0
	modulate.a = 0.0

func _setup_animations() -> void:
	if not sprite.sprite_frames:
		push_warning("[Kapre] No sprite frames assigned!")
		return
	
	# Create default animations if they don't exist
	var frames = sprite.sprite_frames
	
	# Check if animations exist, if not create placeholders
	if not frames.has_animation("idle") or frames.get_frame_count("idle") == 0:
		if not frames.has_animation("idle"):
			frames.add_animation("idle")
		_add_dummy_frame(frames, "idle")

	if not frames.has_animation("eyes_glow") or frames.get_frame_count("eyes_glow") == 0:
		if not frames.has_animation("eyes_glow"):
			frames.add_animation("eyes_glow")
		_add_dummy_frame(frames, "eyes_glow")

	if not frames.has_animation("manifest") or frames.get_frame_count("manifest") == 0:
		if not frames.has_animation("manifest"):
			frames.add_animation("manifest")
		_add_dummy_frame(frames, "manifest")

	if not frames.has_animation("walk") or frames.get_frame_count("walk") == 0:
		if not frames.has_animation("walk"):
			frames.add_animation("walk")
		_add_dummy_frame(frames, "walk")

	if not frames.has_animation("attack") or frames.get_frame_count("attack") == 0:
		if not frames.has_animation("attack"):
			frames.add_animation("attack")
		_add_dummy_frame(frames, "attack")

	sprite.play("idle")

func _add_dummy_frame(frames: SpriteFrames, anim_name: String) -> void:
	# Create a simple colored rectangle as placeholder if no texture
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.1, 0.05, 1.0))
	
	# Add eye highlights for eyes_glow animation
	if anim_name == "eyes_glow":
		image.fill_rect(Rect2(16, 20, 12, 12), Color(0.9, 0.2, 0.1, 1.0))
		image.fill_rect(Rect2(36, 20, 12, 12), Color(0.9, 0.2, 0.1, 1.0))
	
	var texture := ImageTexture.create_from_image(image)
	frames.add_frame(anim_name, texture)

func _setup_eye_glow() -> void:
	if eye_glow:
		eye_glow.energy = 0
		eye_glow.texture_scale = 0.5
		eye_glow.color = Color(0.9, 0.1, 0.05)

func _play_ambient_sound() -> void:
	if audio_player and audio_player.stream:
		audio_player.volume_db = -10
		audio_player.play()

func start_manifestation() -> void:
	if state != KapreState.IDLE:
		return
	
	state = KapreState.MANIFESTING
	is_active = true
	manifestation_progress = 0
	manifestation_started.emit()
	
	# Fade in
	modulate.a = 0.0
	sprite.visible = true
	shadow.visible = true
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, manifestation_time * 0.5)
	
	# Play manifestation animation
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("manifest"):
		sprite.play("manifest")
	
	# Glow eye
	if eye_glow:
		var glow_tween := create_tween()
		glow_tween.tween_property(eye_glow, "energy", 0.8, 0.3)
	
	# Play sound when the optional Kapre SFX assets are present.
	if audio_player:
		audio_player.stream = _load_optional_audio(AMBIENT_SFX_PATH)
		if audio_player.stream:
			audio_player.play()
	
	await get_tree().create_timer(manifestation_time).timeout
	_manifestation_complete()

func _manifestation_complete() -> void:
	state = KapreState.IDLE
	manifestation_complete.emit()
	
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func start_stalking(player_position: Vector2) -> void:
	if state != KapreState.IDLE:
		return
	
	state = KapreState.STALKING
	target_position = player_position
	
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")

func update_stalking(delta: float, player_position: Vector2) -> void:
	if state != KapreState.STALKING:
		return
	
	target_position = player_position
	
	# Move toward player
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)
	
	if distance > stalking_radius * 0.3:
		velocity = direction * move_speed * 0.5
	else:
		velocity = velocity.lerp(Vector2.ZERO, delta * 2.0)
	
	move_and_slide()
	
	# Face player
	if direction.x != 0:
		sprite.flip_h = direction.x < 0
	
	# Update stalking timer
	stalking_timer += delta
	
	# If too close, attack
	if distance < 80:
		trigger_attack()

func trigger_attack() -> void:
	if state == KapreState.ATTACKING:
		return
	
	state = KapreState.ATTACKING
	
	# Play attack animation
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	
	# Play roar
	var roar := AudioStreamPlayer2D.new()
	roar.stream = _load_optional_audio(ROAR_SFX_PATH)
	add_child(roar)
	if roar.stream:
		roar.finished.connect(roar.queue_free, CONNECT_ONE_SHOT)
		roar.play()
	else:
		roar.queue_free()
	
	# Camera shake
	var camera := get_viewport().get_camera_2d()
	if camera:
		var original_pos := camera.position
		var tween := create_tween()
		for i in range(15):
			var offset := Vector2(randf_range(-8, 8), randf_range(-8, 8))
			tween.tween_property(camera, "position", original_pos + offset, 0.03)
		tween.tween_property(camera, "position", original_pos, 0.1)
	
	await get_tree().create_timer(0.5).timeout
	
	kapre_attacked.emit()
	_trigger_consequence()

func _trigger_consequence() -> void:
	# This is called when Kapre attacks - triggers game over state
	get_tree().paused = true
	_show_kapre_game_over()
	await get_tree().create_timer(3.0).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func _show_kapre_game_over() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate.a = 0
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1000
	add_child(overlay)
	
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.8, 0.5)
	
	var label := Label.new()
	label.text = "KAPRE HAS CLAIMED THIS HOUSE\n\nThe shadow engulfs everything..."
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.z_index = 1001
	add_child(label)
	
	tween.tween_property(label, "modulate:a", 1.0, 0.3)

func _load_optional_audio(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("[Kapre] Optional audio is missing: " + path)
		return null
	return load(path) as AudioStream

func vanish() -> void:
	state = KapreState.VANISHING
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): 
		sprite.visible = false
		shadow.visible = false
		kapre_vanished.emit()
		queue_free()
	)

func _process(delta: float) -> void:
	# Pulsing eye glow when active
	if state != KapreState.IDLE and state != KapreState.VANISHING:
		if eye_glow and eye_glow.energy > 0:
			eye_glow.energy = 0.3 + (sin(Time.get_ticks_msec() * 0.001) * 0.5 + 0.5) * 0.5
	
	# Shadow follows character
	if shadow and is_visible:
		shadow.global_position = global_position + Vector2(0, 16)
