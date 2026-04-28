extends Node2D

const ZONE_ID          := "backyard_path"
const TOTAL_TIME_SEC   := 300
const MAX_STRIKES      := 3
const _SERVER_PEER_ID  := 1
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const SCENE_MAIN_MENU  := "res://scenes/mainMenu/MainMenu.tscn"

const PROGRESS_DEFAULT_TEX: Texture2D = preload("res://assets/sprites/tracker/backyardPath/defaultBY.png")
const PROGRESS_PUZZLE1_TEX: Texture2D = preload("res://assets/sprites/tracker/backyardPath/puzzle1BY.png")

const SPARKLE_MIN_SCALE   := 0.45
const SPARKLE_MAX_SCALE   := 0.55
const SPARKLE_PULSE_SPEED := 4.0
const FIREFLY_PULSE_SPEED := 2.8
const FIREFLY_MIN_SCALE_MULTIPLIER := 0.85
const FIREFLY_MAX_SCALE_MULTIPLIER := 1.08
const FIREFLY_MIN_ALPHA := 0.45
const FIREFLY_MAX_ALPHA := 1.0
const GHOST_REVEAL_LINE := "I am here. I was never lost."
const GHOST_TYPEWRITER_DELAY := 0.045

const QUEST_PANEL_POS := Vector2(28, 235)
const QUEST_PANEL_WIDTH := 360.0
const QUEST_HEADER_HEIGHT := 40.0
const QUEST_ROW_HEIGHT := 56.0
const QUEST_ROW_GAP := 6.0
const QUEST_TEXT_LEFT_PADDING := 14.0
const QUEST_STRIKE_HEIGHT := 3.0

const DECODE_INSTRUCTION_FONT_SIZE := 16

@onready var role_label:          Label         = get_node_or_null("RoleLabel")
@onready var back_button:         Button        = $BackButton
@onready var detective_overlays:  Control       = $RoleLayer/Control/DetectiveOverlays
@onready var sidekick_overlays:   Control       = $RoleLayer/Control/SidekickOverlays
@onready var pina_spirit:         TextureRect   = $RoleLayer/Control/DetectiveOverlays/Pina
@onready var detective_height_label: Label      = $RoleLayer/Control/DetectiveOverlays/PinasHeight
@onready var pineapple_plant:     TextureRect   = $RoleLayer/Control/SidekickOverlays/PineapplePlant
@onready var pineapple_fruit:     TextureRect   = $RoleLayer/Control/SidekickOverlays/PineappleFruit
@onready var sidekick_height_label: Label       = $RoleLayer/Control/SidekickOverlays/PlantsHeight
@onready var revealed_pineapple:  Sprite2D      = $RoleLayer/Control/Pineapple
@onready var revealed_plant:      TextureRect   = $RoleLayer/Control/PineapplePlant
@onready var board_tap_button:    TextureButton = $RoleLayer/Control/BoardTapButton
@onready var fruit_tap_button:    TextureButton = $RoleLayer/Control/FruitTapButton
@onready var board_layer:         CanvasLayer   = $"Deduction Board"
@onready var board_sprite:        Sprite2D      = $"Deduction Board/Control/BoardSprite"
@onready var board_height_label:  Label         = $"Deduction Board/Control/PlantHeight"
@onready var x_input:             LineEdit      = $"Deduction Board/Control/XInput"
@onready var submit_button:       Button        = $"Deduction Board/Control/SubmitButton"
@onready var feedback_label:      Label         = $"Deduction Board/Control/FeedbackLabel"
@onready var notification_ui:     CanvasLayer   = get_node_or_null("NotificationUI")
@onready var notification_panel:  Panel         = get_node_or_null("NotificationUI/Panel")
@onready var notification_label:  Label         = get_node_or_null("NotificationUI/Panel/Label")
@onready var guidance_arrow:      CanvasItem    = get_node_or_null("RoleLayer/Control/GuidanceArrow")
@onready var touch_controls:      Node          = get_node_or_null("InsideZoneControl")
@onready var ledger_touch_button:    TouchScreenButton = get_node_or_null("InsideZoneControl/Ledger")
@onready var briefcase_touch_button: TouchScreenButton = get_node_or_null("InsideZoneControl/Briefcase")
@onready var ledger_panel:        Panel  = get_node_or_null("SidekickLayer/Ledger")
@onready var ledger_title_label:  Label  = get_node_or_null("SidekickLayer/Ledger/Control/LedgerTitle")
@onready var ledger_body_label:   Label  = get_node_or_null("SidekickLayer/Ledger/Control/LedgerBody")
@onready var fog_overlay:         ColorRect = $FogOverlay
@onready var inside_zone_control: CanvasLayer = get_node_or_null("InsideZoneControl")
@onready var pause_canvas_layer:  CanvasLayer = get_node_or_null("PauseCanvasLayer")
@onready var in_game_pause_panel: Panel       = get_node_or_null("PauseCanvasLayer/InGamePausePanel")
@onready var option_sub_panel:    Panel       = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel")
@onready var volume_slider:       HSlider     = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider")
@onready var volume_value_label:  Label       = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue")
@onready var briefcase_panel:     Panel       = get_node_or_null("SidekickLayer/Briefcase")
@onready var briefcase_display:   TextureRect = get_node_or_null("SidekickLayer/Briefcase/BriefcaseDisplay")
@onready var reward_layer:             CanvasLayer = get_node_or_null("RewardLayer")
@onready var reward_dark_overlay:      ColorRect   = get_node_or_null("RewardLayer/DarkOverlay")
@onready var reward_banner_label:      Label       = get_node_or_null("RewardLayer/BannerLabel")
@onready var reward_text_label:        Label       = get_node_or_null("RewardLayer/RewardPanel/RewardText")
@onready var clue_sprite:              Sprite2D    = get_node_or_null("RewardLayer/ClueSprite")
@onready var collect_button:           Button      = get_node_or_null("RewardLayer/CollectButton")
@onready var reward_panel:             Sprite2D    = get_node_or_null("RewardLayer/RewardPanel")
@onready var tap_instruction_label:    Label       = get_node_or_null("RewardLayer/TapInstruction")
@onready var tap_catcher:              Button      = get_node_or_null("RewardLayer/TapCatcher")
@onready var briefcase_reveal_sprite:  TextureRect = get_node_or_null("RewardLayer/BriefcaseRevealSprite")
@onready var sparkle:                  Sprite2D    = $RewardLayer/Sparkle
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

