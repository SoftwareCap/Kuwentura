extends Node2D

@onready var storybook_sprite = $StorybookSprite
@onready var text_label = $TextLabel
@onready var fade_rect = $FadeRect
@onready var animation_player = $AnimationPlayer

var story_texts = [
	"Grandmother's ancient storybook is fading...",
	"Text vanishes from the pages of Alamat ng Pinya.",
	"The legend of Pina is being forgotten.",
	"You are pulled into the monochromatic world...",
	"Find the truth behind Pina's disappearance.",
	"Use your eyes. Trust your partner."
]


func _ready():
	_play_cutscene()


func _play_cutscene():
	# Fade in from black
	fade_rect.color = Color.BLACK
	var tween = create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 2.0)
	await tween.finished

	# Animate storybook fading
	var book_tween = create_tween()
	book_tween.set_loops(3)
	book_tween.tween_property(storybook_sprite, "modulate", Color(0.5, 0.5, 0.5, 0.3), 1.5)
	book_tween.tween_property(storybook_sprite, "modulate", Color(1, 1, 1, 1), 0.5)

	# Display text sequence
	for text in story_texts:
		text_label.text = ""
		await _typewriter_text(text)
		await get_tree().create_timer(2.0).timeout

	# Transition to game
	_transition_to_game()


func _typewriter_text(text: String):
	var tween = create_tween()
	for i in range(text.length()):
		text_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(0.05).timeout


func _transition_to_game():
	var tween = create_tween()
	tween.tween_property(fade_rect, "color", Color.BLACK, 2.0)
	await tween.finished

	# Cutscene complete - transition to game
	# Note: Game should already be started by host before cutscene plays
	
	# Change to Forest Hub (starting point)
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
