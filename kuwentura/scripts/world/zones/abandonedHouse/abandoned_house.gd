extends Node2D

const FOREST_HUB_SCENE_PATH := "res://scenes/world/hub/ForestHub.tscn"
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"

const ZONE_ID := "abandoned_house"
const SUB_PUZZLE_ID := "abandoned_house_books"

const BOOK_ORDER_TOP_TO_BOTTOM := ["book_4", "book_3", "book_2", "book_1"]
const BOOK_START_ORDER := ["book_2", "book_4", "book_1", "book_3"]
const REWARD_ITEMS := ["key_fragment_1", "card_piece"]

const MEMORY_PUZZLE_ID := "abandoned_house_memory"
const MEMORY_FACE_IDS := ["face_1", "face_2", "face_3", "face_4", "face_5", "face_6"]
const MEMORY_REWARD_ITEMS := ["key_fragment_2", "light_bulb"]
const DRAWER_REWARD_ITEMS := ["key_fragment_3"]

# Keeps the puzzle more responsive on different screen sizes.
const BOOK_WIDTH_RATIOS := {
	"book_1": 0.58,
	"book_2": 0.51,
	"book_3": 0.44,
	"book_4": 0.37
}

const BOOK_STACK_GAP := 6.0

const BOOK_CROP_REGIONS := {
	"book_1": Rect2(101, 801, 1719, 172),
	"book_2": Rect2(174, 635, 1599, 215),
	"book_3": Rect2(241, 492, 1466, 145),
	"book_4": Rect2(322, 312, 1304, 182)
}

@export var key_fragment_2_texture: Texture2D
@export var lighter_texture: Texture2D

@export var book_1_texture: Texture2D
@export var book_2_texture: Texture2D
@export var book_3_texture: Texture2D
@export var book_4_texture: Texture2D

@export var memory_card_back_texture: Texture2D
@export var memory_card_1_texture: Texture2D
@export var memory_card_2_texture: Texture2D
@export var memory_card_3_texture: Texture2D
@export var memory_card_4_texture: Texture2D
@export var memory_card_5_texture: Texture2D
@export var memory_card_6_texture: Texture2D

@export var key_fragment_1_texture: Texture2D
@export var card_piece_texture: Texture2D

@export var key_fragment_3_texture: Texture2D

@export var mirror_not_lighted_texture: Texture2D
@export var mirror_lighted_with_fp_texture: Texture2D
@export var mirror_lighted_no_fp_texture: Texture2D
@export var lighted_room_texture: Texture2D

const DRAWER_PUZZLE_ID := "abandoned_house_drawer_unlocked"
const DRAWER_CORRECT_CODE := [3, 5, 4]

@export var drawer_closed_texture: Texture2D
@export var drawer_open_texture: Texture2D
@export var drawer_lock_zoom_texture: Texture2D
@export var lock_digit_textures: Array[Texture2D] = []

@export var cabinet_closed_texture: Texture2D
@export var cabinet_opened_texture: Texture2D

@onready var cabinet_area: Area2D = $InteractiveLayer/CabinetArea

@onready var cabinet_puzzle_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/CabinetPuzzlePanel
@onready var cabinet_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/CabinetPuzzlePanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var cabinet_texture_rect: TextureRect = $PuzzleCanvasLayer/Dimmer/CabinetPuzzlePanel/MarginContainer/VBoxContainer/CabinetHolder/CabinetTexture
@onready var cabinet_lock_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/CabinetPuzzlePanel/MarginContainer/VBoxContainer/CabinetHolder/CabinetLockHotspot
@onready var close_cabinet_button: Button = $PuzzleCanvasLayer/Dimmer/CabinetPuzzlePanel/MarginContainer/VBoxContainer/BottomBar/CloseCabinetButton

@onready var drawer_area: Area2D = $InteractiveLayer/DrawerArea

@onready var key_fragment_image: TextureRect = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/DrawerHolder/KeyFragmentImage
@onready var key_fragment_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/DrawerHolder/KeyFragmentHotspot

@onready var drawer_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/DrawerPanel
@onready var drawer_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var drawer_texture_rect: TextureRect = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/DrawerHolder/DrawerTexture
@onready var drawer_lock_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/DrawerHolder/DrawerLockHotspot
@onready var close_drawer_button: Button = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/BottomBar/CloseDrawerButton

@onready var drawer_lock_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel
@onready var drawer_lock_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var drawer_lock_texture_rect: TextureRect = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/LockHolder/DrawerLockTexture
@onready var digit_1_button: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/LockHolder/Digit1
@onready var digit_2_button: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/LockHolder/Digit2
@onready var digit_3_button: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/LockHolder/Digit3
@onready var close_drawer_lock_button: Button = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/BottomBar/CloseDrawerLockButton

var _drawer_unlocked: bool = false
var _drawer_digits: Array[int] = [0, 0, 0]

var _final_box_variation_index: int = -1
var _final_box_data: Dictionary = {}

@onready var mirror_area: Area2D = $InteractiveLayer/MirrorArea
@onready var bedroom_background: Sprite2D = $BackgroundLayer/BedroomBackground

@onready var mirror_puzzle_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel
@onready var mirror_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var mirror_texture_rect: TextureRect = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel/MarginContainer/VBoxContainer/MirrorHolder/MirrorTexture
@onready var lamp_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel/MarginContainer/VBoxContainer/MirrorHolder/LampHotspot
@onready var close_mirror_button: Button = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel/MarginContainer/VBoxContainer/BottomBar/CloseMirrorButton

@onready var inside_zone_control = $InsideZoneControl

@onready var puzzle_area: Area2D = $InteractiveLayer/PuzzleArea

@onready var memory_puzzle_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel
@onready var memory_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var missing_card_preview: TextureRect = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/MissingRow/MissingCardPreview
@onready var memory_grid: GridContainer = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/MemoryGrid
@onready var close_memory_button: Button = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/CloseMemoryButton
@onready var missing_row: HBoxContainer = get_node_or_null("PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/MissingRow")

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton
@onready var notification_label: Label = $NotificationLabel

@onready var books_area: Area2D = $InteractiveLayer/BooksArea

@onready var dimmer: ColorRect = $PuzzleCanvasLayer/Dimmer
@onready var books_puzzle_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel
@onready var instruction_label: Label = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var puzzle_board: Control = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel/MarginContainer/VBoxContainer/PuzzleBoard
@onready var close_puzzle_button: Button = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel/MarginContainer/VBoxContainer/ClosePuzzleButton

@onready var reward_dimmer: ColorRect = $RewardCanvasLayer/RewardDimmer
@onready var reward_panel: PanelContainer = $RewardCanvasLayer/RewardPanel
@onready var reward_title_label: Label = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardTitleLabel
@onready var reward_body_label: Label = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardBodyLabel
@onready var collect_reward_button: Button = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/CollectClueButton

@onready var reward_vbox: VBoxContainer = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer
@onready var reward_items_row: HBoxContainer = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow
@onready var key_item: VBoxContainer = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow/KeyItem
@onready var key_texture_rect: TextureRect = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow/KeyItem/KeyTexture
@onready var card_item: VBoxContainer = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow/CardItem
@onready var card_texture_rect: TextureRect = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow/CardItem/CardTexture
@onready var collect_clue_button: Button = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/CollectClueButton

const FINAL_BOX_PUZZLE_ID := "abandoned_house_final_box_opened"

@export var final_box_closed_texture: Texture2D
@export var final_box_opened_texture: Texture2D

@onready var final_box_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/CabinetPuzzlePanel/MarginContainer/VBoxContainer/CabinetHolder/FinalBoxHotspot

@onready var final_box_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel
@onready var final_box_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var final_box_texture_rect: TextureRect = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/BoxTexture
@onready var detective_pattern_label: Label = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/DetectivePatternLabel
@onready var sidekick_input_row: VBoxContainer = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/SidekickInputRow
@onready var answer_input: LineEdit = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/SidekickInputRow/AnswerInput
@onready var submit_answer_button: Button = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/SidekickInputRow/SubmitAnswerButton
@onready var close_final_box_button: Button = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BottomBar/CloseFinalBoxButton

const FINAL_BOX_REWARD_ITEMS := ["pinas_tiara"]

@export var tiara_clue_texture: Texture2D

@onready var tiara_image: TextureRect = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/TiaraImage
@onready var tiara_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/TiaraHotspot

const TIARA_REWARD_ITEMS := ["pinas_tiara"]

# Use your real solved keys if you already have them in the script
const BOOKS_PUZZLE_ID := "abandoned_house_books_solved"

@export var progress_default_texture: Texture2D
@export var progress_2_texture: Texture2D
@export var progress_3_texture: Texture2D
@export var progress_4_texture: Texture2D
@export var progress_5_texture: Texture2D

@onready var progress_tracker_sprite: Sprite2D = $ProgressTracker/Tracker

const TIARA_SPARKLE_MIN_SCALE := 0.45
const TIARA_SPARKLE_MAX_SCALE := 0.55
const TIARA_SPARKLE_PULSE_SPEED := 4.0

@onready var cinematic_reward_layer: CanvasLayer = get_node_or_null("RewardLayer")
@onready var cinematic_dark_overlay: ColorRect = get_node_or_null("RewardLayer/DarkOverlay")
@onready var cinematic_banner_label: Label = get_node_or_null("RewardLayer/BannerLabel")
@onready var cinematic_reward_text: Label = get_node_or_null("RewardLayer/RewardPanel/RewardText")
@onready var cinematic_clue_sprite: Sprite2D = get_node_or_null("RewardLayer/ClueSprite")
@onready var cinematic_collect_button: Button = get_node_or_null("RewardLayer/CollectButton")
@onready var cinematic_reward_panel: Sprite2D = get_node_or_null("RewardLayer/RewardPanel")
@onready var cinematic_tap_instruction: Label = get_node_or_null("RewardLayer/TapInstruction")
@onready var cinematic_tap_catcher: Button = get_node_or_null("RewardLayer/TapCatcher")
@onready var cinematic_briefcase_reveal: TextureRect = get_node_or_null("RewardLayer/BriefcaseRevealSprite")
@onready var cinematic_sparkle: Sprite2D = get_node_or_null("RewardLayer/Sparkle")

