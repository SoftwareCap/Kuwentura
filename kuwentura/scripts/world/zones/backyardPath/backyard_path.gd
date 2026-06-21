##backyard_path.gd
extends Node2D

const ZONE_ID := "backyard_path"
const TOTAL_TIME_SEC := 300
const MAX_STRIKES := 3
const _SERVER_PEER_ID := 1
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const SCENE_MAIN_MENU := "res://scenes/mainMenu/MainMenu.tscn"
const LEDGER_IMAGE_PATH := "res://assets/sprites/ledger/backyardpath_instructions.png"
const OCRA_FONT: FontFile = preload("res://assets/fonts/ocraextended.ttf")

const PROGRESS_DEFAULT_TEX: Texture2D = preload("res://assets/sprites/tracker/backyardPath/defaultBY.png")
const PROGRESS_PUZZLE1_TEX: Texture2D = preload("res://assets/sprites/tracker/backyardPath/puzzle1BY.png")

const SPARKLE_MIN_SCALE := 0.45
const SPARKLE_MAX_SCALE := 0.55
const SPARKLE_PULSE_SPEED := 4.0
const FIREFLY_PULSE_SPEED := 2.8
const FIREFLY_MIN_SCALE_MULTIPLIER := 0.85
const FIREFLY_MAX_SCALE_MULTIPLIER := 1.08
const FIREFLY_MIN_ALPHA := 0.45
const FIREFLY_MAX_ALPHA := 1.0
const GHOST_REVEAL_LINE := "I am here. I was never lost."
const GHOST_TYPEWRITER_DELAY := 0.045

const QUEST_PANEL_POS := Vector2(28, 235)
const QUEST_PANEL_WIDTH := 390.0
const QUEST_HEADER_HEIGHT := 42.0
const QUEST_ROW_HEIGHT := 60.0
const QUEST_ROW_GAP := 7.0
const QUEST_TEXT_LEFT_PADDING := 16.0
const QUEST_STRIKE_HEIGHT := 3.0

const DECODE_INSTRUCTION_FONT_SIZE := 16
const WORD_PUZZLE_QUESTION_FONT_SIZE := 20
const WORD_PUZZLE_INSTRUCTION_TEXT := "Answer the clues. Each first letter spells the ghost's name."
const FIXED_MEMORY_DISTANCE_DALI := 60
const FIXED_DALI_TO_CM := 2
const FIXED_MEMORY_DISTANCE_CM := 120

const UI_CREAM := Color(0.98, 0.95, 0.88, 1.0)
const UI_INK := Color(0.27, 0.16, 0.08, 1.0)
const UI_PRIMARY := Color(0.54, 0.35, 0.16, 1.0)
const UI_PRIMARY_HOVER := Color(0.66, 0.44, 0.20, 1.0)
const UI_PRIMARY_PRESSED := Color(0.43, 0.26, 0.10, 1.0)
const UI_SECONDARY := Color(0.50, 0.31, 0.13, 1.0)
const UI_SECONDARY_HOVER := Color(0.62, 0.41, 0.19, 1.0)
const UI_SECONDARY_PRESSED := Color(0.39, 0.23, 0.09, 1.0)
const UI_DISABLED := Color(0.46, 0.39, 0.33, 0.92)
const UI_PANEL := Color(0.19, 0.11, 0.05, 0.92)
const UI_PANEL_SOFT := Color(0.35, 0.24, 0.14, 0.94)
const UI_BORDER := Color(0.96, 0.83, 0.58, 1.0)
const UI_SUCCESS := Color(0.53, 0.86, 0.47, 1.0)
const UI_ERROR := Color(0.91, 0.42, 0.34, 1.0)
const UI_INFO := Color(0.99, 0.91, 0.63, 1.0)

@onready var role_label: Label = get_node_or_null("RoleLabel")
@onready var back_button: Button = $BackButton
@onready var players_node: Node = get_node_or_null("Players")
@onready var detective_player: Node2D = get_node_or_null("Players/Detective")
@onready var sidekick_player: Node2D = get_node_or_null("Players/Sidekick")

@onready var detective_overlays: Control = $RoleLayer/Control/DetectiveOverlays
@onready var sidekick_overlays: Control = $RoleLayer/Control/SidekickOverlays
@onready var pina_spirit: TextureRect = $RoleLayer/Control/DetectiveOverlays/Pina
@onready var detective_height_label: Label = $RoleLayer/Control/DetectiveOverlays/PinasHeight
@onready var pineapple_plant: TextureRect = $RoleLayer/Control/SidekickOverlays/PineapplePlant
@onready var pineapple_fruit: TextureRect = $RoleLayer/Control/SidekickOverlays/PineappleFruit
@onready var sidekick_height_label: Label = $RoleLayer/Control/SidekickOverlays/PlantsHeight
@onready var revealed_pineapple: Sprite2D = $RoleLayer/Control/Pineapple
@onready var revealed_plant: TextureRect = $RoleLayer/Control/PineapplePlant
@onready var board_tap_button: TextureButton = $RoleLayer/Control/BoardTapButton
@onready var fruit_tap_button: TextureButton = $RoleLayer/Control/FruitTapButton
@onready var board_layer: CanvasLayer = $"Deduction Board"
@onready var board_sprite: Sprite2D = $"Deduction Board/Control/BoardSprite"
@onready var board_height_label:  Label = $"Deduction Board/Control/PlantHeight"
@onready var board_instruction_label: Label = $"Deduction Board/Control/Plant"
@onready var x_input: LineEdit = $"Deduction Board/Control/XInput"
@onready var submit_button: Button = $"Deduction Board/Control/SubmitButton"
@onready var feedback_label: Label = $"Deduction Board/Control/FeedbackLabel"
@onready var notification_ui: CanvasLayer = get_node_or_null("NotificationUI")
@onready var notification_panel: Panel = get_node_or_null("NotificationUI/Panel")
@onready var notification_label: Label = get_node_or_null("NotificationUI/Panel/Label")
@onready var guidance_arrow: CanvasItem = get_node_or_null("RoleLayer/Control/GuidanceArrow")
@onready var touch_controls: Node = get_node_or_null("InsideZoneControl")
@onready var ledger_touch_button: TouchScreenButton = get_node_or_null("InsideZoneControl/Ledger")
@onready var briefcase_touch_button: TouchScreenButton = get_node_or_null("InsideZoneControl/Briefcase")
@onready var ledger_panel: Panel = get_node_or_null("SidekickLayer/Ledger")
@onready var ledger_title_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerTitle")
@onready var ledger_body_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerBody")

var _ledger_instruction_image: TextureRect = null
@onready var fog_overlay: ColorRect = $FogOverlay
@onready var inside_zone_control: CanvasLayer = get_node_or_null("InsideZoneControl")
@onready var pause_canvas_layer: CanvasLayer = get_node_or_null("PauseCanvasLayer")
@onready var in_game_pause_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel")
@onready var option_sub_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel")
@onready var volume_slider: HSlider = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider")
@onready var volume_value_label: Label = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue")
@onready var briefcase_panel: Panel = get_node_or_null("SidekickLayer/Briefcase")
@onready var briefcase_display: TextureRect = get_node_or_null("SidekickLayer/Briefcase/BriefcaseDisplay")
@onready var reward_layer: CanvasLayer = get_node_or_null("RewardLayer")
@onready var reward_dark_overlay: ColorRect = get_node_or_null("RewardLayer/DarkOverlay")
@onready var reward_banner_label: Label = get_node_or_null("RewardLayer/BannerLabel")
@onready var reward_text_label: Label = get_node_or_null("RewardLayer/RewardPanel/RewardText")
@onready var clue_sprite: Sprite2D = get_node_or_null("RewardLayer/ClueSprite")
@onready var collect_button: Button = get_node_or_null("RewardLayer/CollectButton")
@onready var reward_panel: Sprite2D = get_node_or_null("RewardLayer/RewardPanel")
@onready var tap_instruction_label: Label = get_node_or_null("RewardLayer/TapInstruction")
@onready var tap_catcher: Button = get_node_or_null("RewardLayer/TapCatcher")
@onready var briefcase_reveal_sprite: TextureRect = get_node_or_null("RewardLayer/BriefcaseRevealSprite")
@onready var sparkle: Sprite2D = $RewardLayer/Sparkle
@onready var progress_tracker: Node = get_node_or_null("ProgressTracker")
@onready var progress_tracker_sprite: Sprite2D = get_node_or_null("ProgressTracker/Sprite2D")

# New Backyard Path gameplay nodes
@onready var quest_title_label: Label = get_node_or_null("QuestLayer/QuestTitle")
@onready var quest_fireflies_label: Label = get_node_or_null("QuestLayer/QuestFirefliesLabel")
@onready var quest_lantern_label: Label = get_node_or_null("QuestLayer/QuestLanternLabel")
@onready var quest_decode_label: Label = get_node_or_null("QuestLayer/QuestDecodeLabel")
@onready var quest_memory_label: Label = get_node_or_null("QuestLayer/QuestMemoryLabel")
@onready var quest_grass_label: Label = get_node_or_null("QuestLayer/QuestGrassLabel")

@onready var firefly_layer: Node2D = get_node_or_null("FireflyLayer")
@onready var lantern_layer: Node2D = get_node_or_null("LanternLayer")
@onready var new_lantern: Sprite2D = get_node_or_null("LanternLayer/NewLantern")
@onready var fog_patch: Area2D = get_node_or_null("LanternLayer/FogPatch")
@onready var fog_sprite: Sprite2D = get_node_or_null("LanternLayer/FogPatch/FogSprite")
@onready var lantern_use_layer: CanvasLayer = get_node_or_null("LanternUseUILayer")
@onready var lantern_reward_label: Label = get_node_or_null("LanternUseUILayer/LanternReward")
@onready var lantern_reward_sprite: Sprite2D = get_node_or_null("LanternUseUILayer/Sprite2D")
@onready var use_lantern_button: Button = get_node_or_null("LanternUseUILayer/UseLanternButton")

@onready var ghost_layer: Node2D = get_node_or_null("GhostLayer")
@onready var ghost_sprite: Sprite2D = get_node_or_null("GhostLayer/PinaGhost")
@onready var ghost_name_tag: Area2D = get_node_or_null("GhostLayer/NameTag")
@onready var ghost_dialogue_label: Label = get_node_or_null("GhostLayer/GhostDialogueLabel")

@onready var decode_ui_layer: CanvasLayer = get_node_or_null("DecodeUILayer")
@onready var decode_panel: Panel = get_node_or_null("DecodeUILayer/DecodePanel")
@onready var decode_instruction_label: Label = get_node_or_null("DecodeUILayer/DecodePanel/InstructionLabel")
@onready var name_input: LineEdit = get_node_or_null("DecodeUILayer/DecodePanel/NameInput")
@onready var decode_submit_button: Button = get_node_or_null("DecodeUILayer/DecodePanel/DecodeSubmitButton")

@onready var grass_layer: Node2D = get_node_or_null("GrassLayer")
@onready var tall_grass: Area2D = get_node_or_null("GrassLayer/TallGrass")
@onready var fallen_leaves: Area2D = get_node_or_null("GrassLayer/FallenLeaves")
@onready var tangled_vines: Area2D = get_node_or_null("GrassLayer/TangledVines")

@onready var sidekick_name_tag: CanvasItem = get_node_or_null("DecodeUILayer/SidekickNameTag")
@onready var sidekick_name_tag_instruction_label: Label = get_node_or_null("DecodeUILayer/SidekickNameTag/InstructionLabel")

@onready var word_puzzle_layer: CanvasItem = get_node_or_null("WordPuzzleLayer")
@onready var word_puzzle_name_tag: Sprite2D = get_node_or_null("WordPuzzleLayer/NameTag")
@onready var word_puzzle_placeholder: Sprite2D = get_node_or_null("WordPuzzleLayer/Placholder")
@onready var word_puzzle_answer_input: LineEdit = get_node_or_null("WordPuzzleLayer/AnswerInput")
@onready var word_puzzle_clear_button: Button = get_node_or_null("WordPuzzleLayer/ClearButton")
@onready var word_puzzle_submit_button: Button = get_node_or_null("WordPuzzleLayer/SubmitButton")
@onready var word_puzzle_instruction_label: Label = get_node_or_null("WordPuzzleLayer/InstructionLabel")
@onready var word_puzzle_question_label: Label = get_node_or_null("WordPuzzleLayer/QuestionLabel")
@onready var word_puzzle_turn_label: Label = get_node_or_null("WordPuzzleLayer/TurnLabel")
@onready var word_puzzle_letters: Array = [
	get_node_or_null("WordPuzzleLayer/LetterP"),
	get_node_or_null("WordPuzzleLayer/LetterI"),
	get_node_or_null("WordPuzzleLayer/LetterN"),
	get_node_or_null("WordPuzzleLayer/LetterA")
]
@onready var puzzle_reward_layer: CanvasItem = get_node_or_null("PuzzleReward")
@onready var puzzle_reward_continue_button: Button = get_node_or_null("PuzzleReward/ContinueButton")
@onready var puzzle_reward_shapes: Array = [
	get_node_or_null("PuzzleReward/pentagon"),
	get_node_or_null("PuzzleReward/isosceles"),
	get_node_or_null("PuzzleReward/nonagon"),
	get_node_or_null("PuzzleReward/acute")
]

@onready var quest_layer: Node2D = get_node_or_null("QuestLayer")
@onready var focus_camera: Camera2D = get_node_or_null("FocusCamera")
@onready var grass_focus_point: Node2D = get_node_or_null("GrassFocusPoint")
@onready var pineapple_reveal_layer: Node2D = get_node_or_null("PineappleReveal")
@onready var pineapple_reveal_area: Area2D = get_node_or_null("PineappleReveal/Area2D")
@onready var pineapple_reveal_plant: Sprite2D = get_node_or_null("PineappleReveal/Area2D/PineapplePlant")
@onready var pineapple_reveal_fruit: Sprite2D = get_node_or_null("PineappleReveal/Area2D/PineappleFruit")

@onready var ending_cutscene: VideoStreamPlayer = $Cutscene/EndingCutscene

var _ending_cutscene_resolved := false

var _sfx_player: AudioStreamPlayer
var _zone_completion_sfx: AudioStream = preload("res://assets/audios/ZoneCompletionSFX.mp3")

var spirit_height_cm: int
var plant_height_dali: int
var solution_cm: int

var _waiting_reward_continue := false
var _reward_stage := 0
var _collect_sequence_started := false

var _intro_dialogue_played := false
var _intro_ready_peers: Dictionary = {}
var _zone_active := false
var _board_unlocked := false
var _board_opened := false
var _timer_started := false
var _puzzle_solved := false
var _reward_active := false
var _zone_failed := false
var _strikes := 0
var _ledger_hint_shown := false
var _dialogue_input_locked := false

var _timer_node: Timer
var _animation_time: float = 0.0
var _sparkle_animating: bool = false
var _firefly_base_scales: Dictionary = {}
var _new_lantern_base_scale: Vector2 = Vector2.ONE
var _lantern_reward_base_scale: Vector2 = Vector2.ONE
var _ghost_dialogue_typing := false
var _camera_original_position: Vector2 = Vector2.ZERO
var _camera_original_zoom: Vector2 = Vector2.ONE

var _puzzle_data_ready := false

var _quest_style_ready := false
var _quest_labels: Array = []
var _quest_strike_lines: Array = []
var _quest_active_index := -1
var _quest_expanded := false
var _quest_toggle_button: Button = null
var _quest_focus_overlay: ColorRect = null
var _quest_focus_active := false
var _quest_layer_base_z_index := 0
var _ghost_dialogue_overlay: ColorRect = null
var _dialogue_focus_active := false
var _grass_transition_focus_active := false
var _word_puzzle_reward_active := false
var _word_puzzle_reward_index := -1
var _word_puzzle_instruction_bg: Panel = null
var _word_puzzle_question_bg: ColorRect = null
var _puzzle_reward_dark_overlay: ColorRect = null
var _word_puzzle_text_guard := false

enum BackyardPhase {
	FIREFLIES,
	LANTERN,
	DECODE_NAME,
	DISTANCE,
	GRASS,
	PINEAPPLE_REVEALED,
	SOLVED
}

const REQUIRED_FIREFLIES := 5
const WORD_PUZZLE_DETECTIVE := "detective"
const WORD_PUZZLE_SIDEKICK := "sidekick"
const WORD_PUZZLE_QUESTIONS := [
	{
		"question": "What polygon has 5 sides?",
		"answers": ["PENTAGON"],
		"role": WORD_PUZZLE_DETECTIVE
	},
	{
		"question": "What triangle has at least two equal sides?",
		"answers": ["ISOSCELES", "ISOSCELESTRIANGLE"],
		"role": WORD_PUZZLE_SIDEKICK
	},
	{
		"question": "What polygon has 9 sides and 9 angles?",
		"answers": ["NONAGON", "ENNEAGON"],
		"role": WORD_PUZZLE_DETECTIVE
	},
	{
		"question": "What angle measures less than 90 degrees?",
		"answers": ["ACUTE", "ACUTEANGLE"],
		"role": WORD_PUZZLE_SIDEKICK
	}
]

var _current_phase: int = BackyardPhase.FIREFLIES
var _fireflies_collected := 0
var _caught_fireflies: Dictionary = {}
var _clearing_stage := 0
var _word_puzzle_question_index := 0
var _word_puzzle_revealed_count := 0

var encoded_name := "S L Q D"
var decoded_name := "PINA"
var shift_steps := 3
var memory_distance_dali := FIXED_MEMORY_DISTANCE_DALI
var dali_to_cm := FIXED_DALI_TO_CM
var memory_distance_cm := FIXED_MEMORY_DISTANCE_CM


func _load_puzzle_data() -> void:
	var puzzle: Dictionary = PuzzleManager.get_puzzle_for_zone(ZONE_ID)
	_apply_puzzle_data(puzzle)


func _apply_fixed_distance_values() -> void:
	plant_height_dali = FIXED_MEMORY_DISTANCE_DALI
	spirit_height_cm = FIXED_MEMORY_DISTANCE_CM
	solution_cm = FIXED_MEMORY_DISTANCE_CM
	memory_distance_dali = FIXED_MEMORY_DISTANCE_DALI
	memory_distance_cm = FIXED_MEMORY_DISTANCE_CM
	dali_to_cm = FIXED_DALI_TO_CM


func _apply_puzzle_data(puzzle: Dictionary) -> void:
	# Keep name-tag values local to this scene because the old PuzzleManager
	# does not store the new name-tag puzzle data.
	encoded_name = str(puzzle.get("encoded_name", "S L Q D"))
	decoded_name = str(puzzle.get("decoded_name", "PINA")).to_upper()
	shift_steps = int(puzzle.get("shift_steps", 3))

	# Keep this specific deduction step fixed and easy to teach across peers.
	_apply_fixed_distance_values()



func _cache_original_visual_scales() -> void:
	_firefly_base_scales.clear()

	if is_instance_valid(firefly_layer):
		for child in firefly_layer.get_children():
			if not (child is Area2D):
				continue
			var sprite := child.get_node_or_null("FireflySprite")
			if sprite is Sprite2D:
				_firefly_base_scales[child.name] = sprite.scale

	if is_instance_valid(new_lantern):
		_new_lantern_base_scale = new_lantern.scale

	if is_instance_valid(lantern_reward_sprite):
		_lantern_reward_base_scale = lantern_reward_sprite.scale


