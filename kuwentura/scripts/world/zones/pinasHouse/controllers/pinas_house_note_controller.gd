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
			zone.detective_close.pressed.connect(zone._close_boards)

	if is_instance_valid(zone.sidekick_close):
		if not zone.sidekick_close.pressed.is_connected(zone._close_boards):
			zone.sidekick_close.pressed.connect(zone._close_boards)

	if is_instance_valid(zone.note_btn):
		if not zone.note_btn.pressed.is_connected(zone._on_note_pressed):
			zone.note_btn.pressed.connect(zone._on_note_pressed)

	if is_instance_valid(zone.sidekick_board) and zone.sidekick_board.has_signal("solved"):
		if not zone.sidekick_board.solved.is_connected(zone._on_sidekick_solved):
			zone.sidekick_board.solved.connect(zone._on_sidekick_solved)

	# IMPORTANT: Puzzle 1 state must use zone._note_solved, NOT GameState
	if zone._note_solved:
		apply_solved_text()

		if is_instance_valid(zone.sidekick_board) and zone.sidekick_board.has_method("apply_solved_view"):
			zone.sidekick_board.apply_solved_view()

		zone.tool_hunt_controller.set_tools_unlocked_local(true)

	else:
		apply_unsolved_text()
		zone.tool_hunt_controller.set_tools_unlocked_local(false)

		# Ensure sidekick board starts in puzzle mode
		if is_instance_valid(zone.sidekick_board):
			if zone.sidekick_board.has_method("apply_puzzle_view"):
				zone.sidekick_board.apply_puzzle_view()

	apply_close_button_visibility()
	apply_note_interaction_gate()


func on_note_pressed() -> void:
	on_note_interacted()


func on_note_interacted() -> void:
	if zone._search_mode:
		return

	close_boards()

	var will_play_note_dialogue := false
	if not zone._note_dialogue_played:
		zone._note_dialogue_played = true
		will_play_note_dialogue = true
		DialogueSystems.play("pinas_house_note_clicked", DialogueLibraries.PINAS_HOUSE_NOTE_CLICKED)

	if GameState.local_role == GameState.Role.DETECTIVE:
		if is_instance_valid(zone.detective_board):
			zone.detective_board.visible = true

		mark_detective_note_seen()

		if zone._note_solved:
			apply_solved_text()
		else:
			apply_unsolved_text()

	elif GameState.local_role == GameState.Role.SIDEKICK:

		if is_instance_valid(zone.sidekick_board):
			zone.sidekick_board.visible = true

			if zone.sidekick_board.has_method("open_board"):
				zone.sidekick_board.open_board()

			# Force puzzle mode if puzzle not solved
			if not zone._note_solved:
				if zone.sidekick_board.has_method("apply_puzzle_view"):
					zone.sidekick_board.apply_puzzle_view()

		if zone.sidekick_board.has_method("set_inputs_enabled"):
			zone.sidekick_board.set_inputs_enabled(zone._detective_note_seen)

		if will_play_note_dialogue and zone.sidekick_board.has_method("set_puzzle_inputs_visible"):
			zone.sidekick_board.set_puzzle_inputs_visible(false)

		if will_play_note_dialogue:
			await zone.get_tree().create_timer(3.0, true).timeout

			if DialogueSystems.has_method("stop"):
				DialogueSystems.stop()

			if zone.sidekick_board.has_method("set_puzzle_inputs_visible"):
				zone.sidekick_board.set_puzzle_inputs_visible(true)
		else:
			if zone.sidekick_board.has_method("set_puzzle_inputs_visible"):
				zone.sidekick_board.set_puzzle_inputs_visible(true)

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
		zone.sidekick_board.set_inputs_enabled(zone._detective_note_seen)


func close_boards(force: bool = false) -> void:
	if not force and not zone._search_mode:
		return

	if is_instance_valid(zone.detective_board):
		zone.detective_board.visible = false

	if is_instance_valid(zone.sidekick_board):
		zone.sidekick_board.visible = false


func apply_close_button_visibility() -> void:
	if is_instance_valid(zone.detective_close):
		zone.detective_close.visible = zone._search_mode

	if is_instance_valid(zone.sidekick_close):
		zone.sidekick_close.visible = zone._search_mode


func apply_unsolved_text() -> void:
	var p := PuzzleManager.get_puzzle_for_zone("pinas_house")
	var eqs: Array = p.get("equations", [])
	var txt := "COOKING TOOLS INVENTORY \n\n"

	for e in eqs:
		txt += str(e) + "\n"

	if is_instance_valid(zone.detective_text):
		zone.detective_text.text = txt


func apply_solved_text() -> void:
	var p := PuzzleManager.get_puzzle_for_zone("pinas_house")
	var sol: Dictionary = p.get("solution", {})

	var x := int(sol.get("x", 0))
	var y := int(sol.get("y", 0))
	var z := int(sol.get("z", 0))

	if is_instance_valid(zone.detective_text):
		zone.detective_text.text = (
			"COOKING TOOLS INVENTORY \n\n"
			+ "Pot (z) = %d\nPan (y) = %d\nLadle (x) = %d" % [z, y, x]
		)


func on_sidekick_solved() -> void:
	# Mark puzzle 1 solved locally
	zone._note_solved = true

	zone.rpc_pinas_house_solved.rpc()


func after_puzzle1_solved() -> void:
	apply_solved_text()

	if is_instance_valid(zone.sidekick_board) and zone.sidekick_board.has_method("apply_solved_view"):
		zone.sidekick_board.apply_solved_view()

	# Unlock tool hunt
	zone.tool_hunt_controller.set_tools_unlocked_local(true)

	if is_instance_valid(zone.search_btn_detective):
		zone.search_btn_detective.visible = false

	if is_instance_valid(zone.search_btn_sidekick):
		zone.search_btn_sidekick.visible = false

	DialogueSystems.play(
		"pinas_house_after_puzzle1",
		DialogueLibraries.PINAS_HOUSE_AFTER_PUZZLE1
	)

	await DialogueSystems.wait_finished("pinas_house_after_puzzle1")

	zone.tool_hunt_controller.setup_search_room_buttons()


func apply_note_interaction_gate() -> void:
	var allow_note: bool = not bool(zone._search_mode)

	if is_instance_valid(zone.note_btn):
		zone.note_btn.disabled = not allow_note