@onready var quest_layer: Node2D = get_node_or_null("QuestLayer")
@onready var focus_camera: Camera2D = get_node_or_null("FocusCamera")
@onready var grass_focus_point: Node2D = get_node_or_null("GrassFocusPoint")
@onready var pineapple_reveal_layer: Node2D = get_node_or_null("PineappleReveal")
@onready var pineapple_reveal_area: Area2D = get_node_or_null("PineappleReveal/Area2D")
@onready var pineapple_reveal_plant: Sprite2D = get_node_or_null("PineappleReveal/Area2D/PineapplePlant")
@onready var pineapple_reveal_fruit: Sprite2D = get_node_or_null("PineappleReveal/Area2D/PineappleFruit")

var _sfx_player: AudioStreamPlayer
var _zone_completion_sfx: AudioStream = preload("res://assets/audios/ZoneCompletionSFX.mp3")

var spirit_height_cm:  int
var plant_height_dali: int
var solution_cm:       int

var _waiting_reward_continue  := false
var _reward_stage             := 0
var _collect_sequence_started := false

var _intro_dialogue_played := false
var _intro_ready_peers: Dictionary = {}
var _zone_active      := false
var _board_unlocked   := false
var _board_opened     := false
var _timer_started    := false
var _puzzle_solved    := false
var _reward_active    := false
var _zone_failed      := false
var _strikes          := 0
var _ledger_hint_shown := false
var _dialogue_input_locked := false

var _timer_node: Timer
var _animation_time: float  = 0.0
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

var _current_phase: int = BackyardPhase.FIREFLIES
var _fireflies_collected := 0
var _caught_fireflies: Dictionary = {}
var _clearing_stage := 0

var encoded_name := "S L Q D"
var decoded_name := "PINA"
var shift_steps := 3
var memory_distance_dali := 60
var dali_to_cm := 2
var memory_distance_cm := 120


func _load_puzzle_data() -> void:
	var puzzle: Dictionary = PuzzleManager.get_puzzle_for_zone(ZONE_ID)
	_apply_puzzle_data(puzzle)