var _tiara_reward_active := false
var _tiara_waiting_continue := false
var _tiara_reward_stage := 0
var _tiara_collect_sequence_started := false
var _tiara_animation_time := 0.0
var _tiara_sparkle_animating := false

var _intro_dialogue_played: bool = false
var _dialogue_input_locked: bool = false

var _final_box_opened: bool = false

const CABINET_PUZZLE_ID := "abandoned_house_cabinet_opened"
const CABINET_KEY_ITEM_ID := "assembled_key"

var _cabinet_opened: bool = false

const MIRROR_PUZZLE_ID := "abandoned_house_mirror_lit"

var _mirror_lit: bool = false
var _default_room_texture: Texture2D

var _book_textures: Dictionary = {}
var _book_nodes: Dictionary = {}
var _book_order: Array[String] = []

var _books_solved: bool = false

var _pending_reward_items: Array[String] = []

@onready var books_hint_marker: Sprite2D = $InteractiveLayer/BooksArea/HintMarker
var _books_hint_original_scale: Vector2 = Vector2.ONE
var _books_hint_tween: Tween

var _drag_book_id: String = ""
var _drag_pointer_offset_y: float = 0.0
var _notification_token: int = 0

var _memory_face_textures: Dictionary = {}
var _memory_deck: Array[String] = []
var _memory_buttons: Array[TextureButton] = []
var _memory_selected_indices: Array[int] = []
var _memory_matched_indices: Dictionary = {}
var _memory_busy: bool = false
var _memory_unlocked: bool = false
var _memory_solved: bool = false

func _ready() -> void:
	_book_textures = {
		"book_1": book_1_texture,
		"book_2": book_2_texture,
		"book_3": book_3_texture,
		"book_4": book_4_texture,
	}
	
	_memory_face_textures = {
		"face_1": memory_card_1_texture,
		"face_2": memory_card_2_texture,
		"face_3": memory_card_3_texture,
		"face_4": memory_card_4_texture,
		"face_5": memory_card_5_texture,
		"face_6": memory_card_6_texture,
	}
	
	_setup_ui()
	_setup_books_hint()
	_setup_reward_preview()
	_setup_memory_ui()
	_connect_signals()
	_refresh_role_label()
	_load_books_progress()
	_load_memory_progress()
	
	_default_room_texture = bedroom_background.texture
	_setup_mirror_ui()
	_load_mirror_progress()
	
	_setup_drawer_ui()
	_load_drawer_progress()
	_setup_drawer_lock_digits()
	
	_setup_cabinet_ui()
	_load_cabinet_progress()

	_setup_final_box_ui()
	_load_final_box_progress()
	_load_final_box_data()
	
	_prepare_final_box_variation()
	
	_setup_tiara_reward_layer()
	
	_setup_progress_tracker()
	_refresh_progress_tracker()
	
	await get_tree().process_frame
	_resize_books_popup()
	_prepare_books()
	_start_intro_dialogue_delayed()
	
	if key_fragment_image:
		key_fragment_image.visible = false

	if key_fragment_hotspot:
		key_fragment_hotspot.visible = false
		key_fragment_hotspot.disabled = true
		
	if books_hint_marker:
		books_hint_marker.visible = false

func _setup_ui() -> void:
	if has_node("TestLabel"):
		$TestLabel.visible = false

	notification_label.visible = false

	instruction_label.text = "Drag the books to arrange them by width.\nNarrowest should be on top and widest should be at the bottom."

	dimmer.visible = false
	books_puzzle_panel.visible = false
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	books_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	reward_dimmer.visible = false
	reward_panel.visible = false
	reward_items_row.visible = false
	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup_reward_preview() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	var panel_width: float = clampf(viewport_size.x * 0.42, 480.0, 620.0)
	var panel_height: float = clampf(viewport_size.y * 0.40, 300.0, 380.0)

	reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	reward_panel.size = Vector2(panel_width, panel_height)
	reward_panel.position = (viewport_size - reward_panel.size) * 0.5

	reward_items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_items_row.add_theme_constant_override("separation", 16)

	key_item.custom_minimum_size = Vector2(140, 100)
	card_item.custom_minimum_size = Vector2(140, 140)

	key_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	key_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_fit_reward_texture(key_texture_rect, Vector2(110, 70))
	_fit_reward_texture(card_texture_rect, Vector2(110, 110))

	if key_fragment_1_texture:
		key_texture_rect.texture = _make_cropped_key_texture(key_fragment_1_texture)

	if card_piece_texture:
		card_texture_rect.texture = card_piece_texture


func _connect_signals() -> void:
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	if not books_area.input_event.is_connected(_on_books_area_input_event):
		books_area.input_event.connect(_on_books_area_input_event)

	if not close_puzzle_button.pressed.is_connected(_on_close_puzzle_button_pressed):
		close_puzzle_button.pressed.connect(_on_close_puzzle_button_pressed)

	if not collect_reward_button.pressed.is_connected(_on_collect_reward_button_pressed):
		collect_reward_button.pressed.connect(_on_collect_reward_button_pressed)
		
	if not puzzle_area.input_event.is_connected(_on_puzzle_area_input_event):
		puzzle_area.input_event.connect(_on_puzzle_area_input_event)

	if not close_memory_button.pressed.is_connected(_on_close_memory_button_pressed):
		close_memory_button.pressed.connect(_on_close_memory_button_pressed)

	if not mirror_area.input_event.is_connected(_on_mirror_area_input_event):
		mirror_area.input_event.connect(_on_mirror_area_input_event)

	if not close_mirror_button.pressed.is_connected(_on_close_mirror_button_pressed):
		close_mirror_button.pressed.connect(_on_close_mirror_button_pressed)

	if not lamp_hotspot.pressed.is_connected(_on_lamp_hotspot_pressed):
		lamp_hotspot.pressed.connect(_on_lamp_hotspot_pressed)
		
	if not drawer_area.input_event.is_connected(_on_drawer_area_input_event):
		drawer_area.input_event.connect(_on_drawer_area_input_event)

	if not close_drawer_button.pressed.is_connected(_on_close_drawer_button_pressed):
		close_drawer_button.pressed.connect(_on_close_drawer_button_pressed)

	if not drawer_lock_hotspot.pressed.is_connected(_on_drawer_lock_hotspot_pressed):
		drawer_lock_hotspot.pressed.connect(_on_drawer_lock_hotspot_pressed)

	if not close_drawer_lock_button.pressed.is_connected(_on_close_drawer_lock_button_pressed):
		close_drawer_lock_button.pressed.connect(_on_close_drawer_lock_button_pressed)
	
	if not digit_1_button.pressed.is_connected(_on_drawer_digit_pressed.bind(0)):
		digit_1_button.pressed.connect(_on_drawer_digit_pressed.bind(0))

	if not digit_2_button.pressed.is_connected(_on_drawer_digit_pressed.bind(1)):
		digit_2_button.pressed.connect(_on_drawer_digit_pressed.bind(1))

	if not digit_3_button.pressed.is_connected(_on_drawer_digit_pressed.bind(2)):
		digit_3_button.pressed.connect(_on_drawer_digit_pressed.bind(2))

	if key_fragment_hotspot and not key_fragment_hotspot.pressed.is_connected(_on_key_fragment_hotspot_pressed):
		key_fragment_hotspot.pressed.connect(_on_key_fragment_hotspot_pressed)
	
	if not cabinet_area.input_event.is_connected(_on_cabinet_area_input_event):
		cabinet_area.input_event.connect(_on_cabinet_area_input_event)

	if not close_cabinet_button.pressed.is_connected(_on_close_cabinet_button_pressed):
		close_cabinet_button.pressed.connect(_on_close_cabinet_button_pressed)

	if not cabinet_lock_hotspot.pressed.is_connected(_on_cabinet_lock_hotspot_pressed):
		cabinet_lock_hotspot.pressed.connect(_on_cabinet_lock_hotspot_pressed)
	
	if final_box_hotspot and not final_box_hotspot.pressed.is_connected(_on_final_box_hotspot_pressed):
		final_box_hotspot.pressed.connect(_on_final_box_hotspot_pressed)

	if close_final_box_button and not close_final_box_button.pressed.is_connected(_on_close_final_box_button_pressed):
		close_final_box_button.pressed.connect(_on_close_final_box_button_pressed)

	if submit_answer_button and not submit_answer_button.pressed.is_connected(_on_submit_final_box_answer_pressed):
		submit_answer_button.pressed.connect(_on_submit_final_box_answer_pressed)
	
	if tiara_hotspot and not tiara_hotspot.pressed.is_connected(_on_tiara_hotspot_pressed):
		tiara_hotspot.pressed.connect(_on_tiara_hotspot_pressed)

	if cinematic_collect_button and not cinematic_collect_button.pressed.is_connected(_on_tiara_collect_pressed):
		cinematic_collect_button.pressed.connect(_on_tiara_collect_pressed)

	if cinematic_tap_catcher and not cinematic_tap_catcher.pressed.is_connected(_on_tiara_tap_catcher_pressed):
		cinematic_tap_catcher.pressed.connect(_on_tiara_tap_catcher_pressed)
		
func _refresh_role_label() -> void:
	var role_text := "Unknown"

	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"

	role_label.text = "Role: " + role_text

	if inside_zone_control and inside_zone_control.has_method("set_sidekick_ui_visible"):
		inside_zone_control.set_sidekick_ui_visible(_is_local_sidekick())


func _load_books_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_books_solved = GameState.is_puzzle_solved(SUB_PUZZLE_ID)
	else:
		_books_solved = false


func _prepare_books() -> void:
	if _book_order.is_empty():
		var source_order: Array = BOOK_ORDER_TOP_TO_BOTTOM if _books_solved else BOOK_START_ORDER
		_set_book_order_from(source_order)

	_build_book_nodes()
	_layout_books()

