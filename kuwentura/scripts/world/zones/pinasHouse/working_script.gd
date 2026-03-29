extends Node2D

const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const SCENE_MAIN_MENU := "res://scenes/mainMenu/MainMenu.tscn"
const SETTINGS_FILE := "user://settings.json"

const _SERVER_PEER_ID := 1
const _TOOL_IDS := ["pan", "ladle", "pot"]

const TOTAL_TIME_SEC := 300
const ATTACK_INTERVAL_SEC := 30
const PENALTY_SEC := 45
const MAX_ATTACKS := 10
const FIRST_ATTACK_DELAY_SEC := 10

const HOST_VIEW_UNSOLVED := "COOKING TOOLS INVENTORY\n\nx + y = 10\ny - z = 2\nz = 3"
const HOST_VIEW_SOLVED := "COOKING TOOLS INVENTORY\n\nPot (z) = 3\nPan (y) = 5\nLadle (x) = 5"

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton
@onready var inside_zone_control: CanvasLayer = $InsideZoneControl
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvas_layer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeValue

@onready var detective_overlays: Node = $RoleLayer/Control/DetectiveOverlays
@onready var sidekick_overlays: Node = $RoleLayer/Control/SidekickOverlays
@onready var detective_board: Control = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective
@onready var sidekick_board: Control = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick
@onready var detective_text: Label = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/DetectiveText
@onready var detective_close: Button = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/Close
@onready var sidekick_close: Button = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick/SidekickNote/Close
@onready var note_btn: TextureButton = $RoleLayer/Control/NoteTapButton

@onready var pan_prop: Area2D = $InteractiveLayer/PanProp
@onready var ladle_prop: Area2D = $InteractiveLayer/LadleProp
@onready var pot_prop: Area2D = $InteractiveLayer/PotProp

@onready var pan_collision: CollisionShape2D = $InteractiveLayer/PanProp/PanCollision
@onready var ladle_collision: CollisionShape2D = $InteractiveLayer/LadleProp/LadleCollision
@onready var pot_collision: CollisionShape2D = $InteractiveLayer/PotProp/PotCollision

@onready var search_btn_detective: Button = $RoleLayer/Control/DetectiveOverlays/SearchRoomButton
@onready var search_btn_sidekick: Button = $RoleLayer/Control/SidekickOverlays/SearchRoomButton
@onready var search_room_ui: CanvasLayer = $SearchRoomUI
@onready var frame_ladle: TextureRect = $SearchRoomUI/Root/Banner/FramesRow/Frame_Ladle
@onready var frame_pan: TextureRect = $SearchRoomUI/Root/Banner/FramesRow/Frame_Pan
@onready var frame_pot: TextureRect = $SearchRoomUI/Root/Banner/FramesRow/Frame_Pot

@onready var aswang_sprite: Sprite2D = get_node("InteractiveLayer/Aswang Window/AswangSprite")
@onready var consequence_ui: CanvasLayer = $ConsequenceUI
@onready var blackout: ColorRect = $ConsequenceUI/Blackout
@onready var final_aswang: Sprite2D = $ConsequenceUI/FinalAswang

var _search_mode := false
var _tools_unlocked := false
var _tools_collected := {"pan": false, "ladle": false, "pot": false}

var clue_collected: bool = false
var _detective_note_seen := false
var _note_dialogue_played := false
var _intro_dialogue_played := false

var _time_left := TOTAL_TIME_SEC
var _attack_index := 0
var _failed := false
var _first_warning_played := false

var _tick_timer: Timer = null
var _attack_timer: Timer = null
var _first_attack_timer: Timer = null
var _shake_timer: Timer = null
var _shake_elapsed: float = 0.0
var _shake_duration: float = 0.0
var _shake_amplitude: float = 0.0
var _shake_origin: Vector2 = Vector2.ZERO