func _set_lantern_reward_layer_visible(should_show: bool) -> void:
	if is_instance_valid(lantern_use_layer):
		lantern_use_layer.visible = should_show

	if is_instance_valid(lantern_reward_label):
		lantern_reward_label.visible = should_show

	if is_instance_valid(lantern_reward_sprite):
		lantern_reward_sprite.visible = should_show
		if not should_show:
			lantern_reward_sprite.scale = _lantern_reward_base_scale
			lantern_reward_sprite.modulate.a = 1.0

	if not should_show and is_instance_valid(use_lantern_button):
		use_lantern_button.visible = false
		use_lantern_button.disabled = true


func _play_lantern_reward_animation() -> void:
	_set_lantern_reward_layer_visible(true)

	if is_instance_valid(lantern_reward_label):
		lantern_reward_label.text = "Use lantern to light up the backyard."
		lantern_reward_label.modulate.a = 0.0

	if is_instance_valid(lantern_reward_sprite):
		lantern_reward_sprite.scale = _lantern_reward_base_scale * 0.85
		lantern_reward_sprite.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	if is_instance_valid(lantern_reward_label):
		tween.tween_property(lantern_reward_label, "modulate:a", 1.0, 0.35)
	if is_instance_valid(lantern_reward_sprite):
		tween.tween_property(lantern_reward_sprite, "modulate:a", 1.0, 0.35)
		tween.tween_property(lantern_reward_sprite, "scale", _lantern_reward_base_scale, 0.35)


func _play_ghost_dialogue_typewriter(text: String) -> void:
	if not is_instance_valid(ghost_dialogue_label):
		show_notification("Pina: " + text, 4.0)
		return

	_ghost_dialogue_typing = true
	ghost_dialogue_label.visible = true
	ghost_dialogue_label.text = ""
	ghost_dialogue_label.modulate.a = 0.0
	ghost_dialogue_label.add_theme_font_override("font", OCRA_FONT)
	ghost_dialogue_label.add_theme_font_size_override("font_size", 24)
	ghost_dialogue_label.add_theme_color_override("font_color", UI_CREAM)
	ghost_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost_dialogue_label.add_theme_constant_override("outline_size", 3)
	ghost_dialogue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_set_dialogue_focus(true)
	_animate_ghost_dialogue_entry()

	for i in range(text.length()):
		if not _ghost_dialogue_typing or _zone_failed:
			return
		ghost_dialogue_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(GHOST_TYPEWRITER_DELAY).timeout

	_ghost_dialogue_typing = false


func _play_ghost_dialogue_lines(lines: Array) -> void:
	for line in lines:
		await _play_ghost_dialogue_typewriter(str(line))
		await get_tree().create_timer(0.85).timeout


func _ready() -> void:
	_cache_original_visual_scales()
	_create_timer()
	_connect_signals()

	if is_instance_valid(focus_camera):
		_camera_original_position = focus_camera.global_position
		_camera_original_zoom = focus_camera.zoom

	if is_instance_valid(role_label):
		role_label.text = "Role: " + GameState.get_role_display_text()

	_setup_backyard_visual_theme()
	_setup_quest_panel_style()
	_setup_initial_ui()
	_setup_role_visibility()
	_populate_ledger_content()
	_ensure_briefcase_display()
	_refresh_briefcase_display()

	if not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)
	if not GameState.briefcase_updated.is_connected(_on_briefcase_updated):
		GameState.briefcase_updated.connect(_on_briefcase_updated)

	MusicController.play_track(MusicController.MusicTrack.BACKYARD_PATH)

	_ensure_sfx_bus()
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)
	
	if is_instance_valid(ending_cutscene):
		CutsceneHelper.prepare_mobile_video_player(ending_cutscene)
		ending_cutscene.visible = false
		
	var cutscene_dark: Node = get_node_or_null("Cutscene/DarkOverlay")
	if is_instance_valid(cutscene_dark):
		cutscene_dark.visible = false

	_initialize_puzzle_sync()


func _create_timer() -> void:
	_timer_node = Timer.new()
	_timer_node.one_shot = true
	_timer_node.wait_time = TOTAL_TIME_SEC
	add_child(_timer_node)
	if not _timer_node.timeout.is_connected(_on_board_timer_timeout):
		_timer_node.timeout.connect(_on_board_timer_timeout)


func _ensure_sfx_bus() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		var last := AudioServer.bus_count - 1
		AudioServer.set_bus_name(last, "SFX")
		AudioServer.set_bus_volume_db(last, 0.0)


func _play_zone_completion_sfx() -> void:
	if not is_instance_valid(_sfx_player) or not _zone_completion_sfx:
		return
	MusicController.pause_music()
	_sfx_player.stream = _zone_completion_sfx
	_sfx_player.play()
	if not _sfx_player.finished.is_connected(_on_sfx_finished_resume_music):
		_sfx_player.finished.connect(_on_sfx_finished_resume_music, CONNECT_ONE_SHOT)


func _on_sfx_finished_resume_music() -> void:
	MusicController.resume_music()


func _sync_volume_ui() -> void:
	if is_instance_valid(volume_slider):
		volume_slider.value = MusicController.get_volume() * 100
	if is_instance_valid(volume_value_label):
		volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


func _make_stylebox(bg: Color, border: Color, corner_radius: int = 22, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	return style


func _ensure_word_puzzle_backdrops() -> void:
	if not is_instance_valid(word_puzzle_layer):
		return

	var old_instruction_bg := word_puzzle_layer.get_node_or_null("InstructionBackground") as ColorRect
	if is_instance_valid(old_instruction_bg):
		old_instruction_bg.visible = false

	_word_puzzle_instruction_bg = word_puzzle_layer.get_node_or_null("InstructionBackgroundPanel") as Panel
	if not is_instance_valid(_word_puzzle_instruction_bg):
		_word_puzzle_instruction_bg = Panel.new()
		_word_puzzle_instruction_bg.name = "InstructionBackgroundPanel"
		word_puzzle_layer.add_child(_word_puzzle_instruction_bg)
		_word_puzzle_instruction_bg.position = Vector2(404, 94)
		_word_puzzle_instruction_bg.size = Vector2(519, 45)
	_word_puzzle_instruction_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word_puzzle_instruction_bg.z_index = 3
	_word_puzzle_instruction_bg.add_theme_stylebox_override("panel", _make_stylebox(Color(0.54, 0.36, 0.18, 0.88), Color(0.78, 0.58, 0.35, 0.92), 14, 2))
	if is_instance_valid(word_puzzle_instruction_label):
		_word_puzzle_instruction_bg.position = Vector2(
			word_puzzle_instruction_label.offset_left - 18.0,
			word_puzzle_instruction_label.offset_top - 10.0
		)
		_word_puzzle_instruction_bg.size = Vector2(
			(word_puzzle_instruction_label.offset_right - word_puzzle_instruction_label.offset_left) + 36.0,
			(word_puzzle_instruction_label.offset_bottom - word_puzzle_instruction_label.offset_top) + 20.0
		)

	_word_puzzle_question_bg = word_puzzle_layer.get_node_or_null("QuestionBackground") as ColorRect
	if not is_instance_valid(_word_puzzle_question_bg):
		_word_puzzle_question_bg = ColorRect.new()
		_word_puzzle_question_bg.name = "QuestionBackground"
		word_puzzle_layer.add_child(_word_puzzle_question_bg)
		_word_puzzle_question_bg.position = Vector2(299, 370)
		_word_puzzle_question_bg.size = Vector2(742, 62)
		_word_puzzle_question_bg.color = Color(0.07, 0.04, 0.02, 0.58)
	_word_puzzle_question_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word_puzzle_question_bg.z_index = 3
	if is_instance_valid(word_puzzle_question_label):
		_word_puzzle_question_bg.position = Vector2(
			word_puzzle_question_label.offset_left - 24.0,
			word_puzzle_question_label.offset_top - 12.0
		)
		_word_puzzle_question_bg.size = Vector2(
			(word_puzzle_question_label.offset_right - word_puzzle_question_label.offset_left) + 48.0,
			(word_puzzle_question_label.offset_bottom - word_puzzle_question_label.offset_top) + 24.0
		)

	if is_instance_valid(word_puzzle_instruction_label):
		word_puzzle_instruction_label.z_index = 4
	if is_instance_valid(word_puzzle_question_label):
		word_puzzle_question_label.z_index = 4
	if is_instance_valid(word_puzzle_turn_label):
		word_puzzle_turn_label.z_index = 4


func _ensure_puzzle_reward_overlay() -> void:
	if not is_instance_valid(puzzle_reward_layer):
		return

	_puzzle_reward_dark_overlay = puzzle_reward_layer.get_node_or_null("DarkOverlay") as ColorRect
	if not is_instance_valid(_puzzle_reward_dark_overlay):
		_puzzle_reward_dark_overlay = ColorRect.new()
		_puzzle_reward_dark_overlay.name = "DarkOverlay"
		puzzle_reward_layer.add_child(_puzzle_reward_dark_overlay)
		puzzle_reward_layer.move_child(_puzzle_reward_dark_overlay, 0)

	_puzzle_reward_dark_overlay.position = Vector2(-2200, -1400)
	_puzzle_reward_dark_overlay.size = Vector2(4600, 3000)
	_puzzle_reward_dark_overlay.color = Color(0, 0, 0, 1.0)
	_puzzle_reward_dark_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_puzzle_reward_dark_overlay.z_index = 0

	for shape_node in puzzle_reward_shapes:
		var shape := shape_node as CanvasItem
		if is_instance_valid(shape):
			shape.visible = false
			shape.z_index = 2

	if is_instance_valid(puzzle_reward_continue_button):
		puzzle_reward_continue_button.z_index = 3

	puzzle_reward_layer.visible = false


func _spawn_confetti(parent_node: Node, top_y: float = -40.0, bottom_y: float = 80.0, z_layer: int = 1) -> void:
	if not is_instance_valid(parent_node):
		return

	var colors := [
		Color(0.98, 0.78, 0.28, 0.95),
		Color(0.95, 0.44, 0.32, 0.9),
		Color(0.48, 0.84, 0.38, 0.9),
		Color(0.98, 0.94, 0.72, 0.9)
	]
	for i in range(42):
		var piece := ColorRect.new()
		piece.name = "RewardConfetti"
		piece.size = Vector2(randf_range(8.0, 16.0), randf_range(5.0, 12.0))
		piece.position = Vector2(randf_range(180.0, 1180.0), randf_range(top_y, bottom_y))
		piece.rotation = randf_range(-0.75, 0.75)
		piece.color = colors[i % colors.size()]
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.z_index = z_layer
		parent_node.add_child(piece)

		var fall_distance := randf_range(220.0, 470.0)
		var drift := randf_range(-90.0, 90.0)
		var duration := randf_range(0.65, 1.15)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "position", piece.position + Vector2(drift, fall_distance), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "rotation", piece.rotation + randf_range(-2.4, 2.4), duration)
		tween.tween_property(piece, "modulate:a", 0.0, duration).set_delay(duration * 0.45)
		tween.chain().tween_callback(piece.queue_free)


func _spawn_puzzle_reward_confetti() -> void:
	_spawn_confetti(puzzle_reward_layer, -40.0, 80.0, 1)


func _spawn_artifact_reward_confetti() -> void:
	_spawn_confetti(reward_layer, 28.0, 130.0, 8)


func _setup_backyard_visual_theme() -> void:
	_ensure_word_puzzle_backdrops()
	_ensure_puzzle_reward_overlay()
	_style_notification_panel()
	_style_back_button()
	_style_puzzle_buttons()
	_style_input_fields()
	_style_text_feedback()
	_wire_button_motion()


func _style_notification_panel() -> void:
	if is_instance_valid(notification_panel):
		notification_panel.anchor_left = 0.5
		notification_panel.anchor_right = 0.5
		notification_panel.offset_left = -330.0
		notification_panel.offset_top = 74.0
		notification_panel.offset_right = 330.0
		notification_panel.offset_bottom = 124.0
		notification_panel.add_theme_stylebox_override("panel", _make_stylebox(UI_PANEL_SOFT, UI_BORDER, 20, 2))

	if is_instance_valid(notification_label):
		notification_label.offset_left = -305.0
		notification_label.offset_top = -20.0
		notification_label.offset_right = 305.0
		notification_label.offset_bottom = 20.0
		notification_label.add_theme_font_override("font", OCRA_FONT)
		notification_label.add_theme_font_size_override("font_size", 20)
		notification_label.add_theme_color_override("font_color", UI_CREAM)
		notification_label.add_theme_constant_override("outline_size", 2)
		notification_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notification_label.clip_text = false


func _style_back_button() -> void:
	if not is_instance_valid(back_button):
		return

	back_button.text = "BACK TO FOREST"
	back_button.add_theme_font_override("font", OCRA_FONT)
	back_button.add_theme_font_size_override("font_size", 24)
	back_button.add_theme_color_override("font_color", UI_CREAM)
	back_button.add_theme_color_override("font_hover_color", UI_CREAM)
	back_button.add_theme_color_override("font_pressed_color", UI_CREAM)
	back_button.add_theme_stylebox_override("normal", _make_stylebox(UI_PRIMARY, UI_BORDER))
	back_button.add_theme_stylebox_override("hover", _make_stylebox(UI_PRIMARY_HOVER, UI_BORDER))
	back_button.add_theme_stylebox_override("pressed", _make_stylebox(UI_PRIMARY_PRESSED, UI_BORDER))
	back_button.add_theme_stylebox_override("disabled", _make_stylebox(UI_DISABLED, UI_BORDER))


func _style_button(button: Button, text: String, primary: bool = true, font_size: int = 26) -> void:
	if not is_instance_valid(button):
		return

	button.flat = false
	button.text = text
	button.add_theme_font_override("font", OCRA_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", UI_CREAM)
	button.add_theme_color_override("font_hover_color", UI_CREAM)
	button.add_theme_color_override("font_focus_color", UI_CREAM)
	button.add_theme_color_override("font_pressed_color", UI_CREAM)

	var normal_color := UI_PRIMARY if primary else UI_SECONDARY
	var hover_color := UI_PRIMARY_HOVER if primary else UI_SECONDARY_HOVER
	var pressed_color := UI_PRIMARY_PRESSED if primary else UI_SECONDARY_PRESSED

	button.add_theme_stylebox_override("normal", _make_stylebox(normal_color, UI_BORDER))
	button.add_theme_stylebox_override("hover", _make_stylebox(hover_color, UI_BORDER))
	button.add_theme_stylebox_override("pressed", _make_stylebox(pressed_color, UI_BORDER))
	button.add_theme_stylebox_override("disabled", _make_stylebox(UI_DISABLED, UI_BORDER))
	button.add_theme_stylebox_override("focus", _make_stylebox(normal_color, UI_BORDER))


func _style_puzzle_buttons() -> void:
	_style_button(submit_button, "SUBMIT", true, 24)
	_style_button(word_puzzle_submit_button, "SUBMIT", true, 22)
	_style_button(word_puzzle_clear_button, "CLEAR", false, 22)
	_style_button(use_lantern_button, "USE LANTERN", true, 24)
	_style_button(collect_button, "COLLECT ARTIFACT", false, 24)
	_style_button(decode_submit_button, "SUBMIT", true, 20)
	_style_button(puzzle_reward_continue_button, "CONTINUE", true, 24)


func _style_input_fields() -> void:
	for field in [x_input, word_puzzle_answer_input, name_input]:
		if not is_instance_valid(field):
			continue
		field.add_theme_font_override("font", OCRA_FONT)
		field.add_theme_color_override("font_color", UI_INK)
		field.add_theme_color_override("font_placeholder_color", Color(UI_INK.r, UI_INK.g, UI_INK.b, 0.7))
		field.add_theme_color_override("font_selected_color", UI_CREAM)
		field.add_theme_color_override("selection_color", Color(0.45, 0.28, 0.11, 0.78))
		field.add_theme_color_override("caret_color", UI_PRIMARY_PRESSED)
		field.add_theme_stylebox_override("normal", _make_stylebox(Color(0.94, 0.87, 0.77, 1.0), UI_BORDER, 18, 2))
		field.add_theme_stylebox_override("focus", _make_stylebox(Color(0.99, 0.93, 0.83, 1.0), UI_SUCCESS, 18, 3))
		field.add_theme_stylebox_override("read_only", _make_stylebox(Color(0.82, 0.76, 0.68, 1.0), UI_BORDER, 18, 2))

	if is_instance_valid(x_input):
		x_input.add_theme_font_size_override("font_size", 14)
		x_input.placeholder_text = "CM value"
		x_input.custom_minimum_size.x = 180.0
	if is_instance_valid(word_puzzle_answer_input):
		word_puzzle_answer_input.add_theme_font_size_override("font_size", 24)
		word_puzzle_answer_input.placeholder_text = _get_word_puzzle_answer_hint(_word_puzzle_question_index)
		word_puzzle_answer_input.secret_character = ""

	_refresh_distance_input_visual_state()


func _refresh_distance_input_visual_state() -> void:
	if not is_instance_valid(x_input):
		return

	var has_content := not x_input.text.strip_edges().is_empty()
	var use_large_font := has_content or x_input.has_focus()
	x_input.add_theme_font_size_override("font_size", 24 if use_large_font else 14)


func _get_puzzle_reward_scale_multiplier(reward_index: int) -> float:
	match reward_index:
		0:
			return 1.14
		3:
			return 1.04
		_:
			return 1.0


func _style_text_feedback() -> void:
	for label in [feedback_label, lantern_reward_label, ghost_dialogue_label, reward_banner_label, tap_instruction_label, word_puzzle_instruction_label, word_puzzle_turn_label, word_puzzle_question_label]:
		if not is_instance_valid(label):
			continue
		label.add_theme_font_override("font", OCRA_FONT)
		label.add_theme_color_override("font_color", UI_CREAM)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))

	if is_instance_valid(feedback_label):
		feedback_label.add_theme_font_size_override("font_size", 20)
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		feedback_label.size = Vector2(480, 40)
		feedback_label.position = Vector2(455, 458)

	if is_instance_valid(ghost_dialogue_label):
		ghost_dialogue_label.add_theme_font_override("font", OCRA_FONT)
		ghost_dialogue_label.add_theme_font_size_override("font_size", 24)
		ghost_dialogue_label.add_theme_color_override("font_color", UI_CREAM)
		ghost_dialogue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
		ghost_dialogue_label.add_theme_constant_override("outline_size", 3)
		ghost_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ghost_dialogue_label.clip_text = false
		ghost_dialogue_label.offset_left = 818.0
		ghost_dialogue_label.offset_top = 120.0
		ghost_dialogue_label.offset_right = 1400.0
		ghost_dialogue_label.offset_bottom = 238.0

	if is_instance_valid(lantern_reward_label):
		lantern_reward_label.add_theme_font_size_override("font_size", 22)

	if is_instance_valid(word_puzzle_question_label):
		word_puzzle_question_label.add_theme_font_size_override("font_size", WORD_PUZZLE_QUESTION_FONT_SIZE)
		word_puzzle_question_label.add_theme_color_override("font_color", UI_CREAM)
		word_puzzle_question_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		word_puzzle_question_label.add_theme_constant_override("outline_size", 3)

	if is_instance_valid(word_puzzle_instruction_label):
		word_puzzle_instruction_label.add_theme_color_override("font_color", Color.WHITE)
		word_puzzle_instruction_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
		word_puzzle_instruction_label.add_theme_constant_override("outline_size", 2)
		if word_puzzle_instruction_label.text.strip_edges().is_empty():
			word_puzzle_instruction_label.text = WORD_PUZZLE_INSTRUCTION_TEXT

	if is_instance_valid(word_puzzle_turn_label):
		word_puzzle_turn_label.add_theme_font_size_override("font_size", 18)
		word_puzzle_turn_label.add_theme_color_override("font_color", UI_INFO)
		word_puzzle_turn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
		word_puzzle_turn_label.add_theme_constant_override("outline_size", 2)
		word_puzzle_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word_puzzle_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if is_instance_valid(reward_banner_label):
		reward_banner_label.add_theme_font_size_override("font_size", 50)

	_ensure_ghost_dialogue_overlay()