func _build_book_nodes() -> void:
	if not _book_nodes.is_empty():
		return

	for raw_book_id in BOOK_ORDER_TOP_TO_BOTTOM:
		var book_id: String = str(raw_book_id)
		var texture: Texture2D = _create_cropped_book_texture(book_id)

		if texture == null:
			push_warning("[AbandonedHouse] Missing texture for %s" % book_id)
			continue

		var book_rect: TextureRect = TextureRect.new()
		book_rect.name = book_id
		book_rect.texture = texture
		book_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		book_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		book_rect.stretch_mode = TextureRect.STRETCH_SCALE
		book_rect.gui_input.connect(_on_book_gui_input.bind(book_id))

		puzzle_board.add_child(book_rect)
		_book_nodes[book_id] = book_rect

func _create_cropped_book_texture(book_id: String) -> Texture2D:
	var source_texture: Texture2D = _book_textures.get(book_id, null) as Texture2D
	if source_texture == null:
		return null

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = BOOK_CROP_REGIONS[book_id] as Rect2
	return atlas

func _refresh_books_view_state() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_books_solved = GameState.is_puzzle_solved(SUB_PUZZLE_ID)

	if _books_solved:
		_set_book_order_from(BOOK_ORDER_TOP_TO_BOTTOM)
	else:
		_set_book_order_from(BOOK_START_ORDER)

	_layout_books()

func _on_books_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _dialogue_input_locked:
		return
	
	if not _is_primary_press_event(event):
		return
		
	_hide_books_hint()

	_refresh_books_view_state()
	_open_books_panel()

	if not _books_solved and not _is_local_detective():
		_show_notification("Only the Detective can rearrange these books.")

func _refresh_books_panel_for_role() -> void:
	instruction_label.visible = _is_local_detective() and not _books_solved

	if _is_local_detective():
		close_puzzle_button.text = "Back"
	else:
		close_puzzle_button.text = "Close"

func _open_books_panel() -> void:
	_set_books_panel_visible(true)
	_refresh_books_panel_for_role()
	await get_tree().process_frame
	_resize_books_popup()
	await get_tree().process_frame
	_layout_books()


func _close_books_panel() -> void:
	if _drag_book_id != "":
		_finish_drag()

	_set_books_panel_visible(false)


func _set_books_panel_visible(visible_state: bool) -> void:
	dimmer.visible = visible_state
	books_puzzle_panel.visible = visible_state

	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE
	books_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE


func _on_close_puzzle_button_pressed() -> void:
	_close_books_panel()


func _on_book_gui_input(event: InputEvent, book_id: String) -> void:
	if _books_solved:
		return

	if not _is_local_detective():
		return

	if not books_puzzle_panel.visible:
		return

	if _is_primary_press_event(event):
		_begin_drag(book_id, _get_event_position(event))


func _input(event: InputEvent) -> void:
	if _drag_book_id == "":
		return

	if event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_drag(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_drag()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag()


func _begin_drag(book_id: String, screen_position: Vector2) -> void:
	if not _book_nodes.has(book_id):
		return

	var book_node: TextureRect = _book_nodes[book_id]
	_drag_book_id = book_id

	var local_pointer := book_node.get_global_transform_with_canvas().affine_inverse() * screen_position
	_drag_pointer_offset_y = local_pointer.y

	book_node.z_index = 50
	book_node.modulate = Color(1.0, 0.96, 0.86, 1.0)
	book_node.move_to_front()

func _update_drag(screen_position: Vector2) -> void:
	if _drag_book_id == "":
		return

	var book_node: TextureRect = _book_nodes[_drag_book_id] as TextureRect
	var board_local: Vector2 = puzzle_board.get_global_transform_with_canvas().affine_inverse() * screen_position

	var clamped_y: float = clampf(
		board_local.y - _drag_pointer_offset_y,
		0.0,
		maxf(0.0, puzzle_board.size.y - book_node.size.y)
	)

	book_node.position.y = clamped_y
	book_node.position.x = _get_centered_x(book_node.size.x)


func _finish_drag() -> void:
	if _drag_book_id == "":
		return

	var dragged_id: String = _drag_book_id
	var dragged_node: TextureRect = _book_nodes[dragged_id] as TextureRect

	var target_index: int = _get_nearest_slot_index(dragged_node.position.y + (dragged_node.size.y * 0.5))
	var current_index: int = _book_order.find(dragged_id)

	if current_index != -1 and target_index != -1 and current_index != target_index:
		_book_order.remove_at(current_index)
		_book_order.insert(target_index, dragged_id)

	dragged_node.z_index = 0
	dragged_node.modulate = Color.WHITE

	_drag_book_id = ""
	_drag_pointer_offset_y = 0.0

	_layout_books()
	_check_books_solution()
	
func _layout_books() -> void:
	var current_y: float = _get_stack_start_y()

	for i in range(_book_order.size()):
		var book_id: String = _book_order[i]
		if not _book_nodes.has(book_id):
			continue

		var book_node: TextureRect = _book_nodes[book_id] as TextureRect
		var target_size: Vector2 = _get_book_display_size(book_id)

		book_node.size = target_size
		book_node.position = Vector2(
			_get_centered_x(target_size.x),
			current_y
		)

		if _drag_book_id != book_id:
			book_node.z_index = i

		current_y += target_size.y + BOOK_STACK_GAP

func _get_book_display_size(book_id: String) -> Vector2:
	var crop_region: Rect2 = BOOK_CROP_REGIONS[book_id] as Rect2
	var board_width: float = maxf(1.0, _get_effective_board_size().x)
	var target_width: float = board_width * float(BOOK_WIDTH_RATIOS[book_id])
	var aspect_ratio: float = crop_region.size.y / crop_region.size.x
	var target_height: float = target_width * aspect_ratio

	return Vector2(target_width, target_height)


func _get_centered_x(content_width: float) -> float:
	return (_get_effective_board_size().x - content_width) * 0.5

func _get_slot_top_y(index: int, _book_height: float) -> float:
	var y: float = _get_stack_start_y()

	for i in range(index):
		var previous_id: String = _book_order[i]
		y += _get_book_display_size(previous_id).y + BOOK_STACK_GAP

	return y

func _get_nearest_slot_index(book_center_y: float) -> int:
	var nearest_index: int = 0
	var nearest_distance: float = INF

	for i in range(_book_order.size()):
		var slot_book_id: String = _book_order[i]
		var slot_size: Vector2 = _get_book_display_size(slot_book_id)
		var slot_center_y: float = _get_slot_top_y(i, slot_size.y) + (slot_size.y * 0.5)
		var distance_to_slot: float = absf(book_center_y - slot_center_y)

		if distance_to_slot < nearest_distance:
			nearest_distance = distance_to_slot
			nearest_index = i

	return nearest_index


func _check_books_solution() -> void:
	if _book_order.size() != BOOK_ORDER_TOP_TO_BOTTOM.size():
		return

	for i in range(BOOK_ORDER_TOP_TO_BOTTOM.size()):
		if _book_order[i] != BOOK_ORDER_TOP_TO_BOTTOM[i]:
			return

	_complete_books_puzzle()


func _complete_books_puzzle() -> void:
	if _books_solved:
		return

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_books_puzzle_solved_rpc.rpc()
	else:
		_apply_books_puzzle_solved()


@rpc("authority", "reliable", "call_local")
func _sync_books_puzzle_solved_rpc() -> void:
	_apply_books_puzzle_solved()


func _apply_books_puzzle_solved() -> void:
	if _books_solved:
		return

	_books_solved = true
	_set_book_order_from(BOOK_ORDER_TOP_TO_BOTTOM)
	_layout_books()

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(SUB_PUZZLE_ID, true)

	# IMPORTANT:
	# Do NOT grant the reward items here anymore.
	# We only grant them after the sidekick presses Collect Clue.

	_close_books_panel()
	_show_books_reward_panel()


func _resize_books_popup() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	var panel_width: float = clampf(viewport_size.x * 0.62, 700.0, 980.0)
	var panel_height: float = clampf(viewport_size.y * 0.58, 360.0, 620.0)

	books_puzzle_panel.size = Vector2(panel_width, panel_height)
	books_puzzle_panel.position = (viewport_size - books_puzzle_panel.size) * 0.5

	var board_width: float = panel_width - 80.0
	var board_height: float = panel_height - 170.0

	puzzle_board.custom_minimum_size = Vector2(
		maxf(560.0, board_width),
		maxf(180.0, board_height)
	)

func _show_books_reward_panel() -> void:
	_pending_reward_items.clear()
	_pending_reward_items.append_array(REWARD_ITEMS)
	reward_title_label.text = "Puzzle Solved"
	reward_body_label.text = "You found Key Fragment 1 and the Card Piece."

	reward_items_row.visible = true
	key_texture_rect.visible = true
	card_texture_rect.visible = true

	if key_fragment_1_texture:
		key_texture_rect.texture = _make_cropped_key_texture(key_fragment_1_texture)

	if card_piece_texture:
		card_texture_rect.texture = card_piece_texture

	collect_reward_button.text = "Collect Clue"
	collect_reward_button.visible = _is_local_sidekick()

	reward_dimmer.visible = true
	reward_panel.visible = true

	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _hide_reward_panel() -> void:
	_pending_reward_items.clear()
	reward_dimmer.visible = false
	reward_panel.visible = false
	reward_items_row.visible = false

	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _auto_close_reward_panel() -> void:
	await get_tree().create_timer(1.5).timeout

	if _is_local_detective() and reward_panel.visible:
		_hide_reward_panel()


func _on_collect_reward_button_pressed() -> void:
	if not _is_local_sidekick():
		return

	if _pending_reward_items.is_empty():
		_hide_reward_panel()
		return

	if multiplayer.has_multiplayer_peer():
		_collect_reward_items_rpc.rpc(_pending_reward_items)
	else:
		_collect_reward_items_rpc(_pending_reward_items)

@rpc("any_peer", "reliable", "call_local")
func _collect_reward_items_rpc(item_ids: Array) -> void:
	if GameState and GameState.has_method("grant_zone_items"):
		GameState.grant_zone_items(ZONE_ID, item_ids)

	_hide_reward_panel()

	# refresh drawer UI in case key_fragment_3 was just collected
	if item_ids.has("key_fragment_3"):
		_refresh_drawer_panel_state()
		
	if item_ids.has("pinas_tiara"):
		_refresh_final_box_clue_state()

@rpc("any_peer", "reliable", "call_local")
func _collect_books_reward_rpc() -> void:
	if GameState and GameState.has_method("grant_zone_items"):
		GameState.grant_zone_items(ZONE_ID, REWARD_ITEMS)

	_hide_reward_panel()


func _show_notification(message: String, duration: float = 1.8) -> void:
	_notification_token += 1
	var token := _notification_token

	notification_label.text = message
	notification_label.visible = true

	await get_tree().create_timer(duration).timeout

	if token == _notification_token and is_instance_valid(notification_label):
		notification_label.visible = false


func _is_local_detective() -> bool:
	if not GameState:
		return false

	return GameState.local_role == GameState.Role.DETECTIVE

func _is_local_sidekick() -> bool:
	if not GameState:
		return false

	return GameState.local_role == GameState.Role.SIDEKICK

func _is_primary_press_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and event.pressed

	if event is InputEventScreenTouch:
		return event.pressed

	return false


func _get_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return event.position

	if event is InputEventScreenTouch:
		return event.position

	if event is InputEventScreenDrag:
		return event.position

	if event is InputEventMouseMotion:
		return event.position

	return Vector2.ZERO


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(FOREST_HUB_SCENE_PATH)

func _set_book_order_from(source_order: Array) -> void:
	_book_order.clear()

	for item in source_order:
		_book_order.append(str(item))

func _get_effective_board_size() -> Vector2:
	if puzzle_board.size.x > 0.0 and puzzle_board.size.y > 0.0:
		return puzzle_board.size

	return puzzle_board.custom_minimum_size
	
func _get_stack_start_y() -> float:
	var total_height: float = 0.0

	for raw_book_id in _book_order:
		var book_id: String = str(raw_book_id)
		total_height += _get_book_display_size(book_id).y

	if _book_order.size() > 1:
		total_height += BOOK_STACK_GAP * float(_book_order.size() - 1)

	var board_height: float = _get_effective_board_size().y
	return maxf(12.0, (board_height - total_height) * 0.5)
	
func _fit_reward_texture(texture_rect: TextureRect, target_size: Vector2) -> void:
	texture_rect.custom_minimum_size = target_size
	texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _make_cropped_key_texture(source_texture: Texture2D) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = Rect2(40, 370, 760, 420)
	return atlas

func _setup_memory_ui() -> void:
	if not memory_puzzle_panel:
		push_warning("MemoryPuzzlePanel not found.")
		return

	memory_puzzle_panel.visible = false
	memory_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := get_node_or_null("PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer") as MarginContainer
	if margin:
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 8)

	if memory_instruction_label:
		memory_instruction_label.visible = false

	if memory_grid:
		memory_grid.columns = 4
		memory_grid.visible = true
		memory_grid.add_theme_constant_override("h_separation", 4)
		memory_grid.add_theme_constant_override("v_separation", 4)

	if close_memory_button:
		close_memory_button.visible = true
		close_memory_button.text = "Back"
		close_memory_button.custom_minimum_size = Vector2(170, 42)
	
