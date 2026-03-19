extends Node2D

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton

# Pause / settings UI (teammate)
@onready var inside_zone_control: CanvasLayer = $InsideZoneControl
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvas_layer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeValue

# Role overlays + boards (you)
@onready var detective_overlays: Node = $RoleLayer/Control/DetectiveOverlays
@onready var sidekick_overlays: Node = $RoleLayer/Control/SidekickOverlays

@onready var detective_board: Control = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective
@onready var sidekick_board: Control = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick

@onready var detective_text: Label = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/DetectiveText

@onready var detective_close: Button = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/Close
@onready var sidekick_close: Button = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick/SidekickNote/Close

@onready var note_btn: TextureButton = $RoleLayer/Control/NoteTapButton

# Puzzle 2: cooking tool hunt (unlocked after Puzzle 1 solve)
@onready var pan_prop: Area2D = $InteractiveLayer/PanProp
@onready var ladle_prop: Area2D = $InteractiveLayer/LadleProp
@onready var pot_prop: Area2D = $InteractiveLayer/PotProp

@onready var pan_collision: CollisionShape2D = $InteractiveLayer/PanProp/PanCollision
@onready var ladle_collision: CollisionShape2D = $InteractiveLayer/LadleProp/LadleCollision
@onready var pot_collision: CollisionShape2D = $InteractiveLayer/PotProp/PotCollision

# SEARCH ROOM button (shows only after Puzzle 1 solved)
@onready var search_btn_detective: Button = $RoleLayer/Control/DetectiveOverlays/SearchRoomButton
@onready var search_btn_sidekick: Button = $RoleLayer/Control/SidekickOverlays/SearchRoomButton

# Search Room UI overlay
@onready var search_room_ui: CanvasLayer = $SearchRoomUI
@onready var frame_ladle: TextureRect = $SearchRoomUI/Root/Banner/FramesRow/Frame_Ladle
@onready var frame_pan: TextureRect = $SearchRoomUI/Root/Banner/FramesRow/Frame_Pan
@onready var frame_pot: TextureRect = $SearchRoomUI/Root/Banner/FramesRow/Frame_Pot

# Consequence visuals
@onready var aswang_sprite: Sprite2D = get_node("InteractiveLayer/Aswang Window/AswangSprite")
@onready var consequence_ui: CanvasLayer = $ConsequenceUI
@onready var blackout: ColorRect = $ConsequenceUI/Blackout
@onready var final_aswang: Sprite2D = $ConsequenceUI/FinalAswang

var _search_mode := false

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

const _SERVER_PEER_ID := 1
const _TOOL_IDS := ["pan", "ladle", "pot"]

var _tools_unlocked := false
var _tools_collected := {
	"pan": false,
	"ladle": false,
	"pot": false,
}

# Flag to track if clue was collected (for auto-return)
var clue_collected: bool = false

var _detective_note_seen := false  # local cache (synced via RPC)

# Dialogue guards (local only; prevents replay spam)
var _note_dialogue_played := false
var _intro_dialogue_played := false

const TOTAL_TIME_SEC := 300
const ATTACK_INTERVAL_SEC := 30
const PENALTY_SEC := 45
const MAX_ATTACKS := 10

var _time_left := TOTAL_TIME_SEC
var _attack_index := 0  # 0..10
var _failed := false

var _tick_timer: Timer
var _attack_timer: Timer

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

var _shake_timer: Timer
var _shake_elapsed := 0.0
var _shake_duration := 0.0
var _shake_amplitude := 0.0
var _shake_origin := Vector2.ZERO

const FIRST_ATTACK_DELAY_SEC := 10

var _first_attack_timer: Timer
var _first_warning_played := false