func _apply_puzzle_data(puzzle: Dictionary) -> void:
	# Keep name-tag values local to this scene because the old PuzzleManager
	# does not store the new name-tag puzzle data.
	encoded_name = str(puzzle.get("encoded_name", "S L Q D"))
	decoded_name = str(puzzle.get("decoded_name", "PINA")).to_upper()
	shift_steps = int(puzzle.get("shift_steps", 3))

	# IMPORTANT: Use the old deterministic Backyard Path variation values.
	# PuzzleManager already chooses one variation index for the session, so the
	# board must use plant_height_dali + spirit_height_cm + solution from there.
	plant_height_dali = int(puzzle.get("plant_height_dali", puzzle.get("memory_distance_dali", 60)))
	spirit_height_cm = int(puzzle.get("spirit_height_cm", puzzle.get("solution", plant_height_dali * 2)))
	solution_cm = int(puzzle.get("solution", spirit_height_cm))

	# New gameplay aliases. These must mirror the deterministic old values.
	memory_distance_dali = plant_height_dali
	memory_distance_cm = solution_cm
	dali_to_cm = int(puzzle.get("dali_to_cm", 2))



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
		lantern_reward_label.text = "The fireflies light the lantern."
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
	ghost_dialogue_label.modulate.a = 1.0
	ghost_dialogue_label.add_theme_font_size_override("font_size", 18)
	ghost_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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

	_initialize_puzzle_sync()


func _create_timer() -> void:
	_timer_node = Timer.new()
	_timer_node.one_shot    = true
	_timer_node.wait_time   = TOTAL_TIME_SEC
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


func _connect_signals() -> void:
	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if is_instance_valid(board_tap_button) and not board_tap_button.pressed.is_connected(_on_board_tap_pressed):
		board_tap_button.pressed.connect(_on_board_tap_pressed)
	if is_instance_valid(fruit_tap_button) and not fruit_tap_button.pressed.is_connected(_on_fruit_tap_pressed):
		fruit_tap_button.pressed.connect(_on_fruit_tap_pressed)
	if is_instance_valid(submit_button) and not submit_button.pressed.is_connected(_on_submit_pressed):
		submit_button.pressed.connect(_on_submit_pressed)
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
		x_input.placeholder_text = "Distance in cm"
		x_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	if is_instance_valid(submit_button):
		submit_button.visible = false
		submit_button.disabled = true
	if is_instance_valid(feedback_label):
		feedback_label.text = ""
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
		GameState.Role.SIDEKICK:
			detective_overlays.visible = false
			sidekick_overlays.visible  = true
		_:
			detective_overlays.visible = false
			sidekick_overlays.visible  = false
	_refresh_inside_zone_buttons()


func _populate_heights() -> void:
	if is_instance_valid(detective_height_label):
		detective_height_label.text = str(memory_distance_cm) + " cm"
	if is_instance_valid(sidekick_height_label):
		sidekick_height_label.text = str(memory_distance_dali) + " Dali"
	if is_instance_valid(board_height_label):
		board_height_label.text = str(memory_distance_dali) + " Dali"


func _populate_ledger_content() -> void:
	var ledger_view: Dictionary = PuzzleManager.get_zone_ledger_display(ZONE_ID)
	if ledger_view.is_empty():
		return
	if is_instance_valid(ledger_title_label): ledger_title_label.text = str(ledger_view.get("title", ""))
	if is_instance_valid(ledger_body_label):  ledger_body_label.text  = str(ledger_view.get("body", ""))


func _set_dialogue_input_lock(locked: bool) -> void:
	_dialogue_input_locked = locked
	var is_sidekick: bool  = GameState.local_role == GameState.Role.SIDEKICK
	var dim_color   := Color(0.65, 0.65, 0.65, 1.0)
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
		else:
			x_input.editable = _is_detective_solver() and _board_opened and _board_unlocked and not _puzzle_solved and not _zone_failed
			x_input.modulate = normal_color

	if is_instance_valid(submit_button):
		submit_button.disabled = locked or not (_is_detective_solver() and _board_opened and _board_unlocked and not _puzzle_solved and not _zone_failed)
		submit_button.modulate = dim_color if submit_button.disabled else normal_color

	if is_instance_valid(touch_controls):
		if touch_controls.has_method("set_ledger_enabled"):    touch_controls.set_ledger_enabled(is_sidekick and not locked)
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


func _run_intro_sequence() -> void:
	_set_dialogue_input_lock(true)
	DialogueSystem.play("backyard_path_intro", _get_backyard_intro_dialogue())
	await DialogueSystem.wait_finished("backyard_path_intro")
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


