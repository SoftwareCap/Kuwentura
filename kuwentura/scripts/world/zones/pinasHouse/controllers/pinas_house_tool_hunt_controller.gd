extends RefCounted

var zone


func setup(owner) -> void:
	zone = owner

	if is_instance_valid(zone.pan_prop) and not zone.pan_prop.input_event.is_connected(zone._on_tool_input_event.bind("pan")):
		zone.pan_prop.input_event.connect(zone._on_tool_input_event.bind("pan"))

	if is_instance_valid(zone.ladle_prop) and not zone.ladle_prop.input_event.is_connected(zone._on_tool_input_event.bind("ladle")):
		zone.ladle_prop.input_event.connect(zone._on_tool_input_event.bind("ladle"))

	if is_instance_valid(zone.pot_prop) and not zone.pot_prop.input_event.is_connected(zone._on_tool_input_event.bind("pot")):
		zone.pot_prop.input_event.connect(zone._on_tool_input_event.bind("pot"))

	if is_instance_valid(zone.search_room_ui):
		zone.search_room_ui.visible = false

	apply_banner_frames()
	apply_tool_nodes()


func _is_press_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed

	if event is InputEventScreenTouch:
		return event.pressed

	return false

func on_tool_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, tool_id: String) -> void:
	if not _is_press_event(event):
		return

	try_collect_tool(tool_id)


func try_collect_tool(tool_id: String) -> void:
	if zone._dialogue_input_locked:
		return
		
	if not zone._zone_active:
		return

	if not zone._tool_phase_active:
		return

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
	if zone._failed:
		return

	if not zone._zone_active:
		return

	if not zone._tool_phase_active:
		return

	if not zone._TOOL_IDS.has(tool_id):
		return

	if zone._tools_collected.get(tool_id, false):
		return

	zone.rpc_set_tool_collected.rpc(tool_id)
	zone.rpc_show_tool_feedback.rpc("Tool found!")

	if all_tools_collected():
		_finish_tool_phase_server()


func _finish_tool_phase_server() -> void:
	zone._tool_phase_active = false
	zone._note_phase_active = true
	zone._tools_unlocked = false

	zone.rpc_set_tools_unlocked.rpc(false)
	zone.rpc_note_revealed.rpc()

	# Play dialogue for BOTH players
	zone.rpc_play_tools_done_dialogue.rpc()

func set_tool_collected_local(tool_id: String) -> void:
	zone._tools_collected[tool_id] = true
	apply_tool_nodes()
	apply_banner_frames()


func set_tools_unlocked_local(unlocked: bool) -> void:
	zone._tools_unlocked = unlocked
	apply_tool_nodes()


func set_search_mode_local(enable: bool) -> void:
	if is_instance_valid(zone.search_room_ui):
		zone.search_room_ui.visible = enable
		_set_search_ui_controls_ignore(zone.search_room_ui)

	zone._tool_phase_active = enable
	zone._tools_unlocked = enable
	apply_tool_nodes()
	set_wrong_click_zone_active(enable)

func set_wrong_click_zone_active(enable: bool) -> void:
	if not is_instance_valid(zone.wrong_click_zone):
		return

	zone.wrong_click_zone.input_pickable = enable

	for child in zone.wrong_click_zone.get_children():
		if child is CollisionShape2D:
			child.disabled = not enable


func _set_search_ui_controls_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_search_ui_controls_ignore(child)

func apply_tool_nodes() -> void:
	apply_single_tool("pan", zone.pan_prop, zone.pan_collision)
	apply_single_tool("ladle", zone.ladle_prop, zone.ladle_collision)
	apply_single_tool("pot", zone.pot_prop, zone.pot_collision)


func apply_single_tool(tool_id: String, area: Area2D, col: CollisionShape2D) -> void:
	if not is_instance_valid(area):
		return

	var collected: bool = zone._tools_collected.get(tool_id, false)
	var can_pick: bool = zone._tool_phase_active and zone._tools_unlocked and not collected

	area.visible = not collected
	area.input_pickable = can_pick

	if is_instance_valid(col):
		col.disabled = not can_pick


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


func all_tools_collected() -> bool:
	for tool_id in zone._TOOL_IDS:
		if not zone._tools_collected.get(tool_id, false):
			return false
	return true


func on_wrong_object_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (zone._tool_phase_active or zone._cabinet_phase_active):
		return

	if not _is_press_event(event):
		return

	zone.show_notification("This is not helpful.", 1.6)

	if not zone.multiplayer.has_multiplayer_peer():
		zone.rpc_request_penalty("wrong_object")
	else:
		if zone.multiplayer.is_server():
			zone.rpc_request_penalty("wrong_object")
		else:
			zone.rpc_request_penalty.rpc_id(zone._SERVER_PEER_ID, "wrong_object")
			
