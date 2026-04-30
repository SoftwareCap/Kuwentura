extends Node2D

const PauseControllerScript = preload("res://scripts/world/zones/pinasHouse/controllers/pinas_house_pause_controller.gd")
const NoteControllerScript = preload("res://scripts/world/zones/pinasHouse/controllers/pinas_house_note_controller.gd")
const ToolHuntControllerScript = preload("res://scripts/world/zones/pinasHouse/controllers/pinas_house_tool_hunt_controller.gd")
const ConsequenceControllerScript = preload("res://scripts/world/zones/pinasHouse/controllers/pinas_house_consequence_controller.gd")

const PROGRESS_DEFAULT_TEX: Texture2D = preload("res://assets/sprites/tracker/pinasHouse/defaultPH.png")
const PROGRESS_PUZZLE1_TEX: Texture2D = preload("res://assets/sprites/tracker/pinasHouse/puzzle1PH.png")
const PROGRESS_PUZZLE2_TEX: Texture2D = preload("res://assets/sprites/tracker/pinasHouse/puzzle2PH.png")
const PROGRESS_PUZZLE3_TEX: Texture2D = preload("res://assets/sprites/tracker/pinasHouse/puzzle3PH.png")

const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"

const _SERVER_PEER_ID := 1
const _TOOL_IDS := ["pan", "ladle", "pot"]
const MAX_ATTACKS := 10
const PENALTY_COOLDOWN_SEC := 0.75

const SPARKLE_MIN_SCALE := 0.45
const SPARKLE_MAX_SCALE := 0.55
const SPARKLE_PULSE_SPEED := 4.0

const NOTE_REVEAL_SHAKE_OFFSET: float = 10.0
const NOTE_REVEAL_SHAKE_STEP: float = 0.05
const NOTE_REVEAL_SHAKE_COUNT: int = 4
const QUEST_PANEL_POS := Vector2(28, 210)
const QUEST_PANEL_WIDTH := 390.0
const QUEST_HEADER_HEIGHT := 38.0
const QUEST_ROW_HEIGHT := 40.0
const QUEST_ROW_GAP := 6.0
const QUEST_TEXT_LEFT_PADDING := 14.0
const QUEST_DONE_ALPHA := 0.45
const UI_BROWN := Color(0.55, 0.31, 0.12, 1.0)
const UI_DIM_PANEL := Color(0.19, 0.12, 0.06, 0.64)
const UI_ACTIVE_PANEL := Color(0.28, 0.17, 0.08, 0.76)
const UI_QUEST_DONE := Color(0.72, 0.68, 0.61, 1.0)
const UI_FOCUS_BROWN := Color(0.31, 0.16, 0.06, 0.70)

@onready var role_label: Label = get_node_or_null("RoleLabel")
@onready var back_button: Button = get_node_or_null("BackButton")
@onready var players_node: Node = get_node_or_null("Players")
@onready var detective_player: Node2D = get_node_or_null("Players/Detective")
@onready var sidekick_player: Node2D = get_node_or_null("Players/Sidekick")

@onready var inside_zone_control: CanvasLayer = $InsideZoneControl
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue

@onready var detective_overlays: Node = $RoleLayer/Control/DetectiveOverlays
@onready var sidekick_overlays: Node = $RoleLayer/Control/SidekickOverlays
@onready var detective_board: Control = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective
@onready var sidekick_board: Control = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick
@onready var detective_text: Label = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/DetectiveText
@onready var detective_close: Button = $RoleLayer/Control/DetectiveOverlays/NoteBoardDetective/Close
@onready var sidekick_close: Button = $RoleLayer/Control/SidekickOverlays/NoteBoardSidekick/SidekickNote/Close

@onready var guidance_arrow: CanvasItem = get_node_or_null("RoleLayer/Control/GuidanceArrow")
@onready var notification_ui: Node = get_node_or_null("Notification")
@onready var notification_panel: Sprite2D = get_node_or_null("Notification/Sprite2D")
@onready var notification_label: Label = get_node_or_null("Notification/NotificationLabel")

@onready var ledger_panel: Panel = get_node_or_null("SidekickLayer/Ledger")
@onready var briefcase_panel: Panel = get_node_or_null("SidekickLayer/Briefcase")
@onready var briefcase_display: TextureRect = get_node_or_null("SidekickLayer/Briefcase/BriefcaseDisplay")

@onready var note_area: Area2D = $InteractiveLayer/Notes
@onready var note_sprite: Sprite2D = $InteractiveLayer/Notes/NotesSprite
@onready var note_collision: CollisionShape2D = $InteractiveLayer/Notes/NotesCollision
@onready var note_btn: TextureButton = $RoleLayer/Control/NoteTapButton
@onready var cabinet_area: Area2D = $InteractiveLayer/Cabinet
@onready var wrong_click_zone: Area2D = $InteractiveLayer/Objects/WrongClickZone

@onready var pan_prop: Area2D = $InteractiveLayer/PanProp
@onready var ladle_prop: Area2D = $InteractiveLayer/LadleProp
@onready var pot_prop: Area2D = $InteractiveLayer/PotProp

@onready var pan_collision: CollisionShape2D = $InteractiveLayer/PanProp/PanCollision
@onready var ladle_collision: CollisionShape2D = $InteractiveLayer/LadleProp/LadleCollision
@onready var pot_collision: CollisionShape2D = $InteractiveLayer/PotProp/PotCollision

@onready var search_room_ui: CanvasLayer = $SearchRoomUI
@onready var frame_ladle: TextureRect = $SearchRoomUI/Root/Banner/FramesRow/Frame_Ladle
@onready var frame_pan: TextureRect = $SearchRoomUI/Root/Banner/FramesRow/Frame_Pan
@onready var frame_pot: TextureRect = $SearchRoomUI/Root/Banner/FramesRow/Frame_Pot
@onready var search_room_label: Label = $SearchRoomUI/Root/Label

@onready var aswang_sprite: Sprite2D = $"InteractiveLayer/Aswang Window/AswangSprite"
@onready var consequence_ui: CanvasLayer = $ConsequenceUI
@onready var blackout: ColorRect = $ConsequenceUI/Blackout
@onready var final_aswang: Sprite2D = $ConsequenceUI/FinalAswang

@onready var reward_layer: CanvasLayer = $RewardLayer
@onready var reward_text: Label = $RewardLayer/RewardPanel/RewardText
@onready var banner_label: Label = $RewardLayer/BannerLabel
@onready var clue_sprite: Sprite2D = $RewardLayer/ClueSprite
@onready var sparkle: Sprite2D = $RewardLayer/Sparkle
@onready var collect_button: Node = $RewardLayer/CollectButton
@onready var dark_overlay: Node = $RewardLayer/DarkOverlay
@onready var tap_instruction_label: Label = $RewardLayer/TapInstruction
@onready var tap_catcher: Node = $RewardLayer/TapCatcher
@onready var briefcase_reveal_sprite: TextureRect = $RewardLayer/BriefcaseRevealSprite

@onready var inside_zone_ledger_button: TouchScreenButton = get_node_or_null("InsideZoneControl/Ledger")
@onready var inside_zone_briefcase_button: TouchScreenButton = get_node_or_null("InsideZoneControl/Briefcase")

@onready var ledger_title_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerTitle")
@onready var ledger_left_header_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerLeftHeader")
@onready var ledger_left_body_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerLeftBody")
@onready var ledger_right_header_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerRightHeader")
@onready var ledger_right_body_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerRightBody")

@onready var cabinet_open_sprite: Sprite2D = $InteractiveLayer/Cabinet/OpenCabinet
@onready var cabinet_collision: CollisionShape2D = $InteractiveLayer/Cabinet/Cabinet
@onready var cabinet_ladle_area: Area2D = $InteractiveLayer/Cabinet/LadleInCabinet
@onready var cabinet_ladle_sprite: Sprite2D = $InteractiveLayer/Cabinet/LadleInCabinet/LadleSprite
@onready var cabinet_ladle_collision: CollisionShape2D = $InteractiveLayer/Cabinet/LadleInCabinet/LadleCollision
@onready var reward_panel: Sprite2D = $RewardLayer/RewardPanel

@onready var progress_tracker: Node = get_node_or_null("ProgressTracker")
@onready var progress_tracker_sprite: Sprite2D = get_node_or_null("ProgressTracker/Sprite2D")

@onready var ending_cutscene: VideoStreamPlayer = $Cutscene/EndingCutscene

var quest_layer: Node2D
var quest_title_label: Label
var _quest_style_ready: bool = false
var _quest_labels: Array[Label] = []
var _quest_row_backgrounds: Array[ColorRect] = []
var _quest_toggle_button: Button
var _quest_expanded: bool = false
var _quest_active_index: int = 0
var _focus_overlay: ColorRect
var _dialogue_focus_active: bool = false