func _ensure_ghost_dialogue_overlay() -> void:
	if not is_instance_valid(ghost_layer) or not is_instance_valid(ghost_dialogue_label):
		return

	var old_bubble := ghost_layer.get_node_or_null("GhostDialogueBubble")
	if old_bubble is Panel:
		old_bubble.queue_free()

	var existing_overlay := ghost_layer.get_node_or_null("GhostDialogueOverlay")
	if existing_overlay is ColorRect:
		_ghost_dialogue_overlay = existing_overlay
	else:
		var overlay := ColorRect.new()
		overlay.name = "GhostDialogueOverlay"
		ghost_layer.add_child(overlay)
		ghost_layer.move_child(overlay, 0)
		_ghost_dialogue_overlay = overlay

	if is_instance_valid(_ghost_dialogue_overlay):
		_ghost_dialogue_overlay.visible = false
		_ghost_dialogue_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost_dialogue_overlay.color = Color(0.02, 0.02, 0.03, 0.0)
		_ghost_dialogue_overlay.offset_left = -1500.0
		_ghost_dialogue_overlay.offset_top = -900.0
		_ghost_dialogue_overlay.offset_right = 1500.0
		_ghost_dialogue_overlay.offset_bottom = 900.0


func _wire_button_motion() -> void:
	for button in [back_button, submit_button, word_puzzle_submit_button, word_puzzle_clear_button, use_lantern_button, collect_button, decode_submit_button]:
		if not is_instance_valid(button):
			continue
		if not button.has_meta("ux_motion_ready"):
			button.button_down.connect(_on_ui_button_down.bind(button))
			button.button_up.connect(_on_ui_button_up.bind(button))
			button.mouse_exited.connect(_on_ui_button_up.bind(button))
			button.set_meta("ux_motion_ready", true)


func _on_ui_button_down(button: Button) -> void:
	_tween_node_scale(button, Vector2(0.96, 0.96), 0.08)


func _on_ui_button_up(button: Button) -> void:
	_tween_node_scale(button, Vector2.ONE, 0.12)


func _get_canvas_item_base_scale(target: CanvasItem) -> Vector2:
	var scale_value: Variant = target.get_meta("ux_base_scale", target.get("scale"))
	if scale_value is Vector2:
		return scale_value
	return Vector2.ONE


func _get_canvas_item_base_position(target: CanvasItem) -> Vector2:
	var position_value: Variant = target.get_meta("ux_base_position", target.get("position"))
	if position_value is Vector2:
		return position_value
	return Vector2.ZERO


func _tween_node_scale(target: CanvasItem, scale_multiplier: Vector2, duration: float = 0.14) -> void:
	if not is_instance_valid(target):
		return

	var base_scale := _get_canvas_item_base_scale(target)
	if not target.has_meta("ux_base_scale"):
		target.set_meta("ux_base_scale", base_scale)

	if target.has_meta("ux_scale_tween"):
		var old_tween = target.get_meta("ux_scale_tween")
		if old_tween is Tween:
			old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", base_scale * scale_multiplier, duration)
	target.set_meta("ux_scale_tween", tween)


func _set_attention_pulse(target: CanvasItem, enabled: bool, pulse_scale: float = 1.06, duration: float = 0.7) -> void:
	if not is_instance_valid(target):
		return

	var base_scale := _get_canvas_item_base_scale(target)
	if not target.has_meta("ux_base_scale"):
		target.set_meta("ux_base_scale", base_scale)

	if target.has_meta("ux_pulse_tween"):
		var old_tween = target.get_meta("ux_pulse_tween")
		if old_tween is Tween:
			old_tween.kill()
		target.remove_meta("ux_pulse_tween")

	target.set("scale", base_scale)

	if not enabled:
		return

	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "scale", base_scale * pulse_scale, duration)
	tween.tween_property(target, "scale", base_scale, duration)
	target.set_meta("ux_pulse_tween", tween)


func _shake_node(target: CanvasItem, amount: float = 10.0, duration: float = 0.28) -> void:
	if not is_instance_valid(target):
		return

	var original_position := _get_canvas_item_base_position(target)
	if not target.has_meta("ux_base_position"):
		target.set_meta("ux_base_position", original_position)

	if target.has_meta("ux_shake_tween"):
		var old_tween = target.get_meta("ux_shake_tween")
		if old_tween is Tween:
			old_tween.kill()

	target.set("position", original_position)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "position", original_position + Vector2(-amount, 0), duration * 0.25)
	tween.tween_property(target, "position", original_position + Vector2(amount, 0), duration * 0.35)
	tween.tween_property(target, "position", original_position + Vector2(-amount * 0.5, 0), duration * 0.2)
	tween.tween_property(target, "position", original_position, duration * 0.2)
	target.set_meta("ux_shake_tween", tween)


func _flash_label(label: Label, color: Color, text: String = "") -> void:
	if not is_instance_valid(label):
		return
	if not text.is_empty():
		label.text = text

	label.add_theme_color_override("font_color", color)
	label.modulate = Color.WHITE
	_tween_node_scale(label, Vector2(1.04, 1.04), 0.1)

	var tween := create_tween()
	tween.tween_interval(0.18)
	tween.tween_callback(func():
		if is_instance_valid(label):
			if label == ghost_dialogue_label:
				label.add_theme_color_override("font_color", UI_CREAM)
			else:
				label.add_theme_color_override("font_color", UI_CREAM)
			label.scale = _get_canvas_item_base_scale(label)
	)


func _animate_ghost_dialogue_entry() -> void:
	if not is_instance_valid(ghost_dialogue_label):
		return

	var base_position_value: Variant = ghost_dialogue_label.get_meta("ux_dialogue_base_position", ghost_dialogue_label.position)
	var base_position: Vector2 = base_position_value if base_position_value is Vector2 else ghost_dialogue_label.position
	ghost_dialogue_label.position = base_position + Vector2(0, 18)
	ghost_dialogue_label.set_meta("ux_dialogue_base_position", base_position)

	ghost_dialogue_label.scale = Vector2(0.98, 0.98)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost_dialogue_label, "modulate:a", 1.0, 0.28)
	tween.tween_property(ghost_dialogue_label, "position", base_position, 0.32)
	tween.tween_property(ghost_dialogue_label, "scale", Vector2.ONE, 0.32)


func _set_dialogue_focus(active: bool) -> void:
	_dialogue_focus_active = active
	_refresh_focus_overlay_state()

	if not is_instance_valid(_ghost_dialogue_overlay):
		return

	if active:
		_ghost_dialogue_overlay.visible = true
		if _ghost_dialogue_overlay.has_meta("ux_overlay_tween"):
			var old_tween = _ghost_dialogue_overlay.get_meta("ux_overlay_tween")
			if old_tween is Tween:
				old_tween.kill()
		var fade_in := create_tween()
		fade_in.tween_property(_ghost_dialogue_overlay, "color:a", 0.78, 0.28)
		_ghost_dialogue_overlay.set_meta("ux_overlay_tween", fade_in)
	else:
		if _ghost_dialogue_overlay.has_meta("ux_overlay_tween"):
			var old_tween = _ghost_dialogue_overlay.get_meta("ux_overlay_tween")
			if old_tween is Tween:
				old_tween.kill()
		var fade_out := create_tween()
		fade_out.tween_property(_ghost_dialogue_overlay, "color:a", 0.0, 0.24)
		fade_out.tween_callback(func():
			if is_instance_valid(_ghost_dialogue_overlay) and not _dialogue_focus_active:
				_ghost_dialogue_overlay.visible = false
		)
		_ghost_dialogue_overlay.set_meta("ux_overlay_tween", fade_out)


func _refresh_focus_overlay_state() -> void:
	var word_puzzle_focus := is_instance_valid(word_puzzle_layer) and word_puzzle_layer.visible
	var word_puzzle_reward_focus := is_instance_valid(puzzle_reward_layer) and puzzle_reward_layer.visible
	var board_focus := (is_instance_valid(board_layer) and board_layer.visible) or (_board_opened and _current_phase == BackyardPhase.DISTANCE)
	var board_sidekick_focus := board_focus and GameState.local_role == GameState.Role.SIDEKICK and not _dialogue_focus_active
	var focus_overlay_active := _dialogue_focus_active or _grass_transition_focus_active or word_puzzle_focus or word_puzzle_reward_focus or board_focus

	var focus_nodes: Array = [quest_layer, progress_tracker, back_button, lantern_use_layer]
	if not board_sidekick_focus:
		focus_nodes.append(inside_zone_control)

	for node in focus_nodes:
		if not is_instance_valid(node):
			continue

		if focus_overlay_active:
			if not node.has_meta("ux_focus_restore_visible"):
				node.set_meta("ux_focus_restore_visible", node.visible)
			node.visible = false
		elif node.has_meta("ux_focus_restore_visible"):
			var previous_visible: Variant = node.get_meta("ux_focus_restore_visible", false)
			node.visible = previous_visible if previous_visible is bool else false
			node.remove_meta("ux_focus_restore_visible")

	if is_instance_valid(touch_controls):
		if board_sidekick_focus:
			inside_zone_control.visible = true
			if touch_controls.has_method("set_pause_enabled"):
				touch_controls.set_pause_enabled(false)
			if touch_controls.has_method("set_ledger_enabled"):
				touch_controls.set_ledger_enabled(true)
			if touch_controls.has_method("set_briefcase_enabled"):
				touch_controls.set_briefcase_enabled(false)
			if touch_controls.has_method("set_sidekick_ui_visible"):
				touch_controls.set_sidekick_ui_visible(true)
			if is_instance_valid(ledger_touch_button):
				ledger_touch_button.visible = true
			if is_instance_valid(briefcase_touch_button):
				briefcase_touch_button.visible = false
		else:
			if touch_controls.has_method("set_pause_enabled"):
				touch_controls.set_pause_enabled(true)
			if touch_controls.has_method("set_ledger_enabled"):
				touch_controls.set_ledger_enabled(true)
			if touch_controls.has_method("set_briefcase_enabled"):
				touch_controls.set_briefcase_enabled(true)
			if touch_controls.has_method("set_sidekick_ui_visible"):
				touch_controls.set_sidekick_ui_visible(GameState.local_role == GameState.Role.SIDEKICK)
			if is_instance_valid(ledger_touch_button):
				ledger_touch_button.visible = GameState.local_role == GameState.Role.SIDEKICK
			if is_instance_valid(briefcase_touch_button):
				briefcase_touch_button.visible = GameState.local_role == GameState.Role.SIDEKICK

	var puzzle_overlay_active := word_puzzle_focus or word_puzzle_reward_focus or board_focus or _grass_transition_focus_active
	if is_instance_valid(ghost_layer):
		if puzzle_overlay_active and not _dialogue_focus_active:
			if not ghost_layer.has_meta("ux_focus_restore_visible"):
				ghost_layer.set_meta("ux_focus_restore_visible", ghost_layer.visible)
			ghost_layer.visible = false
		elif ghost_layer.has_meta("ux_focus_restore_visible"):
			var ghost_visible: Variant = ghost_layer.get_meta("ux_focus_restore_visible", false)
			ghost_layer.visible = ghost_visible if ghost_visible is bool else false
			ghost_layer.remove_meta("ux_focus_restore_visible")

	if is_instance_valid(_ghost_dialogue_overlay):
		_ghost_dialogue_overlay.visible = _dialogue_focus_active or _ghost_dialogue_overlay.color.a > 0.01


func _flash_input_state(line_edit: LineEdit, success: bool) -> void:
	if not is_instance_valid(line_edit):
		return

	var accent := UI_SUCCESS if success else UI_ERROR
	line_edit.add_theme_stylebox_override("focus", _make_stylebox(Color(0.99, 0.93, 0.83, 1.0), accent, 18, 3))
	line_edit.add_theme_stylebox_override("normal", _make_stylebox(Color(0.94, 0.87, 0.77, 1.0), accent, 18, 3))

	if not success:
		_shake_node(line_edit, 8.0, 0.22)
	else:
		_tween_node_scale(line_edit, Vector2(1.03, 1.03), 0.1)

	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		if is_instance_valid(line_edit):
			line_edit.add_theme_stylebox_override("normal", _make_stylebox(Color(0.94, 0.87, 0.77, 1.0), UI_BORDER, 18, 2))
			line_edit.add_theme_stylebox_override("focus", _make_stylebox(Color(0.99, 0.93, 0.83, 1.0), UI_SUCCESS, 18, 3))
			line_edit.scale = _get_canvas_item_base_scale(line_edit)
	)


func _animate_panel_pop(panel_node: CanvasItem, start_scale_multiplier: float = 0.94) -> void:
	if not is_instance_valid(panel_node):
		return

	var base_scale := _get_canvas_item_base_scale(panel_node)
	if not panel_node.has_meta("ux_base_scale"):
		panel_node.set_meta("ux_base_scale", base_scale)

	panel_node.visible = true
	panel_node.modulate.a = 0.0
	panel_node.set("scale", base_scale * start_scale_multiplier)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel_node, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel_node, "scale", base_scale, 0.24)


func _animate_firefly_capture(firefly_node: CanvasItem) -> void:
	if not is_instance_valid(firefly_node):
		return

	var sprite := firefly_node.get_node_or_null("FireflySprite")
	if not (sprite is Sprite2D):
		firefly_node.visible = false
		return

	var base_scale: Vector2 = _firefly_base_scales.get(firefly_node.name, sprite.scale)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", base_scale * 1.5, 0.18)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func():
		if is_instance_valid(firefly_node):
			firefly_node.visible = false
		if is_instance_valid(sprite):
			sprite.scale = base_scale
			sprite.modulate.a = 1.0
	)


func _animate_letter_reveal(letter: Sprite2D) -> void:
	if not is_instance_valid(letter):
		return

	var base_scale := _get_canvas_item_base_scale(letter)
	if not letter.has_meta("ux_base_scale"):
		letter.set_meta("ux_base_scale", base_scale)

	letter.visible = true
	letter.modulate.a = 0.0
	letter.scale = base_scale * 1.35

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(letter, "modulate:a", 1.0, 0.18)
	tween.tween_property(letter, "scale", base_scale, 0.22)


