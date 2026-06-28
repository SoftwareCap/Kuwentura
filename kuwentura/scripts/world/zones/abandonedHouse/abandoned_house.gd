##abandoned_house.gd
extends Node2D

const FOREST_HUB_SCENE_PATH := "res://scenes/world/hub/ForestHub.tscn"
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const LEDGER_IMAGE_PATH := "res://assets/sprites/ledger/abandonedhouse_instructions.png"

const ZONE_ID := "abandoned_house"
const SUB_PUZZLE_ID := "abandoned_house_books"

const BOOK_ORDER_TOP_TO_BOTTOM := ["book_4", "book_3", "book_2", "book_1"]
const BOOK_START_ORDER := ["book_2", "book_4", "book_1", "book_3"]
const REWARD_ITEMS := ["key_fragment_1", "card_piece"]

const MEMORY_PUZZLE_ID := "abandoned_house_memory"
const MEMORY_FACE_IDS := ["face_1", "face_2", "face_3", "face_4", "face_5", "face_6"]
const MEMORY_REWARD_ITEMS := ["key_fragment_2", "light_bulb"]
const DRAWER_REWARD_ITEMS := ["key_fragment_3"]
const ZONE_COMPLETION_SFX: AudioStream = preload("res://assets/audios/ZoneCompletionSFX.mp3")
const SERVER_PEER_ID := 1

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
@export var assembled_key_texture: Texture2D

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
@onready var close_cabinet_button: TouchScreenButton = $PuzzleCanvasLayer/Dimmer/CabinetPuzzlePanel/MarginContainer/VBoxContainer/BottomBar/CloseCabinetButton

@onready var drawer_area: Area2D = $InteractiveLayer/DrawerArea

@onready var key_fragment_image: TextureRect = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/DrawerHolder/KeyFragmentImage
@onready var key_fragment_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/DrawerHolder/KeyFragmentHotspot

@onready var drawer_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/DrawerPanel
@onready var drawer_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var drawer_texture_rect: TextureRect = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/DrawerHolder/DrawerTexture
@onready var drawer_lock_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/DrawerHolder/DrawerLockHotspot
@onready var close_drawer_button: TouchScreenButton = $PuzzleCanvasLayer/Dimmer/DrawerPanel/MarginContainer/VBoxContainer/BottomBar/CloseDrawerButton

@onready var drawer_lock_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel
@onready var drawer_lock_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var drawer_lock_texture_rect: TextureRect = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/LockHolder/DrawerLockTexture
@onready var digit_1_button: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/LockHolder/Digit1
@onready var digit_2_button: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/LockHolder/Digit2
@onready var digit_3_button: TextureButton = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/LockHolder/Digit3
@onready var close_drawer_lock_button: TouchScreenButton = $PuzzleCanvasLayer/Dimmer/DrawerLockPanel/MarginContainer/VBoxContainer/BottomBar/CloseDrawerLockButton

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
@onready var close_mirror_button: TouchScreenButton = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel/MarginContainer/VBoxContainer/CloseMirrorButton

@onready var inside_zone_control: CanvasLayer = $InsideZoneControl
@onready var pause_canvas_layer: CanvasLayer = get_node_or_null("PauseCanvasLayer")
@onready var in_game_pause_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel")
@onready var option_sub_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel")
@onready var volume_slider: HSlider = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider")
@onready var volume_value_label: Label = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue")
@onready var sidekick_layer: CanvasLayer = get_node_or_null("SidekickLayer")
@onready var ledger_panel: Panel = get_node_or_null("SidekickLayer/Ledger")
@onready var ledger_title_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerTitle")
@onready var ledger_body_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerBody")
@onready var ledger_left_header_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerLeftHeader")
@onready var ledger_left_body_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerLeftBody")
@onready var ledger_right_header_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerRightHeader")
@onready var ledger_right_body_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerRightBody")
var _ledger_instruction_image: TextureRect = null
@onready var sidekick_briefcase_panel: Panel = get_node_or_null("SidekickLayer/Briefcase")
@onready var inventory_board: Node2D = get_node_or_null("InventoryBoard") as Node2D
@onready var inventory_board_sprite: Sprite2D = get_node_or_null("InventoryBoard/Board") as Sprite2D
@onready var inventory_area: Area2D = get_node_or_null("InventoryBoard/Area2D") as Area2D

@onready var puzzle_area: Area2D = $InteractiveLayer/PuzzleArea

@onready var memory_puzzle_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel
@onready var memory_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var missing_card_preview: TextureRect = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/MissingRow/MissingCardPreview
@onready var memory_grid: GridContainer = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/MemoryGrid
@onready var close_memory_button: Button = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/CloseMemoryButton
@onready var missing_row: HBoxContainer = get_node_or_null("PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/MissingRow")

@onready var role_label: Label = get_node_or_null("RoleLabel") as Label
@onready var detective_player: Node2D = get_node_or_null("Players/Detective")
@onready var sidekick_player: Node2D = get_node_or_null("Players/Sidekick")
@onready var ending_cutscene: VideoStreamPlayer = $Cutscene/EndingCutscene
var _ending_cutscene_resolved := false
@onready var back_button: Button = get_node_or_null("BackButton") as Button
@onready var notification_label: Label = $Notification/NotificationLabel

@onready var books_area: Area2D = $InteractiveLayer/BooksArea

@onready var dimmer: ColorRect = $PuzzleCanvasLayer/Dimmer
@onready var books_puzzle_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel
@onready var instruction_label: Label = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel/MarginContainer/Puzzle/BookPuzzleInstruction
@onready var puzzle_board: Control = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel/MarginContainer/Puzzle/PuzzleBoard
@onready var close_puzzle_button: TouchScreenButton = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel/MarginContainer/Puzzle/ClosePuzzleButton

@onready var reward_canvas_layer: CanvasLayer = $RewardCanvasLayer
@onready var reward_dimmer: ColorRect = $RewardCanvasLayer/RewardDimmer
@onready var reward_panel: Panel = $RewardCanvasLayer/Panel
@onready var reward_title_label: Label = $RewardCanvasLayer/Panel/Reward/RewardTitleLabel
@onready var reward_body_label: Label = $RewardCanvasLayer/Panel/Reward/RewardBodyLabel
@onready var collect_reward_button: Button = $RewardCanvasLayer/Panel/Reward/CollectClueButton

@onready var reward_vbox: VBoxContainer = $RewardCanvasLayer/Panel/Reward
@onready var reward_items_row: HBoxContainer = $RewardCanvasLayer/Panel/Reward/RewardItemsRow
@onready var key_item: Control = $RewardCanvasLayer/Panel/Reward/RewardItemsRow/KeyTexture
@onready var key_texture_rect: TextureRect = $RewardCanvasLayer/Panel/Reward/RewardItemsRow/KeyTexture
@onready var card_item: Control = $RewardCanvasLayer/Panel/Reward/RewardItemsRow/CardTexture
@onready var card_texture_rect: TextureRect = $RewardCanvasLayer/Panel/Reward/RewardItemsRow/CardTexture
@onready var collect_clue_button: Button = $RewardCanvasLayer/Panel/Reward/CollectClueButton

const FINAL_BOX_PUZZLE_ID := "abandoned_house_final_box_opened"

@export var final_box_closed_texture: Texture2D
@export var final_box_opened_texture: Texture2D

@onready var final_box_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/CabinetPuzzlePanel/MarginContainer/VBoxContainer/CabinetHolder/FinalBoxHotspot

@onready var final_box_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel
@onready var final_box_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var final_box_holder: Control = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder
@onready var final_box_texture_rect: TextureRect = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/BoxTexture
@onready var detective_pattern_label: Label = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/DetectivePatternLabel
@onready var sidekick_input_row: VBoxContainer = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/SidekickInputRow
@onready var answer_input: LineEdit = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/SidekickInputRow/AnswerInput
@onready var submit_answer_button: Button = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BoxHolder/SidekickInputRow/SubmitAnswerButton
@onready var close_final_box_button: TouchScreenButton = $PuzzleCanvasLayer/Dimmer/FinalBoxPanel/MarginContainer/VBoxContainer/BottomBar/CloseFinalBoxButton

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

@onready var progress_tracker_sprite: Sprite2D = $ProgressTracker/TiaraTracker


@onready var quest_layer: Node2D = get_node_or_null("Quest")
@onready var quest_title_label: Label = get_node_or_null("Quest/QuestTitle")
@onready var quest_books_label: Label = get_node_or_null("Quest/BooksPuzzle")
@onready var quest_memory_label: Label = get_node_or_null("Quest/MemoryPuzzle")
@onready var quest_mirror_label: Label = get_node_or_null("Quest/MirrorPuzzle")
@onready var quest_drawer_label: Label = get_node_or_null("Quest/DrawerLockPuzzle")
@onready var quest_cabinet_label: Label = get_node_or_null("Quest/CabinetPuzzle")
@onready var quest_treasure_label: Label = get_node_or_null("Quest/TreasureboxPuzzle")


const TIARA_SPARKLE_MIN_SCALE := 0.45
const TIARA_SPARKLE_MAX_SCALE := 0.55
const TIARA_SPARKLE_PULSE_SPEED := 4.0
const QUEST_PANEL_POS := Vector2(22, 108)
const QUEST_PANEL_WIDTH := 390.0
const QUEST_HEADER_HEIGHT := 34.0
const QUEST_ROW_HEIGHT := 33.0
const QUEST_ROW_GAP := 5.0
const QUEST_TEXT_LEFT_PADDING := 12.0
const QUEST_DONE_ALPHA := 0.45
const UI_BROWN := Color(0.55, 0.31, 0.12, 1.0)
const UI_BROWN_DARK := Color(0.30, 0.15, 0.05, 1.0)
const UI_BROWN_HOVER := Color(0.65, 0.39, 0.17, 1.0)
const UI_CREAM := Color(1.0, 0.90, 0.72, 1.0)
const UI_DIM_PANEL := Color(0.02, 0.015, 0.01, 0.76)
const UI_QUEST_DONE := Color(0.72, 0.68, 0.61, 1.0)


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