func _ready() -> void:
	
	print("[PinasHouse] Scene loaded!")

	if is_instance_valid(consequence_ui): consequence_ui.visible = false
	if is_instance_valid(blackout): blackout.visible = false
	if is_instance_valid(final_aswang): final_aswang.visible = false
	# Play Pina's House background music
	if Engine.has_singleton("MusicController") or MusicController:
		MusicController.play_track(MusicController.MusicTrack.PINAS_HOUSE)

	# Show saved position info
	var saved_pos = GameState.get_spawn_position(multiplayer.get_unique_id())
	if saved_pos != Vector2.ZERO:
		print("[PinasHouse] Will return to Forest Hub at position: ", saved_pos)

	# Signals: clue and role assigned 
	if not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)
	if not GameState.player_role_assigned.is_connected(_on_role_assigned):
		GameState.player_role_assigned.connect(_on_role_assigned)

	# Setup pause functionality
	_setup_pause_controls()

	# Role label + overlays
	_update_role_label()
	update_role_visibility()

	# Hide boards by default
	if is_instance_valid(detective_board):
		detective_board.visible = false
	if is_instance_valid(sidekick_board):
		sidekick_board.visible = false

	# Connect close buttons
	if is_instance_valid(detective_close) and not detective_close.pressed.is_connected(_close_boards):
		detective_close.pressed.connect(_close_boards)
	if is_instance_valid(sidekick_close) and not sidekick_close.pressed.is_connected(_close_boards):
		sidekick_close.pressed.connect(_close_boards)

	# Back button
	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	# Note tap opens board 
	if is_instance_valid(note_btn) and not note_btn.pressed.is_connected(_on_note_pressed):
		note_btn.pressed.connect(_on_note_pressed)

	# Puzzle 2 Tool hunt interactions and initial lock state
	_setup_tool_hunt()

	# Listen for sidekick solving
	if is_instance_valid(sidekick_board) and sidekick_board.has_signal("solved"):
		if not sidekick_board.solved.is_connected(_on_sidekick_solved):
			sidekick_board.solved.connect(_on_sidekick_solved)

	# Prepare detective text on load (equations view)
	if GameState.is_puzzle_solved("pinas_house"):
		_apply_solved_text()
		if is_instance_valid(sidekick_board) and sidekick_board.has_method("apply_solved_view"):
			sidekick_board.apply_solved_view()

		# Unlock Puzzle 2 tools
		_set_tools_unlocked_local(true)

	else:
		_apply_unsolved_text()

		# Keep Puzzle 2 locked
		_set_tools_unlocked_local(false)

	# Search Room UI starts hidden
	if is_instance_valid(search_room_ui):
		search_room_ui.visible = false

	# Setup SEARCH ROOM buttons (guarded)
	_setup_search_room_buttons()

	# Initialize frames based on current collected state
	_apply_banner_frames()

	# Ensure tools are not shown until search mode is active
	_search_mode = false
	_apply_tool_nodes()

	# Close button is not visible
	# _apply_close_button_visibility()

	_apply_note_interaction_gate()

	# Start delayed intro dialogue
	_start_intro_dialogue_delayed()

	# Start consequences when zone loads
	# - Server runs it in multiplayer
	# - Offline testing (no peer) also runs it
	if (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server():
		_start_consequences_server()

func _start_consequences_server() -> void:
	_time_left = TOTAL_TIME_SEC
	_attack_index = 0
	_failed = false
	_first_warning_played = false

	# tick timer (1 sec)
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.one_shot = false
	_tick_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tick_timer)
	_tick_timer.timeout.connect(_on_tick_server)
	_tick_timer.start()

	# FIRST attack after 10 seconds (one-shot)
	_first_attack_timer = Timer.new()
	_first_attack_timer.wait_time = float(FIRST_ATTACK_DELAY_SEC)
	_first_attack_timer.one_shot = true
	_first_attack_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_first_attack_timer)
	_first_attack_timer.timeout.connect(_on_first_attack_server)
	_first_attack_timer.start()

	# Normal repeating attack timer (every 30s), but START counting AFTER the first attack
	_attack_timer = Timer.new()
	_attack_timer.wait_time = float(ATTACK_INTERVAL_SEC) # 30
	_attack_timer.one_shot = false
	_attack_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_attack_timer)
	_attack_timer.timeout.connect(_on_scheduled_attack_server)
	# DO NOT start here
	
