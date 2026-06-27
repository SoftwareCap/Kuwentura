extends Node2D

const ZONE_ID := "old_well"
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const SERVER_PEER_ID := 1
const MAX_MISTAKES := 3
const PUZZLE_1_TARGET := 10
const TOTAL_BUCKET_STEPS := 10
const LEDGER_IMAGE_PATH := "res://assets/sprites/ledger/newOldWellLedger.png"

const TEX_SPLASH := "res://assets/sprites/zoneObjects/oldWell/splashWater.png"
const TEX_SIYOKOY_IDLE := "res://assets/sprites/zoneObjects/oldWell/siyokoy1.png"
const TEX_SIYOKOY_ATTACK := "res://assets/sprites/zoneObjects/oldWell/siyokoy2.png"
const TEX_EYE_CLUE := "res://assets/sprites/clues/eyeClue_old_well.png"
const TEX_EYE_REFERENCE := "res://assets/sprites/zoneObjects/oldWell/eyePuzzle.png"
const TEX_DIALOGUE_BOX := "res://assets/sprites/zoneObjects/oldWell/siyokoyDialogue.png"
const TEX_HEART_FULL := "res://assets/sprites/zoneObjects/oldWell/fullHeart.png"
const TEX_HEART_EMPTY := "res://assets/sprites/zoneObjects/oldWell/zeroheart.png"
const FONT_HEADING := "res://assets/fonts/Arabica.ttf"
const FONT_BODY := "res://assets/fonts/ocraextended.ttf"
const COMPLETION_SFX: AudioStream = preload("res://assets/audios/ZoneCompletionSFX.mp3")

const UI_CREAM := Color(1.0, 1.0, 1.0, 1.0)
const UI_INK := Color(0.01, 0.02, 0.07, 1.0)
const UI_GOLD := Color(0.45, 0.62, 1.0, 1.0)
const UI_GREEN := Color(0.0, 0.9, 0.65, 1.0)
const UI_RED := Color(1.0, 0.28, 0.28, 1.0)
const UI_MUTED := Color(0.44, 0.50, 0.64, 1.0)
const UI_PANEL := Color(0.03, 0.05, 0.16, 0.92)
const UI_PRIMARY := Color(0.45, 0.62, 1.0, 1.0)
const UI_PRIMARY_HOVER := Color(0.58, 0.72, 1.0, 1.0)
const UI_PRIMARY_PRESSED := Color(0.30, 0.48, 0.90, 1.0)
const UI_BUTTON := Color(0.26, 0.40, 0.78, 1.0)
const UI_BUTTON_HOVER := Color(0.34, 0.48, 0.86, 1.0)
const UI_BUTTON_PRESSED := Color(0.18, 0.30, 0.66, 1.0)
const UI_DISABLED := Color(0.15, 0.19, 0.30, 0.90)
const UI_BORDER := Color(0.75, 0.86, 1.0, 1.0)
const UI_INPUT := Color(0.45, 0.60, 0.95, 1.0)

const INTRO_LINES := [
	{"speaker": "Siyokoy", "text": "So... you came peeking into my well?"},
	{"speaker": "Siyokoy", "text": "Something waits inside the bucket below."},
	{"speaker": "Siyokoy", "text": "A little clue, broken and sleeping in the dark."},
	{"speaker": "Siyokoy", "text": "But I do not hand treasures to careless eyes."},
	{"speaker": "Siyokoy", "text": "If you want the bucket to rise, then play my game."},
	{"speaker": "Siyokoy", "text": "Read my old number marks. Answer right, and the bucket climbs."},
	{"speaker": "Siyokoy", "text": "Answer wrong... and I drag you closer to the deep."},
]

const ROMAN_QUESTIONS := [
	{"roman": "III", "answer": 3},
	{"roman": "VI", "answer": 6},
	{"roman": "XII", "answer": 12},
	{"roman": "IV", "answer": 4},
	{"roman": "XIV", "answer": 14},
	{"roman": "XXVII", "answer": 27},
	{"roman": "XL", "answer": 40},
	{"roman": "LXVIII", "answer": 68},
	{"roman": "XCIV", "answer": 94},
	{"roman": "CDXLIV", "answer": 444},
]

const CHAIN_RING_SET := [
	{"roman": "II", "answer": 2},
	{"roman": "V", "answer": 5},
	{"roman": "IX", "answer": 9},
	{"roman": "XIV", "answer": 14},
]

const EYE_ORDER := [1, 2, 3, 4, 5, 6]

const RAGE_BAIT_CORRECT_LINES: Array[String] = [
	"Tch. Lucky guess.",
	"Not bad… dry-land child.",
	"Hmph. You got one.",
	"You know Roman numerals? Annoying.",
	"Fine. One point for you.",
]
const RAGE_BAIT_WRONG_LINES: Array[String] = [
	"Wrong! Even moss knows better.",
	"That answer sank fast.",
	"No, no, no. Read it again.",
	"Try again, little detective.",
	"Oof. Straight to the bottom.",
]
const RAGE_BAIT_WIN_LINES: Array[String] = [
	"Grr… impossible.",
	"You actually solved them?",
	"Fine! Take the clue.",
	"The well opens… for now.",
]
const RAGE_BAIT_INK := Color(0.08, 0.16, 0.42, 1.0)
const ACTION_COOLDOWN_MSEC := 900
const RAGE_BAIT_VISIBLE_SECONDS := 2.6

enum RageBaitKind { CORRECT, WRONG, WIN }
enum Phase { IDLE, INTRO, PUZZLE_1, PUZZLE_2, PUZZLE_3, REWARD, FAILED, COMPLETE }

@onready var back_button: Button = get_node_or_null("BackButton") as Button
@onready var well_area: Area2D = get_node_or_null("InteractionLayer/WellInteractionArea") as Area2D
@onready var legacy_background: Sprite2D = get_node_or_null("BackgroundLayer/OldWellBackground") as Sprite2D
@onready var legacy_well_sprite: Sprite2D = get_node_or_null("BackgroundLayer/OldWellSprite") as Sprite2D
@onready var bucket_sprite: Sprite2D = get_node_or_null("BackgroundLayer/BucketSprite") as Sprite2D
@onready var siyokoy_sprite: Sprite2D = get_node_or_null("BackgroundLayer/SiyokoySprite") as Sprite2D
@onready var intro_old_well: Node2D = get_node_or_null("IntroOldWell") as Node2D
@onready var intro_water_sprite: Sprite2D = get_node_or_null("IntroOldWell/water") as Sprite2D
@onready var intro_siyokoy_sprite: Sprite2D = get_node_or_null("IntroOldWell/siyokoy") as Sprite2D
@onready var siyokoys_game_background: Node2D = get_node_or_null("SiyokoysGame") as Node2D
@onready var game_siyokoy_well: Sprite2D = get_node_or_null("SiyokoysGame/siyokoyOldWell") as Sprite2D
@onready var rage_bait_bubble: Node2D = get_node_or_null("RageBaitBubble") as Node2D
@onready var rage_bait_label: Label = get_node_or_null("RageBaitBubble/RageLabel") as Label
@onready var role_label: Label = get_node_or_null("HUD/RoleLabel") as Label
@onready var status_label: Label = get_node_or_null("HUD/StatusPanel/StatusLabel") as Label
@onready var progress_label: Label = get_node_or_null("HUD/StatusPanel/ProgressLabel") as Label
@onready var lives_label: Label = get_node_or_null("HUD/StatusPanel/LivesLabel") as Label
@onready var instruction_label: Label = get_node_or_null("HUD/InstructionPanel/InstructionLabel") as Label
@onready var dialogue_layer: Node2D = get_node_or_null("DialogueLayer") as Node2D
@onready var dialogue_label: Label = get_node_or_null("DialogueLayer/SiyokoyScriptLabel") as Label
@onready var continue_button: Button = get_node_or_null("DialogueLayer/ContinueButton") as Button
@onready var dialogue_prompt_label: Label = get_node_or_null("DialogueLayer/TapAnywhereLabel") as Label
@onready var puzzle1_layer: CanvasLayer = get_node_or_null("Puzzle1Layer") as CanvasLayer
@onready var detective_roman_view: Control = get_node_or_null("Puzzle1Layer/DetectiveRomanView") as Control
@onready var roman_plaque: TextureRect = get_node_or_null("Puzzle1Layer/DetectiveRomanView/RomanPlaqueDisplay") as TextureRect
@onready var detective_hint_label: Label = get_node_or_null("Puzzle1Layer/DetectiveRomanView/DetectiveHintLabel") as Label
@onready var sidekick_answer_panel: Panel = get_node_or_null("Puzzle1Layer/SidekickAnswerPanel") as Panel
@onready var roman_guide_label: Label = get_node_or_null("Puzzle1Layer/SidekickAnswerPanel/RomanGuideLabel") as Label
@onready var number_input: LineEdit = get_node_or_null("Puzzle1Layer/SidekickAnswerPanel/NumberInput") as LineEdit
@onready var submit_number_button: Button = get_node_or_null("Puzzle1Layer/SidekickAnswerPanel/SubmitNumberButton") as Button
@onready var sidekick_hint_label: Label = get_node_or_null("Puzzle1Layer/SidekickAnswerPanel/SidekickHintLabel") as Label
@onready var puzzle1_feedback: Label = get_node_or_null("Puzzle1Layer/Puzzle1FeedbackLabel") as Label
@onready var puzzle2_layer: CanvasLayer = get_node_or_null("Puzzle2Layer") as CanvasLayer
@onready var detective_chain_view: Control = get_node_or_null("Puzzle2Layer/DetectiveChainView") as Control
@onready var chain_instruction_label: Label = get_node_or_null("Puzzle2Layer/DetectiveChainView/ChainInstructionLabel") as Label
@onready var sidekick_order_panel: Panel = get_node_or_null("Puzzle2Layer/SidekickOrderPanel") as Panel
@onready var order_instruction_label: Label = get_node_or_null("Puzzle2Layer/SidekickOrderPanel/OrderInstructionLabel") as Label
@onready var check_chain_button: Button = get_node_or_null("Puzzle2Layer/SidekickOrderPanel/CheckChainButton") as Button
@onready var puzzle2_feedback: Label = get_node_or_null("Puzzle2Layer/Puzzle2FeedbackLabel") as Label
@onready var puzzle3_layer: CanvasLayer = get_node_or_null("Puzzle3Layer") as CanvasLayer
@onready var detective_reflection_panel: Panel = get_node_or_null("Puzzle3Layer/DetectiveReflectionPanel") as Panel
@onready var reflection_title_label: Label = get_node_or_null("Puzzle3Layer/DetectiveReflectionPanel/ReflectionTitleLabel") as Label
@onready var eye_reflection: TextureRect = get_node_or_null("Puzzle3Layer/DetectiveReflectionPanel/EyeReflectionSprite") as TextureRect
@onready var reflection_hint_label: Label = get_node_or_null("Puzzle3Layer/DetectiveReflectionPanel/ReflectionHintLabel") as Label
@onready var sidekick_puzzle_panel: Panel = get_node_or_null("Puzzle3Layer/SidekickPuzzlePanel") as Panel
@onready var puzzle_title_label: Label = get_node_or_null("Puzzle3Layer/SidekickPuzzlePanel/PuzzleTitleLabel") as Label
@onready var puzzle_board: TextureRect = get_node_or_null("Puzzle3Layer/SidekickPuzzlePanel/PuzzleBoard") as TextureRect
@onready var check_puzzle_button: Button = get_node_or_null("Puzzle3Layer/SidekickPuzzlePanel/CheckPuzzleButton") as Button
@onready var puzzle3_feedback: Label = get_node_or_null("Puzzle3Layer/Puzzle3FeedbackLabel") as Label
@onready var water_splash: TextureRect = get_node_or_null("EffectsLayer/WaterSplashOverlay") as TextureRect
@onready var blur_overlay: ColorRect = get_node_or_null("EffectsLayer/BlurOverlay") as ColorRect
@onready var drowning_overlay: ColorRect = get_node_or_null("EffectsLayer/DrowningOverlay") as ColorRect
@onready var correct_overlay: ColorRect = get_node_or_null("EffectsLayer/CorrectGlowOverlay") as ColorRect
@onready var reward_layer: CanvasLayer = get_node_or_null("RewardLayer") as CanvasLayer
@onready var reward_dark: ColorRect = get_node_or_null("RewardLayer/DarkOverlay") as ColorRect
@onready var reward_banner: Label = get_node_or_null("RewardLayer/BannerLabel") as Label
@onready var clue_sprite: Sprite2D = get_node_or_null("RewardLayer/ClueSprite") as Sprite2D
@onready var sparkle: Sprite2D = get_node_or_null("RewardLayer/Sparkle") as Sprite2D
@onready var reward_text: Label = get_node_or_null("RewardLayer/RewardPanel/RewardText") as Label
@onready var tap_instruction: Label = get_node_or_null("RewardLayer/TapInstruction") as Label
@onready var collect_button: Button = get_node_or_null("RewardLayer/CollectButton") as Button
@onready var tap_catcher: Button = get_node_or_null("RewardLayer/TapCatcher") as Button
@onready var briefcase_reveal: TextureRect = get_node_or_null("RewardLayer/BriefcaseRevealSprite") as TextureRect
@onready var inside_zone_control: CanvasLayer = get_node_or_null("InsideZoneControl") as CanvasLayer
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
@onready var pause_layer: CanvasLayer = get_node_or_null("PauseCanvasLayer") as CanvasLayer
@onready var pause_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel") as Panel
@onready var option_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel") as Panel
@onready var volume_slider: HSlider = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider") as HSlider
@onready var volume_value: Label = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue") as Label
@onready var ending_cutscene: VideoStreamPlayer = $Cutscene/EndingCutscene

