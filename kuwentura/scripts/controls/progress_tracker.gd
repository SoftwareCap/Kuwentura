extends Node2D

signal no_lives_remaining

const FULL_HEART_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/brownFullHeart.png")
const EMPTY_HEART_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/brownZeroHeart.png")

const PROGRESS_TEXTURES := {
	0: preload("res://assets/sprites/tracker/progress_0.png"),
	10: preload("res://assets/sprites/tracker/progress_10.png"),
	20: preload("res://assets/sprites/tracker/progress_20.png"),
	30: preload("res://assets/sprites/tracker/progress_30.png"),
	40: preload("res://assets/sprites/tracker/progress_40.png"),
	50: preload("res://assets/sprites/tracker/progress_50.png"),
	60: preload("res://assets/sprites/tracker/progress_60.png"),
	70: preload("res://assets/sprites/tracker/progress_70.png"),
	80: preload("res://assets/sprites/tracker/progress_80.png"),
	90: preload("res://assets/sprites/tracker/progress_90.png"),
	100: preload("res://assets/sprites/tracker/progress_100.png"),
}

const MAX_LIVES := 3

@onready var progress_sprite: Sprite2D = get_node_or_null("ProgressTracker") as Sprite2D
@onready var heart_sprites: Array[Sprite2D] = [
	get_node_or_null("Heart1") as Sprite2D,
	get_node_or_null("Heart2") as Sprite2D,
	get_node_or_null("Heart3") as Sprite2D,
]

var _remaining_lives := MAX_LIVES


func _ready() -> void:
	heart_sprites = heart_sprites.filter(func(heart: Sprite2D) -> bool: return is_instance_valid(heart))
	heart_sprites.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.position.x > b.position.x)
	_refresh_hearts()


func reset_tracker() -> void:
	set_progress_texture(0)
	reset_lives()


func set_progress_by_completed_tasks(completed_tasks: int, total_tasks: int) -> void:
	if total_tasks <= 0:
		set_progress_texture(0)
		return

	var clamped_completed := clampi(completed_tasks, 0, total_tasks)
	var logical_percent := int(round((float(clamped_completed) / float(total_tasks)) * 100.0))
	var texture_percent := clampi(int(round(float(logical_percent) / 10.0) * 10), 0, 100)
	set_progress_texture(texture_percent)


func set_progress_texture(percent: int) -> void:
	if not is_instance_valid(progress_sprite):
		return

	var clamped_percent := clampi(percent, 0, 100)
	if not PROGRESS_TEXTURES.has(clamped_percent):
		clamped_percent = clampi(int(round(float(clamped_percent) / 10.0) * 10), 0, 100)
	if PROGRESS_TEXTURES.has(clamped_percent):
		progress_sprite.texture = PROGRESS_TEXTURES[clamped_percent]


func lose_life() -> int:
	if _remaining_lives <= 0:
		return 0

	_remaining_lives -= 1
	_refresh_hearts()
	print("Life lost. Remaining lives: %d" % _remaining_lives)
	if _remaining_lives <= 0:
		no_lives_remaining.emit()
	return _remaining_lives


func reset_lives() -> void:
	_remaining_lives = MAX_LIVES
	_refresh_hearts()


func get_remaining_lives() -> int:
	return _remaining_lives


func _refresh_hearts() -> void:
	for i in range(heart_sprites.size()):
		var heart := heart_sprites[i]
		if not is_instance_valid(heart):
			continue
		heart.texture = FULL_HEART_TEX if i < _remaining_lives else EMPTY_HEART_TEX
