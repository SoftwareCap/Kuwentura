extends Node


@onready var scene1 : Node = $Scene1
@onready var scene2 : Node = $Scene2

# Scene 1
@onready var grandma : AnimatedSprite2D = $Scene1/Grandma/AnimatedSprite2D
@onready var grandma_node : Node = $Scene1/Grandma
@onready var scene1_background : Node = $Scene1/Background
@onready var book_scene : Node = $Scene1/BookScene
@onready var words_fading : AnimatedSprite2D = $Scene1/BookScene/WordsFading
@onready var book_flipping : AnimatedSprite2D = $Scene1/BookScene/BookFlipping
@onready var dialogue_box : Sprite2D = $DialogueBox
# Labels are direct children of root — always render on top
@onready var dialogue_label1 : Label = $Scene1_DialogueLabel
@onready var name_label1 : Label = $Scene1_NameLabel

# Scene 2
@onready var grandma_flip : AnimatedSprite2D = $Scene2/GrandmaFlipping/AnimatedSprite2D
@onready var grandma_light : AnimatedSprite2D = $Scene2/GrandmaLightEmerge/AnimatedSprite2D
@onready var wind_anim : AnimatedSprite2D = $Scene2/WindAnimation
@onready var dialogue_label2 : Label = $Scene2/Scene2_DialogueLabel
@onready var name_label2 : Label = $Scene2/Scene2_NameLabel

# Scene 3
@onready var scene3 : Node = $Scene3
@onready var scene3_book_glow : PointLight2D = $Scene3/Scene3_BookGlow
@onready var detective_silhouette : Node = $Scene3/DetectiveSilhouette
@onready var sidekick_silhouette : Node = $Scene3/SidekickSilhouette
@onready var players_pull : AnimatedSprite2D = $Scene3/PlayersPull
@onready var dialogue_label3 : Label = $Scene3/Scene3_DialogueLabel
@onready var name_label3 : Label = $Scene3/Scene3_NameLabel

@onready var skip_button : Button = $SkipButton


# Tunables
const DIALOGUE_SPEED : float = 0.04
const PAUSE_SHORT : float = 1.0
const FADE_DURATION : float = 1.5

# Internal state
var _skip_pressed : bool = false
var _typing_done : bool = false


func _ready() -> void:
	scene2.visible = false
	scene2.modulate.a = 0.0

	_clear_dialogue(dialogue_label1, name_label1)
	_clear_dialogue(dialogue_label2, name_label2)
	_clear_dialogue(dialogue_label3, name_label3)
	
	dialogue_box.visible = false
	players_pull.visible = false

	# BookScene and its children hidden at start
	book_scene.visible = false
	book_flipping.visible = false
	words_fading.visible = false
	wind_anim.visible = false
	grandma_light.get_parent().visible = false

	# Scene 3 hidden at start
	scene3.visible = false
	scene3.modulate.a = 0.0
	detective_silhouette.visible = false
	sidekick_silhouette.visible = false

	skip_button.visible = false
	skip_button.pressed.connect(_on_skip_pressed)

	_run_cutscene()


func _on_skip_pressed() -> void:
	_skip_pressed = true


# MAIN COROUTINE
func _run_cutscene() -> void:
	MusicController.play_track(MusicController.MusicTrack.OPENING_CUTSCENE, 1.0)
	await _scene1()
	_transition_to_scene2()
	await _scene2()
	await _transition_to_scene3()
	await _scene3()
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


# SCENE 1 – "The Story That Cannot Be Told"
func _scene1() -> void:
	# Grandma reads — BookScene still hidden
	_play_anim(grandma, "sitting_idle")
	await _say1("Grandmother", "Long ago, in a quiet village, there lived a girl named Pina…")
	await _say1_auto("Grandmother", "She was known for—", 1.0)

	# BookScene fades in smoothly, WordsFading plays on top
	book_scene.visible = true
	book_scene.modulate.a = 0.0
	words_fading.visible = true
	_play_anim(words_fading, "words_fading")
	await _fade_node(book_scene, 1.0)

	# Grandma reacts to the fading words
	await _say1_auto("Grandmother", "Hmm… that's strange…", 1.2)
	await _say1_auto("Grandmother", "Wait… the words… they're disappearing.", 1.2)

	# WordsFading disappears, BookFlipping takes over, Grandma hides
	words_fading.visible = false
	_set_flipping_mode(true)
	await _say1("Grandmother", "No… no… this can't be happening.")
	await _say1("Grandmother", "How can I tell the story if the words are gone?")

	_clear_dialogue(dialogue_label1, name_label1)


# TRANSITION Scene 1 → Scene 2
func _transition_to_scene2() -> void:
	skip_button.visible = false

	# Hide scene1 characters and book, keep background visible
	grandma_node.visible  = false
	book_flipping.visible = false
	book_scene.visible = false

	# Show scene2 immediately on top of scene1 background — no fade
	scene2.visible = true
	scene2.modulate.a = 1.0