func _on_first_attack_server() -> void:
	if _failed:
		return

	# Attack stage 1 at 10 seconds
	_attack_index = 1
	rpc_play_aswang_attack.rpc(_attack_index, false)

	# Play the warning dialogue on both screens once
	if not _first_warning_played:
		_first_warning_played = true
		rpc_play_first_attack_warning.rpc()

	# Now start the normal 30-second cycle AFTER the first attack
	if is_instance_valid(_attack_timer) and _attack_timer.is_stopped():
		_attack_timer.start()

@rpc("any_peer", "reliable", "call_local")
func rpc_play_first_attack_warning() -> void:
	DialogueSystems.play(
		"pinas_house_first_aswang_warning",
		DialogueLibraries.PINAS_HOUSE_FIRST_ASWANG_WARNING,
		true
	)

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
		# Stage 10 = fail presentation + kick/reset logic
		_fail_zone_server()
		return

	# Stage 1-9 normal attack feedback
	rpc_play_aswang_attack.rpc(_attack_index, false)

@rpc("any_peer", "reliable")
func rpc_request_penalty(reason: String) -> void:
	if not multiplayer.is_server():
		return
	_apply_penalty_server(reason)
	
func _apply_penalty_server(_reason: String) -> void:
	if _failed:
		return

	# Immediate thump + shake feedback
	_attack_index = min(_attack_index + 1, MAX_ATTACKS)
	rpc_play_aswang_attack.rpc(_attack_index, true)

	# Time reduction
	_time_left = max(0, _time_left - PENALTY_SEC)
	if _time_left <= 0:
		_fail_zone_server()
		
@rpc("any_peer", "reliable", "call_local")
func rpc_play_aswang_attack(idx: int, from_penalty: bool) -> void:
	if idx <= 0:
		return

	if idx >= 10:
		return # final handled by _fail_zone_server() / rpc_fail_sequence()

	if is_instance_valid(aswang_sprite):
		aswang_sprite.texture = _aswang_window_frames[idx - 1]
		aswang_sprite.visible = true

	# NEW: always violent for attacks
	_screen_shake_attack_local(from_penalty)
	

func _play_final_aswang_overlay() -> void:
	if is_instance_valid(blackout):
		blackout.visible = true
		# start transparent, then fade darker
		var c := blackout.color
		c.a = 0.0
		blackout.color = c

	if is_instance_valid(final_aswang):
		final_aswang.visible = true
		final_aswang.texture = _aswang_final_frame

	var tw := create_tween()
	tw.tween_property(blackout, "color:a", 0.85, 0.25)

	# stronger shake
	_screen_shake_local(true)


func _screen_shake_local(stronger: bool) -> void:
	var target: Node2D = self
	var strength := 10.0 if stronger else 6.0

	var original := target.position
	target.position = original + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))

	var tw := create_tween()
	tw.tween_property(target, "position", original, 0.12)




func _start_intro_dialogue_delayed() -> void:
	if _intro_dialogue_played:
		return
	_intro_dialogue_played = true

	DialogueSystems.play("pinas_house_enter", DialogueLibraries.PINAS_HOUSE_ENTER)


func _setup_pause_controls():
	# Connect inside zone control pause button
	if inside_zone_control:
		if inside_zone_control.has_signal("pause_pressed"):
			if not inside_zone_control.pause_pressed.is_connected(_on_pause_button_pressed):
				inside_zone_control.pause_pressed.connect(_on_pause_button_pressed)

	# Initialize pause panel
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
		if option_sub_panel:
			option_sub_panel.visible = false
		# Set initial volume slider value
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


## Open the pause panel
func _on_pause_button_pressed() -> void:
	print("[PinasHouse] Pause button pressed")
	if in_game_pause_panel:
		in_game_pause_panel.visible = true
		if option_sub_panel:
			option_sub_panel.visible = false
	get_tree().paused = true


## Resume button pressed
func _on_resume_play_button_pressed() -> void:
	print("[PinasHouse] Resume button pressed")
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
	if option_sub_panel:
		option_sub_panel.visible = false
	get_tree().paused = false