func _show_word_puzzle_reward(reward_index: int) -> void:
	_ensure_puzzle_reward_overlay()
	if not is_instance_valid(puzzle_reward_layer):
		return

	_word_puzzle_reward_active = true
	_word_puzzle_reward_index = reward_index
	hide_notification()
	_set_word_puzzle_visible(false)

	puzzle_reward_layer.visible = true
	puzzle_reward_layer.modulate.a = 0.0
	if is_instance_valid(_puzzle_reward_dark_overlay):
		_puzzle_reward_dark_overlay.visible = true

	_play_zone_completion_sfx()
	_spawn_puzzle_reward_confetti()

	for i in range(puzzle_reward_shapes.size()):
		var shape := puzzle_reward_shapes[i] as CanvasItem
		if not is_instance_valid(shape):
			continue
		shape.visible = i == reward_index
		if i == reward_index:
			var base_scale := _get_canvas_item_base_scale(shape)
			var intro_target_multiplier := _get_puzzle_reward_scale_multiplier(reward_index)
			shape.modulate.a = 0.0
			shape.set("scale", base_scale * intro_target_multiplier * 0.76)

	if is_instance_valid(puzzle_reward_continue_button):
		var can_continue := _is_word_puzzle_reward_owner(reward_index)
		puzzle_reward_continue_button.visible = can_continue
		puzzle_reward_continue_button.disabled = not can_continue
		puzzle_reward_continue_button.modulate.a = 1.0
		_set_attention_pulse(puzzle_reward_continue_button, can_continue, 1.04, 0.55)

	var reward_tween := create_tween()
	reward_tween.set_parallel(true)
	reward_tween.tween_property(puzzle_reward_layer, "modulate:a", 1.0, 0.22)
	if reward_index >= 0 and reward_index < puzzle_reward_shapes.size():
		var reward_shape := puzzle_reward_shapes[reward_index] as CanvasItem
		if is_instance_valid(reward_shape):
			var reward_target_multiplier := _get_puzzle_reward_scale_multiplier(reward_index)
			var target_scale := _get_canvas_item_base_scale(reward_shape) * reward_target_multiplier
			reward_tween.tween_property(reward_shape, "modulate:a", 1.0, 0.28)
			reward_tween.tween_property(reward_shape, "scale", target_scale * 1.04, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			reward_tween.tween_property(reward_shape, "scale", target_scale, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_refresh_focus_overlay_state()


func _hide_word_puzzle_reward(restore_word_puzzle: bool = true) -> void:
	if not is_instance_valid(puzzle_reward_layer):
		return

	_word_puzzle_reward_active = false
	_set_attention_pulse(puzzle_reward_continue_button, false)
	var hide_tween := create_tween()
	hide_tween.tween_property(puzzle_reward_layer, "modulate:a", 0.0, 0.18)
	await hide_tween.finished

	if is_instance_valid(puzzle_reward_layer):
		puzzle_reward_layer.visible = false
		puzzle_reward_layer.modulate.a = 1.0
	for shape_node in puzzle_reward_shapes:
		var shape := shape_node as CanvasItem
		if is_instance_valid(shape):
			shape.visible = false
			shape.modulate.a = 1.0

	if restore_word_puzzle and _current_phase == BackyardPhase.DECODE_NAME and _word_puzzle_revealed_count < WORD_PUZZLE_QUESTIONS.size():
		_set_word_puzzle_visible(true)

	_refresh_focus_overlay_state()


func _on_puzzle_reward_continue_pressed() -> void:
	if not _word_puzzle_reward_active:
		return
	if not _is_word_puzzle_reward_owner(_word_puzzle_reward_index):
		return

	var puzzle_complete := _word_puzzle_revealed_count >= WORD_PUZZLE_QUESTIONS.size()
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		await _server_close_word_puzzle_reward(puzzle_complete)
	else:
		rpc_request_close_word_puzzle_reward.rpc_id(_SERVER_PEER_ID, puzzle_complete, _word_puzzle_reward_index)


func _animate_grass_clear(grass: CanvasItem) -> void:
	if not is_instance_valid(grass):
		return

	var sprite := grass.get_child(0) if grass.get_child_count() > 0 else null
	if not (sprite is Sprite2D):
		grass.visible = false
		return

	var base_scale: Vector2 = sprite.scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation_degrees", 10.0, 0.18)
	tween.tween_property(sprite, "scale", base_scale * 0.82, 0.18)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func():
		if is_instance_valid(grass):
			grass.visible = false
		if is_instance_valid(sprite):
			sprite.rotation_degrees = 0.0
			sprite.scale = base_scale
			sprite.modulate.a = 0.65
	)


func _connect_signals() -> void:
	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if is_instance_valid(board_tap_button) and not board_tap_button.pressed.is_connected(_on_board_tap_pressed):
		board_tap_button.pressed.connect(_on_board_tap_pressed)
	if is_instance_valid(fruit_tap_button) and not fruit_tap_button.pressed.is_connected(_on_fruit_tap_pressed):
		fruit_tap_button.pressed.connect(_on_fruit_tap_pressed)
	if is_instance_valid(submit_button) and not submit_button.pressed.is_connected(_on_submit_pressed):
		submit_button.pressed.connect(_on_submit_pressed)
	if is_instance_valid(x_input):
		if not x_input.text_changed.is_connected(_on_distance_input_text_changed):
			x_input.text_changed.connect(_on_distance_input_text_changed)
		if not x_input.focus_entered.is_connected(_on_distance_input_focus_changed):
			x_input.focus_entered.connect(_on_distance_input_focus_changed)
		if not x_input.focus_exited.is_connected(_on_distance_input_focus_changed):
			x_input.focus_exited.connect(_on_distance_input_focus_changed)
	if is_instance_valid(collect_button) and not collect_button.pressed.is_connected(_on_collect_pressed):
		collect_button.pressed.connect(_on_collect_pressed)
	if is_instance_valid(tap_catcher) and not tap_catcher.pressed.is_connected(_on_reward_tap_catcher_pressed):
		tap_catcher.pressed.connect(_on_reward_tap_catcher_pressed)

	if is_instance_valid(volume_slider) and not volume_slider.value_changed.is_connected(_on_in_game_volume_changed):
		volume_slider.value_changed.connect(_on_in_game_volume_changed)

	if is_instance_valid(touch_controls):
		if touch_controls.has_signal("ledger_pressed") and not touch_controls.ledger_pressed.is_connected(_on_ledger_pressed):
			touch_controls.ledger_pressed.connect(_on_ledger_pressed)
		if touch_controls.has_signal("pause_pressed") and not touch_controls.pause_pressed.is_connected(_on_pause_button_pressed):
			touch_controls.pause_pressed.connect(_on_pause_button_pressed)
		if touch_controls.has_signal("briefcase_pressed") and not touch_controls.briefcase_pressed.is_connected(_on_briefcase_button_pressed):
			touch_controls.briefcase_pressed.connect(_on_briefcase_button_pressed)

	var resume_btn: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton")
	if is_instance_valid(resume_btn) and not resume_btn.pressed.is_connected(_on_resume_play_button_pressed):
		resume_btn.pressed.connect(_on_resume_play_button_pressed)

	var option_btn: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionButton")
	if is_instance_valid(option_btn) and not option_btn.pressed.is_connected(_on_option_button_pressed):
		option_btn.pressed.connect(_on_option_button_pressed)

	var exit_btn: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/ExitButton")
	if is_instance_valid(exit_btn) and not exit_btn.pressed.is_connected(_on_exit_to_main_menu_button_pressed):
		exit_btn.pressed.connect(_on_exit_to_main_menu_button_pressed)

	var back_btn: TouchScreenButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/BackToPrevious")
	if is_instance_valid(back_btn) and not back_btn.pressed.is_connected(_on_in_game_option_back_pressed):
		back_btn.pressed.connect(_on_in_game_option_back_pressed)

	_connect_new_backyard_gameplay_signals()


func _on_distance_input_text_changed(_new_text: String) -> void:
	_refresh_distance_input_visual_state()


func _on_word_puzzle_answer_text_changed(new_text: String) -> void:
	if _word_puzzle_text_guard or not is_instance_valid(word_puzzle_answer_input):
		return

	var uppercase_text := new_text.to_upper()
	if uppercase_text == new_text:
		return

	_word_puzzle_text_guard = true
	var caret_column := word_puzzle_answer_input.caret_column
	word_puzzle_answer_input.text = uppercase_text
	word_puzzle_answer_input.caret_column = min(caret_column, uppercase_text.length())
	_word_puzzle_text_guard = false


func _on_distance_input_focus_changed() -> void:
	_refresh_distance_input_visual_state()


func _setup_initial_ui() -> void:
	_zone_active = false
	_board_unlocked = false
	_board_opened = false
	_timer_started = false
	_puzzle_solved = false
	_reward_active = false
	_zone_failed = false
	_strikes = 0
	_ledger_hint_shown = false
	_quest_active_index = -1
	_quest_expanded = false

	_current_phase = BackyardPhase.FIREFLIES
	_fireflies_collected = 0
	_caught_fireflies.clear()
	_clearing_stage = 0

	if is_instance_valid(board_layer):
		board_layer.visible = false
	if is_instance_valid(board_tap_button):
		board_tap_button.disabled = true
		board_tap_button.visible = false
		board_tap_button.z_index = 100
	if is_instance_valid(x_input):
		x_input.visible = false
		x_input.text = ""
		x_input.editable = false
		x_input.placeholder_text = "CM value"
		x_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		_refresh_distance_input_visual_state()
	if is_instance_valid(submit_button):
		submit_button.visible = false
		submit_button.disabled = true
	if is_instance_valid(feedback_label):
		feedback_label.text = ""
		feedback_label.visible = false
	if is_instance_valid(board_height_label):
		board_height_label.visible = false
	if is_instance_valid(board_instruction_label):
		board_instruction_label.visible = false
	if is_instance_valid(quest_layer):
		quest_layer.visible = false

	if is_instance_valid(notification_ui):
		notification_ui.visible = true
	if is_instance_valid(notification_panel):
		notification_panel.visible = false
		notification_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(notification_label):
		notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(guidance_arrow):
		guidance_arrow.visible = false
	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false

	# Backyard starts dark and foggy.
	if is_instance_valid(fog_overlay):
		fog_overlay.visible = true
		fog_overlay.modulate.a = 0.68
		fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(firefly_layer):
		firefly_layer.visible = true
		for child in firefly_layer.get_children():
			if child is Area2D:
				child.visible = true
				_set_area_enabled(child, true)

	if is_instance_valid(new_lantern):
		new_lantern.visible = false
		new_lantern.scale = _new_lantern_base_scale
	if is_instance_valid(fog_sprite):
		fog_sprite.visible = true
	if is_instance_valid(fog_patch):
		_set_area_enabled(fog_patch, true)

	if is_instance_valid(lantern_use_layer):
		lantern_use_layer.visible = false
	if is_instance_valid(lantern_reward_label):
		lantern_reward_label.visible = false
	if is_instance_valid(lantern_reward_sprite):
		lantern_reward_sprite.visible = false
		lantern_reward_sprite.scale = _lantern_reward_base_scale
	if is_instance_valid(use_lantern_button):
		use_lantern_button.visible = false
		use_lantern_button.disabled = true
		use_lantern_button.text = "Use Lantern"

	if is_instance_valid(ghost_layer):
		ghost_layer.visible = false
		ghost_layer.modulate.a = 0.0
	if is_instance_valid(ghost_dialogue_label):
		ghost_dialogue_label.visible = false
		ghost_dialogue_label.text = ""
	if is_instance_valid(_ghost_dialogue_overlay):
		_ghost_dialogue_overlay.visible = false
	if is_instance_valid(ghost_name_tag):
		_set_area_enabled(ghost_name_tag, true)

	if is_instance_valid(decode_ui_layer):
		decode_ui_layer.visible = false
	if is_instance_valid(sidekick_name_tag):
		sidekick_name_tag.visible = false
	if is_instance_valid(sidekick_name_tag_instruction_label):
		sidekick_name_tag_instruction_label.text = ""
	if is_instance_valid(decode_panel):
		decode_panel.visible = false
	if is_instance_valid(decode_instruction_label):
		decode_instruction_label.text = "Rearrange the letters to form a name."
	if is_instance_valid(name_input):
		name_input.text = ""
		name_input.placeholder_text = "Enter name"
		name_input.editable = false
	if is_instance_valid(decode_submit_button):
		decode_submit_button.text = "Submit"
		decode_submit_button.disabled = true
	_reset_word_puzzle_state()
	_set_word_puzzle_visible(false)
	_word_puzzle_reward_active = false
	if is_instance_valid(puzzle_reward_layer):
		puzzle_reward_layer.visible = false
		puzzle_reward_layer.modulate.a = 1.0
	for shape_node in puzzle_reward_shapes:
		var shape := shape_node as CanvasItem
		if is_instance_valid(shape):
			shape.visible = false
			shape.modulate.a = 1.0

	if is_instance_valid(grass_layer):
		grass_layer.visible = false
		for child in grass_layer.get_children():
			if child is Area2D:
				child.visible = true
				_set_area_enabled(child, true)

	if is_instance_valid(pineapple_reveal_layer):
		pineapple_reveal_layer.visible = false
	if is_instance_valid(pineapple_reveal_area):
		_set_area_enabled(pineapple_reveal_area, false)
	if is_instance_valid(pineapple_reveal_plant):
		pineapple_reveal_plant.visible = true
	if is_instance_valid(pineapple_reveal_fruit):
		pineapple_reveal_fruit.visible = true

	if is_instance_valid(fruit_tap_button):
		fruit_tap_button.visible = false
		fruit_tap_button.disabled = true
		fruit_tap_button.z_index = 100
	if is_instance_valid(revealed_plant):
		revealed_plant.visible = false
	if is_instance_valid(revealed_pineapple):
		revealed_pineapple.visible = false
	if is_instance_valid(reward_layer):
		reward_layer.visible = false
	if is_instance_valid(collect_button):
		collect_button.visible = false
	if is_instance_valid(briefcase_touch_button):
		briefcase_touch_button.visible = false
	if is_instance_valid(reward_panel):
		reward_panel.visible = false
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = false
		tap_instruction_label.text = ""
	if is_instance_valid(tap_catcher):
		tap_catcher.visible = false
		tap_catcher.disabled = true
	if is_instance_valid(detective_overlays):
		detective_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(sidekick_overlays):
		sidekick_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null
		briefcase_reveal_sprite.modulate = Color(1, 1, 1, 1)
	if is_instance_valid(sparkle):
		sparkle.visible = false
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
		_animation_time = 0.0
		_sparkle_animating = false
	if is_instance_valid(pause_canvas_layer):
		pause_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(in_game_pause_panel):
		in_game_pause_panel.visible = false
		in_game_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = false
		option_sub_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_volume_ui()
	if is_instance_valid(briefcase_panel):
		briefcase_panel.visible = false
	_set_progress_tracker_stage(0)
	_update_quest_labels()
	_refresh_lantern_use_button()

func _setup_role_visibility() -> void:
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			detective_overlays.visible = true
			sidekick_overlays.visible  = false
			if is_instance_valid(detective_player):
				detective_player.visible = true
			if is_instance_valid(sidekick_player):
				sidekick_player.visible  = false
		GameState.Role.SIDEKICK:
			detective_overlays.visible = false
			sidekick_overlays.visible  = true
			if is_instance_valid(detective_player):
				detective_player.visible = false
			if is_instance_valid(sidekick_player):
				sidekick_player.visible  = true
		_:
			detective_overlays.visible = false
			sidekick_overlays.visible  = false
			if is_instance_valid(detective_player):
				detective_player.visible = false
			if is_instance_valid(sidekick_player):
				sidekick_player.visible  = false
	_refresh_inside_zone_buttons()


func _populate_heights() -> void:
	if is_instance_valid(detective_height_label):
		detective_height_label.text = str(memory_distance_cm) + " cm"
	if is_instance_valid(sidekick_height_label):
		sidekick_height_label.text = str(memory_distance_dali) + " Dali"
	if is_instance_valid(board_height_label):
		board_height_label.text = str(memory_distance_dali) + " Dali"


func _populate_ledger_content() -> void:
	for label in [ledger_title_label, ledger_body_label]:
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

func _set_dialogue_input_lock(locked: bool) -> void:
	_dialogue_input_locked = locked
	_set_dialogue_focus(locked)
	
	if is_instance_valid(players_node):
		players_node.visible = not locked
	
	var is_sidekick: bool  = GameState.local_role == GameState.Role.SIDEKICK
	var dim_color := Color(0.65, 0.65, 0.65, 1.0)
	var normal_color := Color(1, 1, 1, 1)

	if is_instance_valid(touch_controls) and touch_controls.has_method("set_pause_enabled"):
		touch_controls.set_pause_enabled(true)

	if is_instance_valid(board_tap_button):
		board_tap_button.modulate = dim_color if locked else normal_color
	if is_instance_valid(fruit_tap_button):
		fruit_tap_button.modulate = dim_color if locked else normal_color

	if is_instance_valid(x_input):
		if locked:
			x_input.editable = false
			x_input.release_focus()
			x_input.modulate = dim_color
			_refresh_distance_input_visual_state()
		else:
			x_input.editable = _is_detective_solver() and _board_opened and _board_unlocked and not _puzzle_solved and not _zone_failed
			x_input.modulate = normal_color
			_refresh_distance_input_visual_state()

	if is_instance_valid(submit_button):
		submit_button.disabled = locked or not (_is_detective_solver() and _board_opened and _board_unlocked and not _puzzle_solved and not _zone_failed)
		submit_button.modulate = dim_color if submit_button.disabled else normal_color

	if is_instance_valid(touch_controls):
		if touch_controls.has_method("set_ledger_enabled"): touch_controls.set_ledger_enabled(is_sidekick and not locked)
		if touch_controls.has_method("set_briefcase_enabled"): touch_controls.set_briefcase_enabled(is_sidekick and not locked and _reward_active)

	if is_instance_valid(ledger_touch_button):
		ledger_touch_button.visible  = is_sidekick
		ledger_touch_button.modulate = dim_color if locked else normal_color
	if is_instance_valid(briefcase_touch_button):
		briefcase_touch_button.visible  = is_sidekick
		briefcase_touch_button.modulate = dim_color if locked else normal_color

	if is_instance_valid(tap_catcher):
		tap_catcher.disabled = locked or not tap_catcher.visible

	if not locked:
		_refresh_inside_zone_buttons()


func _start_intro_dialogue_delayed() -> void:
	if _intro_dialogue_played:
		return
	_intro_dialogue_played = true
	_run_intro_sequence()


func _get_backyard_intro_dialogue() -> Array[Dictionary]:
	return [
		{"speaker": "detective", "text": "It is too dark here. I can barely see the path."},
		{"speaker": "sidekick", "text": "Wait... there are fireflies around the yard."},
		{"speaker": "detective", "text": "Maybe their light can help us use that old lantern."},
		{"speaker": "sidekick", "text": "Let us catch them before the fog gets thicker."}
	]


func _play_backyard_dialogue(dialogue_id: String, lines: Array[Dictionary]) -> void:
	if DialogueSystem.has_method("set_body_font_override"):
		DialogueSystem.set_body_font_override(OCRA_FONT)
	DialogueSystem.play(dialogue_id, lines)
	await DialogueSystem.wait_finished(dialogue_id)
	if DialogueSystem.has_method("clear_body_font_override"):
		DialogueSystem.clear_body_font_override()


func _run_intro_sequence() -> void:
	_set_dialogue_input_lock(true)
	await _play_backyard_dialogue("backyard_path_intro", _get_backyard_intro_dialogue())
	_set_dialogue_input_lock(false)
	_report_intro_ready()


func _report_intro_ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		rpc_start_firefly_phase()
		return
	if multiplayer.is_server():
		_mark_intro_ready(multiplayer.get_unique_id())
	else:
		rpc_report_intro_ready.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_report_intro_ready() -> void:
	if multiplayer.is_server():
		_mark_intro_ready(multiplayer.get_remote_sender_id())


func _mark_intro_ready(peer_id: int) -> void:
	_intro_ready_peers[peer_id] = true
	if not multiplayer.is_server():
		return
	var needed := multiplayer.get_peers().size() + 1
	if _intro_ready_peers.size() >= needed:
		rpc_start_firefly_phase.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_start_firefly_phase() -> void:
	_zone_active = true
	_board_unlocked = false
	_board_opened = false
	_current_phase = BackyardPhase.FIREFLIES

	if is_instance_valid(quest_layer):
		quest_layer.visible = true
	if is_instance_valid(board_layer):
		board_layer.visible = false
	if is_instance_valid(board_tap_button):
		board_tap_button.visible = false
		board_tap_button.disabled = true
	_set_lantern_reward_layer_visible(false)
	_refresh_focus_overlay_state()

	show_notification("Catch all 5 fireflies to light the old lantern.", 3.0)
	_update_quest_labels()


func _connect_new_backyard_gameplay_signals() -> void:
	if is_instance_valid(firefly_layer):
		for child in firefly_layer.get_children():
			if child is Area2D:
				var firefly := child as Area2D
				var cb := Callable(self, "_on_firefly_input_event").bind(firefly)
				if not firefly.input_event.is_connected(cb):
					firefly.input_event.connect(cb)

	if is_instance_valid(fog_patch):
		var fog_cb := Callable(self, "_on_fog_patch_input_event")
		if not fog_patch.input_event.is_connected(fog_cb):
			fog_patch.input_event.connect(fog_cb)

	if is_instance_valid(ghost_name_tag):
		var tag_cb := Callable(self, "_on_name_tag_input_event")
		if not ghost_name_tag.input_event.is_connected(tag_cb):
			ghost_name_tag.input_event.connect(tag_cb)

	for grass_area in [tall_grass, fallen_leaves, tangled_vines]:
		if grass_area is Area2D:
			var grass_cb := Callable(self, "_on_grass_input_event").bind(grass_area)
			if not grass_area.input_event.is_connected(grass_cb):
				grass_area.input_event.connect(grass_cb)

	if is_instance_valid(decode_submit_button) and not decode_submit_button.pressed.is_connected(_on_decode_submit_pressed):
		decode_submit_button.pressed.connect(_on_decode_submit_pressed)

	if is_instance_valid(word_puzzle_submit_button) and not word_puzzle_submit_button.pressed.is_connected(_on_word_puzzle_submit_pressed):
		word_puzzle_submit_button.pressed.connect(_on_word_puzzle_submit_pressed)

	if is_instance_valid(word_puzzle_clear_button) and not word_puzzle_clear_button.pressed.is_connected(_on_word_puzzle_clear_pressed):
		word_puzzle_clear_button.pressed.connect(_on_word_puzzle_clear_pressed)

	if is_instance_valid(word_puzzle_answer_input) and not word_puzzle_answer_input.text_submitted.is_connected(_on_word_puzzle_answer_submitted):
		word_puzzle_answer_input.text_submitted.connect(_on_word_puzzle_answer_submitted)
	if is_instance_valid(word_puzzle_answer_input) and not word_puzzle_answer_input.text_changed.is_connected(_on_word_puzzle_answer_text_changed):
		word_puzzle_answer_input.text_changed.connect(_on_word_puzzle_answer_text_changed)

	if is_instance_valid(puzzle_reward_continue_button) and not puzzle_reward_continue_button.pressed.is_connected(_on_puzzle_reward_continue_pressed):
		puzzle_reward_continue_button.pressed.connect(_on_puzzle_reward_continue_pressed)

	if is_instance_valid(use_lantern_button) and not use_lantern_button.pressed.is_connected(_on_use_lantern_pressed):
		use_lantern_button.pressed.connect(_on_use_lantern_pressed)

	if is_instance_valid(pineapple_reveal_area):
		var pineapple_cb := Callable(self, "_on_pineapple_reveal_input_event")
		if not pineapple_reveal_area.input_event.is_connected(pineapple_cb):
			pineapple_reveal_area.input_event.connect(pineapple_cb)


func _is_click_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func _is_detective_solver() -> bool:
	return GameState.local_role == GameState.Role.DETECTIVE or not multiplayer.has_multiplayer_peer()


func _is_word_puzzle_local_turn() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true

	var expected_role := _get_word_puzzle_question_role(_word_puzzle_question_index)
	if expected_role == WORD_PUZZLE_DETECTIVE:
		return GameState.local_role == GameState.Role.DETECTIVE
	return GameState.local_role == GameState.Role.SIDEKICK


func _get_word_puzzle_question_role(question_index: int) -> String:
	if question_index < 0 or question_index >= WORD_PUZZLE_QUESTIONS.size():
		return WORD_PUZZLE_DETECTIVE
	return str(WORD_PUZZLE_QUESTIONS[question_index].get("role", WORD_PUZZLE_DETECTIVE))


func _get_word_puzzle_turn_label(question_index: int) -> String:
	var role := _get_word_puzzle_question_role(question_index)
	if role == WORD_PUZZLE_SIDEKICK:
		return "Sidekick"
	return "Detective"


func _is_word_puzzle_reward_owner(reward_index: int) -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true

	var expected_role := _get_word_puzzle_question_role(reward_index)
	if expected_role == WORD_PUZZLE_DETECTIVE:
		return GameState.local_role == GameState.Role.DETECTIVE
	return GameState.local_role == GameState.Role.SIDEKICK


func _get_word_puzzle_answer_hint(question_index: int) -> String:
	if question_index < 0 or question_index >= WORD_PUZZLE_QUESTIONS.size():
		return ""

	var answers: Array = WORD_PUZZLE_QUESTIONS[question_index].get("answers", [])
	if answers.is_empty():
		return ""

	var answer_length := _normalize_word_puzzle_answer(str(answers[0])).length()
	var hint_parts: Array[String] = []
	for _i in range(answer_length):
		hint_parts.append("_")
	return " ".join(hint_parts)


func _normalize_word_puzzle_answer(answer: String) -> String:
	var normalized := answer.strip_edges().to_upper()
	normalized = normalized.replace(" ", "")
	normalized = normalized.replace("-", "")
	normalized = normalized.replace("_", "")
	normalized = normalized.replace(".", "")
	normalized = normalized.replace(",", "")
	normalized = normalized.replace("'", "")
	normalized = normalized.replace("\"", "")
	return normalized


func _reset_word_puzzle_state() -> void:
	_word_puzzle_question_index = 0
	_word_puzzle_revealed_count = 0
	_refresh_word_puzzle_ui()


func _set_word_puzzle_visible(should_show: bool) -> void:
	_ensure_word_puzzle_backdrops()
	if is_instance_valid(word_puzzle_layer):
		word_puzzle_layer.visible = should_show

	for node in [word_puzzle_name_tag, word_puzzle_placeholder, word_puzzle_instruction_label, word_puzzle_question_label, word_puzzle_turn_label, word_puzzle_answer_input, word_puzzle_clear_button, word_puzzle_submit_button, _word_puzzle_instruction_bg, _word_puzzle_question_bg]:
		if is_instance_valid(node):
			node.visible = should_show

	_refresh_focus_overlay_state()
	_refresh_word_puzzle_ui()


func _refresh_word_puzzle_ui() -> void:
	var puzzle_open := is_instance_valid(word_puzzle_layer) and word_puzzle_layer.visible
	var puzzle_complete := _word_puzzle_revealed_count >= WORD_PUZZLE_QUESTIONS.size()
	var local_turn := puzzle_open and not puzzle_complete and _is_word_puzzle_local_turn()

	for i in range(word_puzzle_letters.size()):
		var letter: CanvasItem = word_puzzle_letters[i] as CanvasItem
		if is_instance_valid(letter):
			letter.visible = puzzle_open and i < _word_puzzle_revealed_count

	if is_instance_valid(word_puzzle_question_label):
		word_puzzle_question_label.add_theme_font_size_override("font_size", WORD_PUZZLE_QUESTION_FONT_SIZE)
		word_puzzle_question_label.add_theme_color_override("font_color", Color.WHITE)
		word_puzzle_question_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		word_puzzle_question_label.add_theme_constant_override("outline_size", 3)
		word_puzzle_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word_puzzle_question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word_puzzle_question_label.autowrap_mode = TextServer.AUTOWRAP_OFF

		if puzzle_complete:
			word_puzzle_question_label.text = "The name is complete."
		elif _word_puzzle_question_index < WORD_PUZZLE_QUESTIONS.size():
			word_puzzle_question_label.text = str(WORD_PUZZLE_QUESTIONS[_word_puzzle_question_index].get("question", ""))
		else:
			word_puzzle_question_label.text = ""

	if is_instance_valid(word_puzzle_instruction_label):
		word_puzzle_instruction_label.text = WORD_PUZZLE_INSTRUCTION_TEXT

	if is_instance_valid(word_puzzle_turn_label):
		if not puzzle_open or puzzle_complete:
			word_puzzle_turn_label.text = ""
		elif local_turn:
			word_puzzle_turn_label.text = "Your turn"
		else:
			word_puzzle_turn_label.text = _get_word_puzzle_turn_label(_word_puzzle_question_index) + "'s turn"

	if is_instance_valid(word_puzzle_answer_input):
		word_puzzle_answer_input.add_theme_font_size_override("font_size", 24)
		word_puzzle_answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		word_puzzle_answer_input.visible = local_turn
		word_puzzle_answer_input.editable = local_turn
		var answer_hint := _get_word_puzzle_answer_hint(_word_puzzle_question_index)
		word_puzzle_answer_input.placeholder_text = answer_hint
		if not puzzle_open or not local_turn:
			word_puzzle_answer_input.text = ""
			word_puzzle_answer_input.release_focus()

	if is_instance_valid(word_puzzle_placeholder):
		word_puzzle_placeholder.scale = Vector2(0.27, 0.21)

	if is_instance_valid(word_puzzle_submit_button):
		word_puzzle_submit_button.disabled = not local_turn
		word_puzzle_submit_button.modulate = Color.WHITE if local_turn else Color(1, 1, 1, 0.72)
		_set_attention_pulse(word_puzzle_submit_button, local_turn)

	if is_instance_valid(word_puzzle_clear_button):
		word_puzzle_clear_button.disabled = not local_turn
		word_puzzle_clear_button.modulate = Color.WHITE if local_turn else Color(1, 1, 1, 0.72)


func _set_area_enabled(area: Area2D, enabled: bool) -> void:
	if not is_instance_valid(area):
		return
	area.monitoring = enabled
	area.input_pickable = enabled


func _setup_quest_panel_style() -> void:
	var queatLayer := get_node_or_null("QuestLayer") as Node2D
	if not is_instance_valid(queatLayer):
		return
	_quest_layer_base_z_index = queatLayer.z_index

	var labels := [
		quest_fireflies_label,
		quest_lantern_label,
		quest_decode_label,
		quest_memory_label,
		quest_grass_label
	]

	_quest_labels.clear()
	_quest_strike_lines.clear()

	_quest_focus_overlay = queatLayer.get_node_or_null("QuestFocusOverlay") as ColorRect
	if not is_instance_valid(_quest_focus_overlay):
		_quest_focus_overlay = ColorRect.new()
		_quest_focus_overlay.name = "QuestFocusOverlay"
		queatLayer.add_child(_quest_focus_overlay)
		queatLayer.move_child(_quest_focus_overlay, 0)

	_quest_focus_overlay.position = Vector2.ZERO
	_quest_focus_overlay.size = get_viewport_rect().size
	_quest_focus_overlay.color = Color(0.06, 0.035, 0.018, 0.84)
	_quest_focus_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_quest_focus_overlay.visible = false
	_quest_focus_overlay.z_index = -50

	var header_bar := queatLayer.get_node_or_null("QuestHeaderBar") as ColorRect
	if not is_instance_valid(header_bar):
		header_bar = ColorRect.new()
		header_bar.name = "QuestHeaderBar"
		queatLayer.add_child(header_bar)
		queatLayer.move_child(header_bar, 0)

	header_bar.position = QUEST_PANEL_POS
	header_bar.size = Vector2(QUEST_PANEL_WIDTH, QUEST_HEADER_HEIGHT)
	header_bar.color = Color(0.48, 0.27, 0.11, 0.98)
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_bar.z_index = 0
	_quest_toggle_button = quest_layer.get_node_or_null("QuestToggleButton") as Button
	if not is_instance_valid(_quest_toggle_button):
		_quest_toggle_button = Button.new()
		_quest_toggle_button.name = "QuestToggleButton"
		quest_layer.add_child(_quest_toggle_button)
	if not _quest_toggle_button.pressed.is_connected(_on_quest_header_pressed):
		_quest_toggle_button.pressed.connect(_on_quest_header_pressed)

	_quest_toggle_button.position = QUEST_PANEL_POS
	_quest_toggle_button.size = Vector2(QUEST_PANEL_WIDTH, QUEST_HEADER_HEIGHT)
	_quest_toggle_button.focus_mode = Control.FOCUS_NONE
	_quest_toggle_button.flat = true
	_quest_toggle_button.text = ""
	_quest_toggle_button.self_modulate = Color(1, 1, 1, 0.0)
	_quest_toggle_button.z_index = 5

	if is_instance_valid(quest_title_label):
		quest_title_label.text = "BACKYARD PATH QUEST"
		quest_title_label.position = QUEST_PANEL_POS + Vector2(10, 0)
		quest_title_label.size = Vector2(QUEST_PANEL_WIDTH - 20.0, QUEST_HEADER_HEIGHT)
		quest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		quest_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quest_title_label.add_theme_font_size_override("font_size", 19)
		quest_title_label.add_theme_color_override("font_color", Color.WHITE)
		quest_title_label.add_theme_constant_override("outline_size", 2)
		quest_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		quest_title_label.z_index = 3

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
		row_bg.color = Color(0.02, 0.015, 0.01, 0.62)
		row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_bg.z_index = 0

		label.position = row_pos + Vector2(QUEST_TEXT_LEFT_PADDING, 0)
		label.size = Vector2(QUEST_PANEL_WIDTH - (QUEST_TEXT_LEFT_PADDING * 2.0), QUEST_ROW_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = false
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", UI_CREAM)
		label.add_theme_constant_override("outline_size", 0)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.0))
		label.z_index = 2

		_quest_labels.append(label)

		var strike_name := "QuestStrike" + str(i + 1)
		var strike := quest_layer.get_node_or_null(strike_name) as ColorRect
		if not is_instance_valid(strike):
			strike = ColorRect.new()
			strike.name = strike_name
			quest_layer.add_child(strike)

		strike.position = row_pos + Vector2(QUEST_TEXT_LEFT_PADDING, QUEST_ROW_HEIGHT * 0.52)
		strike.size = Vector2(QUEST_PANEL_WIDTH - (QUEST_TEXT_LEFT_PADDING * 2.0), QUEST_STRIKE_HEIGHT)
		strike.color = Color(0.74, 0.58, 0.38, 0.72)
		strike.visible = false
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strike.z_index = 4

		_quest_strike_lines.append(strike)

	_quest_style_ready = true