func _load_memory_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_memory_solved = GameState.is_puzzle_solved(MEMORY_PUZZLE_ID)
	else:
		_memory_solved = false

	_memory_unlocked = _memory_solved
	
func _on_puzzle_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _dialogue_input_locked:
		return
	
	if not _is_primary_press_event(event):
		return

	if not _is_local_sidekick():
		_show_notification("Only the Sidekick can solve this card puzzle.")
		return

	_open_memory_panel()
	
func _open_memory_panel() -> void:
	_set_memory_panel_visible(true)
	_refresh_memory_panel_state()
	await get_tree().process_frame
	_resize_memory_popup()

	if _memory_unlocked:
		_rebuild_memory_grid_unlocked()
	else:
		_rebuild_memory_grid_locked()
		
func _close_memory_panel() -> void:
	_set_memory_panel_visible(false)
	
func _set_memory_panel_visible(visible_state: bool) -> void:
	dimmer.visible = visible_state
	memory_puzzle_panel.visible = visible_state

	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE
	memory_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE
	
func _on_close_memory_button_pressed() -> void:
	_close_memory_panel()

func _refresh_memory_panel_state() -> void:
	if _memory_solved:
		memory_instruction_label.text = "You already solved this card puzzle."
		if memory_grid:
			memory_grid.visible = true
		return

	if _memory_unlocked:
		memory_instruction_label.text = "Flip the cards and match each pair."
		if memory_grid:
			memory_grid.visible = true
		return

	memory_instruction_label.text = "Open the briefcase, select the Card Piece, press Use, then tap the empty slot."

	if memory_grid:
		memory_grid.visible = true

func _resize_memory_popup() -> void:
	if not memory_puzzle_panel:
		return

	var viewport_size: Vector2 = get_viewport_rect().size

	# Square container for mobile landscape
	var panel_side: float = clampf(minf(viewport_size.x, viewport_size.y) * 0.72, 520.0, 620.0)

	memory_puzzle_panel.size = Vector2(panel_side, panel_side)
	memory_puzzle_panel.position = (viewport_size - memory_puzzle_panel.size) * 0.5

	if memory_grid:
		var card_w := 88.0
		var card_h := 118.0
		var h_sep := 4.0
		var v_sep := 4.0

		var grid_width := (card_w * 4.0) + (h_sep * 3.0)
		var grid_height := (card_h * 3.0) + (v_sep * 2.0)

		memory_grid.custom_minimum_size = Vector2(grid_width, grid_height)
		memory_grid.size = Vector2(grid_width, grid_height)
		memory_grid.position = Vector2(
			(panel_side - grid_width) * 0.5,
			28.0
		)

	if close_memory_button:
		var button_size := Vector2(170, 42)
		close_memory_button.size = button_size
		close_memory_button.position = Vector2(
			(panel_side - button_size.x) * 0.5,
			panel_side - button_size.y - 18.0
		)
	
func _has_card_piece() -> bool:
	return GameState and GameState.has_method("has_zone_item") and GameState.has_zone_item(ZONE_ID, "card_piece")
	
func _clear_memory_grid() -> void:
	for child in memory_grid.get_children():
		child.queue_free()

	_memory_buttons.clear()
	
	
func _rebuild_memory_grid_locked() -> void:
	_clear_memory_grid()

	if memory_grid:
		memory_grid.columns = 4

	for i in range(12):
		if i == 0:
			var missing_slot := TextureButton.new()
			missing_slot.custom_minimum_size = Vector2(105, 145)
			missing_slot.ignore_texture_size = true
			missing_slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			missing_slot.texture_normal = null
			missing_slot.texture_pressed = null
			missing_slot.texture_hover = null
			missing_slot.modulate = Color(1, 1, 1, 0.0)
			missing_slot.focus_mode = Control.FOCUS_NONE
			missing_slot.pressed.connect(_on_missing_slot_pressed)
			memory_grid.add_child(missing_slot)
		else:
			var locked_card := TextureButton.new()
			locked_card.custom_minimum_size = Vector2(105, 145)
			locked_card.ignore_texture_size = true
			locked_card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			locked_card.texture_normal = memory_card_back_texture
			locked_card.disabled = true
			locked_card.focus_mode = Control.FOCUS_NONE
			memory_grid.add_child(locked_card)
			
func _rebuild_memory_grid_unlocked() -> void:
	_clear_memory_grid()

	if memory_grid:
		memory_grid.columns = 4

	if _memory_deck.size() != 12:
		_build_shuffled_memory_deck()

	for i in range(_memory_deck.size()):
		var button := TextureButton.new()
		button.custom_minimum_size = Vector2(105, 145)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_normal = memory_card_back_texture
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_memory_card_pressed.bind(i))
		memory_grid.add_child(button)
		_memory_buttons.append(button)

		_refresh_memory_card_visual(i)
		
func _build_shuffled_memory_deck() -> void:
	_memory_deck.clear()

	for face_id in MEMORY_FACE_IDS:
		_memory_deck.append(face_id)
		_memory_deck.append(face_id)

	_memory_deck.shuffle()
	
func _on_memory_card_pressed(index: int) -> void:
	if _memory_busy or _memory_solved or not _memory_unlocked:
		return

	if _memory_matched_indices.has(index):
		return

	if _memory_selected_indices.has(index):
		return

	_memory_selected_indices.append(index)
	_refresh_memory_card_visual(index)

	if _memory_selected_indices.size() < 2:
		return

	_memory_busy = true
	await get_tree().create_timer(0.6).timeout

	var first_index := _memory_selected_indices[0]
	var second_index := _memory_selected_indices[1]

	if _memory_deck[first_index] == _memory_deck[second_index]:
		_memory_matched_indices[first_index] = true
		_memory_matched_indices[second_index] = true
	else:
		_memory_selected_indices.clear()
		_refresh_memory_card_visual(first_index)
		_refresh_memory_card_visual(second_index)

	if _memory_matched_indices.size() == _memory_deck.size():
		_complete_memory_puzzle()
	else:
		_memory_selected_indices.clear()

	_memory_busy = false
	
func _refresh_memory_card_visual(index: int) -> void:
	if index < 0 or index >= _memory_buttons.size():
		return

	var button: TextureButton = _memory_buttons[index]
	var face_id: String = _memory_deck[index]
	var face_texture: Texture2D = _memory_face_textures.get(face_id, null) as Texture2D

	var should_show_face := _memory_solved or _memory_matched_indices.has(index) or _memory_selected_indices.has(index)

	button.texture_normal = face_texture if should_show_face else memory_card_back_texture
	button.modulate = Color.WHITE if should_show_face else Color(1, 1, 1, 1)
	
func _reset_memory_round() -> void:
	_memory_selected_indices.clear()
	_memory_matched_indices.clear()
	_memory_busy = false
	
func _complete_memory_puzzle() -> void:
	if _memory_solved:
		return

	if multiplayer.has_multiplayer_peer():
		_sync_memory_puzzle_solved_rpc.rpc()
	else:
		_apply_memory_puzzle_solved()

@rpc("any_peer", "reliable", "call_local")
func _sync_memory_puzzle_solved_rpc() -> void:
	_apply_memory_puzzle_solved()

func _apply_memory_puzzle_solved() -> void:
	if _memory_solved:
		return

	_memory_solved = true
	_memory_busy = false
	_memory_selected_indices.clear()

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(MEMORY_PUZZLE_ID, true)

	for i in range(_memory_buttons.size()):
		_refresh_memory_card_visual(i)

	memory_instruction_label.text = "All pairs matched. Puzzle solved!"
	_close_memory_panel()
	_show_memory_reward_panel()
	_show_notification("Card puzzle solved.")

