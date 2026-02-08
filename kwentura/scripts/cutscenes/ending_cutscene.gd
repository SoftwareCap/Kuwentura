extends Node2D

@onready var storybook = $StorybookSprite
@onready var text_label = $TextLabel
@onready var fade_rect = $FadeRect
@onready var animation_player = $AnimationPlayer

var ending_texts = [
	"The story of Pina has been restored...",
	"Her fate sealed in the pages of legend.",
	"A lesson written in pineapple and tears:",
	"Use your own eyes when looking for something,",
	"instead of relying on your mouth and others.",
	"",
	"The book closes...",
	"But the story lives on."
]


func _ready():
	_play_ending_sequence()


func _play_ending_sequence():
	# Start with book open (faded in)
	fade_rect.color = Color(0, 0, 0, 0)
	storybook.frame = 0  # Open book frame
	storybook.modulate = Color(1, 1, 1, 0)

	# Fade in book
	var fade_in = create_tween()
	fade_in.tween_property(storybook, "modulate", Color(1, 1, 1, 1), 2.0)
	await fade_in.finished

	# Show text lines one by one
	for text in ending_texts:
		await _show_text(text)
		await get_tree().create_timer(2.0).timeout

	# Close the book animation
	await _close_book()

	# Transition to post-game lobby
	_go_to_post_game_lobby()


func _show_text(text: String):
	text_label.text = ""

	if text.is_empty():
		return

	# Typewriter effect
	for i in range(text.length()):
		text_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(0.05).timeout


func _close_book():
	# Animate book closing (sprite animation or tween)
	var close_tween = create_tween()

	# Scale down to simulate closing
	close_tween.tween_property(storybook, "scale", Vector2(0.1, 0.8), 1.5)
	close_tween.parallel().tween_property(storybook, "rotation_degrees", -5, 1.5)
	close_tween.parallel().tween_property(storybook, "modulate", Color(0.6, 0.6, 0.6, 1), 1.5)

	# Play closing sound
	AudioManager.play_sfx("book_close")

	await close_tween.finished

	# Hold on closed book for a moment
	await get_tree().create_timer(1.5).timeout

	# Fade to black
	var fade_out = create_tween()
	fade_out.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 2.0)
	await fade_out.finished


func _go_to_post_game_lobby():
	# Mark game as completed
	GameState.game_completed = true
	FirebaseManager.save_progress()

	# Change to post-game lobby
	get_tree().change_scene_to_file("res://scenes/mainMenu/PostGameLobby.tscn")

# Alternative book closing

#func _animate_book_close():
#var book = $StorybookSprite
#
## Phase 1: Pages flutter (rapid scale x changes)
#var flutter = create_tween()
#flutter.set_loops(5)
#flutter.tween_property(book, "scale:x", 0.9, 0.1)
#flutter.tween_property(book, "scale:x", 1.0, 0.1)
#
#await flutter.finished
#
## Phase 2: Close (scale x to 0, rotate slightly)
#var close = create_tween()
#close.set_parallel()
#close.tween_property(book, "scale:x", 0.05, 1.0).set_ease(Tween.EASE_IN)
#close.tween_property(book, "rotation_degrees", -8, 1.0)
#close.tween_property(book, "position:y", book.position.y + 20, 1.0)
#
## Darken as it closes
#close.tween_property(book, "modulate", Color(0.4, 0.4, 0.5, 1), 1.0)
#
## Shadow grows
#var shadow = $BookShadow
#close.tween_property(shadow, "scale", Vector2(1.2, 1.2), 1.0)
#close.tween_property(shadow, "modulate:a", 0.8, 1.0)
#
#await close.finished
#
## Final "thud" effect
#AudioManager.play_sfx("book_thud")
#var thud = create_tween()
#thud.tween_property(book, "position:y", book.position.y + 5, 0.05)
#thud.tween_property(book, "position:y", book.position.y - 5, 0.1)
