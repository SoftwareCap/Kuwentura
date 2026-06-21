## storage_hut.gd
extends Node2D

const ZONE_ID := "storage_hut"
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const SCENE_MAIN_MENU := "res://scenes/mainMenu/MainMenu.tscn"
const LEDGER_IMAGE_PATH := "res://assets/sprites/ledger/storagehut_instructions.png"
const SERVER_PEER_ID := 1
const TOTAL_RIDDLES := 5

const TRIANGLE_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/triangleStorageHut.png")
const SQUARE_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/squareStorageHut.png")
const PENTAGON_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/pentagonStorageHut.png")
const HEXAGON_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/hexagonStorageHut.png")
const RECTANGULAR_CONTAINER_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/rectangularContainer.png")
const CYLINDER_CONTAINER_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/cylinderContainer.png")
const TAPE_MEASURE_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/tapeMeasure.png")
const CRUMPLED_PAPER_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/crumplePaperRoll.png")
const RECTANGULAR_PAPER_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/rectangularPrismPaper.png")
const WIDTH_RECT_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/widthRectangular.png")
const LENGTH_RECT_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/lengthRectangular.png")
const HEIGHT_RECT_TEX: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/heightRectangular.png")
const CLOSE_BUTTON_TEX: Texture2D = preload("res://assets/buttons/closeButton.png")
const COMPLETION_SFX: AudioStream = preload("res://assets/audios/ZoneCompletionSFX.mp3")
const OCRA_FONT: FontFile = preload("res://assets/fonts/ocraextended.ttf")

const UI_CREAM := Color(0.98, 0.95, 0.88, 1.0)
const UI_INK := Color(0.22, 0.13, 0.07, 1.0)
const UI_PANEL := Color(0.13, 0.08, 0.04, 0.92)
const UI_PANEL_SOFT := Color(0.25, 0.16, 0.08, 0.88)
const UI_PRIMARY := Color(0.54, 0.35, 0.16, 1.0)
const UI_PRIMARY_HOVER := Color(0.66, 0.44, 0.20, 1.0)
const UI_PRIMARY_PRESSED := Color(0.43, 0.26, 0.10, 1.0)
const UI_BORDER := Color(0.96, 0.83, 0.58, 1.0)
const UI_SUCCESS := Color(0.53, 0.86, 0.47, 1.0)
const UI_ERROR := Color(0.91, 0.42, 0.34, 1.0)
const UI_INFO := Color(0.99, 0.91, 0.63, 1.0)
const UI_DISABLED := Color(0.50, 0.45, 0.40, 0.9)

const DARKNESS_LEVELS := [0.80, 0.65, 0.50, 0.35, 0.20, 0.0]
const SPARKLE_MIN_SCALE := 0.45
const SPARKLE_MAX_SCALE := 0.55
const SPARKLE_PULSE_SPEED := 4.0

const ROLE_DETECTIVE := "detective"
const ROLE_SIDEKICK := "sidekick"

const SHAPE_TEXTURES := {
	"triangle": TRIANGLE_TEX,
	"square": SQUARE_TEX,
	"pentagon": PENTAGON_TEX,
	"hexagon": HEXAGON_TEX,
}

const RIDDLES := [
	{
		"shapes": ["triangle", "square"],
		"operators": ["+"],
		"answer": 7,
		"viewer": ROLE_DETECTIVE,
		"answerer": ROLE_SIDEKICK,
	},
	{
		"shapes": ["pentagon", "triangle"],
		"operators": ["+"],
		"answer": 8,
		"viewer": ROLE_SIDEKICK,
		"answerer": ROLE_DETECTIVE,
	},
	{
		"shapes": ["hexagon", "square"],
		"operators": ["-"],
		"answer": 2,
		"viewer": ROLE_DETECTIVE,
		"answerer": ROLE_SIDEKICK,
	},
	{
		"shapes": ["triangle", "triangle", "square"],
		"operators": ["+", "+"],
		"answer": 10,
		"viewer": ROLE_SIDEKICK,
		"answerer": ROLE_DETECTIVE,
	},
	{
		"shapes": ["hexagon", "pentagon", "triangle"],
		"operators": ["+", "+"],
		"answer": 14,
		"viewer": ROLE_DETECTIVE,
		"answerer": ROLE_SIDEKICK,
	},
]

const CHEST_LOCKS := [
	{
		"type": "rectangular",
		"title": "Sealed Container",
		"texture": RECTANGULAR_CONTAINER_TEX,
		"dimensions": "Width = 4   Length = 5   Height = 3",
		"formula": "Capacity = width x length x height",
		"answer": 60,
	},
]

const MEASUREMENT_STEPS := [
	{
		"key": "width",
		"title": "Measure the Width",
		"label": "Width",
		"answerer": ROLE_DETECTIVE,
		"instruction": "Use the tape mark across the vessel's width. Enter the number shown.",
		"answer": 4,
		"texture": WIDTH_RECT_TEX,
	},
	{
		"key": "length",
		"title": "Measure the Length",
		"label": "Length",
		"answerer": ROLE_SIDEKICK,
		"instruction": "Use the tape mark along the vessel's length. Enter the number shown.",
		"answer": 5,
		"texture": LENGTH_RECT_TEX,
	},
	{
		"key": "height",
		"title": "Measure the Height",
		"label": "Height",
		"answerer": ROLE_DETECTIVE,
		"instruction": "Use the tape mark up the vessel's height. Enter the number shown.",
		"answer": 3,
		"texture": HEIGHT_RECT_TEX,
	},
]

const LOCK_HINT_TEXT := "The vessel hides the code in its own measure. Find its volume and break the seal."

@onready var role_label: Label = get_node_or_null("RoleLabel") as Label
@onready var back_button: Button = get_node_or_null("BackButton") as Button
@onready var background_sprite: Sprite2D = _first_valid_node(["BackgroundLayer/StorageBackground", "BackgroundLayer/BackyardBackground"]) as Sprite2D
@onready var chest_object: Area2D = get_node_or_null("RoomObjectLayer/ChestObject") as Area2D
@onready var chest_sprite: Sprite2D = get_node_or_null("RoomObjectLayer/ChestObject/ChestSprite") as Sprite2D
@onready var chest_collision: CollisionShape2D = get_node_or_null("RoomObjectLayer/ChestObject/CollisionShape2D") as CollisionShape2D
@onready var measuring_tool_object: Area2D = get_node_or_null("RoomObjectLayer/MeasuringToolObject") as Area2D
@onready var measuring_tool_sprite: Sprite2D = get_node_or_null("RoomObjectLayer/MeasuringToolObject/MeasuringToolSprite") as Sprite2D
@onready var measuring_tool_collision: CollisionShape2D = get_node_or_null("RoomObjectLayer/MeasuringToolObject/CollisionShape2D") as CollisionShape2D
@onready var scratch_paper_object: Area2D = get_node_or_null("RoomObjectLayer/ScratchPaperObject") as Area2D
@onready var scratch_paper_sprite: Sprite2D = get_node_or_null("RoomObjectLayer/ScratchPaperObject/ScratchPaperSprite") as Sprite2D
@onready var scratch_paper_collision: CollisionShape2D = get_node_or_null("RoomObjectLayer/ScratchPaperObject/CollisionShape2D") as CollisionShape2D
@onready var lighting_control: Control = get_node_or_null("LightingLayer/Control") as Control
@onready var dark_overlay: ColorRect = get_node_or_null("LightingLayer/Control/DarkOverlay") as ColorRect
@onready var lantern_glow: ColorRect = get_node_or_null("LightingLayer/Control/LanternGlow") as ColorRect
@onready var glow_progress_panel: Panel = get_node_or_null("LightingLayer/Control/GlowProgressPanel") as Panel
@onready var glow_title_label: Label = get_node_or_null("LightingLayer/Control/GlowProgressPanel/GlowTitleLabel") as Label
@onready var glow_counter_label: Label = get_node_or_null("LightingLayer/Control/GlowProgressPanel/GlowCounterLabel") as Label

@onready var riddle_layer: CanvasLayer = get_node_or_null("RiddleLayer") as CanvasLayer
@onready var riddle_panel: Panel = get_node_or_null("RiddleLayer/RiddlePanel") as Panel
@onready var riddle_header_label: Label = get_node_or_null("RiddleLayer/RiddlePanel/RiddleHeaderLabel") as Label
@onready var turn_label: Label = get_node_or_null("RiddleLayer/RiddlePanel/TurnLabel") as Label
@onready var viewer_instruction_label: Label = get_node_or_null("RiddleLayer/RiddlePanel/ViewerInstructionLabel") as Label
@onready var shape_viewer_panel: Panel = get_node_or_null("RiddleLayer/ShapeViewerPanel") as Panel
@onready var legacy_shape_expression_node: Node2D = get_node_or_null("RiddleLayer/ShapeViewerPanel/ShapeExpressionNode") as Node2D
@onready var shape_row: HBoxContainer = get_node_or_null("RiddleLayer/ShapeViewerPanel/ShapeExpressionRow") as HBoxContainer
@onready var shape_slot_1: Sprite2D = get_node_or_null("RiddleLayer/ShapeViewerPanel/ShapeExpressionRow/ShapeSlot1") as Sprite2D
@onready var shape_slot_2: Sprite2D = get_node_or_null("RiddleLayer/ShapeViewerPanel/ShapeExpressionRow/ShapeSlot2") as Sprite2D
@onready var shape_slot_3: Sprite2D = get_node_or_null("RiddleLayer/ShapeViewerPanel/ShapeExpressionRow/ShapeSlot3") as Sprite2D
@onready var operator_label_1: Label = get_node_or_null("RiddleLayer/ShapeViewerPanel/ShapeExpressionRow/OperatorLabel1") as Label
@onready var operator_label_2: Label = get_node_or_null("RiddleLayer/ShapeViewerPanel/ShapeExpressionRow/OperatorLabel2") as Label
@onready var equals_label: Label = get_node_or_null("RiddleLayer/ShapeViewerPanel/ShapeExpressionRow/EqualsLabel") as Label
@onready var answer_panel: Panel = get_node_or_null("RiddleLayer/AnswerPanel") as Panel
@onready var answer_instruction_label: Label = get_node_or_null("RiddleLayer/AnswerPanel/AnswerInstructionLabel") as Label
@onready var answer_input: LineEdit = get_node_or_null("RiddleLayer/AnswerPanel/AnswerInput") as LineEdit
@onready var submit_answer_button: Button = get_node_or_null("RiddleLayer/AnswerPanel/SubmitAnswerButton") as Button
@onready var feedback_label: Label = get_node_or_null("RiddleLayer/FeedbackLabel") as Label

@onready var chest_ui_layer: CanvasLayer = get_node_or_null("ChestUILayer") as CanvasLayer
@onready var chest_modal: Panel = get_node_or_null("ChestUILayer/ChestModal") as Panel
@onready var modal_title_label: Label = get_node_or_null("ChestUILayer/ChestModal/ModalTitleLabel") as Label
@onready var modal_instruction_label: Label = get_node_or_null("ChestUILayer/ChestModal/ModalInstructionLabel") as Label
@onready var container_preview: Sprite2D = get_node_or_null("ChestUILayer/ChestModal/ContainerPreview") as Sprite2D
@onready var dimension_label: Label = get_node_or_null("ChestUILayer/ChestModal/DimensionLabel") as Label
@onready var passcode_input: LineEdit = get_node_or_null("ChestUILayer/ChestModal/PasscodeInput") as LineEdit
@onready var submit_passcode_button: Button = get_node_or_null("ChestUILayer/ChestModal/SubmitPasscodeButton") as Button
@onready var hint_button: Button = get_node_or_null("ChestUILayer/ChestModal/HintButton") as Button
@onready var close_chest_button: Button = get_node_or_null("ChestUILayer/ChestModal/CloseChestButton") as Button
@onready var chest_feedback_label: Label = get_node_or_null("ChestUILayer/ChestModal/ChestFeedbackLabel") as Label

