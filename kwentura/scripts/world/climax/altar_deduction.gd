extends Node2D

@onready var deduction_board = $DeductionBoard
@onready var clue_slots = $ClueSlots
@onready var final_text_display = $FinalTextDisplay

var placed_clues: Dictionary = {}
var required_clues = ["Ladle", "Pineapple_Sapling", "Eye_Symbol", "Wish_Scroll", "Tiara"]


func _ready():
	_setup_deduction_board()
	_populate_clues()
	_check_if_all_clues_present()


func _setup_deduction_board():
	# Create 5 slots for the clues
	for i in range(5):
		var slot = preload("res://scenes/ui/ClueSlot.tscn").instantiate()
		slot.position = Vector2(100 + i * 150, 300)
		slot.clue_id = required_clues[i]
		slot.clue_placed.connect(_on_clue_placed)
		clue_slots.add_child(slot)


func _populate_clues():
	# Show collected clues from GameState
	for zone_id in GameState.collected_clues.keys():
		var clue_data = GameState.collected_clues[zone_id]
		if clue_data.collected:
			var clue_icon = preload("res://scenes/ui/ClueIcon.tscn").instantiate()
			clue_icon.setup(clue_data.item, clue_data.text)
			$AvailableClues.add_child(clue_icon)


func _on_clue_placed(clue_id: String, slot_id: String):
	placed_clues[slot_id] = clue_id
	AudioManager.play_sfx("clue_place")

	if placed_clues.size() == 5:
		_reveal_truth()


func _reveal_truth():
	# Animate the final deduction
	var story_text = """
	The Truth Revealed:
    
	Pina was raised like a princess (Tiara),
	never using her own eyes (Eye Symbol).
	She searched for the ladle (Ladle)
	when her mother's wish (Wish Scroll)
	transformed her into a pineapple (Pineapple).
    
	"Gamitin ang sariling mata sa paghahanap,
	huwag laging iasa sa bibig at sa iba."
	"""

	final_text_display.text = story_text
	final_text_display.show()

	# Typewriter effect
	await _animate_text(story_text)

	# Mark game complete
	GameState.game_completed = true
	FirebaseManager.save_progress()

	_fade_to_ending()


func _animate_text(text: String):
	final_text_display.text = ""
	for i in text.length():
		final_text_display.text = text.substr(0, i)
		await get_tree().create_timer(5.0).timeout


func _fade_to_ending():
	# Fade out altar scene
	var fade = $FadeRect
	var tween = create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 1), 2.0)
	await tween.finished

	# Change to ending cutscene
	get_tree().change_scene_to_file("res://scenes/cutscenes/EndingCutscene.tscn")
