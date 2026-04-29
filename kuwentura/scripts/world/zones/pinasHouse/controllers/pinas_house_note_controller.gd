extends RefCounted

## Note Controller - Manages the hidden number note puzzle for Pina's House.

const FONT_SIZE_PUZZLE: int = 42
const FONT_SIZE_SOLVED: int = 34

var zone: Node


func setup(owner: Node) -> void:
	zone = owner

	for board in [zone.detective_board, zone.sidekick_board]:
		if is_instance_valid(board):
			board.visible = false

	for btn_node in [zone.detective_close, zone.sidekick_close]:
		if is_instance_valid(btn_node) and not btn_node.pressed.is_connected(zone._close_boards):
			btn_node.pressed.connect(zone._close_boards.bind(true))
			btn_node.pressed.connect(_on_board_closed)

	if is_instance_valid(zone.note_btn):
		zone.note_btn.visible = false
		zone.note_btn.disabled = true

	if is_instance_valid(zone.sidekick_board) and zone.sidekick_board.has_signal("solved"):
		if not zone.sidekick_board.solved.is_connected(zone._on_sidekick_solved):
			zone.sidekick_board.solved.connect(zone._on_sidekick_solved)

	apply_close_button_visibility()
	apply_note_interaction_gate()

	if zone._puzzle_data_ready:
		apply_unsolved_text()
		if zone.has_method("_refresh_note_puzzle_views"):
			zone._refresh_note_puzzle_views()


func on_note_interacted() -> void:
	if not zone._note_phase_active and not zone._note_solved:
		return

	if not zone._puzzle_data_ready:
		zone.show_notification("Puzzle data is still syncing...", 1.5)
		return
	
	close_boards(true)

	var will_play_note_dialogue := false
	if not zone._note_dialogue_played and not zone._note_solved:
		zone._note_dialogue_played = true
		will_play_note_dialogue = true

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
			if zone._note_solved:
				if zone.sidekick_board.has_method("apply_solved_view"):
					zone.sidekick_board.apply_solved_view()
			else:
				if zone.has_method("_refresh_note_puzzle_views"):
					zone._refresh_note_puzzle_views()
				_apply_sidekick_board_input_state()

	if will_play_note_dialogue:
		await zone._play_locked_dialogue("pinas_house_note_clicked", DialogueLibraries.PINAS_HOUSE_NOTE_CLICKED)

	if zone._note_phase_active and not zone._note_solved:
		zone.show_notification("Use the ledger to solve the equation.", 0.0)
		zone.pulse_ledger_guidance(true)
	else:
		zone.hide_notification()
		zone.pulse_ledger_guidance(false)

	if GameState.local_role == GameState.Role.SIDEKICK:
		_apply_sidekick_board_input_state()

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
	_apply_sidekick_board_input_state()


func close_boards(force: bool = false) -> void:
	if not force:
		return
	for board in [zone.detective_board, zone.sidekick_board]:
		if is_instance_valid(board):
			board.visible = false


func apply_close_button_visibility() -> void:
	var show_close: bool = zone._note_solved
	for btn_node in [zone.detective_close, zone.sidekick_close]:
		if is_instance_valid(btn_node):
			btn_node.visible = show_close


func apply_unsolved_text() -> void:
	if not is_instance_valid(zone.detective_text):
		return
	var equation: String = str(zone._puzzle_data.get("equation", "x = ?"))
	zone.detective_text.text = "HIDDEN NUMBER NOTE\n\nSolve the equation:\n" + equation
	zone.detective_text.add_theme_font_size_override("font_size", FONT_SIZE_PUZZLE)


func apply_solved_text() -> void:
	if not is_instance_valid(zone.detective_text):
		return
	zone.detective_text.text = (
		"Where pots and pans quietly stay,\n"
		+ "A hidden clue now waits your way.\n"
		+ "Open the cabinet and you will see,\n"
		+ "The next secret of Pina's mystery."
	)
	zone.detective_text.add_theme_font_size_override("font_size", FONT_SIZE_SOLVED)


func on_sidekick_solved() -> void:
	zone._note_solved = true
	zone._ledger_hint_shown = false
	zone.hide_notification()
	zone.pulse_ledger_guidance(false)
	zone.broadcast_pinas_house_solved()


func after_note_solved() -> void:
	zone._note_phase_active = false
	zone._cabinet_phase_active = true
	zone._ledger_hint_shown = false

	apply_solved_text()
	_show_boards_solved()
	apply_close_button_visibility()
	zone.pulse_ledger_guidance(false)
	zone._enable_cabinet_interaction()

	# Hide players before dialogue
	zone._update_player_visibility(false)

	if zone.multiplayer.is_server():
		await zone._play_locked_dialogue("pinas_house_riddle_reveal", DialogueLibraries.PINAS_HOUSE_RIDDLE_REVEAL)
	else:
		zone._set_dialogue_input_lock(true)
		DialogueSystem.play("pinas_house_riddle_reveal", DialogueLibraries.PINAS_HOUSE_RIDDLE_REVEAL)
		await DialogueSystem.wait_finished("pinas_house_riddle_reveal")
		zone._set_dialogue_input_lock(false)
		if is_instance_valid(zone.sidekick_board):
			zone.sidekick_board.visible = true
			if zone.sidekick_board.has_method("apply_solved_view"):
				zone.sidekick_board.apply_solved_view()

	# Show players again after dialogue
	zone._update_player_visibility(true)
	zone.show_notification("Search where the clue is hidden.", 5.0)


func apply_note_interaction_gate() -> void:
	var can_interact: bool = zone._note_phase_active or zone._note_solved
	if is_instance_valid(zone.note_area):
		zone.note_area.input_pickable = can_interact
	if is_instance_valid(zone.note_collision):
		zone.note_collision.disabled = not can_interact
	if is_instance_valid(zone.note_btn):
		zone.note_btn.disabled = true
		zone.note_btn.visible = false


func _show_boards_solved() -> void:
	if is_instance_valid(zone.detective_board):
		zone.detective_board.visible = true
	if is_instance_valid(zone.sidekick_board):
		zone.sidekick_board.visible = true
		if zone.sidekick_board.has_method("apply_solved_view"):
			zone.sidekick_board.apply_solved_view()


func _apply_sidekick_board_input_state() -> void:
	if not is_instance_valid(zone.sidekick_board):
		return
	var can_input: bool = zone._note_phase_active and zone._detective_note_seen and not zone._note_solved
	if zone.sidekick_board.has_method("set_inputs_enabled"):
		zone.sidekick_board.set_inputs_enabled(can_input)
	if zone.sidekick_board.has_method("set_puzzle_inputs_visible"):
		zone.sidekick_board.set_puzzle_inputs_visible(not zone._note_solved)
	if zone._note_solved and zone.sidekick_board.has_method("apply_solved_view"):
		zone.sidekick_board.apply_solved_view()


func _on_board_closed() -> void:
	if zone._cabinet_phase_active and not zone._reward_active:
		zone.show_notification("Search where the clue is hidden.", 5.0)