var _animation_time: float = 0.0
var _sparkle_animating: bool = false

var _cabinet_opened: bool = false
var _ladle_found: bool = false
var _waiting_reward_continue: bool = false
var _reward_stage: int = 0
var _collect_sequence_started: bool = false

var pause_controller: PauseControllerScript
var note_controller: NoteControllerScript
var tool_hunt_controller: ToolHuntControllerScript
var consequence_controller: ConsequenceControllerScript

var clue_collected: bool = false
var _intro_dialogue_played: bool = false
var _intro_flow_started: bool = false

var _zone_active: bool = false
var _tool_phase_active: bool = false
var _note_phase_active: bool = false
var _cabinet_phase_active: bool = false
var _reward_active: bool = false

var _note_solved: bool = false
var _detective_note_seen: bool = false
var _note_dialogue_played: bool = false
var _ledger_hint_shown: bool = false
var _ledger_opened_once: bool = false
var _dialogue_input_locked: bool = false

var _tools_unlocked: bool = false
var _tools_collected: Dictionary = {"pan": false, "ladle": false, "pot": false}

var _strikes_left: int = MAX_ATTACKS
var _attack_index: int = 0
var _failed: bool = false
var _consequence_active: bool = false
var _penalty_on_cooldown: bool = false

var _sfx_player: AudioStreamPlayer
var _zone_completion_sfx: AudioStream = preload("res://assets/audios/ZoneCompletionSFX.mp3")

var _shake_timer: Timer = null
var _shake_elapsed: float = 0.0
var _shake_duration: float = 0.0
var _shake_amplitude: float = 0.0
var _shake_origin: Vector2 = Vector2.ZERO

var _intro_ready_peers: Dictionary = {}

var _puzzle_data: Dictionary = {}
var _puzzle_data_ready: bool = false

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


func _ensure_quest_nodes() -> void:
	quest_layer = get_node_or_null("QuestLayer") as Node2D
	if not is_instance_valid(quest_layer):
		quest_layer = Node2D.new()
		quest_layer.name = "QuestLayer"
		quest_layer.z_index = 80
		add_child(quest_layer)

	quest_title_label = quest_layer.get_node_or_null("QuestTitle") as Label
	if not is_instance_valid(quest_title_label):
		quest_title_label = Label.new()
		quest_title_label.name = "QuestTitle"
		quest_layer.add_child(quest_title_label)

	while _quest_labels.size() < 5:
		var label := Label.new()
		label.name = "QuestTask" + str(_quest_labels.size() + 1)
		quest_layer.add_child(label)
		_quest_labels.append(label)


func _setup_quest_panel_style() -> void:
	_ensure_quest_nodes()
	if not is_instance_valid(quest_layer):
		return

	_quest_row_backgrounds.clear()

	var header_bar := quest_layer.get_node_or_null("QuestHeaderBar") as ColorRect
	if not is_instance_valid(header_bar):
		header_bar = ColorRect.new()
		header_bar.name = "QuestHeaderBar"
		quest_layer.add_child(header_bar)
		quest_layer.move_child(header_bar, 0)

	header_bar.position = QUEST_PANEL_POS
	header_bar.size = Vector2(QUEST_PANEL_WIDTH, QUEST_HEADER_HEIGHT)
	header_bar.color = UI_BROWN
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_bar.z_index = 0

	if is_instance_valid(quest_title_label):
		quest_title_label.text = "PINAS HOUSE QUEST"
		quest_title_label.position = QUEST_PANEL_POS + Vector2(12.0, 0.0)
		quest_title_label.size = Vector2(QUEST_PANEL_WIDTH - 24.0, QUEST_HEADER_HEIGHT)
		quest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		quest_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quest_title_label.add_theme_font_size_override("font_size", 17)
		quest_title_label.add_theme_color_override("font_color", Color.WHITE)
		quest_title_label.add_theme_constant_override("outline_size", 2)
		quest_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.86))
		quest_title_label.z_index = 3

	_quest_toggle_button = quest_layer.get_node_or_null("QuestToggleButton") as Button
	if not is_instance_valid(_quest_toggle_button):
		_quest_toggle_button = Button.new()
		_quest_toggle_button.name = "QuestToggleButton"
		quest_layer.add_child(_quest_toggle_button)

	_quest_toggle_button.position = QUEST_PANEL_POS
	_quest_toggle_button.size = Vector2(QUEST_PANEL_WIDTH, QUEST_HEADER_HEIGHT)
	_quest_toggle_button.text = ""
	_quest_toggle_button.flat = true
	_quest_toggle_button.focus_mode = Control.FOCUS_NONE
	_quest_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_quest_toggle_button.self_modulate = Color(1, 1, 1, 0)
	_quest_toggle_button.z_index = 10
	if not _quest_toggle_button.pressed.is_connected(_on_quest_header_pressed):
		_quest_toggle_button.pressed.connect(_on_quest_header_pressed)

	for i in range(_quest_labels.size()):
		var label := _quest_labels[i]
		var row_pos := _get_quest_row_position(i)
		var bg_name := "QuestRowBG" + str(i + 1)
		var row_bg := quest_layer.get_node_or_null(bg_name) as ColorRect
		if not is_instance_valid(row_bg):
			row_bg = ColorRect.new()
			row_bg.name = bg_name
			quest_layer.add_child(row_bg)
			quest_layer.move_child(row_bg, 0)

		row_bg.position = row_pos
		row_bg.size = Vector2(QUEST_PANEL_WIDTH, QUEST_ROW_HEIGHT)
		row_bg.color = UI_DIM_PANEL
		row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_bg.z_index = 0

		label.position = row_pos + Vector2(QUEST_TEXT_LEFT_PADDING, 0.0)
		label.size = Vector2(QUEST_PANEL_WIDTH - (QUEST_TEXT_LEFT_PADDING * 2.0), QUEST_ROW_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = false
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.z_index = 2

		_quest_row_backgrounds.append(row_bg)

	_quest_style_ready = true


func _on_quest_header_pressed() -> void:
	_quest_expanded = not _quest_expanded
	_update_quest_labels()


func _get_quest_row_position(row_index: int) -> Vector2:
	return QUEST_PANEL_POS + Vector2(
		0.0,
		QUEST_HEADER_HEIGHT + 8.0 + float(row_index) * (QUEST_ROW_HEIGHT + QUEST_ROW_GAP)
	)


func _set_quest_task(index: int, text: String, done: bool, active: bool) -> void:
	if index < 0 or index >= _quest_labels.size():
		return

	var label := _quest_labels[index]
	if not is_instance_valid(label):
		return

	var row_bg: ColorRect = null
	if index < _quest_row_backgrounds.size():
		row_bg = _quest_row_backgrounds[index]

	var row_visible: bool = _quest_expanded or active
	var visible_row_index: int = index if _quest_expanded else 0
	var row_pos := _get_quest_row_position(visible_row_index)

	label.text = text
	label.set_meta("quest_done", done)
	label.visible = row_visible
	label.position = row_pos + Vector2(QUEST_TEXT_LEFT_PADDING, 0.0)
	label.size = Vector2(QUEST_PANEL_WIDTH - (QUEST_TEXT_LEFT_PADDING * 2.0), QUEST_ROW_HEIGHT)
	label.add_theme_font_size_override("font_size", 16 if active and not done else 15)
	label.add_theme_color_override("font_color", UI_QUEST_DONE if done else Color.WHITE)
	label.modulate = Color(1, 1, 1, QUEST_DONE_ALPHA) if done else Color.WHITE

	if is_instance_valid(row_bg):
		row_bg.visible = row_visible
		row_bg.position = row_pos
		row_bg.size = Vector2(QUEST_PANEL_WIDTH, QUEST_ROW_HEIGHT)
		if done:
			row_bg.color = Color(0.16, 0.12, 0.08, 0.44)
		elif active:
			row_bg.color = UI_ACTIVE_PANEL
		else:
			row_bg.color = UI_DIM_PANEL


func _all_search_tools_collected() -> bool:
	for tool_id in _TOOL_IDS:
		if not _tools_collected.get(tool_id, false):
			return false
	return true


func _update_quest_labels() -> void:
	if not _quest_style_ready:
		_setup_quest_panel_style()
	if not is_instance_valid(quest_layer):
		return

	var tool_done: bool = _all_search_tools_collected() or _note_phase_active or _note_solved or _cabinet_phase_active or _reward_active or _ladle_found or clue_collected
	var note_done: bool = _note_solved or _cabinet_phase_active or _reward_active or _ladle_found or clue_collected
	var cabinet_done: bool = _cabinet_opened or _ladle_found or clue_collected
	var ladle_done: bool = _ladle_found or clue_collected
	var artifact_done: bool = clue_collected

	var tasks: Array[String] = [
		"Find the missing tools",
		"Solve Pina's hidden note",
		"Open the cabinet",
		"Find the ladle artifact",
		"Collect the artifact"
	]
	var done_states: Array[bool] = [
		tool_done,
		note_done,
		cabinet_done,
		ladle_done,
		artifact_done
	]

	var previous_active_index: int = _quest_active_index
	_quest_active_index = done_states.find(false)
	if _quest_active_index == -1:
		_quest_active_index = done_states.size() - 1

	for i in range(tasks.size()):
		_set_quest_task(i, tasks[i], done_states[i], i == _quest_active_index)

	quest_layer.visible = _zone_active and not clue_collected and not _failed
	if previous_active_index != _quest_active_index and not _quest_expanded:
		_animate_current_quest_task()


func _animate_current_quest_task() -> void:
	if _quest_active_index < 0 or _quest_active_index >= _quest_labels.size():
		return

	var label := _quest_labels[_quest_active_index]
	if not is_instance_valid(label) or not label.visible:
		return

	var start_position := label.position
	var target_modulate := Color(1, 1, 1, QUEST_DONE_ALPHA) if bool(label.get_meta("quest_done", false)) else Color.WHITE
	label.position = start_position + Vector2(18.0, 0.0)
	label.modulate = Color(1, 1, 1, 0.35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", start_position, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", target_modulate, 0.22)


func _ensure_focus_overlay() -> void:
	_focus_overlay = get_node_or_null("FocusOverlay") as ColorRect
	if not is_instance_valid(_focus_overlay):
		_focus_overlay = ColorRect.new()
		_focus_overlay.name = "FocusOverlay"
		_focus_overlay.z_index = 90
		_focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_focus_overlay)

	_focus_overlay.position = Vector2.ZERO
	_focus_overlay.size = get_viewport_rect().size
	_focus_overlay.color = Color(UI_FOCUS_BROWN.r, UI_FOCUS_BROWN.g, UI_FOCUS_BROWN.b, 0.0)
	_focus_overlay.visible = false


