## opening_cutscene.gd
## MOBILE FIX: Added is_inside_tree() guards on every await,
## pre-null the video stream before the node is ready,
## and wrapped _run_cutscene in a top-level try guard.
extends Node

@onready var scene1 : Node = $Scene1
@onready var scene2 : Node = $Scene2

# Scene 1
@onready var grandma : AnimatedSprite2D = $Scene1/Grandma/AnimatedSprite2D
@onready var grandma_node : Node = $Scene1/Grandma
@onready var detective_idle1 : AnimatedSprite2D = $Scene1/DetectiveIdle
@onready var sidekick_idle1 : AnimatedSprite2D = $Scene1/SidekickIdle
@onready var scene1_background : Node = $Scene1/Background
@onready var book_scene : Node = $Scene1/BookScene
@onready var words_fading : AnimatedSprite2D = $Scene1/BookScene/WordsFading
@onready var book_flipping : AnimatedSprite2D = $Scene1/BookScene/BookFlipping
@onready var dialogue_box : Sprite2D = $DialogueBox
@onready var dialogue_label1 : Label = $Scene1_DialogueLabel
@onready var name_label1 : Label = $Scene1_NameLabel

# Scene 2
@onready var grandma_flip : AnimatedSprite2D = $Scene2/GrandmaFlipping/AnimatedSprite2D
@onready var grandma_light : AnimatedSprite2D = $Scene2/GrandmaLightEmerge/AnimatedSprite2D
@onready var wind_anim : AnimatedSprite2D = $Scene2/WindAnimation
@onready var dialogue_label2 : Label = $Scene2/Scene2_DialogueLabel
@onready var name_label2 : Label = $Scene2/Scene2_NameLabel
@onready var detective_idle2 : AnimatedSprite2D = $Scene2/DetectiveIdle
@onready var sidekick_idle2 : AnimatedSprite2D = $Scene2/SidekickIdle

# Scene 3
@onready var scene3 : Node = $Scene3
@onready var scene3_book_glow : PointLight2D = $Scene3/Scene3_BookGlow
@onready var detective_silhouette : Node = $Scene3/DetectiveSilhouette
@onready var sidekick_silhouette : Node = $Scene3/SidekickSilhouette
@onready var players_pull : AnimatedSprite2D = $Scene3/PlayersPull
@onready var dialogue_label3 : Label = $Scene3/Scene3_DialogueLabel
@onready var name_label3 : Label = $Scene3/Scene3_NameLabel

@onready var skip_button : Button = $SkipButton

# Scene 4
@onready var scene4 : Node = $Scene4
@onready var zones_intro_video : VideoStreamPlayer = $Scene4/ZonesIntro

# Tunables
const DIALOGUE_SPEED : float = 0.04
const PAUSE_SHORT : float = 1.0
const FADE_DURATION : float = 1.5

# Internal state
var _skip_pressed : bool = false
var _typing_done : bool = false
var _cutscene_aborted : bool = false  # NEW: global abort flag

var _bg_filler : ColorRect


func _ready() -> void:
	# ── MOBILE CRITICAL FIX ──────────────────────────────────────────────────
	# Null the video stream BEFORE anything else touches it.
	# On Android, the VideoStreamPlayer node eagerly starts decoding in _ready
	# even if you never call play(). Setting stream=null here prevents that crash.
	if CutsceneHelper.is_mobile_platform():
		zones_intro_video.stream = null
		zones_intro_video.visible = false
	# ─────────────────────────────────────────────────────────────────────────

	_bg_filler = ColorRect.new()
	_bg_filler.name = "BgFiller"
	_bg_filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_filler.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_filler.color = Color(0.22, 0.16, 0.10, 1.0)
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	cl.add_child(_bg_filler)

	scene2.visible = false
	scene2.modulate.a = 0.0

	_clear_dialogue(dialogue_label1, name_label1)
	_clear_dialogue(dialogue_label2, name_label2)
	_clear_dialogue(dialogue_label3, name_label3)

	dialogue_box.visible = false
	players_pull.visible = false

	book_scene.visible = false
	book_flipping.visible = false
	words_fading.visible = false
	wind_anim.visible = false
	grandma_light.get_parent().visible = false

	scene3.visible = false
	scene3.modulate.a = 0.0
	detective_silhouette.visible = false
	sidekick_silhouette.visible = false

	scene4.visible = false
	scene4.modulate.a = 0.0

	skip_button.visible = false
	skip_button.pressed.connect(_on_skip_pressed)
	_setup_skip_button_for_mobile()

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


