extends Node2D

const PauseControllerScript = preload("res://scripts/world/zones/pinasHouse/controllers/pinas_house_pause_controller.gd")
const NoteControllerScript = preload("res://scripts/world/zones/pinasHouse/controllers/pinas_house_note_controller.gd")
const ToolHuntControllerScript = preload("res://scripts/world/zones/pinasHouse/controllers/pinas_house_tool_hunt_controller.gd")
const ConsequenceControllerScript = preload("res://scripts/world/zones/pinasHouse/controllers/pinas_house_consequence_controller.gd")

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton

# Pause / settings UI
@onready var inside_zone_control: CanvasLayer = $InsideZoneControl
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/HBoxContainer/VolumeValue

# Role overlays + boards
@onready var detective_overlays: Node = $RoleLayer/Control/DetectiveOverlays
@onready var sidekick_overlays: Node = $RoleLayer/Control/SidekickOverlays

@onready var detective_board: Control = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective
@onready var sidekick_board: Control = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick
@onready var detective_text: Label = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/DetectiveText

@onready var detective_close: Button = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/Close
@onready var sidekick_close: Button = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick/SidekickNote/Close
@onready var note_btn: TextureButton = $RoleLayer/Control/NoteTapButton

# Puzzle 2 tools
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

# Consequence visuals
@onready var aswang_sprite: Sprite2D = get_node("InteractiveLayer/Aswang Window/AswangSprite")
@onready var consequence_ui: CanvasLayer = $ConsequenceUI
@onready var blackout: ColorRect = $ConsequenceUI/Blackout
@onready var final_aswang: Sprite2D = $ConsequenceUI/FinalAswang

#Reward System
@onready var reward_layer = $RewardLayer
@onready var reward_banner = $RewardLayer/RewardBanner
@onready var reward_text = $RewardLayer/RewardText
@onready var clue_sprite = $RewardLayer/ClueSprite
@onready var sparkle = $RewardLayer/Sparkle
@onready var collect_button = $RewardLayer/CollectButton
@onready var dark_overlay = $RewardLayer/DarkOverlay

const _SERVER_PEER_ID := 1
const _TOOL_IDS := ["pan", "ladle", "pot"]

const TOTAL_TIME_SEC := 300
const ATTACK_INTERVAL_SEC := 30
const PENALTY_SEC := 45
const MAX_ATTACKS := 10
const FIRST_ATTACK_DELAY_SEC := 10

@warning_ignore("unused_private_class_variable")
var _search_mode := false
@warning_ignore("unused_private_class_variable")
var _tools_unlocked := false
@warning_ignore("unused_private_class_variable")
var _tools_collected := {
	"pan": false,
	"ladle": false,
	"pot": false,
}

var clue_collected := false
@warning_ignore("unused_private_class_variable")
var _detective_note_seen := false
@warning_ignore("unused_private_class_variable")
var _note_dialogue_played := false
var _intro_dialogue_played := false

var _time_left := TOTAL_TIME_SEC
var _attack_index := 0
var _failed := false

@warning_ignore("unused_private_class_variable")
var _tick_timer: Timer
@warning_ignore("unused_private_class_variable")
var _attack_timer: Timer
@warning_ignore("unused_private_class_variable")
var _first_attack_timer: Timer

@warning_ignore("unused_private_class_variable")
var _first_warning_played := false

@warning_ignore("unused_private_class_variable")
var _shake_timer: Timer
@warning_ignore("unused_private_class_variable")
var _shake_elapsed := 0.0
@warning_ignore("unused_private_class_variable")
var _shake_duration := 0.0
@warning_ignore("unused_private_class_variable")
var _shake_amplitude := 0.0
@warning_ignore("unused_private_class_variable")
var _shake_origin := Vector2.ZERO

@warning_ignore("unused_private_class_variable")
var _shadow_tex := {
	"ladle": preload("res://assets/sprites/zoneObjects/Zone 1 Objects/Shadow - Ladle.png"),
	"pan": preload("res://assets/sprites/zoneObjects/Zone 1 Objects/Shadow - Pan.png"),
	"pot": preload("res://assets/sprites/zoneObjects/Zone 1 Objects/Shadow - Pot.png"),
}

@warning_ignore("unused_private_class_variable")
var _reveal_tex := {
	"ladle": preload("res://assets/sprites/zoneObjects/Zone 1 Objects/Reveal - Ladle.png"),
	"pan": preload("res://assets/sprites/zoneObjects/Zone 1 Objects/Reveal - Pan.png"),
	"pot": preload("res://assets/sprites/zoneObjects/Zone 1 Objects/Reveal - Pot.png"),
}