func _is_note_board_open() -> bool:
	return (is_instance_valid(detective_board) and detective_board.visible) or (is_instance_valid(sidekick_board) and sidekick_board.visible)


func _refresh_focus_overlay() -> void:
	_ensure_focus_overlay()
	var should_show: bool = _dialogue_focus_active or _is_note_board_open()
	if not is_instance_valid(_focus_overlay):
		return

	_focus_overlay.size = get_viewport_rect().size
	if should_show:
		_focus_overlay.visible = true
		_focus_overlay.color = UI_FOCUS_BROWN
		if is_instance_valid(quest_layer):
			quest_layer.visible = false
	else:
		_focus_overlay.visible = false
		_focus_overlay.color = Color(UI_FOCUS_BROWN.r, UI_FOCUS_BROWN.g, UI_FOCUS_BROWN.b, 0.0)
		_update_quest_labels()


func _ready() -> void:
	_init_controllers()

	_connect_global_signals()
	_setup_music()

	_update_role_label()
	update_role_visibility()
	_refresh_inside_zone_buttons()
	_populate_ledger_content()
	_ensure_briefcase_display()
	_refresh_briefcase_display()

	if is_instance_valid(reward_layer):
		reward_layer.visible = false
		reward_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if is_instance_valid(dark_overlay):
		dark_overlay.modulate.a = 0.0
	if is_instance_valid(sparkle):
		sparkle.visible = false
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
	if is_instance_valid(banner_label):
		banner_label.visible = false
		banner_label.text = ""
	if is_instance_valid(clue_sprite):
		clue_sprite.visible = false
	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		if collect_button is Button:
			(collect_button as Button).text = "Collect Artifact"
			(collect_button as Button).custom_minimum_size = Vector2(300.0, 54.0)
	if is_instance_valid(tap_catcher):
		tap_catcher.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null
		briefcase_reveal_sprite.modulate = Color(1, 1, 1, 1)
		briefcase_reveal_sprite.z_index = 100
		briefcase_reveal_sprite.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if is_instance_valid(notification_ui):
		notification_ui.visible = true
	if is_instance_valid(notification_panel):
		notification_panel.visible = false
	if is_instance_valid(notification_label):
		notification_label.visible = false
	if is_instance_valid(guidance_arrow):
		guidance_arrow.visible = false
	if is_instance_valid(progress_tracker):
		progress_tracker.visible = false
	_ensure_focus_overlay()
		
	# Hide players until search room phase ends
	if is_instance_valid(detective_player):
		detective_player.visible = false
	if is_instance_valid(sidekick_player):
		sidekick_player.visible = false

	pause_controller.setup(self)
	consequence_controller.setup(self)
	tool_hunt_controller.setup(self)
	note_controller.setup(self)

	_connect_zone_interactions()
	_prepare_initial_flow_state()
	_setup_quest_panel_style()
	_update_quest_labels()

	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if is_instance_valid(collect_button) and not collect_button.pressed.is_connected(_on_collect_clue_pressed):
		collect_button.pressed.connect(_on_collect_clue_pressed)
		
	if is_instance_valid(ending_cutscene):
		ending_cutscene.visible = false
		ending_cutscene.expand = true
		ending_cutscene.anchor_left = 0.1
		ending_cutscene.anchor_top = 0.1
		ending_cutscene.anchor_right = 0.9
		ending_cutscene.anchor_bottom = 0.9
		ending_cutscene.offset_left = 0
		ending_cutscene.offset_top = 0
		ending_cutscene.offset_right = 0
		ending_cutscene.offset_bottom = 0
		ending_cutscene.finished.connect(_on_cutscene_finished)
		
	var cutscene_dark: Node = get_node_or_null("Cutscene/DarkOverlay")
	if is_instance_valid(cutscene_dark):
		cutscene_dark.visible = false
		
	_ensure_sfx_bus()
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_player)

	_initialize_puzzle_sync()


func _update_player_visibility(spawn_players: bool) -> void:
	if is_instance_valid(detective_player):
		detective_player.visible = spawn_players and GameState.local_role == GameState.Role.DETECTIVE
	if is_instance_valid(sidekick_player):
		sidekick_player.visible = spawn_players and GameState.local_role == GameState.Role.SIDEKICK


func _ensure_sfx_bus() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		var last := AudioServer.bus_count - 1
		AudioServer.set_bus_name(last, "SFX")
		AudioServer.set_bus_volume_db(last, 0.0)


func _play_zone_completion_sfx() -> void:
	if not is_instance_valid(_sfx_player) or not _zone_completion_sfx:
		push_error("[PinasHouse] SFX player or stream not valid")
		return
	MusicController.pause_music()
	_sfx_player.stream = _zone_completion_sfx
	_sfx_player.play()
	if not _sfx_player.finished.is_connected(_on_sfx_finished_resume_music):
		_sfx_player.finished.connect(_on_sfx_finished_resume_music, CONNECT_ONE_SHOT)


func _on_sfx_finished_resume_music() -> void:
	MusicController.resume_music()


func _is_press_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _apply_sparkle_animation(sparkle_node: Sprite2D) -> void:
	var pulse := (sin(_animation_time * SPARKLE_PULSE_SPEED) + 1.0) / 2.0
	var target_scale: float = lerp(SPARKLE_MIN_SCALE, SPARKLE_MAX_SCALE, pulse)
	sparkle_node.scale = Vector2(target_scale, target_scale)


func _process(delta: float) -> void:
	if not _sparkle_animating:
		return
	_animation_time += delta
	if is_instance_valid(sparkle) and sparkle.visible:
		_apply_sparkle_animation(sparkle)


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
	if not GameState.briefcase_updated.is_connected(_on_briefcase_updated):
		GameState.briefcase_updated.connect(_on_briefcase_updated)


func _setup_music() -> void:
	MusicController.play_track(MusicController.MusicTrack.PINAS_HOUSE)