func _set_area_enabled(area: Area2D, enabled: bool) -> void:
	if not is_instance_valid(area):
		return
	area.monitoring = enabled
	area.input_pickable = enabled


func _setup_quest_panel_style() -> void:
	var quest_layer := get_node_or_null("QuestLayer")
	if not is_instance_valid(quest_layer):
		return

	var labels := [
		quest_fireflies_label,
		quest_lantern_label,
		quest_decode_label,
		quest_memory_label,
		quest_grass_label
	]

	_quest_labels.clear()
	_quest_strike_lines.clear()

	# Blue header bar, similar to the first reference image.
	var header_bar := quest_layer.get_node_or_null("QuestHeaderBar") as ColorRect
	if not is_instance_valid(header_bar):
		header_bar = ColorRect.new()
		header_bar.name = "QuestHeaderBar"
		quest_layer.add_child(header_bar)
		quest_layer.move_child(header_bar, 0)

	header_bar.position = QUEST_PANEL_POS
	header_bar.size = Vector2(QUEST_PANEL_WIDTH, QUEST_HEADER_HEIGHT)
	header_bar.color = Color(0.34, 0.17, 0.05, 0.95)
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_bar.z_index = 0

	if is_instance_valid(quest_title_label):
		quest_title_label.text = "BACKYARD QUEST"
		quest_title_label.position = QUEST_PANEL_POS + Vector2(10, 0)
		quest_title_label.size = Vector2(QUEST_PANEL_WIDTH - 20.0, QUEST_HEADER_HEIGHT)
		quest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		quest_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quest_title_label.add_theme_font_size_override("font_size", 18)
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
		row_bg.color = Color(0.10, 0.05, 0.02, 0.72)
		row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_bg.z_index = 0

		label.position = row_pos + Vector2(QUEST_TEXT_LEFT_PADDING, 0)
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

		_quest_labels.append(label)

		var strike_name := "QuestStrike" + str(i + 1)
		var strike := quest_layer.get_node_or_null(strike_name) as ColorRect
		if not is_instance_valid(strike):
			strike = ColorRect.new()
			strike.name = strike_name
			quest_layer.add_child(strike)

		strike.position = row_pos + Vector2(QUEST_TEXT_LEFT_PADDING, QUEST_ROW_HEIGHT * 0.52)
		strike.size = Vector2(QUEST_PANEL_WIDTH - (QUEST_TEXT_LEFT_PADDING * 2.0), QUEST_STRIKE_HEIGHT)
		strike.color = Color(1, 1, 1, 0.88)
		strike.visible = false
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strike.z_index = 4

		_quest_strike_lines.append(strike)

	_quest_style_ready = true


func _set_quest_task(index: int, text: String, done: bool) -> void:
	if index < 0 or index >= _quest_labels.size():
		return

	var label := _quest_labels[index] as Label
	if not is_instance_valid(label):
		return

	label.text = text
	# Finished tasks are only dimmed. Do not show strike-through lines because they look messy in the UI.
	label.modulate = Color(1, 1, 1, 0.45) if done else Color.WHITE

	if index < _quest_strike_lines.size():
		var strike := _quest_strike_lines[index] as ColorRect
		if is_instance_valid(strike):
			strike.visible = false