## Option button pressed
func _on_option_button_pressed() -> void:
	print("[PinasHouse] Option button pressed")
	if option_sub_panel:
		option_sub_panel.visible = true
		if volume_slider:
			volume_slider.value = MusicController.get_volume() * 100
		if volume_value_label:
			volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


## Back button from options
func _on_in_game_option_back_pressed() -> void:
	print("[PinasHouse] Back from options")
	if option_sub_panel and option_sub_panel.visible:
		option_sub_panel.visible = false
		print("[PinasHouse] Option sub-panel closed, back to pause panel")


## Exit to Main Menu
func _on_exit_to_main_menu_button_pressed() -> void:
	print("[PinasHouse] Exit to main menu")
	get_tree().paused = false

	# Disconnect from network
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout

	# Save settings
	_save_settings()

	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


## Volume changed
func _on_in_game_volume_changed(value: float) -> void:
	var volume = value / 100.0
	MusicController.set_volume(volume)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"


func _save_settings() -> void:
	const OPTION_FILE = "user://settings.json"
	var data = {
		"volume": MusicController.get_volume()
	}

	var file = FileAccess.open(OPTION_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _exit_tree():
	# Cleanup signal connections
	if inside_zone_control and inside_zone_control.has_signal("pause_pressed"):
		if inside_zone_control.pause_pressed.is_connected(_on_pause_button_pressed):
			inside_zone_control.pause_pressed.disconnect(_on_pause_button_pressed)


func _on_note_pressed() -> void:
	_on_note_interacted()


func _on_note_interacted() -> void:
	if _search_mode:
		return
	# Close both first
	_close_boards()

	# Dialogue when note clicked (guarded)
	var will_play_note_dialogue := false
	if not _note_dialogue_played:
		_note_dialogue_played = true
		will_play_note_dialogue = true
		DialogueSystems.play("pinas_house_note_clicked", DialogueLibraries.PINAS_HOUSE_NOTE_CLICKED)

	if GameState.local_role == GameState.Role.DETECTIVE:
		detective_board.visible = true

		# Mark as seen whenever detective opens it
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

		# Hide inputs briefly while warning dialogue shows
		if will_play_note_dialogue and sidekick_board.has_method("set_puzzle_inputs_visible"):
			sidekick_board.set_puzzle_inputs_visible(false)

		if will_play_note_dialogue:
			# Auto-close after 3s so we never get stuck waiting for dialogue completion
			await get_tree().create_timer(3.0, true).timeout
			if DialogueSystems.has_method("stop"):
				DialogueSystems.stop() # no args
			if sidekick_board.has_method("set_puzzle_inputs_visible"):
				sidekick_board.set_puzzle_inputs_visible(true)
		else:
			# No dialogue played -> ensure inputs are visible
			if sidekick_board.has_method("set_puzzle_inputs_visible"):
				sidekick_board.set_puzzle_inputs_visible(true)

	_apply_close_button_visibility()


func _mark_detective_note_seen() -> void:
	# already marked
	if _detective_note_seen:
		return

	# offline
	if not multiplayer.has_multiplayer_peer():
		_set_detective_note_seen_local(true)
		return

	# server-authoritative
	if multiplayer.is_server():
		_set_detective_note_seen_local(true)
		rpc_set_detective_note_seen.rpc(true)
	else:
		rpc_request_detective_note_seen.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_detective_note_seen() -> void:
	if not multiplayer.is_server():
		return
	_set_detective_note_seen_local(true)
	rpc_set_detective_note_seen.rpc(true)


@rpc("any_peer", "reliable", "call_local")
func rpc_set_detective_note_seen(seen: bool) -> void:
	_set_detective_note_seen_local(seen)


func _set_detective_note_seen_local(seen: bool) -> void:
	_detective_note_seen = seen

	# Tell sidekick UI to enable/disable inputs
	if is_instance_valid(sidekick_board) and sidekick_board.has_method("set_inputs_enabled"):
		sidekick_board.set_inputs_enabled(_detective_note_seen)


func _close_boards(force: bool = false) -> void:
	# Notes cannot be closed during Puzzle 1.
	# They can be closed only in Search Mode (Puzzle 2), unless forced.
	if not force and not _search_mode:
		return

	if is_instance_valid(detective_board):
		detective_board.visible = false
	if is_instance_valid(sidekick_board):
		sidekick_board.visible = false


func _apply_close_button_visibility() -> void:
	# Only show close buttons during Search Room UI (Puzzle 2)

	if is_instance_valid(detective_close):
		detective_close.visible = _search_mode

	if is_instance_valid(sidekick_close):
		sidekick_close.visible = _search_mode


func _apply_unsolved_text() -> void:
	var p := PuzzleManager.get_puzzle_for_zone("pinas_house")
	var eqs: Array = p.get("equations", [])
	var txt := "COOKING TOOLS INVENTORY \n\n"
	for e in eqs:
		txt += str(e) + "\n"

	if is_instance_valid(detective_text):
		detective_text.text = txt


func _apply_solved_text() -> void:
	var p := PuzzleManager.get_puzzle_for_zone("pinas_house")
	var sol: Dictionary = p.get("solution", {})

	var x := int(sol.get("x", 0))
	var y := int(sol.get("y", 0))
	var z := int(sol.get("z", 0))

	if is_instance_valid(detective_text):
		detective_text.text = (
			"COOKING TOOLS INVENTORY \n\n"
			+ "Pot (z) = %d\nPan (y) = %d\nLadle (x) = %d" % [z, y, x]
		)


func _on_sidekick_solved() -> void:
	# Sidekick got it correct → update both peers immediately
	rpc_pinas_house_solved.rpc()

	# Also ensure clue collection happens
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

	# Hide search buttons first
	if is_instance_valid(search_btn_detective):
		search_btn_detective.visible = false
	if is_instance_valid(search_btn_sidekick):
		search_btn_sidekick.visible = false

	# Play dialogue
	DialogueSystems.play(
		"pinas_house_after_puzzle1",
		DialogueLibraries.PINAS_HOUSE_AFTER_PUZZLE1
	)

	# Wait until dialogue finishes
	await DialogueSystems.wait_finished("pinas_house_after_puzzle1")

	# Only now show the search button
	_setup_search_room_buttons()


# =========================
# Puzzle 2: Tool Hunt Logic
# =========================

func _setup_tool_hunt() -> void:
	# Lock tools first (prevents clicking before puzzle 1)
	_set_area_pickable(pan_prop, false)
	_set_area_pickable(ladle_prop, false)
	_set_area_pickable(pot_prop, false)

	# Connect input signals (guarded)
	if is_instance_valid(pan_prop) and not pan_prop.input_event.is_connected(_on_tool_input_event.bind("pan")):
		pan_prop.input_event.connect(_on_tool_input_event.bind("pan"))
	if is_instance_valid(ladle_prop) and not ladle_prop.input_event.is_connected(_on_tool_input_event.bind("ladle")):
		ladle_prop.input_event.connect(_on_tool_input_event.bind("ladle"))
	if is_instance_valid(pot_prop) and not pot_prop.input_event.is_connected(_on_tool_input_event.bind("pot")):
		pot_prop.input_event.connect(_on_tool_input_event.bind("pot"))

	# Apply initial gate
	_set_tools_unlocked_local(GameState.is_puzzle_solved("pinas_house"))


func _on_tool_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, tool_id: String) -> void:
	# Mouse
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_collect_tool(tool_id)
			return

	# Touch
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_try_collect_tool(tool_id)
			return


