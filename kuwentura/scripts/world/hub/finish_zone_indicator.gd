extends Node2D

## Finish Zone Indicator - Manages completion indicators for all zones.
## Uses editor-set positions; only handles visibility and sparkle animation.

const SPARKLE_PULSE_SPEED: float = 3.0
const SPARKLE_MIN_SCALE: float = 0.15
const SPARKLE_MAX_SCALE: float = 0.25

const ZONE_CHILD_MAP: Dictionary = {
	"pinas_house": "PinasHouse",
	"old_well": "OldWell",
	"backyard_path": "Backyard",
	"storage_hut": "StorageHut",
	"abandoned_house":"AbandonedHouse",
}

var _animation_time: float = 0.0


func _ready() -> void:
	## All indicators start hidden — ForestHub shows them as zones are completed.
	for child in get_children():
		if child is CanvasItem:
			child.visible = false


func _process(delta: float) -> void:
	_animation_time += delta
	_animate_sparkles()


func show_indicator(zone_name: String) -> void:
	var child_name := ZONE_CHILD_MAP.get(zone_name, "") as String
	if child_name.is_empty():
		return
	var indicator := get_node_or_null(child_name)
	if indicator:
		indicator.visible = true
		visible = true


func hide_indicator(zone_name: String) -> void:
	var child_name := ZONE_CHILD_MAP.get(zone_name, "") as String
	if child_name.is_empty():
		return
	var indicator := get_node_or_null(child_name)
	if indicator:
		indicator.visible = false


func _animate_sparkles() -> void:
	for zone_name in ZONE_CHILD_MAP.values():
		var indicator := get_node_or_null(zone_name)
		if not indicator or not indicator.visible:
			continue
		var sparkle := indicator.get_node_or_null("Sparkle") as Sprite2D
		if sparkle:
			_apply_sparkle_animation(sparkle)


func _apply_sparkle_animation(sparkle: Sprite2D) -> void:
	var pulse := (sin(_animation_time * SPARKLE_PULSE_SPEED) + 1.0) / 2.0
	var target_scale: float = lerp(SPARKLE_MIN_SCALE, SPARKLE_MAX_SCALE, pulse)
	sparkle.scale = Vector2(target_scale, target_scale)
