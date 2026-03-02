extends Node2D

## Pina's House - Indoor zone with pause functionality + role-based note boards

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton

# Pause / settings UI (teammate)
@onready var inside_zone_control: CanvasLayer = $InsideZoneControl
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeSlider
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


func _ready() -> void:
	print("[PinasHouse] Scene loaded!")

	# Teammate: Play Pina's House background music
	if Engine.has_singleton("MusicController") or MusicController:
		MusicController.play_track(MusicController.MusicTrack.PINAS_HOUSE)

	# Show saved position info (teammate)
	var saved_pos = GameState.get_spawn_position(multiplayer.get_unique_id())
	if saved_pos != Vector2.ZERO:
		print("[PinasHouse] Will return to Forest Hub at position: ", saved_pos)

	# Signals: clue + role assigned (merge-safe guarded connections)
	if not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)
	if not GameState.player_role_assigned.is_connected(_on_role_assigned):
		GameState.player_role_assigned.connect(_on_role_assigned)

	# Teammate: Setup pause functionality
	_setup_pause_controls()

	# You: role label + overlays
	_update_role_label()
	update_role_visibility()

	# You: hide boards by default
	if is_instance_valid(detective_board):
		detective_board.visible = false
	if is_instance_valid(sidekick_board):
		sidekick_board.visible = false

	# You: connect close buttons (guarded)
	if is_instance_valid(detective_close) and not detective_close.pressed.is_connected(_close_boards):
		detective_close.pressed.connect(_close_boards)
	if is_instance_valid(sidekick_close) and not sidekick_close.pressed.is_connected(_close_boards):
		sidekick_close.pressed.connect(_close_boards)

	# Back button (guarded)
	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	# Note tap opens board (guarded)
	if is_instance_valid(note_btn) and not note_btn.pressed.is_connected(_on_note_pressed):
		note_btn.pressed.connect(_on_note_pressed)
		
	# Puzzle 2: tool hunt interactions + initial lock state
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
	# Close both first
	_close_boards()

	if GameState.local_role == GameState.Role.DETECTIVE:
		detective_board.visible = true
		if GameState.is_puzzle_solved("pinas_house"):
			_apply_solved_text()
		else:
			_apply_unsolved_text()
	elif GameState.local_role == GameState.Role.SIDEKICK:
		sidekick_board.visible = true
		if sidekick_board.has_method("open_board"):
			sidekick_board.open_board()


func _close_boards() -> void:
	if is_instance_valid(detective_board):
		detective_board.visible = false
	if is_instance_valid(sidekick_board):
		sidekick_board.visible = false


func _apply_unsolved_text() -> void:
	var p := PuzzleManager.get_puzzle_for_zone("pinas_house")
	var eqs: Array = p.get("equations", [])
	var txt := "Cooking Tools Inventory\n\n"
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
			"Cooking Tools Inventory \n\n"
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

	# Sidekick board needs to show the solved values on reopen too
	if is_instance_valid(sidekick_board) and sidekick_board.has_method("apply_solved_view"):
		sidekick_board.apply_solved_view()
	
	# Puzzle 2 unlocks now (applies on all peers because this RPC is call_local)
	_set_tools_unlocked_local(true)

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


@rpc("any_peer", "reliable", "call_local")
func rpc_set_tools_unlocked(unlocked: bool) -> void:
	_set_tools_unlocked_local(unlocked)


@rpc("any_peer", "reliable", "call_local")
func rpc_reveal_pinas_house_clue() -> void:
	# Reveal in both clients by collecting locally
	GameState.collect_clue("pinas_house")


func _set_tools_unlocked_local(unlocked: bool) -> void:
	_tools_unlocked = unlocked
	_apply_tool_nodes()


func _apply_tool_nodes() -> void:
	_apply_single_tool("pan", pan_prop, pan_collision)
	_apply_single_tool("ladle", ladle_prop, ladle_collision)
	_apply_single_tool("pot", pot_prop, pot_collision)


func _apply_single_tool(tool_id: String, area: Area2D, col: CollisionShape2D) -> void:
	# Item exists in the world always, but can only be collected after unlock
	var collected: bool = bool(_tools_collected.get(tool_id, false))
	var unlocked: bool = _tools_unlocked

	var can_interact: bool = unlocked and not collected
	var should_show: bool = not collected  # visible until collected, regardless of unlock

	if is_instance_valid(area):
		area.visible = should_show
		_set_area_pickable(area, can_interact)
	if is_instance_valid(col):
		col.disabled = not can_interact


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
