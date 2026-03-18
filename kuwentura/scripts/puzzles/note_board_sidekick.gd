extends Control

@onready var equation: Label = $SidekickNote/Equation
@onready var x_input: LineEdit = $SidekickNote/XInput
@onready var y_input: LineEdit = $SidekickNote/YInput
@onready var submit: Button = $SidekickNote/Submit
@onready var feedback: Label = $SidekickNote/Feedback

signal solved

var puzzle_data: Dictionary = {}
var equation_text: String = ""
var solution_x: int = 0
var riddle_text: String = ""


func _ready() -> void:
	puzzle_data = PuzzleManager.get_puzzle_for_zone("pinas_house")
	equation_text = str(puzzle_data.get("equation", "x = ?"))
	solution_x = int(puzzle_data.get("solution", 0))
	riddle_text = str(puzzle_data.get("riddle", ""))

	apply_puzzle_view()

	var is_sidekick: bool = GameState.local_role == GameState.Role.SIDEKICK
	x_input.editable = is_sidekick
	submit.disabled = not is_sidekick

	y_input.visible = false
	y_input.editable = false

	if not submit.pressed.is_connected(_on_submit_pressed):
		submit.pressed.connect(_on_submit_pressed)

	if get_tree().current_scene._note_solved:
		apply_solved_view()


func open_board() -> void:
	feedback.text = ""

	if get_tree().current_scene._note_solved:
		apply_solved_view()
		return

	apply_puzzle_view()
	x_input.text = ""
	x_input.placeholder_text = "Answer"

	if GameState.local_role == GameState.Role.SIDEKICK and x_input.visible and x_input.editable:
		x_input.grab_focus()


func _on_submit_pressed() -> void:
	var scene = get_tree().current_scene
	if scene and "_dialogue_input_locked" in scene and scene._dialogue_input_locked:
		return

	_check_answer()


func _check_answer() -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		return

	var x_txt: String = x_input.text.strip_edges()

	if x_txt.is_empty():
		feedback.text = "Enter your answer first."
		return

	if not x_txt.is_valid_int():
		feedback.text = "Numbers only, sidekick. Try again."
		if get_tree().current_scene.has_method("rpc_request_penalty"):
			get_tree().current_scene.rpc_request_penalty.rpc_id(1, "numbers_only")
		return

	var x_val: int = int(x_txt)

	if x_val == solution_x:
		feedback.text = "Correct!"
		x_input.editable = false
		submit.disabled = true
		emit_signal("solved")
	else:
		feedback.text = "That’s not the right answer yet. Try again."
		if get_tree().current_scene.has_method("rpc_request_penalty"):
			get_tree().current_scene.rpc_request_penalty.rpc_id(1, "wrong_answer")


func apply_puzzle_view() -> void:
	x_input.visible = true
	y_input.visible = false
	submit.visible = true

	equation.text = (
		"HIDDEN NUMBER NOTE\n\n"
		+ "Solve the equation:\n"
		+ equation_text
		+ "\n\nx = ______"
	)
	equation.add_theme_font_size_override("font_size", 42)

	feedback.text = ""


func apply_solved_view() -> void:
	x_input.visible = false
	y_input.visible = false
	submit.visible = false

	equation.text = (
		"Where pots and pans quietly stay,\n"
		+ "A hidden clue now waits your way.\n"
		+ "Open the cabinet and you will see,\n"
		+ "The next secret of Pina’s mystery."
	)
	equation.add_theme_font_size_override("font_size", 34)

	feedback.text = ""


func set_inputs_enabled(enabled: bool) -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		return

	if get_tree().current_scene._note_solved:
		return

	x_input.editable = enabled
	submit.disabled = not enabled


func set_puzzle_inputs_visible(show_inputs: bool) -> void:
	if get_tree().current_scene._note_solved:
		x_input.visible = false
		y_input.visible = false
		submit.visible = false
		return

	x_input.visible = show_inputs
	y_input.visible = false
	submit.visible = show_inputs

	if show_inputs and GameState.local_role == GameState.Role.SIDEKICK and x_input.editable:
		x_input.grab_focus()