var _ending_cutscene_resolved := false

var _rng := RandomNumberGenerator.new()
var _phase: int = Phase.IDLE
var _mistakes := 0
var _bucket_progress := 0
var _intro_index := 0
var _puzzle1_correct := 0
var _roman_sequence: Array = []
var _roman_index := 0
var _current_roman: Dictionary = {}
var _chain_rings: Array = []
var _chain_slots: Array[int] = [-1, -1, -1, -1]
var _selected_chain_ring := -1
var _eye_order: Array[int] = []
var _eye_slots: Array[int] = [-1, -1, -1, -1, -1, -1]
var _selected_eye_piece := -1
var _active_answer_role: int = GameState.Role.SIDEKICK
var _last_pass_msec: int = 0
var _last_action_msec: int = 0
var _last_server_answer_msec: int = 0
var _rage_bait_tween: Tween = null
var _pass_button: Button = null
var _reward_stage := 0
var _waiting_reward_tap := false
var _collect_started := false
var _clue_collected := false
var _fail_started := false
var _bucket_start := Vector2.ZERO
var _font: Font
var _heading_font: Font
var _sfx_player: AudioStreamPlayer
var _hearts_container: HBoxContainer = null
var _puzzle1_instruction_label: Label = null
var _heart_icons: Array[TextureRect] = []
var _heart_full_texture: Texture2D = null
var _heart_empty_texture: Texture2D = null
var _chain_displays: Array[TextureRect] = []
var _chain_choice_buttons: Array[BaseButton] = []
var _chain_slot_buttons: Array[BaseButton] = []
var _eye_piece_buttons: Array[BaseButton] = []
var _eye_slot_buttons: Array[BaseButton] = []


func _ready() -> void:
	_rng.randomize()
	_font = _load_font(FONT_BODY)
	_heading_font = _load_font(FONT_HEADING)
	_ensure_sfx_bus()
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)
	_cache_arrays()
	_apply_assets()
	_setup_mobile_layout()
	_connect_signals()
	_reset_state()
	call_deferred("_auto_start_intro")
	if GameState and not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)

	if is_instance_valid(ending_cutscene):
		CutsceneHelper.prepare_mobile_video_player(ending_cutscene)
		ending_cutscene.visible = false

	var cutscene_dark: Node = get_node_or_null("Cutscene/DarkOverlay")
	if is_instance_valid(cutscene_dark):
		cutscene_dark.visible = false


func _cache_arrays() -> void:
	for i in range(1, 5):
		_chain_displays.append(get_node_or_null("Puzzle2Layer/DetectiveChainView/ChainRingDisplay%d" % i) as TextureRect)
		_chain_choice_buttons.append(get_node_or_null("Puzzle2Layer/SidekickOrderPanel/AvailableRings/RingChoice%d" % i) as BaseButton)
		_chain_slot_buttons.append(get_node_or_null("Puzzle2Layer/SidekickOrderPanel/ChainSlots/Slot%d" % i) as BaseButton)
	for i in range(1, 7):
		_eye_piece_buttons.append(get_node_or_null("Puzzle3Layer/SidekickPuzzlePanel/PuzzlePieces/Piece%d" % i) as BaseButton)
		_eye_slot_buttons.append(get_node_or_null("Puzzle3Layer/SidekickPuzzlePanel/PuzzleSlots/Slot%d" % i) as BaseButton)


func _apply_assets() -> void:
	_heart_full_texture = _load_texture(TEX_HEART_FULL)
	_heart_empty_texture = _load_texture(TEX_HEART_EMPTY)
	if is_instance_valid(water_splash):
		water_splash.texture = _load_texture(TEX_SPLASH)
	if is_instance_valid(siyokoy_sprite):
		siyokoy_sprite.texture = _load_texture(TEX_SIYOKOY_IDLE)
	if is_instance_valid(clue_sprite):
		var clue: Texture2D = _load_texture(TEX_EYE_CLUE)
		if clue:
			clue_sprite.texture = clue
	var eye_reference: Texture2D = _load_texture(TEX_EYE_REFERENCE)
	if is_instance_valid(eye_reflection):
		eye_reflection.texture = eye_reference
	if is_instance_valid(puzzle_board):
		puzzle_board.texture = eye_reference
		puzzle_board.modulate.a = 0.12


func _setup_mobile_layout() -> void:
	_bucket_start = bucket_sprite.position if is_instance_valid(bucket_sprite) else Vector2.ZERO
	_ensure_turn_controls()
	_ensure_dialogue_frame()
	_ensure_heart_display()
	_layout_runtime()
	_apply_font_tree(self)
	_apply_design_system()
	_setup_rage_bait()
	_place_guardian_art()
	if is_instance_valid(number_input):
		number_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		number_input.max_length = 3
		number_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for button in [continue_button, check_chain_button, check_puzzle_button, collect_button, back_button]:
		if is_instance_valid(button):
			button.custom_minimum_size = Vector2(160, 48)
			button.focus_mode = Control.FOCUS_NONE
	for button in [submit_number_button, _pass_button]:
		if is_instance_valid(button):
			button.custom_minimum_size = Vector2(148, 48)
			button.focus_mode = Control.FOCUS_NONE
	for button in _chain_choice_buttons + _chain_slot_buttons + _eye_piece_buttons + _eye_slot_buttons:
		if is_instance_valid(button):
			button.custom_minimum_size = Vector2(88, 88)
			button.focus_mode = Control.FOCUS_NONE
	for overlay in [water_splash, blur_overlay, drowning_overlay, correct_overlay, reward_dark]:
		if overlay is Control:
			(overlay as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(blur_overlay):
		blur_overlay.color = Color(0.4, 0.65, 0.95, 0.0)
	if is_instance_valid(drowning_overlay):
		drowning_overlay.color = Color(0.0, 0.05, 0.10, 0.0)
	if is_instance_valid(correct_overlay):
		correct_overlay.color = Color(0.45, 0.95, 0.45, 0.0)


func _ensure_turn_controls() -> void:
	if not is_instance_valid(sidekick_answer_panel):
		return
	if not is_instance_valid(_puzzle1_instruction_label):
		_puzzle1_instruction_label = Label.new()
		_puzzle1_instruction_label.name = "Puzzle1InstructionLabel"
		_puzzle1_instruction_label.text = "Turn the Roman numeral into a number."
		_puzzle1_instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sidekick_answer_panel.add_child(_puzzle1_instruction_label)
		if is_instance_valid(roman_guide_label):
			sidekick_answer_panel.move_child(_puzzle1_instruction_label, roman_guide_label.get_index() + 1)
	if not is_instance_valid(_pass_button):
		_pass_button = Button.new()
		_pass_button.name = "PassTurnButton"
		_pass_button.text = "Pass"
		sidekick_answer_panel.add_child(_pass_button)


func _ensure_dialogue_frame() -> void:
	if is_instance_valid(dialogue_layer):
		dialogue_layer.visible = false
	if is_instance_valid(dialogue_label):
		dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_instance_valid(dialogue_prompt_label) and is_instance_valid(dialogue_layer):
		dialogue_prompt_label = Label.new()
		dialogue_prompt_label.name = "TapAnywhereLabel"
		dialogue_prompt_label.text = "Tap anywhere to continue."
		dialogue_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dialogue_layer.add_child(dialogue_prompt_label)
	if is_instance_valid(dialogue_prompt_label):
		dialogue_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dialogue_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dialogue_prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		dialogue_prompt_label.text = "Tap anywhere to continue."
	if is_instance_valid(continue_button):
		continue_button.text = ""
		continue_button.flat = true
		continue_button.focus_mode = Control.FOCUS_NONE
		continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
		continue_button.visible = false
		continue_button.disabled = true
		continue_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		continue_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		continue_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		continue_button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())


func _ensure_heart_display() -> void:
	if is_instance_valid(_hearts_container):
		return
	_hearts_container = HBoxContainer.new()
	_hearts_container.name = "OldWellHearts"
	_hearts_container.position = Vector2(62, 46)
	_hearts_container.size = Vector2(204, 54)
	_hearts_container.add_theme_constant_override("separation", 10)
	add_child(_hearts_container)
	for i in range(MAX_MISTAKES):
		var heart: TextureRect = TextureRect.new()
		heart.name = "Heart%d" % (i + 1)
		heart.custom_minimum_size = Vector2(50, 44)
		heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hearts_container.add_child(heart)
		_heart_icons.append(heart)