@warning_ignore("unused_private_class_variable")
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

@warning_ignore("unused_private_class_variable")
var _aswang_final_frame: Texture2D = preload("res://assets/sprites/consequences/aswang/aswang10.png")

var pause_controller
var note_controller
var tool_hunt_controller
var consequence_controller


func _ready() -> void:
	print("[PinasHouse] Scene loaded!")
	
	reward_layer.visible = false

	dark_overlay.modulate.a = 0
	sparkle.visible = false
	reward_banner.visible = false
	clue_sprite.visible = false
	collect_button.visible = false

	_init_controllers()
	_connect_global_signals()
	_setup_music()
	_setup_scene()

	_update_role_label()
	update_role_visibility()
	
	collect_button.pressed.connect(_on_collect_clue_pressed)

	pause_controller.setup(self)
	consequence_controller.setup(self)
	tool_hunt_controller.setup(self)
	note_controller.setup(self)

	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	_start_intro_dialogue_delayed()

	if (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server():
		consequence_controller.start_server()


func _init_controllers() -> void:
	pause_controller = PauseControllerScript.new()
	note_controller = NoteControllerScript.new()
	tool_hunt_controller = ToolHuntControllerScript.new()
	consequence_controller = ConsequenceControllerScript.new()


func _connect_global_signals() -> void:
	if not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)

	if not GameState.player_role_assigned.is_connected(_on_role_assigned):
		GameState.player_role_assigned.connect(_on_role_assigned)


func _setup_music() -> void:
	if Engine.has_singleton("MusicController") or MusicController:
		MusicController.play_track(MusicController.MusicTrack.PINAS_HOUSE)


func _setup_scene() -> void:
	var saved_pos = GameState.get_spawn_position(multiplayer.get_unique_id())
	if saved_pos != Vector2.ZERO:
		print("[PinasHouse] Will return to Forest Hub at position: ", saved_pos)


func _start_intro_dialogue_delayed() -> void:
	if _intro_dialogue_played:
		return

	_intro_dialogue_played = true
	DialogueSystems.play("pinas_house_enter", DialogueLibraries.PINAS_HOUSE_ENTER)


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
		role_label.text = "Clue collected! Returning..."
		await get_tree().create_timer(3.0).timeout
		_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


func _exit_tree() -> void:
	if pause_controller:
		pause_controller.cleanup()


# =========================
# Pause wrappers
# =========================

func _setup_pause_controls() -> void:
	pause_controller.setup(self)


func _on_pause_button_pressed() -> void:
	pause_controller.on_pause_button_pressed()


func _on_resume_play_button_pressed() -> void:
	pause_controller.on_resume_play_button_pressed()


func _on_option_button_pressed() -> void:
	pause_controller.on_option_button_pressed()


func _on_in_game_option_back_pressed() -> void:
	pause_controller.on_in_game_option_back_pressed()


func _on_exit_to_main_menu_button_pressed() -> void:
	await pause_controller.on_exit_to_main_menu_button_pressed()


func _on_in_game_volume_changed(value: float) -> void:
	pause_controller.on_in_game_volume_changed(value)


func _save_settings() -> void:
	pause_controller.save_settings()


# =========================
# Note wrappers
# =========================

func _on_note_pressed() -> void:
	note_controller.on_note_pressed()


func _on_note_interacted() -> void:
	note_controller.on_note_interacted()


func _mark_detective_note_seen() -> void:
	note_controller.mark_detective_note_seen()


@rpc("any_peer", "reliable")
func rpc_request_detective_note_seen() -> void:
	if not multiplayer.is_server():
		return
	note_controller.set_detective_note_seen_local(true)
	rpc_set_detective_note_seen.rpc(true)


@rpc("any_peer", "reliable", "call_local")
func rpc_set_detective_note_seen(seen: bool) -> void:
	note_controller.set_detective_note_seen_local(seen)


func _set_detective_note_seen_local(seen: bool) -> void:
	note_controller.set_detective_note_seen_local(seen)


func _close_boards(force: bool = false) -> void:
	note_controller.close_boards(force)


func _apply_close_button_visibility() -> void:
	note_controller.apply_close_button_visibility()


func _apply_unsolved_text() -> void:
	note_controller.apply_unsolved_text()


func _apply_solved_text() -> void:
	note_controller.apply_solved_text()


func _on_sidekick_solved() -> void:
	note_controller.on_sidekick_solved()