@onready var measurement_ui_layer: CanvasLayer = get_node_or_null("MeasurementUILayer") as CanvasLayer
@onready var measurement_modal: Panel = get_node_or_null("MeasurementUILayer/MeasurementModal") as Panel
@onready var measurement_title_label: Label = get_node_or_null("MeasurementUILayer/MeasurementModal/MeasurementTitleLabel") as Label
@onready var measurement_instruction_label: Label = get_node_or_null("MeasurementUILayer/MeasurementModal/MeasurementInstructionLabel") as Label
@onready var measurement_image: Sprite2D = get_node_or_null("MeasurementUILayer/MeasurementModal/MeasurementImage") as Sprite2D
@onready var measurement_answer_input: LineEdit = get_node_or_null("MeasurementUILayer/MeasurementModal/MeasurementAnswerInput") as LineEdit
@onready var confirm_measurement_button: Button = get_node_or_null("MeasurementUILayer/MeasurementModal/ConfirmMeasurementButton") as Button
@onready var close_measurement_button: Button = get_node_or_null("MeasurementUILayer/MeasurementModal/CloseMeasurementButton") as Button
@onready var measurement_feedback_label: Label = get_node_or_null("MeasurementUILayer/MeasurementModal/MeasurementFeedbackLabel") as Label
@onready var measurement_summary_label: Label = get_node_or_null("MeasurementUILayer/MeasurementModal/MeasurementSummaryLabel") as Label

@onready var scratch_paper_ui_layer: CanvasLayer = get_node_or_null("ScratchPaperUILayer") as CanvasLayer
@onready var scratch_paper_modal: Panel = get_node_or_null("ScratchPaperUILayer/ScratchPaperModal") as Panel
@onready var scratch_paper_title_label: Label = get_node_or_null("ScratchPaperUILayer/ScratchPaperModal/ScratchPaperTitleLabel") as Label
@onready var scratch_paper_image: Sprite2D = get_node_or_null("ScratchPaperUILayer/ScratchPaperModal/ScratchPaperImage") as Sprite2D
@onready var rectangular_paper_button: Button = get_node_or_null("ScratchPaperUILayer/ScratchPaperModal/RectangularPaperButton") as Button
@onready var cylinder_paper_button: Button = get_node_or_null("ScratchPaperUILayer/ScratchPaperModal/CylinderPaperButton") as Button
@onready var close_scratch_paper_button: Button = get_node_or_null("ScratchPaperUILayer/ScratchPaperModal/CloseScratchPaperButton") as Button
@onready var scratch_paper_feedback_label: Label = get_node_or_null("ScratchPaperUILayer/ScratchPaperModal/ScratchPaperFeedbackLabel") as Label

@onready var sidekick_layer: CanvasLayer = get_node_or_null("SidekickLayer") as CanvasLayer
@onready var ledger_panel: Panel = get_node_or_null("SidekickLayer/Ledger") as Panel
@onready var ledger_title: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerTitle") as Label
@onready var ledger_body: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerBody") as Label
@onready var ledger_left_header: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerLeftHeader") as Label
@onready var ledger_left_body: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerLeftBody") as Label
@onready var ledger_right_header: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerRightHeader") as Label
@onready var ledger_right_body: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerRightBody") as Label
@onready var briefcase_panel: Panel = get_node_or_null("SidekickLayer/Briefcase") as Panel
@onready var briefcase_display: TextureRect = get_node_or_null("SidekickLayer/Briefcase/BriefcaseDisplay") as TextureRect
var _ledger_instruction_image: TextureRect = null

@onready var reward_layer: CanvasLayer = get_node_or_null("RewardLayer") as CanvasLayer
@onready var reward_dark_overlay: ColorRect = get_node_or_null("RewardLayer/DarkOverlay") as ColorRect
@onready var reward_banner_label: Label = get_node_or_null("RewardLayer/BannerLabel") as Label
@onready var reward_panel: Sprite2D = get_node_or_null("RewardLayer/RewardPanel") as Sprite2D
@onready var reward_text_label: Label = get_node_or_null("RewardLayer/RewardPanel/RewardText") as Label
@onready var clue_sprite: Sprite2D = get_node_or_null("RewardLayer/ClueSprite") as Sprite2D
@onready var sparkle: Sprite2D = get_node_or_null("RewardLayer/Sparkle") as Sprite2D
@onready var tap_instruction_label: Label = get_node_or_null("RewardLayer/TapInstruction") as Label
@onready var tap_catcher: Button = get_node_or_null("RewardLayer/TapCatcher") as Button
@onready var collect_button: Button = get_node_or_null("RewardLayer/CollectButton") as Button
@onready var briefcase_reveal_sprite: TextureRect = get_node_or_null("RewardLayer/BriefcaseRevealSprite") as TextureRect

@onready var notification_ui: CanvasLayer = get_node_or_null("NotificationUI") as CanvasLayer
@onready var notification_panel: Panel = get_node_or_null("NotificationUI/Panel") as Panel
@onready var notification_label: Label = get_node_or_null("NotificationUI/Panel/Label") as Label
@onready var pause_canvas_layer: CanvasLayer = get_node_or_null("PauseCanvasLayer") as CanvasLayer
@onready var pause_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel") as Panel
@onready var option_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel") as Panel
@onready var volume_slider: HSlider = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider") as HSlider
@onready var volume_value_label: Label = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue") as Label
@onready var inside_zone_control: CanvasLayer = get_node_or_null("InsideZoneControl") as CanvasLayer
@onready var progress_sprite: Sprite2D = get_node_or_null("ProgressTracker/Sprite2D") as Sprite2D

@export var progress_default_tex: Texture2D
@export var progress_solved_tex: Texture2D

var _current_riddle_index: int = 0
var _glow_progress: int = 0
var _chest_revealed: bool = false
var _reward_active: bool = false
var _waiting_reward_continue: bool = false
var _reward_stage: int = 0
var _collect_sequence_started: bool = false
var _is_submitting_riddle: bool = false
var _is_submitting_chest: bool = false
var _is_submitting_measurement: bool = false
var _chest_lock_index: int = 0
var _final_phase_unlocked: bool = false
var _current_measurement_index: int = 0
var _recorded_measurements: Dictionary = {}
var _scratch_paper_seen: bool = false
var _zone_failed: bool = false
var _clue_collected: bool = false
var _sparkle_animating: bool = false
var _animation_time: float = 0.0
var _sfx_player: AudioStreamPlayer
var _aswang_overlay: ColorRect = null
var _shape_expression_layer: Control = null
var _runtime_shape_rects: Array[TextureRect] = []
var _runtime_operator_labels: Array[Label] = []
var _runtime_equals_label: Label = null
var _clear_answer_button: Button = null
var _passcode_digit_2: LineEdit = null
var _measurement_backdrop: ColorRect = null
var _measurement_clear_button: Button = null
var _measurement_intro_active: bool = false
var _chest_glow_rect: ColorRect = null
var _measurement_value_labels: Array[Label] = []


func _ready() -> void:
	_ensure_sfx_bus()
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

	if is_instance_valid(role_label):
		role_label.text = "Role: " + GameState.get_role_display_text()

	setup_layout()
	_setup_initial_state()
	_populate_ledger()
	_connect_signals()
	_refresh_inside_zone_buttons()
	_refresh_briefcase()

	if not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)
	if not GameState.briefcase_updated.is_connected(_refresh_briefcase):
		GameState.briefcase_updated.connect(_refresh_briefcase)

	MusicController.play_track(MusicController.MusicTrack.BACKYARD_PATH)
	_initialize_chest_lock_sync()
	_sync_riddle_ui("The hut is dark. Solve the carved shapes together.", false)


func _process(delta: float) -> void:
	if _sparkle_animating and is_instance_valid(sparkle) and sparkle.visible:
		_animation_time += delta
		var pulse := (sin(_animation_time * SPARKLE_PULSE_SPEED) + 1.0) / 2.0
		var target_scale: float = lerpf(SPARKLE_MIN_SCALE, SPARKLE_MAX_SCALE, pulse)
		sparkle.scale = Vector2(target_scale, target_scale)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(chest_modal) or not chest_modal.visible:
		return
	if not _is_click_event(event):
		return
	var click_position := Vector2.ZERO
	if event is InputEventMouseButton:
		click_position = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch:
		click_position = (event as InputEventScreenTouch).position
	if not chest_modal.get_global_rect().has_point(click_position):
		chest_modal.visible = false