var _shadow_tex := {
	"ladle": preload("res://assets/sprites/zoneObjects/pinasHouseObjects/shadow_Ladle.png"),
	"pan": preload("res://assets/sprites/zoneObjects/pinasHouseObjects/shadow_Pan.png"),
	"pot": preload("res://assets/sprites/zoneObjects/pinasHouseObjects/shadow_Pot.png"),
}
var _reveal_tex := {
	"ladle": preload("res://assets/sprites/zoneObjects/pinasHouseObjects/reveal_Ladle.png"),
	"pan": preload("res://assets/sprites/zoneObjects/pinasHouseObjects/reveal_Pan.png"),
	"pot": preload("res://assets/sprites/zoneObjects/pinasHouseObjects/reveal_Pot.png"),
}
var _aswang_window_frames: Array[Texture2D] = [
	preload("res://assets/sprites/consequences/aswang/aswang1.png"),
	preload("res://assets/sprites/consequences/aswang/aswang2.png"),
	preload("res://assets/sprites/consequences/aswang/aswang3.png"),
	preload("res://assets/sprites/consequences/aswang/aswang4.png"),
	preload("res://assets/sprites/consequences/aswang/aswang5.png"),
	preload("res://assets/sprites/consequences/aswang/aswang6.png"),
	preload("res://assets/sprites/consequences/aswang/aswang7.png"),
	preload("res://assets/sprites/consequences/aswang/aswang8.png"),
	preload("res://assets/sprites/consequences/aswang/aswang9.png"),
]
var _aswang_final_frame: Texture2D = preload("res://assets/sprites/consequences/aswang/aswang10.png")

# [frame_node, tool_id] — single source of truth for banner loops
var _banner_registry: Array = []


func _ready() -> void:
	if is_instance_valid(consequence_ui): consequence_ui.visible = false
	if is_instance_valid(blackout): blackout.visible = false
	if is_instance_valid(final_aswang): final_aswang.visible = false

	MusicController.play_track(MusicController.MusicTrack.PINAS_HOUSE)

	if not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)
	if not GameState.player_role_assigned.is_connected(_on_role_assigned):
		GameState.player_role_assigned.connect(_on_role_assigned)

	_setup_pause_controls()
	_update_role_label()
	update_role_visibility()

	if is_instance_valid(detective_board): detective_board.visible = false
	if is_instance_valid(sidekick_board): sidekick_board.visible = false

	for btn in [detective_close, sidekick_close]:
		if is_instance_valid(btn) and not btn.pressed.is_connected(_close_boards):
			btn.pressed.connect(_close_boards)

	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if is_instance_valid(note_btn) and not note_btn.pressed.is_connected(_on_note_interacted):
		note_btn.pressed.connect(_on_note_interacted)

	_setup_tool_hunt()

	if is_instance_valid(sidekick_board) and sidekick_board.has_signal("solved"):
		if not sidekick_board.solved.is_connected(_on_sidekick_solved):
			sidekick_board.solved.connect(_on_sidekick_solved)

	if GameState.is_puzzle_solved("pinas_house"):
		_apply_solved_text()
		if is_instance_valid(sidekick_board) and sidekick_board.has_method("apply_solved_view"):
			sidekick_board.apply_solved_view()
		_set_tools_unlocked_local(true)
	else:
		_apply_unsolved_text()
		_set_tools_unlocked_local(false)

	if is_instance_valid(search_room_ui):
		search_room_ui.visible = false

	_setup_search_room_buttons()

	_banner_registry = [
		[frame_ladle, "ladle"],
		[frame_pan, "pan"],
		[frame_pot, "pot"],
	]
	_apply_banner_frames()
	_search_mode = false
	_apply_tool_nodes()
	_apply_note_interaction_gate()
	_start_intro_dialogue_delayed()

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_start_consequences_server()


func _exit_tree() -> void:
	if inside_zone_control and inside_zone_control.has_signal("pause_pressed"):
		if inside_zone_control.pause_pressed.is_connected(_on_pause_button_pressed):
			inside_zone_control.pause_pressed.disconnect(_on_pause_button_pressed)


func _is_press_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _start_shake(duration: float, amplitude: float, interval: float) -> void:
	_shake_duration = duration
	_shake_amplitude = amplitude
	_shake_elapsed = 0.0
	_shake_origin = position
	if _shake_timer == null:
		_shake_timer = Timer.new()
		_shake_timer.one_shot = false
		_shake_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_shake_timer)
		_shake_timer.timeout.connect(_on_final_shake_tick)
	_shake_timer.wait_time = interval
	_shake_timer.start()