func _layout_runtime() -> void:
	var size: Vector2 = get_viewport_rect().size
	if size == Vector2.ZERO:
		size = Vector2(1240, 720)
	_place(continue_button, Vector2.ZERO, size)
	_place(dialogue_prompt_label, Vector2((size.x - 520.0) * 0.5, 588.0), Vector2(520.0, 28.0))
	if is_instance_valid(_hearts_container):
		_hearts_container.position = Vector2(80, 44)
		_hearts_container.size = Vector2(204, 54)

	var puzzle_block_width: float = 420.0
	var puzzle_block_x: float = maxf(148.0, size.x * 0.30 - puzzle_block_width * 0.5)
	var puzzle_block_y: float = 168.0
	var puzzle_button_width: float = 148.0
	var puzzle_button_height: float = 48.0
	var puzzle_button_y: float = 286.0
	var puzzle_button_gap: float = 12.0
	var puzzle_buttons_total: float = puzzle_button_width * 2.0 + puzzle_button_gap
	var puzzle_button_x: float = (puzzle_block_width - puzzle_buttons_total) * 0.5
	var puzzle_input_width: float = 280.0
	var puzzle_input_x: float = (puzzle_block_width - puzzle_input_width) * 0.5
	var puzzle_feedback_gap: float = 32.0
	var puzzle_feedback_y: float = puzzle_block_y + puzzle_button_y + puzzle_button_height + puzzle_feedback_gap

	_place(detective_roman_view, Vector2(puzzle_block_x, puzzle_block_y + 106), Vector2(puzzle_block_width, 84))
	_place(roman_plaque, Vector2.ZERO, Vector2.ZERO)
	_place(detective_hint_label, Vector2(0, 0), Vector2(puzzle_block_width, 84))
	_place(sidekick_answer_panel, Vector2(puzzle_block_x, puzzle_block_y), Vector2(puzzle_block_width, 350))
	_place(roman_guide_label, Vector2(0, 0), Vector2(puzzle_block_width, 54))
	_place(_puzzle1_instruction_label, Vector2(0, 58), Vector2(puzzle_block_width, 34))
	_place(sidekick_hint_label, Vector2(0, 192), Vector2(puzzle_block_width, 34))
	_place(number_input, Vector2(puzzle_input_x, 232), Vector2(puzzle_input_width, 46))
	_place(submit_number_button, Vector2(puzzle_button_x, puzzle_button_y), Vector2(puzzle_button_width, puzzle_button_height))
	_place(_pass_button, Vector2(puzzle_button_x + puzzle_button_width + puzzle_button_gap, puzzle_button_y), Vector2(puzzle_button_width, puzzle_button_height))
	_place(puzzle1_feedback, Vector2(puzzle_block_x, puzzle_feedback_y), Vector2(puzzle_block_width, 28))
	_place(detective_chain_view, Vector2(size.x * 0.05, 220), Vector2(size.x * 0.44, 300))
	_place(chain_instruction_label, Vector2(20, 10), Vector2(size.x * 0.44 - 40, 52))
	for i in range(_chain_displays.size()):
		_place(_chain_displays[i], Vector2(34 + i * 126, 88), Vector2(104, 104))
	_place(sidekick_order_panel, Vector2(size.x * 0.52, 190), Vector2(size.x * 0.43, 384))
	_place(order_instruction_label, Vector2(18, 12), Vector2(size.x * 0.43 - 36, 54))
	_place(get_node_or_null("Puzzle2Layer/SidekickOrderPanel/ChainSlots") as Control, Vector2(24, 80), Vector2(size.x * 0.43 - 48, 92))
	_place(get_node_or_null("Puzzle2Layer/SidekickOrderPanel/AvailableRings") as Control, Vector2(24, 200), Vector2(size.x * 0.43 - 48, 92))
	_place(check_chain_button, Vector2(42, 312), Vector2(size.x * 0.43 - 84, 48))
	_place(puzzle2_feedback, Vector2(size.x * 0.20, 594), Vector2(size.x * 0.60, 48))

	_place(detective_reflection_panel, Vector2(size.x * 0.06, 190), Vector2(size.x * 0.42, 360))
	_place(reflection_title_label, Vector2(18, 12), Vector2(size.x * 0.42 - 36, 40))
	_place(eye_reflection, Vector2(70, 66), Vector2(size.x * 0.42 - 140, 190))
	_place(reflection_hint_label, Vector2(18, 270), Vector2(size.x * 0.42 - 36, 68))
	_place(sidekick_puzzle_panel, Vector2(size.x * 0.52, 140), Vector2(size.x * 0.43, 470))
	_place(puzzle_title_label, Vector2(18, 10), Vector2(size.x * 0.43 - 36, 40))
	_place(puzzle_board, Vector2(28, 56), Vector2(size.x * 0.43 - 56, 120))
	var puzzle_slots: GridContainer = get_node_or_null("Puzzle3Layer/SidekickPuzzlePanel/PuzzleSlots") as GridContainer
	if is_instance_valid(puzzle_slots):
		puzzle_slots.columns = 3
	_place(puzzle_slots, Vector2(34, 74), Vector2(size.x * 0.43 - 68, 164))
	var puzzle_pieces: GridContainer = get_node_or_null("Puzzle3Layer/SidekickPuzzlePanel/PuzzlePieces") as GridContainer
	if is_instance_valid(puzzle_pieces):
		puzzle_pieces.columns = 3
	_place(puzzle_pieces, Vector2(34, 258), Vector2(size.x * 0.43 - 68, 104))
	_place(check_puzzle_button, Vector2(42, 394), Vector2(size.x * 0.43 - 84, 48))
	_place(puzzle3_feedback, Vector2(size.x * 0.20, 624), Vector2(size.x * 0.60, 48))

	for label in [dialogue_label, dialogue_prompt_label, detective_hint_label, roman_guide_label, sidekick_hint_label, chain_instruction_label, order_instruction_label, puzzle2_feedback, reflection_title_label, reflection_hint_label, puzzle_title_label, puzzle3_feedback]:
		if is_instance_valid(label):
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_instance_valid(_puzzle1_instruction_label):
		_puzzle1_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_puzzle1_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_puzzle1_instruction_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_puzzle1_instruction_label.max_lines_visible = 1
		_puzzle1_instruction_label.clip_text = true
		_puzzle1_instruction_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_instance_valid(puzzle1_feedback):
		puzzle1_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		puzzle1_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		puzzle1_feedback.autowrap_mode = TextServer.AUTOWRAP_OFF
		puzzle1_feedback.max_lines_visible = 1
		puzzle1_feedback.clip_text = true
		puzzle1_feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _place(control: Control, pos: Vector2, rect_size: Vector2) -> void:
	if not is_instance_valid(control):
		return
	control.position = pos
	control.size = rect_size
	control.custom_minimum_size = rect_size


func _apply_design_system() -> void:
	for panel in [get_node_or_null("HUD/StatusPanel"), get_node_or_null("HUD/InstructionPanel"), sidekick_order_panel, detective_reflection_panel, sidekick_puzzle_panel]:
		if panel is Panel:
			_apply_panel_style(panel as Panel, UI_PANEL)
	for button in [check_chain_button, check_puzzle_button, collect_button, back_button]:
		if button is Button:
			_apply_button_style(button as Button)
	for button in [submit_number_button, _pass_button]:
		if button is Button:
			_apply_button_style(button as Button, UI_BUTTON, UI_BUTTON_HOVER, UI_BUTTON_PRESSED)
	_apply_line_edit_style(number_input)
	_clear_panel_style(sidekick_answer_panel)
	_style_label(role_label, 16, UI_CREAM)
	_style_label(status_label, 20, UI_GOLD)
	_style_label(progress_label, 18, UI_CREAM)
	_style_label(lives_label, 18, UI_CREAM)
	_style_label(instruction_label, 19, UI_CREAM)
	_style_label(dialogue_label, 30, UI_CREAM)
	_style_label(dialogue_prompt_label, 13, Color(0.86, 0.90, 1.0, 0.88))
	_style_label(detective_hint_label, 88, UI_CREAM)
	_style_label(roman_guide_label, 52, UI_CREAM)
	_style_label(_puzzle1_instruction_label, 20, UI_CREAM)
	_style_label(sidekick_hint_label, 22, UI_GREEN)
	_style_label(chain_instruction_label, 19, UI_CREAM)
	_style_label(order_instruction_label, 18, UI_CREAM)
	_style_label(reflection_title_label, 22, UI_GOLD)
	_style_label(reflection_hint_label, 18, UI_CREAM)
	_style_label(puzzle_title_label, 22, UI_GOLD)
	for label in [dialogue_label, detective_hint_label, roman_guide_label, reflection_title_label, puzzle_title_label]:
		if is_instance_valid(label) and _heading_font:
			label.add_theme_font_override("font", _heading_font)
	_style_label(puzzle1_feedback, 16, UI_GOLD)
	for label in [puzzle2_feedback, puzzle3_feedback]:
		_style_label(label, 20, UI_GOLD)
	if is_instance_valid(reward_text):
		if _heading_font:
			reward_text.add_theme_font_override("font", _heading_font)
		reward_text.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
		reward_text.add_theme_constant_override("outline_size", 0)
	_apply_single_line_label(_puzzle1_instruction_label)
	_apply_single_line_label(puzzle1_feedback)