func _show_memory_reward_panel() -> void:
	_pending_reward_items.clear()
	_pending_reward_items.append_array(MEMORY_REWARD_ITEMS)
	reward_title_label.text = "Puzzle Solved"
	reward_body_label.text = "You found Key Fragment 2 and the Lighter."

	reward_items_row.visible = true
	key_texture_rect.visible = true
	card_texture_rect.visible = true

	if key_fragment_2_texture:
		key_texture_rect.texture = key_fragment_2_texture

	if lighter_texture:
		card_texture_rect.texture = lighter_texture

	collect_reward_button.text = "Collect Clue"
	collect_reward_button.visible = _is_local_sidekick()

	reward_dimmer.visible = true
	reward_panel.visible = true

	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_missing_slot_pressed() -> void:
	if _memory_unlocked or _memory_solved:
		return

	if not _is_local_sidekick():
		return

	if not inside_zone_control:
		return

	if not inside_zone_control.has_method("consume_armed_item"):
		return

	var used: bool = inside_zone_control.consume_armed_item("card_piece")
	if not used:
		_show_notification("Open the briefcase, select the Card Piece, press Use, then tap the empty slot.")
		return

	_memory_unlocked = true
	_reset_memory_round()
	_build_shuffled_memory_deck()
	_refresh_memory_panel_state()
	_rebuild_memory_grid_unlocked()
	_show_notification("Card Piece inserted.")

func _setup_mirror_ui() -> void:
	if mirror_puzzle_panel:
		mirror_puzzle_panel.visible = false
		mirror_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _load_mirror_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_mirror_lit = GameState.is_puzzle_solved(MIRROR_PUZZLE_ID)
	else:
		_mirror_lit = false

	_refresh_room_lighting()


func _on_mirror_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _dialogue_input_locked:
		return
	
	if not _is_primary_press_event(event):
		return

	_open_mirror_panel()


func _open_mirror_panel() -> void:
	_close_books_panel()
	_close_memory_panel()

	dimmer.visible = true
	mirror_puzzle_panel.visible = true

	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	mirror_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_refresh_mirror_panel_state()


func _close_mirror_panel() -> void:
	mirror_puzzle_panel.visible = false
	mirror_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not books_puzzle_panel.visible and not memory_puzzle_panel.visible:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_close_mirror_button_pressed() -> void:
	_close_mirror_panel()


func _refresh_mirror_panel_state() -> void:
	if _mirror_lit:
		if _is_local_sidekick():
			mirror_texture_rect.texture = mirror_lighted_no_fp_texture
		else:
			mirror_texture_rect.texture = mirror_lighted_with_fp_texture

		mirror_instruction_label.text = "The lamp is lit."
		lamp_hotspot.visible = false
		lamp_hotspot.disabled = true
	else:
		mirror_texture_rect.texture = mirror_not_lighted_texture

		if _is_local_sidekick():
			mirror_instruction_label.text = "Tap the lamp."
			lamp_hotspot.visible = true
			lamp_hotspot.disabled = false
		else:
			mirror_instruction_label.text = "Wait for the Sidekick to light the lamp."
			lamp_hotspot.visible = false
			lamp_hotspot.disabled = true

func _on_lamp_hotspot_pressed() -> void:
	if _dialogue_input_locked:
		return
	
	if _mirror_lit:
		return

	if not _is_local_sidekick():
		return

	if not inside_zone_control or not inside_zone_control.has_method("consume_armed_item"):
		return

	var used: bool = inside_zone_control.consume_armed_item("light_bulb")
	if not used:
		mirror_instruction_label.text = "Light this lamp. Open the briefcase, select the Lighter, press Use, then tap the lamp."
		_show_notification("Light this lamp.")
		return

	if multiplayer.has_multiplayer_peer():
		_sync_mirror_lit_rpc.rpc()
	else:
		_apply_mirror_lit()


@rpc("any_peer", "reliable", "call_local")
func _sync_mirror_lit_rpc() -> void:
	_apply_mirror_lit()


func _apply_mirror_lit() -> void:
	if _mirror_lit:
		return

	_mirror_lit = true

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(MIRROR_PUZZLE_ID, true)

	if GameState and GameState.has_signal("briefcase_updated"):
		GameState.briefcase_updated.emit()

	_refresh_room_lighting()
	_refresh_mirror_panel_state()
	_show_notification("The lamp is lit.")


func _refresh_room_lighting() -> void:
	if _mirror_lit and lighted_room_texture:
		bedroom_background.texture = lighted_room_texture
	elif _default_room_texture:
		bedroom_background.texture = _default_room_texture
		
func _close_puzzle_panel() -> void:
	books_puzzle_panel.visible = false
	books_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not memory_puzzle_panel.visible and not mirror_puzzle_panel.visible:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_drawer_ui() -> void:
	if drawer_panel:
		drawer_panel.visible = false
		drawer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if drawer_lock_panel:
		drawer_lock_panel.visible = false
		drawer_lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _load_drawer_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_drawer_unlocked = GameState.is_puzzle_solved(DRAWER_PUZZLE_ID)
	else:
		_drawer_unlocked = false

	if _drawer_unlocked:
		_drawer_digits = DRAWER_CORRECT_CODE.duplicate()
	else:
		_drawer_digits = [0, 0, 0]

	_refresh_drawer_panel_state()
	_refresh_drawer_lock_panel_state()
	_refresh_drawer_digit_visuals()


func _on_drawer_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _dialogue_input_locked:
		return
	
	if cabinet_puzzle_panel.visible:
		return
	if not _is_primary_press_event(event):
		return
	_open_drawer_panel()


func _open_drawer_panel() -> void:
	_close_books_panel()
	_close_memory_panel()
	_close_mirror_panel()

	drawer_lock_panel.visible = false
	drawer_lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	dimmer.visible = true
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP

	drawer_panel.visible = true
	drawer_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_refresh_drawer_panel_state()


func _close_drawer_panel() -> void:
	drawer_panel.visible = false
	drawer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not books_puzzle_panel.visible and not memory_puzzle_panel.visible and not mirror_puzzle_panel.visible and not drawer_lock_panel.visible:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_close_drawer_button_pressed() -> void:
	_close_drawer_panel()


func _refresh_drawer_panel_state() -> void:
	if _drawer_unlocked:
		if drawer_open_texture:
			drawer_texture_rect.texture = drawer_open_texture

		drawer_instruction_label.text = "The drawer is open."
		drawer_lock_hotspot.visible = false
		drawer_lock_hotspot.disabled = true
		_refresh_drawer_fragment_state()
		return

	if drawer_closed_texture:
		drawer_texture_rect.texture = drawer_closed_texture

	if _is_local_detective():
		drawer_instruction_label.text = "Tap the lock to inspect it."
		drawer_lock_hotspot.visible = true
		drawer_lock_hotspot.disabled = false
	else:
		drawer_instruction_label.text = "Only the Detective can inspect this lock."
		drawer_lock_hotspot.visible = false
		drawer_lock_hotspot.disabled = true

	if key_fragment_hotspot:
		key_fragment_hotspot.visible = false
		key_fragment_hotspot.disabled = true


func _on_drawer_lock_hotspot_pressed() -> void:
	if _dialogue_input_locked:
		return
	
	if _drawer_unlocked:
		return

	if not _is_local_detective():
		_show_notification("Only the Detective can inspect this lock.")
		return

	_open_drawer_lock_panel()


func _open_drawer_lock_panel() -> void:
	drawer_panel.visible = false
	drawer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	dimmer.visible = true
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP

	drawer_lock_panel.visible = true
	drawer_lock_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_refresh_drawer_lock_panel_state()


func _close_drawer_lock_panel() -> void:
	drawer_lock_panel.visible = false
	drawer_lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_open_drawer_panel()


func _on_close_drawer_lock_button_pressed() -> void:
	_close_drawer_lock_panel()


func _refresh_drawer_lock_panel_state() -> void:
	if drawer_lock_zoom_texture:
		drawer_lock_texture_rect.texture = drawer_lock_zoom_texture
	elif drawer_closed_texture:
		drawer_lock_texture_rect.texture = drawer_closed_texture

	_refresh_drawer_digit_visuals()

	var allow_input := _is_local_detective() and not _drawer_unlocked

	digit_1_button.disabled = not allow_input
	digit_2_button.disabled = not allow_input
	digit_3_button.disabled = not allow_input

	if _drawer_unlocked:
		drawer_lock_instruction_label.text = "The drawer is unlocked."
	elif _is_local_detective():
		drawer_lock_instruction_label.text = "Tap each digit to enter the code."
	else:
		drawer_lock_instruction_label.text = "Wait for the Detective to enter the code."


func _setup_drawer_lock_digits() -> void:
	if lock_digit_textures.size() < 10:
		push_warning("[AbandonedHouse] Please assign 10 lock digit textures in order 0 to 9.")
		return

	for button in [digit_1_button, digit_2_button, digit_3_button]:
		if button == null:
			continue

		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.focus_mode = Control.FOCUS_NONE

	_refresh_drawer_digit_visuals()


func _refresh_drawer_digit_visuals() -> void:
	_set_digit_button_texture(digit_1_button, _drawer_digits[0])
	_set_digit_button_texture(digit_2_button, _drawer_digits[1])
	_set_digit_button_texture(digit_3_button, _drawer_digits[2])


func _set_digit_button_texture(button: TextureButton, digit_value: int) -> void:
	if button == null:
		return

	if digit_value < 0 or digit_value >= lock_digit_textures.size():
		return

	var tex: Texture2D = lock_digit_textures[digit_value]
	button.texture_normal = tex
	button.texture_pressed = tex
	button.texture_hover = tex
	button.texture_disabled = tex


func _on_drawer_digit_pressed(index: int) -> void:
	if _drawer_unlocked:
		return

	if not _is_local_detective():
		_show_notification("Only the Detective can change the lock code.")
		return

	var next_value: int = (_drawer_digits[index] + 1) % 10

	if multiplayer.has_multiplayer_peer():
		_sync_drawer_digit_changed_rpc.rpc(index, next_value)
	else:
		_apply_drawer_digit_changed(index, next_value)


