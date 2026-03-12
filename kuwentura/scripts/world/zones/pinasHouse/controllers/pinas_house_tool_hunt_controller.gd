extends RefCounted

var zone


func setup(owner) -> void:
	zone = owner

	set_area_pickable(zone.pan_prop, false)
	set_area_pickable(zone.ladle_prop, false)
	set_area_pickable(zone.pot_prop, false)

	if is_instance_valid(zone.pan_prop) and not zone.pan_prop.input_event.is_connected(zone._on_tool_input_event.bind("pan")):
		zone.pan_prop.input_event.connect(zone._on_tool_input_event.bind("pan"))

	if is_instance_valid(zone.ladle_prop) and not zone.ladle_prop.input_event.is_connected(zone._on_tool_input_event.bind("ladle")):
		zone.ladle_prop.input_event.connect(zone._on_tool_input_event.bind("ladle"))

	if is_instance_valid(zone.pot_prop) and not zone.pot_prop.input_event.is_connected(zone._on_tool_input_event.bind("pot")):
		zone.pot_prop.input_event.connect(zone._on_tool_input_event.bind("pot"))

	set_tools_unlocked_local(false)

	if is_instance_valid(zone.search_room_ui):
		zone.search_room_ui.visible = false

	setup_search_room_buttons()
	apply_banner_frames()

	zone._search_mode = false
	apply_tool_nodes()


func on_tool_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, tool_id: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			try_collect_tool(tool_id)
			return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			try_collect_tool(tool_id)
			return


func try_collect_tool(tool_id: String) -> void:
	if not zone._tools_unlocked:
		return

	if zone._tools_collected.get(tool_id, false):
		return

	if not zone.multiplayer.has_multiplayer_peer():
		server_collect_tool(tool_id, 0)
		return

	if zone.multiplayer.is_server():
		server_collect_tool(tool_id, zone.multiplayer.get_unique_id())
	else:
		zone.rpc_request_collect_tool.rpc_id(zone._SERVER_PEER_ID, tool_id)


func server_collect_tool(tool_id: String, _sender_peer_id: int) -> void:
	if not GameState.is_puzzle_solved("pinas_house"):
		return

	if not zone._TOOL_IDS.has(tool_id):
		return

	if zone._tools_collected.get(tool_id, false):
		return

	zone.rpc_set_tool_collected.rpc(tool_id)

	if all_tools_collected():
		print("All tools collected!")
		zone.rpc_show_pinas_house_reward.rpc()


func set_tool_collected_local(tool_id: String) -> void:
	zone._tools_collected[tool_id] = true
	apply_tool_nodes()
	apply_banner_frames()


func set_tools_unlocked_local(unlocked: bool) -> void:
	zone._tools_unlocked = unlocked
	apply_tool_nodes()


func setup_search_room_buttons() -> void:
	var solved: bool = zone._note_solved

	if is_instance_valid(zone.search_btn_detective):
		zone.search_btn_detective.visible = solved

		if not zone.search_btn_detective.pressed.is_connected(zone._on_search_room_pressed):
			zone.search_btn_detective.pressed.connect(zone._on_search_room_pressed)

	if is_instance_valid(zone.search_btn_sidekick):
		zone.search_btn_sidekick.visible = solved

		if not zone.search_btn_sidekick.pressed.is_connected(zone._on_search_room_pressed):
			zone.search_btn_sidekick.pressed.connect(zone._on_search_room_pressed)


func on_search_room_pressed() -> void:
	print("[ToolHunt] Search room button pressed!")

	if not zone._note_solved:
		print("[ToolHunt] Puzzle not solved yet, ignoring search button")
		return

	if is_instance_valid(zone.search_btn_detective):
		zone.search_btn_detective.visible = false

	if is_instance_valid(zone.search_btn_sidekick):
		zone.search_btn_sidekick.visible = false

	zone.note_controller.close_boards(true)
	set_search_mode_local(true)

	if zone.multiplayer.has_multiplayer_peer():
		zone.rpc_request_consequence_state.rpc_id(zone._SERVER_PEER_ID)


func set_search_mode_local(enable: bool) -> void:
	zone._search_mode = enable

	if is_instance_valid(zone.search_room_ui):
		zone.search_room_ui.visible = enable

	zone.note_controller.apply_note_interaction_gate()
	zone.note_controller.apply_close_button_visibility()

	apply_tool_nodes()
	apply_banner_frames()


func apply_tool_nodes() -> void:
	apply_single_tool("pan", zone.pan_prop, zone.pan_collision)
	apply_single_tool("ladle", zone.ladle_prop, zone.ladle_collision)
	apply_single_tool("pot", zone.pot_prop, zone.pot_collision)


func apply_single_tool(tool_id: String, area: Area2D, col: CollisionShape2D) -> void:
	var collected: bool = bool(zone._tools_collected.get(tool_id, false))
	var unlocked: bool = zone._tools_unlocked

	var can_interact: bool = unlocked and not collected
	var should_show: bool = not collected

	if is_instance_valid(area):
		area.visible = should_show
		set_area_pickable(area, can_interact)

	if is_instance_valid(col):
		col.disabled = not can_interact


func apply_banner_frames() -> void:
	if is_instance_valid(zone.frame_ladle):
		zone.frame_ladle.texture = zone._reveal_tex["ladle"] if zone._tools_collected["ladle"] else zone._shadow_tex["ladle"]

	if is_instance_valid(zone.frame_pan):
		zone.frame_pan.texture = zone._reveal_tex["pan"] if zone._tools_collected["pan"] else zone._shadow_tex["pan"]

	if is_instance_valid(zone.frame_pot):
		zone.frame_pot.texture = zone._reveal_tex["pot"] if zone._tools_collected["pot"] else zone._shadow_tex["pot"]


func set_area_pickable(area: Area2D, pickable: bool) -> void:
	if not is_instance_valid(area):
		return

	area.input_pickable = pickable
	area.monitoring = pickable
	area.monitorable = pickable


func all_tools_collected() -> bool:
	for id in zone._TOOL_IDS:
		if not zone._tools_collected.get(id, false):
			return false
	return true


func on_wrong_object_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not zone._search_mode:
		return

	if zone._failed:
		return

	var clicked := false

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		clicked = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		clicked = st.pressed

	if clicked:
		zone._send_wrong_click_to_server()


func play_validation_dialogue(dialogue_id: String) -> void:
	var key := ""
	var lib = null

	match dialogue_id:
		"numbers_only":
			key = "pinas_house_numbers_only"
			lib = DialogueLibraries.PINAS_HOUSE_NUMBERS_ONLY
		"wrong_answer":
			key = "pinas_house_wrong_answer"
			lib = DialogueLibraries.PINAS_HOUSE_WRONG_ANSWER
		_:
			return

	DialogueSystems.play(key, lib, true)

	var t: SceneTreeTimer = zone.get_tree().create_timer(3.0, true)
	await t.timeout

	if DialogueSystems.has_method("stop"):
		DialogueSystems.stop()