func _on_final_shake_tick() -> void:
	_shake_elapsed += _shake_timer.wait_time
	if _shake_elapsed >= _shake_duration:
		position = _shake_origin
		_shake_timer.stop()
		return
	var ox := randf_range(-_shake_amplitude, _shake_amplitude)
	var oy := randf_range(-_shake_amplitude, _shake_amplitude)
	position = _shake_origin + Vector2(ox, oy)


func _sync_volume_ui() -> void:
	if volume_slider:
		volume_slider.value = MusicController.get_volume() * 100
	if volume_value_label:
		volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


func _setup_pause_controls() -> void:
	if inside_zone_control and inside_zone_control.has_signal("pause_pressed"):
		if not inside_zone_control.pause_pressed.is_connected(_on_pause_button_pressed):
			inside_zone_control.pause_pressed.connect(_on_pause_button_pressed)
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
		if option_sub_panel:
			option_sub_panel.visible = false
		_sync_volume_ui()


func _on_pause_button_pressed() -> void:
	if in_game_pause_panel:
		in_game_pause_panel.visible = true
		if option_sub_panel:
			option_sub_panel.visible = false
	get_tree().paused = true


func _on_resume_play_button_pressed() -> void:
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
	if option_sub_panel:
		option_sub_panel.visible = false
	get_tree().paused = false


func _on_option_button_pressed() -> void:
	if option_sub_panel:
		option_sub_panel.visible = true
		_sync_volume_ui()


func _on_in_game_option_back_pressed() -> void:
	if option_sub_panel and option_sub_panel.visible:
		option_sub_panel.visible = false


func _on_exit_to_main_menu_button_pressed() -> void:
	get_tree().paused = false
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout
	_save_settings()
	if is_inside_tree():
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _on_in_game_volume_changed(value: float) -> void:
	MusicController.set_volume(value / 100.0)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"volume": MusicController.get_volume()}))
		file.close()


func _start_consequences_server() -> void:
	_time_left = TOTAL_TIME_SEC
	_attack_index = 0
	_failed = false
	_first_warning_played = false

	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.one_shot = false
	_tick_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tick_timer)
	_tick_timer.timeout.connect(_on_tick_server)
	_tick_timer.start()

	_first_attack_timer = Timer.new()
	_first_attack_timer.wait_time = float(FIRST_ATTACK_DELAY_SEC)
	_first_attack_timer.one_shot = true
	_first_attack_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_first_attack_timer)
	_first_attack_timer.timeout.connect(_on_first_attack_server)
	_first_attack_timer.start()

	_attack_timer = Timer.new()
	_attack_timer.wait_time = float(ATTACK_INTERVAL_SEC)
	_attack_timer.one_shot = false
	_attack_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_attack_timer)
	_attack_timer.timeout.connect(_on_scheduled_attack_server)


func _on_first_attack_server() -> void:
	if _failed:
		return
	_attack_index = 1
	rpc_play_aswang_attack.rpc(_attack_index, false)
	if not _first_warning_played:
		_first_warning_played = true
		rpc_play_first_attack_warning.rpc()
	if is_instance_valid(_attack_timer) and _attack_timer.is_stopped():
		_attack_timer.start()


@rpc("any_peer", "reliable", "call_local")
func rpc_play_first_attack_warning() -> void:
	DialogueSystems.play("pinas_house_first_aswang_warning", DialogueLibraries.PINAS_HOUSE_FIRST_ASWANG_WARNING, true)


func _on_tick_server() -> void:
	if _failed:
		return
	_time_left -= 1
	if _time_left <= 0:
		_time_left = 0
		_fail_zone_server()


func _on_scheduled_attack_server() -> void:
	if _failed:
		return
	_attack_index += 1
	if _attack_index >= 10:
		_fail_zone_server()
		return
	rpc_play_aswang_attack.rpc(_attack_index, false)


@rpc("any_peer", "reliable")
func rpc_request_penalty(reason: String) -> void:
	if multiplayer.is_server():
		_apply_penalty_server(reason)