func _try_collect_tool(tool_id: String) -> void:
	if not _tools_unlocked:
		return
	if _tools_collected.get(tool_id, false):
		return

	# Offline / singleplayer test
	if not multiplayer.has_multiplayer_peer():
		_server_collect_tool(tool_id, 0)
		return

	# Authoritative server validates and broadcasts
	if multiplayer.is_server():
		_server_collect_tool(tool_id, multiplayer.get_unique_id())
	else:
		rpc_request_collect_tool.rpc_id(_SERVER_PEER_ID, tool_id)


@rpc("any_peer", "reliable")
func rpc_request_collect_tool(tool_id: String) -> void:
	# Runs on server only. Clients calling this will be ignored locally.
	if not multiplayer.is_server():
		return
	_server_collect_tool(tool_id, multiplayer.get_remote_sender_id())


func _server_collect_tool(tool_id: String, _sender_peer_id: int) -> void:
	# Gate: Puzzle 1 must be solved first
	if not GameState.is_puzzle_solved("pinas_house"):
		return
	if not _TOOL_IDS.has(tool_id):
		return
	if _tools_collected.get(tool_id, false):
		return

	# Broadcast tool removal to all peers (and apply locally)
	rpc_set_tool_collected.rpc(tool_id)

	# If all tools collected, reveal clue on BOTH screens
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
	# Reveal in both clients by collecting locally
	GameState.collect_clue("pinas_house")