const INVENTORY_SLOT_ITEM_ORDER := [
	"key_fragment_1",
	"card_piece",
	"key_fragment_2",
	"light_bulb",
	"key_fragment_3",
	"assembled_key"
]

const INVENTORY_ITEM_NAMES := {
	"key_fragment_1": "Key Fragment 1",
	"card_piece": "Card Piece",
	"key_fragment_2": "Key Fragment 2",
	"light_bulb": "Lighter",
	"key_fragment_3": "Key Fragment 3",
	"assembled_key": "Key"
}
const INVENTORY_DISPLAY_PRIORITY := [
	"key_fragment_1",
	"card_piece",
	"key_fragment_2",
	"light_bulb",
	"key_fragment_3"
]

var _armed_inventory_item: String = ""
var _inventory_icon_nodes: Dictionary = {}
var _inventory_display_items: Array[String] = []
var _inventory_slot_highlight: Panel
var _inventory_block_label: Label
var _inventory_block_tween: Tween
var _armed_inventory_slot_index: int = -1

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

var _quest_style_ready: bool = false
var _quest_labels: Array = []
var _quest_row_backgrounds: Array = []
var _quest_toggle_button: Button
var _quest_expanded: bool = false
var _quest_active_index: int = 0
var _sfx_player: AudioStreamPlayer
var _final_box_role_card: Panel
var _final_box_role_title_label: Label
var _final_box_role_hint_label: Label
var _ending_cutscene_transition_active := false
var _ending_cutscene_return_sent := false
var _ending_cutscene_finished_peers: Dictionary = {}

func _get_drawer_correct_code() -> Array[int]:
	return [
		DRAWER_CORRECT_CODE[0],
		DRAWER_CORRECT_CODE[1],
		DRAWER_CORRECT_CODE[2]
	]