func _apply_single_line_label(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = 1
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _place_guardian_art() -> void:
	if not is_instance_valid(siyokoy_sprite):
		return
	var size: Vector2 = get_viewport_rect().size
	if size == Vector2.ZERO:
		size = Vector2(1240, 720)
	siyokoy_sprite.position = Vector2(size.x * 0.79, size.y * 0.42)
	siyokoy_sprite.modulate = Color(1, 1, 1, 0.82)
	siyokoy_sprite.z_index = 2
	var tex_size: Vector2 = Vector2(420, 420)
	if siyokoy_sprite.texture:
		tex_size = siyokoy_sprite.texture.get_size()
	var max_extent: float = maxf(tex_size.x, tex_size.y)
	var target_extent: float = 250.0
	var scale_value: float = target_extent / max_extent if max_extent > 0.0 else 0.28
	siyokoy_sprite.scale = Vector2(scale_value, scale_value)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	if not is_instance_valid(label):
		return
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", UI_INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _apply_line_edit_style(input: LineEdit) -> void:
	if not is_instance_valid(input):
		return
	if _font:
		input.add_theme_font_override("font", _font)
	input.add_theme_font_size_override("font_size", 22)
	input.add_theme_color_override("font_color", UI_INK)
	input.add_theme_color_override("font_placeholder_color", Color(0.78, 0.84, 1.0, 0.95))
	input.add_theme_stylebox_override("normal", _input_style(UI_INPUT))
	input.add_theme_stylebox_override("focus", _input_style(Color(0.58, 0.72, 1.0, 1.0)))
	input.add_theme_stylebox_override("read_only", _input_style(Color(0.20, 0.25, 0.42, 0.95)))


func _input_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UI_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _apply_panel_style(panel: Panel, color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UI_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)


func _clear_panel_style(panel: Panel) -> void:
	if not is_instance_valid(panel):
		return
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func _apply_button_style(button: Button, normal_color: Color = UI_PRIMARY, hover_color: Color = UI_PRIMARY_HOVER, pressed_color: Color = UI_PRIMARY_PRESSED) -> void:
	button.focus_mode = Control.FOCUS_NONE
	if _font:
		button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", UI_CREAM)
	button.add_theme_color_override("font_disabled_color", Color(0.70, 0.76, 0.92, 0.72))
	button.add_theme_stylebox_override("normal", _button_style(normal_color))
	button.add_theme_stylebox_override("hover", _button_style(hover_color))
	button.add_theme_stylebox_override("pressed", _button_style(pressed_color))
	button.add_theme_stylebox_override("disabled", _button_style(UI_DISABLED))


func _button_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UI_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


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


func _close_sidekick_panels() -> void:
	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false
	if is_instance_valid(briefcase_panel):
		briefcase_panel.visible = false


func _on_ledger_pressed() -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		return
	if is_instance_valid(briefcase_panel):
		briefcase_panel.visible = false
	if is_instance_valid(ledger_panel):
		ledger_panel.visible = not ledger_panel.visible


func _on_briefcase_pressed() -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		return
	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false
	if is_instance_valid(briefcase_display):
		var tex: Texture2D = GameState.get_briefcase_texture("forest") if GameState else null
		briefcase_display.texture = tex
		briefcase_display.visible = tex != null
	if is_instance_valid(briefcase_panel):
		briefcase_panel.visible = not briefcase_panel.visible


func _connect_signals() -> void:
	if is_instance_valid(back_button):
		back_button.pressed.connect(_on_back_pressed)
	if is_instance_valid(well_area):
		well_area.input_pickable = true
		well_area.input_event.connect(_on_well_input_event)
	if is_instance_valid(continue_button):
		continue_button.pressed.connect(advance_intro)
	if is_instance_valid(submit_number_button):
		submit_number_button.pressed.connect(submit_puzzle_1_answer)
	if is_instance_valid(_pass_button):
		_pass_button.pressed.connect(pass_puzzle_1_question)
	if is_instance_valid(number_input):
		number_input.text_submitted.connect(_on_number_submitted)
		number_input.text_changed.connect(_on_number_changed)
	if is_instance_valid(check_chain_button):
		check_chain_button.pressed.connect(check_chain_order)
	if is_instance_valid(check_puzzle_button):
		check_puzzle_button.pressed.connect(check_eye_puzzle)
	if is_instance_valid(tap_catcher):
		tap_catcher.pressed.connect(_on_reward_tap_pressed)
	if is_instance_valid(collect_button):
		collect_button.pressed.connect(collect_reward)
	for i in range(_chain_choice_buttons.size()):
		if is_instance_valid(_chain_choice_buttons[i]):
			_chain_choice_buttons[i].pressed.connect(select_chain_ring.bind(i))
	for i in range(_chain_slot_buttons.size()):
		if is_instance_valid(_chain_slot_buttons[i]):
			_chain_slot_buttons[i].pressed.connect(select_chain_slot.bind(i))
	for i in range(_eye_piece_buttons.size()):
		if is_instance_valid(_eye_piece_buttons[i]):
			_eye_piece_buttons[i].pressed.connect(select_eye_piece.bind(i))
	for i in range(_eye_slot_buttons.size()):
		if is_instance_valid(_eye_slot_buttons[i]):
			_eye_slot_buttons[i].pressed.connect(select_eye_slot.bind(i))
	if is_instance_valid(inside_zone_control):
		if inside_zone_control.has_signal("pause_pressed"):
			inside_zone_control.pause_pressed.connect(_on_pause_pressed)
		if inside_zone_control.has_signal("ledger_pressed"):
			inside_zone_control.ledger_pressed.connect(_on_ledger_pressed)
		if inside_zone_control.has_signal("briefcase_pressed"):
			inside_zone_control.briefcase_pressed.connect(_on_briefcase_pressed)
	if is_instance_valid(get_node_or_null("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton")):
		(get_node("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton") as BaseButton).pressed.connect(_on_resume_pressed)
	if is_instance_valid(get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionButton")):
		(get_node("PauseCanvasLayer/InGamePausePanel/OptionButton") as BaseButton).pressed.connect(_on_option_pressed)
	var exit_button: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/BackToForest") as BaseButton
	if is_instance_valid(exit_button):
		exit_button.pressed.connect(_on_exit_pressed)
	var option_back: TouchScreenButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/BackToPrevious") as TouchScreenButton
	if is_instance_valid(option_back):
		option_back.pressed.connect(_on_option_back_pressed)
	if is_instance_valid(volume_slider):
		volume_slider.value_changed.connect(_on_volume_changed)


func _reset_state() -> void:
	_phase = Phase.IDLE
	_mistakes = 0
	_bucket_progress = 0
	_intro_index = 0
	_puzzle1_correct = 0
	_active_answer_role = GameState.Role.SIDEKICK
	_last_pass_msec = 0
	_last_action_msec = 0
	_last_server_answer_msec = 0
	_roman_sequence.clear()
	_roman_index = 0
	_current_roman = {}
	_chain_rings.clear()
	_chain_slots = [-1, -1, -1, -1]
	_selected_chain_ring = -1
	_eye_order.clear()
	_eye_slots = [-1, -1, -1, -1, -1, -1]
	_selected_eye_piece = -1
	_reward_stage = 0
	_waiting_reward_tap = false
	_collect_started = false
	_fail_started = false
	_clue_collected = GameState.has_clue(ZONE_ID) if GameState else false
	_hide_phase_layers()
	_hide_effects()
	_set_background_state(true, false)
	_update_role_text()
	_update_hud()
	_update_instruction("Inspect the well to begin.")
	_close_sidekick_panels()
	_populate_ledger()
	_hide_rage_bait()
	_refresh_role_visibility()
	if is_instance_valid(back_button):
		back_button.visible = false
		back_button.disabled = true


func _auto_start_intro() -> void:
	if _phase != Phase.IDLE or _clue_collected:
		return
	start_intro()


func _on_well_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _phase == Phase.IDLE and _is_click_event(event):
		start_intro()


func start_intro() -> void:
	if _phase != Phase.IDLE:
		return
	if _has_multiplayer() and not multiplayer.is_server():
		rpc_request_start_intro.rpc_id(SERVER_PEER_ID)
	else:
		_server_start_intro()


@rpc("any_peer", "reliable")
func rpc_request_start_intro() -> void:
	if multiplayer.is_server():
		_server_start_intro()


func _server_start_intro() -> void:
	_phase = Phase.INTRO
	_intro_index = 0
	_mistakes = 0
	_bucket_progress = 0
	_server_sync_state()
	_server_feedback("Siyokoy waits in the Old Well.", false)


func advance_intro() -> void:
	if _phase != Phase.INTRO:
		return
	if _has_multiplayer() and not multiplayer.is_server():
		rpc_request_advance_intro.rpc_id(SERVER_PEER_ID)
	else:
		_server_advance_intro()


@rpc("any_peer", "reliable")
func rpc_request_advance_intro() -> void:
	if multiplayer.is_server():
		_server_advance_intro()


func _server_advance_intro() -> void:
	if _phase != Phase.INTRO:
		return
	_intro_index += 1
	if _intro_index >= INTRO_LINES.size():
		if _has_multiplayer():
			rpc_play_game_transition.rpc()
		else:
			rpc_play_game_transition()
		await get_tree().create_timer(0.75, true).timeout
		_server_start_puzzle_1()
	else:
		_server_sync_state()


func _server_start_puzzle_1() -> void:
	_phase = Phase.PUZZLE_1
	_puzzle1_correct = 0
	_active_answer_role = GameState.Role.SIDEKICK
	_last_pass_msec = 0
	_roman_sequence = ROMAN_QUESTIONS.duplicate(true)
	_roman_index = 0
	_pick_next_roman()
	_server_sync_state()


func _pick_next_roman() -> void:
	if _roman_sequence.is_empty():
		_roman_sequence = ROMAN_QUESTIONS.duplicate(true)
	if _roman_index >= _roman_sequence.size():
		_roman_index = 0
	_current_roman = (_roman_sequence[_roman_index] as Dictionary).duplicate(true)
	_roman_index += 1


func submit_puzzle_1_answer() -> void:
	if _phase != Phase.PUZZLE_1:
		return
	if not _can_current_answerer_act():
		_local_feedback("It is " + _role_turn_text(_active_answer_role) + " turn now.", true)
		return
	if not is_instance_valid(number_input):
		return
	var text: String = number_input.text.strip_edges()
	if not text.is_valid_int():
		_local_feedback("Enter a number first.", true)
		return
	var answer: int = int(text)
	if _has_multiplayer() and not multiplayer.is_server():
		if not _try_consume_action_cooldown():
			return
		rpc_request_puzzle_1_answer.rpc_id(SERVER_PEER_ID, answer)
	else:
		_server_handle_puzzle_1(answer)


func pass_puzzle_1_question() -> void:
	if _phase != Phase.PUZZLE_1:
		return
	if not _can_current_answerer_act():
		_local_feedback("Only " + _role_turn_text(_active_answer_role) + " can pass.", true)
		return
	if _has_multiplayer() and not multiplayer.is_server():
		rpc_request_pass_puzzle_1.rpc_id(SERVER_PEER_ID)
	else:
		_server_pass_puzzle_1()


@rpc("any_peer", "reliable")
func rpc_request_pass_puzzle_1() -> void:
	if multiplayer.is_server():
		_server_pass_puzzle_1(multiplayer.get_remote_sender_id())


func _server_pass_puzzle_1(sender_id: int = SERVER_PEER_ID) -> void:
	if _phase != Phase.PUZZLE_1 or _fail_started:
		return
	if not _is_sender_active_answerer(sender_id):
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_pass_msec < 350:
		return
	_last_pass_msec = now_msec
	_toggle_answer_role()
	_server_sync_state()
	_server_feedback(_role_turn_text(_active_answer_role) + "'s Turn", false)


func _on_number_submitted(_text: String) -> void:
	submit_puzzle_1_answer()


func _on_number_changed(text: String) -> void:
	if not _can_current_answerer_act():
		return
	var digits: String = ""
	for i in range(text.length()):
		var c: String = text.substr(i, 1)
		if c.is_valid_int():
			digits += c
	if digits != text and is_instance_valid(number_input):
		var caret: int = number_input.caret_column
		number_input.text = digits
		number_input.caret_column = mini(caret, digits.length())


@rpc("any_peer", "reliable")
func rpc_request_puzzle_1_answer(answer: int) -> void:
	if multiplayer.is_server():
		_server_handle_puzzle_1(answer, multiplayer.get_remote_sender_id())


func _server_handle_puzzle_1(answer: int, sender_id: int = SERVER_PEER_ID) -> void:
	if _phase != Phase.PUZZLE_1 or _current_roman.is_empty() or _fail_started:
		return
	if not _is_sender_active_answerer(sender_id):
		return
	if not _try_consume_server_answer_cooldown():
		return
	if answer == int(_current_roman.get("answer", -1)):
		_puzzle1_correct += 1
		_bucket_progress = clampi(_puzzle1_correct, 0, PUZZLE_1_TARGET)
		if _puzzle1_correct >= PUZZLE_1_TARGET:
			_bucket_progress = TOTAL_BUCKET_STEPS
			_server_sync_state()
			_broadcast_rage_bait(RageBaitKind.WIN)
			_server_feedback("The bucket breaks the surface. The clue is yours.", false)
			_broadcast_correct_effect()
			await get_tree().create_timer(0.7, true).timeout
			_server_show_reward()
		else:
			_toggle_answer_role()
			_pick_next_roman()
			_server_sync_state()
			_broadcast_rage_bait(RageBaitKind.CORRECT)
			_server_feedback("Correct. The bucket climbs from the deep.", false)
			_broadcast_correct_effect()
	else:
		_broadcast_rage_bait(RageBaitKind.WRONG)
		_server_register_mistake("Siyokoy laughs. The water pulls closer.")


func _toggle_answer_role() -> void:
	_active_answer_role = GameState.Role.DETECTIVE if _active_answer_role == GameState.Role.SIDEKICK else GameState.Role.SIDEKICK


func _server_start_puzzle_2() -> void:
	if _fail_started:
		return
	_phase = Phase.PUZZLE_2
	_chain_rings = CHAIN_RING_SET.duplicate(true)
	_chain_rings.shuffle()
	_chain_slots = [-1, -1, -1, -1]
	_selected_chain_ring = -1
	_bucket_progress = max(_bucket_progress, PUZZLE_1_TARGET)
	_server_sync_state()
	_server_feedback("Puzzle 2: order the rings from smallest to largest.", false)


func select_chain_ring(index: int) -> void:
	if _phase != Phase.PUZZLE_2:
		return
	if not _can_sidekick_act():
		_local_feedback("Only the Sidekick can move rings.", true)
		return
	if index < 0 or index >= _chain_rings.size() or _chain_slots.has(index):
		return
	_selected_chain_ring = index
	_refresh_chain_ui()


func select_chain_slot(index: int) -> void:
	if _phase != Phase.PUZZLE_2 or _selected_chain_ring < 0:
		return
	if not _can_sidekick_act():
		_local_feedback("Only the Sidekick can move rings.", true)
		return
	if _has_multiplayer() and not multiplayer.is_server():
		rpc_request_chain_placement.rpc_id(SERVER_PEER_ID, _selected_chain_ring, index)
	else:
		_server_place_chain_ring(_selected_chain_ring, index)
	_selected_chain_ring = -1


@rpc("any_peer", "reliable")
func rpc_request_chain_placement(ring_index: int, slot_index: int) -> void:
	if multiplayer.is_server():
		_server_place_chain_ring(ring_index, slot_index)


func _server_place_chain_ring(ring_index: int, slot_index: int) -> void:
	if _phase != Phase.PUZZLE_2 or _fail_started:
		return
	if ring_index < 0 or ring_index >= _chain_rings.size() or slot_index < 0 or slot_index >= _chain_slots.size():
		return
	for i in range(_chain_slots.size()):
		if _chain_slots[i] == ring_index:
			_chain_slots[i] = -1
	_chain_slots[slot_index] = ring_index
	_server_sync_state()


func check_chain_order() -> void:
	if _phase != Phase.PUZZLE_2:
		return
	if not _can_sidekick_act():
		_local_feedback("Only the Sidekick checks the chain.", true)
		return
	if _has_multiplayer() and not multiplayer.is_server():
		if not _try_consume_action_cooldown():
			return
		rpc_request_check_chain.rpc_id(SERVER_PEER_ID)
	else:
		_server_check_chain()


@rpc("any_peer", "reliable")
func rpc_request_check_chain() -> void:
	if multiplayer.is_server():
		_server_check_chain()


func _server_check_chain() -> void:
	if _phase != Phase.PUZZLE_2 or _fail_started:
		return
	if _chain_slots.has(-1):
		_server_feedback("Fill every chain slot before checking.", true)
		return
	if not _try_consume_server_answer_cooldown():
		return
	var previous: int = -999999
	for ring_index in _chain_slots:
		var value: int = int((_chain_rings[ring_index] as Dictionary).get("answer", 0))
		if value < previous:
			_broadcast_rage_bait(RageBaitKind.WRONG)
			_server_register_mistake("The chain order is wrong. The water climbs.")
			return
		previous = value
	_bucket_progress = max(_bucket_progress, PUZZLE_1_TARGET + 1)
	_server_sync_state()
	_broadcast_rage_bait(RageBaitKind.CORRECT)
	_server_feedback("The chain loosens. The bucket reaches the top.", false)
	_broadcast_correct_effect()
	await get_tree().create_timer(0.6, true).timeout
	_server_start_puzzle_3()


func _server_start_puzzle_3() -> void:
	if _fail_started:
		return
	_phase = Phase.PUZZLE_3
	_eye_order = EYE_ORDER.duplicate()
	_eye_order.shuffle()
	_eye_slots = [-1, -1, -1, -1, -1, -1]
	_selected_eye_piece = -1
	_server_sync_state()
	_server_feedback("Puzzle 3: restore the broken Eye Clue.", false)


func select_eye_piece(index: int) -> void:
	if _phase != Phase.PUZZLE_3:
		return
	if not _can_sidekick_act():
		_local_feedback("Only the Sidekick arranges the pieces.", true)
		return
	if index < 0 or index >= _eye_order.size():
		return
	var piece: int = int(_eye_order[index])
	if _eye_slots.has(piece):
		return
	_selected_eye_piece = piece
	_refresh_eye_ui()


func select_eye_slot(index: int) -> void:
	if _phase != Phase.PUZZLE_3 or _selected_eye_piece < 0:
		return
	if not _can_sidekick_act():
		_local_feedback("Only the Sidekick arranges the pieces.", true)
		return
	if _has_multiplayer() and not multiplayer.is_server():
		rpc_request_eye_placement.rpc_id(SERVER_PEER_ID, _selected_eye_piece, index)
	else:
		_server_place_eye_piece(_selected_eye_piece, index)
	_selected_eye_piece = -1


@rpc("any_peer", "reliable")
func rpc_request_eye_placement(piece: int, slot_index: int) -> void:
	if multiplayer.is_server():
		_server_place_eye_piece(piece, slot_index)


func _server_place_eye_piece(piece: int, slot_index: int) -> void:
	if _phase != Phase.PUZZLE_3 or _fail_started:
		return
	if not EYE_ORDER.has(piece) or slot_index < 0 or slot_index >= _eye_slots.size():
		return
	for i in range(_eye_slots.size()):
		if _eye_slots[i] == piece:
			_eye_slots[i] = -1
	_eye_slots[slot_index] = piece
	_server_sync_state()


func check_eye_puzzle() -> void:
	if _phase != Phase.PUZZLE_3:
		return
	if not _can_sidekick_act():
		_local_feedback("Only the Sidekick checks the image.", true)
		return
	if _has_multiplayer() and not multiplayer.is_server():
		if not _try_consume_action_cooldown():
			return
		rpc_request_check_eye.rpc_id(SERVER_PEER_ID)
	else:
		_server_check_eye()


@rpc("any_peer", "reliable")
func rpc_request_check_eye() -> void:
	if multiplayer.is_server():
		_server_check_eye()


func _server_check_eye() -> void:
	if _phase != Phase.PUZZLE_3 or _fail_started:
		return
	if _eye_slots.has(-1):
		_server_feedback("Place all six pieces before checking.", true)
		return
	if not _try_consume_server_answer_cooldown():
		return
	for i in range(EYE_ORDER.size()):
		if int(_eye_slots[i]) != int(EYE_ORDER[i]):
			_broadcast_rage_bait(RageBaitKind.WRONG)
			_server_register_mistake("The eye is still broken. Siyokoy laughs.")
			return
	_bucket_progress = TOTAL_BUCKET_STEPS
	_server_sync_state()
	_broadcast_rage_bait(RageBaitKind.CORRECT)
	_server_feedback("The Eye Clue is restored.", false)
	_broadcast_correct_effect()
	await get_tree().create_timer(0.6, true).timeout
	_server_show_reward()


func _server_register_mistake(message: String) -> void:
	if _phase in [Phase.FAILED, Phase.COMPLETE] or _fail_started:
		return
	_mistakes = clampi(_mistakes + 1, 0, MAX_MISTAKES)
	_server_sync_state()
	_server_feedback(message, true)
	_broadcast_wrong_effect()
	if _mistakes >= MAX_MISTAKES:
		_fail_started = true
		await get_tree().create_timer(0.5, true).timeout
		_phase = Phase.FAILED
		_server_sync_state()
		_broadcast_drowning_fail()


func _broadcast_wrong_effect() -> void:
	if _has_multiplayer():
		rpc_play_wrong_effect.rpc()
	else:
		rpc_play_wrong_effect()


func _broadcast_correct_effect() -> void:
	if _has_multiplayer():
		rpc_play_correct_effect.rpc()
	else:
		rpc_play_correct_effect()


func _broadcast_drowning_fail() -> void:
	if _has_multiplayer():
		rpc_trigger_drowning_fail.rpc()
	else:
		rpc_trigger_drowning_fail()


@rpc("authority", "reliable", "call_local")
func rpc_trigger_drowning_fail() -> void:
	_phase = Phase.FAILED
	_apply_phase_visibility()
	_update_hud()
	await _play_drowning_fail()
	_return_to_forest()


func _server_show_reward() -> void:
	_phase = Phase.REWARD
	_reward_stage = 0
	_waiting_reward_tap = true
	_collect_started = false
	if GameState:
		GameState.set_puzzle_solved(ZONE_ID, true)
	_server_sync_state()


func _on_reward_tap_pressed() -> void:
	if _phase != Phase.REWARD or not _waiting_reward_tap:
		return
	_reward_stage += 1
	if _reward_stage == 1:
		_set_reward_text("Eye Clue Acquired")
	elif _reward_stage == 2:
		_set_reward_text("The restored eye watches from the broken image.")
	else:
		_waiting_reward_tap = false
		_refresh_reward_ui()


func collect_reward() -> void:
	if _phase != Phase.REWARD or _collect_started:
		return
	if not _can_sidekick_act():
		_local_feedback("The Sidekick keeps the briefcase.", true)
		return
	_collect_started = true
	_refresh_reward_ui()
	if not _has_multiplayer():
		rpc_show_briefcase_reveal_then_finalize()
	elif multiplayer.is_server():
		rpc_show_briefcase_reveal_then_finalize.rpc()
	else:
		rpc_request_collect_reward.rpc_id(SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_collect_reward() -> void:
	if multiplayer.is_server():
		rpc_show_briefcase_reveal_then_finalize.rpc()


@rpc("authority", "reliable", "call_local")
func rpc_show_briefcase_reveal_then_finalize() -> void:
	_hide_reward_for_briefcase()
	if is_instance_valid(briefcase_reveal):
		var reveal: Texture2D = GameState.get_briefcase_texture("old_well_reveal") if GameState else null
		briefcase_reveal.texture = reveal
		briefcase_reveal.visible = reveal != null
	await get_tree().create_timer(1.5).timeout
	if not _has_multiplayer():
		rpc_finalize_clue()
	elif multiplayer.is_server():
		rpc_finalize_clue.rpc()


@rpc("authority", "reliable", "call_local")
func rpc_finalize_clue() -> void:
	if _phase == Phase.COMPLETE:
		return
	if GameState:
		GameState.collect_clue(ZONE_ID)
	_clue_collected = true
	_phase = Phase.COMPLETE
	_vis(reward_layer, false)
	if is_instance_valid(briefcase_reveal):
		briefcase_reveal.visible = false
		briefcase_reveal.texture = null
	await _fade_out(0.6)
	_play_ending_cutscene()
	await _fade_in(0.6)


func _play_ending_cutscene() -> void:
	if not is_instance_valid(ending_cutscene):
		_return_to_forest()
		return
	var dark: Node = get_node_or_null("Cutscene/DarkOverlay")
	var viewport_size := get_viewport().get_visible_rect().size
	if is_instance_valid(dark):
		dark.visible = true
		dark.z_index = 1
		dark.position = Vector2.ZERO
		dark.size = viewport_size

	var margin_x := viewport_size.x * 0.1
	var margin_y := viewport_size.y * 0.1
	ending_cutscene.z_index = 2
	ending_cutscene.visible = true
	ending_cutscene.position = Vector2(margin_x, margin_y)
	ending_cutscene.size = Vector2(
		viewport_size.x - margin_x * 2.0,
		viewport_size.y - margin_y * 2.0
	)
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
	if is_inside_tree():
		GameState.change_to_post_zone_scene(get_tree())


func _server_sync_state() -> void:
	if _has_multiplayer():
		rpc_sync_state.rpc(_phase, _mistakes, _bucket_progress, _intro_index, _puzzle1_correct, _active_answer_role, _current_roman, _chain_rings, _chain_slots, _eye_order, _eye_slots, _reward_stage, _waiting_reward_tap, _collect_started)
	else:
		rpc_sync_state(_phase, _mistakes, _bucket_progress, _intro_index, _puzzle1_correct, _active_answer_role, _current_roman, _chain_rings, _chain_slots, _eye_order, _eye_slots, _reward_stage, _waiting_reward_tap, _collect_started)


@rpc("authority", "reliable", "call_local")
func rpc_sync_state(phase: int, mistakes: int, bucket_progress: int, intro_index: int, puzzle1_correct: int, active_answer_role: int, current_roman: Dictionary, chain_rings: Array, chain_slots: Array, eye_order: Array, eye_slots: Array, reward_stage: int, waiting_reward_tap: bool, collect_started: bool) -> void:
	var previous_phase: int = _phase
	_phase = phase
	_mistakes = mistakes
	_bucket_progress = bucket_progress
	_intro_index = intro_index
	_puzzle1_correct = puzzle1_correct
	_active_answer_role = active_answer_role
	_current_roman = current_roman.duplicate(true)
	_chain_rings = chain_rings.duplicate(true)
	_chain_slots = _to_int_array(chain_slots)
	_eye_order = _to_int_array(eye_order)
	_eye_slots = _to_int_array(eye_slots)
	_reward_stage = reward_stage
	_waiting_reward_tap = waiting_reward_tap
	_collect_started = collect_started
	_apply_phase_visibility()
	_update_role_text()
	_update_hud()
	_refresh_current_ui()
	if phase == Phase.REWARD and previous_phase != Phase.REWARD:
		_play_zone_completion_sfx()


func _server_feedback(message: String, is_error: bool) -> void:
	if _has_multiplayer():
		rpc_show_feedback.rpc(message, is_error, _phase)
	else:
		rpc_show_feedback(message, is_error, _phase)


@rpc("authority", "reliable", "call_local")
func rpc_show_feedback(message: String, is_error: bool, phase: int) -> void:
	_feedback_for_phase(phase, message, is_error)


@rpc("authority", "reliable", "call_local")
func rpc_play_wrong_effect() -> void:
	_play_wrong_effect()


@rpc("authority", "reliable", "call_local")
func rpc_play_correct_effect() -> void:
	_play_correct_effect()


@rpc("authority", "reliable", "call_local")
func rpc_play_opening_emerge() -> void:
	_set_background_state(true, false)
	var dialogue_panel_node: CanvasItem = get_node_or_null("DialogueLayer") as CanvasItem
	if is_instance_valid(dialogue_panel_node):
		dialogue_panel_node.visible = false
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if is_instance_valid(intro_water_sprite):
		intro_water_sprite.visible = true
		intro_water_sprite.modulate.a = 0.25
		var water_start_pos: Vector2 = intro_water_sprite.position
		var water_start_scale: Vector2 = intro_water_sprite.scale
		tween.tween_property(intro_water_sprite, "position", water_start_pos - Vector2(0, 42), 0.18)
		tween.tween_property(intro_water_sprite, "scale", water_start_scale * 1.28, 0.18)
		tween.tween_property(intro_water_sprite, "modulate:a", 1.0, 0.12)
		tween.tween_property(intro_water_sprite, "position", water_start_pos, 0.45).set_delay(0.22)
		tween.tween_property(intro_water_sprite, "scale", water_start_scale, 0.45).set_delay(0.22)
	if is_instance_valid(intro_siyokoy_sprite):
		intro_siyokoy_sprite.visible = true
		var siyokoy_target_pos: Vector2 = intro_siyokoy_sprite.position
		intro_siyokoy_sprite.position = siyokoy_target_pos + Vector2(0, 92)
		intro_siyokoy_sprite.modulate.a = 0.0
		tween.tween_property(intro_siyokoy_sprite, "position", siyokoy_target_pos, 1.05).set_delay(0.18)
		tween.tween_property(intro_siyokoy_sprite, "modulate:a", 1.0, 0.75).set_delay(0.18)
	if is_instance_valid(intro_old_well):
		var intro_start_pos: Vector2 = intro_old_well.position
		tween.tween_property(intro_old_well, "position", intro_start_pos + Vector2(7, -3), 0.05)
		tween.tween_property(intro_old_well, "position", intro_start_pos + Vector2(-6, 3), 0.05).set_delay(0.05)
		tween.tween_property(intro_old_well, "position", intro_start_pos, 0.08).set_delay(0.10)
	await tween.finished
	await get_tree().create_timer(0.16, true).timeout
	if is_instance_valid(dialogue_panel_node):
		dialogue_panel_node.visible = true


@rpc("authority", "reliable", "call_local")
func rpc_play_game_transition() -> void:
	if not is_instance_valid(correct_overlay):
		return
	correct_overlay.visible = true
	correct_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(correct_overlay, "color:a", 0.72, 0.25)
	tween.tween_property(correct_overlay, "color:a", 0.0, 0.45)
	tween.finished.connect(func(): _vis(correct_overlay, false))


func _apply_phase_visibility() -> void:
	_hide_phase_layers()
	match _phase:
		Phase.IDLE:
			_set_background_state(true, false)
			_update_instruction("The well is still. Siyokoy waits below.")
		Phase.INTRO:
			_set_background_state(true, false)
			_vis(dialogue_layer, true)
			_update_instruction("Tap anywhere to continue Siyokoy's dialogue.")
		Phase.PUZZLE_1:
			_set_background_state(false, true)
			_vis(puzzle1_layer, true)
			_update_instruction("")
		Phase.PUZZLE_2:
			_set_background_state(false, true)
			_vis(puzzle2_layer, true)
			_update_instruction("Arrange the chain from smallest to largest.")
		Phase.PUZZLE_3:
			_set_background_state(false, true)
			_vis(puzzle3_layer, true)
			_update_instruction("Restore the Eye image using the Detective's reflection.")
		Phase.REWARD:
			_set_background_state(false, true)
			_vis(reward_layer, true)
			_update_instruction("Collect the Eye Clue.")
		Phase.FAILED:
			_set_background_state(false, true)
			_update_instruction("The well pulls the players under.")
		Phase.COMPLETE:
			_set_background_state(false, true)
			_update_instruction("The Eye Clue is safe.")
	_refresh_role_visibility()
	if _phase not in [Phase.PUZZLE_1, Phase.PUZZLE_2, Phase.PUZZLE_3]:
		_hide_rage_bait()


func _refresh_role_visibility() -> void:
	if _phase == Phase.PUZZLE_1:
		_vis(detective_roman_view, true)
		_vis(sidekick_answer_panel, true)
	elif _phase == Phase.PUZZLE_2:
		_vis(detective_chain_view, _is_detective_view())
		_vis(sidekick_order_panel, _is_sidekick_view())
	elif _phase == Phase.PUZZLE_3:
		_vis(detective_reflection_panel, _is_detective_view())
		_vis(sidekick_puzzle_panel, _is_sidekick_view())
	if _phase in [Phase.IDLE, Phase.INTRO, Phase.REWARD, Phase.FAILED, Phase.COMPLETE]:
		_close_sidekick_panels()
	if is_instance_valid(inside_zone_control):
		var sidekick_only: bool = GameState.local_role == GameState.Role.SIDEKICK
		if inside_zone_control.has_method("set_pause_enabled"):
			inside_zone_control.set_pause_enabled(true)
		if inside_zone_control.has_method("set_ledger_enabled"):
			inside_zone_control.set_ledger_enabled(sidekick_only)
		if inside_zone_control.has_method("set_briefcase_enabled"):
			inside_zone_control.set_briefcase_enabled(sidekick_only)
		if inside_zone_control.has_method("set_sidekick_ui_visible"):
			inside_zone_control.set_sidekick_ui_visible(sidekick_only)


func _refresh_current_ui() -> void:
	match _phase:
		Phase.INTRO:
			_refresh_intro_ui()
		Phase.PUZZLE_1:
			_refresh_puzzle1_ui()
		Phase.PUZZLE_2:
			_refresh_chain_ui()
		Phase.PUZZLE_3:
			_refresh_eye_ui()
		Phase.REWARD:
			_refresh_reward_ui()
	_update_bucket_visual()


func _refresh_intro_ui() -> void:
	var index: int = clampi(_intro_index, 0, INTRO_LINES.size() - 1)
	var line: Dictionary = INTRO_LINES[index]
	if is_instance_valid(dialogue_label):
		dialogue_label.text = str(line.get("text", ""))
	if is_instance_valid(dialogue_prompt_label):
		dialogue_prompt_label.text = "Tap anywhere to continue."
	if is_instance_valid(continue_button):
		continue_button.visible = true
		continue_button.disabled = false


func _refresh_puzzle1_ui() -> void:
	var roman: String = str(_current_roman.get("roman", "?"))
	var can_act: bool = _can_current_answerer_act()
	if is_instance_valid(detective_hint_label):
		detective_hint_label.text = roman
	if is_instance_valid(roman_plaque):
		roman_plaque.visible = false
	if is_instance_valid(roman_guide_label):
		roman_guide_label.text = "Siyokoy's Game"
	if is_instance_valid(_puzzle1_instruction_label):
		_puzzle1_instruction_label.text = "Turn the Roman numeral into a number."
	if is_instance_valid(sidekick_hint_label):
		sidekick_hint_label.text = "Your Turn" if can_act else _role_turn_text(_active_answer_role) + "'s Turn"
		sidekick_hint_label.add_theme_color_override("font_color", UI_GREEN)
	if is_instance_valid(submit_number_button):
		submit_number_button.text = "Check"
		_set_control_interactive(submit_number_button, can_act)
	if is_instance_valid(_pass_button):
		_pass_button.visible = true
		_pass_button.text = "Pass"
		_set_control_interactive(_pass_button, can_act)
	if is_instance_valid(number_input):
		number_input.placeholder_text = "Enter Answer"
		_set_line_edit_interactive(number_input, can_act)
		if can_act:
			number_input.clear()


func _refresh_chain_ui() -> void:
	var texts: Array[String] = []
	for ring in _chain_rings:
		texts.append(str((ring as Dictionary).get("roman", "?")))
	if is_instance_valid(chain_instruction_label):
		chain_instruction_label.text = "Rings in the well: " + ", ".join(texts)
	if is_instance_valid(order_instruction_label):
		order_instruction_label.text = "Tap a ring, then a slot. Check only after all slots are filled."
	for i in range(_chain_displays.size()):
		_set_texture_label(_chain_displays[i], _chain_text(i))
	for i in range(_chain_choice_buttons.size()):
		var button: BaseButton = _chain_choice_buttons[i]
		_set_button_label(button, _chain_text(i))
		if is_instance_valid(button):
			var used: bool = _chain_slots.has(i)
			button.disabled = not _can_sidekick_act() or used
			button.modulate = UI_MUTED if used else (UI_GOLD if i == _selected_chain_ring else Color.WHITE)
	for i in range(_chain_slot_buttons.size()):
		var ring_index: int = int(_chain_slots[i])
		_set_button_label(_chain_slot_buttons[i], "Slot %d" % (i + 1) if ring_index < 0 else _chain_text(ring_index))
		if is_instance_valid(_chain_slot_buttons[i]):
			_chain_slot_buttons[i].disabled = not _can_sidekick_act()
	if is_instance_valid(check_chain_button):
		check_chain_button.text = "Check Chain"
		check_chain_button.disabled = not _can_sidekick_act()


func _refresh_eye_ui() -> void:
	if is_instance_valid(reflection_title_label):
		reflection_title_label.text = "Complete Eye Reflection"
	if is_instance_valid(reflection_hint_label):
		reflection_hint_label.text = "Guide your partner: top row 1-3, bottom row 4-6."
	if is_instance_valid(puzzle_title_label):
		puzzle_title_label.text = "Broken Eye Pieces"
	for i in range(_eye_piece_buttons.size()):
		var piece := int(_eye_order[i]) if i < _eye_order.size() else i + 1
		_set_button_label(_eye_piece_buttons[i], "Piece %d" % piece)
		if is_instance_valid(_eye_piece_buttons[i]):
			var used := _eye_slots.has(piece)
			_eye_piece_buttons[i].disabled = not _can_sidekick_act() or used
			_eye_piece_buttons[i].modulate = UI_MUTED if used else (UI_GOLD if piece == _selected_eye_piece else Color.WHITE)
	for i in range(_eye_slot_buttons.size()):
		var placed: int = int(_eye_slots[i])
		_set_button_label(_eye_slot_buttons[i], "Slot %d" % (i + 1) if placed < 0 else "Piece %d" % placed)
		if is_instance_valid(_eye_slot_buttons[i]):
			_eye_slot_buttons[i].disabled = not _can_sidekick_act()
	if is_instance_valid(check_puzzle_button):
		check_puzzle_button.text = "Check Eye"
		check_puzzle_button.disabled = not _can_sidekick_act()


func _refresh_reward_ui() -> void:
	if is_instance_valid(reward_dark):
		reward_dark.modulate.a = 0.48
	if is_instance_valid(reward_banner):
		reward_banner.text = "ARTIFACT FOUND!"
	for node in [clue_sprite, sparkle, reward_banner]:
		_vis(node, true)
	if _reward_stage <= 1:
		_set_reward_text("Eye Clue Acquired")
	elif _reward_stage == 2:
		_set_reward_text("The restored eye watches from the broken image.")
	else:
		_set_reward_text("")
	if is_instance_valid(tap_catcher):
		tap_catcher.visible = _waiting_reward_tap
		tap_catcher.disabled = not _waiting_reward_tap
	if is_instance_valid(tap_instruction):
		tap_instruction.visible = _waiting_reward_tap
		tap_instruction.text = "Tap anywhere to continue."
	if is_instance_valid(collect_button):
		var can_collect: bool = not _waiting_reward_tap and _can_sidekick_act() and not _collect_started
		collect_button.visible = can_collect
		collect_button.disabled = not can_collect
		collect_button.text = "Collect Artifact"


func _set_reward_text(text: String) -> void:
	var reward_panel: CanvasItem = get_node_or_null("RewardLayer/RewardPanel") as CanvasItem
	if is_instance_valid(reward_panel):
		reward_panel.visible = not text.is_empty()
	if is_instance_valid(reward_text):
		reward_text.text = text


func _hide_reward_for_briefcase() -> void:
	for node in [clue_sprite, sparkle, reward_banner, tap_instruction, tap_catcher, collect_button, get_node_or_null("RewardLayer/RewardPanel")]:
		_vis(node, false)
	if is_instance_valid(reward_text):
		reward_text.text = ""
	if is_instance_valid(tap_catcher):
		tap_catcher.disabled = true
	if is_instance_valid(collect_button):
		collect_button.disabled = true


func _hide_phase_layers() -> void:
	for layer in [dialogue_layer, puzzle1_layer, puzzle2_layer, puzzle3_layer, reward_layer]:
		_vis(layer, false)


func _hide_effects() -> void:
	for node in [water_splash, blur_overlay, drowning_overlay, correct_overlay]:
		_vis(node, false)


func _update_role_text() -> void:
	if is_instance_valid(role_label):
		if not _has_multiplayer() and GameState.local_role == GameState.Role.NONE:
			role_label.text = "Role: SOLO TEST"
		else:
			role_label.text = "Role: " + GameState.get_role_display_text()


func _update_hud() -> void:
	if is_instance_valid(status_label):
		status_label.text = _phase_name(_phase)
	if is_instance_valid(progress_label):
		progress_label.text = "Series: %d / %d" % [_bucket_progress, TOTAL_BUCKET_STEPS]
	_update_life_hearts()
	if is_instance_valid(lives_label):
		var game_phase: bool = _phase in [Phase.PUZZLE_1, Phase.PUZZLE_2, Phase.PUZZLE_3]
		if game_phase and (_heart_icons.is_empty() or _heart_full_texture == null or _heart_empty_texture == null):
			lives_label.visible = true
			lives_label.text = "Lives: %d / %d" % [clampi(MAX_MISTAKES - _mistakes, 0, MAX_MISTAKES), MAX_MISTAKES]
		else:
			lives_label.visible = false


func _update_instruction(text: String) -> void:
	if is_instance_valid(instruction_label):
		instruction_label.text = text


func _update_life_hearts() -> void:
	var remaining: int = clampi(MAX_MISTAKES - _mistakes, 0, MAX_MISTAKES)
	var game_phase: bool = _phase in [Phase.PUZZLE_1, Phase.PUZZLE_2, Phase.PUZZLE_3]
	var can_use_textures: bool = game_phase and _heart_full_texture != null and _heart_empty_texture != null and not _heart_icons.is_empty()
	if is_instance_valid(_hearts_container):
		_hearts_container.visible = can_use_textures
	if not can_use_textures:
		return
	for i in range(_heart_icons.size()):
		var heart: TextureRect = _heart_icons[i]
		if is_instance_valid(heart):
			heart.texture = _heart_full_texture if i < remaining else _heart_empty_texture


func _update_bucket_visual() -> void:
	if not is_instance_valid(bucket_sprite):
		return
	var lift: float = 120.0 * (float(_bucket_progress) / float(TOTAL_BUCKET_STEPS))
	bucket_sprite.position = _bucket_start - Vector2(0, lift)


func _set_background_state(show_intro: bool, show_game: bool) -> void:
	_vis(legacy_background, true)
	_vis(intro_old_well, show_intro)
	_vis(siyokoys_game_background, show_game)
	_vis(legacy_well_sprite, false)
	_vis(siyokoy_sprite, false)
	_vis(bucket_sprite, false)
	_vis(intro_water_sprite, false)
	_vis(intro_siyokoy_sprite, false)
	if is_instance_valid(game_siyokoy_well):
		game_siyokoy_well.visible = show_game


func _feedback_for_phase(phase: int, message: String, is_error: bool) -> void:
	var label: Label = null
	match phase:
		Phase.PUZZLE_1:
			label = puzzle1_feedback
		Phase.PUZZLE_2:
			label = puzzle2_feedback
		Phase.PUZZLE_3:
			label = puzzle3_feedback
	if not is_instance_valid(label):
		label = instruction_label
	if is_instance_valid(label):
		label.text = message
		label.add_theme_color_override("font_color", UI_RED if is_error else UI_GREEN)


func _local_feedback(message: String, is_error: bool) -> void:
	_feedback_for_phase(_phase, message, is_error)


func _try_consume_action_cooldown() -> bool:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_action_msec < ACTION_COOLDOWN_MSEC:
		return false
	_last_action_msec = now_msec
	return true


func _try_consume_server_answer_cooldown() -> bool:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_server_answer_msec < ACTION_COOLDOWN_MSEC:
		return false
	_last_server_answer_msec = now_msec
	return true


func _setup_rage_bait() -> void:
	_hide_rage_bait()
	if is_instance_valid(rage_bait_label):
		if _font:
			rage_bait_label.add_theme_font_override("font", _font)
		rage_bait_label.add_theme_font_size_override("font_size", 18)
		rage_bait_label.add_theme_color_override("font_color", RAGE_BAIT_INK)
		rage_bait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rage_bait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rage_bait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _hide_rage_bait() -> void:
	if is_instance_valid(_rage_bait_tween):
		_rage_bait_tween.kill()
		_rage_bait_tween = null
	if is_instance_valid(rage_bait_bubble):
		rage_bait_bubble.visible = false
		rage_bait_bubble.modulate = Color.WHITE
		rage_bait_bubble.scale = Vector2.ONE


func _pick_rage_bait_line(kind: int) -> String:
	match kind:
		RageBaitKind.WIN:
			return RAGE_BAIT_WIN_LINES[_rng.randi_range(0, RAGE_BAIT_WIN_LINES.size() - 1)]
		RageBaitKind.WRONG:
			return RAGE_BAIT_WRONG_LINES[_rng.randi_range(0, RAGE_BAIT_WRONG_LINES.size() - 1)]
		_:
			return RAGE_BAIT_CORRECT_LINES[_rng.randi_range(0, RAGE_BAIT_CORRECT_LINES.size() - 1)]


func _show_rage_bait(line: String) -> void:
	if _phase not in [Phase.PUZZLE_1, Phase.PUZZLE_2, Phase.PUZZLE_3]:
		return
	if not is_instance_valid(rage_bait_bubble) or not is_instance_valid(rage_bait_label):
		return
	if is_instance_valid(_rage_bait_tween):
		_rage_bait_tween.kill()
	rage_bait_label.text = line
	rage_bait_bubble.visible = true
	rage_bait_bubble.modulate = Color(1, 1, 1, 0)
	rage_bait_bubble.scale = Vector2(0.92, 0.92)
	_rage_bait_tween = create_tween()
	_rage_bait_tween.set_trans(Tween.TRANS_BACK)
	_rage_bait_tween.set_ease(Tween.EASE_OUT)
	_rage_bait_tween.tween_property(rage_bait_bubble, "modulate:a", 1.0, 0.16)
	_rage_bait_tween.parallel().tween_property(rage_bait_bubble, "scale", Vector2.ONE, 0.16)
	_rage_bait_tween.tween_interval(RAGE_BAIT_VISIBLE_SECONDS)
	_rage_bait_tween.tween_property(rage_bait_bubble, "modulate:a", 0.0, 0.22)
	_rage_bait_tween.tween_callback(_hide_rage_bait)


func _broadcast_rage_bait(kind: int) -> void:
	var line: String = _pick_rage_bait_line(kind)
	if _has_multiplayer():
		rpc_show_rage_bait.rpc(line)
	else:
		rpc_show_rage_bait(line)


@rpc("authority", "reliable", "call_local")
func rpc_show_rage_bait(line: String) -> void:
	_show_rage_bait(line)


func _play_wrong_effect() -> void:
	_play_heartbreak_effect()
	if is_instance_valid(siyokoy_sprite):
		var attack: Texture2D = _load_texture(TEX_SIYOKOY_ATTACK)
		if attack:
			siyokoy_sprite.texture = attack
	if is_instance_valid(water_splash):
		water_splash.visible = true
		water_splash.modulate.a = 0.0
	if is_instance_valid(blur_overlay):
		blur_overlay.visible = true
		blur_overlay.color.a = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if is_instance_valid(water_splash):
		tween.tween_property(water_splash, "modulate:a", 0.85, 0.12)
		tween.tween_property(water_splash, "modulate:a", 0.0, 0.55).set_delay(0.18)
	if is_instance_valid(blur_overlay):
		tween.tween_property(blur_overlay, "color:a", 0.35, 0.12)
		tween.tween_property(blur_overlay, "color:a", 0.0, 0.55).set_delay(0.18)
	tween.finished.connect(func():
		_vis(water_splash, false)
		_vis(blur_overlay, false)
		if is_instance_valid(siyokoy_sprite):
			var idle: Texture2D = _load_texture(TEX_SIYOKOY_IDLE)
			if idle:
				siyokoy_sprite.texture = idle
	)


func _play_heartbreak_effect() -> void:
	if _heart_icons.is_empty() or _heart_full_texture == null or _heart_empty_texture == null:
		return
	var lost_index: int = clampi(MAX_MISTAKES - _mistakes, 0, _heart_icons.size() - 1)
	var heart: TextureRect = _heart_icons[lost_index]
	if not is_instance_valid(heart):
		return
	heart.visible = true
	heart.texture = _heart_full_texture
	heart.modulate = Color.WHITE
	heart.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(heart, "scale", Vector2(1.28, 1.28), 0.10)
	tween.tween_property(heart, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.10)
	tween.tween_property(heart, "scale", Vector2(0.82, 0.82), 0.12).set_delay(0.10)
	tween.tween_property(heart, "modulate:a", 0.45, 0.12).set_delay(0.10)
	tween.finished.connect(func():
		if is_instance_valid(heart):
			heart.texture = _heart_empty_texture
			heart.modulate = Color.WHITE
			heart.scale = Vector2.ONE
	)


func _play_correct_effect() -> void:
	if not is_instance_valid(correct_overlay):
		return
	correct_overlay.visible = true
	correct_overlay.color.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(correct_overlay, "color:a", 0.22, 0.15)
	tween.tween_property(correct_overlay, "color:a", 0.0, 0.35)
	tween.finished.connect(func(): _vis(correct_overlay, false))


func _play_drowning_fail() -> void:
	_hide_phase_layers()
	if is_instance_valid(drowning_overlay):
		drowning_overlay.visible = true
		drowning_overlay.color.a = 0.0
	var tween: Tween = create_tween()
	if is_instance_valid(drowning_overlay):
		tween.tween_property(drowning_overlay, "color:a", 0.82, 0.35)
	tween.tween_interval(0.9)
	await tween.finished


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
	var overlay := get_node_or_null("FadeOverlay")
	if not is_instance_valid(overlay):
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "color:a", 0.0, duration)
	await tween.finished
	overlay.queue_free()


func _on_pause_pressed() -> void:
	if is_instance_valid(pause_layer):
		pause_layer.visible = true
	if is_instance_valid(pause_panel):
		pause_panel.visible = true
	if is_instance_valid(option_panel):
		option_panel.visible = false
	if is_instance_valid(inside_zone_control):
		inside_zone_control.visible = false
	if MusicController and MusicController.has_method("pause_music"):
		MusicController.pause_music()
	get_tree().paused = true


func _on_resume_pressed() -> void:
	if is_instance_valid(pause_panel):
		pause_panel.visible = false
	if is_instance_valid(option_panel):
		option_panel.visible = false
	get_tree().paused = false
	if MusicController and MusicController.has_method("resume_music"):
		MusicController.resume_music()
	if is_instance_valid(inside_zone_control):
		inside_zone_control.visible = true


func _on_option_pressed() -> void:
	if is_instance_valid(option_panel):
		option_panel.visible = true
	if is_instance_valid(volume_slider) and MusicController and MusicController.has_method("get_volume"):
		volume_slider.value = MusicController.get_volume() * 100.0
	if is_instance_valid(volume_value):
		volume_value.text = str(int(volume_slider.value)) + "%"


func _on_option_back_pressed() -> void:
	if is_instance_valid(option_panel):
		option_panel.visible = false


func _on_exit_pressed() -> void:
	if is_instance_valid(pause_layer):
		pause_layer.visible = false
	get_tree().paused = false
	if MusicController and MusicController.has_method("resume_music"):
		MusicController.resume_music()
	_return_to_forest()


func _on_volume_changed(value: float) -> void:
	if MusicController and MusicController.has_method("set_volume"):
		MusicController.set_volume(value / 100.0)
	if is_instance_valid(volume_value):
		volume_value.text = str(int(value)) + "%"


func _on_back_pressed() -> void:
	_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	if MusicController and MusicController.has_method("resume_music"):
		MusicController.resume_music()
	if is_inside_tree():
		GameState.change_to_post_zone_scene(get_tree())


func _on_clue_collected(zone_id: String, _data: Dictionary) -> void:
	if zone_id == ZONE_ID:
		_clue_collected = true


func _input(event: InputEvent) -> void:
	if is_instance_valid(ending_cutscene) and ending_cutscene.visible:
		var skip := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
		skip = skip or (event is InputEventScreenTouch and event.pressed)
		if skip:
			_on_cutscene_finished()


func _is_click_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _has_multiplayer() -> bool:
	return multiplayer.has_multiplayer_peer()


func _is_detective_view() -> bool:
	return GameState.local_role == GameState.Role.DETECTIVE or not _has_multiplayer() or GameState.local_role == GameState.Role.NONE


func _is_sidekick_view() -> bool:
	return GameState.local_role == GameState.Role.SIDEKICK or not _has_multiplayer() or GameState.local_role == GameState.Role.NONE


func _can_current_answerer_act() -> bool:
	if _clue_collected or _phase in [Phase.FAILED, Phase.COMPLETE]:
		return false
	if not _has_multiplayer() or GameState.local_role == GameState.Role.NONE:
		return true
	return GameState.local_role == _active_answer_role


func _is_sender_active_answerer(sender_id: int) -> bool:
	if not _has_multiplayer() or GameState.local_role == GameState.Role.NONE:
		return true
	var sender_role: int = GameState.Role.DETECTIVE if sender_id == SERVER_PEER_ID else GameState.Role.SIDEKICK
	return sender_role == _active_answer_role


func _set_control_interactive(control: Control, interactive: bool) -> void:
	if not is_instance_valid(control):
		return
	if control is BaseButton:
		(control as BaseButton).disabled = not interactive
	control.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE


func _set_line_edit_interactive(input: LineEdit, interactive: bool) -> void:
	if not is_instance_valid(input):
		return
	input.editable = interactive
	input.focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	input.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	if not interactive and input.has_focus():
		input.release_focus()


func _role_turn_text(role: int) -> String:
	match role:
		GameState.Role.DETECTIVE:
			return "Detective"
		GameState.Role.SIDEKICK:
			return "Sidekick"
	return "Player"


func _can_sidekick_act() -> bool:
	return _is_sidekick_view() and not _clue_collected and _phase not in [Phase.FAILED, Phase.COMPLETE]


func _phase_name(phase: int) -> String:
	match phase:
		Phase.IDLE: return "Old Well"
		Phase.INTRO: return "Siyokoy's Warning"
		Phase.PUZZLE_1: return "Number Challenge"
		Phase.PUZZLE_2: return "Broken Chain"
		Phase.PUZZLE_3: return "Broken Eye"
		Phase.REWARD: return "Eye Clue unlocked"
		Phase.FAILED: return "Drowning"
		Phase.COMPLETE: return "Old Well complete"
	return "Old Well"


func _chain_text(index: int) -> String:
	if index < 0 or index >= _chain_rings.size():
		return "?"
	return str((_chain_rings[index] as Dictionary).get("roman", "?"))


func _to_int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result


func _ensure_sfx_bus() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		var last := AudioServer.bus_count - 1
		AudioServer.set_bus_name(last, "SFX")
		AudioServer.set_bus_volume_db(last, 0.0)


func _play_zone_completion_sfx() -> void:
	if not is_instance_valid(_sfx_player) or COMPLETION_SFX == null:
		return
	MusicController.pause_music()
	var sfx_stream := COMPLETION_SFX.duplicate()
	if sfx_stream is AudioStreamMP3 or sfx_stream is AudioStreamOggVorbis:
		sfx_stream.loop = false
	_sfx_player.stop()
	_sfx_player.stream = sfx_stream
	_sfx_player.play()
	if not _sfx_player.finished.is_connected(_on_sfx_finished_resume_music):
		_sfx_player.finished.connect(_on_sfx_finished_resume_music, CONNECT_ONE_SHOT)


func _on_sfx_finished_resume_music() -> void:
	MusicController.resume_music()


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _load_font(path: String) -> Font:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Font


func _vis(node: Object, itis_visible: bool) -> void:
	if not is_instance_valid(node):
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = itis_visible
	elif node is CanvasLayer:
		(node as CanvasLayer).visible = itis_visible


func _set_button_label(button: BaseButton, text: String) -> void:
	if not is_instance_valid(button):
		return
	button.tooltip_text = text
	if button is Button:
		(button as Button).text = text
		return
	var label: Label = button.get_node_or_null("FallbackLabel") as Label
	if not is_instance_valid(label):
		label = Label.new()
		label.name = "FallbackLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if _font:
			label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", UI_CREAM)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", UI_INK)
	label.text = text


func _set_texture_label(rect: TextureRect, text: String) -> void:
	if not is_instance_valid(rect):
		return
	var label: Label = rect.get_node_or_null("FallbackLabel") as Label
	if not is_instance_valid(label):
		label = Label.new()
		label.name = "FallbackLabel"
		rect.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", UI_GOLD)
		label.add_theme_constant_override("outline_size", 2)
	label.text = text
	label.visible = rect.texture == null


func _apply_font_tree(root: Node) -> void:
	if root is Label:
		var label: Label = root as Label
		if _font:
			label.add_theme_font_override("font", _font)
		label.add_theme_color_override("font_color", UI_CREAM)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", UI_INK)
	for child in root.get_children():
		_apply_font_tree(child)
