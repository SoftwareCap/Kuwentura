extends CanvasLayer

## LoadingScreen - Reusable scene transition with fade effect

@onready var fade_rect: ColorRect = $FadeRect
@onready var loading_label: Label = $LoadingLabel

var _is_transitioning: bool = false


func _ready():
	# Start fully transparent
	fade_rect.modulate = Color(0, 0, 0, 0)
	loading_label.modulate = Color(1, 1, 1, 0)
	visible = false


## Transition to a new scene with fade effect
func change_scene(scene_path: String, fade_duration: float = 0.5) -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	visible = true
	
	print("[LoadingScreen] Starting transition to: ", scene_path)
	
	# Fade in (to black)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_rect, "modulate", Color(0, 0, 0, 1), fade_duration)
	tween.tween_property(loading_label, "modulate", Color(1, 1, 1, 1), fade_duration)
	
	await tween.finished
	
	# Change scene
	var err = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("[LoadingScreen] Failed to change scene: " + scene_path)
	
	# Small delay to let the new scene load
	await get_tree().create_timer(0.1).timeout
	
	# Fade out (back to transparent)
	var tween_out = create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(fade_rect, "modulate", Color(0, 0, 0, 0), fade_duration)
	tween_out.tween_property(loading_label, "modulate", Color(1, 1, 1, 0), fade_duration)
	
	await tween_out.finished
	
	visible = false
	_is_transitioning = false
	
	print("[LoadingScreen] Transition complete")


## Simple fade to black and back (for effect)
func fade_out_in(duration: float = 0.5, hold_time: float = 0.2) -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	visible = true
	
	# Fade to black
	var tween_in = create_tween()
	tween_in.tween_property(fade_rect, "modulate", Color(0, 0, 0, 1), duration)
	await tween_in.finished
	
	# Hold
	await get_tree().create_timer(hold_time).timeout
	
	# Fade back
	var tween_out = create_tween()
	tween_out.tween_property(fade_rect, "modulate", Color(0, 0, 0, 0), duration)
	await tween_out.finished
	
	visible = false
	_is_transitioning = false


func is_transitioning() -> bool:
	return _is_transitioning