func _make_flat_style(fill_color: Color, border_color: Color = Color.TRANSPARENT, radius: int = 10, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _style_brown_button(button: Button, minimum_size: Vector2 = Vector2(180, 46)) -> void:
	if not is_instance_valid(button):
		return

	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", UI_CREAM)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.42))
	button.add_theme_stylebox_override("normal", _make_flat_style(UI_BROWN, UI_CREAM, 11, 2))
	button.add_theme_stylebox_override("hover", _make_flat_style(UI_BROWN_HOVER, UI_CREAM, 11, 2))
	button.add_theme_stylebox_override("pressed", _make_flat_style(UI_BROWN_DARK, UI_CREAM, 11, 2))
	button.add_theme_stylebox_override("disabled", _make_flat_style(Color(0.28, 0.22, 0.17, 0.82), Color(0.75, 0.65, 0.52, 0.55), 11, 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_abandoned_house_buttons() -> void:
	_style_brown_button(back_button, Vector2(160, 42))
	_style_brown_button(close_memory_button, Vector2(170, 42))
	_style_brown_button(collect_reward_button, Vector2(210, 46))
	_style_brown_button(submit_answer_button, Vector2(190, 46))
	_style_brown_button(cinematic_collect_button, Vector2(240, 58))


func _ensure_sfx_bus() -> void:
	var sfx_bus_index := AudioServer.get_bus_index("SFX")
	if sfx_bus_index != -1:
		return

	AudioServer.add_bus(AudioServer.bus_count)
	var last_bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(last_bus_index, "SFX")
	AudioServer.set_bus_volume_db(last_bus_index, 0.0)


func _play_zone_completion_sfx() -> void:
	if not is_instance_valid(_sfx_player) or ZONE_COMPLETION_SFX == null:
		return

	MusicController.pause_music()
	_sfx_player.stream = ZONE_COMPLETION_SFX
	_sfx_player.play()
	if not _sfx_player.finished.is_connected(_on_sfx_finished_resume_music):
		_sfx_player.finished.connect(_on_sfx_finished_resume_music, CONNECT_ONE_SHOT)


func _on_sfx_finished_resume_music() -> void:
	MusicController.resume_music()


func _spawn_confetti(parent_node: Node, amount: int = 52) -> void:
	if not is_instance_valid(parent_node):
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var colors: Array[Color] = [
		Color(1.0, 0.78, 0.22, 1.0),
		Color(0.95, 0.38, 0.25, 1.0),
		Color(0.35, 0.78, 0.42, 1.0),
		Color(0.36, 0.65, 1.0, 1.0),
		Color(1.0, 0.92, 0.62, 1.0)
	]

	for i in range(amount):
		var piece := ColorRect.new()
		var color_index: int = randi() % colors.size()
		piece.name = "ConfettiPiece"
		piece.color = colors[color_index]
		piece.size = Vector2(randf_range(7.0, 13.0), randf_range(12.0, 22.0))
		piece.position = Vector2(randf_range(0.0, viewport_size.x), randf_range(-110.0, -15.0))
		piece.rotation = randf_range(-0.9, 0.9)
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.z_index = 500
		parent_node.add_child(piece)

		var fall_duration: float = randf_range(1.6, 2.45)
		var end_position := piece.position + Vector2(
			randf_range(-120.0, 120.0),
			viewport_size.y + randf_range(100.0, 220.0)
		)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "position", end_position, fall_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(piece, "rotation", piece.rotation + randf_range(3.0, 7.0), fall_duration)
		tween.tween_property(piece, "modulate:a", 0.0, 0.35).set_delay(maxf(0.1, fall_duration - 0.35))
		tween.finished.connect(piece.queue_free)


func _setup_quest_panel_style() -> void:
	if not is_instance_valid(quest_layer):
		return

	var labels: Array[Label] = [
		quest_books_label,
		quest_memory_label,
		quest_mirror_label,
		quest_drawer_label,
		quest_cabinet_label,
		quest_treasure_label
	]

	_quest_labels.clear()
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
		quest_title_label.text = "ABANDONED HOUSE QUEST"
		quest_title_label.position = QUEST_PANEL_POS + Vector2(10, 0)
		quest_title_label.size = Vector2(QUEST_PANEL_WIDTH - 20.0, QUEST_HEADER_HEIGHT)
		quest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		quest_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quest_title_label.add_theme_font_size_override("font_size", 15)
		quest_title_label.add_theme_color_override("font_color", Color.WHITE)
		quest_title_label.add_theme_constant_override("outline_size", 2)
		quest_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
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
	_quest_toggle_button.z_index = 10
	_quest_toggle_button.self_modulate = Color(1, 1, 1, 0)
	if not _quest_toggle_button.pressed.is_connected(_on_quest_header_pressed):
		_quest_toggle_button.pressed.connect(_on_quest_header_pressed)

	for i in range(labels.size()):
		var label := labels[i] as Label
		if not is_instance_valid(label):
			continue

		var row_pos := QUEST_PANEL_POS + Vector2(
			0,
			QUEST_HEADER_HEIGHT + 8.0 + float(i) * (QUEST_ROW_HEIGHT + QUEST_ROW_GAP)
		)

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

		label.position = row_pos + Vector2(QUEST_TEXT_LEFT_PADDING, 0)
		label.size = Vector2(QUEST_PANEL_WIDTH - (QUEST_TEXT_LEFT_PADDING * 2.0), QUEST_ROW_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = false
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.z_index = 2

		_quest_labels.append(label)
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

	var label := _quest_labels[index] as Label
	if not is_instance_valid(label):
		return

	var row_bg: ColorRect = null
	if index < _quest_row_backgrounds.size():
		row_bg = _quest_row_backgrounds[index] as ColorRect
	var row_visible: bool = _quest_expanded or active
	var visible_row_index: int = index if _quest_expanded else 0
	var row_pos := _get_quest_row_position(visible_row_index)

	label.text = text
	label.set_meta("quest_done", done)
	label.visible = row_visible
	label.position = row_pos + Vector2(QUEST_TEXT_LEFT_PADDING, 0.0)
	label.size = Vector2(QUEST_PANEL_WIDTH - (QUEST_TEXT_LEFT_PADDING * 2.0), QUEST_ROW_HEIGHT)
	label.add_theme_font_size_override("font_size", 15 if active and not done else 14)
	label.add_theme_color_override("font_color", UI_QUEST_DONE if done else Color.WHITE)
	label.modulate = Color(1, 1, 1, QUEST_DONE_ALPHA) if done else Color.WHITE

	if is_instance_valid(row_bg):
		row_bg.visible = row_visible
		row_bg.position = row_pos
		row_bg.size = Vector2(QUEST_PANEL_WIDTH, QUEST_ROW_HEIGHT)
		if done:
			row_bg.color = Color(0.02, 0.018, 0.014, 0.48)
		elif active:
			row_bg.color = Color(0.02, 0.014, 0.008, 0.82)
		else:
			row_bg.color = UI_DIM_PANEL


func _is_game_state_puzzle_solved(puzzle_id: String) -> bool:
	return GameState and GameState.has_method("is_puzzle_solved") and GameState.is_puzzle_solved(puzzle_id)


func _update_quest_labels() -> void:
	if not _quest_style_ready:
		_setup_quest_panel_style()

	var books_done := _books_solved or _is_game_state_puzzle_solved(SUB_PUZZLE_ID) or _is_game_state_puzzle_solved(BOOKS_PUZZLE_ID)
	var memory_done := _memory_solved or _is_game_state_puzzle_solved(MEMORY_PUZZLE_ID)
	var mirror_done := _mirror_lit or _is_game_state_puzzle_solved(MIRROR_PUZZLE_ID)
	var drawer_done := _drawer_unlocked or _is_game_state_puzzle_solved(DRAWER_PUZZLE_ID)
	var cabinet_done := _cabinet_opened or _is_game_state_puzzle_solved(CABINET_PUZZLE_ID)
	var treasure_done := _final_box_opened or _is_game_state_puzzle_solved(FINAL_BOX_PUZZLE_ID) or (GameState and GameState.has_method("has_clue") and GameState.has_clue(ZONE_ID))

	var tasks: Array[String] = [
		"Arrange the books",
		"Complete the memory cards",
		"Light the mirror",
		"Unlock the drawer",
		"Open the cabinet",
		"Open the treasure box"
	]
	var done_states: Array[bool] = [
		books_done,
		memory_done,
		mirror_done,
		drawer_done,
		cabinet_done,
		treasure_done
	]

	var previous_active_index: int = _quest_active_index
	_quest_active_index = done_states.find(false)
	if _quest_active_index == -1:
		_quest_active_index = done_states.size() - 1

	for i in range(tasks.size()):
		_set_quest_task(i, tasks[i], done_states[i], i == _quest_active_index)

	if previous_active_index != _quest_active_index and not _quest_expanded:
		_animate_current_quest_task()


func _animate_current_quest_task() -> void:
	if _quest_active_index < 0 or _quest_active_index >= _quest_labels.size():
		return

	var label := _quest_labels[_quest_active_index] as Label
	if not is_instance_valid(label) or not label.visible:
		return

	var start_position := label.position
	var target_modulate := Color(1, 1, 1, QUEST_DONE_ALPHA) if bool(label.get_meta("quest_done", false)) else Color.WHITE
	label.position = start_position + Vector2(18.0, 0.0)
	label.modulate = Color(1, 1, 1, 0.35)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", start_position, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", target_modulate, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
	_setup_quest_panel_style()
	_update_quest_labels()
	_setup_inventory_board()
	_ensure_sfx_bus()
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)
	
	await get_tree().process_frame
	_resize_books_popup()
	_prepare_books()
	_start_intro_dialogue_delayed()
	
	# Hide players until intro dialogue ends
	if is_instance_valid(detective_player):
		detective_player.visible = false
	if is_instance_valid(sidekick_player):
		sidekick_player.visible = false
	
	if is_instance_valid(ending_cutscene):
		CutsceneHelper.prepare_mobile_video_player(ending_cutscene)
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

	var cutscene_dark: Node = get_node_or_null("Cutscene/DarkOverlay")
	if is_instance_valid(cutscene_dark):
		cutscene_dark.visible = false
	
	if key_fragment_image:
		key_fragment_image.visible = false

	if key_fragment_hotspot:
		key_fragment_hotspot.visible = false
		key_fragment_hotspot.disabled = true
		
	if books_hint_marker:
		books_hint_marker.visible = false

func _setup_ui() -> void:
	if is_instance_valid(quest_layer):
		quest_layer.visible = false

	if has_node("TestLabel"):
		$TestLabel.visible = false

	if notification_label:
		notification_label.visible = false

	if is_instance_valid(sidekick_layer):
		sidekick_layer.visible = true
	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false
	if is_instance_valid(sidekick_briefcase_panel):
		sidekick_briefcase_panel.visible = false
	_populate_ledger_content()

	instruction_label.text = "Drag the books to arrange them by width.\nNarrowest should be on top and widest should be at the bottom."

	dimmer.visible = false
	dimmer.color = Color.BLACK
	books_puzzle_panel.visible = false
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	books_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if reward_canvas_layer:
		reward_canvas_layer.visible = false
		reward_canvas_layer.layer = 80

	reward_dimmer.visible = false
	reward_dimmer.color = Color.BLACK
	reward_panel.visible = false
	reward_items_row.visible = false
	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_abandoned_house_buttons()

func _center_reward_panel() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	# Make the dark overlay cover the whole screen.
	if reward_dimmer:
		reward_dimmer.anchor_left = 0.0
		reward_dimmer.anchor_top = 0.0
		reward_dimmer.anchor_right = 1.0
		reward_dimmer.anchor_bottom = 1.0
		reward_dimmer.offset_left = 0.0
		reward_dimmer.offset_top = 0.0
		reward_dimmer.offset_right = 0.0
		reward_dimmer.offset_bottom = 0.0

	# Actual popup size.
	var panel_width: float = clampf(viewport_size.x * 0.44, 520.0, 700.0)
	var panel_height: float = clampf(viewport_size.y * 0.52, 360.0, 450.0)
	var panel_size := Vector2(panel_width, panel_height)

	# IMPORTANT:
	# Do not use PRESET_CENTER here.
	# Use top-left anchors, then manually place the panel in the center.
	if reward_panel:
		reward_panel.anchor_left = 0.0
		reward_panel.anchor_top = 0.0
		reward_panel.anchor_right = 0.0
		reward_panel.anchor_bottom = 0.0

		reward_panel.offset_left = 0.0
		reward_panel.offset_top = 0.0
		reward_panel.offset_right = 0.0
		reward_panel.offset_bottom = 0.0

		reward_panel.size = panel_size
		reward_panel.position = (viewport_size - panel_size) * 0.5
		reward_panel.z_index = 100

	# Make the VBox fill the centered panel.
	if reward_vbox:
		reward_vbox.anchor_left = 0.0
		reward_vbox.anchor_top = 0.0
		reward_vbox.anchor_right = 1.0
		reward_vbox.anchor_bottom = 1.0

		reward_vbox.offset_left = 30.0
		reward_vbox.offset_top = 24.0
		reward_vbox.offset_right = -30.0
		reward_vbox.offset_bottom = -24.0

		reward_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_vbox.add_theme_constant_override("separation", 18)

	if reward_title_label:
		reward_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reward_title_label.custom_minimum_size = Vector2(0, 54)
		reward_title_label.add_theme_font_size_override("font_size", 34)

	if reward_body_label:
		reward_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reward_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reward_body_label.custom_minimum_size = Vector2(0, 68)
		reward_body_label.add_theme_font_size_override("font_size", 22)

	if reward_items_row:
		reward_items_row.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_items_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reward_items_row.custom_minimum_size = Vector2(0, 146)

	if collect_reward_button:
		collect_reward_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _setup_reward_preview() -> void:
	_center_reward_panel()

	reward_items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_items_row.add_theme_constant_override("separation", 24)

	key_item.custom_minimum_size = Vector2(150, 130)
	card_item.custom_minimum_size = Vector2(150, 130)

	key_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	key_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_fit_reward_texture(key_texture_rect, Vector2(124, 92))
	_fit_reward_texture(card_texture_rect, Vector2(124, 124))

	if key_fragment_1_texture:
		key_texture_rect.texture = _make_cropped_key_texture(key_fragment_1_texture)

	if card_piece_texture:
		card_texture_rect.texture = card_piece_texture
		
		


func _connect_signals() -> void:
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
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

	# Lets the mirror close when the player taps outside the mirror image.
	# We connect both the dark dimmer and the mirror panel because either one can receive the tap.
	if dimmer and not dimmer.gui_input.is_connected(_on_puzzle_dimmer_gui_input):
		dimmer.gui_input.connect(_on_puzzle_dimmer_gui_input)

	if mirror_puzzle_panel and not mirror_puzzle_panel.gui_input.is_connected(_on_mirror_panel_gui_input):
		mirror_puzzle_panel.gui_input.connect(_on_mirror_panel_gui_input)

	if not lamp_hotspot.pressed.is_connected(_on_lamp_hotspot_pressed):
		lamp_hotspot.pressed.connect(_on_lamp_hotspot_pressed)
		
	if not drawer_area.input_event.is_connected(_on_drawer_area_input_event):
		drawer_area.input_event.connect(_on_drawer_area_input_event)

	if not close_drawer_button.pressed.is_connected(_on_close_drawer_button_pressed):
		close_drawer_button.pressed.connect(_on_close_drawer_button_pressed)

	if drawer_panel and not drawer_panel.gui_input.is_connected(_on_drawer_panel_gui_input):
		drawer_panel.gui_input.connect(_on_drawer_panel_gui_input)

	if drawer_lock_panel and not drawer_lock_panel.gui_input.is_connected(_on_drawer_lock_panel_gui_input):
		drawer_lock_panel.gui_input.connect(_on_drawer_lock_panel_gui_input)

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

	if cabinet_puzzle_panel and not cabinet_puzzle_panel.gui_input.is_connected(_on_cabinet_panel_gui_input):
		cabinet_puzzle_panel.gui_input.connect(_on_cabinet_panel_gui_input)

	if not cabinet_lock_hotspot.pressed.is_connected(_on_cabinet_lock_hotspot_pressed):
		cabinet_lock_hotspot.pressed.connect(_on_cabinet_lock_hotspot_pressed)
	
	if final_box_hotspot and not final_box_hotspot.pressed.is_connected(_on_final_box_hotspot_pressed):
		final_box_hotspot.pressed.connect(_on_final_box_hotspot_pressed)

	if close_final_box_button and not close_final_box_button.pressed.is_connected(_on_close_final_box_button_pressed):
		close_final_box_button.pressed.connect(_on_close_final_box_button_pressed)

	if submit_answer_button and not submit_answer_button.pressed.is_connected(_on_submit_final_box_answer_pressed):
		submit_answer_button.pressed.connect(_on_submit_final_box_answer_pressed)

	if final_box_panel and not final_box_panel.gui_input.is_connected(_on_final_box_panel_gui_input):
		final_box_panel.gui_input.connect(_on_final_box_panel_gui_input)
	
	if tiara_hotspot and not tiara_hotspot.pressed.is_connected(_on_tiara_hotspot_pressed):
		tiara_hotspot.pressed.connect(_on_tiara_hotspot_pressed)

	if cinematic_collect_button and not cinematic_collect_button.pressed.is_connected(_on_tiara_collect_pressed):
		cinematic_collect_button.pressed.connect(_on_tiara_collect_pressed)

	if cinematic_tap_catcher and not cinematic_tap_catcher.pressed.is_connected(_on_tiara_tap_catcher_pressed):
		cinematic_tap_catcher.pressed.connect(_on_tiara_tap_catcher_pressed)

	if inside_zone_control and inside_zone_control.has_signal("pause_pressed") and not inside_zone_control.pause_pressed.is_connected(_on_pause_button_pressed):
		inside_zone_control.pause_pressed.connect(_on_pause_button_pressed)

	if inside_zone_control and inside_zone_control.has_signal("ledger_pressed") and not inside_zone_control.ledger_pressed.is_connected(_on_ledger_pressed):
		inside_zone_control.ledger_pressed.connect(_on_ledger_pressed)

	var resume_btn: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton")
	if is_instance_valid(resume_btn) and not resume_btn.pressed.is_connected(_on_resume_play_button_pressed):
		resume_btn.pressed.connect(_on_resume_play_button_pressed)

	var option_btn: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionButton")
	if is_instance_valid(option_btn) and not option_btn.pressed.is_connected(_on_option_button_pressed):
		option_btn.pressed.connect(_on_option_button_pressed)

	var exit_btn: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/ExitButton")
	if is_instance_valid(exit_btn) and not exit_btn.pressed.is_connected(_on_exit_to_main_menu_button_pressed):
		exit_btn.pressed.connect(_on_exit_to_main_menu_button_pressed)

	var pause_back_btn: TouchScreenButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/BackToPrevious")
	if is_instance_valid(pause_back_btn) and not pause_back_btn.pressed.is_connected(_on_in_game_option_back_pressed):
		pause_back_btn.pressed.connect(_on_in_game_option_back_pressed)

	if is_instance_valid(volume_slider) and not volume_slider.value_changed.is_connected(_on_in_game_volume_changed):
		volume_slider.value_changed.connect(_on_in_game_volume_changed)
		
func _refresh_role_label() -> void:
	var role_text := "Unknown"

	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"

	if role_label:
		role_label.text = "Role: " + role_text

	if inside_zone_control and inside_zone_control.has_method("set_sidekick_ui_visible"):
		inside_zone_control.set_sidekick_ui_visible(_is_local_sidekick())

	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false

	_refresh_inventory_interaction_state()


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
	if not is_instance_valid(instruction_label):
		return

	instruction_label.visible = not _books_solved
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_label.add_theme_constant_override("outline_size", 4)
	instruction_label.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.03, 0.95))
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _is_local_detective():
		instruction_label.text = "Drag the books to arrange them by width.\nNarrowest should be on top and widest should be at the bottom."
	else:
		instruction_label.text = "Only the Detective can move the books."

	# ClosePuzzleButton is a TouchScreenButton image, so no text update is needed.

func _open_books_panel() -> void:
	if multiplayer.has_multiplayer_peer():
		_sync_books_panel_visible_rpc.rpc(true)
	else:
		_apply_books_panel_visibility(true)
	_refresh_books_panel_for_role()
	await get_tree().process_frame
	_resize_books_popup()
	await get_tree().process_frame
	_layout_books()


func _close_books_panel() -> void:
	if _drag_book_id != "":
		_finish_drag()

	if multiplayer.has_multiplayer_peer():
		_sync_books_panel_visible_rpc.rpc(false)
	else:
		_apply_books_panel_visibility(false)


func _close_books_panel_local_only() -> void:
	if _drag_book_id != "":
		_finish_drag()

	_apply_books_panel_visibility(false)


@rpc("any_peer", "reliable", "call_local")
func _sync_books_panel_visible_rpc(visible_state: bool) -> void:
	_apply_books_panel_visibility(visible_state)


func _apply_books_panel_visibility(visible_state: bool) -> void:
	dimmer.visible = visible_state
	books_puzzle_panel.visible = visible_state

	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE
	books_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE

	if visible_state:
		_refresh_books_view_state()
		_refresh_books_panel_for_role()
		call_deferred("_finalize_books_panel_open")


func _finalize_books_panel_open() -> void:
	if not is_instance_valid(books_puzzle_panel) or not books_puzzle_panel.visible:
		return

	_resize_books_popup()
	_layout_books()


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
		# Skip cutscene
	if is_instance_valid(ending_cutscene) and ending_cutscene.visible:
		var skip := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
		skip = skip or (event is InputEventScreenTouch and event.pressed)
		if skip:
			_on_cutscene_finished()
			return

	# existing mirror tap-close logic
	if _try_close_mirror_from_tap(event):
		return
		
	# Keep this here so taps are detected even when a Control node does not pass gui_input.
	if _try_close_mirror_from_tap(event):
		return

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
	# We only grant them after the Sidekick presses the reward button.

	_close_books_panel()
	_update_quest_labels()
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

func _show_reward_panel(title: String, body: String, item_ids: Array, texture_1: Texture2D = null, texture_2: Texture2D = null) -> void:
	_pending_reward_items.clear()
	_pending_reward_items.append_array(item_ids)

	# Force the whole reward canvas to show above the puzzle canvas.
	# This fixes the issue where the puzzle closes but the reward UI does not appear.
	if reward_canvas_layer:
		reward_canvas_layer.visible = true
		reward_canvas_layer.layer = 80
		
	_center_reward_panel()

	reward_title_label.text = title
	reward_body_label.text = body

	reward_items_row.visible = true

	key_item.visible = texture_1 != null
	key_texture_rect.visible = texture_1 != null
	if texture_1:
		key_texture_rect.texture = texture_1

	card_item.visible = texture_2 != null
	card_texture_rect.visible = texture_2 != null
	if texture_2:
		card_texture_rect.texture = texture_2

	collect_reward_button.text = "Collect Reward"
	collect_reward_button.visible = _is_local_sidekick()
	collect_reward_button.disabled = not _is_local_sidekick()

	reward_dimmer.visible = true
	reward_panel.visible = true
	
	_center_reward_panel()

	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_play_zone_completion_sfx()
	_spawn_confetti(reward_canvas_layer, 56)


func _show_books_reward_panel() -> void:
	_show_reward_panel(
		"Puzzle Solved",
		"You found Key Fragment 1 and the Card Piece.",
		REWARD_ITEMS,
		_make_cropped_key_texture(key_fragment_1_texture) if key_fragment_1_texture else null,
		card_piece_texture
	)


func _hide_reward_panel() -> void:
	_pending_reward_items.clear()

	if reward_canvas_layer:
		reward_canvas_layer.visible = false

	reward_dimmer.visible = false
	reward_panel.visible = false
	reward_items_row.visible = false
	collect_reward_button.visible = false
	collect_reward_button.disabled = true

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

	_refresh_inventory_board()
	_hide_reward_panel()

	# refresh drawer UI in case key_fragment_3 was just collected
	if item_ids.has("key_fragment_3"):
		_refresh_drawer_panel_state()
		if _has_inventory_item("key_fragment_1") and _has_inventory_item("key_fragment_2") and _has_inventory_item("key_fragment_3"):
			_show_notification("Tap any key fragment to combine them into the key.")
		
	if item_ids.has("pinas_tiara"):
		if GameState and GameState.has_method("has_clue") and GameState.has_method("collect_clue"):
			if not GameState.has_clue(ZONE_ID):
				GameState.collect_clue(ZONE_ID)

		if GameState and GameState.has_method("set_puzzle_solved"):
			GameState.set_puzzle_solved(ZONE_ID, true)

		_refresh_final_box_clue_state()
		_return_to_forest()

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
		if notification_label:
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
	GameState.change_to_post_zone_scene(get_tree())


func _on_pause_button_pressed() -> void:
	if is_instance_valid(pause_canvas_layer):
		pause_canvas_layer.visible = true
		pause_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		_set_pause_process_mode_recursive(pause_canvas_layer)
	if is_instance_valid(in_game_pause_panel):
		in_game_pause_panel.visible = true
	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = false
	if is_instance_valid(inside_zone_control):
		inside_zone_control.visible = false
	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false
	MusicController.pause_music()
	get_tree().paused = true


func _on_resume_play_button_pressed() -> void:
	if is_instance_valid(in_game_pause_panel):
		in_game_pause_panel.visible = false
	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = false
	if is_instance_valid(pause_canvas_layer):
		pause_canvas_layer.visible = false
	get_tree().paused = false
	MusicController.resume_music()
	if is_instance_valid(inside_zone_control):
		inside_zone_control.visible = true


func _on_option_button_pressed() -> void:
	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = true
	_sync_volume_ui()


func _on_in_game_option_back_pressed() -> void:
	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = false


func _on_exit_to_main_menu_button_pressed() -> void:
	if is_instance_valid(pause_canvas_layer):
		pause_canvas_layer.visible = false
	get_tree().paused = false
	MusicController.resume_music()
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _sync_volume_ui() -> void:
	if not is_instance_valid(volume_slider):
		return
	var percent := 80.0
	if MusicController.has_method("get_volume"):
		percent = float(MusicController.get_volume()) * 100.0
	volume_slider.value = percent
	if is_instance_valid(volume_value_label):
		volume_value_label.text = str(int(percent)) + "%"


func _on_in_game_volume_changed(value: float) -> void:
	if MusicController.has_method("set_volume"):
		MusicController.set_volume(value / 100.0)
	if is_instance_valid(volume_value_label):
		volume_value_label.text = str(int(value)) + "%"


func _set_pause_process_mode_recursive(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	for child in node.get_children():
		_set_pause_process_mode_recursive(child)


func _populate_ledger_content() -> void:
	for label in [ledger_title_label, ledger_body_label, ledger_left_header_label, ledger_left_body_label, ledger_right_header_label, ledger_right_body_label]:
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

func _on_ledger_pressed() -> void:
	if _dialogue_input_locked or not _is_local_sidekick() or not is_instance_valid(ledger_panel):
		return

	_populate_ledger_content()
	if is_instance_valid(sidekick_briefcase_panel):
		sidekick_briefcase_panel.visible = false
	ledger_panel.visible = not ledger_panel.visible


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

	memory_instruction_label.text = "Tap the Card Piece on the Inventory Board, then tap the empty slot."

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
	_grant_items_for_memory_completion()
	_refresh_progress_tracker()
	_update_quest_labels()
	_start_tiara_reward_sequence()
	_show_notification("Card puzzle solved.")

func _grant_items_for_memory_completion() -> void:
	if GameState and GameState.has_method("grant_zone_items"):
		GameState.grant_zone_items(ZONE_ID, MEMORY_REWARD_ITEMS)

	_refresh_inventory_board()

func _start_tiara_reward_sequence() -> void:
	if _has_tiara_clue() or _tiara_reward_active:
		return

	rpc_show_tiara_reward()

func _show_memory_reward_panel() -> void:
	_show_reward_panel(
		"Puzzle Solved",
		"You found Key Fragment 2 and the Lighter.",
		MEMORY_REWARD_ITEMS,
		key_fragment_2_texture,
		lighter_texture
	)


func _on_missing_slot_pressed() -> void:
	if _memory_unlocked or _memory_solved:
		return

	if not _is_local_sidekick():
		return

	var used: bool = _consume_armed_inventory_item("card_piece")
	if not used:
		_show_notification("Tap the Card Piece on the Inventory Board first.")
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


func _on_puzzle_dimmer_gui_input(event: InputEvent) -> void:
	if not _is_primary_press_event(event):
		return

	if _try_close_mirror_from_tap(event):
		return

	if _close_active_focus_panel_from_backdrop():
		get_viewport().set_input_as_handled()


func _on_mirror_panel_gui_input(event: InputEvent) -> void:
	_try_close_mirror_from_tap(event)


func _on_drawer_panel_gui_input(event: InputEvent) -> void:
	_try_close_drawer_from_tap(event)


func _on_drawer_lock_panel_gui_input(event: InputEvent) -> void:
	_try_close_drawer_lock_from_tap(event)


func _on_cabinet_panel_gui_input(event: InputEvent) -> void:
	_try_close_cabinet_from_tap(event)


func _on_final_box_panel_gui_input(event: InputEvent) -> void:
	_try_close_final_box_from_tap(event)


func _close_active_focus_panel_from_backdrop() -> bool:
	if is_instance_valid(books_puzzle_panel) and books_puzzle_panel.visible:
		_close_books_panel_local_only()
		return true

	var closed_any := false

	if _drag_book_id != "":
		_finish_drag()

	var focus_panels: Array[Control] = [
		memory_puzzle_panel,
		drawer_panel,
		drawer_lock_panel,
		cabinet_puzzle_panel,
		final_box_panel
	]

	for panel in focus_panels:
		if is_instance_valid(panel) and panel.visible:
			panel.visible = false
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			closed_any = true

	if closed_any and is_instance_valid(dimmer):
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return closed_any


func _try_close_mirror_from_tap(event: InputEvent) -> bool:
	if not mirror_puzzle_panel or not mirror_puzzle_panel.visible:
		return false

	if not _is_primary_press_event(event):
		return false

	var tap_position: Vector2 = _get_event_position(event)

	# Keep the view open when the player taps the mirror image itself.
	# This fixes the earlier issue because checking MirrorPuzzlePanel was too wide.
	if mirror_texture_rect and mirror_texture_rect.get_global_rect().grow(8.0).has_point(tap_position):
		return false

	# The lamp hotspot is slightly outside the mirror image in the scene, so do not close
	# when the Sidekick taps the lamp to use the lighter.
	if lamp_hotspot and lamp_hotspot.visible and lamp_hotspot.get_global_rect().grow(8.0).has_point(tap_position):
		return false

	_close_mirror_panel()
	get_viewport().set_input_as_handled()
	return true


func _try_close_drawer_from_tap(event: InputEvent) -> bool:
	if not drawer_panel or not drawer_panel.visible:
		return false

	if not _is_primary_press_event(event):
		return false

	var tap_position: Vector2 = _get_event_position(event)

	if _is_drawer_lock_tap(tap_position):
		_on_drawer_lock_hotspot_pressed()
		get_viewport().set_input_as_handled()
		return true

	if key_fragment_hotspot and key_fragment_hotspot.visible and key_fragment_hotspot.get_global_rect().grow(8.0).has_point(tap_position):
		return false

	if drawer_texture_rect and drawer_texture_rect.get_global_rect().grow(8.0).has_point(tap_position):
		return false

	_close_drawer_panel()
	get_viewport().set_input_as_handled()
	return true


func _is_drawer_lock_tap(tap_position: Vector2) -> bool:
	if not is_instance_valid(drawer_lock_hotspot) or not drawer_lock_hotspot.visible or drawer_lock_hotspot.disabled:
		return false

	if drawer_lock_hotspot.get_global_rect().grow(28.0).has_point(tap_position):
		return true

	if is_instance_valid(drawer_texture_rect):
		var drawer_rect := drawer_texture_rect.get_global_rect()
		var visual_lock_rect := Rect2(
			drawer_rect.position + Vector2(drawer_rect.size.x * 0.08, drawer_rect.size.y * 0.35),
			Vector2(drawer_rect.size.x * 0.66, drawer_rect.size.y * 0.55)
		)
		if visual_lock_rect.has_point(tap_position):
			return true

	return false


func _control_contains_tap(control: Control, tap_position: Vector2, grow: float = 8.0) -> bool:
	return is_instance_valid(control) and control.visible and control.get_global_rect().grow(grow).has_point(tap_position)


func _try_close_drawer_lock_from_tap(event: InputEvent) -> bool:
	if not drawer_lock_panel or not drawer_lock_panel.visible:
		return false

	if not _is_primary_press_event(event):
		return false

	var tap_position: Vector2 = _get_event_position(event)

	if _control_contains_tap(drawer_lock_texture_rect, tap_position):
		return false

	if _control_contains_tap(digit_1_button, tap_position) or _control_contains_tap(digit_2_button, tap_position) or _control_contains_tap(digit_3_button, tap_position):
		return false

	_close_drawer_lock_panel()
	get_viewport().set_input_as_handled()
	return true


func _try_close_cabinet_from_tap(event: InputEvent) -> bool:
	if not cabinet_puzzle_panel or not cabinet_puzzle_panel.visible:
		return false

	if not _is_primary_press_event(event):
		return false

	var tap_position: Vector2 = _get_event_position(event)

	if _control_contains_tap(cabinet_texture_rect, tap_position):
		return false

	if _control_contains_tap(cabinet_lock_hotspot, tap_position) or _control_contains_tap(final_box_hotspot, tap_position):
		return false

	_close_cabinet_panel()
	get_viewport().set_input_as_handled()
	return true


func _try_close_final_box_from_tap(event: InputEvent) -> bool:
	if not final_box_panel or not final_box_panel.visible:
		return false

	if not _is_primary_press_event(event):
		return false

	var tap_position: Vector2 = _get_event_position(event)

	if _control_contains_tap(final_box_texture_rect, tap_position):
		return false

	if _control_contains_tap(_final_box_role_card, tap_position):
		return false

	if _control_contains_tap(answer_input, tap_position) or _control_contains_tap(submit_answer_button, tap_position):
		return false

	if _control_contains_tap(detective_pattern_label, tap_position) or _control_contains_tap(sidekick_input_row, tap_position):
		return false

	if _control_contains_tap(tiara_image, tap_position) or _control_contains_tap(tiara_hotspot, tap_position):
		return false

	_close_final_box_panel()
	get_viewport().set_input_as_handled()
	return true


func _on_mirror_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _dialogue_input_locked:
		return
	
	if not _is_primary_press_event(event):
		return

	_open_mirror_panel()


func _open_mirror_panel() -> void:
	_close_books_panel_local_only()
	_close_memory_panel()

	dimmer.visible = true
	mirror_puzzle_panel.visible = true

	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	mirror_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_refresh_mirror_panel_state()


func _close_mirror_panel() -> void:
	mirror_puzzle_panel.visible = false
	mirror_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var any_other_panel_open := (
		books_puzzle_panel.visible
		or memory_puzzle_panel.visible
		or drawer_panel.visible
		or drawer_lock_panel.visible
		or cabinet_puzzle_panel.visible
		or final_box_panel.visible
	)

	if not any_other_panel_open:
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

	var used: bool = _consume_armed_inventory_item("light_bulb")
	if not used:
		mirror_instruction_label.text = "Tap the Lighter on the Inventory Board, then tap the lamp."
		_show_notification("Select the Lighter first.")
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
	_update_quest_labels()
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

	if drawer_lock_hotspot:
		drawer_lock_hotspot.position = Vector2(350.0, 88.0)
		drawer_lock_hotspot.size = Vector2(430.0, 170.0)
		drawer_lock_hotspot.custom_minimum_size = Vector2(430.0, 170.0)
		drawer_lock_hotspot.focus_mode = Control.FOCUS_NONE
		drawer_lock_hotspot.ignore_texture_size = true
		drawer_lock_hotspot.stretch_mode = TextureButton.STRETCH_SCALE

	if drawer_lock_panel:
		drawer_lock_panel.visible = false
		drawer_lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _load_drawer_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_drawer_unlocked = GameState.is_puzzle_solved(DRAWER_PUZZLE_ID)
	else:
		_drawer_unlocked = false

	if _drawer_unlocked:
		_drawer_digits = _get_drawer_correct_code()
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
	_close_books_panel_local_only()
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
	_drawer_digits = _get_drawer_correct_code()

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(DRAWER_PUZZLE_ID, true)

	_refresh_drawer_digit_visuals()
	_refresh_drawer_panel_state()
	_refresh_drawer_lock_panel_state()
	_refresh_progress_tracker()
	_update_quest_labels()

	_show_notification("The drawer unlocked.")

	# New flow: after solving the drawer lock, show the reward panel immediately.
	# The Sidekick is the only one who can collect this reward.
	_hide_drawer_ui()
	if dimmer:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_show_drawer_reward_panel()

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

	_show_reward_panel(
		"Puzzle Solved",
		"You found Key Fragment 3.",
		DRAWER_REWARD_ITEMS,
		key_fragment_3_texture,
		null
	)


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
	_close_books_panel_local_only()
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

	var used: bool = _consume_armed_inventory_item(CABINET_KEY_ITEM_ID)
	if not used:
		cabinet_instruction_label.text = "Tap the Key on the Inventory Board, then tap the cabinet lock."
		_show_notification("Select the Key first.")
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
	_update_quest_labels()
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
		answer_input.placeholder_text = "_"
		answer_input.max_length = 3
		answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		answer_input.add_theme_font_size_override("font_size", 24)
		answer_input.add_theme_color_override("font_color", Color.WHITE)
		answer_input.add_theme_color_override("caret_color", UI_CREAM)
		answer_input.add_theme_color_override("font_placeholder_color", Color(1.0, 0.9, 0.62, 0.95))
		answer_input.add_theme_color_override("selection_color", Color(0.9, 0.68, 0.35, 0.55))
		answer_input.add_theme_stylebox_override("normal", _make_flat_style(Color(0.08, 0.055, 0.035, 0.78), UI_CREAM, 12, 2))
		answer_input.add_theme_stylebox_override("focus", _make_flat_style(Color(0.12, 0.075, 0.04, 0.92), Color(1.0, 0.78, 0.34, 1.0), 12, 3))
		answer_input.custom_minimum_size = Vector2(260, 54)
	
	if tiara_image:
		tiara_image.visible = false
		tiara_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tiara_hotspot:
		tiara_hotspot.visible = false
		tiara_hotspot.disabled = true

	_ensure_final_box_role_card()


func _ensure_final_box_role_card() -> void:
	if not is_instance_valid(final_box_holder):
		return

	_final_box_role_card = final_box_holder.get_node_or_null("RoleCard") as Panel
	if not is_instance_valid(_final_box_role_card):
		_final_box_role_card = Panel.new()
		_final_box_role_card.name = "RoleCard"
		final_box_holder.add_child(_final_box_role_card)

	_final_box_role_card.position = Vector2(370, 58)
	_final_box_role_card.size = Vector2(490, 192)
	_final_box_role_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final_box_role_card.z_index = 1
	_final_box_role_card.add_theme_stylebox_override("panel", _make_flat_style(Color(0.95, 0.92, 0.82, 0.96), Color(0.58, 0.37, 0.16, 1.0), 18, 3))

	_final_box_role_title_label = final_box_holder.get_node_or_null("RoleCardTitle") as Label
	if not is_instance_valid(_final_box_role_title_label):
		_final_box_role_title_label = Label.new()
		_final_box_role_title_label.name = "RoleCardTitle"
		final_box_holder.add_child(_final_box_role_title_label)

	_final_box_role_title_label.position = _final_box_role_card.position + Vector2(0, 12)
	_final_box_role_title_label.size = Vector2(_final_box_role_card.size.x, 24)
	_final_box_role_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_box_role_title_label.add_theme_font_size_override("font_size", 17)
	_final_box_role_title_label.add_theme_color_override("font_color", UI_BROWN_DARK)
	_final_box_role_title_label.add_theme_constant_override("outline_size", 1)
	_final_box_role_title_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.45))
	_final_box_role_title_label.z_index = 2

	_final_box_role_hint_label = final_box_holder.get_node_or_null("RoleCardHint") as Label
	if not is_instance_valid(_final_box_role_hint_label):
		_final_box_role_hint_label = Label.new()
		_final_box_role_hint_label.name = "RoleCardHint"
		final_box_holder.add_child(_final_box_role_hint_label)

	_final_box_role_hint_label.position = _final_box_role_card.position + Vector2(28, 150)
	_final_box_role_hint_label.size = Vector2(_final_box_role_card.size.x - 56.0, 32.0)
	_final_box_role_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_box_role_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_final_box_role_hint_label.add_theme_font_size_override("font_size", 15)
	_final_box_role_hint_label.add_theme_color_override("font_color", UI_BROWN_DARK)
	_final_box_role_hint_label.z_index = 2
	
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