func _update_quest_labels() -> void:
	if not _quest_style_ready:
		_setup_quest_panel_style()

	var fireflies_done := _fireflies_collected >= REQUIRED_FIREFLIES
	var lantern_done := _current_phase > BackyardPhase.LANTERN
	var decode_done := _current_phase > BackyardPhase.DECODE_NAME
	var memory_done := _current_phase > BackyardPhase.DISTANCE
	var grass_done := _current_phase > BackyardPhase.GRASS

	_set_quest_task(
		0,
		"Catch fireflies: " + str(_fireflies_collected) + "/5",
		fireflies_done
	)

	_set_quest_task(
		1,
		"Use the Firefly Lantern",
		lantern_done
	)

	_set_quest_task(
		2,
		"Find and decode the name tag",
		decode_done
	)

	_set_quest_task(
		3,
		"Find Pina's memory",
		memory_done
	)

	_set_quest_task(
		4,
		"Clear the strange plant",
		grass_done
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
			lantern_reward_label.text = "The fireflies light the lantern. Use it to reveal the fog."
		else:
			lantern_reward_label.text = "The lantern is ready. Tell the Detective to use it."

	if is_instance_valid(lantern_reward_sprite):
		lantern_reward_sprite.visible = in_lantern_phase

	var show_button := _should_show_use_lantern_button()
	if is_instance_valid(use_lantern_button):
		use_lantern_button.visible = show_button
		use_lantern_button.disabled = not show_button


func _on_use_lantern_pressed() -> void:
	if _dialogue_input_locked or _zone_failed:
		return
	if _current_phase != BackyardPhase.LANTERN:
		return
	if not _is_detective_solver():
		show_notification("Only the Detective can use the Firefly Lantern here.", 2.0)
		return
	_request_reveal_ghost()


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
		firefly.visible = false
		if firefly is Area2D:
			_set_area_enabled(firefly, false)

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
	show_notification("The fireflies light the lantern. Detective, press Use Lantern.", 3.0)
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

	if is_instance_valid(fog_sprite):
		var fog_sprite_tween := create_tween()
		fog_sprite_tween.tween_property(fog_sprite, "modulate:a", 0.0, 0.8)
		fog_sprite_tween.tween_callback(func(): fog_sprite.visible = false)

	if is_instance_valid(fog_overlay):
		var light_tween := create_tween()
		light_tween.tween_property(fog_overlay, "modulate:a", 0.22, 1.0)

	if is_instance_valid(ghost_layer):
		ghost_layer.visible = true
		ghost_layer.modulate.a = 0.0
		var ghost_tween := create_tween()
		ghost_tween.tween_property(ghost_layer, "modulate:a", 0.55, 1.4)
		await ghost_tween.finished

	await _play_ghost_dialogue_typewriter(GHOST_REVEAL_LINE)

	DialogueSystem.play("backyard_after_ghost_reveal", _get_after_ghost_reveal_dialogue())
	await DialogueSystem.wait_finished("backyard_after_ghost_reveal")

	_set_dialogue_input_lock(false)

	show_notification("Look for the name tag on the ghost.", 3.5)
	_update_quest_labels()


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
		rpc_open_decode_panel.rpc()
	else:
		rpc_open_decode_panel()

func _style_decode_instruction_label(label: Label) -> void:
	if not is_instance_valid(label):
		return

	label.add_theme_font_size_override("font_size", DECODE_INSTRUCTION_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false

@rpc("any_peer", "reliable", "call_local")
func rpc_open_decode_panel() -> void:
	if is_instance_valid(decode_ui_layer):
		decode_ui_layer.visible = true

	var detective_instruction := "Rearrange the letters to form a name."
	var sidekick_instruction := "Rearrange the letters to form a name."

	if _is_detective_solver():
		if is_instance_valid(decode_panel):
			decode_panel.visible = true

		if is_instance_valid(sidekick_name_tag):
			sidekick_name_tag.visible = false

		if is_instance_valid(decode_instruction_label):
			decode_instruction_label.text = detective_instruction
			_style_decode_instruction_label(decode_instruction_label)

		if is_instance_valid(name_input):
			name_input.text = ""
			name_input.editable = true
			name_input.grab_focus()
			name_input.add_theme_font_size_override("font_size", 22)
			name_input.placeholder_text = "Type name here"

		if is_instance_valid(decode_submit_button):
			decode_submit_button.disabled = false
			decode_submit_button.add_theme_font_size_override("font_size", 18)
			decode_submit_button.text = "SUBMIT"

		show_notification("Decode the faded name and type the answer.", 3.0)

	else:
		if is_instance_valid(decode_panel):
			decode_panel.visible = false

		if is_instance_valid(sidekick_name_tag):
			sidekick_name_tag.visible = true

		if is_instance_valid(sidekick_name_tag_instruction_label):
			sidekick_name_tag_instruction_label.text = sidekick_instruction
			_style_decode_instruction_label(sidekick_name_tag_instruction_label)
			
		show_notification("Help the Detective decode the ghost's name.", 3.0)

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

	DialogueSystem.play("backyard_after_memory_clue", _get_after_memory_clue_dialogue())
	await DialogueSystem.wait_finished("backyard_after_memory_clue")

	_set_dialogue_input_lock(false)

	_show_dali_conversion_ledger()
	await get_tree().create_timer(1.0).timeout

	show_notification("Use the ledger clue to convert Dali into centimeters.", 3.5)
	_open_distance_board_local()

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

	if is_instance_valid(board_layer):
		board_layer.visible = true
	if is_instance_valid(board_tap_button):
		board_tap_button.visible = false
		board_tap_button.disabled = true
	if is_instance_valid(board_height_label):
		board_height_label.text = str(memory_distance_dali) + " Dali"

	if is_instance_valid(feedback_label):
		if _is_detective_solver():
			feedback_label.text = "Set the Firefly Lantern distance in centimeters."
		else:
			feedback_label.text = "Clue: Pina's memory is " + str(memory_distance_dali) + " Dali away. 1 Dali = " + str(dali_to_cm) + " cm."

	if is_instance_valid(x_input):
		x_input.visible = _is_detective_solver()
		x_input.editable = _is_detective_solver()
		x_input.text = ""
		x_input.placeholder_text = "Distance in cm"
		x_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		if _is_detective_solver():
			x_input.grab_focus()

	if is_instance_valid(submit_button):
		submit_button.visible = _is_detective_solver()
		submit_button.disabled = not _is_detective_solver()

	if _is_detective_solver():
		show_notification("Convert " + str(memory_distance_dali) + " Dali to centimeters.", 3.0)
	else:
		show_notification("Tell the Detective: " + str(memory_distance_dali) + " Dali × " + str(dali_to_cm) + " cm = " + str(memory_distance_cm) + " cm.", 4.0)

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
	elif _board_unlocked and not _puzzle_solved:
		show_notification("Convert Dali to centimeters in the Deduction Board to uncover the clue.", 0.0)

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
	briefcase_display.name          = "BriefcaseDisplay"
	briefcase_display.visible       = false
	briefcase_display.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	briefcase_display.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	briefcase_display.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	briefcase_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefcase_display.offset_left   = -152.0
	briefcase_display.offset_top    = 40.0
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
	if is_instance_valid(in_game_pause_panel): in_game_pause_panel.visible = true
	if is_instance_valid(option_sub_panel):    option_sub_panel.visible    = false
	if is_instance_valid(inside_zone_control): inside_zone_control.visible = false
	MusicController.pause_music()
	get_tree().paused = true


func _on_resume_play_button_pressed() -> void:
	if is_instance_valid(in_game_pause_panel): in_game_pause_panel.visible = false
	if is_instance_valid(option_sub_panel):    option_sub_panel.visible    = false
	get_tree().paused = false
	MusicController.resume_music()
	if is_instance_valid(inside_zone_control): inside_zone_control.visible = true


func _on_option_button_pressed() -> void:
	if is_instance_valid(option_sub_panel): option_sub_panel.visible = true
	_sync_volume_ui()


func _on_in_game_option_back_pressed() -> void:
	if is_instance_valid(option_sub_panel): option_sub_panel.visible = false


func _on_exit_to_main_menu_button_pressed() -> void:
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
			feedback_label.text = "Enter an answer first."
		return
	if not answer_text.is_valid_int():
		if is_instance_valid(feedback_label):
			feedback_label.text = "Numbers only."
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
			strike_message = "The Tikbalang is watching from the trees..."
		2:
			strike_message = "The Tikbalang twists the backyard path with fog..."
		_:
			strike_message = "The Tikbalang hides the backyard path."

	if multiplayer.has_multiplayer_peer():
		rpc_apply_strike.rpc(_strikes, strike_message)
	else:
		rpc_apply_strike(_strikes, strike_message)

	if _strikes >= MAX_STRIKES:
		_server_fail_zone("The Tikbalang has hidden the backyard path.\\nReturn later when the path clears.")


@rpc("any_peer", "reliable", "call_local")
func rpc_apply_strike(strike_count: int, strike_message: String) -> void:
	_strikes = strike_count
	if is_instance_valid(feedback_label):
		feedback_label.text = strike_message
	if is_instance_valid(fog_overlay):
		match strike_count:
			1:
				fog_overlay.modulate.a = 0.50
			2:
				fog_overlay.modulate.a = 0.66
			_:
				fog_overlay.modulate.a = 0.85
	show_notification(strike_message, 2.0)

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
	_zone_failed    = true
	_board_unlocked = false
	if is_instance_valid(board_tap_button):  board_tap_button.disabled  = true
	if is_instance_valid(submit_button):     submit_button.disabled     = true
	show_notification(message, 2.5)
	_set_dialogue_input_lock(true)
	DialogueSystem.play("backyard_fail", DialogueLibrary.BACKYARD_PATH_FAIL)
	await DialogueSystem.wait_finished("backyard_fail")
	_set_dialogue_input_lock(false)
	await get_tree().create_timer(2.5).timeout
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
	tween.set_parallel(true)
	tween.tween_property(focus_camera, "global_position", target_pos, 0.9)
	tween.tween_property(focus_camera, "zoom", target_zoom, 0.9)


func _hide_ghost_before_grass_focus() -> void:
	_ghost_dialogue_typing = false

	if is_instance_valid(ghost_dialogue_label):
		ghost_dialogue_label.visible = false
		ghost_dialogue_label.text = ""

	if is_instance_valid(ghost_name_tag):
		_set_area_enabled(ghost_name_tag, false)

	if not is_instance_valid(ghost_layer) or not ghost_layer.visible:
		return

	var ghost_tween := create_tween()
	ghost_tween.tween_property(ghost_layer, "modulate:a", 0.0, 0.35)
	await ghost_tween.finished

	if is_instance_valid(ghost_layer):
		ghost_layer.visible = false

@rpc("any_peer", "reliable", "call_local")
func rpc_distance_answered() -> void:
	_current_phase = BackyardPhase.GRASS
	_board_unlocked = false
	_board_opened = false

	if is_instance_valid(board_layer):
		board_layer.visible = false

	if is_instance_valid(x_input):
		x_input.visible = false
		x_input.editable = false

	if is_instance_valid(submit_button):
		submit_button.visible = false
		submit_button.disabled = true

	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false

	# Hide Pina's spirit first so the camera focuses only on the grass patch.
	await _hide_ghost_before_grass_focus()

	if is_instance_valid(grass_layer):
		grass_layer.visible = true
		for child in grass_layer.get_children():
			if child is Area2D:
				child.visible = true
				_set_area_enabled(child, true)

	_zoom_camera_to_grass()

	show_notification("The lantern light stops on the grass. Clear what is covering it.", 4.0)
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
		_server_add_strike("The Tikbalang confuses your hands in the grass...")
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
		grass.visible = false
		if grass is Area2D:
			_set_area_enabled(grass, false)

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
		fruit_tap_button.scale           = Vector2(1.4, 1.4)


func _blink_board() -> void:
	if not is_instance_valid(board_sprite):
		return
	var tw := create_tween()
	tw.tween_property(board_sprite, "modulate", Color(1, 1, 1, 0.3), 0.12)
	tw.tween_property(board_sprite, "modulate", Color(1, 1, 1, 1),   0.12)
	tw.tween_property(board_sprite, "modulate", Color(1, 1, 1, 0.3), 0.12)
	tw.tween_property(board_sprite, "modulate", Color(1, 1, 1, 1),   0.12)
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
	_reward_active             = true
	_waiting_reward_continue   = true
	_reward_stage              = 1
	_collect_sequence_started  = false

	_play_zone_completion_sfx()
	_hide_revealed_clue_after_touch()

	if is_instance_valid(fruit_tap_button):
		fruit_tap_button.disabled = true
		fruit_tap_button.visible  = false
	if is_instance_valid(reward_layer):      reward_layer.visible      = true
	if is_instance_valid(clue_sprite):       clue_sprite.visible       = true
	if is_instance_valid(sparkle):
		sparkle.visible    = true
		sparkle.scale      = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
		_animation_time    = 0.0
		_sparkle_animating = true
	if is_instance_valid(reward_dark_overlay): reward_dark_overlay.modulate.a = 0.45
	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = true
		reward_banner_label.text    = "CLUE FOUND!"
	if is_instance_valid(reward_text_label):   reward_text_label.text   = ""
	if is_instance_valid(reward_panel):        reward_panel.visible      = false
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = true
		tap_instruction_label.text    = "Tap anywhere to continue."
	if is_instance_valid(tap_catcher):
		tap_catcher.visible  = true
		tap_catcher.disabled = false
	if is_instance_valid(collect_button):     collect_button.visible    = false
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null


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
		sparkle.scale   = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
	if is_instance_valid(clue_sprite):            clue_sprite.visible            = false
	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = false
		reward_banner_label.text    = ""
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null
	if is_instance_valid(reward_layer):           reward_layer.visible           = false
	_return_to_forest()


func show_notification(text: String, duration: float = 2.0) -> void:
	if not is_instance_valid(notification_panel) or not is_instance_valid(notification_label):
		return
	notification_label.text    = text
	notification_panel.visible = true
	var current_id := Time.get_ticks_msec()
	notification_panel.set_meta("msg_id", current_id)
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration, true).timeout
	if is_instance_valid(notification_panel) and notification_panel.get_meta("msg_id", -1) == current_id:
		notification_panel.visible = false


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
	get_tree().change_scene_to_file(SCENE_FOREST_HUB)


func _refresh_inside_zone_buttons() -> void:
	var is_sidekick: bool = GameState.local_role == GameState.Role.SIDEKICK
	if is_instance_valid(touch_controls):
		if touch_controls.has_method("set_pause_enabled"):      touch_controls.set_pause_enabled(true)
		if touch_controls.has_method("set_ledger_enabled"):     touch_controls.set_ledger_enabled(is_sidekick)
		if touch_controls.has_method("set_briefcase_enabled"):  touch_controls.set_briefcase_enabled(is_sidekick)
		if touch_controls.has_method("set_sidekick_ui_visible"):touch_controls.set_sidekick_ui_visible(is_sidekick)
	if not is_sidekick:
		if is_instance_valid(ledger_panel):           ledger_panel.visible           = false
		if is_instance_valid(briefcase_panel):        briefcase_panel.visible        = false
		if is_instance_valid(ledger_touch_button):    ledger_touch_button.visible    = false
		if is_instance_valid(briefcase_touch_button): briefcase_touch_button.visible = false


func _show_reward_stage_text(text: String) -> void:
	if is_instance_valid(reward_panel):          reward_panel.visible           = true
	if is_instance_valid(reward_text_label):     reward_text_label.text         = text
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = true
		tap_instruction_label.text    = "Tap anywhere to continue."


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
			_reward_stage            = 6
			_waiting_reward_continue = false
			if is_instance_valid(tap_instruction_label):
				tap_instruction_label.visible = false
				tap_instruction_label.text    = ""
			if is_instance_valid(tap_catcher):
				tap_catcher.visible  = false
				tap_catcher.disabled = true
			if is_instance_valid(reward_panel):      reward_panel.visible      = false
			if is_instance_valid(reward_text_label): reward_text_label.text    = ""
			if is_instance_valid(collect_button):
				collect_button.visible = GameState.local_role == GameState.Role.SIDEKICK if multiplayer.has_multiplayer_peer() else true


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
		tap_instruction_label.text    = ""
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
		sparkle.scale   = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
	if is_instance_valid(clue_sprite):            clue_sprite.visible            = false
	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = false
		reward_banner_label.text    = ""
	if is_instance_valid(reward_panel):           reward_panel.visible           = false
	if is_instance_valid(reward_text_label):      reward_text_label.text         = ""
	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = false
		tap_instruction_label.text    = ""
	if is_instance_valid(tap_catcher):
		tap_catcher.visible  = false
		tap_catcher.disabled = true
	if is_instance_valid(collect_button):         collect_button.visible         = false


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
func rpc_sync_puzzle_data(variation_index: int, sync_encoded_name: String, sync_decoded_name: String, sync_shift_steps: int, sync_plant_dali: int, sync_dali_to_cm: int, sync_solution: int, sync_spirit_cm: int = 0) -> void:
	GameState.force_puzzle_variation_index(ZONE_ID, variation_index)

	encoded_name = sync_encoded_name
	decoded_name = sync_decoded_name.to_upper()
	shift_steps = sync_shift_steps
	dali_to_cm = sync_dali_to_cm

	# Apply the same deterministic values from the server-side PuzzleManager.
	plant_height_dali = sync_plant_dali
	spirit_height_cm = sync_spirit_cm if sync_spirit_cm > 0 else sync_solution
	solution_cm = sync_solution

	# New gameplay aliases.
	memory_distance_dali = plant_height_dali
	memory_distance_cm = solution_cm

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
		# Old behavior: do not force the ledger open here.
		# The Sidekick opens/closes it by pressing the ledger button.
		pulse_ledger_guidance(true)
		if is_instance_valid(ledger_panel):
			ledger_panel.visible = false
		show_notification("Open the ledger to see the Dali conversion clue.", 3.0)
	else:
		if is_instance_valid(ledger_panel):
			ledger_panel.visible = false