# ── SAFE AWAIT HELPER ────────────────────────────────────────────────────────
# Every await in the cutscene goes through _safe_wait so that if the node is
# freed mid-animation (app backgrounded, scene changed) we set _cutscene_aborted
# and all subsequent guards bail out cleanly instead of crashing.
func _safe_wait(seconds: float) -> void:
	if _cutscene_aborted or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		_cutscene_aborted = true


func _safe_frame() -> void:
	if _cutscene_aborted or not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		_cutscene_aborted = true


func _abort_if_dead() -> bool:
	if _cutscene_aborted or not is_inside_tree():
		_cutscene_aborted = true
		return true
	return false
# ─────────────────────────────────────────────────────────────────────────────


# MAIN COROUTINE
func _run_cutscene() -> void:
	# Top-level guard: if anything goes wrong we still end up at ForestHub
	MusicController.play_track(MusicController.MusicTrack.OPENING_CUTSCENE, 1.0)

	await _scene1()
	if _abort_if_dead(): _goto_hub(); return

	_transition_to_scene2()
	if _abort_if_dead(): _goto_hub(); return

	await _scene2()
	if _abort_if_dead(): _goto_hub(); return

	await _transition_to_scene3()
	if _abort_if_dead(): _goto_hub(); return

	await _scene3()
	if _abort_if_dead(): _goto_hub(); return

	await _transition_to_scene4()
	if _abort_if_dead(): _goto_hub(); return

	await _scene4()
	if _abort_if_dead(): _goto_hub(); return

	MusicController.stop_music(1.5)
	await _safe_wait(1.5)
	_goto_hub()


func _goto_hub() -> void:
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


# SCENE 1
func _scene1() -> void:
	_play_anim(grandma, "sitting_idle")
	_play_anim(detective_idle1, "default")
	_play_anim(sidekick_idle1, "default")
	await _say1("Grandmother", "Long ago, in a quiet village, there lived a girl named Pina…")
	if _abort_if_dead(): return
	await _say1_auto("Grandmother", "She was known for—", 1.0)
	if _abort_if_dead(): return

	book_scene.visible = true
	book_scene.modulate.a = 0.0
	words_fading.visible = true
	_play_anim(words_fading, "words_fading")
	await _fade_node(book_scene, 1.0)
	if _abort_if_dead(): return

	await _say1_auto("Grandmother", "Hmm… that's strange…", 1.2)
	if _abort_if_dead(): return
	await _say1_auto("Grandmother", "Wait… the words… they're disappearing.", 1.2)
	if _abort_if_dead(): return

	words_fading.visible = false
	_set_flipping_mode(true)
	await _say1("Grandmother", "No… no… this can't be happening.")
	if _abort_if_dead(): return
	await _say1_auto("Grandmother", "How can I tell the story if the words are gone?", 1.2)
	if _abort_if_dead(): return

	_clear_dialogue(dialogue_label1, name_label1)


# TRANSITION Scene 1 → Scene 2
func _transition_to_scene2() -> void:
	skip_button.visible = false
	grandma_node.visible = false
	book_flipping.visible = false
	book_scene.visible = false
	detective_idle1.visible = false
	sidekick_idle1.visible = false
	scene2.visible = true
	scene2.modulate.a = 1.0
	if _bg_filler:
		_bg_filler.color = Color(0.10, 0.08, 0.06, 1.0)


