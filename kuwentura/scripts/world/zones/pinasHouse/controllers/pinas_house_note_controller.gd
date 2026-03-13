extends RefCounted

var zone

func setup(owner) -> void:
	zone = owner

	if is_instance_valid(zone.detective_board):
		zone.detective_board.visible = false

	if is_instance_valid(zone.sidekick_board):
		zone.sidekick_board.visible = false

	if is_instance_valid(zone.detective_close):
		if not zone.detective_close.pressed.is_connected(zone._close_boards):
			zone.detective_close.pressed.connect(zone._close_boards.bind(true))

	if is_instance_valid(zone.sidekick_close):
		if not zone.sidekick_close.pressed.is_connected(zone._close_boards):
			zone.sidekick_close.pressed.connect(zone._close_boards.bind(true))

	if is_instance_valid(zone.note_btn):
		if not zone.note_btn.pressed.is_connected(zone._on_note_pressed):
			zone.note_btn.pressed.connect(zone._on_note_pressed)

	if is_instance_valid(zone.sidekick_board) and zone.sidekick_board.has_signal("solved"):
		if not zone.sidekick_board.solved.is_connected(zone._on_sidekick_solved):
			zone.sidekick_board.solved.connect(zone._on_sidekick_solved)

	apply_unsolved_text()
	apply_close_button_visibility()
	apply_note_interaction_gate()

	if is_instance_valid(zone.sidekick_board) and zone.sidekick_board.has_method("apply_puzzle_view"):
		zone.sidekick_board.apply_puzzle_view()

func on_note_pressed() -> void:
	on_note_interacted()

func on_note_interacted() -> void:
	if not zone._note_phase_active and not zone._note_solved:
		return

	close_boards(true)

	var will_play_note_dialogue := false
	if not zone._note_dialogue_played:
		zone._note_dialogue_played = true
		will_play_note_dialogue = true
		DialogueSystems.play("pinas_house_note_clicked", DialogueLibraries.PINAS_HOUSE_NOTE_CLICKED)

	if GameState.local_role == GameState.Role.DETECTIVE:
		if is_instance_valid(zone.detective_board):
			zone.detective_board.visible = true

		if zone._note_solved:
			apply_solved_text()
		else:
			apply_unsolved_text()

		mark_detective_note_seen()

	elif GameState.local_role == GameState.Role.SIDEKICK:
		if is_instance_valid(zone.sidekick_board):
			zone.sidekick_board.visible = true

			if zone.sidekick_board.has_method("open_board"):
				zone.sidekick_board.open_board()

			if not zone._note_solved and zone.sidekick_board.has_method("apply_puzzle_view"):
				zone.sidekick_board.apply_puzzle_view()

			if zone.sidekick_board.has_method("set_inputs_enabled"):
				zone.sidekick_board.set_inputs_enabled(false)

			if zone.sidekick_board.has_method("set_puzzle_inputs_visible"):
				zone.sidekick_board.set_puzzle_inputs_visible(not will_play_note_dialogue)

	if will_play_note_dialogue:
		await DialogueSystems.wait_finished("pinas_house_note_clicked")

	zone.show_notification("Hint: Open the Investigation Ledger to learn how to solve this puzzle.", 3.0)
	zone.pulse_ledger_guidance(true)

	if GameState.local_role == GameState.Role.SIDEKICK and is_instance_valid(zone.sidekick_board):
		if zone.sidekick_board.has_method("set_inputs_enabled"):
			zone.sidekick_board.set_inputs_enabled(true)

		if zone.sidekick_board.has_method("set_puzzle_inputs_visible"):
			zone.sidekick_board.set_puzzle_inputs_visible(true)

	zone.apply_note_interaction_gate()
	apply_close_button_visibility()

func mark_detective_note_seen() -> void:
	if zone._detective_note_seen:
		return

	if not zone.multiplayer.has_multiplayer_peer():
		set_detective_note_seen_local(true)
		return

	if zone.multiplayer.is_server():
		set_detective_note_seen_local(true)
		zone.rpc_set_detective_note_seen.rpc(true)
	else:
		zone.rpc_request_detective_note_seen.rpc_id(zone._SERVER_PEER_ID)

func set_detective_note_seen_local(seen: bool) -> void:
	zone._detective_note_seen = seen

	if is_instance_valid(zone.sidekick_board) and zone.sidekick_board.has_method("set_inputs_enabled"):
		var can_input: bool = zone._note_phase_active and seen and not zone._note_solved
		zone.sidekick_board.set_inputs_enabled(can_input)

func close_boards(force: bool = false) -> void:
	if not force:
		return

	if is_instance_valid(zone.detective_board):
		zone.detective_board.visible = false

	if is_instance_valid(zone.sidekick_board):
		zone.sidekick_board.visible = false

func apply_close_button_visibility() -> void:
	var show_close: bool = zone._note_solved

	if is_instance_valid(zone.detective_close):
		zone.detective_close.visible = show_close

	if is_instance_valid(zone.sidekick_close):
		zone.sidekick_close.visible = show_close

func apply_unsolved_text() -> void:
	var puzzle: Dictionary = PuzzleManager.get_puzzle_for_zone("pinas_house")
	var equation_text: String = str(puzzle.get("equation", "x = ?"))

	if is_instance_valid(zone.detective_text):
		zone.detective_text.text = (
			"HIDDEN NUMBER NOTE\n\n"
			+ "Solve the equation:\n"
			+ equation_text
		)
		zone.detective_text.add_theme_font_size_override("font_size", 48)

func apply_solved_text() -> void:
	if is_instance_valid(zone.detective_text):
		zone.detective_text.text = (
			"Where pots and pans quietly stay,\n"
			+ "A hidden clue now waits your way.\n"
			+ "Open the cabinet and you will see,\n"
			+ "The next secret of Pina’s mystery."
		)

		zone.detective_text.add_theme_font_size_override("font_size", 35)

func on_sidekick_solved() -> void:
	zone._note_solved = true
	zone.broadcast_pinas_house_solved()

func after_note_solved() -> void:
	zone._note_phase_active = false
	zone._cabinet_phase_active = true

	apply_solved_text()

	if is_instance_valid(zone.detective_board):
		zone.detective_board.visible = true

	if is_instance_valid(zone.sidekick_board):
		zone.sidekick_board.visible = true

		if zone.sidekick_board.has_method("apply_solved_view"):
			zone.sidekick_board.apply_solved_view()

	apply_close_button_visibility()
	zone.pulse_ledger_guidance(false)
	zone._enable_cabinet_interaction()

	# force detective text refresh again after visibility change
	apply_solved_text()

	DialogueSystems.play("pinas_house_riddle_reveal", DialogueLibraries.PINAS_HOUSE_RIDDLE_REVEAL)
	await DialogueSystems.wait_finished("pinas_house_riddle_reveal")

	zone.show_notification("Riddle revealed! Search where the clue is hidden.", 2.0)

func apply_note_interaction_gate() -> void:
	var can_interact: bool = zone._note_phase_active or zone._note_solved

	if is_instance_valid(zone.note_area):
		zone.note_area.input_pickable = can_interact

	if is_instance_valid(zone.note_collision):
		zone.note_collision.disabled = not can_interact

	if is_instance_valid(zone.note_btn):
		zone.note_btn.disabled = not can_interact