func setup_layout() -> void:
	var screen_size := get_viewport_rect().size
	if screen_size == Vector2.ZERO:
		screen_size = Vector2(1280, 720)
	_apply_ocra_font_tree(self)
	var riddle_width: float = min(720.0, screen_size.x - 420.0)
	if riddle_width < 500.0:
		riddle_width = min(screen_size.x - 60.0, 560.0)
	var riddle_x := (screen_size.x - riddle_width) * 0.5
	var shape_panel_width: float = min(660.0, screen_size.x - 240.0)
	if shape_panel_width < 520.0:
		shape_panel_width = min(screen_size.x - 80.0, 560.0)
	var shape_panel_height: float = clampf(screen_size.y * 0.24, 138.0, 182.0)
	var shape_panel_y: float = clampf(screen_size.y * 0.31, 176.0, screen_size.y - 380.0)
	var feedback_width: float = min(720.0, screen_size.x - 80.0)

	if is_instance_valid(background_sprite):
		background_sprite.position = screen_size * 0.5
		var tex_size := Vector2(1280, 720)
		if background_sprite.texture:
			tex_size = background_sprite.texture.get_size()
		var scale_factor: float = max(screen_size.x / tex_size.x, screen_size.y / tex_size.y)
		background_sprite.scale = Vector2(scale_factor, scale_factor)

	if is_instance_valid(lighting_control):
		lighting_control.position = Vector2.ZERO
		lighting_control.size = screen_size
		lighting_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for overlay in [dark_overlay, lantern_glow]:
		if overlay is ColorRect:
			overlay.position = Vector2.ZERO
			overlay.size = screen_size
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(lantern_glow):
		lantern_glow.color = Color(1.0, 0.78, 0.35, 0.08)
		lantern_glow.visible = false

	if is_instance_valid(glow_progress_panel):
		glow_progress_panel.position = Vector2(24.0, 60.0)
		glow_progress_panel.size = Vector2(238.0, 78.0)
		_apply_panel_style(glow_progress_panel, UI_PANEL_SOFT)
	if is_instance_valid(glow_title_label):
		_place_label(glow_title_label, Vector2(12, 7), Vector2(214, 24), 13, UI_INFO)
		glow_title_label.text = "Storage Hut"
	if is_instance_valid(glow_counter_label):
		_place_label(glow_counter_label, Vector2(12, 36), Vector2(214, 30), 14, UI_CREAM)

	if is_instance_valid(riddle_panel):
		riddle_panel.position = Vector2(riddle_x, 34.0)
		riddle_panel.size = Vector2(riddle_width, 148.0)
		_apply_panel_style(riddle_panel, UI_PANEL)
	if is_instance_valid(riddle_header_label):
		_place_label(riddle_header_label, Vector2(18, 10), Vector2(riddle_width - 36.0, 34), 29, UI_CREAM)
	if is_instance_valid(turn_label):
		_place_label(turn_label, Vector2(18, 50), Vector2(riddle_width - 36.0, 30), 22, UI_INFO)
	if is_instance_valid(viewer_instruction_label):
		_place_label(viewer_instruction_label, Vector2(18, 92), Vector2(riddle_width - 36.0, 42), 16, UI_CREAM)
		viewer_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if is_instance_valid(shape_viewer_panel):
		shape_viewer_panel.position = Vector2((screen_size.x - shape_panel_width) * 0.5, shape_panel_y)
		shape_viewer_panel.size = Vector2(shape_panel_width, shape_panel_height)
		_apply_panel_style(shape_viewer_panel, Color(0.08, 0.05, 0.03, 0.88))
		shape_viewer_panel.z_index = 20
		_ensure_shape_expression_layer()
		_hide_legacy_shape_nodes()
	if is_instance_valid(shape_row):
		shape_row.position = Vector2.ZERO
		shape_row.size = shape_viewer_panel.size if is_instance_valid(shape_viewer_panel) else Vector2(shape_panel_width, shape_panel_height)
		shape_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape_row.visible = false

	_normalize_shape_expression_parent()
	_layout_shape_expression()

	if is_instance_valid(answer_panel):
		answer_panel.position = Vector2(screen_size.x * 0.5 - 310.0, screen_size.y - 230.0)
		answer_panel.size = Vector2(620.0, 190.0)
		_apply_panel_style(answer_panel, UI_PANEL)
	if is_instance_valid(answer_instruction_label):
		_place_label(answer_instruction_label, Vector2(18, 10), Vector2(584, 30), 18, UI_CREAM)
	if is_instance_valid(answer_input):
		answer_input.position = Vector2(70, 50)
		answer_input.size = Vector2(480, 58)
		answer_input.placeholder_text = "Enter Answer"
		answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		answer_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		answer_input.max_length = 3
		answer_input.add_theme_font_override("font", OCRA_FONT)
		answer_input.add_theme_font_size_override("font_size", 24)
		_apply_line_edit_style(answer_input)
	_ensure_clear_answer_button()
	if is_instance_valid(_clear_answer_button):
		_clear_answer_button.position = Vector2(122, 124)
		_clear_answer_button.size = Vector2(170, 52)
		_apply_button_style(_clear_answer_button)
		_clear_answer_button.add_theme_font_size_override("font_size", 20)
	if is_instance_valid(submit_answer_button):
		submit_answer_button.position = Vector2(328, 124)
		submit_answer_button.size = Vector2(170, 52)
		submit_answer_button.text = "Submit"
		_apply_button_style(submit_answer_button)
		submit_answer_button.add_theme_font_size_override("font_size", 20)
	if is_instance_valid(feedback_label):
		feedback_label.position = Vector2((screen_size.x - feedback_width) * 0.5, shape_panel_y + shape_panel_height + 12.0)
		feedback_label.size = Vector2(feedback_width, 38.0)
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		feedback_label.add_theme_font_size_override("font_size", 22)
		feedback_label.add_theme_constant_override("outline_size", 2)
		feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))

	if is_instance_valid(chest_modal):
		chest_modal.size = Vector2(620.0, 330.0)
		chest_modal.position = (screen_size - chest_modal.size) * 0.5
		_apply_panel_style(chest_modal, Color(0.12, 0.075, 0.04, 0.97))
	if is_instance_valid(modal_title_label):
		_place_label(modal_title_label, Vector2(24, 44), Vector2(572, 52), 32, UI_CREAM)
		modal_title_label.text = "Enter Passcode"
	if is_instance_valid(modal_instruction_label):
		_place_label(modal_instruction_label, Vector2(32, 222), Vector2(484, 54), 15, UI_INFO)
		modal_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_instruction_label.visible = false
	if is_instance_valid(container_preview):
		container_preview.visible = false
	if is_instance_valid(dimension_label):
		_place_label(dimension_label, Vector2(32, 278), Vector2(556, 28), 14, UI_ERROR)
		dimension_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dimension_label.visible = false
	if is_instance_valid(passcode_input):
		passcode_input.position = Vector2(178, 128)
		passcode_input.size = Vector2(104, 104)
		passcode_input.placeholder_text = ""
		passcode_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		passcode_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		passcode_input.max_length = 1
		passcode_input.add_theme_font_override("font", OCRA_FONT)
		passcode_input.add_theme_font_size_override("font_size", 40)
		_apply_line_edit_style(passcode_input)
	_ensure_passcode_digit_2()
	if is_instance_valid(_passcode_digit_2):
		_passcode_digit_2.position = Vector2(338, 128)
		_passcode_digit_2.size = Vector2(104, 104)
		_passcode_digit_2.placeholder_text = ""
		_passcode_digit_2.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_passcode_digit_2.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		_passcode_digit_2.max_length = 1
		_passcode_digit_2.add_theme_font_override("font", OCRA_FONT)
		_passcode_digit_2.add_theme_font_size_override("font_size", 40)
		_apply_line_edit_style(_passcode_digit_2)
	if is_instance_valid(submit_passcode_button):
		submit_passcode_button.visible = false
		submit_passcode_button.disabled = true
		_apply_button_style(submit_passcode_button)
	if is_instance_valid(hint_button):
		hint_button.position = Vector2(532, 236)
		hint_button.size = Vector2(58, 58)
		hint_button.text = "i"
		_apply_hint_button_style(hint_button)
		hint_button.add_theme_font_size_override("font_size", 26)
	if is_instance_valid(close_chest_button):
		close_chest_button.visible = false
		close_chest_button.disabled = true
		_apply_button_style(close_chest_button)
	if is_instance_valid(chest_feedback_label):
		_place_label(chest_feedback_label, Vector2(28, 236), Vector2(492, 58), 14, UI_INFO)
		chest_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chest_feedback_label.visible = false

	if is_instance_valid(chest_sprite):
		chest_sprite.position = Vector2(screen_size.x * 0.54, screen_size.y * 0.64)
		chest_sprite.scale = Vector2(0.30, 0.22)
		chest_sprite.self_modulate = Color(1, 1, 1, 1)
	if is_instance_valid(chest_collision) and is_instance_valid(chest_sprite):
		chest_collision.position = chest_sprite.position
	_ensure_chest_glow(screen_size)
	if is_instance_valid(measuring_tool_object):
		measuring_tool_object.position = Vector2(screen_size.x * 0.14, screen_size.y * 0.78)
	if is_instance_valid(measuring_tool_sprite):
		measuring_tool_sprite.texture = TAPE_MEASURE_TEX
		measuring_tool_sprite.scale = Vector2(0.13, 0.13)
	if is_instance_valid(scratch_paper_object):
		scratch_paper_object.position = Vector2(screen_size.x * 0.86, screen_size.y * 0.75)
	if is_instance_valid(scratch_paper_sprite):
		scratch_paper_sprite.texture = CRUMPLED_PAPER_TEX
		scratch_paper_sprite.scale = Vector2(0.13, 0.13)

	_ensure_measurement_backdrop(screen_size)
	if is_instance_valid(measurement_modal):
		measurement_modal.size = Vector2(640.0, 560.0)
		measurement_modal.position = (screen_size - measurement_modal.size) * 0.5
		_apply_panel_style(measurement_modal, Color(0.12, 0.075, 0.04, 0.97))
		measurement_modal.z_index = 5
	if is_instance_valid(measurement_title_label):
		_place_label(measurement_title_label, Vector2(34, 36), Vector2(572, 48), 31, UI_CREAM)
	if is_instance_valid(measurement_instruction_label):
		_place_label(measurement_instruction_label, Vector2(58, 96), Vector2(524, 42), 15, UI_CREAM)
		measurement_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_instance_valid(measurement_image):
		measurement_image.position = Vector2(320, 238)
		measurement_image.scale = Vector2(0.36, 0.36)
	if is_instance_valid(measurement_answer_input):
		measurement_answer_input.position = Vector2(170, 372)
		measurement_answer_input.size = Vector2(300, 42)
		measurement_answer_input.placeholder_text = ""
		measurement_answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		measurement_answer_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		measurement_answer_input.add_theme_font_override("font", OCRA_FONT)
		measurement_answer_input.add_theme_font_size_override("font_size", 24)
		_apply_line_edit_style(measurement_answer_input)
	if is_instance_valid(confirm_measurement_button):
		confirm_measurement_button.position = Vector2(174, 438)
		confirm_measurement_button.size = Vector2(132, 52)
		confirm_measurement_button.text = "Record"
		_apply_button_style(confirm_measurement_button)
	_ensure_measurement_clear_button()
	if is_instance_valid(_measurement_clear_button):
		_measurement_clear_button.position = Vector2(334, 438)
		_measurement_clear_button.size = Vector2(132, 52)
		_measurement_clear_button.text = "Clear"
		_apply_button_style(_measurement_clear_button)
	if is_instance_valid(close_measurement_button):
		close_measurement_button.position = Vector2(574, 4)
		close_measurement_button.size = Vector2(86, 86)
		close_measurement_button.text = ""
		close_measurement_button.icon = CLOSE_BUTTON_TEX
		close_measurement_button.expand_icon = true
		close_measurement_button.flat = true
	if is_instance_valid(measurement_feedback_label):
		_place_label(measurement_feedback_label, Vector2(154, 332), Vector2(170, 130), 18, UI_CREAM)
		measurement_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_instance_valid(measurement_summary_label):
		_place_label(measurement_summary_label, Vector2(340, 330), Vector2(210, 132), 18, UI_INK)
		measurement_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ensure_measurement_value_labels()

	if is_instance_valid(scratch_paper_modal):
		scratch_paper_modal.size = Vector2(720.0, 560.0)
		scratch_paper_modal.position = (screen_size - scratch_paper_modal.size) * 0.5
		_apply_panel_style(scratch_paper_modal, Color(0.12, 0.075, 0.04, 0.97))
	if is_instance_valid(scratch_paper_title_label):
		_place_label(scratch_paper_title_label, Vector2(24, 18), Vector2(672, 44), 30, UI_CREAM)
		scratch_paper_title_label.text = "Crumpled Scratch Paper"
	if is_instance_valid(scratch_paper_image):
		scratch_paper_image.texture = RECTANGULAR_PAPER_TEX
		scratch_paper_image.position = Vector2(360, 250)
		scratch_paper_image.scale = Vector2(0.48, 0.48)
	if is_instance_valid(rectangular_paper_button):
		rectangular_paper_button.visible = false
		rectangular_paper_button.disabled = true
	if is_instance_valid(cylinder_paper_button):
		cylinder_paper_button.position = Vector2(326, 408)
		cylinder_paper_button.size = Vector2(160, 58)
		cylinder_paper_button.text = "Cylinder"
		cylinder_paper_button.visible = false
		cylinder_paper_button.disabled = true
		_apply_button_style(cylinder_paper_button)
	if is_instance_valid(close_scratch_paper_button):
		close_scratch_paper_button.position = Vector2(300, 414)
		close_scratch_paper_button.size = Vector2(120, 56)
		close_scratch_paper_button.text = "Close"
		_apply_button_style(close_scratch_paper_button)
	if is_instance_valid(scratch_paper_feedback_label):
		_place_label(scratch_paper_feedback_label, Vector2(64, 488), Vector2(592, 44), 18, UI_INFO)
		scratch_paper_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _setup_initial_state() -> void:
	_current_riddle_index = 0
	_glow_progress = 0
	_chest_revealed = false
	_reward_active = false
	_waiting_reward_continue = false
	_reward_stage = 0
	_collect_sequence_started = false
	_is_submitting_riddle = false
	_is_submitting_chest = false
	_is_submitting_measurement = false
	_final_phase_unlocked = false
	_current_measurement_index = 0
	_recorded_measurements.clear()
	_scratch_paper_seen = false
	_zone_failed = false
	_clue_collected = GameState.has_clue(ZONE_ID)

	_set_final_objects_visible(false)
	if is_instance_valid(chest_modal):
		chest_modal.visible = false
	if is_instance_valid(chest_ui_layer):
		chest_ui_layer.visible = true
	if is_instance_valid(measurement_ui_layer):
		measurement_ui_layer.visible = true
	if is_instance_valid(measurement_modal):
		measurement_modal.visible = false
	if is_instance_valid(_measurement_backdrop):
		_measurement_backdrop.visible = false
	if is_instance_valid(scratch_paper_ui_layer):
		scratch_paper_ui_layer.visible = true
	if is_instance_valid(scratch_paper_modal):
		scratch_paper_modal.visible = false
	if is_instance_valid(reward_layer):
		reward_layer.visible = false
	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false
	if is_instance_valid(briefcase_panel):
		briefcase_panel.visible = false
	if is_instance_valid(glow_progress_panel):
		glow_progress_panel.visible = true
	if is_instance_valid(notification_panel):
		notification_panel.visible = false
	if is_instance_valid(pause_panel):
		pause_panel.visible = false
	if is_instance_valid(option_panel):
		option_panel.visible = false
	if is_instance_valid(back_button):
		back_button.visible = false
	if is_instance_valid(progress_sprite):
		progress_sprite.texture = progress_default_tex if progress_default_tex else progress_sprite.texture

	_update_darkness()