func _format_final_box_display(display_text: String) -> String:
	var formatted := display_text.replace("□", "_")
	formatted = formatted.replace("â–¡", "_")
	formatted = formatted.replace("?", "_")
	return formatted
	
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
	if answer_input and not _final_box_opened:
		answer_input.text = ""

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
		final_box_texture_rect.modulate = Color(1, 1, 1, 0.22)

		if detective_pattern_label:
			detective_pattern_label.visible = false

		if sidekick_input_row:
			sidekick_input_row.visible = false
		if is_instance_valid(_final_box_role_card):
			_final_box_role_card.visible = false
		if is_instance_valid(_final_box_role_title_label):
			_final_box_role_title_label.visible = false
		if is_instance_valid(_final_box_role_hint_label):
			_final_box_role_hint_label.visible = false
	else:
		if final_box_closed_texture:
			final_box_texture_rect.texture = final_box_closed_texture
		final_box_texture_rect.modulate = Color(1, 1, 1, 0.28)

		if is_instance_valid(_final_box_role_card):
			_final_box_role_card.visible = false
		if is_instance_valid(_final_box_role_title_label):
			_final_box_role_title_label.visible = false
		if is_instance_valid(_final_box_role_hint_label):
			_final_box_role_hint_label.visible = false

		if _is_local_detective():
			final_box_instruction_label.text = "Read the number pattern to your partner."
			if detective_pattern_label:
				detective_pattern_label.visible = true
				detective_pattern_label.text = _format_final_box_display(str(_final_box_data.get("display", "")))
				detective_pattern_label.position = Vector2(390.0, 118.0)
				detective_pattern_label.size = Vector2(565.0, 76.0)
				detective_pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				detective_pattern_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				detective_pattern_label.autowrap_mode = TextServer.AUTOWRAP_OFF
				detective_pattern_label.add_theme_font_size_override("font_size", 34)
				detective_pattern_label.add_theme_color_override("font_color", UI_CREAM)
				detective_pattern_label.add_theme_constant_override("outline_size", 5)
				detective_pattern_label.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.03, 0.98))
			if sidekick_input_row:
				sidekick_input_row.visible = false
		else:
			final_box_instruction_label.text = "Enter the missing number."
			if detective_pattern_label:
				detective_pattern_label.visible = false
			if sidekick_input_row:
				sidekick_input_row.visible = true
				sidekick_input_row.add_theme_constant_override("separation", 12)
			if answer_input:
				answer_input.placeholder_text = "_"
				answer_input.custom_minimum_size = Vector2(260, 48)
				answer_input.add_theme_font_size_override("font_size", 30)
				answer_input.add_theme_color_override("font_placeholder_color", Color(1.0, 0.9, 0.62, 0.95))
			if submit_answer_button:
				submit_answer_button.custom_minimum_size = Vector2(150, 40)

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
	_update_quest_labels()
	_show_notification("The box opened.")

	# Artifact flow: after the math puzzle is solved, show the cinematic tiara reward sequence.
	# Do not use the normal item reward panel here because the tiara is the main artifact.
	_close_final_box_panel()
	rpc_show_tiara_reward()

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
		_show_tiara_reward_panel_rpc.rpc()
	else:
		_show_tiara_reward_panel()


