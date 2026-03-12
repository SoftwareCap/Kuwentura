extends Node2D

## Backyard Path - Test zone with position save/restore

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton

var clue_collected: bool = false

@onready var pina_spirit = $RoleLayer/Control/DetectiveOverlays/Pina
@onready var pineapple = $RoleLayer/Control/SidekickOverlays/PineapplePlant

@onready var input_field = $PuzzleBoard/LineEdit
@onready var submit_button = $PuzzleBoard/SubmitButton
@onready var feedback = $PuzzleBoard/FeedbackLabel

@onready var fog = $FogOverlay

var max_time = 300
var remaining_time = 300

var darkness = 0.0

var puzzle_data : Dictionary
var solution : int

func _ready():
	print("[BackyardPath] Scene loaded!")
	
	puzzle_data = PuzzleManager.get_puzzle("backyard_path")
	
	start_timer()

	solution = puzzle_data["solution"]

	var spirit_height = puzzle_data["spirit_height"]
	var plant_dali = puzzle_data["plant_dali"]

	$PuzzleBoard/HeightLabel.text = str(plant_dali) + " Dali"
	
	var role_text = "Unknown"
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"
	
	role_label.text = "Role: " + role_text
	print("[BackyardPath] Local role: ", role_text, " | Peer ID: ", multiplayer.get_unique_id())
	
	if GameState.local_role == GameState.Role.DETECTIVE:
		input_field.editable = false
		submit_button.disabled = true
	
	var saved_pos = GameState.get_spawn_position(multiplayer.get_unique_id())
	if saved_pos != Vector2.ZERO:
		print("[BackyardPath] Will return to Forest Hub at position: ", saved_pos)
	
	GameState.clue_collected.connect(_on_clue_collected)

func setup_role_visibility():

	match GameState.local_role:

		GameState.Role.DETECTIVE:
			pina_spirit.visible = true
			pineapple.visible = false

		GameState.Role.SIDEKICK:
			pina_spirit.visible = false
			pineapple.visible = true


func _on_back_pressed():
	print("[BackyardPath] Returning to Forest Hub...")
	_return_to_forest()


func _on_clue_collected(zone_id: String, _clue_data: Dictionary):
	if zone_id == "backyard_path" and not clue_collected:
		clue_collected = true
		print("[BackyardPath] Clue collected! Auto-returning in 3 seconds...")
		role_label.text = "Clue collected! Returning..."
		await get_tree().create_timer(3.0).timeout
		_return_to_forest()

func _on_submit_pressed():

	var answer = input_field.text.strip_edges()

	if not answer.is_valid_int():
		DialogueSystems.play("backyard_invalid",
		[
			{"speaker":"detective","text":"Answers should only be in numbers."},
			{"speaker":"detective","text":"Let's try again."}
		])
		apply_wrong_penalty()
		return

	var value = int(answer)

	if value == solution:
		solve_puzzle()

	else:
		feedback.text = "Incorrect!"
		apply_wrong_penalty()

func solve_puzzle():

	print("Puzzle solved!")

	GameState.mark_puzzle_solved("backyard_path")

	GameState.emit_clue_collected(
		"backyard_path",
		{
			"name":"Pina's Fate",
			"description":"Pina has become the pineapple plant."
		}
	)

func start_timer():

	while remaining_time > 0:

		await get_tree().create_timer(1.0).timeout

		remaining_time -= 1

		var progress = 1.0 - float(remaining_time) / float(max_time)

		fog.modulate.a = progress * 0.7

	if remaining_time <= 0:
		kick_player_out()
		
func apply_wrong_penalty():

	darkness += 0.1
	remaining_time -= 30

	if darkness > 1.0:
		darkness = 1.0

	fog.modulate.a = darkness
	
func kick_player_out():

	print("Players took too long. Tikbalang fog consumed the area.")

	DialogueSystems.play("fog_fail",
	[
		{"speaker":"narrator","text":"The fog grows too thick..."},
		{"speaker":"narrator","text":"You can no longer see anything."}
	])

	await get_tree().create_timer(3).timeout

	_return_to_forest()

func _on_board_path_button_pressed():
	$PuzzleBoard.visible = true

func _return_to_forest():
	print("[BackyardPath] Teleporting back to Forest Hub")
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