@rpc("any_peer", "reliable")
func rpc_request_validation_dialogue(dialogue_id: String) -> void:
	if not multiplayer.is_server():
		return

	if dialogue_id == "numbers_only" or dialogue_id == "wrong_answer":
		_apply_penalty_server(dialogue_id)

	# NEW: shake first + short dialogue (both peers)
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

	# Auto-close after 3 seconds
	var t := get_tree().create_timer(3.0, true)
	await t.timeout

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
	var unlocked: bool = _tools_unlocked

	var can_interact: bool = unlocked and not collected
	var should_show: bool = not collected

	if is_instance_valid(area):
		area.visible = should_show
		_set_area_pickable(area, can_interact)

	if is_instance_valid(col):
		col.disabled = not can_interact


func _setup_search_room_buttons() -> void:
	var solved := GameState.is_puzzle_solved("pinas_house")

	if is_instance_valid(search_btn_detective):
		search_btn_detective.visible = solved
		if not search_btn_detective.pressed.is_connected(_on_search_room_pressed):
			search_btn_detective.pressed.connect(_on_search_room_pressed)

	if is_instance_valid(search_btn_sidekick):
		search_btn_sidekick.visible = solved
		if not search_btn_sidekick.pressed.is_connected(_on_search_room_pressed):
			search_btn_sidekick.pressed.connect(_on_search_room_pressed)


func _on_search_room_pressed() -> void:
	# Gate: must be solved first
	if not GameState.is_puzzle_solved("pinas_house"):
		return

	# Hide SEARCH ROOM button locally
	if is_instance_valid(search_btn_detective):
		search_btn_detective.visible = false
	if is_instance_valid(search_btn_sidekick):
		search_btn_sidekick.visible = false

	# Close notes locally
	_close_boards(true)

	# Open search UI locally
	_set_search_mode_local(true)

	# Catch up with current attack stage when entering Search Room
	if multiplayer.has_multiplayer_peer():
		rpc_request_consequence_state.rpc_id(_SERVER_PEER_ID)

func _set_search_mode_local(enable: bool) -> void:
	_search_mode = enable

	if is_instance_valid(search_room_ui):
		search_room_ui.visible = enable

	_apply_note_interaction_gate() # NEW

	_apply_tool_nodes()
	_apply_banner_frames()


func _apply_note_interaction_gate() -> void:
	# When Search Room UI is active, block note interaction
	var allow_note := not _search_mode

	if is_instance_valid(note_btn):
		note_btn.disabled = not allow_note


func _apply_banner_frames() -> void:
	if is_instance_valid(frame_ladle):
		frame_ladle.texture = _reveal_tex["ladle"] if _tools_collected["ladle"] else _shadow_tex["ladle"]
	if is_instance_valid(frame_pan):
		frame_pan.texture = _reveal_tex["pan"] if _tools_collected["pan"] else _shadow_tex["pan"]
	if is_instance_valid(frame_pot):
		frame_pot.texture = _reveal_tex["pot"] if _tools_collected["pot"] else _shadow_tex["pot"]


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