@rpc("any_peer", "reliable", "call_local")
func _show_tiara_reward_panel_rpc() -> void:
	# This keeps the old hotspot fallback working, but it now uses the cinematic artifact sequence.
	rpc_show_tiara_reward()


func _show_tiara_reward_panel() -> void:
	# Fallback if the player taps the tiara manually after the box opens.
	# The final-box solve path calls rpc_show_tiara_reward() directly to avoid double RPC broadcasts.
	if _has_tiara_clue():
		return

	if multiplayer.has_multiplayer_peer():
		_show_tiara_reward_panel_rpc.rpc()
	else:
		rpc_show_tiara_reward()



func _setup_inventory_board() -> void:
	if inventory_area and not inventory_area.input_event.is_connected(_on_inventory_area_input_event):
		inventory_area.input_event.connect(_on_inventory_area_input_event)

	if GameState and GameState.has_signal("briefcase_updated"):
		if not GameState.briefcase_updated.is_connected(_refresh_inventory_board):
			GameState.briefcase_updated.connect(_refresh_inventory_board)

	_ensure_inventory_slot_highlight()
	_ensure_inventory_block_label()
	_refresh_inventory_interaction_state()
	_refresh_inventory_board()


func _refresh_inventory_interaction_state() -> void:
	if is_instance_valid(inventory_area):
		# Keep the board pickable on both screens so Detective taps can show
		# a local guidance message, but only Sidekick can actually use items.
		inventory_area.input_pickable = true

	if is_instance_valid(inventory_board_sprite):
		inventory_board_sprite.modulate = Color(0.68, 0.68, 0.68, 0.74) if _is_local_detective() else Color.WHITE


