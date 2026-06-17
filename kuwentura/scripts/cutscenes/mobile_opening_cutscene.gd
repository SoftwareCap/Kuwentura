extends Control

## Lightweight mobile-safe opening cutscene.
## Avoids frame sequences and video streams so Android can enter gameplay reliably.

const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const STEP_HOLD_SECONDS := 2.2
const FADE_SECONDS := 0.25

@onready var background: ColorRect = $Background
@onready var title_label: Label = $Content/TitleLabel
@onready var body_label: Label = $Content/BodyLabel
@onready var continue_button: Button = $ContinueButton

var _step_index: int = 0
var _advance_requested: bool = false
var _leaving: bool = false

var _steps: Array[Dictionary] = [
	{
		"title": "The Story Fades",
		"body": "Grandmother's tale begins to disappear from the old book.",
		"color": Color(0.12, 0.08, 0.05, 1.0),
	},
	{
		"title": "A Lost Legend",
		"body": "Only those who seek the truth can restore the legend of Pina.",
		"color": Color(0.05, 0.07, 0.12, 1.0),
	},
	{
		"title": "Two Roles, One Case",
		"body": "Detective follows the clues. Sidekick listens, guides, and remembers.",
		"color": Color(0.08, 0.11, 0.08, 1.0),
	},
	{
		"title": "Enter The Forest",
		"body": "Find the missing pieces of the story before the night takes them.",
		"color": Color(0.04, 0.09, 0.07, 1.0),
	},
]


func _ready() -> void:
	set_process_unhandled_input(true)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.text = "Tap to continue"
	_fit_text_for_mobile()
	MusicController.play_track(MusicController.MusicTrack.OPENING_CUTSCENE, 0.4)
	await _run_steps()


func _fit_text_for_mobile() -> void:
	title_label.add_theme_font_size_override("font_size", 54)
	body_label.add_theme_font_size_override("font_size", 28)
	continue_button.custom_minimum_size = Vector2(260, 64)


func _run_steps() -> void:
	while _step_index < _steps.size():
		if not is_inside_tree() or _leaving:
			return
		await _show_step(_steps[_step_index])
		_step_index += 1
	_goto_hub()


func _show_step(step: Dictionary) -> void:
	_advance_requested = false
	title_label.text = step.get("title", "")
	body_label.text = step.get("body", "")
	background.color = step.get("color", Color.BLACK)

	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	await fade_in.finished

	var elapsed := 0.0
	while elapsed < STEP_HOLD_SECONDS and not _advance_requested:
		if not is_inside_tree() or _leaving:
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	if not is_inside_tree() or _leaving:
		return

	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	await fade_out.finished


func _on_continue_pressed() -> void:
	_advance_requested = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_advance_requested = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_requested = true


func _goto_hub() -> void:
	if _leaving or not is_inside_tree():
		return
	_leaving = true
	MusicController.stop_music(0.4)
	get_tree().change_scene_to_file(SCENE_FOREST_HUB)