# SCENE 2 – "The Book Awakens"
func _scene2() -> void:
	# GrandmaFlipping plays over scene1 background (still visible)
	_play_anim(grandma_flip, "sitting_flipping")
	await _say2_auto("Grandmother", "What is happening to this book?", 1.2)
	await _say2("Grandmother", "The story is fading.")

	# GrandmaFlipping hides, GrandmaLightEmerge takes over
	grandma_flip.get_parent().visible  = false
	grandma_light.get_parent().visible = true
	_play_anim(grandma_light, "sitting_light")
	await _say2_auto("Grandmother", "If the story disappears…", 1.2)

	# WindAnimation starts automatically — hides scene1 background instantly
	scene1_background.visible = false
	wind_anim.visible = true
	_play_anim(wind_anim, "wind_swirling")
	await _say2_auto("Grandmother", "The legend will be lost forever.", 1.0)

	_clear_dialogue(dialogue_label2, name_label2)


# TRANSITION  Scene 2 → Scene 3
func _transition_to_scene3() -> void:
	skip_button.visible = false

	# Fade out scene2 and dialogue box together BEFORE clearing
	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(scene2, "modulate:a", 0.0, FADE_DURATION)
	fade_out.tween_property(dialogue_box, "modulate:a", 0.0, FADE_DURATION)
	await fade_out.finished

	# Clear after fade so labels don't pop off visibly
	_clear_dialogue(dialogue_label2, name_label2)
	scene2.visible = false
	dialogue_box.visible = false

	# Fade in scene3 and restore dialogue box alpha
	scene3.visible = true
	await _fade_node(scene3, 1.0)


# SCENE 3 – "The Glowing Light Expands"
func _scene3() -> void:
	# Book glow expands via PointLight2D energy tween
	scene3_book_glow.energy = 0.0
	var glow_tw := create_tween()
	glow_tw.tween_property(scene3_book_glow, "energy", 3.0, 1.5)
	await _wait(0.8)

	# Detective and Sidekick silhouettes fade in together
	detective_silhouette.visible = true
	sidekick_silhouette.visible = true
	detective_silhouette.modulate.a = 0.0
	sidekick_silhouette.modulate.a  = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(detective_silhouette, "modulate:a", 1.0, 1.0)
	tw.tween_property(sidekick_silhouette,  "modulate:a", 1.0, 1.0)
	await tw.finished

	await _say3_auto("", "Only those who seek the truth can restore the lost story.", 1.5)
	await _say3_auto("", "The legend of Pina has been forgotten.", 1.5)
	await _say3_auto("", "Find the truth behind her disappearance.", 1.5)
	await _say3("", "Restore the missing pieces of the tale.")
	
	_clear_dialogue(dialogue_label3, name_label3)
	players_pull.visible = true
	_play_anim(players_pull, "players_pull")
	await _wait(players_pull.sprite_frames.get_frame_count("players_pull") * (1.0 / players_pull.sprite_frames.get_animation_speed("players_pull")))
	# Environment dissolves to white before loading next scene
	var dissolve := create_tween()
	dissolve.tween_property(scene3, "modulate:a", 0.0, 2.0)
	await dissolve.finished

	_clear_dialogue(dialogue_label3, name_label3)


# HELPERS

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
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", target_alpha, FADE_DURATION)
	await tw.finished


func _set_flipping_mode(flipping: bool) -> void:
	grandma_node.visible  = not flipping
	book_flipping.visible = flipping
	if flipping:
		_play_anim(book_flipping, "book_flipping")
	else:
		_play_anim(grandma, "sitting_idle")


func _play_anim(sprite: AnimatedSprite2D, anim: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


# Delta accumulator typewriter — no SceneTreeTimer objects spawned per character
func _say(dlabel: Label, nlabel: Label, speaker: String, text: String) -> void:
	_skip_pressed = false
	_typing_done  = false
	nlabel.text = speaker
	dlabel.text = ""
	
	dialogue_box.modulate.a = 1.0
	dialogue_box.visible = true
	skip_button.text = "Skip"
	skip_button.visible = true

	var char_index : int = 0
	var elapsed : float = 0.0
	var length : int = text.length()

	while char_index <= length:
		if _skip_pressed:
			dlabel.text = text
			_skip_pressed = false
			break
		elapsed += get_process_delta_time()
		if elapsed >= DIALOGUE_SPEED:
			elapsed -= DIALOGUE_SPEED
			char_index += 1
			dlabel.text = text.substr(0, char_index)
		await get_tree().process_frame

	_typing_done = true
	skip_button.text = "Click to continue..."
	_skip_pressed = false

	while not _skip_pressed:
		await get_tree().process_frame

	dialogue_box.visible = false
	skip_button.visible = false
	_skip_pressed = false


# Reusable wait using delta — no SceneTreeTimer objects spawned
func _wait(seconds: float) -> void:
	var elapsed : float = 0.0
	while elapsed < seconds:
		elapsed += get_process_delta_time()
		await get_tree().process_frame


# Auto-advancing version of _say — no button press required
func _say_auto(dlabel: Label, nlabel: Label, speaker: String, text: String, hold: float) -> void:
	_skip_pressed = false
	nlabel.text = speaker
	dlabel.text = ""
	
	dialogue_box.modulate.a = 1.0
	dialogue_box.visible = true
	skip_button.visible = false

	var char_index : int = 0
	var elapsed : float = 0.0
	var length : int = text.length()

	while char_index <= length:
		elapsed += get_process_delta_time()
		if elapsed >= DIALOGUE_SPEED:
			elapsed -= DIALOGUE_SPEED
			char_index += 1
			dlabel.text = text.substr(0, char_index)
		await get_tree().process_frame

	# Auto-advance after hold duration
	await _wait(hold)


func _clear_dialogue(dlabel: Label, nlabel: Label) -> void:
	dlabel.text = ""
	nlabel.text = ""