@rpc("any_peer", "reliable", "call_local")
func rpc_pinas_house_solved() -> void:
	await note_controller.after_puzzle1_solved()


# =========================
# Tool hunt wrappers
# =========================

func _setup_tool_hunt() -> void:
	tool_hunt_controller.setup(self)


func _on_tool_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, tool_id: String) -> void:
	tool_hunt_controller.on_tool_input_event(_viewport, event, _shape_idx, tool_id)


func _try_collect_tool(tool_id: String) -> void:
	tool_hunt_controller.try_collect_tool(tool_id)


@rpc("any_peer", "reliable")
func rpc_request_collect_tool(tool_id: String) -> void:
	if not multiplayer.is_server():
		return
	tool_hunt_controller.server_collect_tool(tool_id, multiplayer.get_remote_sender_id())


func _server_collect_tool(tool_id: String, _sender_peer_id: int) -> void:
	tool_hunt_controller.server_collect_tool(tool_id, _sender_peer_id)


@rpc("any_peer", "reliable", "call_local")
func rpc_set_tool_collected(tool_id: String) -> void:
	tool_hunt_controller.set_tool_collected_local(tool_id)


@rpc("any_peer", "reliable", "call_local")
func rpc_set_tools_unlocked(unlocked: bool) -> void:
	tool_hunt_controller.set_tools_unlocked_local(unlocked)


@rpc("any_peer", "reliable", "call_local")
func rpc_reveal_pinas_house_clue() -> void:
	GameState.collect_clue("pinas_house")


@rpc("any_peer", "reliable")
func rpc_request_validation_dialogue(dialogue_id: String) -> void:
	if not multiplayer.is_server():
		return

	if dialogue_id == "numbers_only" or dialogue_id == "wrong_answer":
		consequence_controller.apply_penalty_server(dialogue_id)

	rpc_play_validation_feedback.rpc(dialogue_id)


@rpc("any_peer", "reliable", "call_local")
func rpc_play_validation_dialogue(dialogue_id: String) -> void:
	await tool_hunt_controller.play_validation_dialogue(dialogue_id)


func _set_tools_unlocked_local(unlocked: bool) -> void:
	tool_hunt_controller.set_tools_unlocked_local(unlocked)


func _apply_tool_nodes() -> void:
	tool_hunt_controller.apply_tool_nodes()


func _apply_single_tool(tool_id: String, area: Area2D, col: CollisionShape2D) -> void:
	tool_hunt_controller.apply_single_tool(tool_id, area, col)


func _setup_search_room_buttons() -> void:
	tool_hunt_controller.setup_search_room_buttons()


func _on_search_room_pressed() -> void:
	tool_hunt_controller.on_search_room_pressed()


func _set_search_mode_local(enable: bool) -> void:
	tool_hunt_controller.set_search_mode_local(enable)


func _apply_note_interaction_gate() -> void:
	note_controller.apply_note_interaction_gate()


func _apply_banner_frames() -> void:
	tool_hunt_controller.apply_banner_frames()


func _set_area_pickable(area: Area2D, pickable: bool) -> void:
	tool_hunt_controller.set_area_pickable(area, pickable)


func _all_tools_collected() -> bool:
	return tool_hunt_controller.all_tools_collected()


func _on_wrong_object_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	tool_hunt_controller.on_wrong_object_input(_viewport, event, _shape_idx)


# =========================
# Consequence wrappers
# =========================

func _start_consequences_server() -> void:
	consequence_controller.start_server()


func _on_first_attack_server() -> void:
	consequence_controller.on_first_attack_server()


@rpc("any_peer", "reliable", "call_local")
func rpc_play_first_attack_warning() -> void:
	consequence_controller.play_first_attack_warning()


func _on_tick_server() -> void:
	consequence_controller.on_tick_server()


func _on_scheduled_attack_server() -> void:
	consequence_controller.on_scheduled_attack_server()


@rpc("any_peer", "reliable")
func rpc_request_penalty(reason: String) -> void:
	if not multiplayer.is_server():
		return
	consequence_controller.apply_penalty_server(reason)


func _apply_penalty_server(_reason: String) -> void:
	consequence_controller.apply_penalty_server(_reason)


@rpc("any_peer", "reliable", "call_local")
func rpc_play_aswang_attack(idx: int, from_penalty: bool) -> void:
	consequence_controller.play_aswang_attack(idx, from_penalty)


func _play_final_aswang_overlay() -> void:
	consequence_controller.play_final_aswang_overlay()


func _screen_shake_local(stronger: bool) -> void:
	consequence_controller.screen_shake_local(stronger)