@rpc("any_peer", "reliable", "call_local")
func _sync_drawer_digit_changed_rpc(index: int, value: int) -> void:
	_apply_drawer_digit_changed(index, value)


func _apply_drawer_digit_changed(index: int, value: int) -> void:
	if index < 0 or index > 2:
		return

	if _drawer_unlocked:
		return

	_drawer_digits[index] = clampi(value, 0, 9)
	_refresh_drawer_digit_visuals()

	if _is_correct_drawer_code():
		if multiplayer.has_multiplayer_peer():
			_sync_drawer_unlocked_rpc.rpc()
		else:
			_apply_drawer_unlocked()


func _is_correct_drawer_code() -> bool:
	return (
		_drawer_digits.size() == 3
		and _drawer_digits[0] == DRAWER_CORRECT_CODE[0]
		and _drawer_digits[1] == DRAWER_CORRECT_CODE[1]
		and _drawer_digits[2] == DRAWER_CORRECT_CODE[2]
	)


@rpc("any_peer", "reliable", "call_local")
func _sync_drawer_unlocked_rpc() -> void:
	_apply_drawer_unlocked()


func _apply_drawer_unlocked() -> void:
	if _drawer_unlocked:
		return

	_drawer_unlocked = true
	_drawer_digits = [
	DRAWER_CORRECT_CODE[0],
	DRAWER_CORRECT_CODE[1],
	DRAWER_CORRECT_CODE[2]
	]

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(DRAWER_PUZZLE_ID, true)

	_refresh_drawer_digit_visuals()
	_refresh_drawer_panel_state()
	_refresh_drawer_lock_panel_state()
	_refresh_progress_tracker()

	_show_notification("The drawer unlocked.")

	# If the player is currently viewing the lock panel,
	# return them to the drawer panel so they can see it open.
	if drawer_lock_panel.visible:
		drawer_lock_panel.visible = false
		drawer_lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		drawer_panel.visible = true
		drawer_panel.mouse_filter = Control.MOUSE_FILTER_STOP

		dimmer.visible = true
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP

func _has_key_fragment_3() -> bool:
	return GameState and GameState.has_method("has_zone_item") and GameState.has_zone_item(ZONE_ID, "key_fragment_3")


func _refresh_drawer_fragment_state() -> void:
	var should_show := _drawer_unlocked and not _has_key_fragment_3()

	if key_fragment_image:
		key_fragment_image.visible = should_show

	if key_fragment_hotspot:
		key_fragment_hotspot.visible = should_show
		key_fragment_hotspot.disabled = not should_show or not _is_local_detective()

func _on_key_fragment_hotspot_pressed() -> void:
	if _dialogue_input_locked:
		return
	
	if not _drawer_unlocked:
		return

	if _has_key_fragment_3():
		return

	if not _is_local_detective():
		_show_notification("Only the Detective can inspect this fragment.")
		return

	if multiplayer.has_multiplayer_peer():
		_show_drawer_reward_panel_rpc.rpc()
	else:
		_show_drawer_reward_panel()


@rpc("any_peer", "reliable", "call_local")
func _show_drawer_reward_panel_rpc() -> void:
	_show_drawer_reward_panel()


func _show_drawer_reward_panel() -> void:
	if _has_key_fragment_3():
		return

	_pending_reward_items.clear()
	_pending_reward_items.append_array(DRAWER_REWARD_ITEMS)

	reward_title_label.text = "Item Found"
	reward_body_label.text = "You found Key Fragment 3."

	reward_items_row.visible = true

	key_item.visible = true
	card_item.visible = false

	key_texture_rect.visible = true
	card_texture_rect.visible = false

	if key_fragment_3_texture:
		key_texture_rect.texture = key_fragment_3_texture

	collect_reward_button.text = "Collect Clue"
	collect_reward_button.visible = _is_local_sidekick()

	reward_dimmer.visible = true
	reward_panel.visible = true

	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _setup_cabinet_ui() -> void:
	if cabinet_puzzle_panel:
		cabinet_puzzle_panel.visible = false
		cabinet_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _load_cabinet_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_cabinet_opened = GameState.is_puzzle_solved(CABINET_PUZZLE_ID)
	else:
		_cabinet_opened = false


func _on_cabinet_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _dialogue_input_locked:
		return
	
	if drawer_panel.visible or drawer_lock_panel.visible:
		return
	if not _is_primary_press_event(event):
		return
	_open_cabinet_panel()


func _open_cabinet_panel() -> void:
	_close_books_panel()
	_close_memory_panel()
	_close_mirror_panel()
	_hide_drawer_ui()

	dimmer.visible = true
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP

	cabinet_puzzle_panel.visible = true
	cabinet_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_refresh_cabinet_panel_state()


func _close_cabinet_panel() -> void:
	cabinet_puzzle_panel.visible = false
	cabinet_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not books_puzzle_panel.visible \
	and not memory_puzzle_panel.visible \
	and not mirror_puzzle_panel.visible \
	and not drawer_panel.visible \
	and not drawer_lock_panel.visible \
	and not cabinet_puzzle_panel.visible:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_close_cabinet_button_pressed() -> void:
	_close_cabinet_panel()


func _refresh_cabinet_panel_state() -> void:
	if final_box_hotspot:
		final_box_hotspot.visible = _cabinet_opened
		final_box_hotspot.disabled = not _cabinet_opened
	
	if _cabinet_opened:
		if cabinet_opened_texture:
			cabinet_texture_rect.texture = cabinet_opened_texture

		cabinet_instruction_label.text = "The cabinet is open."
		cabinet_lock_hotspot.visible = false
		cabinet_lock_hotspot.disabled = true
	else:
		if cabinet_closed_texture:
			cabinet_texture_rect.texture = cabinet_closed_texture

		if _is_local_sidekick():
			cabinet_instruction_label.text = "Tap the cabinet lock."
			cabinet_lock_hotspot.visible = true
			cabinet_lock_hotspot.disabled = false
		else:
			cabinet_instruction_label.text = "Wait for the Sidekick to open the cabinet."
			cabinet_lock_hotspot.visible = false
			cabinet_lock_hotspot.disabled = true


func _on_cabinet_lock_hotspot_pressed() -> void:
	if _cabinet_opened:
		return

	if not _is_local_sidekick():
		return

	if not inside_zone_control or not inside_zone_control.has_method("consume_armed_item"):
		return

	var used: bool = inside_zone_control.consume_armed_item(CABINET_KEY_ITEM_ID)
	if not used:
		cabinet_instruction_label.text = "Open the briefcase, select the Key, press Use, then tap the cabinet lock."
		_show_notification("Use the key on the cabinet lock.")
		return

	if multiplayer.has_multiplayer_peer():
		_sync_cabinet_opened_rpc.rpc()
	else:
		_apply_cabinet_opened()


@rpc("any_peer", "reliable", "call_local")
func _sync_cabinet_opened_rpc() -> void:
	_apply_cabinet_opened()


func _apply_cabinet_opened() -> void:
	if _cabinet_opened:
		return

	_cabinet_opened = true

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(CABINET_PUZZLE_ID, true)

	_refresh_progress_tracker()
	_refresh_cabinet_panel_state()
	_show_notification("The cabinet opened.")

func _hide_drawer_ui() -> void:
	if drawer_panel:
		drawer_panel.visible = false
		drawer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if drawer_lock_panel:
		drawer_lock_panel.visible = false
		drawer_lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_final_box_ui() -> void:
	if final_box_panel:
		final_box_panel.visible = false
		final_box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if final_box_hotspot:
		final_box_hotspot.visible = false
		final_box_hotspot.disabled = true

	if answer_input:
		answer_input.text = ""
		answer_input.placeholder_text = "Enter Missing Number"
		answer_input.max_length = 3
	
	if tiara_image:
		tiara_image.visible = false
		tiara_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tiara_hotspot:
		tiara_hotspot.visible = false
		tiara_hotspot.disabled = true
	
func _load_final_box_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_final_box_opened = GameState.is_puzzle_solved(FINAL_BOX_PUZZLE_ID)
	else:
		_final_box_opened = false


func _load_final_box_data() -> void:
	_final_box_data = _get_final_box_variation_data()


func _get_final_box_variation_data() -> Dictionary:
	if not PuzzleManager:
		push_warning("[AbandonedHouse] PuzzleManager not found.")
		return {}

	if not PuzzleManager.PUZZLE_DATA.has("abandoned_house"):
		push_warning("[AbandonedHouse] No abandoned_house data in PuzzleManager.")
		return {}

	var zone_data: Dictionary = PuzzleManager.PUZZLE_DATA["abandoned_house"]
	var variations: Array = zone_data.get("variations", [])

	if variations.is_empty():
		push_warning("[AbandonedHouse] No abandoned_house variations found.")
		return {}

	var variation_index := 0
	if GameState and GameState.has_method("get_puzzle_variation_index"):
		variation_index = GameState.get_puzzle_variation_index("abandoned_house", variations.size())

	variation_index = clampi(variation_index, 0, variations.size() - 1)
	return variations[variation_index]
	
func _on_final_box_hotspot_pressed() -> void:
	if _dialogue_input_locked:
		return
	
	if not _cabinet_opened:
		return

	_open_final_box_panel()


func _open_final_box_panel() -> void:
	_hide_cabinet_ui()

	dimmer.visible = true
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP

	final_box_panel.visible = true
	final_box_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_refresh_final_box_panel_state()


func _close_final_box_panel() -> void:
	final_box_panel.visible = false
	final_box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not books_puzzle_panel.visible \
	and not memory_puzzle_panel.visible \
	and not mirror_puzzle_panel.visible \
	and not drawer_panel.visible \
	and not drawer_lock_panel.visible \
	and not cabinet_puzzle_panel.visible \
	and not final_box_panel.visible:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_close_final_box_button_pressed() -> void:
	_close_final_box_panel()
	
