extends CanvasLayer

## LoadingScreen - Reusable scene transition with fade effect.

@onready var fade_rect: ColorRect = $FadeRect
@onready var loading_label: Label = $LoadingLabel
@onready var spinner: Sprite2D = $Sprite2D

var _is_transitioning: bool = false


func _ready() -> void:
	fade_rect.modulate = Color.TRANSPARENT
	loading_label.modulate = Color(1, 1, 1, 0)
	visible = false


func change_scene(scene_path: String, fade_duration: float = 0.5) -> void:
	if not _begin_transition():
		return
	
	# Fade to black first
	await _fade(Color.BLACK, fade_duration)
	
	# Change the scene while screen is black
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("[LoadingScreen] Failed to change scene: " + scene_path)
		_end_transition()
		return
	
	# Wait for the new scene to be fully ready before fading back in
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Fade back in
	await _fade(Color.TRANSPARENT, fade_duration)
	_end_transition()


func fade_out_in(duration: float = 0.5, hold_time: float = 0.2) -> void:
	if not _begin_transition():
		return
	await _fade(Color.BLACK, duration)
	await get_tree().create_timer(hold_time).timeout
	await _fade(Color.TRANSPARENT, duration)
	_end_transition()


func is_transitioning() -> bool:
	return _is_transitioning


func _begin_transition() -> bool:
	if _is_transitioning:
		return false
	_is_transitioning = true
	visible = true
	return true


func _end_transition() -> void:
	visible = false
	_is_transitioning = false


func _fade(target: Color, duration: float) -> void:
	"""Fade both fade_rect and loading_label to target color in parallel."""
	var label_target := Color(1, 1, 1, target.a)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_rect, "modulate", target, duration)
	tween.tween_property(loading_label, "modulate", label_target, duration)
	await tween.finished


func _process(delta: float) -> void:
	if _is_transitioning:
		spinner.rotation += delta * 2.0