func _connect_signals() -> void:
	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if is_instance_valid(submit_answer_button) and not submit_answer_button.pressed.is_connected(_on_submit_answer_pressed):
		submit_answer_button.pressed.connect(_on_submit_answer_pressed)
	if is_instance_valid(answer_input) and not answer_input.text_submitted.is_connected(_on_answer_text_submitted):
		answer_input.text_submitted.connect(_on_answer_text_submitted)
	if is_instance_valid(chest_object) and not chest_object.input_event.is_connected(_on_chest_input_event):
		chest_object.input_event.connect(_on_chest_input_event)
	if is_instance_valid(submit_passcode_button) and not submit_passcode_button.pressed.is_connected(_on_submit_passcode_pressed):
		submit_passcode_button.pressed.connect(_on_submit_passcode_pressed)
	if is_instance_valid(passcode_input) and not passcode_input.text_submitted.is_connected(_on_passcode_text_submitted):
		passcode_input.text_submitted.connect(_on_passcode_text_submitted)
	if is_instance_valid(passcode_input) and not passcode_input.text_changed.is_connected(_on_passcode_digit_1_changed):
		passcode_input.text_changed.connect(_on_passcode_digit_1_changed)
	_ensure_passcode_digit_2()
	if is_instance_valid(_passcode_digit_2) and not _passcode_digit_2.text_submitted.is_connected(_on_passcode_text_submitted):
		_passcode_digit_2.text_submitted.connect(_on_passcode_text_submitted)
	if is_instance_valid(_passcode_digit_2) and not _passcode_digit_2.text_changed.is_connected(_on_passcode_digit_2_changed):
		_passcode_digit_2.text_changed.connect(_on_passcode_digit_2_changed)
	if is_instance_valid(close_chest_button) and not close_chest_button.pressed.is_connected(_on_close_chest_pressed):
		close_chest_button.pressed.connect(_on_close_chest_pressed)
	if is_instance_valid(hint_button) and not hint_button.pressed.is_connected(_on_hint_pressed):
		hint_button.pressed.connect(_on_hint_pressed)
	if is_instance_valid(measuring_tool_object) and not measuring_tool_object.input_event.is_connected(_on_measuring_tool_input_event):
		measuring_tool_object.input_event.connect(_on_measuring_tool_input_event)
	if is_instance_valid(scratch_paper_object) and not scratch_paper_object.input_event.is_connected(_on_scratch_paper_input_event):
		scratch_paper_object.input_event.connect(_on_scratch_paper_input_event)
	if is_instance_valid(confirm_measurement_button) and not confirm_measurement_button.pressed.is_connected(_on_confirm_measurement_pressed):
		confirm_measurement_button.pressed.connect(_on_confirm_measurement_pressed)
	if is_instance_valid(measurement_answer_input) and not measurement_answer_input.text_submitted.is_connected(_on_measurement_text_submitted):
		measurement_answer_input.text_submitted.connect(_on_measurement_text_submitted)
	if is_instance_valid(close_measurement_button) and not close_measurement_button.pressed.is_connected(_on_close_measurement_pressed):
		close_measurement_button.pressed.connect(_on_close_measurement_pressed)
	_ensure_measurement_clear_button()
	if is_instance_valid(_measurement_clear_button) and not _measurement_clear_button.pressed.is_connected(_on_clear_measurement_pressed):
		_measurement_clear_button.pressed.connect(_on_clear_measurement_pressed)
	if is_instance_valid(rectangular_paper_button) and not rectangular_paper_button.pressed.is_connected(_on_rectangular_paper_pressed):
		rectangular_paper_button.pressed.connect(_on_rectangular_paper_pressed)
	if is_instance_valid(cylinder_paper_button) and not cylinder_paper_button.pressed.is_connected(_on_cylinder_paper_pressed):
		cylinder_paper_button.pressed.connect(_on_cylinder_paper_pressed)
	if is_instance_valid(close_scratch_paper_button) and not close_scratch_paper_button.pressed.is_connected(_on_close_scratch_paper_pressed):
		close_scratch_paper_button.pressed.connect(_on_close_scratch_paper_pressed)
	if is_instance_valid(tap_catcher) and not tap_catcher.pressed.is_connected(_on_reward_tap_catcher_pressed):
		tap_catcher.pressed.connect(_on_reward_tap_catcher_pressed)
	if is_instance_valid(collect_button) and not collect_button.pressed.is_connected(_on_collect_pressed):
		collect_button.pressed.connect(_on_collect_pressed)
	if is_instance_valid(inside_zone_control):
		if inside_zone_control.has_signal("pause_pressed") and not inside_zone_control.pause_pressed.is_connected(_on_pause_pressed):
			inside_zone_control.pause_pressed.connect(_on_pause_pressed)
		if inside_zone_control.has_signal("ledger_pressed") and not inside_zone_control.ledger_pressed.is_connected(_on_ledger_pressed):
			inside_zone_control.ledger_pressed.connect(_on_ledger_pressed)
		if inside_zone_control.has_signal("briefcase_pressed") and not inside_zone_control.briefcase_pressed.is_connected(_on_briefcase_pressed):
			inside_zone_control.briefcase_pressed.connect(_on_briefcase_pressed)
	_connect_pause_signals()


func _connect_pause_signals() -> void:
	var resume := get_node_or_null("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton") as BaseButton
	if is_instance_valid(resume) and not resume.pressed.is_connected(_on_resume_pressed):
		resume.pressed.connect(_on_resume_pressed)
	var option := get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionButton") as BaseButton
	if is_instance_valid(option) and not option.pressed.is_connected(_on_option_pressed):
		option.pressed.connect(_on_option_pressed)
	var exit_button := get_node_or_null("PauseCanvasLayer/InGamePausePanel/ExitButton") as BaseButton
	if not is_instance_valid(exit_button):
		exit_button = get_node_or_null("PauseCanvasLayer/InGamePausePanel/BackToForest") as BaseButton
	if is_instance_valid(exit_button) and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	var option_back := get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/BackToPrevious") as TouchScreenButton
	if is_instance_valid(option_back) and not option_back.pressed.is_connected(_on_option_back_pressed):
		option_back.pressed.connect(_on_option_back_pressed)
	if is_instance_valid(volume_slider) and not volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.connect(_on_volume_changed)


