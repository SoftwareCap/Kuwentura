extends Control

const FONT_SIZE_PUZZLE := 42
const FONT_SIZE_SOLVED := 34

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
	if is_instance_valid(y_input):
		y_input.visible = false
		y_input.editable = false

	if is_instance_valid(x_input):
		x_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		x_input.editable = _is_sidekick()

	if is_instance_valid(submit):
		submit.disabled = not _is_sidekick()
		if not submit.pressed.is_connected(_on_submit_pressed):
			submit.pressed.connect(_on_submit_pressed)

	if _is_solved():
		apply_solved_view()
	else:
		apply_puzzle_view()


func set_puzzle_data(new_puzzle_data: Dictionary) -> void:
	puzzle_data = new_puzzle_data.duplicate(true)
	equation_text = str(puzzle_data.get("equation", "x = ?"))
	solution_x = int(puzzle_data.get("solution", 0))
	riddle_text = str(puzzle_data.get("riddle", ""))


func set_equation_and_solution(new_equation: String, new_solution: int) -> void:
	equation_text = new_equation
	solution_x = new_solution


func set_equation(new_equation: String) -> void:
	equation_text = new_equation


func set_solution(new_solution: int) -> void:
	solution_x = new_solution


func set_answer_format(_answer_format: String) -> void:
	pass


func open_board() -> void:
	feedback.text = ""
	if _is_solved():
		apply_solved_view()
		return

	apply_puzzle_view()
	x_input.text = ""
	x_input.placeholder_text = "Answer"

	if _is_sidekick() and x_input.visible and x_input.editable:
		x_input.grab_focus()


func set_inputs_enabled(enabled: bool) -> void:
	if _is_solved():
		return
	x_input.editable = enabled and _is_sidekick()
	submit.disabled = not (enabled and _is_sidekick())


func set_puzzle_inputs_visible(show_inputs: bool) -> void:
	if _is_solved():
		apply_solved_view()
		return
	x_input.visible = show_inputs
	submit.visible = show_inputs
	if show_inputs and _is_sidekick() and x_input.editable:
		x_input.grab_focus()


func apply_puzzle_view() -> void:
	x_input.visible = true
	submit.visible = true
	equation.text = (
		"HIDDEN NUMBER NOTE\n\n"
		+ "Solve the equation:\n"
		+ equation_text
		+ "\n\nx = ______"
	)
	equation.add_theme_font_size_override("font_size", FONT_SIZE_PUZZLE)
	feedback.text = ""


func apply_solved_view() -> void:
	x_input.visible = false
	submit.visible = false
	equation.text = (
		"Where pots and pans quietly stay,\n"
		+ "A hidden clue now waits your way.\n"
		+ "Open the cabinet and you will see,\n"
		+ "The next secret of Pina's mystery."
	)
	equation.add_theme_font_size_override("font_size", FONT_SIZE_SOLVED)
	feedback.text = ""


func _on_submit_pressed() -> void:
	var scene := get_tree().current_scene
	if scene and "_dialogue_input_locked" in scene and scene._dialogue_input_locked:
		return
	_check_answer()


func _check_answer() -> void:
	if not _is_sidekick():
		return

	var x_txt := x_input.text.strip_edges()

	if x_txt.is_empty():
		feedback.text = "Enter your answer first."
		return

	if not x_txt.is_valid_int():
		feedback.text = "Numbers only, sidekick. Try again."
		_request_penalty("numbers_only")
		return

	if int(x_txt) == solution_x:
		feedback.text = "Correct!"
		x_input.editable = false
		submit.disabled = true
		solved.emit()
	else:
		feedback.text = "That's not the right answer yet. Try again."
		_request_penalty("wrong_answer")


func _is_solved() -> bool:
	var scene := get_tree().current_scene
	return scene != null and "_note_solved" in scene and scene._note_solved


func _is_sidekick() -> bool:
	return GameState.local_role == GameState.Role.SIDEKICK


func _request_penalty(reason: String) -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("rpc_request_penalty"):
		scene.rpc_request_penalty.rpc_id(1, reason)