func _connect_zone_interactions() -> void:
	if is_instance_valid(note_area) and not note_area.input_event.is_connected(_on_note_area_input_event):
		note_area.input_event.connect(_on_note_area_input_event)
	if is_instance_valid(cabinet_area) and not cabinet_area.input_event.is_connected(_on_cabinet_input_event):
		cabinet_area.input_event.connect(_on_cabinet_input_event)
	if is_instance_valid(wrong_click_zone) and not wrong_click_zone.input_event.is_connected(_on_wrong_object_input):
		wrong_click_zone.input_event.connect(_on_wrong_object_input)
	if is_instance_valid(cabinet_ladle_area) and not cabinet_ladle_area.input_event.is_connected(_on_cabinet_ladle_input_event):
		cabinet_ladle_area.input_event.connect(_on_cabinet_ladle_input_event)
	if is_instance_valid(tap_catcher) and not tap_catcher.pressed.is_connected(_on_reward_tap_catcher_pressed):
		tap_catcher.pressed.connect(_on_reward_tap_catcher_pressed)
	if inside_zone_control:
		if inside_zone_control.has_signal("ledger_pressed") and not inside_zone_control.ledger_pressed.is_connected(_on_ledger_button_pressed):
			inside_zone_control.ledger_pressed.connect(_on_ledger_button_pressed)
		if inside_zone_control.has_signal("briefcase_pressed") and not inside_zone_control.briefcase_pressed.is_connected(_on_briefcase_button_pressed):
			inside_zone_control.briefcase_pressed.connect(_on_briefcase_button_pressed)


func _prepare_initial_flow_state() -> void:
	_zone_active = false; _tool_phase_active = false; _note_phase_active = false
	_cabinet_phase_active = false; _reward_active = false
	_note_solved = false; _detective_note_seen = false; _note_dialogue_played = false
	_ledger_hint_shown = false; _ledger_opened_once = false
	_tools_unlocked = false
	_tools_collected = {"pan": false, "ladle": false, "pot": false}

	if is_instance_valid(search_room_ui):
		search_room_ui.visible = false
	if is_instance_valid(search_room_label):
		search_room_label.text = "Find missing tools:"
	
	if _puzzle_data_ready:
		note_controller.apply_unsolved_text()

	tool_hunt_controller.apply_banner_frames()
	tool_hunt_controller.set_tools_unlocked_local(false)
	_hide_note()
	_hide_cabinet_reward_state()
	note_controller.close_boards(true)
	note_controller.apply_note_interaction_gate()
	_refresh_inside_zone_buttons()
	_reset_cabinet_clue_state()
	
	if is_instance_valid(detective_player):
		detective_player.visible = false
	if is_instance_valid(sidekick_player):
		sidekick_player.visible = false
	_update_quest_labels()


func _hide_note() -> void:
	if is_instance_valid(note_area): note_area.input_pickable = false
	if is_instance_valid(note_collision): note_collision.disabled = true
	_stop_note_reveal_highlight()
	if is_instance_valid(note_sprite): note_sprite.visible = false
	if is_instance_valid(note_btn):
		note_btn.visible = false
		note_btn.disabled = true


func _show_note() -> void:
	if is_instance_valid(note_area): note_area.input_pickable = true
	if is_instance_valid(note_collision): note_collision.disabled = false
	if is_instance_valid(note_sprite):
		note_sprite.visible = true
		_play_note_reveal_highlight()
	if is_instance_valid(note_btn):
		note_btn.visible = true
		note_btn.disabled = false