func _initialize_chest_lock_sync() -> void:
	_apply_chest_lock(0)
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		rpc_sync_chest_lock.rpc(_chest_lock_index)
	else:
		rpc_request_chest_lock.rpc_id(SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_chest_lock() -> void:
	if multiplayer.is_server():
		rpc_sync_chest_lock.rpc_id(multiplayer.get_remote_sender_id(), _chest_lock_index)


@rpc("authority", "reliable", "call_local")
func rpc_sync_chest_lock(lock_index: int) -> void:
	_apply_chest_lock(lock_index)


func _apply_chest_lock(lock_index: int) -> void:
	_chest_lock_index = clampi(lock_index, 0, CHEST_LOCKS.size() - 1)
	_update_chest_modal_content()


func _sync_riddle_ui(message: String = "", is_error: bool = false) -> void:
	if not _chest_revealed:
		_set_chest_visible(false)
	_update_glow_progress_label()
	_update_darkness()

	if _current_riddle_index >= TOTAL_RIDDLES:
		_reveal_chest(message)
		return

	var riddle: Dictionary = RIDDLES[_current_riddle_index]
	var viewer_role := str(riddle.get("viewer", ROLE_DETECTIVE))
	var answer_role := str(riddle.get("answerer", ROLE_SIDEKICK))
	var is_viewer := _is_local_role(viewer_role) or _is_single_player_test()
	var is_answerer := _is_local_role(answer_role) or _is_single_player_test()

	if is_instance_valid(riddle_layer):
		riddle_layer.visible = true
	if is_instance_valid(riddle_header_label):
		riddle_header_label.text = "Shape Riddle %d / %d" % [_current_riddle_index + 1, TOTAL_RIDDLES]
	if is_instance_valid(turn_label):
		turn_label.text = "Viewer: %s   Answer: %s" % [_role_display(viewer_role), _role_display(answer_role)]
	if is_instance_valid(viewer_instruction_label):
		if is_viewer and is_answerer:
			viewer_instruction_label.text = "Count each shape's sides, follow the operator, then enter the result."
		elif is_viewer:
			viewer_instruction_label.text = "Count the sides of each shape and tell your partner the full equation."
		elif is_answerer:
			viewer_instruction_label.text = "Use your partner's shape counts, solve the equation, then enter the number."
		else:
			viewer_instruction_label.text = "Watch your partner's turn."

	if is_instance_valid(shape_viewer_panel):
		shape_viewer_panel.visible = is_viewer
	if is_instance_valid(answer_panel):
		answer_panel.visible = is_answerer
	if is_instance_valid(answer_input):
		answer_input.editable = is_answerer
		answer_input.text = ""
	if is_instance_valid(_clear_answer_button):
		_clear_answer_button.visible = is_answerer
		_clear_answer_button.disabled = not is_answerer
	if is_instance_valid(submit_answer_button):
		submit_answer_button.disabled = not is_answerer
	if is_instance_valid(answer_instruction_label):
		answer_instruction_label.text = "Enter the side-count result."

	_set_shape_expression(riddle)
	_set_feedback(message, is_error)


func _set_shape_expression(riddle: Dictionary) -> void:
	_normalize_shape_expression_parent()
	_ensure_shape_expression_layer()
	var shapes: Array = riddle.get("shapes", [])
	var ops: Array = riddle.get("operators", [])

	for i in range(_runtime_shape_rects.size()):
		var slot := _runtime_shape_rects[i]
		if not is_instance_valid(slot):
			continue
		if i < shapes.size():
			var shape_name := str(shapes[i])
			slot.texture = SHAPE_TEXTURES.get(shape_name, null)
			slot.visible = slot.texture != null
		else:
			slot.visible = false

	for i in range(_runtime_operator_labels.size()):
		var label := _runtime_operator_labels[i]
		if not is_instance_valid(label):
			continue
		label.text = str(ops[i]) if i < ops.size() else ""
		label.visible = i < ops.size()

	if is_instance_valid(_runtime_equals_label):
		_runtime_equals_label.text = "= ?"
		_runtime_equals_label.visible = true

	_layout_shape_expression()


func _layout_shape_expression() -> void:
	if not is_instance_valid(shape_viewer_panel):
		return
	_ensure_shape_expression_layer()
	if not is_instance_valid(_shape_expression_layer):
		return
	var layer_size := _shape_expression_layer.size
	var center_y := layer_size.y * 0.50
	var visible_count := 0
	for slot in _runtime_shape_rects:
		if is_instance_valid(slot) and slot.visible:
			visible_count += 1
	var panel_width := layer_size.x
	var target_sprite_size: float = min(118.0, layer_size.y - 28.0)
	var x_positions := [panel_width * 0.24, panel_width * 0.50, 0.0]
	var op_positions := [panel_width * 0.37, 0.0]
	var equals_x := panel_width * 0.70
	if visible_count >= 3:
		x_positions = [panel_width * 0.16, panel_width * 0.38, panel_width * 0.60]
		op_positions = [panel_width * 0.27, panel_width * 0.49]
		equals_x = panel_width * 0.78
	for i in range(_runtime_shape_rects.size()):
		var slot := _runtime_shape_rects[i]
		if is_instance_valid(slot):
			slot.position = Vector2(x_positions[i] - target_sprite_size * 0.5, center_y - target_sprite_size * 0.5)
			slot.size = Vector2(target_sprite_size, target_sprite_size)
			slot.z_index = 4

	for i in range(_runtime_operator_labels.size()):
		var label := _runtime_operator_labels[i]
		if is_instance_valid(label):
			_place_expression_label(label, Vector2(op_positions[i] - 34.0, center_y - 28.0), Vector2(68, 56))
	if is_instance_valid(_runtime_equals_label):
		_place_expression_label(_runtime_equals_label, Vector2(equals_x - 44.0, center_y - 28.0), Vector2(96, 56))


func _ensure_shape_expression_layer() -> void:
	if not is_instance_valid(shape_viewer_panel):
		return
	if not is_instance_valid(_shape_expression_layer):
		_shape_expression_layer = shape_viewer_panel.get_node_or_null("RuntimeExpressionLayer") as Control
	if not is_instance_valid(_shape_expression_layer):
		_shape_expression_layer = Control.new()
		_shape_expression_layer.name = "RuntimeExpressionLayer"
		shape_viewer_panel.add_child(_shape_expression_layer)
	_shape_expression_layer.position = Vector2.ZERO
	_shape_expression_layer.size = shape_viewer_panel.size
	_shape_expression_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shape_expression_layer.z_index = 10
	_ensure_runtime_expression_nodes()


func _ensure_runtime_expression_nodes() -> void:
	if not is_instance_valid(_shape_expression_layer):
		return
	while _runtime_shape_rects.size() < 3:
		var rect := TextureRect.new()
		rect.name = "ShapeSlotUI%d" % (_runtime_shape_rects.size() + 1)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.visible = false
		_shape_expression_layer.add_child(rect)
		_runtime_shape_rects.append(rect)
	while _runtime_operator_labels.size() < 2:
		var label := Label.new()
		label.name = "OperatorLabelUI%d" % (_runtime_operator_labels.size() + 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = false
		_shape_expression_layer.add_child(label)
		_runtime_operator_labels.append(label)
	if not is_instance_valid(_runtime_equals_label):
		_runtime_equals_label = Label.new()
		_runtime_equals_label.name = "EqualsLabelUI"
		_runtime_equals_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_runtime_equals_label.visible = false
		_shape_expression_layer.add_child(_runtime_equals_label)

	for old_node in [shape_slot_1, shape_slot_2, shape_slot_3, operator_label_1, operator_label_2, equals_label]:
		if is_instance_valid(old_node):
			old_node.visible = false
	_hide_legacy_shape_nodes()


func _normalize_shape_expression_parent() -> void:
	if not is_instance_valid(shape_viewer_panel):
		return
	_ensure_shape_expression_layer()
	for old_node in [shape_slot_1, shape_slot_2, shape_slot_3, operator_label_1, operator_label_2, equals_label]:
		if is_instance_valid(old_node):
			old_node.visible = false
	_hide_legacy_shape_nodes()


func _hide_legacy_shape_nodes() -> void:
	var legacy_nodes: Array[Node] = [
		legacy_shape_expression_node,
		shape_row,
		shape_slot_1,
		shape_slot_2,
		shape_slot_3,
		operator_label_1,
		operator_label_2,
		equals_label,
	]
	for legacy_node in legacy_nodes:
		_hide_canvas_item_tree(legacy_node)


func _hide_canvas_item_tree(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	for child in node.get_children():
		_hide_canvas_item_tree(child)


func _fit_sprite_to_size(sprite: Sprite2D, target_size: float) -> void:
	if not is_instance_valid(sprite) or sprite.texture == null:
		return
	var texture_size := sprite.texture.get_size()
	var largest_side: float = max(texture_size.x, texture_size.y)
	if largest_side <= 0.0:
		return
	var scale_value := target_size / largest_side
	sprite.scale = Vector2(scale_value, scale_value)


func _place_expression_label(label: Label, pos: Vector2, size: Vector2) -> void:
	label.position = pos
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", OCRA_FONT)
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", UI_CREAM)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))


func _on_answer_text_submitted(_text: String) -> void:
	_on_submit_answer_pressed()


func _ensure_clear_answer_button() -> void:
	if not is_instance_valid(answer_panel):
		return
	if not is_instance_valid(_clear_answer_button):
		_clear_answer_button = answer_panel.get_node_or_null("ClearAnswerButton") as Button
	if not is_instance_valid(_clear_answer_button):
		_clear_answer_button = Button.new()
		_clear_answer_button.name = "ClearAnswerButton"
		_clear_answer_button.text = "Clear"
		answer_panel.add_child(_clear_answer_button)
	if not _clear_answer_button.pressed.is_connected(_on_clear_answer_pressed):
		_clear_answer_button.pressed.connect(_on_clear_answer_pressed)


func _ensure_measurement_backdrop(screen_size: Vector2) -> void:
	if not is_instance_valid(measurement_ui_layer):
		return
	if not is_instance_valid(_measurement_backdrop):
		_measurement_backdrop = measurement_ui_layer.get_node_or_null("MeasurementBackdrop") as ColorRect
	if not is_instance_valid(_measurement_backdrop):
		_measurement_backdrop = ColorRect.new()
		_measurement_backdrop.name = "MeasurementBackdrop"
		measurement_ui_layer.add_child(_measurement_backdrop)
		measurement_ui_layer.move_child(_measurement_backdrop, 0)
	_measurement_backdrop.position = Vector2.ZERO
	_measurement_backdrop.size = screen_size
	_measurement_backdrop.color = Color(0.0, 0.0, 0.0, 0.68)
	_measurement_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_measurement_backdrop.visible = false
	_measurement_backdrop.z_index = 0


func _ensure_chest_glow(screen_size: Vector2) -> void:
	var glow_parent: Node = self
	if is_instance_valid(chest_object) and is_instance_valid(chest_object.get_parent()):
		glow_parent = chest_object.get_parent()
	if not is_instance_valid(_chest_glow_rect):
		_chest_glow_rect = get_node_or_null("ChestInteractGlow") as ColorRect
	if not is_instance_valid(_chest_glow_rect):
		_chest_glow_rect = ColorRect.new()
		_chest_glow_rect.name = "ChestInteractGlow"
		glow_parent.add_child(_chest_glow_rect)
	if _chest_glow_rect.get_parent() != glow_parent:
		_chest_glow_rect.reparent(glow_parent)
	if is_instance_valid(glow_parent):
		glow_parent.move_child(_chest_glow_rect, 0)
	var glow_size := Vector2(clampf(screen_size.x * 0.20, 210.0, 320.0), clampf(screen_size.y * 0.16, 90.0, 145.0))
	var glow_center := Vector2(screen_size.x * 0.54, screen_size.y * 0.64)
	_chest_glow_rect.position = glow_center - glow_size * 0.5
	_chest_glow_rect.size = glow_size
	_chest_glow_rect.color = Color(1.0, 0.74, 0.30, 0.16)
	_chest_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_glow_rect.z_index = -1
	_chest_glow_rect.visible = _final_phase_unlocked and not _reward_active and not _zone_failed


func _ensure_measurement_clear_button() -> void:
	if not is_instance_valid(measurement_modal):
		return
	if not is_instance_valid(_measurement_clear_button):
		_measurement_clear_button = measurement_modal.get_node_or_null("ClearMeasurementButton") as Button
	if not is_instance_valid(_measurement_clear_button):
		_measurement_clear_button = Button.new()
		_measurement_clear_button.name = "ClearMeasurementButton"
		measurement_modal.add_child(_measurement_clear_button)
	if not _measurement_clear_button.pressed.is_connected(_on_clear_measurement_pressed):
		_measurement_clear_button.pressed.connect(_on_clear_measurement_pressed)


func _ensure_measurement_value_labels() -> void:
	if not is_instance_valid(measurement_modal):
		return
	while _measurement_value_labels.size() < 3:
		var value_label := Label.new()
		value_label.name = "MeasurementValue%d" % (_measurement_value_labels.size() + 1)
		value_label.visible = false
		measurement_modal.add_child(value_label)
		_measurement_value_labels.append(value_label)
	var values := ["4", "5", "3"]
	for i in range(_measurement_value_labels.size()):
		var label := _measurement_value_labels[i]
		if not is_instance_valid(label):
			continue
		label.text = values[i] if i < values.size() else ""
		_place_label(label, Vector2(348, 322 + i * 56), Vector2(196, 38), 17, UI_INK)
		_apply_measurement_value_style(label)


func _show_measurement_values() -> void:
	_ensure_measurement_value_labels()
	for label in _measurement_value_labels:
		if is_instance_valid(label):
			label.visible = true


func _hide_measurement_values() -> void:
	for label in _measurement_value_labels:
		if is_instance_valid(label):
			label.visible = false


func _ensure_passcode_digit_2() -> void:
	if not is_instance_valid(chest_modal):
		return
	if not is_instance_valid(_passcode_digit_2):
		_passcode_digit_2 = chest_modal.get_node_or_null("PasscodeDigit2") as LineEdit
	if not is_instance_valid(_passcode_digit_2):
		_passcode_digit_2 = LineEdit.new()
		_passcode_digit_2.name = "PasscodeDigit2"
		chest_modal.add_child(_passcode_digit_2)
	_passcode_digit_2.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_passcode_digit_2.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_passcode_digit_2.max_length = 1
	_passcode_digit_2.add_theme_font_override("font", OCRA_FONT)
	_passcode_digit_2.add_theme_font_size_override("font_size", 40)
	_apply_line_edit_style(_passcode_digit_2)


func _on_clear_answer_pressed() -> void:
	if is_instance_valid(answer_input):
		answer_input.text = ""
		answer_input.grab_focus()


func _on_submit_answer_pressed() -> void:
	if _is_submitting_riddle or _zone_failed or _reward_active:
		return
	if _current_riddle_index >= TOTAL_RIDDLES:
		return
	var answer_role := str(RIDDLES[_current_riddle_index].get("answerer", ROLE_SIDEKICK))
	if not (_is_local_role(answer_role) or _is_single_player_test()):
		show_notification("It is your partner's turn to answer.", 1.6)
		return
	if not is_instance_valid(answer_input):
		return

	var answer_text := answer_input.text.strip_edges()
	if answer_text.is_empty() or not answer_text.is_valid_int():
		_set_feedback("Enter a whole number.", true)
		return

	_is_submitting_riddle = true
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_validate_riddle_answer(int(answer_text))
	else:
		rpc_submit_riddle_answer.rpc_id(SERVER_PEER_ID, int(answer_text), _current_riddle_index)
	await get_tree().create_timer(0.18).timeout
	_is_submitting_riddle = false


@rpc("any_peer", "reliable")
func rpc_submit_riddle_answer(answer: int, riddle_index: int) -> void:
	if not multiplayer.is_server() or _zone_failed:
		return
	if riddle_index != _current_riddle_index:
		rpc_sync_riddle_state.rpc_id(multiplayer.get_remote_sender_id(), _current_riddle_index, _glow_progress, _chest_revealed, "The hut has already changed. Try the current riddle.", true)
		return
	var answer_role := str(RIDDLES[_current_riddle_index].get("answerer", ROLE_SIDEKICK))
	if answer_role != ROLE_SIDEKICK:
		return
	_validate_riddle_answer(answer)


func _validate_riddle_answer(answer: int) -> void:
	var correct := int(RIDDLES[_current_riddle_index].get("answer", 0))
	if answer == correct:
		_current_riddle_index += 1
		_glow_progress = min(_glow_progress + 1, TOTAL_RIDDLES)
		var message := "The lantern glows brighter."
		if _current_riddle_index >= TOTAL_RIDDLES:
			message = "The hut is fully revealed."
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			rpc_sync_riddle_state.rpc(_current_riddle_index, _glow_progress, _current_riddle_index >= TOTAL_RIDDLES, message, false)
		else:
			rpc_sync_riddle_state(_current_riddle_index, _glow_progress, _current_riddle_index >= TOTAL_RIDDLES, message, false)
	else:
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			rpc_sync_riddle_state.rpc(_current_riddle_index, _glow_progress, _chest_revealed, "The lantern flickers. Try again.", true)
		else:
			rpc_sync_riddle_state(_current_riddle_index, _glow_progress, _chest_revealed, "The lantern flickers. Try again.", true)


@rpc("authority", "reliable", "call_local")
func rpc_sync_riddle_state(riddle_index: int, glow_progress: int, chest_revealed: bool, message: String, is_error: bool) -> void:
	_current_riddle_index = clampi(riddle_index, 0, TOTAL_RIDDLES)
	_glow_progress = clampi(glow_progress, 0, TOTAL_RIDDLES)
	_chest_revealed = chest_revealed
	if _chest_revealed:
		_reveal_chest(message)
	else:
		_sync_riddle_ui(message, is_error)


func _reveal_chest(message: String = "The hut is fully revealed.") -> void:
	_chest_revealed = true
	_final_phase_unlocked = true
	_glow_progress = TOTAL_RIDDLES
	_update_darkness()
	_update_glow_progress_label()
	if is_instance_valid(glow_progress_panel):
		glow_progress_panel.visible = false
	_set_feedback(message, false)
	if is_instance_valid(riddle_layer):
		riddle_layer.visible = false
	_set_final_objects_visible(true)
	if is_instance_valid(progress_sprite):
		progress_sprite.texture = progress_solved_tex if progress_solved_tex else progress_sprite.texture
	show_notification("The room is revealed. Search the hut for a way to open the vessel.", 2.4)


func _set_chest_visible(should_show: bool) -> void:
	if is_instance_valid(chest_object):
		chest_object.visible = should_show
		chest_object.input_pickable = should_show
		chest_object.monitoring = should_show
		chest_object.monitorable = should_show
	if is_instance_valid(chest_sprite):
		chest_sprite.visible = should_show
	if is_instance_valid(_chest_glow_rect):
		_chest_glow_rect.visible = should_show and not _reward_active and not _zone_failed
	if is_instance_valid(chest_collision):
		chest_collision.disabled = not should_show


func _set_final_objects_visible(should_show: bool) -> void:
	_set_chest_visible(should_show)
	_set_area_object_visible(measuring_tool_object, measuring_tool_sprite, measuring_tool_collision, should_show)
	_set_area_object_visible(scratch_paper_object, scratch_paper_sprite, scratch_paper_collision, should_show)


func _set_area_object_visible(area: Area2D, sprite: Sprite2D, collision: CollisionShape2D, should_show: bool) -> void:
	if is_instance_valid(area):
		area.visible = should_show
		area.input_pickable = should_show
		area.monitoring = should_show
		area.monitorable = should_show
	if is_instance_valid(sprite):
		sprite.visible = should_show
	if is_instance_valid(collision):
		collision.disabled = not should_show


func _on_chest_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _final_phase_unlocked or _reward_active or _zone_failed:
		return
	if not _is_click_event(event):
		return
	_open_chest_modal()


func _open_chest_modal() -> void:
	_update_chest_modal_content()
	if is_instance_valid(chest_modal):
		chest_modal.visible = true
	if is_instance_valid(passcode_input):
		passcode_input.text = ""
		passcode_input.grab_focus()
	if is_instance_valid(_passcode_digit_2):
		_passcode_digit_2.text = ""
	if is_instance_valid(chest_feedback_label):
		chest_feedback_label.text = ""
		chest_feedback_label.visible = false


func _update_chest_modal_content() -> void:
	if is_instance_valid(modal_title_label):
		modal_title_label.text = "Enter Passcode"
	if is_instance_valid(modal_instruction_label):
		modal_instruction_label.text = LOCK_HINT_TEXT
		modal_instruction_label.visible = false
	if is_instance_valid(container_preview):
		container_preview.visible = false
	if is_instance_valid(dimension_label):
		dimension_label.visible = false
	if is_instance_valid(passcode_input):
		passcode_input.placeholder_text = ""
		passcode_input.max_length = 1
	if is_instance_valid(submit_passcode_button):
		submit_passcode_button.visible = false
		submit_passcode_button.disabled = true
	if is_instance_valid(hint_button):
		hint_button.text = "i"
	if is_instance_valid(close_chest_button):
		close_chest_button.visible = false
		close_chest_button.disabled = true


func _on_passcode_text_submitted(_text: String) -> void:
	if _get_passcode_text().length() < 2 and is_instance_valid(_passcode_digit_2):
		_passcode_digit_2.grab_focus()
		return
	_on_submit_passcode_pressed()


func _on_passcode_digit_1_changed(_new_text: String) -> void:
	_sanitize_digit_input(passcode_input)
	if is_instance_valid(passcode_input) and not passcode_input.text.is_empty() and is_instance_valid(_passcode_digit_2):
		_passcode_digit_2.grab_focus()
	_try_submit_passcode_digits()


func _on_passcode_digit_2_changed(_new_text: String) -> void:
	_sanitize_digit_input(_passcode_digit_2)
	_try_submit_passcode_digits()


func _sanitize_digit_input(field: LineEdit) -> void:
	if not is_instance_valid(field):
		return
	var clean_digit := ""
	for i in range(field.text.length()):
		var character := field.text.substr(i, 1)
		if character.is_valid_int():
			clean_digit = character
			break
	if field.text != clean_digit:
		field.text = clean_digit
	field.caret_column = field.text.length()


func _try_submit_passcode_digits() -> void:
	var passcode_text := _get_passcode_text()
	if passcode_text.length() == 2 and passcode_text.is_valid_int():
		_on_submit_passcode_pressed()


func _get_passcode_text() -> String:
	var first_digit := ""
	var second_digit := ""
	if is_instance_valid(passcode_input):
		first_digit = passcode_input.text.strip_edges()
	if is_instance_valid(_passcode_digit_2):
		second_digit = _passcode_digit_2.text.strip_edges()
	return first_digit + second_digit


func _on_submit_passcode_pressed() -> void:
	if _is_submitting_chest or _zone_failed or _reward_active:
		return
	var passcode_text := _get_passcode_text()
	if passcode_text.length() != 2 or not passcode_text.is_valid_int():
		_set_chest_feedback("Enter the two-digit code.", true)
		return

	_is_submitting_chest = true
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_validate_chest_passcode(int(passcode_text))
	else:
		rpc_submit_chest_passcode.rpc_id(SERVER_PEER_ID, int(passcode_text))
	await get_tree().create_timer(0.2).timeout
	_is_submitting_chest = false


@rpc("any_peer", "reliable")
func rpc_submit_chest_passcode(passcode: int) -> void:
	if multiplayer.is_server():
		_validate_chest_passcode(passcode)


func _validate_chest_passcode(passcode: int) -> void:
	if not _has_all_measurements():
		_set_chest_feedback("The seal stays cold. Something is still missing.", true)
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			var sender_id := multiplayer.get_remote_sender_id()
			if sender_id > 0:
				rpc_sync_chest_feedback.rpc_id(sender_id, "The seal stays cold. Something is still missing.", true)
		return
	var lock: Dictionary = CHEST_LOCKS[_chest_lock_index]
	var correct := int(lock.get("answer", 60))
	if passcode == correct:
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			rpc_chest_unlocked.rpc()
		else:
			rpc_chest_unlocked()
	else:
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			rpc_eject_from_hut.rpc()
		else:
			rpc_eject_from_hut()


@rpc("authority", "reliable", "call_local")
func rpc_chest_unlocked() -> void:
	if _reward_active:
		return
	if is_instance_valid(chest_modal):
		chest_modal.visible = false
	if is_instance_valid(measurement_modal):
		measurement_modal.visible = false
	if is_instance_valid(_measurement_backdrop):
		_measurement_backdrop.visible = false
	if is_instance_valid(scratch_paper_modal):
		scratch_paper_modal.visible = false
	_play_zone_completion_sfx()
	_show_reward()


@rpc("authority", "reliable", "call_local")
func rpc_eject_from_hut() -> void:
	if _zone_failed:
		return
	_zone_failed = true
	if is_instance_valid(chest_modal):
		chest_modal.visible = false
	if is_instance_valid(measurement_modal):
		measurement_modal.visible = false
	if is_instance_valid(_measurement_backdrop):
		_measurement_backdrop.visible = false
	if is_instance_valid(scratch_paper_modal):
		scratch_paper_modal.visible = false
	_show_aswang_warning()
	show_notification("Wrong passcode. Something watches from the rafters.", 1.5)
	await get_tree().create_timer(1.5).timeout
	_return_to_forest()


func _on_close_chest_pressed() -> void:
	if is_instance_valid(chest_modal):
		chest_modal.visible = false


func _on_hint_pressed() -> void:
	_set_chest_feedback(LOCK_HINT_TEXT, false)


@rpc("authority", "reliable", "call_local")
func rpc_sync_chest_feedback(message: String, is_error: bool) -> void:
	_set_chest_feedback(message, is_error)


func _on_measuring_tool_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _final_phase_unlocked or _reward_active or _zone_failed:
		return
	if not _is_click_event(event):
		return
	_open_measurement_modal()


func _open_measurement_modal() -> void:
	_measurement_intro_active = not _has_all_measurements()
	_update_measurement_modal_content()
	if is_instance_valid(_measurement_backdrop):
		_measurement_backdrop.visible = true
	if is_instance_valid(measurement_modal):
		measurement_modal.visible = true
	if not _measurement_intro_active and is_instance_valid(measurement_answer_input) and measurement_answer_input.editable:
		measurement_answer_input.grab_focus()


func _show_measurement_form_synced() -> void:
	if _zone_failed or _reward_active or not _final_phase_unlocked:
		return
	_measurement_intro_active = false
	if is_instance_valid(_measurement_backdrop):
		_measurement_backdrop.visible = true
	if is_instance_valid(measurement_modal):
		measurement_modal.visible = true
	_update_measurement_modal_content()
	if is_instance_valid(measurement_answer_input) and measurement_answer_input.editable:
		measurement_answer_input.grab_focus()


@rpc("any_peer", "reliable")
func rpc_request_measurement_form() -> void:
	if not multiplayer.is_server() or _zone_failed or _reward_active or not _final_phase_unlocked:
		return
	rpc_open_measurement_form.rpc()


@rpc("authority", "reliable", "call_local")
func rpc_open_measurement_form() -> void:
	_show_measurement_form_synced()


func _update_measurement_modal_content(feedback_text: String = "", is_error: bool = false) -> void:
	var all_done := _has_all_measurements()
	var step: Dictionary = {}
	if not all_done:
		step = MEASUREMENT_STEPS[_current_measurement_index]
	var answer_role := str(step.get("answerer", ROLE_DETECTIVE))
	var can_answer := (not all_done) and (_is_local_role(answer_role) or _is_single_player_test())

	if _measurement_intro_active and not all_done:
		_update_measurement_intro_content()
		return

	if is_instance_valid(measurement_title_label):
		measurement_title_label.text = "Measurement Record" if all_done else "Measure the Vessel"
	if is_instance_valid(measurement_instruction_label):
		if all_done:
			measurement_instruction_label.text = ""
			measurement_instruction_label.visible = false
		elif can_answer:
			measurement_instruction_label.visible = true
			measurement_instruction_label.text = "Read the tape and record the vessel's measurement."
			_place_label(measurement_instruction_label, Vector2(58, 92), Vector2(524, 36), 15, UI_CREAM)
		else:
			measurement_instruction_label.visible = true
			measurement_instruction_label.text = "%s must read this tape mark." % _role_display(answer_role)
			_place_label(measurement_instruction_label, Vector2(58, 92), Vector2(524, 36), 15, UI_CREAM)
	if is_instance_valid(measurement_image):
		var measurement_texture: Texture2D = RECTANGULAR_CONTAINER_TEX
		if not all_done:
			measurement_texture = step.get("texture") as Texture2D
		measurement_image.texture = measurement_texture
		measurement_image.visible = measurement_image.texture != null
		measurement_image.position = Vector2(330, 208) if all_done else Vector2(330, 245)
		measurement_image.scale = Vector2(0.32, 0.32) if all_done else Vector2(0.42, 0.42)
	if is_instance_valid(measurement_answer_input):
		measurement_answer_input.visible = not all_done
		measurement_answer_input.editable = can_answer
		measurement_answer_input.placeholder_text = "Measurement"
		measurement_answer_input.text = ""
	if is_instance_valid(confirm_measurement_button):
		confirm_measurement_button.visible = not all_done
		confirm_measurement_button.disabled = not can_answer
		confirm_measurement_button.text = "Record"
		confirm_measurement_button.position = Vector2(174, 438)
		confirm_measurement_button.size = Vector2(132, 52)
		_apply_button_style(confirm_measurement_button)
	if is_instance_valid(_measurement_clear_button):
		_measurement_clear_button.visible = not all_done
		_measurement_clear_button.disabled = not can_answer
		_measurement_clear_button.position = Vector2(334, 438)
		_measurement_clear_button.size = Vector2(132, 52)
		_measurement_clear_button.text = "Clear"
		_apply_button_style(_measurement_clear_button)
	if is_instance_valid(measurement_feedback_label):
		if all_done:
			measurement_feedback_label.text = "Width =\n\nLength =\n\nHeight ="
			measurement_feedback_label.add_theme_color_override("font_color", UI_CREAM)
			_place_label(measurement_feedback_label, Vector2(154, 322), Vector2(172, 132), 18, UI_CREAM)
			measurement_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		elif feedback_text.is_empty() and not can_answer:
			measurement_feedback_label.text = "Wait for your partner's measurement."
			measurement_feedback_label.add_theme_color_override("font_color", UI_INFO)
			_place_label(measurement_feedback_label, Vector2(68, 496), Vector2(504, 28), 14, UI_INFO)
			measurement_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			measurement_feedback_label.text = feedback_text
			measurement_feedback_label.add_theme_color_override("font_color", UI_ERROR if is_error else UI_INFO)
			_place_label(measurement_feedback_label, Vector2(68, 496), Vector2(504, 28), 14, UI_ERROR if is_error else UI_SUCCESS)
			measurement_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_instance_valid(measurement_summary_label):
		measurement_summary_label.visible = true
		if all_done:
			measurement_summary_label.text = "The measurements are complete. Find the vessel's volume to break the seal."
			_place_label(measurement_summary_label, Vector2(64, 488), Vector2(512, 30), 11, UI_INFO)
			measurement_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			measurement_summary_label.remove_theme_stylebox_override("normal")
			_show_measurement_values()
		else:
			measurement_summary_label.text = str(step.get("label", "Measurement"))
			_place_label(measurement_summary_label, Vector2(170, 328), Vector2(300, 36), 18, UI_INFO)
			measurement_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			measurement_summary_label.remove_theme_stylebox_override("normal")
			_hide_measurement_values()


func _update_measurement_intro_content() -> void:
	if is_instance_valid(measurement_title_label):
		measurement_title_label.text = "Measuring Tape"
	if is_instance_valid(measurement_instruction_label):
		measurement_instruction_label.text = ""
	if is_instance_valid(measurement_image):
		measurement_image.texture = TAPE_MEASURE_TEX
		measurement_image.visible = true
		measurement_image.position = Vector2(320, 242)
		measurement_image.scale = Vector2(0.56, 0.56)
	if is_instance_valid(measurement_answer_input):
		measurement_answer_input.visible = false
	if is_instance_valid(confirm_measurement_button):
		confirm_measurement_button.visible = true
		confirm_measurement_button.disabled = false
		confirm_measurement_button.text = "Use Now"
		confirm_measurement_button.position = Vector2(220, 420)
		confirm_measurement_button.size = Vector2(200, 64)
		_apply_button_style(confirm_measurement_button)
		confirm_measurement_button.add_theme_font_size_override("font_size", 24)
	if is_instance_valid(_measurement_clear_button):
		_measurement_clear_button.visible = false
	if is_instance_valid(measurement_feedback_label):
		measurement_feedback_label.text = ""
	if is_instance_valid(measurement_summary_label):
		measurement_summary_label.visible = false
	_hide_measurement_values()


func _on_measurement_text_submitted(_text: String) -> void:
	_on_confirm_measurement_pressed()


func _on_confirm_measurement_pressed() -> void:
	if _is_submitting_measurement or _zone_failed or _reward_active:
		return
	if _measurement_intro_active:
		if multiplayer.has_multiplayer_peer():
			if multiplayer.is_server():
				rpc_open_measurement_form.rpc()
			else:
				rpc_request_measurement_form.rpc_id(SERVER_PEER_ID)
		else:
			_show_measurement_form_synced()
		return
	if _has_all_measurements():
		return
	var step: Dictionary = MEASUREMENT_STEPS[_current_measurement_index]
	var answer_role := str(step.get("answerer", ROLE_DETECTIVE))
	if not (_is_local_role(answer_role) or _is_single_player_test()):
		_update_measurement_modal_content("It is your partner's turn to read this tape mark.", true)
		return
	if not is_instance_valid(measurement_answer_input):
		return

	var answer_text := measurement_answer_input.text.strip_edges()
	if answer_text.is_empty() or not answer_text.is_valid_int():
		_update_measurement_modal_content("Enter a whole number from the tape.", true)
		return

	_is_submitting_measurement = true
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_validate_measurement_answer(int(answer_text))
	else:
		rpc_submit_measurement_answer.rpc_id(SERVER_PEER_ID, int(answer_text), _current_measurement_index)
	await get_tree().create_timer(0.18).timeout
	_is_submitting_measurement = false


@rpc("any_peer", "reliable")
func rpc_submit_measurement_answer(answer: int, measurement_index: int) -> void:
	if not multiplayer.is_server() or _zone_failed:
		return
	if measurement_index != _current_measurement_index:
		rpc_sync_measurement_state.rpc_id(multiplayer.get_remote_sender_id(), _current_measurement_index, _recorded_measurements, "The tape has already moved. Try the current mark.", true)
		return
	if _has_all_measurements():
		rpc_sync_measurement_state.rpc_id(multiplayer.get_remote_sender_id(), _current_measurement_index, _recorded_measurements, "", false)
		return
	var step: Dictionary = MEASUREMENT_STEPS[_current_measurement_index]
	var answer_role := str(step.get("answerer", ROLE_DETECTIVE))
	if answer_role != ROLE_SIDEKICK:
		rpc_sync_measurement_state.rpc_id(multiplayer.get_remote_sender_id(), _current_measurement_index, _recorded_measurements, "It is your partner's turn to read this tape mark.", true)
		return
	_validate_measurement_answer(answer)


func _validate_measurement_answer(answer: int) -> void:
	if _has_all_measurements():
		return
	var step: Dictionary = MEASUREMENT_STEPS[_current_measurement_index]
	var correct := int(step.get("answer", 0))
	if answer == correct:
		_recorded_measurements[str(step.get("key", ""))] = correct
		_current_measurement_index = min(_current_measurement_index + 1, MEASUREMENT_STEPS.size())
		var message := "%s recorded." % str(step.get("label", "Measurement"))
		if _has_all_measurements():
			message = "Measurements recorded:\nWidth = 4\nLength = 5\nHeight = 3"
		_sync_measurement_state(message, false)
	else:
		_sync_measurement_state("The tape mark does not match. Try again.", true)


func _sync_measurement_state(message: String, is_error: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		rpc_sync_measurement_state.rpc(_current_measurement_index, _recorded_measurements, message, is_error)
	else:
		rpc_sync_measurement_state(_current_measurement_index, _recorded_measurements, message, is_error)


@rpc("authority", "reliable", "call_local")
func rpc_sync_measurement_state(measurement_index: int, recorded_measurements: Dictionary, message: String, is_error: bool) -> void:
	_current_measurement_index = clampi(measurement_index, 0, MEASUREMENT_STEPS.size())
	_recorded_measurements = recorded_measurements.duplicate(true)
	if is_instance_valid(measurement_modal) and measurement_modal.visible:
		_update_measurement_modal_content(message, is_error)
	if is_instance_valid(chest_modal) and chest_modal.visible:
		_update_chest_modal_content()


func _on_close_measurement_pressed() -> void:
	if is_instance_valid(measurement_modal):
		measurement_modal.visible = false
	if is_instance_valid(_measurement_backdrop):
		_measurement_backdrop.visible = false
	_measurement_intro_active = false


func _on_clear_measurement_pressed() -> void:
	if is_instance_valid(measurement_answer_input):
		measurement_answer_input.text = ""
		measurement_answer_input.grab_focus()
	if is_instance_valid(measurement_feedback_label):
		measurement_feedback_label.text = ""


func _on_scratch_paper_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _final_phase_unlocked or _reward_active or _zone_failed:
		return
	if not _is_click_event(event):
		return
	_open_scratch_paper_modal()


func _open_scratch_paper_modal() -> void:
	_scratch_paper_seen = true
	_on_rectangular_paper_pressed()
	if is_instance_valid(scratch_paper_modal):
		scratch_paper_modal.visible = true


func _on_rectangular_paper_pressed() -> void:
	if is_instance_valid(scratch_paper_title_label):
		scratch_paper_title_label.text = "Crumpled Scratch Paper"
	if is_instance_valid(scratch_paper_image):
		scratch_paper_image.texture = RECTANGULAR_PAPER_TEX
		scratch_paper_image.visible = true
	if is_instance_valid(scratch_paper_feedback_label):
		scratch_paper_feedback_label.text = "The crumpled paper shows how to find a container's capacity."
		scratch_paper_feedback_label.add_theme_color_override("font_color", UI_INFO)


func _on_cylinder_paper_pressed() -> void:
	if is_instance_valid(scratch_paper_feedback_label):
		scratch_paper_feedback_label.text = "Only the rectangular vessel matters in this hut."
		scratch_paper_feedback_label.add_theme_color_override("font_color", UI_INFO)


func _on_close_scratch_paper_pressed() -> void:
	if is_instance_valid(scratch_paper_modal):
		scratch_paper_modal.visible = false


func _has_all_measurements() -> bool:
	for step in MEASUREMENT_STEPS:
		if not _recorded_measurements.has(str(step.get("key", ""))):
			return false
	return true


func _measurement_summary_text() -> String:
	if _has_all_measurements():
		return "Width  = 4\nLength = 5\nHeight = 3"
	var lines: Array[String] = []
	for step in MEASUREMENT_STEPS:
		var key := str(step.get("key", ""))
		if _recorded_measurements.has(key):
			lines.append("%s = %d" % [str(step.get("label", "Measurement")), int(_recorded_measurements[key])])
	if lines.is_empty():
		return "No measurements recorded yet."
	return "Recorded:\n%s" % "\n".join(lines)


func _show_reward() -> void:
	_reward_active = true
	_waiting_reward_continue = true
	_reward_stage = 1
	_collect_sequence_started = false

	if is_instance_valid(reward_layer):
		reward_layer.visible = true
	if is_instance_valid(reward_dark_overlay):
		reward_dark_overlay.modulate.a = 0.45
	if is_instance_valid(clue_sprite):
		clue_sprite.visible = true
		clue_sprite.modulate.a = 1.0
	if is_instance_valid(sparkle):
		sparkle.visible = true
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
		_animation_time = 0.0
		_sparkle_animating = true
	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = true
		reward_banner_label.text = "ARTIFACT FOUND!"
	if is_instance_valid(reward_panel):
		reward_panel.visible = false
	if is_instance_valid(reward_text_label):
		reward_text_label.text = ""
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = true
		tap_instruction_label.text = "Tap anywhere to continue."
	if is_instance_valid(tap_catcher):
		tap_catcher.visible = true
		tap_catcher.disabled = false
	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.disabled = true
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null


func _on_reward_tap_catcher_pressed() -> void:
	if not _waiting_reward_continue:
		return
	match _reward_stage:
		1:
			_reward_stage = 2
			_show_reward_stage_text("You found the Wish Scroll.")
		2:
			_reward_stage = 3
			_show_reward_stage_text("The scroll carries a mother's old wish.")
		3:
			_reward_stage = 4
			_show_reward_stage_text("\"I wished you had many eyes, so you could find what you seek...\"")
		4:
			_reward_stage = 5
			_waiting_reward_continue = false
			if is_instance_valid(tap_instruction_label):
				tap_instruction_label.visible = false
				tap_instruction_label.text = ""
			if is_instance_valid(tap_catcher):
				tap_catcher.visible = false
				tap_catcher.disabled = true
			if is_instance_valid(reward_panel):
				reward_panel.visible = false
			if is_instance_valid(reward_text_label):
				reward_text_label.text = ""
			if is_instance_valid(collect_button):
				var can_collect := GameState.local_role == GameState.Role.SIDEKICK or not multiplayer.has_multiplayer_peer()
				collect_button.visible = can_collect
				collect_button.disabled = not can_collect


func _show_reward_stage_text(text: String) -> void:
	if is_instance_valid(reward_panel):
		reward_panel.visible = true
	if is_instance_valid(reward_text_label):
		reward_text_label.text = text
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = true
		tap_instruction_label.text = "Tap anywhere to continue."


func _on_collect_pressed() -> void:
	if _collect_sequence_started:
		return
	_collect_sequence_started = true
	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.disabled = true
	if not multiplayer.has_multiplayer_peer():
		rpc_show_briefcase_reveal_then_finalize()
	elif multiplayer.is_server():
		rpc_show_briefcase_reveal_then_finalize.rpc()
	else:
		rpc_request_collect_clue.rpc_id(SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_collect_clue() -> void:
	if multiplayer.is_server():
		rpc_show_briefcase_reveal_then_finalize.rpc()


@rpc("authority", "reliable", "call_local")
func rpc_show_briefcase_reveal_then_finalize() -> void:
	_hide_reward_visuals_for_briefcase()
	if is_instance_valid(briefcase_reveal_sprite):
		var reveal_texture: Texture2D = GameState.get_briefcase_texture("storage_hut_reveal")
		briefcase_reveal_sprite.texture = reveal_texture
		briefcase_reveal_sprite.visible = reveal_texture != null
	await get_tree().create_timer(1.5).timeout
	if not multiplayer.has_multiplayer_peer():
		rpc_finalize_clue()
	elif multiplayer.is_server():
		rpc_finalize_clue.rpc()


@rpc("authority", "reliable", "call_local")
func rpc_finalize_clue() -> void:
	GameState.collect_clue(ZONE_ID)
	_clue_collected = true
	_sparkle_animating = false
	if is_instance_valid(sparkle):
		sparkle.visible = false
	if is_instance_valid(clue_sprite):
		clue_sprite.visible = false
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null
	if is_instance_valid(reward_layer):
		reward_layer.visible = false
	if is_instance_valid(reward_dark_overlay):
		reward_dark_overlay.modulate.a = 0.0
	await _fade_out(0.6)
	await get_tree().create_timer(0.2).timeout
	await _fade_in(0.6)
	_return_to_forest()


func _hide_reward_visuals_for_briefcase() -> void:
	_sparkle_animating = false
	for node in [sparkle, clue_sprite, reward_banner_label, reward_panel, tap_instruction_label, tap_catcher, collect_button]:
		if is_instance_valid(node):
			node.visible = false
	if is_instance_valid(reward_text_label):
		reward_text_label.text = ""
	if is_instance_valid(tap_catcher):
		tap_catcher.disabled = true


func _populate_ledger() -> void:
	for label in [ledger_title, ledger_body, ledger_left_header, ledger_left_body, ledger_right_header, ledger_right_body]:
		if is_instance_valid(label):
			label.visible = false
	_show_ledger_instruction_image(LEDGER_IMAGE_PATH)


func _show_ledger_instruction_image(path: String) -> void:
	if not is_instance_valid(ledger_panel):
		return
	ledger_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var holder: Control = get_node_or_null("SidekickLayer/Ledger/Control") as Control
	if not is_instance_valid(holder):
		holder = ledger_panel
	if not is_instance_valid(_ledger_instruction_image):
		_ledger_instruction_image = holder.get_node_or_null("LedgerInstructionImage") as TextureRect
	if not is_instance_valid(_ledger_instruction_image):
		_ledger_instruction_image = TextureRect.new()
		_ledger_instruction_image.name = "LedgerInstructionImage"
		_ledger_instruction_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(_ledger_instruction_image)
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_warning("Ledger instruction image missing: " + path)
		return
	var image_size := holder.size
	if image_size == Vector2.ZERO:
		image_size = ledger_panel.size
	if image_size == Vector2.ZERO:
		image_size = Vector2(900.0, 540.0)
	_ledger_instruction_image.texture = texture
	_ledger_instruction_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_ledger_instruction_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ledger_instruction_image.position = Vector2.ZERO
	_ledger_instruction_image.size = image_size
	_ledger_instruction_image.custom_minimum_size = image_size
	_ledger_instruction_image.visible = true
	_ledger_instruction_image.move_to_front()

func _refresh_inside_zone_buttons() -> void:
	var is_sidekick := GameState.local_role == GameState.Role.SIDEKICK
	if is_instance_valid(inside_zone_control):
		if inside_zone_control.has_method("set_pause_enabled"):
			inside_zone_control.set_pause_enabled(true)
		if inside_zone_control.has_method("set_ledger_enabled"):
			inside_zone_control.set_ledger_enabled(is_sidekick)
		if inside_zone_control.has_method("set_briefcase_enabled"):
			inside_zone_control.set_briefcase_enabled(is_sidekick)
		if inside_zone_control.has_method("set_sidekick_ui_visible"):
			inside_zone_control.set_sidekick_ui_visible(is_sidekick)
	if not is_sidekick:
		if is_instance_valid(ledger_panel):
			ledger_panel.visible = false
		if is_instance_valid(briefcase_panel):
			briefcase_panel.visible = false


func _on_ledger_pressed() -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		return
	if is_instance_valid(ledger_panel):
		ledger_panel.visible = not ledger_panel.visible


func _on_briefcase_pressed() -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		return
	_refresh_briefcase()
	if is_instance_valid(briefcase_panel):
		briefcase_panel.visible = not briefcase_panel.visible


func _refresh_briefcase() -> void:
	if not is_instance_valid(briefcase_display):
		return
	var tex: Texture2D = GameState.get_briefcase_texture("forest")
	briefcase_display.texture = tex
	briefcase_display.visible = tex != null


func _update_darkness() -> void:
	var alpha := float(DARKNESS_LEVELS[clampi(_glow_progress, 0, DARKNESS_LEVELS.size() - 1)])
	if is_instance_valid(dark_overlay):
		dark_overlay.visible = alpha > 0.0
		dark_overlay.color = Color(0.0, 0.0, 0.0, alpha)
	if is_instance_valid(lantern_glow):
		lantern_glow.visible = _glow_progress > 0 and _glow_progress < TOTAL_RIDDLES
		lantern_glow.color = Color(1.0, 0.78, 0.35, 0.04 + float(_glow_progress) * 0.035)


func _update_glow_progress_label() -> void:
	if is_instance_valid(glow_counter_label):
		glow_counter_label.text = "Hut Glow: %d / %d" % [_glow_progress, TOTAL_RIDDLES]


func _set_feedback(text: String, is_error: bool) -> void:
	if not is_instance_valid(feedback_label):
		return
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", UI_ERROR if is_error else UI_SUCCESS)


func _set_chest_feedback(text: String, is_error: bool) -> void:
	if not is_instance_valid(chest_feedback_label):
		return
	chest_feedback_label.text = text
	chest_feedback_label.visible = not text.is_empty()
	chest_feedback_label.add_theme_color_override("font_color", UI_ERROR if is_error else UI_INFO)


func show_notification(text: String, duration: float = 2.0) -> void:
	if not is_instance_valid(notification_panel) or not is_instance_valid(notification_label):
		return
	if is_instance_valid(notification_ui):
		notification_ui.visible = true
	notification_label.text = text
	notification_panel.visible = true
	notification_panel.modulate.a = 1.0
	var current_id := Time.get_ticks_msec()
	notification_panel.set_meta("msg_id", current_id)
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration, true).timeout
	if is_instance_valid(notification_panel) and notification_panel.get_meta("msg_id", -1) == current_id:
		notification_panel.visible = false


func _show_aswang_warning() -> void:
	if not is_instance_valid(_aswang_overlay):
		_aswang_overlay = ColorRect.new()
		_aswang_overlay.name = "AswangWarningOverlay"
		_aswang_overlay.color = Color(0.2, 0.0, 0.0, 0.0)
		_aswang_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aswang_overlay.z_index = 3000
		_aswang_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_aswang_overlay)
	var tween := create_tween()
	tween.tween_property(_aswang_overlay, "color:a", 0.58, 0.18)
	tween.tween_property(_aswang_overlay, "color:a", 0.15, 0.18)
	tween.tween_property(_aswang_overlay, "color:a", 0.65, 0.18)


func _on_pause_pressed() -> void:
	if is_instance_valid(pause_canvas_layer):
		pause_canvas_layer.visible = true
	if is_instance_valid(pause_panel):
		pause_panel.visible = true
	if is_instance_valid(option_panel):
		option_panel.visible = false
	if is_instance_valid(inside_zone_control):
		inside_zone_control.visible = false
	MusicController.pause_music()
	get_tree().paused = true


func _on_resume_pressed() -> void:
	if is_instance_valid(pause_panel):
		pause_panel.visible = false
	if is_instance_valid(option_panel):
		option_panel.visible = false
	get_tree().paused = false
	MusicController.resume_music()
	if is_instance_valid(inside_zone_control):
		inside_zone_control.visible = true


func _on_option_pressed() -> void:
	if is_instance_valid(option_panel):
		option_panel.visible = true
	if is_instance_valid(volume_slider):
		volume_slider.value = MusicController.get_volume() * 100.0
	if is_instance_valid(volume_value_label):
		volume_value_label.text = str(int(volume_slider.value)) + "%"


func _on_option_back_pressed() -> void:
	if is_instance_valid(option_panel):
		option_panel.visible = false


func _on_exit_pressed() -> void:
	if is_instance_valid(pause_canvas_layer):
		pause_canvas_layer.visible = false
	get_tree().paused = false
	MusicController.resume_music()
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _on_volume_changed(value: float) -> void:
	MusicController.set_volume(value / 100.0)
	if is_instance_valid(volume_value_label):
		volume_value_label.text = str(int(value)) + "%"


func _on_back_pressed() -> void:
	_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	MusicController.resume_music()
	if is_inside_tree():
		GameState.change_to_post_zone_scene(get_tree())


func _on_clue_collected(zone_id: String, _clue_data: Dictionary) -> void:
	if zone_id == ZONE_ID:
		_clue_collected = true


func _play_zone_completion_sfx() -> void:
	if not is_instance_valid(_sfx_player) or not COMPLETION_SFX:
		return
	_sfx_player.stream = COMPLETION_SFX
	_sfx_player.play()


func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		var last_bus := AudioServer.bus_count - 1
		AudioServer.set_bus_name(last_bus, "SFX")
		AudioServer.set_bus_volume_db(last_bus, 0.0)


func _is_click_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func _is_single_player_test() -> bool:
	return not multiplayer.has_multiplayer_peer() or GameState.local_role == GameState.Role.NONE


func _is_local_role(role: String) -> bool:
	match role:
		ROLE_DETECTIVE:
			return GameState.local_role == GameState.Role.DETECTIVE
		ROLE_SIDEKICK:
			return GameState.local_role == GameState.Role.SIDEKICK
	return false


func _role_display(role: String) -> String:
	match role:
		ROLE_DETECTIVE:
			return "Detective"
		ROLE_SIDEKICK:
			return "Sidekick"
	return "Partner"


func _first_valid_node(paths: Array[String]) -> Node:
	for node_path in paths:
		var node := get_node_or_null(node_path)
		if is_instance_valid(node):
			return node
	return null


func _place_label(label: Label, pos: Vector2, size: Vector2, font_size: int, color: Color) -> void:
	label.position = pos
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", OCRA_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))


func _apply_panel_style(panel: Panel, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UI_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)


func _apply_button_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = UI_PRIMARY
	normal.border_color = UI_BORDER
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = UI_PRIMARY_HOVER
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = UI_PRIMARY_PRESSED
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = UI_DISABLED
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_override("font", OCRA_FONT)
	button.add_theme_color_override("font_color", UI_CREAM)
	button.add_theme_color_override("font_disabled_color", Color(0.78, 0.72, 0.66, 1.0))
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE


func _apply_hint_button_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = UI_PRIMARY
	normal.border_color = UI_BORDER
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(29)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = UI_PRIMARY_HOVER
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = UI_PRIMARY_PRESSED
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_font_override("font", OCRA_FONT)
	button.add_theme_color_override("font_color", UI_CREAM)
	button.add_theme_font_size_override("font_size", 26)
	button.focus_mode = Control.FOCUS_NONE


func _apply_measurement_value_style(label: Label) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.78, 0.54, 0.23, 0.96)
	normal.border_color = Color(0.96, 0.72, 0.38, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(20)
	label.add_theme_stylebox_override("normal", normal)


func _apply_line_edit_style(line_edit: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.95, 0.86, 0.66, 0.94)
	normal.border_color = UI_BORDER
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(1.0, 0.91, 0.70, 1.0)
	focus.border_color = Color(1.0, 0.92, 0.58, 1.0)
	line_edit.add_theme_stylebox_override("normal", normal)
	line_edit.add_theme_stylebox_override("focus", focus)
	line_edit.add_theme_color_override("font_color", UI_INK)
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.38, 0.25, 0.14, 0.82))
	line_edit.add_theme_color_override("caret_color", UI_INK)
	line_edit.add_theme_color_override("selection_color", Color(0.54, 0.35, 0.16, 0.35))


func _apply_ocra_font_tree(root: Node) -> void:
	if root is Control:
		var control := root as Control
		control.add_theme_font_override("font", OCRA_FONT)
	for child in root.get_children():
		_apply_ocra_font_tree(child)


func _fade_out(duration: float = 0.6) -> void:
	var overlay := ColorRect.new()
	overlay.name = "FadeOverlay"
	overlay.color = Color(0, 0, 0, 0)
	overlay.z_index = 4096
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "color:a", 1.0, duration)
	await tween.finished


func _fade_in(duration: float = 0.6) -> void:
	var overlay := get_node_or_null("FadeOverlay") as ColorRect
	if not is_instance_valid(overlay):
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "color:a", 0.0, duration)
	await tween.finished
	overlay.queue_free()