func _ensure_inventory_slot_highlight() -> void:
	if not is_instance_valid(inventory_board):
		return

	var existing_highlight := inventory_board.get_node_or_null("SelectedSlotHighlight")
	if is_instance_valid(existing_highlight) and not (existing_highlight is Panel):
		inventory_board.remove_child(existing_highlight)
		existing_highlight.queue_free()

	_inventory_slot_highlight = inventory_board.get_node_or_null("SelectedSlotHighlight") as Panel
	if is_instance_valid(_inventory_slot_highlight):
		return

	_inventory_slot_highlight = Panel.new()
	_inventory_slot_highlight.name = "SelectedSlotHighlight"
	_inventory_slot_highlight.size = Vector2(112.0, 82.0)
	_inventory_slot_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_slot_highlight.visible = false
	_inventory_slot_highlight.z_index = 18
	_inventory_slot_highlight.add_theme_stylebox_override(
		"panel",
		_make_flat_style(Color(0.66, 0.66, 0.66, 0.78), Color(1.0, 1.0, 1.0, 0.9), 8, 3)
	)
	inventory_board.add_child(_inventory_slot_highlight)


func _ensure_inventory_block_label() -> void:
	if not is_instance_valid(inventory_board):
		return

	_inventory_block_label = inventory_board.get_node_or_null("DetectiveInventoryHint") as Label
	if is_instance_valid(_inventory_block_label):
		return

	_inventory_block_label = Label.new()
	_inventory_block_label.name = "DetectiveInventoryHint"
	_inventory_block_label.text = "Only Sidekick can interact with the inventory."
	_inventory_block_label.size = Vector2(560.0, 34.0)
	_inventory_block_label.position = Vector2(398.0, 438.0)
	if is_instance_valid(inventory_board_sprite):
		_inventory_block_label.position = inventory_board_sprite.position + Vector2(-280.0, -134.0)
	_inventory_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inventory_block_label.add_theme_font_size_override("font_size", 18)
	_inventory_block_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_inventory_block_label.add_theme_constant_override("outline_size", 5)
	_inventory_block_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08, 0.95))
	_inventory_block_label.modulate.a = 0.0
	_inventory_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_block_label.z_index = 60
	inventory_board.add_child(_inventory_block_label)