func _apply_penalty_server(_reason: String) -> void:
	if _failed:
		return
	_attack_index = min(_attack_index + 1, MAX_ATTACKS)
	rpc_play_aswang_attack.rpc(_attack_index, true)
	_time_left = max(0, _time_left - PENALTY_SEC)
	if _time_left <= 0:
		_fail_zone_server()


@rpc("any_peer", "reliable", "call_local")
func rpc_play_aswang_attack(idx: int, from_penalty: bool) -> void:
	if idx < 1 or idx >= 10:
		return
	if is_instance_valid(aswang_sprite):
		aswang_sprite.texture = _aswang_window_frames[idx - 1]
		aswang_sprite.visible = true
	_screen_shake_attack_local(from_penalty)


func _screen_shake_local(stronger: bool) -> void:
	var strength := 10.0 if stronger else 6.0
	var original := position
	position = original + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	var tw := create_tween()
	tw.tween_property(self, "position", original, 0.12)


func _screen_shake_extreme_local() -> void:
	_start_shake(0.6, 20.0, 0.02)


func _screen_shake_attack_local(from_penalty: bool) -> void:
	var duration := 0.75 if from_penalty else 0.55
	var amplitude := 28.0 if from_penalty else 20.0
	_start_shake(duration, amplitude, 0.02)


func _screen_shake_final_local() -> void:
	_start_shake(5.0, 30.0, 0.03)


func _start_intro_dialogue_delayed() -> void:
	if _intro_dialogue_played:
		return
	_intro_dialogue_played = true
	DialogueSystems.play("pinas_house_enter", DialogueLibraries.PINAS_HOUSE_ENTER)


func _on_note_interacted() -> void:
	if _search_mode:
		return
	_close_boards()
	var will_play_note_dialogue := false
	if not _note_dialogue_played:
		_note_dialogue_played = true
		will_play_note_dialogue = true
		DialogueSystems.play("pinas_house_note_clicked", DialogueLibraries.PINAS_HOUSE_NOTE_CLICKED)

	if GameState.local_role == GameState.Role.DETECTIVE:
		detective_board.visible = true
		_mark_detective_note_seen()
		if GameState.is_puzzle_solved("pinas_house"):
			_apply_solved_text()
		else:
			_apply_unsolved_text()

	elif GameState.local_role == GameState.Role.SIDEKICK:
		sidekick_board.visible = true
		if sidekick_board.has_method("open_board"):
			sidekick_board.open_board()
		if sidekick_board.has_method("set_inputs_enabled"):
			sidekick_board.set_inputs_enabled(_detective_note_seen)
		if will_play_note_dialogue and sidekick_board.has_method("set_puzzle_inputs_visible"):
			sidekick_board.set_puzzle_inputs_visible(false)
		if will_play_note_dialogue:
			await get_tree().create_timer(3.0, true).timeout
			if DialogueSystems.has_method("stop"):
				DialogueSystems.stop()
			if sidekick_board.has_method("set_puzzle_inputs_visible"):
				sidekick_board.set_puzzle_inputs_visible(true)
		else:
			if sidekick_board.has_method("set_puzzle_inputs_visible"):
				sidekick_board.set_puzzle_inputs_visible(true)

	_apply_close_button_visibility()


func _mark_detective_note_seen() -> void:
	if _detective_note_seen:
		return
	if not multiplayer.has_multiplayer_peer():
		_set_detective_note_seen_local(true)
		return
	if multiplayer.is_server():
		_set_detective_note_seen_local(true)
		rpc_set_detective_note_seen.rpc(true)
	else:
		rpc_request_detective_note_seen.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_detective_note_seen() -> void:
	if multiplayer.is_server():
		_set_detective_note_seen_local(true)
		rpc_set_detective_note_seen.rpc(true)


@rpc("any_peer", "reliable", "call_local")
func rpc_set_detective_note_seen(seen: bool) -> void:
	_set_detective_note_seen_local(seen)


func _set_detective_note_seen_local(seen: bool) -> void:
	_detective_note_seen = seen
	if is_instance_valid(sidekick_board) and sidekick_board.has_method("set_inputs_enabled"):
		sidekick_board.set_inputs_enabled(_detective_note_seen)