# SCENE 2
func _scene2() -> void:
	_play_anim(grandma_flip, "sitting_flipping")
	_play_anim(detective_idle2, "default")
	_play_anim(sidekick_idle2, "default")
	await _say2_auto("Grandmother", "What is happening to this book?", 1.2)
	if _abort_if_dead(): return
	await _say2_auto("Grandmother", "The story is fading.", 1.2)
	if _abort_if_dead(): return

	grandma_flip.get_parent().visible = false
	grandma_light.get_parent().visible = true
	_play_anim(grandma_light, "sitting_light")
	await _say2_auto("Grandmother", "If the story disappears…", 1.2)
	if _abort_if_dead(): return

	scene1_background.visible = false
	wind_anim.visible = true
	_play_anim(wind_anim, "wind_swirling")
	await _say2_auto("Grandmother", "The legend will be lost forever.", 1.0)
	if _abort_if_dead(): return

	_clear_dialogue(dialogue_label2, name_label2)


# TRANSITION Scene 2 → Scene 3
func _transition_to_scene3() -> void:
	skip_button.visible = false
	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(scene2, "modulate:a", 0.0, FADE_DURATION)
	fade_out.tween_property(dialogue_box, "modulate:a", 0.0, FADE_DURATION)
	await fade_out.finished
	if _abort_if_dead(): return

	_clear_dialogue(dialogue_label2, name_label2)
	scene2.visible = false
	dialogue_box.visible = false
	if _bg_filler:
		_bg_filler.color = Color(0.04, 0.04, 0.08, 1.0)
	scene3.visible = true
	await _fade_node(scene3, 1.0)


# SCENE 3
func _scene3() -> void:
	scene3_book_glow.energy = 0.0
	var glow_tw := create_tween()
	glow_tw.tween_property(scene3_book_glow, "energy", 3.0, 1.5)
	await _safe_wait(0.8)
	if _abort_if_dead(): return

	detective_silhouette.visible = true
	sidekick_silhouette.visible = true
	detective_silhouette.modulate.a = 0.0
	sidekick_silhouette.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(detective_silhouette, "modulate:a", 1.0, 1.0)
	tw.tween_property(sidekick_silhouette, "modulate:a", 1.0, 1.0)
	await tw.finished
	if _abort_if_dead(): return

	await _say3_auto("", "Only those who seek the truth can restore the lost story.", 1.5)
	if _abort_if_dead(): return
	await _say3_auto("", "The legend of Pina has been forgotten.", 1.5)
	if _abort_if_dead(): return
	await _say3_auto("", "Find the truth behind her disappearance.", 1.5)
	if _abort_if_dead(): return
	await _say3_auto("", "Restore the missing pieces of the tale.", 1.5)
	if _abort_if_dead(): return

	_clear_dialogue(dialogue_label3, name_label3)
	dialogue_box.visible = false
	players_pull.visible = true
	_play_anim(players_pull, "players_pull")

	# Safely compute frame duration — guard against missing animation
	var frame_count: int = 1
	var frame_speed: float = 8.0
	if players_pull.sprite_frames and players_pull.sprite_frames.has_animation("players_pull"):
		frame_count = players_pull.sprite_frames.get_frame_count("players_pull")
		frame_speed = players_pull.sprite_frames.get_animation_speed("players_pull")
	if frame_speed <= 0.0:
		frame_speed = 8.0
	await _safe_wait(float(frame_count) / frame_speed)
	if _abort_if_dead(): return

	var dissolve := create_tween()
	dissolve.tween_property(scene3, "modulate:a", 0.0, 2.0)
	await dissolve.finished
	if _abort_if_dead(): return

	_clear_dialogue(dialogue_label3, name_label3)


# TRANSITION Scene 3 → Scene 4
func _transition_to_scene4() -> void:
	skip_button.visible = false
	scene4.visible = true
	scene4.modulate.a = 0.0
	await _fade_node(scene4, 1.0)