func _on_quest_header_pressed() -> void:
	_quest_expanded = not _quest_expanded
	_quest_active_index = -1
	_set_quest_focus_active(_quest_expanded)
	_update_quest_labels()

	if is_instance_valid(quest_title_label):
		var base_scale := _get_canvas_item_base_scale(quest_title_label)
		quest_title_label.scale = base_scale * 1.04
		var tween := create_tween()
		tween.tween_property(quest_title_label, "scale", base_scale, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_quest_focus_active(active: bool) -> void:
	if _quest_focus_active == active:
		_update_quest_focus_overlay()
		return

	_quest_focus_active = active
	_update_quest_focus_overlay()

	var focus_nodes: Array = [
		inside_zone_control,
		back_button,
		progress_tracker,
		lantern_use_layer,
		ledger_panel,
		briefcase_panel,
		notification_ui,
		detective_player,
		sidekick_player
	]

	if active:
		if is_instance_valid(quest_layer):
			quest_layer.z_index = 90
		for node in focus_nodes:
			if not is_instance_valid(node):
				continue
			if not node.has_meta("quest_focus_restore_visible"):
				node.set_meta("quest_focus_restore_visible", node.visible)
			node.visible = false
	else:
		if is_instance_valid(quest_layer):
			quest_layer.z_index = _quest_layer_base_z_index
		for node in focus_nodes:
			if not is_instance_valid(node):
				continue
			if node.has_meta("quest_focus_restore_visible"):
				var previous_visible: Variant = node.get_meta("quest_focus_restore_visible", false)
				node.visible = previous_visible if previous_visible is bool else false
				node.remove_meta("quest_focus_restore_visible")


func _update_quest_focus_overlay() -> void:
	if not is_instance_valid(_quest_focus_overlay):
		return
	_quest_focus_overlay.position = Vector2.ZERO
	_quest_focus_overlay.size = get_viewport_rect().size
	_quest_focus_overlay.visible = _quest_focus_active


func _set_quest_task(index: int, text: String, done: bool, is_active: bool = false) -> void:
	if index < 0 or index >= _quest_labels.size():
		return

	var label := _quest_labels[index] as Label
	if not is_instance_valid(label):
		return

	var row_bg := get_node_or_null("QuestLayer/QuestRowBG" + str(index + 1)) as ColorRect
	var strike: ColorRect = null
	if index < _quest_strike_lines.size():
		strike = _quest_strike_lines[index] as ColorRect

	if not _quest_expanded and (done or not is_active):
		label.visible = false
		if is_instance_valid(row_bg):
			row_bg.visible = false
		if is_instance_valid(strike):
			strike.visible = false
		return

	label.text = text
	label.visible = true
	label.modulate = Color.WHITE
	var row_index := index if _quest_expanded else 0
	var target_y := QUEST_PANEL_POS.y + QUEST_HEADER_HEIGHT + 8.0 + float(row_index) * (QUEST_ROW_HEIGHT + QUEST_ROW_GAP)
	label.position = Vector2(QUEST_PANEL_POS.x + QUEST_TEXT_LEFT_PADDING, target_y)
	label.add_theme_color_override("font_color", Color(0.52, 0.42, 0.33, 1.0) if done else UI_CREAM)

	if is_instance_valid(row_bg):
		row_bg.visible = true
		row_bg.position = Vector2(QUEST_PANEL_POS.x, target_y)
		if done:
			row_bg.color = Color(0.02, 0.015, 0.01, 0.28)
		elif is_active:
			row_bg.color = Color(0.02, 0.015, 0.01, 0.68)
		else:
			row_bg.color = Color(0.02, 0.015, 0.01, 0.45)

	if is_instance_valid(strike):
		strike.visible = done and _quest_expanded
		strike.position = Vector2(QUEST_PANEL_POS.x + QUEST_TEXT_LEFT_PADDING, target_y + QUEST_ROW_HEIGHT * 0.52)

	if not _quest_expanded and index != _quest_active_index:
		_quest_active_index = index
		label.modulate.a = 0.0
		label.position.y += 18.0
		if is_instance_valid(row_bg):
			row_bg.modulate.a = 0.0
			row_bg.position.y += 18.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "modulate:a", 1.0, 0.22)
		tween.tween_property(label, "position:y", target_y, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if is_instance_valid(row_bg):
			tween.tween_property(row_bg, "modulate:a", 1.0, 0.22)
			tween.tween_property(row_bg, "position:y", target_y, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_quest_labels() -> void:
	if not _quest_style_ready:
		_setup_quest_panel_style()

	var fireflies_done := _fireflies_collected >= REQUIRED_FIREFLIES
	var lantern_done := _current_phase > BackyardPhase.LANTERN
	var decode_done := _current_phase > BackyardPhase.DECODE_NAME
	var memory_done := _current_phase > BackyardPhase.DISTANCE
	var grass_done := _current_phase > BackyardPhase.GRASS
	var active_index := -1
	if not fireflies_done:
		active_index = 0
	elif not lantern_done:
		active_index = 1
	elif not decode_done:
		active_index = 2
	elif not memory_done:
		active_index = 3
	elif not grass_done:
		active_index = 4

	_set_quest_task(
		0,
		"Catch fireflies: " + str(_fireflies_collected) + "/5",
		fireflies_done,
		active_index == 0
	)

	_set_quest_task(
		1,
		"Use lantern to light up the backyard",
		lantern_done,
		active_index == 1
	)

	_set_quest_task(
		2,
		"Find ghost's name tag",
		decode_done,
		active_index == 2
	)

	_set_quest_task(
		3,
		"Find Pina's memory",
		memory_done,
		active_index == 3
	)

	_set_quest_task(
		4,
		"Clear the strange plant",
		grass_done,
		active_index == 4
	)


func _should_show_use_lantern_button() -> bool:
	return _current_phase == BackyardPhase.LANTERN and _is_detective_solver() and not _zone_failed


func _refresh_lantern_use_button() -> void:
	var in_lantern_phase := _current_phase == BackyardPhase.LANTERN and not _zone_failed

	if is_instance_valid(lantern_use_layer):
		lantern_use_layer.visible = in_lantern_phase

	if is_instance_valid(lantern_reward_label):
		lantern_reward_label.visible = in_lantern_phase
		if _is_detective_solver():
			lantern_reward_label.text = "Use lantern to light up the backyard."
		else:
			lantern_reward_label.text = "The lantern is ready. Tell the Detective to use it."

	if is_instance_valid(lantern_reward_sprite):
		lantern_reward_sprite.visible = in_lantern_phase

	var show_button := _should_show_use_lantern_button()
	if is_instance_valid(use_lantern_button):
		use_lantern_button.visible = show_button
		use_lantern_button.disabled = not show_button
		use_lantern_button.modulate = Color.WHITE if show_button else Color(1, 1, 1, 0.72)
		_set_attention_pulse(use_lantern_button, show_button)

	if is_instance_valid(lantern_reward_sprite):
		_set_attention_pulse(lantern_reward_sprite, in_lantern_phase, 1.03, 0.9)


func _on_use_lantern_pressed() -> void:
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.LANTERN:
		return
	if not _is_detective_solver():
		show_notification("Only the Detective can use the Firefly Lantern here.", 2.0)
		return
	_request_reveal_ghost()


func _play_lantern_old_bulb_flicker() -> void:
	if is_instance_valid(use_lantern_button):
		use_lantern_button.disabled = true
		_set_attention_pulse(use_lantern_button, false)

	if is_instance_valid(lantern_reward_label):
		lantern_reward_label.text = "The lantern flickers to life..."

	var flicker_steps := [
		{"alpha": 0.72, "duration": 0.16, "sprite_alpha": 0.35},
		{"alpha": 0.43, "duration": 0.14, "sprite_alpha": 0.08},
		{"alpha": 0.68, "duration": 0.18, "sprite_alpha": 0.54},
		{"alpha": 0.30, "duration": 0.15, "sprite_alpha": 0.16},
		{"alpha": 0.58, "duration": 0.22, "sprite_alpha": 0.78},
		{"alpha": 0.22, "duration": 0.34, "sprite_alpha": 1.0}
	]

	for step in flicker_steps:
		var alpha := float(step.get("alpha", 0.5))
		var duration := float(step.get("duration", 0.08))
		var sprite_alpha := float(step.get("sprite_alpha", 1.0))
		var tween := create_tween()
		tween.set_parallel(true)
		if is_instance_valid(fog_overlay):
			tween.tween_property(fog_overlay, "modulate:a", alpha, duration)
		if is_instance_valid(lantern_reward_sprite):
			tween.tween_property(lantern_reward_sprite, "modulate:a", sprite_alpha, duration)
		await tween.finished
	await get_tree().create_timer(0.18).timeout


func _on_firefly_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, firefly: Area2D) -> void:
	if not _is_click_event(event):
		return
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.FIREFLIES:
		return
	_request_collect_firefly(firefly.name)


func _request_collect_firefly(firefly_name: String) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_server_collect_firefly(firefly_name)
	else:
		rpc_request_collect_firefly.rpc_id(_SERVER_PEER_ID, firefly_name)


@rpc("any_peer", "reliable")
func rpc_request_collect_firefly(firefly_name: String) -> void:
	if multiplayer.is_server():
		_server_collect_firefly(firefly_name)


func _server_collect_firefly(firefly_name: String) -> void:
	if _current_phase != BackyardPhase.FIREFLIES or _zone_failed:
		return
	if _caught_fireflies.has(firefly_name):
		return

	_caught_fireflies[firefly_name] = true
	_fireflies_collected = min(_fireflies_collected + 1, REQUIRED_FIREFLIES)

	if multiplayer.has_multiplayer_peer():
		rpc_firefly_collected.rpc(firefly_name, _fireflies_collected)
	else:
		rpc_firefly_collected(firefly_name, _fireflies_collected)

	if _fireflies_collected >= REQUIRED_FIREFLIES:
		if multiplayer.has_multiplayer_peer():
			rpc_lantern_ready.rpc()
		else:
			rpc_lantern_ready()


@rpc("any_peer", "reliable", "call_local")
func rpc_firefly_collected(firefly_name: String, count: int) -> void:
	_fireflies_collected = count

	var firefly := get_node_or_null("FireflyLayer/" + firefly_name)
	if is_instance_valid(firefly):
		if firefly is Area2D:
			_set_area_enabled(firefly, false)
		_animate_firefly_capture(firefly)

	_update_quest_labels()
	show_notification("Fireflies caught: " + str(_fireflies_collected) + "/5", 1.5)


@rpc("any_peer", "reliable", "call_local")
func rpc_lantern_ready() -> void:
	_current_phase = BackyardPhase.LANTERN

	if is_instance_valid(firefly_layer):
		firefly_layer.visible = false

	# Show the lantern reward UI instead of forcing the world lantern sprite size.
	if is_instance_valid(new_lantern):
		new_lantern.visible = false
		new_lantern.scale = _new_lantern_base_scale

	_play_lantern_reward_animation()

	if is_instance_valid(fog_overlay):
		var fog_tween := create_tween()
		fog_tween.tween_property(fog_overlay, "modulate:a", 0.58, 0.5)

	_refresh_lantern_use_button()
	show_notification("Detective, use lantern to light up the backyard.", 3.0)
	_update_quest_labels()


func _on_fog_patch_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_click_event(event):
		return
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.LANTERN:
		show_notification("The lantern needs firefly light first.", 2.0)
		return

	# If you added the bottom Use Lantern button, let that button control this step.
	# This keeps the action clear: fireflies first, then Detective uses the lantern.
	if is_instance_valid(use_lantern_button):
		if _is_detective_solver():
			show_notification("Press Use Lantern at the bottom of the screen.", 2.0)
		else:
			show_notification("Tell the Detective to use the Firefly Lantern.", 2.0)
		return

	# Fallback if the button has not been added to the scene yet.
	_request_reveal_ghost()


func _request_reveal_ghost() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_server_reveal_ghost()
	else:
		rpc_request_reveal_ghost.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_reveal_ghost() -> void:
	if multiplayer.is_server():
		_server_reveal_ghost()


func _server_reveal_ghost() -> void:
	if _current_phase != BackyardPhase.LANTERN or _zone_failed:
		return
	if multiplayer.has_multiplayer_peer():
		rpc_reveal_ghost.rpc()
	else:
		rpc_reveal_ghost()


@rpc("any_peer", "reliable", "call_local")
func rpc_reveal_ghost() -> void:
	_current_phase = BackyardPhase.DECODE_NAME

	_set_lantern_reward_layer_visible(false)
	_set_dialogue_input_lock(true)
	await _play_lantern_old_bulb_flicker()

	if is_instance_valid(fog_sprite):
		var fog_sprite_tween := create_tween()
		fog_sprite_tween.tween_property(fog_sprite, "modulate:a", 0.0, 0.8)
		fog_sprite_tween.tween_callback(func(): fog_sprite.visible = false)

	await _play_ghost_glitch_reveal()

	await _play_ghost_dialogue_typewriter(GHOST_REVEAL_LINE)

	await _play_backyard_dialogue("backyard_after_ghost_reveal", _get_after_ghost_reveal_dialogue())

	_set_dialogue_input_lock(false)

	show_notification("Look for the name tag on the ghost.", 3.5)
	_update_quest_labels()


func _spawn_ghost_glitch_bar(color: Color, y_position: float, height: float, duration: float) -> void:
	var bar := ColorRect.new()
	bar.name = "GhostGlitchBar"
	bar.position = Vector2(-160.0, y_position)
	bar.size = Vector2(1800.0, height)
	bar.color = color
	bar.modulate.a = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = 990
	add_child(bar)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(bar, "modulate:a", 1.0, duration * 0.22)
	tween.tween_property(bar, "position:x", randf_range(-260.0, -40.0), duration)
	tween.tween_property(bar, "modulate:a", 0.0, duration * 0.38).set_delay(duration * 0.42)
	tween.chain().tween_callback(bar.queue_free)


func _play_tikbalang_consequence_glitch(screen_text: String, final_strike: bool = false, strike_count: int = 1) -> void:
	hide_notification()

	var overlay := ColorRect.new()
	overlay.name = "TikbalangConsequenceOverlay"
	overlay.position = Vector2(-1600.0, -900.0)
	overlay.size = Vector2(4600.0, 3000.0)
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 980
	add_child(overlay)

	var warning_label := Label.new()
	warning_label.name = "TikbalangConsequenceText"
	warning_label.text = screen_text
	warning_label.visible_ratio = 0.0
	warning_label.position = Vector2(180.0, 245.0)
	warning_label.size = Vector2(1000.0, 150.0)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.add_theme_font_size_override("font_size", 48 if final_strike else 38)
	warning_label.add_theme_color_override("font_color", Color(0.95, 0.04, 0.03, 1.0))
	warning_label.add_theme_constant_override("outline_size", 7)
	warning_label.add_theme_color_override("font_outline_color", Color.BLACK)
	warning_label.z_index = 1000
	add_child(warning_label)

	var target_alpha := 1.0 if final_strike else clampf(0.48 + float(strike_count) * 0.18, 0.62, 0.86)
	var blacken := create_tween()
	blacken.tween_property(overlay, "modulate:a", target_alpha, 1.35 if final_strike else 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await blacken.finished

	var reveal_duration := 2.4 if final_strike else 1.8
	var text_reveal := create_tween()
	text_reveal.tween_property(warning_label, "visible_ratio", 1.0, reveal_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var glitch_colors := [
		Color(1, 1, 1, 0.9),
		Color(0.68, 0.68, 0.68, 0.86),
		Color(0.08, 0.08, 0.08, 0.9)
	]
	var hold_time := 8.0 + reveal_duration
	var elapsed := 0.0
	while elapsed < hold_time:
		for j in range(5 if final_strike else 3):
			_spawn_ghost_glitch_bar(glitch_colors[randi() % glitch_colors.size()], randf_range(35.0, 660.0), randf_range(10.0, 62.0), randf_range(0.08, 0.18))
		warning_label.modulate.a = 1.0
		warning_label.add_theme_color_override("font_color", Color(0.95, 0.04, 0.03, 1.0))
		await get_tree().create_timer(0.18).timeout
		elapsed += 0.18

	if final_strike:
		return

	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(overlay, "modulate:a", 0.0, 0.35)
	fade.tween_property(warning_label, "modulate:a", 0.0, 0.35)
	await fade.finished

	if is_instance_valid(overlay):
		overlay.queue_free()
	if is_instance_valid(warning_label):
		warning_label.queue_free()


func _play_ghost_glitch_reveal() -> void:
	if not is_instance_valid(ghost_layer):
		return

	ghost_layer.visible = true

	var base_layer_position := ghost_layer.position
	if ghost_layer.has_meta("ux_ghost_base_position"):
		var stored_position: Variant = ghost_layer.get_meta("ux_ghost_base_position", base_layer_position)
		if stored_position is Vector2:
			base_layer_position = stored_position
	else:
		ghost_layer.set_meta("ux_ghost_base_position", base_layer_position)

	var base_sprite_position := Vector2.ZERO
	if is_instance_valid(ghost_sprite):
		base_sprite_position = ghost_sprite.position
		if ghost_sprite.has_meta("ux_ghost_sprite_base_position"):
			var stored_sprite_position: Variant = ghost_sprite.get_meta("ux_ghost_sprite_base_position", base_sprite_position)
			if stored_sprite_position is Vector2:
				base_sprite_position = stored_sprite_position
		else:
			ghost_sprite.set_meta("ux_ghost_sprite_base_position", base_sprite_position)

	ghost_layer.position = base_layer_position
	ghost_layer.modulate.a = 1.0

	if is_instance_valid(ghost_sprite):
		ghost_sprite.position = base_sprite_position
		ghost_sprite.modulate.a = 0.0

	var glitch_steps := [
		{"alpha": 0.0, "fog_alpha": 0.88, "duration": 0.08, "flash": Color(1, 1, 1, 0.82)},
		{"alpha": 0.68, "fog_alpha": 0.18, "duration": 0.07, "flash": Color(0.96, 0.2, 0.16, 0.72)},
		{"alpha": 0.12, "fog_alpha": 0.82, "duration": 0.06, "flash": Color(0.2, 0.78, 1.0, 0.58)},
		{"alpha": 0.86, "fog_alpha": 0.12, "duration": 0.08, "flash": Color(1, 0.82, 0.24, 0.66)},
		{"alpha": 0.18, "fog_alpha": 0.72, "duration": 0.06, "flash": Color(1, 1, 1, 0.76)},
		{"alpha": 0.92, "fog_alpha": 0.2, "duration": 0.1, "flash": Color(0.96, 0.2, 0.16, 0.62)},
		{"alpha": 0.35, "fog_alpha": 0.58, "duration": 0.08, "flash": Color(0.2, 0.78, 1.0, 0.56)},
		{"alpha": 0.74, "fog_alpha": 0.24, "duration": 0.18, "flash": Color(1, 1, 1, 0.5)}
	]

	for step in glitch_steps:
		var flash_value: Variant = step.get("flash", Color(1, 1, 1, 0.7))
		var flash_color: Color = flash_value if flash_value is Color else Color(1, 1, 1, 0.7)
		for i in range(3):
			_spawn_ghost_glitch_bar(flash_color, randf_range(40.0, 640.0), randf_range(8.0, 46.0), float(step.get("duration", 0.08)) + randf_range(0.02, 0.08))

		var tween := create_tween()
		tween.set_parallel(true)
		if is_instance_valid(ghost_sprite):
			ghost_sprite.position = base_sprite_position
			tween.tween_property(ghost_sprite, "modulate:a", float(step.get("alpha", 0.5)), float(step.get("duration", 0.08)))
		if is_instance_valid(fog_overlay):
			tween.tween_property(fog_overlay, "modulate:a", float(step.get("fog_alpha", 0.22)), float(step.get("duration", 0.08)))
		await tween.finished

	if is_instance_valid(ghost_sprite):
		var settle_tween := create_tween()
		settle_tween.set_parallel(true)
		settle_tween.tween_property(ghost_sprite, "position", base_sprite_position, 0.2)
		settle_tween.tween_property(ghost_sprite, "modulate:a", 0.7, 0.28)
		await settle_tween.finished


func _on_name_tag_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_click_event(event):
		return
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.DECODE_NAME:
		return
	_request_open_decode_panel()


func _request_open_decode_panel() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_server_open_decode_panel()
	else:
		rpc_request_open_decode_panel.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_open_decode_panel() -> void:
	if multiplayer.is_server():
		_server_open_decode_panel()


func _server_open_decode_panel() -> void:
	if _current_phase != BackyardPhase.DECODE_NAME or _zone_failed:
		return
	if multiplayer.has_multiplayer_peer():
		rpc_open_decode_panel.rpc(_word_puzzle_question_index, _word_puzzle_revealed_count)
	else:
		rpc_open_decode_panel(_word_puzzle_question_index, _word_puzzle_revealed_count)

func _style_decode_instruction_label(label: Label) -> void:
	if not is_instance_valid(label):
		return

	label.add_theme_font_size_override("font_size", DECODE_INSTRUCTION_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false

@rpc("any_peer", "reliable", "call_local")
func rpc_open_decode_panel(question_index: int = 0, revealed_count: int = 0) -> void:
	if is_instance_valid(decode_ui_layer):
		decode_ui_layer.visible = false
	if is_instance_valid(decode_panel):
		decode_panel.visible = false
	if is_instance_valid(sidekick_name_tag):
		sidekick_name_tag.visible = false

	_word_puzzle_question_index = clampi(question_index, 0, WORD_PUZZLE_QUESTIONS.size())
	_word_puzzle_revealed_count = clampi(revealed_count, 0, WORD_PUZZLE_QUESTIONS.size())
	_set_word_puzzle_visible(true)
	_animate_panel_pop(word_puzzle_layer, 0.97)

	if _is_word_puzzle_local_turn() and is_instance_valid(word_puzzle_answer_input):
		word_puzzle_answer_input.grab_focus()
	hide_notification()


func _on_word_puzzle_clear_pressed() -> void:
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.DECODE_NAME:
		return
	if not _is_word_puzzle_local_turn():
		return
	if is_instance_valid(word_puzzle_answer_input):
		word_puzzle_answer_input.text = ""
		word_puzzle_answer_input.grab_focus()


func _on_word_puzzle_answer_submitted(_answer: String) -> void:
	_on_word_puzzle_submit_pressed()


func _on_word_puzzle_submit_pressed() -> void:
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.DECODE_NAME:
		return
	if not _is_word_puzzle_local_turn():
		return

	var answer := ""
	if is_instance_valid(word_puzzle_answer_input):
		answer = word_puzzle_answer_input.text.strip_edges()

	if answer.is_empty():
		_flash_input_state(word_puzzle_answer_input, false)
		show_notification("Enter your answer first.", 1.8)
		return

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var sender_peer_id := _SERVER_PEER_ID
		if multiplayer.has_multiplayer_peer():
			sender_peer_id = multiplayer.get_unique_id()
		_server_validate_word_puzzle_answer(answer, sender_peer_id)
	else:
		rpc_request_validate_word_puzzle_answer.rpc_id(_SERVER_PEER_ID, answer)


@rpc("any_peer", "reliable")
func rpc_request_validate_word_puzzle_answer(answer: String) -> void:
	if multiplayer.is_server():
		_server_validate_word_puzzle_answer(answer, multiplayer.get_remote_sender_id())


func _server_validate_word_puzzle_answer(answer: String, sender_peer_id: int) -> void:
	if _current_phase != BackyardPhase.DECODE_NAME or _zone_failed:
		return
	if _word_puzzle_question_index < 0 or _word_puzzle_question_index >= WORD_PUZZLE_QUESTIONS.size():
		return
	if not _is_word_puzzle_peer_turn(sender_peer_id, _word_puzzle_question_index):
		return

	if not _is_word_puzzle_answer_correct(answer, _word_puzzle_question_index):
		_server_add_strike("The Tikbalang twists the answer in the fog...")
		return

	_word_puzzle_revealed_count += 1
	_word_puzzle_question_index += 1

	if multiplayer.has_multiplayer_peer():
		rpc_word_puzzle_answer_correct.rpc(_word_puzzle_question_index, _word_puzzle_revealed_count)
	else:
		rpc_word_puzzle_answer_correct(_word_puzzle_question_index, _word_puzzle_revealed_count)


func _is_word_puzzle_peer_turn(peer_id: int, question_index: int) -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true

	var expected_role := _get_word_puzzle_question_role(question_index)
	if expected_role == WORD_PUZZLE_DETECTIVE:
		return peer_id == _SERVER_PEER_ID
	return peer_id != _SERVER_PEER_ID


func _is_word_puzzle_answer_correct(answer: String, question_index: int) -> bool:
	var normalized := _normalize_word_puzzle_answer(answer)
	var valid_answers: Array = WORD_PUZZLE_QUESTIONS[question_index].get("answers", [])
	for valid_answer in valid_answers:
		if normalized == _normalize_word_puzzle_answer(str(valid_answer)):
			return true
	return false


@rpc("any_peer", "reliable", "call_local")
func rpc_word_puzzle_answer_correct(question_index: int, revealed_count: int) -> void:
	var revealed_index := clampi(revealed_count - 1, 0, word_puzzle_letters.size() - 1)
	_word_puzzle_question_index = clampi(question_index, 0, WORD_PUZZLE_QUESTIONS.size())
	_word_puzzle_revealed_count = clampi(revealed_count, 0, WORD_PUZZLE_QUESTIONS.size())
	if is_instance_valid(word_puzzle_answer_input):
		word_puzzle_answer_input.text = ""
		_flash_input_state(word_puzzle_answer_input, true)

	if revealed_index >= 0 and revealed_index < word_puzzle_letters.size():
		var letter := word_puzzle_letters[revealed_index] as Sprite2D
		_animate_letter_reveal(letter)

	_refresh_word_puzzle_ui()

	_show_word_puzzle_reward(revealed_index)


func _request_finish_word_puzzle() -> void:
	if _current_phase != BackyardPhase.DECODE_NAME or _zone_failed:
		return
	if _word_puzzle_revealed_count < WORD_PUZZLE_QUESTIONS.size():
		return

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if multiplayer.has_multiplayer_peer():
			rpc_name_decoded.rpc()
		else:
			rpc_name_decoded()
	else:
		rpc_request_finish_word_puzzle.rpc_id(_SERVER_PEER_ID)


func _server_close_word_puzzle_reward(puzzle_complete: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		rpc_close_word_puzzle_reward.rpc(puzzle_complete)
	else:
		await rpc_close_word_puzzle_reward(puzzle_complete)

	if puzzle_complete:
		await get_tree().create_timer(0.08).timeout
		if _current_phase == BackyardPhase.DECODE_NAME and not _zone_failed:
			if multiplayer.has_multiplayer_peer():
				rpc_name_decoded.rpc()
			else:
				rpc_name_decoded()


@rpc("any_peer", "reliable")
func rpc_request_close_word_puzzle_reward(puzzle_complete: bool, reward_index: int) -> void:
	if not multiplayer.is_server():
		return
	if not _word_puzzle_reward_active:
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	if not _is_word_puzzle_peer_turn(sender_peer_id, reward_index):
		return
	await _server_close_word_puzzle_reward(puzzle_complete)


@rpc("authority", "reliable", "call_local")
func rpc_close_word_puzzle_reward(puzzle_complete: bool) -> void:
	await _hide_word_puzzle_reward(not puzzle_complete)
	if not puzzle_complete and _is_word_puzzle_local_turn() and is_instance_valid(word_puzzle_answer_input):
		word_puzzle_answer_input.grab_focus()


@rpc("any_peer", "reliable")
func rpc_request_finish_word_puzzle() -> void:
	if not multiplayer.is_server():
		return
	if _current_phase != BackyardPhase.DECODE_NAME or _zone_failed:
		return
	if _word_puzzle_revealed_count < WORD_PUZZLE_QUESTIONS.size():
		return
	rpc_name_decoded.rpc()

func _on_decode_submit_pressed() -> void:
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.DECODE_NAME:
		return
	if not _is_detective_solver():
		return

	var answer := ""
	if is_instance_valid(name_input):
		answer = name_input.text.strip_edges().to_upper()

	if answer.is_empty():
		show_notification("Enter the decoded name first.", 1.8)
		return

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_server_validate_decoded_name(answer)
	else:
		rpc_request_validate_decoded_name.rpc_id(_SERVER_PEER_ID, answer)


@rpc("any_peer", "reliable")
func rpc_request_validate_decoded_name(answer: String) -> void:
	if multiplayer.is_server():
		_server_validate_decoded_name(answer)


func _server_validate_decoded_name(answer: String) -> void:
	if _current_phase != BackyardPhase.DECODE_NAME or _zone_failed:
		return

	if answer == decoded_name:
		if multiplayer.has_multiplayer_peer():
			rpc_name_decoded.rpc()
		else:
			rpc_name_decoded()
	else:
		_server_add_strike("The Tikbalang twists the letters in the fog...")


@rpc("any_peer", "reliable", "call_local")
func rpc_name_decoded() -> void:
	_current_phase = BackyardPhase.DISTANCE

	if is_instance_valid(decode_ui_layer):
		decode_ui_layer.visible = false

	if is_instance_valid(decode_panel):
		decode_panel.visible = false

	if is_instance_valid(sidekick_name_tag):
		sidekick_name_tag.visible = false
	_set_word_puzzle_visible(false)

	if is_instance_valid(name_input):
		name_input.editable = false

	if is_instance_valid(decode_submit_button):
		decode_submit_button.disabled = true

	_update_quest_labels()
	_set_dialogue_input_lock(true)

	await _play_ghost_dialogue_lines([
		"Yes, I am Pina.",
		"Something of me remained here.",
		"Find where my memory remains.",
		"It is " + str(memory_distance_dali) + " Dali away from me."
	])

	await _play_backyard_dialogue("backyard_after_memory_clue", _get_after_memory_clue_dialogue())

	hide_notification()
	_show_dali_conversion_ledger()
	_open_distance_board_local()
	_set_dialogue_input_lock(false)

func _on_board_tap_pressed() -> void:
	# Board is now opened automatically after decoding Pina's name.
	if _dialogue_input_locked or not _board_unlocked or _zone_failed or _puzzle_solved:
		return
	_open_distance_board_local()


func _open_board_local() -> void:
	_open_distance_board_local()


func _open_distance_board_local() -> void:
	_board_unlocked = true
	_board_opened = true
	_grass_transition_focus_active = false
	var detective_solver := _is_detective_solver()

	if is_instance_valid(board_layer):
		board_layer.visible = detective_solver
	if is_instance_valid(board_sprite):
		board_sprite.visible = detective_solver
		board_sprite.modulate.a = 1.0
		if detective_solver:
			_animate_panel_pop(board_sprite, 0.95)
	if is_instance_valid(board_tap_button):
		board_tap_button.visible = false
		board_tap_button.disabled = true
	if is_instance_valid(board_height_label):
		board_height_label.visible = detective_solver
		board_height_label.modulate.a = 1.0
		board_height_label.text = str(memory_distance_dali) + " Dali"
	if is_instance_valid(board_instruction_label):
		board_instruction_label.visible = detective_solver
		board_instruction_label.modulate.a = 1.0
		board_instruction_label.text = "Convert Dali to Centimeters"
		board_instruction_label.add_theme_font_size_override("font_size", 22)

	if is_instance_valid(feedback_label):
		feedback_label.text = ""
		feedback_label.visible = false
		feedback_label.modulate.a = 1.0

	if is_instance_valid(x_input):
		x_input.visible = detective_solver
		x_input.editable = detective_solver
		x_input.text = ""
		x_input.placeholder_text = "CM value"
		x_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		_refresh_distance_input_visual_state()
		if detective_solver:
			x_input.grab_focus()

	if is_instance_valid(submit_button):
		submit_button.visible = detective_solver
		submit_button.disabled = not detective_solver
		submit_button.modulate = Color.WHITE if detective_solver else Color(1, 1, 1, 0.72)
		_set_attention_pulse(submit_button, detective_solver)

	if is_instance_valid(ledger_panel):
		_populate_ledger_content()
		ledger_panel.visible = not detective_solver
		ledger_panel.modulate.a = 1.0
	if is_instance_valid(ledger_touch_button):
		ledger_touch_button.visible = not detective_solver
		ledger_touch_button.modulate = Color.WHITE
	if is_instance_valid(touch_controls) and touch_controls.has_method("set_ledger_enabled"):
		touch_controls.set_ledger_enabled(not detective_solver)

	_refresh_focus_overlay_state()
	hide_notification()

func _request_start_timer() -> void:
	if _timer_started:
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_start_board_timer_server()
	else:
		rpc_request_start_timer.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_start_timer() -> void:
	if multiplayer.is_server():
		_start_board_timer_server()


func _start_board_timer_server() -> void:
	if _timer_started or _puzzle_solved or _zone_failed:
		return
	_timer_started = true
	rpc_timer_started.rpc()
	_timer_node.start(TOTAL_TIME_SEC)


@rpc("any_peer", "reliable", "call_local")
func rpc_timer_started() -> void:
	_timer_started = true


func _on_board_timer_timeout() -> void:
	if not multiplayer.is_server() or _puzzle_solved or _zone_failed:
		return
	_server_fail_zone("The forest rejects your presence.\nReturn in 1 minute to try again.")


func _on_ledger_pressed() -> void:
	# Restored from the old Backyard Path behavior:
	# Sidekick taps the ledger button to toggle the ledger panel.
	if _dialogue_input_locked or GameState.local_role != GameState.Role.SIDEKICK or not is_instance_valid(ledger_panel):
		return

	# Always refresh from PuzzleManager before opening, so the old ledger information is displayed.
	_populate_ledger_content()

	var should_open: bool = not ledger_panel.visible

	if should_open and is_instance_valid(briefcase_panel):
		briefcase_panel.visible = false

	ledger_panel.visible = should_open

	if ledger_panel.visible:
		hide_notification()
		pulse_ledger_guidance(false)
	else:
		hide_notification()

func _on_briefcase_button_pressed() -> void:
	if _dialogue_input_locked or GameState.local_role != GameState.Role.SIDEKICK or not is_instance_valid(briefcase_panel):
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
	briefcase_display.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	briefcase_display.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	briefcase_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefcase_display.offset_left = -152.0
	briefcase_display.offset_top = 40.0
	briefcase_display.offset_right  = 185.0
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


func _on_pause_button_pressed() -> void:
	if is_instance_valid(pause_canvas_layer): pause_canvas_layer.visible = true
	if is_instance_valid(in_game_pause_panel): in_game_pause_panel.visible = true
	if is_instance_valid(option_sub_panel): option_sub_panel.visible = false
	if is_instance_valid(inside_zone_control): inside_zone_control.visible = false
	MusicController.pause_music()
	get_tree().paused = true


func _on_resume_play_button_pressed() -> void:
	if is_instance_valid(in_game_pause_panel): in_game_pause_panel.visible = false
	if is_instance_valid(option_sub_panel): option_sub_panel.visible = false
	if is_instance_valid(pause_canvas_layer): pause_canvas_layer.visible = false
	get_tree().paused = false
	MusicController.resume_music()
	if is_instance_valid(inside_zone_control): inside_zone_control.visible = true


func _on_option_button_pressed() -> void:
	if is_instance_valid(option_sub_panel): option_sub_panel.visible = true
	_sync_volume_ui()


func _on_in_game_option_back_pressed() -> void:
	if is_instance_valid(option_sub_panel): option_sub_panel.visible = false


func _on_exit_to_main_menu_button_pressed() -> void:
	if is_instance_valid(pause_canvas_layer): pause_canvas_layer.visible = false
	get_tree().paused = false
	MusicController.resume_music()
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _on_in_game_volume_changed(value: float) -> void:
	MusicController.set_volume(value / 100.0)
	if is_instance_valid(volume_value_label):
		volume_value_label.text = str(int(value)) + "%"


func pulse_ledger_guidance(enable: bool) -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		if is_instance_valid(guidance_arrow): guidance_arrow.visible = false
		return
	if _puzzle_solved: enable = false
	_ledger_hint_shown = enable
	if is_instance_valid(guidance_arrow): guidance_arrow.visible = enable
	if is_instance_valid(ledger_touch_button):
		if enable:
			if not ledger_touch_button.has_meta("pulse_tween"):
				var tw := create_tween()
				tw.set_loops()
				tw.tween_property(ledger_touch_button, "scale", Vector2(0.07, 0.07), 0.4)
				tw.tween_property(ledger_touch_button, "scale", Vector2(0.06, 0.06), 0.4)
				ledger_touch_button.set_meta("pulse_tween", tw)
		else:
			if ledger_touch_button.has_meta("pulse_tween"):
				var old_tw: Tween = ledger_touch_button.get_meta("pulse_tween")
				if old_tw: old_tw.kill()
				ledger_touch_button.remove_meta("pulse_tween")
			ledger_touch_button.scale = Vector2(0.06, 0.06)


func _on_submit_pressed() -> void:
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.DISTANCE:
		return
	if not _is_detective_solver():
		return
	if not _board_unlocked or _puzzle_solved:
		return

	var answer_text := x_input.text.strip_edges()
	if answer_text.is_empty():
		if is_instance_valid(feedback_label):
			_flash_label(feedback_label, UI_ERROR, "Enter an answer first.")
		_flash_input_state(x_input, false)
		return
	if not answer_text.is_valid_int():
		if is_instance_valid(feedback_label):
			_flash_label(feedback_label, UI_ERROR, "Numbers only.")
		_flash_input_state(x_input, false)
		show_notification("Numbers only. Try again.", 1.8)
		return

	var value := int(answer_text)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_server_validate_answer(value)
	else:
		rpc_request_validate_answer.rpc_id(_SERVER_PEER_ID, value)


@rpc("any_peer", "reliable")
func rpc_request_validate_answer(value: int) -> void:
	if multiplayer.is_server():
		_server_validate_answer(value)


func _server_validate_answer(value: int) -> void:
	if _current_phase != BackyardPhase.DISTANCE or _puzzle_solved or _zone_failed:
		return
	if value == memory_distance_cm:
		if multiplayer.has_multiplayer_peer():
			rpc_distance_answered.rpc()
		else:
			rpc_distance_answered()
	else:
		_server_add_strike("The lantern light fades before reaching the hidden place...")


func _server_add_strike(message: String) -> void:
	if _zone_failed:
		return
	_strikes += 1

	var strike_message := message
	match _strikes:
		1:
			strike_message = "Wrong again, brave little detectives."
		2:
			strike_message = "Run in circles. The backyard knows you are lost."
		_:
			strike_message = "The backyard rejects your presence"

	if _strikes >= MAX_STRIKES:
		_server_fail_zone("The backyard rejects your presence")
		return

	if multiplayer.has_multiplayer_peer():
		rpc_apply_strike.rpc(_strikes, strike_message)
	else:
		rpc_apply_strike(_strikes, strike_message)


@rpc("any_peer", "reliable", "call_local")
func rpc_apply_strike(strike_count: int, strike_message: String) -> void:
	_strikes = strike_count
	if is_instance_valid(feedback_label):
		_flash_label(feedback_label, UI_ERROR, strike_message)
	if is_instance_valid(fog_overlay):
		match strike_count:
			1:
				fog_overlay.modulate.a = 0.50
			2:
				fog_overlay.modulate.a = 0.66
			_:
				fog_overlay.modulate.a = 0.85
	if _current_phase == BackyardPhase.DISTANCE:
		_flash_input_state(x_input, false)
	elif _current_phase == BackyardPhase.DECODE_NAME:
		_flash_input_state(word_puzzle_answer_input, false)
	if is_instance_valid(board_sprite) and board_layer.visible:
		_shake_node(board_sprite, 12.0, 0.3)
	elif is_instance_valid(word_puzzle_layer) and word_puzzle_layer.visible:
		_shake_node(word_puzzle_layer, 12.0, 0.3)
	await _play_tikbalang_consequence_glitch(strike_message, false, strike_count)

func _server_fail_zone(message: String) -> void:
	if _zone_failed:
		return
	_zone_failed = true
	GameState.lock_zone_temp(ZONE_ID, 30)
	if multiplayer.has_multiplayer_peer():
		rpc_fail_zone.rpc(message)
	else:
		rpc_fail_zone(message)


@rpc("any_peer", "reliable", "call_local")
func rpc_fail_zone(message: String) -> void:
	_zone_failed = true
	_board_unlocked = false
	if is_instance_valid(board_tap_button):  board_tap_button.disabled  = true
	if is_instance_valid(submit_button): submit_button.disabled = true
	hide_notification()
	_set_dialogue_input_lock(true)
	await _play_tikbalang_consequence_glitch(message, true, MAX_STRIKES)
	_set_dialogue_input_lock(false)
	await get_tree().create_timer(0.5).timeout
	_return_to_forest()


func _get_grass_focus_position() -> Vector2:
	if is_instance_valid(grass_focus_point):
		return grass_focus_point.global_position

	if is_instance_valid(grass_layer):
		var total := Vector2.ZERO
		var count := 0

		for area in grass_layer.get_children():
			if area is Node2D:
				for visual in area.get_children():
					if visual is Sprite2D or visual is CollisionShape2D:
						total += visual.global_position
						count += 1

		if count > 0:
			return total / float(count)

		return grass_layer.global_position

	return _camera_original_position


func _zoom_camera_to_grass() -> void:
	if not is_instance_valid(focus_camera):
		return

	focus_camera.enabled = true
	focus_camera.make_current()

	var target_pos := _get_grass_focus_position()
	var target_zoom := Vector2(1.45, 1.45)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(focus_camera, "global_position", target_pos, 1.45)
	tween.tween_property(focus_camera, "zoom", target_zoom, 1.45)
	await tween.finished


func _play_distance_to_grass_transition() -> void:
	if is_instance_valid(board_sprite):
		var board_tween := create_tween()
		board_tween.set_parallel(true)
		board_tween.tween_property(board_sprite, "modulate:a", 0.0, 0.28)
		board_tween.tween_property(board_sprite, "scale", _get_canvas_item_base_scale(board_sprite) * 0.96, 0.28)
		if is_instance_valid(feedback_label):
			board_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.2)
		if is_instance_valid(board_height_label):
			board_tween.tween_property(board_height_label, "modulate:a", 0.0, 0.2)
		if is_instance_valid(board_instruction_label):
			board_tween.tween_property(board_instruction_label, "modulate:a", 0.0, 0.2)
		if is_instance_valid(x_input):
			board_tween.tween_property(x_input, "modulate:a", 0.0, 0.2)
		if is_instance_valid(submit_button):
			board_tween.tween_property(submit_button, "modulate:a", 0.0, 0.2)
		if is_instance_valid(ledger_panel):
			board_tween.tween_property(ledger_panel, "modulate:a", 0.0, 0.22)
		await board_tween.finished

	if is_instance_valid(fog_overlay):
		fog_overlay.visible = true
		var fade_up := create_tween()
		fade_up.tween_property(fog_overlay, "modulate:a", 0.82, 0.45)
		await fade_up.finished


func _hide_ghost_before_grass_focus() -> void:
	_ghost_dialogue_typing = false

	if is_instance_valid(ghost_dialogue_label):
		ghost_dialogue_label.visible = false
		ghost_dialogue_label.text = ""
	if is_instance_valid(_ghost_dialogue_overlay):
		_ghost_dialogue_overlay.visible = false

	if is_instance_valid(ghost_name_tag):
		_set_area_enabled(ghost_name_tag, false)

	if not is_instance_valid(ghost_layer):
		return
	if ghost_layer.has_meta("ux_focus_restore_visible"):
		ghost_layer.remove_meta("ux_focus_restore_visible")
	if not ghost_layer.visible:
		ghost_layer.modulate.a = 0.0
		return

	var ghost_tween := create_tween()
	ghost_tween.tween_property(ghost_layer, "modulate:a", 0.0, 0.35)
	await ghost_tween.finished

	if is_instance_valid(ghost_layer):
		ghost_layer.visible = false
	_refresh_focus_overlay_state()

@rpc("any_peer", "reliable", "call_local")
func rpc_distance_answered() -> void:
	_current_phase = BackyardPhase.GRASS
	_board_unlocked = false
	_board_opened = false
	_grass_transition_focus_active = true
	hide_notification()
	_refresh_focus_overlay_state()

	if is_instance_valid(feedback_label):
		feedback_label.visible = is_instance_valid(board_layer) and board_layer.visible
		feedback_label.modulate.a = 1.0
		_flash_label(feedback_label, UI_SUCCESS, "Correct! The light points to the grass.")
	if is_instance_valid(x_input):
		_flash_input_state(x_input, true)
	await _hide_ghost_before_grass_focus()
	await get_tree().create_timer(0.6).timeout
	await _play_distance_to_grass_transition()

	if is_instance_valid(board_layer):
		board_layer.visible = false

	if is_instance_valid(x_input):
		x_input.visible = false
		x_input.editable = false
		x_input.modulate.a = 1.0
		_refresh_distance_input_visual_state()

	if is_instance_valid(submit_button):
		submit_button.visible = false
		submit_button.disabled = true
		submit_button.modulate.a = 1.0

	if is_instance_valid(feedback_label):
		feedback_label.text = ""
		feedback_label.visible = false
		feedback_label.modulate.a = 1.0
	if is_instance_valid(board_height_label):
		board_height_label.visible = false
		board_height_label.modulate.a = 1.0
	if is_instance_valid(board_instruction_label):
		board_instruction_label.visible = false
		board_instruction_label.modulate.a = 1.0

	if is_instance_valid(board_sprite):
		board_sprite.modulate.a = 1.0
		board_sprite.scale = _get_canvas_item_base_scale(board_sprite)

	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false
		ledger_panel.modulate.a = 1.0

	_refresh_focus_overlay_state()

	if is_instance_valid(grass_layer):
		grass_layer.visible = true
		for child in grass_layer.get_children():
			if child is Area2D:
				child.visible = true
				_set_area_enabled(child, true)

	await _zoom_camera_to_grass()

	if is_instance_valid(fog_overlay):
		var fade_down := create_tween()
		fade_down.tween_property(fog_overlay, "modulate:a", 0.58, 0.55)
		await fade_down.finished

	_grass_transition_focus_active = false
	_refresh_focus_overlay_state()
	_update_quest_labels()

func _on_grass_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, grass_area: Area2D) -> void:
	if not _is_click_event(event):
		return
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.GRASS:
		return
	_request_clear_grass(grass_area.name)


func _request_clear_grass(grass_name: String) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_server_clear_grass(grass_name)
	else:
		rpc_request_clear_grass.rpc_id(_SERVER_PEER_ID, grass_name)


@rpc("any_peer", "reliable")
func rpc_request_clear_grass(grass_name: String) -> void:
	if multiplayer.is_server():
		_server_clear_grass(grass_name)


func _server_clear_grass(grass_name: String) -> void:
	if _current_phase != BackyardPhase.GRASS or _zone_failed:
		return

	var expected_name := ""
	match _clearing_stage:
		0:
			expected_name = "TallGrass"
		1:
			expected_name = "FallenLeaves"
		2:
			expected_name = "TangledVines"

	if grass_name != expected_name:
		return

	_clearing_stage += 1
	if multiplayer.has_multiplayer_peer():
		rpc_grass_cleared.rpc(grass_name, _clearing_stage)
	else:
		rpc_grass_cleared(grass_name, _clearing_stage)

	if _clearing_stage >= 3:
		if multiplayer.has_multiplayer_peer():
			rpc_reveal_pineapple_from_grass.rpc()
		else:
			rpc_reveal_pineapple_from_grass()


@rpc("any_peer", "reliable", "call_local")
func rpc_grass_cleared(grass_name: String, new_stage: int) -> void:
	_clearing_stage = new_stage
	var grass := get_node_or_null("GrassLayer/" + grass_name)
	if is_instance_valid(grass):
		if grass is Area2D:
			_set_area_enabled(grass, false)
		_animate_grass_clear(grass)

	match _clearing_stage:
		1:
			show_notification("Something sharp and green is growing here.", 2.5)
		2:
			show_notification("A strange fruit is hidden beneath the leaves.", 2.5)
		3:
			show_notification("The fruit had many eyes.", 2.5)


@rpc("any_peer", "reliable", "call_local")
func rpc_reveal_pineapple_from_grass() -> void:
	_current_phase = BackyardPhase.PINEAPPLE_REVEALED
	_puzzle_solved = true
	_board_unlocked = false
	_set_progress_tracker_stage(1)
	GameState.set_puzzle_solved(ZONE_ID, true)

	if is_instance_valid(grass_layer):
		grass_layer.visible = false
	if is_instance_valid(fog_overlay):
		fog_overlay.modulate.a = 0.18

	# Hide old role-based visuals and show only the new PineappleReveal layer.
	for node in [pina_spirit, detective_height_label, pineapple_plant, pineapple_fruit, sidekick_height_label, revealed_plant, revealed_pineapple]:
		if is_instance_valid(node):
			node.visible = false

	if is_instance_valid(fruit_tap_button):
		fruit_tap_button.visible = false
		fruit_tap_button.disabled = true

	if is_instance_valid(pineapple_reveal_layer):
		pineapple_reveal_layer.visible = true
	if is_instance_valid(pineapple_reveal_area):
		pineapple_reveal_area.visible = true
		_set_area_enabled(pineapple_reveal_area, true)
	if is_instance_valid(pineapple_reveal_plant):
		pineapple_reveal_plant.visible = true
	if is_instance_valid(pineapple_reveal_fruit):
		pineapple_reveal_fruit.visible = true

	_current_phase = BackyardPhase.SOLVED
	_update_quest_labels()
	# No notification here. The player taps the pineapple and goes straight to the reward sequence.


@rpc("any_peer", "reliable", "call_local")
func rpc_puzzle_solved() -> void:
	# Kept for compatibility with older calls. New flow uses rpc_reveal_pineapple_from_grass().
	rpc_reveal_pineapple_from_grass()

func _sync_fruit_tap_button_to_revealed_pineapple() -> void:
	if is_instance_valid(fruit_tap_button) and is_instance_valid(revealed_pineapple):
		fruit_tap_button.global_position = revealed_pineapple.global_position
		fruit_tap_button.scale = Vector2(1.4, 1.4)


func _blink_board() -> void:
	if not is_instance_valid(board_sprite):
		return
	var tw := create_tween()
	tw.tween_property(board_sprite, "modulate", Color(1, 1, 1, 0.3), 0.12)
	tw.tween_property(board_sprite, "modulate", Color(1, 1, 1, 1), 0.12)
	tw.tween_property(board_sprite, "modulate", Color(1, 1, 1, 0.3), 0.12)
	tw.tween_property(board_sprite, "modulate", Color(1, 1, 1, 1), 0.12)
	await tw.finished


func _on_pineapple_reveal_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_click_event(event):
		return
	if _dialogue_input_locked or not _puzzle_solved or _reward_active or _zone_failed:
		return

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		rpc_show_reward.rpc()
	else:
		rpc_request_show_reward.rpc_id(_SERVER_PEER_ID)


func _on_fruit_tap_pressed() -> void:
	if _dialogue_input_locked or not _puzzle_solved or _reward_active or _zone_failed:
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		rpc_show_reward.rpc()
	else:
		rpc_request_show_reward.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_show_reward() -> void:
	if multiplayer.is_server():
		rpc_show_reward.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_show_reward() -> void:
	if _reward_active: return
	_reward_active = true
	_waiting_reward_continue = true
	_reward_stage = 1
	_collect_sequence_started  = false

	_play_zone_completion_sfx()
	_hide_revealed_clue_after_touch()

	if is_instance_valid(fruit_tap_button):
		fruit_tap_button.disabled = true
		fruit_tap_button.visible  = false
	if is_instance_valid(reward_layer): reward_layer.visible = true
	if is_instance_valid(clue_sprite): clue_sprite.visible = true
	_spawn_artifact_reward_confetti()
	if is_instance_valid(clue_sprite):
		clue_sprite.modulate.a = 0.0
		clue_sprite.scale = Vector2(0.14, 0.14)
	if is_instance_valid(sparkle):
		sparkle.visible = true
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
		_animation_time = 0.0
		_sparkle_animating = true
	if is_instance_valid(reward_dark_overlay): reward_dark_overlay.modulate.a = 0.45
	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = true
		reward_banner_label.text = "ARTIFACT FOUND!"
		reward_banner_label.modulate.a = 0.0
	if is_instance_valid(reward_text_label): reward_text_label.text = ""
	if is_instance_valid(reward_panel): reward_panel.visible = false
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = true
		tap_instruction_label.text = "Tap anywhere to continue."
	if is_instance_valid(tap_catcher):
		tap_catcher.visible  = true
		tap_catcher.disabled = false
	if is_instance_valid(collect_button): collect_button.visible = false
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null

	var reward_tween := create_tween()
	reward_tween.set_parallel(true)
	if is_instance_valid(clue_sprite):
		reward_tween.tween_property(clue_sprite, "modulate:a", 1.0, 0.25)
		reward_tween.tween_property(clue_sprite, "scale", Vector2(0.16943358, 0.14160155), 0.25)
	if is_instance_valid(reward_banner_label):
		reward_tween.tween_property(reward_banner_label, "modulate:a", 1.0, 0.25)


func _on_collect_pressed() -> void:
	if _collect_sequence_started: return
	_collect_sequence_started = true
	if is_instance_valid(collect_button):
		collect_button.visible  = false
		collect_button.disabled = true
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		rpc_show_briefcase_reveal_then_finalize.rpc()
	else:
		rpc_request_collect_clue.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_collect_clue() -> void:
	if multiplayer.is_server():
		rpc_show_briefcase_reveal_then_finalize.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_finalize_clue() -> void:
	GameState.collect_clue(ZONE_ID)
	_sparkle_animating = false
	if is_instance_valid(sparkle):
		sparkle.visible = false
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
	if is_instance_valid(clue_sprite): clue_sprite.visible = false
	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = false
		reward_banner_label.text = ""
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null
	if is_instance_valid(reward_layer): reward_layer.visible = false
	if is_instance_valid(reward_dark_overlay): reward_dark_overlay.modulate.a = 0.0
	await _fade_out(0.6)
	_play_ending_cutscene()
	await _fade_in(0.6)


func show_notification(text: String, duration: float = 2.0) -> void:
	if not is_instance_valid(notification_panel) or not is_instance_valid(notification_label):
		return
	notification_label.text = text
	notification_panel.modulate.a = 0.0
	notification_panel.visible = true
	var current_id := Time.get_ticks_msec()
	notification_panel.set_meta("msg_id", current_id)

	if notification_panel.has_meta("ux_notification_tween"):
		var existing_tween = notification_panel.get_meta("ux_notification_tween")
		if existing_tween is Tween:
			existing_tween.kill()

	var fade_in := create_tween()
	fade_in.tween_property(notification_panel, "modulate:a", 1.0, 0.16)
	notification_panel.set_meta("ux_notification_tween", fade_in)

	if duration <= 0.0:
		return
	await get_tree().create_timer(duration, true).timeout
	if is_instance_valid(notification_panel) and notification_panel.get_meta("msg_id", -1) == current_id:
		var fade_out := create_tween()
		fade_out.tween_property(notification_panel, "modulate:a", 0.0, 0.16)
		fade_out.tween_callback(func():
			if is_instance_valid(notification_panel) and notification_panel.get_meta("msg_id", -1) == current_id:
				notification_panel.visible = false
		)
		notification_panel.set_meta("ux_notification_tween", fade_out)


func hide_notification() -> void:
	if is_instance_valid(notification_panel):
		notification_panel.visible = false


func _on_clue_collected(_zone_id: String, _clue_data: Dictionary) -> void:
	pass


func _on_back_pressed() -> void:
	if not _dialogue_input_locked:
		_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	MusicController.resume_music()
	GameState.change_to_post_zone_scene(get_tree())


func _refresh_inside_zone_buttons() -> void:
	var is_sidekick: bool = GameState.local_role == GameState.Role.SIDEKICK
	if is_instance_valid(touch_controls):
		if touch_controls.has_method("set_pause_enabled"): touch_controls.set_pause_enabled(true)
		if touch_controls.has_method("set_ledger_enabled"): touch_controls.set_ledger_enabled(is_sidekick)
		if touch_controls.has_method("set_briefcase_enabled"):  touch_controls.set_briefcase_enabled(is_sidekick)
		if touch_controls.has_method("set_sidekick_ui_visible"):touch_controls.set_sidekick_ui_visible(is_sidekick)
	if not is_sidekick:
		if is_instance_valid(ledger_panel): ledger_panel.visible = false
		if is_instance_valid(briefcase_panel): briefcase_panel.visible = false
		if is_instance_valid(ledger_touch_button): ledger_touch_button.visible = false
		if is_instance_valid(briefcase_touch_button): briefcase_touch_button.visible = false


func _show_reward_stage_text(text: String) -> void:
	if is_instance_valid(reward_panel): reward_panel.visible = true
	if is_instance_valid(reward_text_label): reward_text_label.text = text
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = true
		tap_instruction_label.text = "Tap anywhere to continue."


func _on_reward_tap_catcher_pressed() -> void:
	if _dialogue_input_locked or not _waiting_reward_continue:
		return
	match _reward_stage:
		1:
			_reward_stage = 2
			_show_reward_stage_text("Pina has become the pineapple in the backyard.")
		2:
			_reward_stage = 3
			_show_reward_stage_text("Pina cannot find the things she is looking for.")
		3:
			_reward_stage = 4
			_show_reward_stage_text("But if she had a thousand eyes like a pineapple,")
		4:
			_reward_stage = 5
			_show_reward_stage_text("perhaps she could see them again.")
		5:
			_reward_stage = 6
			_waiting_reward_continue = false
			if is_instance_valid(tap_instruction_label):
				tap_instruction_label.visible = false
				tap_instruction_label.text = ""
			if is_instance_valid(tap_catcher):
				tap_catcher.visible  = false
				tap_catcher.disabled = true
			if is_instance_valid(reward_panel): reward_panel.visible = false
			if is_instance_valid(reward_text_label): reward_text_label.text = ""
			if is_instance_valid(collect_button):
				collect_button.visible = GameState.local_role == GameState.Role.SIDEKICK if multiplayer.has_multiplayer_peer() else true
				collect_button.disabled = not collect_button.visible
				_set_attention_pulse(collect_button, collect_button.visible)


func _show_briefcase_reveal_local() -> void:
	if not is_instance_valid(briefcase_reveal_sprite):
		return
	var reveal_texture: Texture2D = GameState.get_briefcase_texture("backyard_path_reveal")
	briefcase_reveal_sprite.texture  = reveal_texture
	briefcase_reveal_sprite.visible  = reveal_texture != null
	briefcase_reveal_sprite.modulate = Color(1, 1, 1, 1)


@rpc("any_peer", "reliable", "call_local")
func rpc_show_briefcase_reveal_then_finalize() -> void:
	_hide_reward_visuals_for_briefcase()
	_show_briefcase_reveal_local()
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = false
		tap_instruction_label.text = ""
	if is_instance_valid(tap_catcher):
		tap_catcher.visible  = false
		tap_catcher.disabled = true
	await get_tree().create_timer(1.5).timeout
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		rpc_finalize_clue.rpc()


func _apply_sparkle_animation(sparkle_node: Sprite2D) -> void:
	var pulse := (sin(_animation_time * SPARKLE_PULSE_SPEED) + 1.0) / 2.0
	var target_scale: float = lerp(SPARKLE_MIN_SCALE, SPARKLE_MAX_SCALE, pulse)
	sparkle_node.scale = Vector2(target_scale, target_scale)


func _animate_fireflies() -> void:
	if not is_instance_valid(firefly_layer):
		return
	if _current_phase != BackyardPhase.FIREFLIES:
		return

	var index := 0
	for child in firefly_layer.get_children():
		if not (child is Area2D):
			continue
		if not child.visible:
			continue

		var sprite := child.get_node_or_null("FireflySprite")
		if not (sprite is Sprite2D):
			continue

		var base_scale: Vector2 = _firefly_base_scales.get(child.name, sprite.scale)
		var pulse := (sin((_animation_time * FIREFLY_PULSE_SPEED) + float(index) * 0.9) + 1.0) / 2.0
		var scale_multiplier: float = lerp(FIREFLY_MIN_SCALE_MULTIPLIER, FIREFLY_MAX_SCALE_MULTIPLIER, pulse)
		var target_alpha: float = lerp(FIREFLY_MIN_ALPHA, FIREFLY_MAX_ALPHA, pulse)
		sprite.scale = base_scale * scale_multiplier
		sprite.modulate.a = target_alpha
		index += 1


func _process(delta: float) -> void:
	_animation_time += delta
	_animate_fireflies()

	if _sparkle_animating and is_instance_valid(sparkle) and sparkle.visible:
		_apply_sparkle_animation(sparkle)


func _hide_reward_visuals_for_briefcase() -> void:
	_sparkle_animating = false
	if is_instance_valid(sparkle):
		sparkle.visible = false
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
	if is_instance_valid(clue_sprite): clue_sprite.visible = false
	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = false
		reward_banner_label.text = ""
	if is_instance_valid(reward_panel): reward_panel.visible = false
	if is_instance_valid(reward_text_label): reward_text_label.text = ""
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = false
		tap_instruction_label.text = ""
	if is_instance_valid(tap_catcher):
		tap_catcher.visible  = false
		tap_catcher.disabled = true
	if is_instance_valid(collect_button): collect_button.visible = false
	_set_attention_pulse(collect_button, false)


func _hide_revealed_clue_after_touch() -> void:
	for node in [revealed_plant, revealed_pineapple, fruit_tap_button, pineapple_reveal_layer]:
		if is_instance_valid(node):
			node.visible = false
	if is_instance_valid(pineapple_reveal_area):
		_set_area_enabled(pineapple_reveal_area, false)

func _initialize_puzzle_sync() -> void:
	if not multiplayer.has_multiplayer_peer():
		_load_puzzle_data()
		_on_puzzle_data_ready()
		return

	if multiplayer.is_server():
		_broadcast_puzzle_data()
	else:
		rpc_request_puzzle_data.rpc_id(_SERVER_PEER_ID)


func _broadcast_puzzle_data(target_peer_id: int = 0) -> void:
	var puzzle: Dictionary = PuzzleManager.get_puzzle_for_zone(ZONE_ID)
	var variation_index: int = int(puzzle.get("variation_index", 0))
	var sync_encoded_name: String = str(puzzle.get("encoded_name", "S L Q D"))
	var sync_decoded_name: String = str(puzzle.get("decoded_name", "PINA"))
	var sync_shift_steps: int = int(puzzle.get("shift_steps", 3))

	# Sync the deterministic conversion numbers selected by PuzzleManager.
	var sync_plant_dali: int = int(puzzle.get("plant_height_dali", puzzle.get("memory_distance_dali", 60)))
	var sync_spirit_cm: int = int(puzzle.get("spirit_height_cm", puzzle.get("solution", sync_plant_dali * 2)))
	var sync_solution: int = int(puzzle.get("solution", sync_spirit_cm))
	var sync_dali_to_cm: int = int(puzzle.get("dali_to_cm", 2))

	GameState.force_puzzle_variation_index(ZONE_ID, variation_index)

	if target_peer_id > 0:
		rpc_sync_puzzle_data.rpc_id(target_peer_id, variation_index, sync_encoded_name, sync_decoded_name, sync_shift_steps, sync_plant_dali, sync_dali_to_cm, sync_solution, sync_spirit_cm)
	else:
		rpc_sync_puzzle_data.rpc(variation_index, sync_encoded_name, sync_decoded_name, sync_shift_steps, sync_plant_dali, sync_dali_to_cm, sync_solution, sync_spirit_cm)


@rpc("any_peer", "reliable")
func rpc_request_puzzle_data() -> void:
	if multiplayer.is_server():
		_broadcast_puzzle_data(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable", "call_local")
func rpc_sync_puzzle_data(variation_index: int, sync_encoded_name: String, sync_decoded_name: String, sync_shift_steps: int, _sync_plant_dali: int, _sync_dali_to_cm: int, _sync_solution: int, _sync_spirit_cm: int = 0) -> void:
	GameState.force_puzzle_variation_index(ZONE_ID, variation_index)

	encoded_name = sync_encoded_name
	decoded_name = sync_decoded_name.to_upper()
	shift_steps = sync_shift_steps
	_apply_fixed_distance_values()

	_on_puzzle_data_ready()


func _on_puzzle_data_ready() -> void:
	_populate_heights()

	if _puzzle_data_ready:
		return

	_puzzle_data_ready = true
	_start_intro_dialogue_delayed()

func _set_progress_tracker_stage(stage: int) -> void:
	if not is_instance_valid(progress_tracker_sprite):
		return

	match stage:
		0:
			progress_tracker_sprite.texture = PROGRESS_DEFAULT_TEX
		1:
			progress_tracker_sprite.texture = PROGRESS_PUZZLE1_TEX
		_:
			progress_tracker_sprite.texture = PROGRESS_DEFAULT_TEX


func _update_progress_tracker_for_current_state() -> void:
	if _puzzle_solved:
		_set_progress_tracker_stage(1)
	else:
		_set_progress_tracker_stage(0)

func _get_after_ghost_reveal_dialogue() -> Array[Dictionary]:
	return [
		{"speaker": "sidekick", "text": "Ahh! I am scared... I did not know there was a ghost here."},
		{"speaker": "detective", "text": "Wait. She does not look dangerous."},
		{"speaker": "sidekick", "text": "Then... who could this spirit be?"},
		{"speaker": "detective", "text": "Maybe something on her can tell us her name."}
	]


func _get_after_memory_clue_dialogue() -> Array[Dictionary]:
	return [
		{"speaker": "detective", "text": "We need to find her remains."},
		{"speaker": "sidekick", "text": "How can we measure Dali?"},
		{"speaker": "detective", "text": "Maybe the ledger has some information."}
	]


func _show_dali_conversion_ledger() -> void:
	# Keep the ledger content coming from PuzzleManager, same as the old Backyard Path behavior.
	# This prevents the new gameplay script from replacing the ledger with only the short Dali clue.
	_populate_ledger_content()

	var is_sidekick := GameState.local_role == GameState.Role.SIDEKICK

	if is_instance_valid(ledger_touch_button):
		ledger_touch_button.visible = is_sidekick

	if is_instance_valid(touch_controls) and touch_controls.has_method("set_ledger_enabled"):
		touch_controls.set_ledger_enabled(is_sidekick)

	if is_sidekick:
		pulse_ledger_guidance(false)
		if is_instance_valid(ledger_panel):
			ledger_panel.visible = true
			ledger_panel.modulate.a = 1.0
		hide_notification()
	else:
		if is_instance_valid(ledger_panel):
			ledger_panel.visible = false


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

	# Inset the video to leave a black frame — mirrors Pinas House layout
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


func _input(event: InputEvent) -> void:
	if is_instance_valid(ending_cutscene) and ending_cutscene.visible:
		var skip := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
		skip = skip or (event is InputEventScreenTouch and event.pressed)
		if skip:
			_on_cutscene_finished()