func _on_role_assigned(_role) -> void:
	GameState.local_role = _role
	update_role_visibility()
	_update_role_label()


func _update_role_label() -> void:
	var role_text := "Unknown"
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"

	role_label.text = "Role: " + role_text
	print("[PinasHouse] Local role: ", role_text, " | Peer ID: ", multiplayer.get_unique_id())


func _on_back_pressed() -> void:
	print("[PinasHouse] Returning to Forest Hub...")
	_return_to_forest()


func _on_clue_collected(zone_id: String, _clue_data: Dictionary) -> void:
	if zone_id == "pinas_house" and not clue_collected:
		clue_collected = true
		print("[PinasHouse] Clue collected! Auto-returning in 3s...")

		# Update UI to show returning
		role_label.text = "Clue collected! Returning..."

		await get_tree().create_timer(3.0).timeout
		_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


func _on_wrong_object_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Only punish during Puzzle 2 search mode
	if not _search_mode:
		return
	if _failed:
		return

	var clicked := false

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		clicked = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		clicked = st.pressed

	if clicked:
		_send_wrong_click_to_server()

func _fail_zone_server() -> void:
	if _failed:
		return
	_failed = true

	if is_instance_valid(_first_attack_timer): _first_attack_timer.stop()
	# Stop timers
	if is_instance_valid(_tick_timer): _tick_timer.stop()
	if is_instance_valid(_attack_timer): _attack_timer.stop()

	# Force final presentation (aswang10)
	# 1) Shake violently first (both peers)
	rpc_fail_pre_shake.rpc()
	
	# short delay so shake is visible BEFORE blackout
	var pre := get_tree().create_timer(0.6, true)
	await pre.timeout

	# 2) Now show consequence UI (blackout + aswang10)
	rpc_fail_show_ui.rpc()

	# Reset zone progress + lock zone for 3 mins
	rpc_reset_pinas_house_progress.rpc()
	rpc_lock_pinas_house_zone.rpc(180)

	# Kick out after a short delay so the fail screen is seen
	var t := get_tree().create_timer(3.0, true)
	await t.timeout
	rpc_kick_to_hub.rpc()
	
	
func _screen_shake_final_local() -> void:
	# stronger shake for the final attack
	_shake_duration = 5.0
	_shake_amplitude = 30.0
	_shake_elapsed = 0.0
	_shake_origin = position

	if _shake_timer == null:
		_shake_timer = Timer.new()
		_shake_timer.wait_time = 0.03
		_shake_timer.one_shot = false
		_shake_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_shake_timer)
		_shake_timer.timeout.connect(_on_final_shake_tick)

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
	
	
@rpc("any_peer", "reliable", "call_local")
func rpc_reset_pinas_house_progress() -> void:
	# Reset puzzle state
	GameState.set_puzzle_solved("pinas_house", false)

	# Make sure clue isn't awarded
	if GameState.collected_clues.has("pinas_house"):
		GameState.collected_clues["pinas_house"]["collected"] = false

	# Reset tool hunt local state
	_tools_unlocked = false
	_tools_collected = {"pan": false, "ladle": false, "pot": false}
	_search_mode = false

	# Hide UI
	if is_instance_valid(search_room_ui): search_room_ui.visible = false
	if is_instance_valid(search_btn_detective): search_btn_detective.visible = false
	if is_instance_valid(search_btn_sidekick): search_btn_sidekick.visible = false

	_apply_tool_nodes()
	_apply_banner_frames()
	
@rpc("any_peer", "reliable", "call_local")
func rpc_lock_pinas_house_zone(duration_sec: int) -> void:
	print("[LOCK] Setting lock pinas_house for ", duration_sec, "s on peer ", multiplayer.get_unique_id())
	GameState.lock_zone_temp("pinas_house", duration_sec)
	
@rpc("any_peer", "reliable", "call_local")
func rpc_kick_to_hub() -> void:
	if is_instance_valid(consequence_ui): consequence_ui.visible = false
	if is_instance_valid(blackout): blackout.visible = false
	if is_instance_valid(final_aswang): final_aswang.visible = false

	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")

