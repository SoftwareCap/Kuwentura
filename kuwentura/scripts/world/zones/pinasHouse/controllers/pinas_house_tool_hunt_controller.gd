extends RefCounted

## Tool Hunt Controller - Manages the kitchen tool search phase for Pina's House.

var zone: Node

# Maps tool ID → [prop_node, collision_node, frame_node] — single source of truth for all tool loops
var _tool_registry: Array = []


func setup(owner: Node) -> void:
	zone = owner

	_tool_registry = [
		["pan", zone.pan_prop, zone.pan_collision, zone.frame_pan],
		["ladle", zone.ladle_prop, zone.ladle_collision, zone.frame_ladle],
		["pot", zone.pot_prop, zone.pot_collision, zone.frame_pot],
	]

	for entry in _tool_registry:
		var tool_id: String = entry[0]
		var prop: Area2D = entry[1]
		if is_instance_valid(prop) and not prop.input_event.is_connected(zone._on_tool_input_event.bind(tool_id)):
			prop.input_event.connect(zone._on_tool_input_event.bind(tool_id))

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
	if _is_press_event(event):
		try_collect_tool(tool_id)


func try_collect_tool(tool_id: String) -> void:
	if zone._dialogue_input_locked or not zone._zone_active or not zone._tool_phase_active:
		return
	if not zone._tools_unlocked or zone._tools_collected.get(tool_id, false):
		return
	if not zone.multiplayer.has_multiplayer_peer():
		server_collect_tool(tool_id, 0)
		return
	if zone.multiplayer.is_server():
		server_collect_tool(tool_id, zone.multiplayer.get_unique_id())
	else:
		zone.rpc_request_collect_tool.rpc_id(zone._SERVER_PEER_ID, tool_id)


func server_collect_tool(tool_id: String, _sender_peer_id: int) -> void:
	if zone._failed or not zone._zone_active or not zone._tool_phase_active:
		return
	if not zone._TOOL_IDS.has(tool_id) or zone._tools_collected.get(tool_id, false):
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
	for entry in _tool_registry:
		apply_single_tool(entry[0], entry[1], entry[2])


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
	for entry in _tool_registry:
		var tool_id: String = entry[0]
		var frame: Node = entry[3]
		if is_instance_valid(frame):
			frame.texture = zone._reveal_tex[tool_id] if zone._tools_collected[tool_id] else zone._shadow_tex[tool_id]


func set_area_pickable(area: Area2D, pickable: bool) -> void:
	if is_instance_valid(area):
		area.input_pickable = pickable


func all_tools_collected() -> bool:
	for tool_id in zone._TOOL_IDS:
		if not zone._tools_collected.get(tool_id, false):
			return false
	return true


func on_wrong_object_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (zone._tool_phase_active or zone._cabinet_phase_active) or not _is_press_event(event):
		return
	zone.show_notification("This is not helpful.", 1.6)
	if not zone.multiplayer.has_multiplayer_peer() or zone.multiplayer.is_server():
		zone.rpc_request_penalty("wrong_object")
	else:
		zone.rpc_request_penalty.rpc_id(zone._SERVER_PEER_ID, "wrong_object")