func _fail_zone_server() -> void:
	await consequence_controller.fail_zone_server()


func _screen_shake_final_local() -> void:
	consequence_controller.screen_shake_final_local()


func _on_final_shake_tick() -> void:
	consequence_controller.on_final_shake_tick()


@rpc("any_peer", "reliable", "call_local")
func rpc_reset_pinas_house_progress() -> void:
	consequence_controller.reset_pinas_house_progress_local()


@rpc("any_peer", "reliable", "call_local")
func rpc_lock_pinas_house_zone(duration_sec: int) -> void:
	consequence_controller.lock_pinas_house_zone_local(duration_sec)


@rpc("any_peer", "reliable", "call_local")
func rpc_kick_to_hub() -> void:
	consequence_controller.kick_to_hub_local()


@rpc("any_peer", "reliable")
func rpc_report_wrong_search_click() -> void:
	if not multiplayer.is_server():
		return

	if _failed:
		return

	consequence_controller.apply_penalty_attack_server()


func _apply_penalty_attack_server() -> void:
	consequence_controller.apply_penalty_attack_server()


@rpc("any_peer", "reliable")
func rpc_request_consequence_state() -> void:
	if not multiplayer.is_server():
		return

	var peer := multiplayer.get_remote_sender_id()
	rpc_apply_consequence_state.rpc_id(peer, _attack_index, _time_left, _failed)


@rpc("any_peer", "reliable", "call_local")
func rpc_apply_consequence_state(attack_idx: int, time_left: int, failed: bool) -> void:
	consequence_controller.apply_consequence_state(attack_idx, time_left, failed)


@rpc("any_peer", "reliable", "call_local")
func rpc_play_validation_feedback(dialogue_id: String) -> void:
	consequence_controller.play_validation_feedback(dialogue_id)


func _screen_shake_extreme_local() -> void:
	consequence_controller.screen_shake_extreme_local()


func _send_wrong_click_to_server() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		rpc_report_wrong_search_click()
	else:
		rpc_report_wrong_search_click.rpc_id(_SERVER_PEER_ID)


func _screen_shake_attack_local(from_penalty: bool) -> void:
	consequence_controller.screen_shake_attack_local(from_penalty)


@rpc("any_peer", "reliable", "call_local")
func rpc_fail_pre_shake() -> void:
	consequence_controller.fail_pre_shake()


@rpc("any_peer", "reliable", "call_local")
func rpc_fail_show_ui() -> void:
	consequence_controller.fail_show_ui()

#Reward System Function
func show_reward() -> void:
	print("Starting reward sequence")

	get_tree().paused = true
	reward_layer.visible = true

	await reward_sequence()
	
func reward_sequence() -> void:

	# Reset visuals
	sparkle.visible = false
	reward_banner.visible = false
	clue_sprite.visible = false
	collect_button.visible = false

	# STEP 1 — darken screen
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(dark_overlay, "modulate:a", 0.7, 0.6)
	await tween.finished

	await get_tree().create_timer(0.4, true).timeout

	# STEP 2 — sparkle appears
	sparkle.visible = true

	await get_tree().create_timer(0.6, true).timeout

	# STEP 3 — banner appears
	reward_banner.visible = true

	var reward_data = PuzzleManager.PUZZLE_DATA["pinas_house"]["reward"]
	reward_text.text = reward_data["note"]

	await get_tree().create_timer(0.6, true).timeout

	# STEP 4 — reveal clue
	clue_sprite.visible = true

	await get_tree().create_timer(0.6, true).timeout

	# STEP 5 — show collect button only for sidekick (or always in offline play)
	if multiplayer.has_multiplayer_peer():
		collect_button.visible = GameState.local_role == GameState.Role.SIDEKICK
	else:
		# In offline/single-player, always allow collecting so the game can proceed
		collect_button.visible = true
	

@rpc("any_peer", "call_local", "reliable")
func rpc_show_pinas_house_reward() -> void:
	show_reward()

func _on_collect_clue_pressed() -> void:

	var reward_data = PuzzleManager.PUZZLE_DATA["pinas_house"]["reward"]
	var clue_name = reward_data["clue"]

	# Record clue collection using the authoritative GameState system
	GameState.collect_clue("pinas_house")

	print("Collected clue:", clue_name)

	get_tree().paused = false

	# Exit for both players
	rpc_exit_pinas_house.rpc()
	
@rpc("any_peer", "call_local", "reliable")
func rpc_exit_pinas_house():
	exit_zone()

func exit_zone() -> void:

	print("Exiting Pinas House")

	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