# SCENE 4 — ZONE INTRODUCTION
func _scene4() -> void:
	skip_button.text = "Skip"
	skip_button.visible = true
	_skip_pressed = false

	# On mobile OR if stream was already nulled, just wait briefly and move on.
	if CutsceneHelper.is_mobile_platform() or zones_intro_video.stream == null:
		zones_intro_video.visible = false
		await _safe_wait(1.5)
	else:
		zones_intro_video.play()
		var start_ms := Time.get_ticks_msec()
		const MAX_WAIT_MS := 15000
		while zones_intro_video.is_playing() and not _skip_pressed:
			if not is_inside_tree():
				_cutscene_aborted = true
				return
			if Time.get_ticks_msec() - start_ms > MAX_WAIT_MS:
				break
			await _safe_frame()
		zones_intro_video.stop()

	skip_button.visible = false
	var dissolve := create_tween()
	dissolve.tween_property(scene4, "modulate:a", 0.0, FADE_DURATION)
	await dissolve.finished


# ── HELPERS ──────────────────────────────────────────────────────────────────

func _say1(speaker: String, text: String) -> void:
	await _say(dialogue_label1, name_label1, speaker, text)

func _say1_auto(speaker: String, text: String, hold: float) -> void:
	await _say_auto(dialogue_label1, name_label1, speaker, text, hold)

func _say2(speaker: String, text: String) -> void:
	await _say(dialogue_label2, name_label2, speaker, text)

func _say2_auto(speaker: String, text: String, hold: float) -> void:
	await _say_auto(dialogue_label2, name_label2, speaker, text, hold)

func _say3(speaker: String, text: String) -> void:
	await _say(dialogue_label3, name_label3, speaker, text)

func _say3_auto(speaker: String, text: String, hold: float) -> void:
	await _say_auto(dialogue_label3, name_label3, speaker, text, hold)


func _fade_node(node: Node, target_alpha: float) -> void:
	if not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", target_alpha, FADE_DURATION)
	await tw.finished


func _set_flipping_mode(flipping: bool) -> void:
	grandma_node.visible = not flipping
	book_flipping.visible = flipping
	if flipping:
		_play_anim(book_flipping, "book_flipping")
	else:
		_play_anim(grandma, "sitting_idle")


func _play_anim(sprite: AnimatedSprite2D, anim: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func _say(dlabel: Label, nlabel: Label, speaker: String, text: String) -> void:
	if _abort_if_dead():
		return
	_skip_pressed = false
	_typing_done = false
	nlabel.text = speaker
	dlabel.text = ""

	dialogue_box.modulate.a = 1.0
	dialogue_box.visible = true
	skip_button.text = "Skip"
	skip_button.visible = true

	var char_index : int = 0
	var length : int = text.length()

	while char_index <= length:
		if _abort_if_dead():
			return
		if _skip_pressed:
			dlabel.text = text
			_skip_pressed = false
			break
		await get_tree().create_timer(DIALOGUE_SPEED).timeout
		if _abort_if_dead():
			return
		char_index += 1
		dlabel.text = text.substr(0, char_index)
		if _skip_pressed:
			dlabel.text = text
			break

	_typing_done = true
	skip_button.text = "Tap to continue" if CutsceneHelper.is_mobile_platform() else "Click to continue.."
	_skip_pressed = false

	if CutsceneHelper.is_mobile_platform():
		var wait_start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - wait_start < 2500 and not _skip_pressed:
			if _abort_if_dead():
				return
			await get_tree().process_frame
	else:
		while not _skip_pressed:
			if _abort_if_dead():
				return
			await get_tree().process_frame

	dialogue_box.visible = false
	skip_button.visible = false
	_skip_pressed = false


func _say_auto(dlabel: Label, nlabel: Label, speaker: String, text: String, hold: float) -> void:
	if _abort_if_dead():
		return
	_skip_pressed = false
	nlabel.text = speaker
	dlabel.text = ""

	dialogue_box.modulate.a = 1.0
	dialogue_box.visible = true
	skip_button.visible = false

	var char_index : int = 0
	var length : int = text.length()

	while char_index <= length:
		if _abort_if_dead():
			return
		await get_tree().create_timer(DIALOGUE_SPEED).timeout
		if _abort_if_dead():
			return
		char_index += 1
		dlabel.text = text.substr(0, char_index)

	await _safe_wait(hold)


func _clear_dialogue(dlabel: Label, nlabel: Label) -> void:
	if is_instance_valid(dlabel):
		dlabel.text = ""
	if is_instance_valid(nlabel):
		nlabel.text = ""
