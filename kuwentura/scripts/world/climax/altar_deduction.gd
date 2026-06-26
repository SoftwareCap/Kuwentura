extends Node2D

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var dialogue_box: Sprite2D = $DialogueBox
@onready var dialogue_label: Label = $Scene1_DialogueLabel

# --- Edit your dialogue lines here ---
var dialogue_lines: Array = [
	"The missing pieces are united.",
	"The truth has been uncovered.",
	"The legend is restored.",
]

var current_line: int = 0
var seconds_per_line: float = 4.5  # Adjust how long each line shows

var video_finished: bool = false
var dialogue_finished: bool = false

var dialogue_timer: Timer

func _ready() -> void:
	MusicController.play_track(MusicController.MusicTrack.ALTAR_DEDUCTION)
	_fit_video_to_screen()
	video_player.play()
	video_player.finished.connect(_on_video_finished)

	dialogue_timer = Timer.new()
	add_child(dialogue_timer)
	dialogue_timer.wait_time = seconds_per_line
	dialogue_timer.one_shot = false
	dialogue_timer.timeout.connect(_on_dialogue_timer_timeout)

	_show_dialogue_line(current_line)
	dialogue_timer.start()

func _fit_video_to_screen() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	video_player.expand = true
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.set_deferred("size", screen_size)
	video_player.set_deferred("position", Vector2.ZERO)

func _show_dialogue_line(index: int) -> void:
	dialogue_label.text = dialogue_lines[index]
	dialogue_box.visible = true
	dialogue_label.visible = true

func _on_dialogue_timer_timeout() -> void:
	current_line += 1
	if current_line < dialogue_lines.size():
		_show_dialogue_line(current_line)
	else:
		dialogue_timer.stop()
		dialogue_box.visible = false
		dialogue_label.visible = false
		dialogue_finished = true
		_try_change_scene()

func _on_video_finished() -> void:
	video_finished = true
	_try_change_scene()

func _try_change_scene() -> void:
	if video_finished and dialogue_finished:
		# Fade to black before switching
		var black := ColorRect.new()
		black.color = Color(0, 0, 0, 0)
		black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var cl := CanvasLayer.new()
		cl.layer = 99
		add_child(cl)
		cl.add_child(black)

		var fade := create_tween()
		fade.tween_property(black, "color:a", 1.0, 1.5)
		await fade.finished

		get_tree().change_scene_to_file("res://scenes/cutscenes/endingscene/EndingScene.tscn")