func _refresh_final_box_panel_state() -> void:
	if _final_box_opened:
		if final_box_opened_texture:
			final_box_texture_rect.texture = final_box_opened_texture

		final_box_instruction_label.text = "The box is open."

		if detective_pattern_label:
			detective_pattern_label.visible = false

		if sidekick_input_row:
			sidekick_input_row.visible = false
	else:
		if final_box_closed_texture:
			final_box_texture_rect.texture = final_box_closed_texture

		if _is_local_detective():
			final_box_instruction_label.text = "Read the number pattern to your partner."
			if detective_pattern_label:
				detective_pattern_label.visible = true
				detective_pattern_label.text = str(_final_box_data.get("display", ""))
			if sidekick_input_row:
				sidekick_input_row.visible = false
		else:
			final_box_instruction_label.text = "Enter the missing number."
			if detective_pattern_label:
				detective_pattern_label.visible = false
			if sidekick_input_row:
				sidekick_input_row.visible = true

	_refresh_final_box_clue_state()
			
func _on_submit_final_box_answer_pressed() -> void:
	if _final_box_opened:
		return

	if not _is_local_sidekick():
		return

	if answer_input == null:
		return

	if _final_box_data.is_empty():
		_show_notification("Puzzle data not ready yet.")
		return

	var raw_answer := answer_input.text.strip_edges()

	if raw_answer.is_empty() or not raw_answer.is_valid_int():
		_show_notification("Numbers only.")
		return

	var submitted_answer := int(raw_answer)
	var correct_answer := int(_final_box_data.get("solution", -999999))

	print("[FinalBox] submitted =", submitted_answer, " correct =", correct_answer)

	if submitted_answer != correct_answer:
		_show_notification("That’s not the right answer yet. Try again.")
		return

	if multiplayer.has_multiplayer_peer():
		_sync_final_box_opened_rpc.rpc()
	else:
		_apply_final_box_opened()
		
@rpc("any_peer", "reliable", "call_local")
func _sync_final_box_opened_rpc() -> void:
	_apply_final_box_opened()


func _apply_final_box_opened() -> void:
	if _final_box_opened:
		return

	_final_box_opened = true

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(FINAL_BOX_PUZZLE_ID, true)

	_refresh_progress_tracker()
	_refresh_final_box_panel_state()
	_show_notification("The box opened.")

func _get_abandoned_house_variations() -> Array:
	if not PuzzleManager:
		push_warning("[AbandonedHouse] PuzzleManager missing.")
		return []

	if not PuzzleManager.PUZZLE_DATA.has("abandoned_house"):
		push_warning("[AbandonedHouse] No abandoned_house puzzle data.")
		return []

	return PuzzleManager.PUZZLE_DATA["abandoned_house"].get("variations", [])

func _prepare_final_box_variation() -> void:
	var variations := _get_abandoned_house_variations()
	if variations.is_empty():
		return

	# Single-player fallback
	if not multiplayer.has_multiplayer_peer():
		var local_index := GameState.get_puzzle_variation_index("abandoned_house", variations.size())
		_apply_final_box_variation(local_index)
		return

	# Multiplayer: host chooses once, everyone receives the same index
	if multiplayer.is_server():
		var host_index := GameState.get_puzzle_variation_index("abandoned_house", variations.size())
		_sync_final_box_variation_rpc.rpc(host_index)
		
@rpc("any_peer", "reliable", "call_local")
func _sync_final_box_variation_rpc(variation_index: int) -> void:
	_apply_final_box_variation(variation_index)

func _apply_final_box_variation(variation_index: int) -> void:
	var variations := _get_abandoned_house_variations()
	if variations.is_empty():
		return

	_final_box_variation_index = clampi(variation_index, 0, variations.size() - 1)
	_final_box_data = (variations[_final_box_variation_index] as Dictionary).duplicate(true)

	print("[FinalBox] variation_index =", _final_box_variation_index)
	print("[FinalBox] display =", _final_box_data.get("display", ""))
	print("[FinalBox] solution =", _final_box_data.get("solution", -1))

func _hide_cabinet_ui() -> void:
	if cabinet_puzzle_panel:
		cabinet_puzzle_panel.visible = false
		cabinet_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _has_tiara_clue() -> bool:
	return GameState and GameState.has_method("has_zone_item") and GameState.has_zone_item(ZONE_ID, "pinas_tiara")


func _refresh_final_box_clue_state() -> void:
	var should_show := _final_box_opened and not _has_tiara_clue()

	if tiara_image:
		tiara_image.visible = should_show

	if tiara_hotspot:
		tiara_hotspot.visible = should_show
		tiara_hotspot.disabled = not should_show or not _is_local_sidekick()
		
func _on_tiara_hotspot_pressed() -> void:
	if _dialogue_input_locked:
		return
	
	if not _final_box_opened:
		return

	if _has_tiara_clue():
		return

	if not _is_local_sidekick():
		return

	if multiplayer.has_multiplayer_peer():
		rpc_show_tiara_reward.rpc()
	else:
		rpc_show_tiara_reward()


@rpc("any_peer", "reliable", "call_local")
func _show_tiara_reward_panel_rpc() -> void:
	_show_tiara_reward_panel()


func _show_tiara_reward_panel() -> void:
	if _has_tiara_clue():
		return

	_pending_reward_items.clear()
	_pending_reward_items.append_array(FINAL_BOX_REWARD_ITEMS)

	reward_title_label.text = "Clue Found"
	reward_body_label.text = "You found Pina's Tiara."

	reward_items_row.visible = true

	key_item.visible = true
	card_item.visible = false

	key_texture_rect.visible = true
	card_texture_rect.visible = false

	if tiara_clue_texture:
		key_texture_rect.texture = tiara_clue_texture

	collect_reward_button.text = "Collect Clue"
	collect_reward_button.visible = _is_local_sidekick()

	reward_dimmer.visible = true
	reward_panel.visible = true

	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _setup_tiara_reward_layer() -> void:
	if cinematic_reward_layer:
		cinematic_reward_layer.visible = false

	if cinematic_dark_overlay:
		cinematic_dark_overlay.visible = true
		cinematic_dark_overlay.modulate.a = 0.0

	if cinematic_clue_sprite:
		cinematic_clue_sprite.visible = false
		if tiara_clue_texture:
			cinematic_clue_sprite.texture = tiara_clue_texture

	if cinematic_banner_label:
		cinematic_banner_label.visible = false
		cinematic_banner_label.text = ""

	if cinematic_reward_panel:
		cinematic_reward_panel.visible = false

	if cinematic_reward_text:
		cinematic_reward_text.text = ""

	if cinematic_tap_instruction:
		cinematic_tap_instruction.visible = false
		cinematic_tap_instruction.text = ""

	if cinematic_collect_button:
		cinematic_collect_button.visible = false
		cinematic_collect_button.disabled = true

	if cinematic_tap_catcher:
		cinematic_tap_catcher.visible = false
		cinematic_tap_catcher.disabled = true

	if cinematic_briefcase_reveal:
		cinematic_briefcase_reveal.visible = false
		cinematic_briefcase_reveal.texture = null

	if cinematic_sparkle:
		cinematic_sparkle.visible = false
		cinematic_sparkle.scale = Vector2(TIARA_SPARKLE_MIN_SCALE, TIARA_SPARKLE_MIN_SCALE)
		
@rpc("any_peer", "reliable", "call_local")
func rpc_show_tiara_reward() -> void:
	if _tiara_reward_active:
		return

	_tiara_reward_active = true
	_tiara_waiting_continue = true
	_tiara_reward_stage = 1
	_tiara_collect_sequence_started = false

	# hide final box panel while cinematic reward is active
	if final_box_panel:
		final_box_panel.visible = false
		final_box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if cinematic_reward_layer:
		cinematic_reward_layer.visible = true

	if cinematic_dark_overlay:
		cinematic_dark_overlay.modulate.a = 0.45

	if cinematic_clue_sprite:
		cinematic_clue_sprite.visible = true
		if tiara_clue_texture:
			cinematic_clue_sprite.texture = tiara_clue_texture

	if cinematic_sparkle:
		cinematic_sparkle.visible = true
		cinematic_sparkle.scale = Vector2(TIARA_SPARKLE_MIN_SCALE, TIARA_SPARKLE_MIN_SCALE)
		_tiara_animation_time = 0.0
		_tiara_sparkle_animating = true

	if cinematic_banner_label:
		cinematic_banner_label.visible = true
		cinematic_banner_label.text = "CLUE FOUND!"

	if cinematic_reward_text:
		cinematic_reward_text.text = ""

	if cinematic_reward_panel:
		cinematic_reward_panel.visible = false

	if cinematic_tap_instruction:
		cinematic_tap_instruction.visible = true
		cinematic_tap_instruction.text = "Tap anywhere to continue."

	if cinematic_tap_catcher:
		cinematic_tap_catcher.visible = true
		cinematic_tap_catcher.disabled = false

	if cinematic_collect_button:
		cinematic_collect_button.visible = false
		cinematic_collect_button.disabled = true

	if cinematic_briefcase_reveal:
		cinematic_briefcase_reveal.visible = false
		cinematic_briefcase_reveal.texture = null
		
func _show_tiara_reward_stage_text(text: String) -> void:
	if cinematic_reward_panel:
		cinematic_reward_panel.visible = true
	if cinematic_reward_text:
		cinematic_reward_text.text = text
	if cinematic_tap_instruction:
		cinematic_tap_instruction.visible = true
		cinematic_tap_instruction.text = "Tap anywhere to continue."
		
func _on_tiara_tap_catcher_pressed() -> void:
	if not _tiara_waiting_continue:
		return

	match _tiara_reward_stage:
		1:
			_tiara_reward_stage = 2
			_show_tiara_reward_stage_text("Pina was treated like a princess at home.")
		2:
			_tiara_reward_stage = 3
			_show_tiara_reward_stage_text("The tiara shows how she was admired,")
		3:
			_tiara_reward_stage = 4
			_show_tiara_reward_stage_text("but she was not taught to help herself.")
		4:
			_tiara_reward_stage = 5
			_show_tiara_reward_stage_text("This clue reveals how Pina lived inside the house.")
		5:
			_tiara_reward_stage = 6
			_tiara_waiting_continue = false

			if cinematic_tap_instruction:
				cinematic_tap_instruction.visible = false
				cinematic_tap_instruction.text = ""

			if cinematic_tap_catcher:
				cinematic_tap_catcher.visible = false
				cinematic_tap_catcher.disabled = true

			if cinematic_reward_panel:
				cinematic_reward_panel.visible = false

			if cinematic_reward_text:
				cinematic_reward_text.text = ""

			if cinematic_collect_button:
				cinematic_collect_button.visible = _is_local_sidekick()
				cinematic_collect_button.disabled = not _is_local_sidekick()
				
