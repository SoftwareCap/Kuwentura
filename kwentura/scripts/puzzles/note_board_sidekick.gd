extends Control

@onready var equation: Label = $SidekickNote/Equation
@onready var x_input: LineEdit = $SidekickNote/XInput
@onready var y_input: LineEdit = $SidekickNote/YInput
@onready var submit: Button = $SidekickNote/Submit
@onready var feedback: Label = $SidekickNote/Feedback

signal solved  # tells PinasHouse "correct answer was entered"

var puzzle_data: Dictionary = {}
var solution: Dictionary = {}

func _ready() -> void:
	# Deterministic randomized puzzle
	puzzle_data = PuzzleManager.get_puzzle_for_zone("pinas_house")
	solution = puzzle_data.get("solution", {})

	# Sidekick sees blanks (no equations)
	var z_val := int(solution.get("z", 0))
	equation.text = "COOKING TOOLS INVENTORY \n\nX = \nY = \nZ = %d" % z_val
	feedback.text = ""

	# Sidekick-only gate (hard lock even if UI visibility fails)
	var is_sidekick := GameState.local_role == GameState.Role.SIDEKICK
	x_input.editable = is_sidekick
	y_input.editable = is_sidekick
	submit.disabled = not is_sidekick

	# Realtime checking
	x_input.text_changed.connect(_on_realtime_changed)
	y_input.text_changed.connect(_on_realtime_changed)

	# Manual submit (no lambda)
	submit.pressed.connect(_on_submit_pressed)
	if GameState.is_puzzle_solved("pinas_house"):
			apply_solved_view()

func open_board() -> void:
	feedback.text = ""

	# If already solved, keep showing the solved values
	if GameState.is_puzzle_solved("pinas_house"):
		apply_solved_view()
		return

	x_input.text = ""
	y_input.text = ""
	if GameState.local_role == GameState.Role.SIDEKICK:
		x_input.grab_focus()

func _on_realtime_changed(_new_text: String) -> void:
	_check_answer(true)  # realtime = true

func _on_submit_pressed() -> void:
	_check_answer(false)  # realtime = false

func _check_answer(realtime: bool) -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		return

	var x_txt := x_input.text.strip_edges()
	var y_txt := y_input.text.strip_edges()

	# In realtime mode, stay quiet until they type enough
	if x_txt.is_empty() or y_txt.is_empty():
		if not realtime:
			feedback.text = "Fill in X and Y."
		return

	# Numbers-only validation
	if not x_txt.is_valid_int() or not y_txt.is_valid_int():
		if not realtime:
			feedback.text = "Numbers only."
			# Dialogue only on submit (no spam)
		get_tree().current_scene.rpc_request_validation_dialogue.rpc_id(1, "numbers_only")
		return

	var x := int(x_txt)
	var y := int(y_txt)

	var correct_x := int(solution.get("x", -999999))
	var correct_y := int(solution.get("y", -999999))

	if x == correct_x and y == correct_y:
		feedback.text = "Correct!"
		x_input.editable = false
		y_input.editable = false
		submit.disabled = true
		emit_signal("solved")
	else:
		if realtime:
			# Real-time feedback only (no dialogue spam)
			feedback.text = "Incorrect..."
		else:
			# Submit pressed → show dialogue
			feedback.text = "Incorrect. Try again."
			get_tree().current_scene.rpc_request_validation_dialogue.rpc_id(1, "wrong_answer")

func apply_solved_view() -> void:
	var z_val := int(solution.get("z", 0))
	var x_val := int(solution.get("x", 0))
	var y_val := int(solution.get("y", 0))

	# Hide inputs after solved
	x_input.visible = false
	y_input.visible = false
	submit.visible = false

	# Show solved text same as detective
	equation.text = (
		"COOKING TOOLS INVENTORY \n\n"
		+ "Pot (z) = %d\nPan (y) = %d\nLadle (x) = %d" % [z_val, y_val, x_val]
	)

	feedback.text = "Solved."

func set_inputs_enabled(enabled: bool) -> void:
	# Only affects sidekick; detective should never be able to type anyway
	if GameState.local_role != GameState.Role.SIDEKICK:
		return

	# If already solved, keep locked/hidden
	if GameState.is_puzzle_solved("pinas_house"):
		return

	x_input.editable = enabled
	y_input.editable = enabled
	submit.disabled = not enabled

func set_puzzle_inputs_visible(show_inputs: bool) -> void:
	# If already solved, keep them hidden regardless
	if GameState.is_puzzle_solved("pinas_house"):
		x_input.visible = false
		y_input.visible = false
		submit.visible = false
		return

	x_input.visible = show_inputs
	y_input.visible = show_inputs
	submit.visible = show_inputs

	# Optional: focus when showing
	if show_inputs and GameState.local_role == GameState.Role.SIDEKICK:
		x_input.grab_focus()