func _play_note_reveal_highlight() -> void:
	if not is_instance_valid(note_sprite):
		return
	_stop_note_reveal_highlight()
	var old_glow := note_sprite.get_parent().get_node_or_null("NoteRevealGlow") as Sprite2D
	if is_instance_valid(old_glow):
		old_glow.queue_free()

	var base_pos: Vector2 = note_sprite.position
	var base_scale: Vector2 = note_sprite.scale
	var base_modulate: Color = note_sprite.modulate
	var base_z_index: int = note_sprite.z_index
	note_sprite.set_meta("note_reveal_base_position", base_pos)
	note_sprite.set_meta("note_reveal_base_scale", base_scale)
	note_sprite.set_meta("note_reveal_base_modulate", base_modulate)
	note_sprite.set_meta("note_reveal_base_z_index", base_z_index)
	var glow := Sprite2D.new()
	glow.name = "NoteRevealGlow"
	glow.texture = note_sprite.texture
	glow.position = note_sprite.position
	glow.rotation = note_sprite.rotation
	glow.scale = base_scale * 1.2
	glow.modulate = Color(1.0, 0.78, 0.24, 0.0)
	glow.z_index = base_z_index + 1
	glow.show_behind_parent = false
	note_sprite.get_parent().add_child(glow)

	note_sprite.z_index = base_z_index + 2
	note_sprite.scale = base_scale
	note_sprite.modulate = base_modulate

	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_loops()
	tween.set_parallel(false)
	tween.tween_property(note_sprite, "scale", base_scale * 1.18, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(note_sprite, "modulate", Color(1.0, 0.94, 0.62, 1.0), 0.22)
	tween.parallel().tween_property(glow, "scale", base_scale * 1.45, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(glow, "modulate:a", 0.58, 0.22)
	tween.tween_property(note_sprite, "scale", base_scale, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(note_sprite, "modulate", base_modulate, 0.18)
	for i in range(NOTE_REVEAL_SHAKE_COUNT):
		tween.tween_property(note_sprite, "position", base_pos + Vector2(-NOTE_REVEAL_SHAKE_OFFSET, 0), NOTE_REVEAL_SHAKE_STEP)
		tween.tween_property(note_sprite, "position", base_pos + Vector2(NOTE_REVEAL_SHAKE_OFFSET, 0), NOTE_REVEAL_SHAKE_STEP)
	tween.tween_property(note_sprite, "position", base_pos, NOTE_REVEAL_SHAKE_STEP)
	tween.parallel().tween_property(glow, "modulate:a", 0.0, 0.34)
	tween.parallel().tween_property(glow, "scale", base_scale * 1.62, 0.34)
	tween.tween_interval(0.35)
	note_sprite.set_meta("reveal_shake_tween", tween)


func _stop_note_reveal_highlight() -> void:
	if not is_instance_valid(note_sprite):
		return
	if note_sprite.has_meta("reveal_shake_tween"):
		var old: Tween = note_sprite.get_meta("reveal_shake_tween")
		if is_instance_valid(old):
			old.kill()
		note_sprite.remove_meta("reveal_shake_tween")
	if note_sprite.has_meta("note_reveal_base_position"):
		note_sprite.position = note_sprite.get_meta("note_reveal_base_position")
		note_sprite.remove_meta("note_reveal_base_position")
	if note_sprite.has_meta("note_reveal_base_scale"):
		note_sprite.scale = note_sprite.get_meta("note_reveal_base_scale")
		note_sprite.remove_meta("note_reveal_base_scale")
	if note_sprite.has_meta("note_reveal_base_modulate"):
		note_sprite.modulate = note_sprite.get_meta("note_reveal_base_modulate")
		note_sprite.remove_meta("note_reveal_base_modulate")
	if note_sprite.has_meta("note_reveal_base_z_index"):
		note_sprite.z_index = note_sprite.get_meta("note_reveal_base_z_index")
		note_sprite.remove_meta("note_reveal_base_z_index")
	var glow := note_sprite.get_parent().get_node_or_null("NoteRevealGlow") as Sprite2D
	if is_instance_valid(glow):
		glow.queue_free()


func _hide_cabinet_reward_state() -> void:
	if is_instance_valid(cabinet_area): cabinet_area.input_pickable = false
	if is_instance_valid(cabinet_collision): cabinet_collision.disabled = true


func _enable_cabinet_interaction() -> void:
	if is_instance_valid(cabinet_area): cabinet_area.input_pickable = true
	if is_instance_valid(cabinet_collision): cabinet_collision.disabled = false


func _start_intro_dialogue_delayed() -> void:
	if _intro_dialogue_played:
		return
	_intro_dialogue_played = true
	_run_intro_sequence()


func _run_intro_sequence() -> void:
	await _play_locked_dialogue("pinas_house_enter", DialogueLibraries.PINAS_HOUSE_ENTER)
	_report_intro_ready()


func _report_intro_ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		_begin_zone_flow_local()
		return
	if multiplayer.is_server():
		_mark_intro_ready(multiplayer.get_unique_id())
	else:
		rpc_report_intro_ready.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_report_intro_ready() -> void:
	if not multiplayer.is_server():
		return
	_mark_intro_ready(multiplayer.get_remote_sender_id())


func _mark_intro_ready(peer_id: int) -> void:
	_intro_ready_peers[peer_id] = true
	if multiplayer.is_server():
		_intro_ready_peers[multiplayer.get_unique_id()] = true
		if _intro_ready_peers.size() >= multiplayer.get_peers().size() + 1:
			rpc_begin_zone_flow.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_begin_zone_flow() -> void:
	_begin_zone_flow_local()


func _begin_zone_flow_local() -> void:
	if _intro_flow_started:
		return
	_intro_flow_started = true
	_zone_active = true
	tool_hunt_controller.set_search_mode_local(true)
	if is_instance_valid(search_room_label):
		search_room_label.text = "Find missing tools:"
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_start_strike_system()
	_update_quest_labels()


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


func _on_role_assigned(role: Variant) -> void:
	GameState.local_role = role
	update_role_visibility()
	_update_role_label()
	_refresh_inside_zone_buttons()
	
	var past_tool_phase: bool = _note_phase_active or _note_solved or _cabinet_phase_active or _reward_active
	_update_player_visibility(past_tool_phase)
	_update_quest_labels()


func _update_role_label() -> void:
	if is_instance_valid(role_label):
		role_label.text = "Role: " + GameState.get_role_display_text()


func show_notification(text: String, duration: float = 1.8) -> void:
	if not is_instance_valid(notification_panel) or not is_instance_valid(notification_label):
		return
	notification_label.text = text
	#notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notification_panel.visible = true
	notification_label.visible = true
	var current_id := Time.get_ticks_msec()
	notification_panel.set_meta("msg_id", current_id)
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration, true).timeout
	if is_instance_valid(notification_panel) and notification_panel.get_meta("msg_id", -1) == current_id:
		notification_panel.visible = false
		notification_label.visible = false


func hide_notification() -> void:
	if is_instance_valid(notification_panel):
		notification_panel.visible = false
	if is_instance_valid(notification_label):
		notification_label.visible = false


func pulse_ledger_guidance(enable: bool) -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		if is_instance_valid(guidance_arrow):
			guidance_arrow.visible = false
		return
	if _note_solved:
		enable = false
	if enable:
		_ledger_hint_shown = true
	_refresh_inside_zone_buttons()
	if is_instance_valid(inside_zone_ledger_button):
		if enable:
			if not inside_zone_ledger_button.has_meta("pulse_tween"):
				var tw := create_tween()
				tw.set_loops()
				tw.tween_property(inside_zone_ledger_button, "scale", Vector2(0.07, 0.07), 0.4)
				tw.tween_property(inside_zone_ledger_button, "scale", Vector2(0.06, 0.06), 0.4)
				inside_zone_ledger_button.set_meta("pulse_tween", tw)
		else:
			if inside_zone_ledger_button.has_meta("pulse_tween"):
				var old_tw: Tween = inside_zone_ledger_button.get_meta("pulse_tween")
				if old_tw:
					old_tw.kill()
				inside_zone_ledger_button.remove_meta("pulse_tween")
			inside_zone_ledger_button.scale = Vector2(0.06, 0.06)
	if is_instance_valid(guidance_arrow):
		guidance_arrow.visible = enable


func _on_ledger_button_pressed() -> void:
	if GameState.local_role != GameState.Role.SIDEKICK or _dialogue_input_locked:
		return
	var first_open: bool = not _ledger_opened_once
	_ledger_opened_once = true
	pulse_ledger_guidance(false)
	_populate_ledger_content()
	if ledger_panel:
		ledger_panel.visible = not ledger_panel.visible
	if first_open and _note_phase_active and not _note_solved:
		show_notification("Use the ledger steps to solve the equation.", 2.0)


func _on_briefcase_button_pressed() -> void:
	if GameState.local_role != GameState.Role.SIDEKICK or _dialogue_input_locked:
		return
	if not is_instance_valid(briefcase_panel):
		return
	_refresh_briefcase_display()
	var should_open: bool = not briefcase_panel.visible
	if should_open and is_instance_valid(ledger_panel):
		ledger_panel.visible = false
	briefcase_panel.visible = should_open


func _ensure_briefcase_display() -> void:
	if not is_instance_valid(briefcase_panel) or is_instance_valid(briefcase_display):
		return
	briefcase_display = TextureRect.new()
	briefcase_display.name = "BriefcaseDisplay"
	briefcase_display.visible = false
	briefcase_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	briefcase_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	briefcase_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	briefcase_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefcase_display.offset_left = -152.0
	briefcase_display.offset_top = 40.0
	briefcase_display.offset_right = 185.0
	briefcase_display.offset_bottom = 67.0
	briefcase_panel.add_child(briefcase_display)


func _refresh_briefcase_display() -> void:
	if not is_instance_valid(briefcase_display):
		return
	var texture: Texture2D = GameState.get_briefcase_texture("forest")
	briefcase_display.texture = texture
	briefcase_display.visible = texture != null


func _on_briefcase_updated() -> void:
	_refresh_briefcase_display()


func _on_back_pressed() -> void:
	if not _dialogue_input_locked:
		_return_to_forest()


func _return_to_forest() -> void:
	_stop_strike_system()
	get_tree().paused = false
	if pause_controller:
		pause_controller._resume_zone_systems()
	await get_tree().process_frame
	if is_inside_tree():
		get_tree().change_scene_to_file(SCENE_FOREST_HUB)


func _exit_tree() -> void:
	if pause_controller:
		pause_controller.cleanup()


func _on_clue_collected(zone_id: String, _clue_data: Dictionary) -> void:
	if zone_id == "pinas_house" and not clue_collected:
		clue_collected = true
		_update_quest_labels()


func _on_note_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _dialogue_input_locked and _is_press_event(event):
		_request_open_note()


func _request_open_note() -> void:
	if not _note_phase_active and not _note_solved:
		return
	if not multiplayer.has_multiplayer_peer():
		rpc_open_note_boards()
	elif multiplayer.is_server():
		rpc_open_note_boards.rpc()
	else:
		rpc_request_open_note.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_open_note() -> void:
	if multiplayer.is_server():
		rpc_open_note_boards.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_open_note_boards() -> void:
	_stop_note_reveal_highlight()
	note_controller.on_note_interacted()


func _on_cabinet_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _dialogue_input_locked and _cabinet_phase_active and _is_press_event(event):
		_request_open_cabinet()


func _request_open_cabinet() -> void:
	if not _cabinet_phase_active:
		show_notification("The cabinet won't open yet.", 2.0)
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_open_cabinet_server()
	else:
		rpc_request_open_cabinet.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_open_cabinet() -> void:
	if multiplayer.is_server():
		_open_cabinet_server()


func _open_cabinet_server() -> void:
	if not _cabinet_phase_active or _reward_active or _cabinet_opened:
		return
	rpc_open_cabinet_visual.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_open_cabinet_visual() -> void:
	_cabinet_opened = true
	if is_instance_valid(cabinet_open_sprite): cabinet_open_sprite.visible = true
	if is_instance_valid(cabinet_ladle_sprite): cabinet_ladle_sprite.visible = not _ladle_found
	if is_instance_valid(cabinet_ladle_collision): cabinet_ladle_collision.disabled = _ladle_found
	if is_instance_valid(cabinet_ladle_area): cabinet_ladle_area.input_pickable = not _ladle_found
	show_notification("The cabinet is open. Look inside.", 2.0)
	_update_quest_labels()


@rpc("any_peer", "call_local", "reliable")
func rpc_show_pinas_house_reward() -> void:
	show_reward()


func show_reward() -> void:
	if _reward_active:
		return
	_reward_active = true
	_update_quest_labels()
	get_tree().paused = true
	reward_layer.visible = true
	await reward_sequence()


func reward_sequence() -> void:
	sparkle.visible = false
	banner_label.visible = false
	clue_sprite.visible = false
	collect_button.visible = false
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(dark_overlay, "modulate:a", 0.7, 0.6)
	await tween.finished
	await get_tree().create_timer(0.4, true).timeout
	sparkle.visible = true
	await get_tree().create_timer(0.6, true).timeout
	banner_label.visible = true
	reward_text.text = "ARTIFACT FOUND!\n\nThe ladle matters because it represents the kitchen work Pina ignored.\n\n\"We use our eyes to find things, but Pina never used hers…\""
	await get_tree().create_timer(0.6, true).timeout
	clue_sprite.visible = true
	await get_tree().create_timer(0.6, true).timeout
	if multiplayer.has_multiplayer_peer():
		collect_button.visible = GameState.local_role == GameState.Role.SIDEKICK
	else:
		collect_button.visible = true


func _on_collect_clue_pressed() -> void:
	if _collect_sequence_started:
		return
	_collect_sequence_started = true
	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.disabled = true
	# Sidekick presses collect — send to server to broadcast to all peers
	if multiplayer.is_server():
		rpc_show_briefcase_reveal_then_finalize.rpc()
	else:
		rpc_request_collect_clue.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_collect_clue() -> void:
	# Server receives collect request from sidekick — broadcast to all peers
	if multiplayer.is_server():
		rpc_show_briefcase_reveal_then_finalize.rpc()


func _collect_clue_server() -> void:
	rpc_begin_briefcase_store_sequence.rpc()
	await get_tree().create_timer(2.0, true).timeout
	rpc_finalize_clue_collection.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_finalize_clue_collection() -> void:
	_stop_strike_system()
	GameState.collect_clue("pinas_house")
	clue_collected = true
	_update_quest_labels()
	_dialogue_input_locked = false
	get_tree().paused = false
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null
	if is_instance_valid(reward_layer):
		reward_layer.visible = false
	_return_to_forest()


func _on_pause_button_pressed() -> void:
	if not in_game_pause_panel:
		return
	in_game_pause_panel.visible = true
	in_game_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Add a full-screen blocker behind the panel
	if option_sub_panel:
		option_sub_panel.visible = false
	get_tree().paused = true
	MusicController.pause_music()

func _on_resume_play_button_pressed() -> void:
	pause_controller.on_resume_play_button_pressed()

func _on_option_button_pressed() -> void:
	pause_controller.on_option_button_pressed()

func _on_in_game_option_back_pressed() -> void:
	pause_controller.on_in_game_option_back_pressed()

func _on_exit_to_main_menu_button_pressed() -> void:
	get_tree().paused = false
	if pause_controller:
		pause_controller._resume_zone_systems()
	_return_to_forest()

func _on_in_game_volume_changed(value: float) -> void:
	pause_controller.on_in_game_volume_changed(value)


func apply_note_interaction_gate() -> void:
	note_controller.apply_note_interaction_gate()

@rpc("any_peer", "reliable")
func rpc_request_detective_note_seen() -> void:
	if multiplayer.is_server():
		note_controller.set_detective_note_seen_local(true)
		rpc_set_detective_note_seen.rpc(true)

@rpc("any_peer", "reliable", "call_local")
func rpc_set_detective_note_seen(seen: bool) -> void:
	note_controller.set_detective_note_seen_local(seen)

func _close_boards(force: bool = false) -> void:
	note_controller.close_boards(force)
	_refresh_focus_overlay()

func _on_sidekick_solved() -> void:
	note_controller.on_sidekick_solved()


func _on_tool_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, tool_id: String) -> void:
	tool_hunt_controller.on_tool_input_event(_viewport, event, _shape_idx, tool_id)

@rpc("any_peer", "reliable")
func rpc_request_collect_tool(tool_id: String) -> void:
	if multiplayer.is_server():
		tool_hunt_controller.server_collect_tool(tool_id, multiplayer.get_remote_sender_id())

@rpc("any_peer", "reliable", "call_local")
func rpc_set_tool_collected(tool_id: String) -> void:
	tool_hunt_controller.set_tool_collected_local(tool_id)
	_update_quest_labels()

@rpc("any_peer", "reliable", "call_local")
func rpc_set_tools_unlocked(unlocked: bool) -> void:
	tool_hunt_controller.set_tools_unlocked_local(unlocked)
	_update_quest_labels()

@rpc("any_peer", "reliable", "call_local")
func rpc_show_tool_feedback(message: String) -> void:
	show_notification(message, 1.6)

@rpc("any_peer", "reliable", "call_local")
func rpc_note_revealed() -> void:
	if is_instance_valid(search_room_ui):
		search_room_ui.visible = false

	_tool_phase_active = false
	_note_phase_active = true
	_show_note()
	_set_progress_tracker_stage(1)

	note_controller.apply_note_interaction_gate()
	note_controller.apply_close_button_visibility()

	if has_method("_refresh_note_puzzle_views"):
		_refresh_note_puzzle_views()
	
	# Show the correct player after tool hunt completes
	_update_player_visibility(true)
	_update_quest_labels()


func _on_wrong_object_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	tool_hunt_controller.on_wrong_object_input(_viewport, event, _shape_idx)


func _start_strike_system() -> void:
	if _consequence_active:
		return
	_consequence_active = true
	_strikes_left = MAX_ATTACKS
	_attack_index = 0
	_failed = false
	_penalty_on_cooldown = false


func _stop_strike_system() -> void:
	_consequence_active = false
	_penalty_on_cooldown = false


func _can_apply_strike() -> bool:
	return _consequence_active and not _failed and not _penalty_on_cooldown and not clue_collected


func _apply_strike_server(reason: String) -> void:
	if not _can_apply_strike():
		return
	_penalty_on_cooldown = true
	_strikes_left = max(0, _strikes_left - 1)
	_attack_index = min(MAX_ATTACKS - _strikes_left, 9)
	rpc_play_aswang_attack.rpc(_attack_index, true)
	rpc_play_validation_feedback.rpc(reason)
	if _strikes_left <= 0:
		consequence_controller.fail_zone_server()
		return
	await get_tree().create_timer(PENALTY_COOLDOWN_SEC, true).timeout
	_penalty_on_cooldown = false


@rpc("any_peer", "reliable")
func rpc_request_penalty(reason: String) -> void:
	if multiplayer.is_server():
		_apply_strike_server(reason)

@rpc("any_peer", "reliable", "call_local")
func rpc_play_aswang_attack(idx: int, from_penalty: bool) -> void:
	consequence_controller.play_aswang_attack(idx, from_penalty)

@rpc("any_peer", "reliable")
func rpc_request_consequence_state() -> void:
	if multiplayer.is_server():
		rpc_apply_consequence_state.rpc_id(multiplayer.get_remote_sender_id(), _attack_index, _strikes_left, _failed)

@rpc("any_peer", "reliable", "call_local")
func rpc_apply_consequence_state(attack_idx: int, strikes_left: int, failed: bool) -> void:
	consequence_controller.apply_consequence_state(attack_idx, strikes_left, failed)

@rpc("any_peer", "reliable", "call_local")
func rpc_play_validation_feedback(dialogue_id: String) -> void:
	consequence_controller.play_validation_feedback(dialogue_id)

@rpc("any_peer", "reliable", "call_local")
func rpc_fail_pre_shake() -> void:
	consequence_controller.fail_pre_shake()

@rpc("any_peer", "reliable", "call_local")
func rpc_fail_show_ui() -> void:
	consequence_controller.fail_show_ui()

@rpc("any_peer", "reliable", "call_local")
func rpc_reset_pinas_house_progress() -> void:
	consequence_controller.reset_pinas_house_progress_local()

@rpc("any_peer", "reliable", "call_local")
func rpc_lock_pinas_house_zone(duration_sec: int) -> void:
	consequence_controller.lock_pinas_house_zone_local(duration_sec)

@rpc("any_peer", "reliable", "call_local")
func rpc_kick_to_hub() -> void:
	consequence_controller.kick_to_hub_local()

func _on_final_shake_tick() -> void:
	consequence_controller.on_final_shake_tick()


func broadcast_pinas_house_solved() -> void:
	if multiplayer.has_multiplayer_peer():
		rpc_pinas_house_solved.rpc()
	else:
		rpc_pinas_house_solved()

@rpc("any_peer", "reliable", "call_local")
func rpc_pinas_house_solved() -> void:
	_note_solved = true
	_cabinet_phase_active = true
	GameState.set_puzzle_solved("pinas_house", true)
	_ledger_hint_shown = false
	hide_notification()
	pulse_ledger_guidance(false)
	_refresh_inside_zone_buttons()
	_set_progress_tracker_stage(2)
	_update_quest_labels()
	await note_controller.after_note_solved()
	_update_quest_labels()

@rpc("any_peer", "reliable", "call_local")
func rpc_set_search_mode(enable: bool) -> void:
	tool_hunt_controller.set_search_mode_local(enable)
	_update_quest_labels()


func _populate_ledger_content() -> void:
	var ledger_view: Dictionary = PuzzleManager.get_zone_ledger_display("pinas_house")
	if ledger_view.is_empty():
		return
	if is_instance_valid(ledger_title_label): ledger_title_label.text = str(ledger_view.get("title", ""))
	if is_instance_valid(ledger_left_header_label): ledger_left_header_label.text = str(ledger_view.get("left_header", ""))
	if is_instance_valid(ledger_left_body_label): ledger_left_body_label.text = str(ledger_view.get("left_body", ""))
	if is_instance_valid(ledger_right_header_label): ledger_right_header_label.text = str(ledger_view.get("right_header", ""))
	if is_instance_valid(ledger_right_body_label): ledger_right_body_label.text = str(ledger_view.get("right_body", ""))


func _refresh_inside_zone_buttons() -> void:
	var is_sidekick: bool = GameState.local_role == GameState.Role.SIDEKICK
	if is_instance_valid(inside_zone_control):
		if inside_zone_control.has_method("set_sidekick_ui_visible"): inside_zone_control.set_sidekick_ui_visible(is_sidekick)
		if inside_zone_control.has_method("set_pause_enabled"): inside_zone_control.set_pause_enabled(true)
		if inside_zone_control.has_method("set_briefcase_enabled"): inside_zone_control.set_briefcase_enabled(is_sidekick)
		if inside_zone_control.has_method("set_ledger_enabled"): inside_zone_control.set_ledger_enabled(is_sidekick)


func _set_dialogue_input_lock(locked: bool) -> void:
	_dialogue_input_locked = locked
	var is_sidekick: bool = GameState.local_role == GameState.Role.SIDEKICK
	if is_instance_valid(inside_zone_control):
		if inside_zone_control.has_method("set_pause_enabled"): inside_zone_control.set_pause_enabled(true)
		if inside_zone_control.has_method("set_ledger_enabled"): inside_zone_control.set_ledger_enabled(is_sidekick and not locked)
		if inside_zone_control.has_method("set_briefcase_enabled"): inside_zone_control.set_briefcase_enabled(is_sidekick and not locked)
	if is_instance_valid(back_button):
		back_button.disabled = locked

	var note_interactable: bool = not locked and (_note_phase_active or _note_solved)
	if is_instance_valid(note_area): note_area.input_pickable = note_interactable
	if is_instance_valid(note_collision): note_collision.disabled = not note_interactable

	var cabinet_interactable: bool = not locked and _cabinet_phase_active
	if is_instance_valid(cabinet_area): cabinet_area.input_pickable = cabinet_interactable
	if is_instance_valid(cabinet_collision): cabinet_collision.disabled = not cabinet_interactable

	var wrong_interactable: bool = not locked and (_tool_phase_active or _cabinet_phase_active)
	if is_instance_valid(wrong_click_zone):
		wrong_click_zone.input_pickable = wrong_interactable
		for child in wrong_click_zone.get_children():
			if child is CollisionShape2D:
				child.disabled = not wrong_interactable

	tool_hunt_controller.apply_tool_nodes()

	var ladle_interactable: bool = not locked and (_cabinet_opened and not _ladle_found)
	if is_instance_valid(cabinet_ladle_area): cabinet_ladle_area.input_pickable = ladle_interactable
	if is_instance_valid(cabinet_ladle_collision): cabinet_ladle_collision.disabled = not ladle_interactable

	if is_instance_valid(sidekick_board) and sidekick_board.has_method("set_inputs_enabled"):
		var can_input: bool = not locked and _note_phase_active and _detective_note_seen and not _note_solved
		sidekick_board.set_inputs_enabled(can_input)

	if is_instance_valid(detective_close): detective_close.disabled = locked
	if is_instance_valid(sidekick_close): sidekick_close.disabled = locked

	if not locked:
		_refresh_inside_zone_buttons()
		tool_hunt_controller.apply_tool_nodes()
		note_controller.apply_note_interaction_gate()


func _play_locked_dialogue(dialogue_id: String, lines: Array[Dictionary]) -> void:
	_set_dialogue_input_lock(true)
	_update_player_visibility(false)  # hide players during dialogue
	_dialogue_focus_active = true
	_refresh_focus_overlay()
	DialogueSystem.play(dialogue_id, lines)
	await DialogueSystem.wait_finished(dialogue_id)
	_dialogue_focus_active = false
	_refresh_focus_overlay()
	_set_dialogue_input_lock(false)
	# Only show players again if we're past the tool hunt phase
	var past_tool_phase: bool = _note_phase_active or _note_solved or _cabinet_phase_active or _reward_active
	_update_player_visibility(past_tool_phase)


func _reset_cabinet_clue_state() -> void:
	_cabinet_opened = false
	_ladle_found = false
	_waiting_reward_continue = false
	_reward_stage = 0
	_collect_sequence_started = false

	if is_instance_valid(cabinet_open_sprite): cabinet_open_sprite.visible = false
	if is_instance_valid(cabinet_ladle_sprite): cabinet_ladle_sprite.visible = false
	if is_instance_valid(cabinet_ladle_collision):cabinet_ladle_collision.disabled = true
	if is_instance_valid(cabinet_ladle_area): cabinet_ladle_area.input_pickable = false
	if is_instance_valid(reward_layer): reward_layer.visible = false
	if is_instance_valid(reward_panel): reward_panel.visible = false
	if is_instance_valid(banner_label):
		banner_label.visible = false
		banner_label.text = ""
	if is_instance_valid(clue_sprite): clue_sprite.visible = false
	if is_instance_valid(sparkle): sparkle.visible = false
	if is_instance_valid(reward_text): reward_text.text = ""
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = false
		tap_instruction_label.text = ""
	if is_instance_valid(collect_button): collect_button.visible = false
	if is_instance_valid(tap_catcher):
		tap_catcher.visible = false
		tap_catcher.disabled = true
	if is_instance_valid(briefcase_reveal_sprite): briefcase_reveal_sprite.visible = false
	if is_instance_valid(dark_overlay): dark_overlay.modulate.a = 0.0
	_update_quest_labels()


func _on_cabinet_ladle_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _dialogue_input_locked and _cabinet_opened and not _ladle_found and _is_press_event(event):
		_request_pickup_cabinet_ladle()


func _request_pickup_cabinet_ladle() -> void:
	if not _cabinet_opened or _ladle_found:
		return
	_play_zone_completion_sfx()
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_pickup_cabinet_ladle_server()
	else:
		rpc_request_pickup_cabinet_ladle.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_pickup_cabinet_ladle() -> void:
	if multiplayer.is_server():
		_pickup_cabinet_ladle_server()


func _pickup_cabinet_ladle_server() -> void:
	if _cabinet_opened and not _ladle_found:
		rpc_start_ladle_found_sequence.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_start_ladle_found_sequence() -> void:
	_ladle_found = true
	_reward_active = true
	_waiting_reward_continue = true
	_reward_stage = 1
	_set_progress_tracker_stage(3)
	_update_quest_labels()

	if is_instance_valid(cabinet_ladle_sprite): cabinet_ladle_sprite.visible = false
	if is_instance_valid(cabinet_ladle_collision): cabinet_ladle_collision.disabled = true
	if is_instance_valid(cabinet_ladle_area): cabinet_ladle_area.input_pickable = false

	get_tree().paused = true

	if is_instance_valid(reward_layer): reward_layer.visible = true
	if is_instance_valid(dark_overlay): dark_overlay.modulate.a = 0.45
	if is_instance_valid(clue_sprite): clue_sprite.visible = true
	if is_instance_valid(banner_label):
		banner_label.visible = true
		banner_label.text = "ARTIFACT FOUND!"
	if is_instance_valid(sparkle):
		sparkle.visible = true
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
		_animation_time = 0.0
		_sparkle_animating = true
	if is_instance_valid(reward_panel): reward_panel.visible = false
	if is_instance_valid(reward_text): reward_text.text = ""
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = true
		tap_instruction_label.text = "Tap anywhere to continue."
	if is_instance_valid(collect_button): collect_button.visible = false
	if is_instance_valid(tap_catcher):
		tap_catcher.visible = true
		tap_catcher.disabled = false
	if is_instance_valid(briefcase_reveal_sprite): briefcase_reveal_sprite.visible = false


func _show_reward_stage_text(text: String) -> void:
	if is_instance_valid(reward_panel): reward_panel.visible = true
	if is_instance_valid(reward_text): reward_text.text = text
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = true
		tap_instruction_label.text = "Tap anywhere to continue."


func _on_reward_tap_catcher_pressed() -> void:
	if _dialogue_input_locked or not _waiting_reward_continue:
		return
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false

	match _reward_stage:
		1:
			_reward_stage = 2
			_show_reward_stage_text("The ladle was the last thing Pina looked for.")
		2:
			_reward_stage = 3
			_show_reward_stage_text("It was right in front of her, but she still could not see it.")
		3:
			_reward_stage = 4
			_show_reward_stage_text("\"We use our eyes to find things, but Pina never used hers...\"")
		4:
			_reward_stage = 5
			_waiting_reward_continue = false
			if is_instance_valid(tap_instruction_label):
				tap_instruction_label.visible = false
				tap_instruction_label.text = ""
			if is_instance_valid(tap_catcher):
				tap_catcher.visible = false
				tap_catcher.disabled = true
			if is_instance_valid(reward_text): reward_text.text = ""
			if is_instance_valid(reward_panel): reward_panel.visible = false
			if is_instance_valid(collect_button):
				collect_button.visible = GameState.local_role == GameState.Role.SIDEKICK


@rpc("any_peer", "reliable", "call_local")
func rpc_begin_briefcase_store_sequence() -> void:
	_dialogue_input_locked = true
	if is_instance_valid(reward_layer): reward_layer.visible = true
	if is_instance_valid(reward_panel): reward_panel.visible = false
	if is_instance_valid(reward_text): reward_text.text = ""
	if is_instance_valid(banner_label):
		banner_label.visible = false
		banner_label.text = ""
	if is_instance_valid(clue_sprite): clue_sprite.visible = false
	if is_instance_valid(sparkle): sparkle.visible = false
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = false
		tap_instruction_label.text = ""
	if is_instance_valid(tap_catcher):
		tap_catcher.visible = false
		tap_catcher.disabled = true
	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.disabled = true
	if is_instance_valid(dark_overlay): dark_overlay.modulate.a = 0.45
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = true
		briefcase_reveal_sprite.modulate = Color(1, 1, 1, 1)
		briefcase_reveal_sprite.z_index = 100


@rpc("any_peer", "call_local", "reliable")
func rpc_play_tools_done_dialogue() -> void:
	await _play_locked_dialogue("pinas_house_tools_done", DialogueLibraries.PINAS_HOUSE_TOOLS_DONE)


func _show_briefcase_reveal_local() -> void:
	if not is_instance_valid(briefcase_reveal_sprite):
		return
	var reveal_texture: Texture2D = GameState.get_briefcase_texture("pinas_house_reveal")
	briefcase_reveal_sprite.texture = reveal_texture
	briefcase_reveal_sprite.visible = reveal_texture != null
	briefcase_reveal_sprite.modulate = Color(1, 1, 1, 1)


@rpc("authority", "reliable", "call_local")
func rpc_show_briefcase_reveal_then_finalize() -> void:
	# Broadcast by server to all peers including itself.
	# Each peer runs the reveal animation then server fires rpc_finalize_clue
	# which is broadcast to everyone — ensuring sidekick also returns to forest.
	_hide_reward_visuals_for_briefcase()
	_show_briefcase_reveal_local()
	await get_tree().create_timer(1.5).timeout
	if multiplayer.is_server():
		rpc_finalize_clue.rpc()


func _hide_reward_visuals_for_briefcase() -> void:
	_sparkle_animating = false
	if is_instance_valid(sparkle):
		sparkle.visible = false
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
	if is_instance_valid(clue_sprite): clue_sprite.visible = false
	if is_instance_valid(banner_label):
		banner_label.visible = false
		banner_label.text = ""
	if is_instance_valid(reward_panel): reward_panel.visible = false
	if is_instance_valid(reward_text): reward_text.text = ""
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = false
		tap_instruction_label.text = ""
	if is_instance_valid(tap_catcher):
		tap_catcher.visible = false
		tap_catcher.disabled = true
	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.disabled = true


@rpc("authority", "reliable", "call_local")
func rpc_finalize_clue() -> void:
	GameState.collect_clue("pinas_house")
	clue_collected = true
	_sparkle_animating = false
	_update_quest_labels()
	get_tree().paused = false
	if is_instance_valid(sparkle):
		sparkle.visible = false
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
	if is_instance_valid(clue_sprite): clue_sprite.visible = false
	if is_instance_valid(banner_label):
		banner_label.visible = false
		banner_label.text = ""
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null
	if is_instance_valid(reward_layer):
		reward_layer.visible = false

	# Fade out before cutscene
	await _fade_out(0.6)
	_play_ending_cutscene()
	# Fade back in over the cutscene
	await _fade_in(0.6)

func _initialize_puzzle_sync() -> void:
	if not multiplayer.has_multiplayer_peer():
		var puzzle: Dictionary = PuzzleManager.get_puzzle_for_zone("pinas_house")
		_apply_puzzle_data(puzzle)
		_on_puzzle_data_ready()
		return

	if multiplayer.is_server():
		_broadcast_puzzle_data()
	else:
		rpc_request_pinas_puzzle_data.rpc_id(_SERVER_PEER_ID)


func _broadcast_puzzle_data(target_peer_id: int = 0) -> void:
	var puzzle: Dictionary = PuzzleManager.get_puzzle_for_zone("pinas_house")
	var variation_index: int = int(puzzle.get("variation_index", 0))

	GameState.force_puzzle_variation_index("pinas_house", variation_index)

	if target_peer_id > 0:
		rpc_sync_pinas_puzzle_data.rpc_id(target_peer_id, puzzle)
	else:
		rpc_sync_pinas_puzzle_data.rpc(puzzle)


@rpc("any_peer", "reliable")
func rpc_request_pinas_puzzle_data() -> void:
	if not multiplayer.is_server():
		return
	_broadcast_puzzle_data(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable", "call_local")
func rpc_sync_pinas_puzzle_data(puzzle: Dictionary) -> void:
	var variation_index: int = int(puzzle.get("variation_index", 0))
	GameState.force_puzzle_variation_index("pinas_house", variation_index)

	_apply_puzzle_data(puzzle)
	_on_puzzle_data_ready()


func _apply_puzzle_data(puzzle: Dictionary) -> void:
	_puzzle_data = puzzle.duplicate(true)


func _on_puzzle_data_ready() -> void:
	if _puzzle_data_ready:
		return

	_puzzle_data_ready = true
	_refresh_note_puzzle_views()
	_start_intro_dialogue_delayed()


func _refresh_note_puzzle_views() -> void:
	if note_controller:
		note_controller.apply_unsolved_text()

	if is_instance_valid(sidekick_board):
		if sidekick_board.has_method("set_puzzle_data"):
			sidekick_board.set_puzzle_data(_puzzle_data.duplicate(true))
		elif sidekick_board.has_method("set_equation_and_solution"):
			sidekick_board.set_equation_and_solution(
				str(_puzzle_data.get("equation", "")),
				int(_puzzle_data.get("solution", 0))
			)
		else:
			if sidekick_board.has_method("set_equation"):
				sidekick_board.set_equation(str(_puzzle_data.get("equation", "")))
			if sidekick_board.has_method("set_solution"):
				sidekick_board.set_solution(int(_puzzle_data.get("solution", 0)))
			if sidekick_board.has_method("set_answer_format"):
				sidekick_board.set_answer_format(str(_puzzle_data.get("answer_format", "")))

		if sidekick_board.has_method("apply_puzzle_view") and not _note_solved:
			sidekick_board.apply_puzzle_view()

func _update_progress_tracker_for_current_state() -> void:
	if not is_instance_valid(progress_tracker_sprite):
		return

	if _ladle_found:
		progress_tracker_sprite.texture = PROGRESS_PUZZLE3_TEX
	elif _note_solved:
		progress_tracker_sprite.texture = PROGRESS_PUZZLE2_TEX
	elif _note_phase_active:
		progress_tracker_sprite.texture = PROGRESS_PUZZLE1_TEX
	else:
		progress_tracker_sprite.texture = PROGRESS_DEFAULT_TEX


func _set_progress_tracker_stage(stage: int) -> void:
	if not is_instance_valid(progress_tracker_sprite):
		return

	match stage:
		0:
			progress_tracker_sprite.texture = PROGRESS_DEFAULT_TEX
		1:
			progress_tracker_sprite.texture = PROGRESS_PUZZLE1_TEX
		2:
			progress_tracker_sprite.texture = PROGRESS_PUZZLE2_TEX
		3:
			progress_tracker_sprite.texture = PROGRESS_PUZZLE3_TEX
		_:
			progress_tracker_sprite.texture = PROGRESS_DEFAULT_TEX


func _play_ending_cutscene() -> void:
	if not is_instance_valid(ending_cutscene):
		_return_to_forest()
		return
	var dark: Node = get_node_or_null("Cutscene/DarkOverlay")
	if is_instance_valid(dark):
		dark.visible = true
	ending_cutscene.visible = true
	ending_cutscene.play()


func _on_cutscene_finished() -> void:
	if is_instance_valid(ending_cutscene):
		ending_cutscene.visible = false
		ending_cutscene.stop()
	var dark: Node = get_node_or_null("Cutscene/DarkOverlay")
	if is_instance_valid(dark):
		dark.visible = false
	# Fade to black before scene change — no flash back to zone
	await _fade_out(0.6)
	get_tree().paused = false
	_stop_strike_system()
	await get_tree().process_frame
	if is_inside_tree():
		get_tree().change_scene_to_file(SCENE_FOREST_HUB)


func _input(event: InputEvent) -> void:
	if is_instance_valid(ending_cutscene) and ending_cutscene.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			ending_cutscene.stop()
			_on_cutscene_finished()


func _fade_out(duration: float = 0.6) -> void:
	var overlay := ColorRect.new()
	overlay.name = "FadeOverlay"
	overlay.color = Color(0, 0, 0, 0)
	overlay.z_index = 9999
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "color:a", 1.0, duration)
	await tween.finished


func _fade_in(duration: float = 0.6) -> void:
	var overlay := get_node_or_null("FadeOverlay")
	if not is_instance_valid(overlay):
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "color:a", 0.0, duration)
	await tween.finished
	overlay.queue_free()