@rpc("any_peer", "reliable")
func rpc_report_wrong_search_click() -> void:
	# Server-only: apply penalty and broadcast to everyone
	if not multiplayer.is_server():
		return
	if _failed:
		return
	# if not _search_mode:
		# Optional: only punish if the search puzzle is currently active
		# return

	_apply_penalty_attack_server()
	
func _apply_penalty_attack_server() -> void:
	# Penalty pushes Aswang faster (same system as scheduled attacks)
	_attack_index += 1

	# If reaching final, fail immediately
	if _attack_index >= 10:
		_fail_zone_server()
		return

	# Broadcast the attack to BOTH peers
	rpc_play_aswang_attack.rpc(_attack_index, true)

@rpc("any_peer", "reliable")
func rpc_request_consequence_state() -> void:
	if not multiplayer.is_server():
		return
	# reply only to the requester
	var peer := multiplayer.get_remote_sender_id()
	rpc_apply_consequence_state.rpc_id(peer, _attack_index, _time_left, _failed)
	
@rpc("any_peer", "reliable", "call_local")
func rpc_apply_consequence_state(attack_idx: int, time_left: int, failed: bool) -> void:
	_attack_index = attack_idx
	_time_left = time_left
	_failed = failed

	# If already failed, show fail UI (optional)
	if _failed:
		return

	# Show the latest window sprite so late joiners "catch up"
	if _attack_index >= 1 and _attack_index <= 9 and is_instance_valid(aswang_sprite):
		aswang_sprite.texture = _aswang_window_frames[_attack_index - 1]
		aswang_sprite.visible = true

@rpc("any_peer", "reliable", "call_local")
func rpc_play_validation_feedback(dialogue_id: String) -> void:
	# 1) extreme shake first
	_screen_shake_extreme_local()

	# 2) then show the one-line warning dialogue
	rpc_play_validation_dialogue(dialogue_id) # call local function (no .rpc)
	
func _screen_shake_extreme_local() -> void:
	_shake_duration = 0.6
	_shake_amplitude = 20.0
	_shake_elapsed = 0.0
	_shake_origin = position

	if _shake_timer == null:
		_shake_timer = Timer.new()
		_shake_timer.wait_time = 0.02
		_shake_timer.one_shot = false
		_shake_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_shake_timer)
		_shake_timer.timeout.connect(_on_final_shake_tick)

	_shake_timer.start()

func _send_wrong_click_to_server() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		rpc_report_wrong_search_click()
	else:
		rpc_report_wrong_search_click.rpc_id(_SERVER_PEER_ID)

func _screen_shake_attack_local(from_penalty: bool) -> void:
	# Violent shake for EVERY aswang attack.
	# Penalty attacks can be slightly stronger.
	_shake_duration = 0.55 if not from_penalty else 0.75
	_shake_amplitude = 20.0 if not from_penalty else 28.0
	_shake_elapsed = 0.0
	_shake_origin = position

	if _shake_timer == null:
		_shake_timer = Timer.new()
		_shake_timer.wait_time = 0.02
		_shake_timer.one_shot = false
		_shake_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_shake_timer)
		_shake_timer.timeout.connect(_on_final_shake_tick)

	_shake_timer.start()

@rpc("any_peer", "reliable", "call_local")
func rpc_fail_pre_shake() -> void:
	# Shake the WORLD first (your attack shake system)
	_screen_shake_attack_local(true)
	
@rpc("any_peer", "reliable", "call_local")
func rpc_fail_show_ui() -> void:
	# show parent layer
	if is_instance_valid(consequence_ui):
		consequence_ui.visible = true
		consequence_ui.layer = 100

	# blackout INSTANT (no fade)
	if is_instance_valid(blackout):
		blackout.visible = true
		var c := blackout.color
		c.a = 1.0
		blackout.color = c
		blackout.z_index = 0

	# final aswang on top
	if is_instance_valid(final_aswang):
		final_aswang.visible = true
		final_aswang.texture = _aswang_final_frame
		final_aswang.z_index = 1