func _close_boards(force: bool = false) -> void:
	if not force and not _search_mode:
		return
	if is_instance_valid(detective_board): detective_board.visible = false
	if is_instance_valid(sidekick_board): sidekick_board.visible = false


func _apply_close_button_visibility() -> void:
	if is_instance_valid(detective_close): detective_close.visible = _search_mode
	if is_instance_valid(sidekick_close): sidekick_close.visible = _search_mode


func _apply_unsolved_text() -> void:
	if is_instance_valid(detective_text):
		detective_text.text = HOST_VIEW_UNSOLVED


func _apply_solved_text() -> void:
	if is_instance_valid(detective_text):
		detective_text.text = HOST_VIEW_SOLVED


func _on_sidekick_solved() -> void:
	rpc_pinas_house_solved.rpc()
	if multiplayer.is_server():
		GameState.collect_clue("pinas_house")
	else:
		NetworkManager.trigger_clue_collection.rpc("pinas_house", {})


@rpc("any_peer", "reliable", "call_local")
func rpc_pinas_house_solved() -> void:
	GameState.set_puzzle_solved("pinas_house", true)
	_apply_solved_text()
	if is_instance_valid(sidekick_board) and sidekick_board.has_method("apply_solved_view"):
		sidekick_board.apply_solved_view()
	_set_tools_unlocked_local(true)
	if is_instance_valid(search_btn_detective): search_btn_detective.visible = false
	if is_instance_valid(search_btn_sidekick): search_btn_sidekick.visible = false
	DialogueSystems.play("pinas_house_after_puzzle1", DialogueLibraries.PINAS_HOUSE_AFTER_PUZZLE1)
	await DialogueSystems.wait_finished("pinas_house_after_puzzle1")
	_setup_search_room_buttons()


func _setup_tool_hunt() -> void:
	for area in [pan_prop, ladle_prop, pot_prop]:
		_set_area_pickable(area, false)

	for entry in [["pan", pan_prop], ["ladle", ladle_prop], ["pot", pot_prop]]:
		var tool_id: String = entry[0]
		var prop: Area2D = entry[1]
		if is_instance_valid(prop) and not prop.input_event.is_connected(_on_tool_input_event.bind(tool_id)):
			prop.input_event.connect(_on_tool_input_event.bind(tool_id))

	_set_tools_unlocked_local(GameState.is_puzzle_solved("pinas_house"))


func _on_tool_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, tool_id: String) -> void:
	if _is_press_event(event):
		_try_collect_tool(tool_id)


func _try_collect_tool(tool_id: String) -> void:
	if not _tools_unlocked or _tools_collected.get(tool_id, false):
		return
	if not multiplayer.has_multiplayer_peer():
		_server_collect_tool(tool_id, 0)
		return
	if multiplayer.is_server():
		_server_collect_tool(tool_id, multiplayer.get_unique_id())
	else:
		rpc_request_collect_tool.rpc_id(_SERVER_PEER_ID, tool_id)


@rpc("any_peer", "reliable")
func rpc_request_collect_tool(tool_id: String) -> void:
	if multiplayer.is_server():
		_server_collect_tool(tool_id, multiplayer.get_remote_sender_id())


func _server_collect_tool(tool_id: String, _sender_peer_id: int) -> void:
	if not GameState.is_puzzle_solved("pinas_house"):
		return
	if not _TOOL_IDS.has(tool_id) or _tools_collected.get(tool_id, false):
		return
	rpc_set_tool_collected.rpc(tool_id)
	if _all_tools_collected():
		rpc_reveal_pinas_house_clue.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_set_tool_collected(tool_id: String) -> void:
	_tools_collected[tool_id] = true
	_apply_tool_nodes()
	_apply_banner_frames()


@rpc("any_peer", "reliable", "call_local")
func rpc_set_tools_unlocked(unlocked: bool) -> void:
	_set_tools_unlocked_local(unlocked)


@rpc("any_peer", "reliable", "call_local")
func rpc_reveal_pinas_house_clue() -> void:
	GameState.collect_clue("pinas_house")


