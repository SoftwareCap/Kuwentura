extends Node

# Scene 1
@onready var scene1: Node = $Scene1
@onready var grandma: AnimatedSprite2D = $Scene1/Grandma/AnimatedSprite2D
@onready var detective_idle1: AnimatedSprite2D = $Scene1/DetectiveIdle
@onready var sidekick_idle1: AnimatedSprite2D = $Scene1/SidekickIdle

# Scene 2
@onready var scene2: Node = $Scene2
@onready var wind_anim: AnimatedSprite2D = $Scene2/WindAnimation
@onready var pineapple: Node2D = $Scene2/Pineapple

# UI
@onready var dialogue_box: Sprite2D = $DialogueBox
@onready var dialogue_label: Label = $DialogueLabel
@onready var name_label: Label = $NameLabel
@onready var skip_button: Button = $SkipButton

# Tunables
const DIALOGUE_SPEED: float = 0.04
const FADE_DURATION: float = 1.5

# Internal state
var _skip_pressed: bool = false
var _cutscene_aborted: bool = false


func _ready() -> void:
	scene2.visible = false
	pineapple.visible = false
	dialogue_box.visible = false
	dialogue_label.visible = false
	name_label.visible = false
	skip_button.visible = false
	skip_button.pressed.connect(_on_skip_pressed)
	_setup_skip_button_for_mobile()

	_play_anim(grandma, "sitting_idle")
	_play_anim(detective_idle1, "default")
	_play_anim(sidekick_idle1, "default")

		# Fade in from black on scene entry
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 99
	add_child(cl)
	cl.add_child(black)
	var fade_in := create_tween()
	fade_in.tween_property(black, "color:a", 0.0, 1.5)
	await fade_in.finished
	cl.queue_free()

	_run_cutscene()


func _on_skip_pressed() -> void:
	_skip_pressed = true


func _setup_skip_button_for_mobile() -> void:
	if not is_instance_valid(skip_button):
		return
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "CutsceneUI"
	ui_layer.layer = 100
	add_child(ui_layer)
	skip_button.reparent(ui_layer)
	skip_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.offset_left = -240.0
	skip_button.offset_top = -56.0
	skip_button.offset_right = -16.0
	skip_button.offset_bottom = -16.0
	skip_button.custom_minimum_size = Vector2(200, 48)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_skip_pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip_pressed = true


func _safe_wait(seconds: float) -> void:
	if _cutscene_aborted or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		_cutscene_aborted = true


func _abort_if_dead() -> bool:
	if _cutscene_aborted or not is_inside_tree():
		_cutscene_aborted = true
		return true
	return false


func _run_cutscene() -> void:
	await _say("Grandmother", "Ah… there it is. The words have finally returned.")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "Let me read it to you properly this time.")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "Long ago, in a quiet village, there lived a girl named Pina…")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "She was known for her beauty and her soft, gentle voice.")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "But, she was also known for something else… her laziness.")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "Her mother always asked Pina to help with the chores, but Pina preferred to sleep, play, or daydream.")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "Whenever her mother asked her to do something, Pina would complain.")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "\"Pina, please cook the rice.\"")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "And because she always asked, \"Where is it?\", she was given eyes all over her body… becoming the pineapple we know today.")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "Thank you, my dear detectives. You found the missing pieces and restored the legend.")
	if _abort_if_dead(): _goto_credits(); return

	await _say("Grandmother", "The story of Pina will never be forgotten again.")
	if _abort_if_dead(): _goto_credits(); return

	await _outro()
	_goto_credits()


func _outro() -> void:
	# Hide all dialogue nodes immediately
	dialogue_box.visible = false
	dialogue_label.visible = false
	name_label.visible = false
	skip_button.visible = false

	var camera: Camera2D = $Camera2D

	# Zoom camera toward the book/table
	var zoom_tween := create_tween()
	zoom_tween.tween_property(camera, "zoom", Vector2(1.6, 1.6), 2.5).set_ease(Tween.EASE_IN_OUT)
	await zoom_tween.finished
	if _abort_if_dead(): return

	await _safe_wait(0.3)
	if _abort_if_dead(): return

	# Show Scene2 but hide everything inside it first
	scene2.visible = true
	for child in scene2.get_children():
		child.visible = false
	wind_anim.visible = true
	wind_anim.modulate.a = 0.0

	# Fade wind animation in
	var wind_fade_in := create_tween()
	wind_fade_in.tween_property(wind_anim, "modulate:a", 1.0, 0.5)
	await wind_fade_in.finished
	if _abort_if_dead(): return

	# Play wind animation and calculate its duration
	wind_anim.play("wind_swirling")
	var frame_count: int = wind_anim.sprite_frames.get_frame_count("wind_swirling")
	var fps: float = wind_anim.sprite_frames.get_animation_speed("wind_swirling")
	var anim_duration: float = frame_count / fps

	# Wait until 0.5s before the animation ends, then start pineapple fade-in
	await _safe_wait(anim_duration - 0.5)
	if _abort_if_dead(): return

	# Pineapple fades in while wind animation is still finishing
	pineapple.visible = true
	pineapple.modulate.a = 0.0
	var pine_fade := create_tween()
	pine_fade.tween_property(pineapple, "modulate:a", 1.0, 0.5)
	await pine_fade.finished
	if _abort_if_dead(): return

	wind_anim.visible = false

	await _safe_wait(1.0)
	if _abort_if_dead(): return

	# Fade everything to black + fade out music together
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 99
	add_child(cl)
	cl.add_child(black)

	MusicController.stop_music(FADE_DURATION)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(black, "color:a", 1.0, FADE_DURATION)
	fade.tween_property(pineapple, "modulate:a", 0.0, FADE_DURATION)
	await fade.finished
	if _abort_if_dead(): return

	await _safe_wait(0.5)


func _goto_credits() -> void:
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/credits/Credits.tscn")


func _play_anim(sprite: AnimatedSprite2D, anim: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func _say(speaker: String, text: String) -> void:
	if _abort_if_dead():
		return
	_skip_pressed = false
	name_label.text = speaker
	dialogue_label.text = ""
	dialogue_box.visible = true
	dialogue_label.visible = true
	name_label.visible = true
	skip_button.text = "Skip"
	skip_button.visible = true

	var char_index: int = 0
	var length: int = text.length()

	while char_index <= length:
		if _abort_if_dead(): return
		if _skip_pressed:
			dialogue_label.text = text
			_skip_pressed = false
			break
		await get_tree().create_timer(DIALOGUE_SPEED).timeout
		if _abort_if_dead(): return
		char_index += 1
		dialogue_label.text = text.substr(0, char_index)

	skip_button.text = "Tap to continue" if CutsceneHelper.is_mobile_platform() else "Click to continue..."
	_skip_pressed = false

	if CutsceneHelper.is_mobile_platform():
		var wait_start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - wait_start < 2500 and not _skip_pressed:
			if _abort_if_dead(): return
			await get_tree().process_frame
	else:
		while not _skip_pressed:
			if _abort_if_dead(): return
			await get_tree().process_frame

	dialogue_box.visible = false
	dialogue_label.visible = false
	name_label.visible = false
	skip_button.visible = false
	_skip_pressed = false