func _show_inventory_block_message() -> void:
	if not is_instance_valid(_inventory_block_label):
		_ensure_inventory_block_label()
	if not is_instance_valid(_inventory_block_label):
		return

	if is_instance_valid(_inventory_block_tween):
		_inventory_block_tween.kill()

	_inventory_block_label.visible = true
	_inventory_block_label.modulate.a = 0.0
	_inventory_block_tween = create_tween()
	_inventory_block_tween.tween_property(_inventory_block_label, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_inventory_block_tween.tween_interval(1.35)
	_inventory_block_tween.tween_property(_inventory_block_label, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _get_display_inventory_items() -> Array[String]:
	var display_items: Array[String] = []

	if _has_inventory_item(CABINET_KEY_ITEM_ID):
		display_items.append(CABINET_KEY_ITEM_ID)

	for item_id in INVENTORY_DISPLAY_PRIORITY:
		if item_id.begins_with("key_fragment_") and _has_inventory_item(CABINET_KEY_ITEM_ID):
			continue
		if _has_inventory_item(item_id):
			display_items.append(item_id)

	return display_items


func _refresh_inventory_board() -> void:
	if not inventory_board or not inventory_area:
		return

	for icon in _inventory_icon_nodes.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_inventory_icon_nodes.clear()
	_inventory_display_items = _get_display_inventory_items()

	if not _inventory_display_items.has(_armed_inventory_item):
		_armed_inventory_item = ""

	_armed_inventory_slot_index = _inventory_display_items.find(_armed_inventory_item)

	if is_instance_valid(_inventory_slot_highlight):
		_inventory_slot_highlight.visible = false

	for slot_index in range(_inventory_display_items.size()):
		if slot_index >= INVENTORY_SLOT_ITEM_ORDER.size():
			break

		var item_id: String = _inventory_display_items[slot_index]
		var texture := _get_inventory_item_texture(item_id)
		if texture == null:
			continue

		var slot_node := inventory_area.get_node_or_null("Item%d" % (slot_index + 1)) as CollisionShape2D
		if slot_node == null:
			continue

		var icon := Sprite2D.new()
		icon.name = "Inventory_%s" % item_id
		icon.texture = texture
		icon.position = inventory_board.to_local(slot_node.global_position)
		icon.z_index = 26
		_fit_inventory_icon(icon, texture)

		if _armed_inventory_item == item_id:
			icon.modulate = Color(1.0, 0.96, 0.72, 1.0)
			icon.scale *= 1.1
		elif _is_local_detective():
			icon.modulate = Color(0.72, 0.72, 0.72, 0.82)
		else:
			icon.modulate = Color.WHITE

		inventory_board.add_child(icon)
		_inventory_icon_nodes[item_id] = icon

		if slot_index == _armed_inventory_slot_index and is_instance_valid(_inventory_slot_highlight):
			_inventory_slot_highlight.position = icon.position - (_inventory_slot_highlight.size * 0.5)
			_inventory_slot_highlight.visible = true


func _fit_inventory_icon(icon: Sprite2D, texture: Texture2D) -> void:
	if texture == null:
		return

	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var target_size := Vector2(72.0, 52.0)
	var scale_factor := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	icon.scale = Vector2(scale_factor, scale_factor)


func _get_inventory_item_texture(item_id: String) -> Texture2D:
	match item_id:
		"key_fragment_1":
			return key_fragment_1_texture
		"card_piece":
			return card_piece_texture
		"key_fragment_2":
			return key_fragment_2_texture
		"light_bulb":
			return lighter_texture
		"key_fragment_3":
			return key_fragment_3_texture
		"assembled_key":
			if assembled_key_texture:
				return assembled_key_texture
			return key_fragment_3_texture
	return null


func _has_inventory_item(item_id: String) -> bool:
	return GameState and GameState.has_method("has_zone_item") and GameState.has_zone_item(ZONE_ID, item_id)


func _on_inventory_area_input_event(_viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if _dialogue_input_locked:
		return

	if not _is_primary_press_event(event):
		return

	if not _is_local_sidekick():
		_show_inventory_block_message()
		return

	if shape_idx < 0 or shape_idx >= INVENTORY_SLOT_ITEM_ORDER.size():
		return

	if shape_idx >= _inventory_display_items.size():
		_show_notification("That inventory slot is still empty.")
		return

	var item_id: String = _inventory_display_items[shape_idx]

	if item_id in ["key_fragment_1", "key_fragment_2", "key_fragment_3"]:
		_try_combine_key_fragments()
		return

	_arm_inventory_item(item_id)


func _try_combine_key_fragments() -> void:
	if _has_inventory_item(CABINET_KEY_ITEM_ID):
		_arm_inventory_item(CABINET_KEY_ITEM_ID)
		return

	var has_all_fragments := (
		_has_inventory_item("key_fragment_1")
		and _has_inventory_item("key_fragment_2")
		and _has_inventory_item("key_fragment_3")
	)

	if not has_all_fragments:
		_show_notification("Collect all 3 key fragments first.")
		return

	if multiplayer.has_multiplayer_peer():
		_sync_assemble_key_rpc.rpc()
	else:
		_apply_assemble_key()


@rpc("any_peer", "reliable", "call_local")
func _sync_assemble_key_rpc() -> void:
	_apply_assemble_key()


func _apply_assemble_key() -> void:
	if GameState and GameState.has_method("remove_zone_items"):
		GameState.remove_zone_items(ZONE_ID, [
			"key_fragment_1",
			"key_fragment_2",
			"key_fragment_3"
		])

	if GameState and GameState.has_method("grant_zone_item"):
		GameState.grant_zone_item(ZONE_ID, CABINET_KEY_ITEM_ID)

	_armed_inventory_item = CABINET_KEY_ITEM_ID
	_refresh_inventory_board()
	_show_notification("The fragments formed a key. Tap the cabinet lock.")


func _arm_inventory_item(item_id: String) -> void:
	if multiplayer.has_multiplayer_peer():
		_sync_inventory_selection_rpc.rpc(item_id)
	else:
		_apply_inventory_selection(item_id)


@rpc("any_peer", "reliable", "call_local")
func _sync_inventory_selection_rpc(item_id: String) -> void:
	_apply_inventory_selection(item_id)


func _apply_inventory_selection(item_id: String) -> void:
	if not _has_inventory_item(item_id):
		return

	_armed_inventory_item = item_id
	_refresh_inventory_board()
	if _is_local_sidekick() or not multiplayer.has_multiplayer_peer():
		_show_notification("%s selected." % str(INVENTORY_ITEM_NAMES.get(item_id, item_id)))


func _consume_armed_inventory_item(item_id: String) -> bool:
	if _armed_inventory_item != item_id:
		return false

	if not _has_inventory_item(item_id):
		_armed_inventory_item = ""
		_refresh_inventory_board()
		return false

	if multiplayer.has_multiplayer_peer():
		_sync_inventory_item_consumed_rpc.rpc(item_id)
	else:
		_apply_inventory_item_consumed(item_id)

	return true


@rpc("any_peer", "reliable", "call_local")
func _sync_inventory_item_consumed_rpc(item_id: String) -> void:
	_apply_inventory_item_consumed(item_id)


func _apply_inventory_item_consumed(item_id: String) -> void:
	if _armed_inventory_item == item_id:
		_armed_inventory_item = ""

	if GameState and GameState.has_method("remove_zone_item"):
		GameState.remove_zone_item(ZONE_ID, item_id)

	_refresh_inventory_board()

func _setup_tiara_reward_layer() -> void:
	if cinematic_reward_layer:
		cinematic_reward_layer.visible = false
		# Keep the artifact reward above puzzle panels and normal reward panels.
		cinematic_reward_layer.layer = 100

	if cinematic_dark_overlay:
		cinematic_dark_overlay.visible = true
		cinematic_dark_overlay.color = Color.BLACK
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
		_style_brown_button(cinematic_collect_button, Vector2(240, 58))

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

	# Hide normal reward UI so the artifact sequence is the only reward visible.
	if reward_canvas_layer:
		reward_canvas_layer.visible = false
	if reward_dimmer:
		reward_dimmer.visible = false
	if reward_panel:
		reward_panel.visible = false

	# Hide final box panel while cinematic reward is active.
	if final_box_panel:
		final_box_panel.visible = false
		final_box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if dimmer:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if cinematic_reward_layer:
		cinematic_reward_layer.visible = true
		cinematic_reward_layer.layer = 100

	if cinematic_dark_overlay:
		cinematic_dark_overlay.modulate.a = 1.0

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
		cinematic_banner_label.text = "ARTIFACT FOUND!"

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

	_play_zone_completion_sfx()
	_spawn_confetti(cinematic_reward_layer, 72)
		
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
			_show_tiara_reward_stage_text("Inside the old box, the tiara began to shine.")
		2:
			_tiara_reward_stage = 3
			_show_tiara_reward_stage_text("This was Pina's tiara, a sign that she was treated like a princess.")
		3:
			_tiara_reward_stage = 4
			_show_tiara_reward_stage_text("She was loved and admired, but she still needed to learn to help herself.")
		4:
			_tiara_reward_stage = 5
			_show_tiara_reward_stage_text("The tiara remembers the life Pina had before she disappeared.")
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
				cinematic_collect_button.text = "Collect Artifact"
				# Only the Sidekick can collect the artifact in multiplayer.
				# In single-player/debug with no peer, allow collection so you can test quickly.
				var can_collect := _is_local_sidekick() or not multiplayer.has_multiplayer_peer()
				cinematic_collect_button.visible = can_collect
				cinematic_collect_button.disabled = not can_collect
				
func _on_tiara_collect_pressed() -> void:
	if _tiara_collect_sequence_started:
		return

	_tiara_collect_sequence_started = true

	if cinematic_collect_button:
		cinematic_collect_button.visible = false
		cinematic_collect_button.disabled = true

	if not multiplayer.has_multiplayer_peer():
		rpc_show_tiara_briefcase_reveal_then_finalize()
	elif multiplayer.is_server():
		rpc_show_tiara_briefcase_reveal_then_finalize.rpc()
	else:
		rpc_request_collect_tiara.rpc_id(SERVER_PEER_ID)

@rpc("any_peer", "reliable")
func rpc_request_collect_tiara() -> void:
	if multiplayer.is_server():
		rpc_show_tiara_briefcase_reveal_then_finalize.rpc()
		
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

	var reveal_texture: Texture2D = GameState.get_briefcase_texture("abandoned_house_reveal")
	cinematic_briefcase_reveal.texture = reveal_texture
	cinematic_briefcase_reveal.visible = reveal_texture != null
	cinematic_briefcase_reveal.modulate = Color(1, 1, 1, 1)
	
@rpc("authority", "reliable", "call_local")
func rpc_show_tiara_briefcase_reveal_then_finalize() -> void:
	_hide_tiara_reward_visuals_for_briefcase()
	_show_tiara_briefcase_reveal_local()

	await get_tree().create_timer(1.5).timeout

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			rpc_finalize_tiara_clue.rpc()
	else:
		rpc_finalize_tiara_clue()
		
func _complete_remaining_progress_after_memory() -> void:
	if _final_box_opened:
		return

	if GameState and GameState.has_method("grant_zone_items"):
		GameState.grant_zone_items(ZONE_ID, MEMORY_REWARD_ITEMS)
		GameState.grant_zone_items(ZONE_ID, DRAWER_REWARD_ITEMS)
		GameState.grant_zone_items(ZONE_ID, [CABINET_KEY_ITEM_ID])

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(MIRROR_PUZZLE_ID, true)
		GameState.set_puzzle_solved(DRAWER_PUZZLE_ID, true)
		GameState.set_puzzle_solved(CABINET_PUZZLE_ID, true)
		GameState.set_puzzle_solved(FINAL_BOX_PUZZLE_ID, true)

	_mirror_lit = true
	_drawer_unlocked = true
	_drawer_digits = _get_drawer_correct_code()
	_cabinet_opened = true
	_final_box_opened = true

	_refresh_room_lighting()
	_refresh_drawer_digit_visuals()
	_refresh_drawer_panel_state()
	_refresh_drawer_lock_panel_state()
	_refresh_cabinet_panel_state()
	_refresh_final_box_panel_state()
	_refresh_progress_tracker()
	_refresh_inventory_board()
	_update_quest_labels()

@rpc("authority", "reliable", "call_local")
func rpc_finalize_tiara_clue() -> void:
	_complete_remaining_progress_after_memory()

	# grant the tiara item and mark the whole abandoned house zone as solved
	if GameState and GameState.has_method("grant_zone_items"):
		GameState.grant_zone_items(ZONE_ID, TIARA_REWARD_ITEMS)

	if GameState and GameState.has_method("has_clue") and GameState.has_method("collect_clue"):
		if not GameState.has_clue(ZONE_ID):
			GameState.collect_clue(ZONE_ID)

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(ZONE_ID, true)

	_update_quest_labels()
	_refresh_inventory_board()

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

	await _start_synced_zone_ending_sequence()
	
func _process(delta: float) -> void:
	if _tiara_sparkle_animating and cinematic_sparkle and cinematic_sparkle.visible:
		_tiara_animation_time += delta
		var pulse: float = (sin(_tiara_animation_time * TIARA_SPARKLE_PULSE_SPEED) + 1.0) / 2.0
		var target_scale: float = lerpf(TIARA_SPARKLE_MIN_SCALE, TIARA_SPARKLE_MAX_SCALE, pulse)
		cinematic_sparkle.scale = Vector2(target_scale, target_scale)

func _return_to_forest() -> void:
	get_tree().paused = false
	MusicController.resume_music()
	GameState.change_to_post_zone_scene(get_tree())

func _start_synced_zone_ending_sequence() -> void:
	if _ending_cutscene_transition_active:
		return

	_ending_cutscene_transition_active = true
	_ending_cutscene_return_sent = false
	_ending_cutscene_finished_peers.clear()
	_ending_cutscene_resolved = false

	await _fade_out(0.6)
	_play_ending_cutscene()
	await _fade_in(0.6)
	
func _play_ending_cutscene() -> void:
	if not is_instance_valid(ending_cutscene):
		call_deferred("_on_cutscene_finished")
		return
	var dark: Node = get_node_or_null("Cutscene/DarkOverlay")
	if is_instance_valid(dark):
		dark.visible = true
	ending_cutscene.visible = true
	CutsceneHelper.play_with_fallback(self, ending_cutscene, _on_cutscene_finished)


func _on_cutscene_finished() -> void:
	if _ending_cutscene_resolved:
		return
	_ending_cutscene_resolved = true
	if is_instance_valid(ending_cutscene):
		ending_cutscene.visible = false
		ending_cutscene.stop()
	var dark: Node = get_node_or_null("Cutscene/DarkOverlay")
	if is_instance_valid(dark):
		dark.visible = false
	await _fade_out(0.6)
	get_tree().paused = false
	await get_tree().process_frame

	if not multiplayer.has_multiplayer_peer():
		if is_inside_tree():
			_return_to_forest()
		return

	if multiplayer.is_server():
		_mark_ending_cutscene_peer_finished(multiplayer.get_unique_id())
		_try_return_to_forest_after_synced_ending()
	else:
		rpc_notify_ending_cutscene_finished.rpc_id(SERVER_PEER_ID)

func _mark_ending_cutscene_peer_finished(peer_id: int) -> void:
	_ending_cutscene_finished_peers[str(peer_id)] = true

func _have_all_ending_cutscene_peers_finished() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true

	if not _ending_cutscene_finished_peers.get(str(multiplayer.get_unique_id()), false):
		return false

	for peer_id in multiplayer.get_peers():
		if not _ending_cutscene_finished_peers.get(str(peer_id), false):
			return false

	return true

func _try_return_to_forest_after_synced_ending() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return

	if _ending_cutscene_return_sent or not _have_all_ending_cutscene_peers_finished():
		return

	_ending_cutscene_return_sent = true
	rpc_return_to_forest_after_ending.rpc()

@rpc("any_peer", "reliable")
func rpc_notify_ending_cutscene_finished() -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return

	_mark_ending_cutscene_peer_finished(sender_id)
	_try_return_to_forest_after_synced_ending()

@rpc("authority", "reliable", "call_local")
func rpc_return_to_forest_after_ending() -> void:
	_ending_cutscene_transition_active = false
	_ending_cutscene_return_sent = false
	_ending_cutscene_finished_peers.clear()

	if is_inside_tree():
		_return_to_forest()


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

func _set_dialogue_input_lock(locked: bool) -> void:
	_dialogue_input_locked = locked

	# Keep exit/back usable if you want.
	if is_instance_valid(back_button):
		back_button.disabled = false

	# Lock sidekick utility buttons during dialogue.
	if is_instance_valid(inside_zone_control):
		if inside_zone_control.has_method("set_pause_enabled"):
			inside_zone_control.set_pause_enabled(true)
		if inside_zone_control.has_method("set_briefcase_enabled"):
			inside_zone_control.set_briefcase_enabled(not locked and GameState.local_role == GameState.Role.SIDEKICK)
		
	# Show/hide players based on lock state
	_update_player_visibility(not locked)


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
	_update_player_visibility(false)
	_set_dialogue_input_lock(true)
	DialogueSystem.play("abandoned_house_intro", _get_abandoned_house_intro_dialogue())
	await DialogueSystem.wait_finished("abandoned_house_intro")
	_set_dialogue_input_lock(false)
	_update_player_visibility(true)
	if is_instance_valid(quest_layer):
		quest_layer.visible = true
	_update_quest_labels()
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


# Player Visibility Helper
func _update_player_visibility(spawn_players: bool) -> void:
	if is_instance_valid(detective_player):
		detective_player.visible = spawn_players and GameState.local_role == GameState.Role.DETECTIVE
	if is_instance_valid(sidekick_player):
		sidekick_player.visible = spawn_players and GameState.local_role == GameState.Role.SIDEKICK