@rpc("any_peer", "reliable")
func rpc_request_validation_dialogue(dialogue_id: String) -> void:
	if not multiplayer.is_server():
		return
	if dialogue_id == "numbers_only" or dialogue_id == "wrong_answer":
		_apply_penalty_server(dialogue_id)
	rpc_play_validation_feedback.rpc(dialogue_id)


@rpc("any_peer", "reliable", "call_local")
func rpc_play_validation_dialogue(dialogue_id: String) -> void:
	var key: String = ""
	var lib: Variant = null
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
	await get_tree().create_timer(3.0, true).timeout
	if DialogueSystems.has_method("stop"):
		DialogueSystems.stop()


func _set_tools_unlocked_local(unlocked: bool) -> void:
	_tools_unlocked = unlocked
	_apply_tool_nodes()


func _apply_tool_nodes() -> void:
	_apply_single_tool("pan", pan_prop, pan_collision)
	_apply_single_tool("ladle", ladle_prop, ladle_collision)
	_apply_single_tool("pot", pot_prop, pot_collision)


func _apply_single_tool(tool_id: String, area: Area2D, col: CollisionShape2D) -> void:
	var collected: bool = bool(_tools_collected.get(tool_id, false))
	var can_interact: bool = _tools_unlocked and not collected
	if is_instance_valid(area):
		area.visible = not collected
		_set_area_pickable(area, can_interact)
	if is_instance_valid(col):
		col.disabled = not can_interact


func _setup_search_room_buttons() -> void:
	var solved := GameState.is_puzzle_solved("pinas_house")
	for btn in [search_btn_detective, search_btn_sidekick]:
		if is_instance_valid(btn):
			btn.visible = solved
			if not btn.pressed.is_connected(_on_search_room_pressed):
				btn.pressed.connect(_on_search_room_pressed)


func _on_search_room_pressed() -> void:
	if not GameState.is_puzzle_solved("pinas_house"):
		return
	if is_instance_valid(search_btn_detective): search_btn_detective.visible = false
	if is_instance_valid(search_btn_sidekick): search_btn_sidekick.visible = false
	_close_boards(true)
	_set_search_mode_local(true)
	if multiplayer.has_multiplayer_peer():
		rpc_request_consequence_state.rpc_id(_SERVER_PEER_ID)


func _set_search_mode_local(enable: bool) -> void:
	_search_mode = enable
	if is_instance_valid(search_room_ui):
		search_room_ui.visible = enable
	_apply_note_interaction_gate()
	_apply_tool_nodes()
	_apply_banner_frames()


func _apply_note_interaction_gate() -> void:
	if is_instance_valid(note_btn):
		note_btn.disabled = _search_mode


func _apply_banner_frames() -> void:
	for entry in _banner_registry:
		var frame: TextureRect = entry[0]
		var tool_id: String = entry[1]
		if is_instance_valid(frame):
			frame.texture = _reveal_tex[tool_id] if _tools_collected[tool_id] else _shadow_tex[tool_id]


func _set_area_pickable(area: Area2D, pickable: bool) -> void:
	if not is_instance_valid(area):
		return
	area.input_pickable = pickable
	area.monitoring = pickable
	area.monitorable = pickable


func _all_tools_collected() -> bool:
	for id in _TOOL_IDS:
		if not _tools_collected.get(id, false):
			return false
	return true


func update_role_visibility() -> void:
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			detective_overlays.visible = true
			sidekick_overlays.visible = false
		GameState.Role.SIDEKICK:
			detective_overlays.visible = false
			sidekick_overlays.visible = true
		_:
			detective_overlays.visible = false
			sidekick_overlays.visible = false


func _on_role_assigned(_role: Variant) -> void:
	GameState.local_role = _role
	update_role_visibility()
	_update_role_label()


func _update_role_label() -> void:
	if is_instance_valid(role_label):
		role_label.text = "Role: " + GameState.get_role_display_text()


func _on_back_pressed() -> void:
	_return_to_forest()


func _on_clue_collected(zone_id: String, _clue_data: Dictionary) -> void:
	if zone_id == "pinas_house" and not clue_collected:
		clue_collected = true
		role_label.text = "Clue collected! Returning..."
		await get_tree().create_timer(3.0).timeout
		_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_FOREST_HUB)