func _on_tiara_collect_pressed() -> void:
	if _tiara_collect_sequence_started:
		return

	_tiara_collect_sequence_started = true

	if cinematic_collect_button:
		cinematic_collect_button.visible = false
		cinematic_collect_button.disabled = true

	if multiplayer.has_multiplayer_peer():
		rpc_show_tiara_briefcase_reveal_then_finalize.rpc()
	else:
		rpc_show_tiara_briefcase_reveal_then_finalize()
		
func _hide_tiara_reward_visuals_for_briefcase() -> void:
	_tiara_sparkle_animating = false

	if cinematic_sparkle:
		cinematic_sparkle.visible = false
		cinematic_sparkle.scale = Vector2(TIARA_SPARKLE_MIN_SCALE, TIARA_SPARKLE_MIN_SCALE)

	if cinematic_clue_sprite:
		cinematic_clue_sprite.visible = false

	if cinematic_banner_label:
		cinematic_banner_label.visible = false
		cinematic_banner_label.text = ""

	if cinematic_reward_panel:
		cinematic_reward_panel.visible = false

	if cinematic_reward_text:
		cinematic_reward_text.text = ""

	if cinematic_tap_instruction:
		cinematic_tap_instruction.visible = false
		cinematic_tap_instruction.text = ""

	if cinematic_tap_catcher:
		cinematic_tap_catcher.visible = false
		cinematic_tap_catcher.disabled = true

	if cinematic_collect_button:
		cinematic_collect_button.visible = false
		cinematic_collect_button.disabled = true
		
func _show_tiara_briefcase_reveal_local() -> void:
	if not cinematic_briefcase_reveal:
		return

	var reveal_texture: Texture2D = GameState.get_briefcase_texture("abandoned_house")
	cinematic_briefcase_reveal.texture = reveal_texture
	cinematic_briefcase_reveal.visible = reveal_texture != null
	cinematic_briefcase_reveal.modulate = Color(1, 1, 1, 1)
	
@rpc("any_peer", "reliable", "call_local")
func rpc_show_tiara_briefcase_reveal_then_finalize() -> void:
	_hide_tiara_reward_visuals_for_briefcase()
	_show_tiara_briefcase_reveal_local()

	await get_tree().create_timer(1.5).timeout

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			rpc_finalize_tiara_clue.rpc()
	else:
		rpc_finalize_tiara_clue()
		
@rpc("any_peer", "reliable", "call_local")
func rpc_finalize_tiara_clue() -> void:
	# grant the tiara clue
	if GameState and GameState.has_method("grant_zone_items"):
		GameState.grant_zone_items(ZONE_ID, TIARA_REWARD_ITEMS)

	# mark the whole abandoned house zone as solved
	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(ZONE_ID, true)

	_tiara_reward_active = false
	_tiara_waiting_continue = false
	_tiara_collect_sequence_started = false
	_tiara_sparkle_animating = false

	if cinematic_sparkle:
		cinematic_sparkle.visible = false

	if cinematic_clue_sprite:
		cinematic_clue_sprite.visible = false

	if cinematic_banner_label:
		cinematic_banner_label.visible = false
		cinematic_banner_label.text = ""

	if cinematic_reward_panel:
		cinematic_reward_panel.visible = false

	if cinematic_reward_text:
		cinematic_reward_text.text = ""

	if cinematic_tap_instruction:
		cinematic_tap_instruction.visible = false
		cinematic_tap_instruction.text = ""

	if cinematic_tap_catcher:
		cinematic_tap_catcher.visible = false
		cinematic_tap_catcher.disabled = true

	if cinematic_collect_button:
		cinematic_collect_button.visible = false
		cinematic_collect_button.disabled = true

	if cinematic_briefcase_reveal:
		cinematic_briefcase_reveal.visible = false
		cinematic_briefcase_reveal.texture = null

	if cinematic_reward_layer:
		cinematic_reward_layer.visible = false

	# safety: hide any open abandoned-house panels too
	if final_box_panel:
		final_box_panel.visible = false
		final_box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if cabinet_puzzle_panel:
		cabinet_puzzle_panel.visible = false
		cabinet_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if drawer_panel:
		drawer_panel.visible = false
		drawer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if drawer_lock_panel:
		drawer_lock_panel.visible = false
		drawer_lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if mirror_puzzle_panel:
		mirror_puzzle_panel.visible = false
		mirror_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if memory_puzzle_panel:
		memory_puzzle_panel.visible = false
		memory_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if books_puzzle_panel:
		books_puzzle_panel.visible = false
		books_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if dimmer:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_refresh_final_box_clue_state()
	_return_to_forest()
	
func _process(delta: float) -> void:
	if _tiara_sparkle_animating and cinematic_sparkle and cinematic_sparkle.visible:
		_tiara_animation_time += delta
		var pulse: float = (sin(_tiara_animation_time * TIARA_SPARKLE_PULSE_SPEED) + 1.0) / 2.0
		var target_scale: float = lerpf(TIARA_SPARKLE_MIN_SCALE, TIARA_SPARKLE_MAX_SCALE, pulse)
		cinematic_sparkle.scale = Vector2(target_scale, target_scale)

func _return_to_forest() -> void:
	get_tree().paused = false
	MusicController.resume_music()
	get_tree().change_scene_to_file(SCENE_FOREST_HUB)

func _set_dialogue_input_lock(locked: bool) -> void:
	_dialogue_input_locked = locked

	# Keep exit/back usable if you want.
	if is_instance_valid(back_button):
		back_button.disabled = false

	# Lock sidekick utility buttons during dialogue.
	if is_instance_valid(inside_zone_control):
		if inside_zone_control.has_method("set_pause_enabled"):
			inside_zone_control.set_pause_enabled(true)
		if inside_zone_control.has_method("set_ledger_enabled"):
			inside_zone_control.set_ledger_enabled(not locked and GameState.local_role == GameState.Role.SIDEKICK)
		if inside_zone_control.has_method("set_briefcase_enabled"):
			inside_zone_control.set_briefcase_enabled(not locked and GameState.local_role == GameState.Role.SIDEKICK)


func _start_intro_dialogue_delayed() -> void:
	if _intro_dialogue_played:
		return

	_intro_dialogue_played = true
	_run_intro_sequence()


func _get_abandoned_house_intro_dialogue() -> Array[Dictionary]:
	return [
		{
			"speaker": "detective",
			"text": "This looks like Pina's room."
		},
		{
			"speaker": "sidekick",
			"text": "It's neat... but it feels quiet. Like nobody has stayed here for a long time."
		},
		{
			"speaker": "detective",
			"text": "Then this room may still be hiding clues about her."
		},
		{
			"speaker": "sidekick",
			"text": "Let's search carefully. Everything here might mean something."
		}
	]


func _run_intro_sequence() -> void:
	_set_dialogue_input_lock(true)
	DialogueSystem.play("abandoned_house_intro", _get_abandoned_house_intro_dialogue())
	await DialogueSystem.wait_finished("abandoned_house_intro")
	_set_dialogue_input_lock(false)
	_show_books_hint()

func _show_books_hint() -> void:
	if multiplayer.has_multiplayer_peer():
		_rpc_show_books_hint.rpc()
	else:
		_apply_show_books_hint()


func _hide_books_hint() -> void:
	if multiplayer.has_multiplayer_peer():
		_rpc_hide_books_hint.rpc()
	else:
		_apply_hide_books_hint()
		
@rpc("any_peer", "reliable", "call_local")
func _rpc_show_books_hint() -> void:
	_apply_show_books_hint()


@rpc("any_peer", "reliable", "call_local")
func _rpc_hide_books_hint() -> void:
	_apply_hide_books_hint()

func _apply_show_books_hint() -> void:
	if not books_hint_marker:
		return

	if _books_hint_tween:
		_books_hint_tween.kill()

	books_hint_marker.visible = true
	books_hint_marker.modulate = Color(1, 1, 1, 1)
	books_hint_marker.scale = _books_hint_original_scale

	_books_hint_tween = create_tween()
	_books_hint_tween.set_loops()
	_books_hint_tween.tween_property(
		books_hint_marker,
		"scale",
		_books_hint_original_scale * 1.08,
		0.5
	)
	_books_hint_tween.tween_property(
		books_hint_marker,
		"scale",
		_books_hint_original_scale,
		0.5
	)


func _apply_hide_books_hint() -> void:
	if not books_hint_marker:
		return

	if _books_hint_tween:
		_books_hint_tween.kill()
		_books_hint_tween = null

	books_hint_marker.visible = false
	books_hint_marker.scale = _books_hint_original_scale

func _setup_books_hint() -> void:
	if not books_hint_marker:
		return

	_books_hint_original_scale = books_hint_marker.scale
	books_hint_marker.visible = false
	books_hint_marker.modulate = Color(1, 1, 1, 1)

func _setup_progress_tracker() -> void:
	if not progress_tracker_sprite:
		return

	if progress_default_texture:
		progress_tracker_sprite.texture = progress_default_texture


func _refresh_progress_tracker() -> void:
	if not progress_tracker_sprite:
		return

	var next_texture: Texture2D = progress_default_texture

	if GameState and GameState.has_method("is_puzzle_solved"):
		# Highest completed state wins
		if GameState.is_puzzle_solved(FINAL_BOX_PUZZLE_ID):
			next_texture = progress_5_texture
		elif GameState.is_puzzle_solved(CABINET_PUZZLE_ID):
			next_texture = progress_4_texture
		elif GameState.is_puzzle_solved(DRAWER_PUZZLE_ID):
			next_texture = progress_3_texture
		elif GameState.is_puzzle_solved(MEMORY_PUZZLE_ID):
			next_texture = progress_2_texture
		else:
			# Books solved still stays on defaultProgress.png
			next_texture = progress_default_texture

	if next_texture:
		progress_tracker_sprite.texture = next_texture