func _on_wrong_object_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _search_mode or _failed or not _is_press_event(event):
		return
	_send_wrong_click_to_server()


func _fail_zone_server() -> void:
	if _failed:
		return
	_failed = true
	for tmr in [_first_attack_timer, _tick_timer, _attack_timer]:
		if is_instance_valid(tmr): tmr.stop()
	rpc_fail_pre_shake.rpc()
	await get_tree().create_timer(0.6, true).timeout
	rpc_fail_show_ui.rpc()
	rpc_reset_pinas_house_progress.rpc()
	rpc_lock_pinas_house_zone.rpc(180)
	await get_tree().create_timer(3.0, true).timeout
	rpc_kick_to_hub.rpc()


@rpc("any_peer", "reliable")
func rpc_report_wrong_search_click() -> void:
	if not multiplayer.is_server() or _failed:
		return
	_apply_penalty_attack_server()


func _apply_penalty_attack_server() -> void:
	_attack_index += 1
	if _attack_index >= 10:
		_fail_zone_server()
		return
	rpc_play_aswang_attack.rpc(_attack_index, true)


@rpc("any_peer", "reliable")
func rpc_request_consequence_state() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	rpc_apply_consequence_state.rpc_id(peer, _attack_index, _time_left, _failed)


@rpc("any_peer", "reliable", "call_local")
func rpc_apply_consequence_state(attack_idx: int, time_left: int, failed: bool) -> void:
	_attack_index = attack_idx
	_time_left = time_left
	_failed = failed
	if not _failed and _attack_index >= 1 and _attack_index <= 9 and is_instance_valid(aswang_sprite):
		aswang_sprite.texture = _aswang_window_frames[_attack_index - 1]
		aswang_sprite.visible = true


@rpc("any_peer", "reliable", "call_local")
func rpc_play_validation_feedback(dialogue_id: String) -> void:
	_screen_shake_extreme_local()
	rpc_play_validation_dialogue(dialogue_id)


func _send_wrong_click_to_server() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		rpc_report_wrong_search_click()
	else:
		rpc_report_wrong_search_click.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable", "call_local")
func rpc_reset_pinas_house_progress() -> void:
	GameState.set_puzzle_solved("pinas_house", false)
	if GameState.collected_clues.has("pinas_house"):
		GameState.collected_clues["pinas_house"]["collected"] = false
	_tools_unlocked = false
	_tools_collected = {"pan": false, "ladle": false, "pot": false}
	_search_mode = false
	if is_instance_valid(search_room_ui): search_room_ui.visible = false
	if is_instance_valid(search_btn_detective): search_btn_detective.visible = false
	if is_instance_valid(search_btn_sidekick): search_btn_sidekick.visible = false
	_apply_tool_nodes()
	_apply_banner_frames()


@rpc("any_peer", "reliable", "call_local")
func rpc_lock_pinas_house_zone(duration_sec: int) -> void:
	GameState.lock_zone_temp("pinas_house", duration_sec)


@rpc("any_peer", "reliable", "call_local")
func rpc_kick_to_hub() -> void:
	if is_instance_valid(consequence_ui): consequence_ui.visible = false
	if is_instance_valid(blackout): blackout.visible = false
	if is_instance_valid(final_aswang): final_aswang.visible = false
	get_tree().change_scene_to_file(SCENE_FOREST_HUB)


@rpc("any_peer", "reliable", "call_local")
func rpc_fail_pre_shake() -> void:
	_screen_shake_attack_local(true)


@rpc("any_peer", "reliable", "call_local")
func rpc_fail_show_ui() -> void:
	if is_instance_valid(consequence_ui):
		consequence_ui.visible = true
		consequence_ui.layer = 100
	if is_instance_valid(blackout):
		blackout.visible = true
		var c: Color = blackout.color
		c.a = 1.0
		blackout.color = c
		blackout.z_index = 0
	if is_instance_valid(final_aswang):
		final_aswang.visible = true
		final_aswang.texture = _aswang_final_frame
		final_aswang.z_index = 1
