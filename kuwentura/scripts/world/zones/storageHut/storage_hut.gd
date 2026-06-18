##storage_hut.gd
extends Node2D

## Storage Hut – Zone 4
## Puzzle type: Volume
## Sidekick sees dimensions of 5 containers and calculates volumes.
## Detective sees a glowing spirit-water line marking the target volume.
## Together they identify the correct container.

const ZONE_ID := "storage_hut"
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const _SERVER_PEER_ID := 1
const MAX_STRIKES := 3

# ── UI colours ────────────────────────────────────────────────────────────────
const UI_CREAM   := Color(0.98, 0.95, 0.88, 1.0)
const UI_INK     := Color(0.27, 0.16, 0.08, 1.0)
const UI_BROWN   := Color(0.54, 0.35, 0.16, 1.0)
const UI_HOVER   := Color(0.66, 0.44, 0.20, 1.0)
const UI_PRESS   := Color(0.43, 0.26, 0.10, 1.0)
const UI_BORDER  := Color(0.96, 0.83, 0.58, 1.0)
const UI_PANEL   := Color(0.19, 0.11, 0.05, 0.92)
const UI_SUCCESS := Color(0.53, 0.86, 0.47, 1.0)
const UI_ERROR   := Color(0.91, 0.42, 0.34, 1.0)
const UI_INFO    := Color(0.99, 0.91, 0.63, 1.0)
const UI_DISABLED:= Color(0.46, 0.39, 0.33, 0.92)

const SPARKLE_MIN   := 0.45
const SPARKLE_MAX   := 0.55
const SPARKLE_SPEED := 4.0

# ── Node references ───────────────────────────────────────────────────────────
@onready var role_label: Label              = get_node_or_null("RoleLabel")
@onready var back_button: Button            = get_node_or_null("BackButton")
@onready var notification_panel: Panel      = get_node_or_null("NotificationUI/Panel")
@onready var notification_label: Label      = get_node_or_null("NotificationUI/Panel/Label")
@onready var inside_zone_control: CanvasLayer = get_node_or_null("InsideZoneControl")
@onready var pause_canvas: CanvasLayer      = get_node_or_null("PauseCanvasLayer")
@onready var pause_panel: Panel             = get_node_or_null("PauseCanvasLayer/InGamePausePanel")
@onready var option_panel: Panel            = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel")
@onready var volume_slider: HSlider         = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider")
@onready var volume_label: Label            = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue")
@onready var ledger_panel: Panel            = get_node_or_null("SidekickLayer/Ledger")
@onready var ledger_title: Label            = get_node_or_null("SidekickLayer/Ledger/Control/LedgerTitle")
@onready var ledger_body: Label             = get_node_or_null("SidekickLayer/Ledger/Control/LedgerBody")
@onready var briefcase_panel: Panel         = get_node_or_null("SidekickLayer/Briefcase")
@onready var briefcase_display: TextureRect = get_node_or_null("SidekickLayer/Briefcase/BriefcaseDisplay")

# Detective – spirit water display
@onready var detective_layer: CanvasLayer   = get_node_or_null("DetectiveLayer")
@onready var spirit_volume_label: Label     = get_node_or_null("DetectiveLayer/SpiritVolumeLabel")
@onready var spirit_glow_rect: ColorRect    = get_node_or_null("DetectiveLayer/SpiritGlowRect")

# Sidekick – container selection UI (created procedurally)
@onready var sidekick_puzzle_layer: CanvasLayer = get_node_or_null("SidekickPuzzleLayer")

# Quest
@onready var quest_layer: Node2D            = get_node_or_null("QuestLayer")
@onready var quest_title_label: Label       = get_node_or_null("QuestLayer/QuestTitle")

# Reward layer
@onready var reward_layer: CanvasLayer      = get_node_or_null("RewardLayer")
@onready var reward_dark: ColorRect         = get_node_or_null("RewardLayer/DarkOverlay")
@onready var reward_banner: Label           = get_node_or_null("RewardLayer/BannerLabel")
@onready var reward_text: Label             = get_node_or_null("RewardLayer/RewardPanel/RewardText")
@onready var reward_panel_node: Sprite2D    = get_node_or_null("RewardLayer/RewardPanel")
@onready var clue_sprite: Sprite2D          = get_node_or_null("RewardLayer/ClueSprite")
@onready var sparkle: Sprite2D              = get_node_or_null("RewardLayer/Sparkle")
@onready var tap_instruction: Label         = get_node_or_null("RewardLayer/TapInstruction")
@onready var tap_catcher: Button            = get_node_or_null("RewardLayer/TapCatcher")
@onready var collect_button: Button         = get_node_or_null("RewardLayer/CollectButton")
@onready var briefcase_reveal: TextureRect  = get_node_or_null("RewardLayer/BriefcaseRevealSprite")

@onready var ending_cutscene: VideoStreamPlayer = get_node_or_null("Cutscene/EndingCutscene")

var _ending_cutscene_resolved := false

@onready var progress_sprite: Sprite2D      = get_node_or_null("ProgressTracker/Sprite2D")
@export var progress_default_tex: Texture2D
@export var progress_solved_tex: Texture2D

# ── Puzzle state ──────────────────────────────────────────────────────────────
var _puzzle_data: Dictionary = {}
var _puzzle_data_ready := false
var _puzzle_variation: Dictionary = {}
var _containers: Array = []         # Array of Dictionaries from PuzzleManager
var _target_volume: float = 0.0
var _correct_container_id: int = -1

# Game flow
var _zone_active := false
var _zone_failed := false
var _clue_collected := false
var _puzzle_solved := false
var _strikes := 0
var _dialogue_locked := false
var _intro_played := false
var _intro_ready_peers: Dictionary = {}

# Reward
var _reward_active := false
var _waiting_tap := false
var _reward_stage := 0
var _collect_started := false
var _anim_time := 0.0
var _sparkle_on := false

# Procedural container buttons (Sidekick view)
var _container_buttons: Array = []

# Quest
var _quest_labels: Array = []
var _quest_bgs: Array = []
var _quest_style_ready := false
var _quest_expanded := false
var _quest_active_index := 0
var _quest_toggle: Button

const QUEST_POS   := Vector2(28, 210)
const QUEST_W     := 390.0
const QUEST_H_HDR := 38.0
const QUEST_H_ROW := 40.0
const QUEST_GAP   := 6.0
const QUEST_PAD   := 14.0

# Audio
var _sfx_player: AudioStreamPlayer
const _COMPLETION_SFX: AudioStream = preload("res://assets/audios/ZoneCompletionSFX.mp3")

# Sigbin consequence
var _sigbin_shadow_overlay: ColorRect

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_ensure_sfx_bus()
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

	_setup_ui()
	_populate_ledger()
	_setup_quest_panel()
	_update_quest()
	_connect_signals()

	if is_instance_valid(reward_layer):
		reward_layer.visible = false
	if is_instance_valid(ending_cutscene):
		CutsceneHelper.prepare_mobile_video_player(ending_cutscene)
		ending_cutscene.visible = false

	MusicController.play_track(MusicController.MusicTrack.BACKYARD_PATH)

	if not GameState.clue_collected.is_connected(_on_clue_signal):
		GameState.clue_collected.connect(_on_clue_signal)
	if not GameState.briefcase_updated.is_connected(_refresh_briefcase):
		GameState.briefcase_updated.connect(_refresh_briefcase)

	_initialize_puzzle_sync()


func _process(delta: float) -> void:
	if _sparkle_on and is_instance_valid(sparkle) and sparkle.visible:
		_anim_time += delta
		var pulse := (sin(_anim_time * SPARKLE_SPEED) + 1.0) / 2.0
		var s := lerpf(SPARKLE_MIN, SPARKLE_MAX, pulse)
		sparkle.scale = Vector2(s, s)

	# Sigbin shadow deepens as strikes accumulate
	if _zone_active and not _puzzle_solved and is_instance_valid(_sigbin_shadow_overlay):
		var target_alpha := _strikes * 0.18
		_sigbin_shadow_overlay.color.a = lerpf(_sigbin_shadow_overlay.color.a, target_alpha, delta * 1.5)


# ── Setup ─────────────────────────────────────────────────────────────────────
func _setup_ui() -> void:
	if is_instance_valid(role_label):
		role_label.text = "Role: " + GameState.get_role_display_text()
	if is_instance_valid(ledger_panel):
		ledger_panel.visible = false
	if is_instance_valid(briefcase_panel):
		briefcase_panel.visible = false
	if is_instance_valid(notification_panel):
		notification_panel.visible = false
	if is_instance_valid(detective_layer):
		detective_layer.visible = GameState.local_role == GameState.Role.DETECTIVE
	if is_instance_valid(sidekick_puzzle_layer):
		sidekick_puzzle_layer.visible = false

	# Sigbin ambient shadow – starts invisible, deepens with wrong answers
	_sigbin_shadow_overlay = ColorRect.new()
	_sigbin_shadow_overlay.name = "SigbinShadow"
	_sigbin_shadow_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_sigbin_shadow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sigbin_shadow_overlay.z_index = 50
	_sigbin_shadow_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sigbin_shadow_overlay)

	_refresh_briefcase()


func _populate_ledger() -> void:
	var data := PuzzleManager.get_zone_ledger_display(ZONE_ID)
	if data.is_empty():
		return
	if is_instance_valid(ledger_title):
		ledger_title.text = str(data.get("title", "Volume Formulas"))
	if is_instance_valid(ledger_body):
		var body := "Rectangular Box:\nV = Length × Width × Height\n\nCylinder:\nV = 3.14 × radius² × Height\n\nFind which container volume matches the spirit water level."
		ledger_body.text = body


func _connect_signals() -> void:
	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if is_instance_valid(collect_button) and not collect_button.pressed.is_connected(_on_collect_pressed):
		collect_button.pressed.connect(_on_collect_pressed)
	if is_instance_valid(tap_catcher) and not tap_catcher.pressed.is_connected(_on_tap_catcher_pressed):
		tap_catcher.pressed.connect(_on_tap_catcher_pressed)
	if is_instance_valid(inside_zone_control):
		if inside_zone_control.has_signal("ledger_pressed") and not inside_zone_control.ledger_pressed.is_connected(_on_ledger_pressed):
			inside_zone_control.ledger_pressed.connect(_on_ledger_pressed)
		if inside_zone_control.has_signal("briefcase_pressed") and not inside_zone_control.briefcase_pressed.is_connected(_on_briefcase_pressed):
			inside_zone_control.briefcase_pressed.connect(_on_briefcase_pressed)
		if inside_zone_control.has_signal("pause_pressed") and not inside_zone_control.pause_pressed.is_connected(_on_pause_pressed):
			inside_zone_control.pause_pressed.connect(_on_pause_pressed)
	_connect_pause_signals()


func _connect_pause_signals() -> void:
	var resume := get_node_or_null("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton") as BaseButton
	if is_instance_valid(resume) and not resume.pressed.is_connected(_on_resume_pressed):
		resume.pressed.connect(_on_resume_pressed)
	var opt := get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionButton") as BaseButton
	if is_instance_valid(opt) and not opt.pressed.is_connected(_on_option_pressed):
		opt.pressed.connect(_on_option_pressed)
	var ext := get_node_or_null("PauseCanvasLayer/InGamePausePanel/ExitButton") as BaseButton
	if is_instance_valid(ext) and not ext.pressed.is_connected(_on_exit_pressed):
		ext.pressed.connect(_on_exit_pressed)
	if is_instance_valid(volume_slider) and not volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.connect(_on_volume_changed)


# ── Puzzle sync ───────────────────────────────────────────────────────────────
func _initialize_puzzle_sync() -> void:
	if not multiplayer.has_multiplayer_peer():
		_load_local_puzzle()
		_on_puzzle_ready()
		return
	if multiplayer.is_server():
		_broadcast_puzzle()
	else:
		rpc_request_puzzle_data.rpc_id(_SERVER_PEER_ID)


func _load_local_puzzle() -> void:
	_puzzle_data = PuzzleManager.get_puzzle_for_zone(ZONE_ID)
	var variation := _puzzle_data.get("selected_variation", {}) as Dictionary
	_apply_variation(variation)


func _broadcast_puzzle(target: int = 0) -> void:
	_puzzle_data = PuzzleManager.get_puzzle_for_zone(ZONE_ID)
	var vi := int(_puzzle_data.get("variation_index", 0))
	GameState.force_puzzle_variation_index(ZONE_ID, vi)
	var variation := _puzzle_data.get("selected_variation", {}) as Dictionary
	if target > 0:
		rpc_sync_puzzle.rpc_id(target, vi, variation)
	else:
		rpc_sync_puzzle.rpc(vi, variation)


@rpc("any_peer", "reliable")
func rpc_request_puzzle_data() -> void:
	if multiplayer.is_server():
		_broadcast_puzzle(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable", "call_local")
func rpc_sync_puzzle(vi: int, variation: Dictionary) -> void:
	GameState.force_puzzle_variation_index(ZONE_ID, vi)
	_puzzle_data = PuzzleManager.get_puzzle_for_zone(ZONE_ID)
	_apply_variation(variation)
	_on_puzzle_ready()


func _apply_variation(variation: Dictionary) -> void:
	_puzzle_variation = variation
	_target_volume = float(variation.get("target_volume", variation.get("solution", 240)))
	_correct_container_id = int(variation.get("correct_container", 1))
	var containers_raw: Array = variation.get("containers", [])
	_containers = []
	for c in containers_raw:
		_containers.append(c as Dictionary)


func _on_puzzle_ready() -> void:
	if _puzzle_data_ready:
		return
	_puzzle_data_ready = true
	_refresh_detective_view()
	_build_sidekick_container_ui()
	_start_intro()


# ── Detective view ─────────────────────────────────────────────────────────────
func _refresh_detective_view() -> void:
	if GameState.local_role != GameState.Role.DETECTIVE:
		return
	if is_instance_valid(spirit_volume_label):
		spirit_volume_label.text = "Spirit Water Level: %.0f cubic units" % _target_volume
		spirit_volume_label.visible = _zone_active
	if is_instance_valid(spirit_glow_rect):
		spirit_glow_rect.visible = _zone_active
		# Animated glow to indicate spirit water
		var tween := create_tween().set_loops()
		tween.set_parallel(true)
		tween.tween_property(spirit_glow_rect, "modulate:a", 0.35, 1.0)
		tween.tween_property(spirit_glow_rect, "modulate:a", 1.0, 1.0)


# ── Sidekick container UI (procedural) ────────────────────────────────────────
func _build_sidekick_container_ui() -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		return
	if not is_instance_valid(sidekick_puzzle_layer):
		# Create it dynamically if not in scene
		sidekick_puzzle_layer = CanvasLayer.new()
		sidekick_puzzle_layer.name = "SidekickPuzzleLayer"
		sidekick_puzzle_layer.layer = 20
		add_child(sidekick_puzzle_layer)

	# Clear old buttons
	for btn in _container_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_container_buttons.clear()

	sidekick_puzzle_layer.visible = false  # shown after zone begins

	var viewport_size := get_viewport_rect().size
	var panel := Panel.new()
	panel.name = "ContainerPanel"
	panel.size = Vector2(viewport_size.x * 0.9, viewport_size.y * 0.75)
	panel.position = Vector2((viewport_size.x - panel.size.x) * 0.5, viewport_size.y * 0.12)
	panel.z_index = 10

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.04, 0.96)
	style.border_color = UI_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	sidekick_puzzle_layer.add_child(panel)

	var title_lbl := Label.new()
	title_lbl.text = "Containers in the Hut – Which matches the spirit water level?"
	title_lbl.position = Vector2(20, 14)
	title_lbl.size = Vector2(panel.size.x - 40, 36)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", UI_CREAM)
	title_lbl.add_theme_constant_override("outline_size", 2)
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	panel.add_child(title_lbl)

	var instruction_lbl := Label.new()
	instruction_lbl.text = "Calculate each volume. Tell the Detective. Press the button for the one that matches."
	instruction_lbl.position = Vector2(20, 52)
	instruction_lbl.size = Vector2(panel.size.x - 40, 28)
	instruction_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_lbl.add_theme_font_size_override("font_size", 14)
	instruction_lbl.add_theme_color_override("font_color", UI_INFO)
	instruction_lbl.add_theme_constant_override("outline_size", 1)
	instruction_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	instruction_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(instruction_lbl)

	var btn_h := 68.0
	var btn_gap := 10.0
	var btn_y_start := 90.0
	var btn_w := panel.size.x - 40

	for i in range(_containers.size()):
		var c: Dictionary = _containers[i]
		var btn := Button.new()
		btn.name = "ContainerBtn%d" % i
		btn.position = Vector2(20, btn_y_start + i * (btn_h + btn_gap))
		btn.size = Vector2(btn_w, btn_h)
		btn.focus_mode = Control.FOCUS_NONE

		var dim_text := _format_container_dims(c)
		btn.text = "%s\n%s" % [str(c.get("name", "Container %d" % (i+1))), dim_text]

		# Style
		var s_normal := StyleBoxFlat.new()
		s_normal.bg_color = Color(0.28, 0.18, 0.08, 0.88)
		s_normal.border_color = UI_BORDER
		s_normal.set_border_width_all(2)
		s_normal.set_corner_radius_all(10)
		var s_hover := StyleBoxFlat.new()
		s_hover.bg_color = UI_HOVER
		s_hover.border_color = UI_BORDER
		s_hover.set_border_width_all(2)
		s_hover.set_corner_radius_all(10)
		var s_pressed := StyleBoxFlat.new()
		s_pressed.bg_color = UI_PRESS
		s_pressed.border_color = UI_SUCCESS
		s_pressed.set_border_width_all(3)
		s_pressed.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", s_normal)
		btn.add_theme_stylebox_override("hover", s_hover)
		btn.add_theme_stylebox_override("pressed", s_pressed)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", UI_CREAM)
		btn.add_theme_constant_override("outline_size", 2)
		btn.add_theme_color_override("font_outline_color", Color(0,0,0,0.9))

		var captured_id := int(c.get("id", i + 1))
		btn.pressed.connect(func(): _on_container_selected(captured_id))
		panel.add_child(btn)
		_container_buttons.append(btn)


func _format_container_dims(c: Dictionary) -> String:
	var ctype := str(c.get("type", "rectangular"))
	if ctype == "cylinder":
		return "Cylinder  |  radius = %s  |  height = %s" % [str(c.get("r","?")), str(c.get("h","?"))]
	return "Box  |  L=%s  W=%s  H=%s" % [str(c.get("l","?")), str(c.get("w","?")), str(c.get("h","?"))]


func _show_sidekick_containers() -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		return
	if is_instance_valid(sidekick_puzzle_layer):
		sidekick_puzzle_layer.visible = true


func _hide_sidekick_containers() -> void:
	if is_instance_valid(sidekick_puzzle_layer):
		sidekick_puzzle_layer.visible = false


# ── Intro dialogue ────────────────────────────────────────────────────────────
func _start_intro() -> void:
	if _intro_played:
		return
	_intro_played = true
	_run_intro()


func _run_intro() -> void:
	_set_lock(true)
	var lines: Array[Dictionary] = [
		{"speaker": "detective", "text": "This storage hut holds many containers."},
		{"speaker": "sidekick", "text": "I can see their sizes. Some are boxes, some are cylinders."},
		{"speaker": "detective", "text": "I see a glow on one of them — a spirit water line."},
		{"speaker": "sidekick", "text": "Tell me the volume it marks and I will calculate which one matches."}
	]
	DialogueSystem.play("storage_hut_intro", lines)
	await DialogueSystem.wait_finished("storage_hut_intro")
	_set_lock(false)
	_report_intro_ready()


func _report_intro_ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		rpc_begin_zone()
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
	if _intro_ready_peers.size() >= multiplayer.get_peers().size() + 1:
		rpc_begin_zone.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_begin_zone() -> void:
	_zone_active = true
	if is_instance_valid(detective_layer):
		detective_layer.visible = GameState.local_role == GameState.Role.DETECTIVE
	_refresh_detective_view()
	_show_sidekick_containers()
	_update_quest()

	var spirit_text := "Detective: the spirit water marks %.0f cubic units.\nSidekick: calculate each container's volume to find the match." % _target_volume
	show_notification(spirit_text, 5.0)


# ── Container answer validation ────────────────────────────────────────────────
func _on_container_selected(container_id: int) -> void:
	if not _zone_active or _dialogue_locked or _puzzle_solved or _zone_failed or _clue_collected:
		return
	if GameState.local_role != GameState.Role.SIDEKICK and multiplayer.has_multiplayer_peer():
		show_notification("Only the Sidekick selects the container.", 1.8)
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_server_validate_container(container_id)
	else:
		rpc_request_validate.rpc_id(_SERVER_PEER_ID, container_id)


@rpc("any_peer", "reliable")
func rpc_request_validate(container_id: int) -> void:
	if multiplayer.is_server():
		_server_validate_container(container_id)


func _server_validate_container(container_id: int) -> void:
	if _puzzle_solved or _zone_failed:
		return
	if container_id == _correct_container_id:
		if multiplayer.has_multiplayer_peer():
			rpc_puzzle_solved.rpc(container_id)
		else:
			rpc_puzzle_solved(container_id)
	else:
		_server_add_strike("That container's volume does not match the spirit water level.")


func _server_add_strike(message: String) -> void:
	if _zone_failed:
		return
	_strikes += 1
	if _strikes >= MAX_STRIKES:
		_server_fail_zone()
		return
	if multiplayer.has_multiplayer_peer():
		rpc_apply_strike.rpc(_strikes, message)
	else:
		rpc_apply_strike(_strikes, message)


@rpc("any_peer", "reliable", "call_local")
func rpc_apply_strike(count: int, message: String) -> void:
	_strikes = count
	show_notification("✗ " + message + "\n(" + str(MAX_STRIKES - count) + " tries left)", 2.5)
	_flash_wrong_button()
	_sigbin_darken_pulse()


func _flash_wrong_button() -> void:
	# Brief red flash on the whole sidekick panel
	if not is_instance_valid(sidekick_puzzle_layer):
		return
	var flash := ColorRect.new()
	flash.color = Color(0.8, 0.1, 0.1, 0.0)
	flash.z_index = 100
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sidekick_puzzle_layer.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.55, 0.12)
	tween.tween_property(flash, "color:a", 0.0, 0.35)
	tween.tween_callback(flash.queue_free)


func _sigbin_darken_pulse() -> void:
	# Sigbin's shadow deepens momentarily on mistakes
	if not is_instance_valid(_sigbin_shadow_overlay):
		return
	var tween := create_tween()
	tween.tween_property(_sigbin_shadow_overlay, "color:a", minf(0.7, _strikes * 0.25), 0.4)
	tween.tween_property(_sigbin_shadow_overlay, "color:a", _strikes * 0.18, 0.6)


func _server_fail_zone() -> void:
	_zone_failed = true
	GameState.lock_zone_temp(ZONE_ID, 30)
	if multiplayer.has_multiplayer_peer():
		rpc_fail_zone.rpc()
	else:
		rpc_fail_zone()


@rpc("any_peer", "reliable", "call_local")
func rpc_fail_zone() -> void:
	_zone_failed = true
	_zone_active = false
	_hide_sidekick_containers()
	# Sigbin plunges hut into darkness
	_play_sigbin_final_darkness()
	await get_tree().create_timer(5.0).timeout
	_return_to_forest()


func _play_sigbin_final_darkness() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.z_index = 500
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Red glowing eyes appear in the darkness
	var eyes_label := Label.new()
	eyes_label.text = "👁  👁"
	eyes_label.z_index = 501
	eyes_label.add_theme_font_size_override("font_size", 72)
	eyes_label.add_theme_color_override("font_color", Color(0.9, 0.05, 0.05, 1.0))
	eyes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyes_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eyes_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eyes_label.modulate.a = 0.0
	add_child(eyes_label)

	var warning := Label.new()
	warning.text = "The Sigbin plunges the hut into darkness…"
	warning.z_index = 501
	warning.add_theme_font_size_override("font_size", 32)
	warning.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	warning.add_theme_constant_override("outline_size", 6)
	warning.add_theme_color_override("font_outline_color", Color.BLACK)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning.position.y += 120
	warning.modulate.a = 0.0
	add_child(warning)

	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 1.2)
	tween.tween_property(eyes_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(warning, "modulate:a", 1.0, 0.4)
	tween.tween_interval(3.0)


# ── Puzzle solved ──────────────────────────────────────────────────────────────
@rpc("any_peer", "reliable", "call_local")
func rpc_puzzle_solved(correct_id: int) -> void:
	_puzzle_solved = true
	_zone_active = false
	GameState.set_puzzle_solved(ZONE_ID, true)
	_update_quest()
	_set_progress_stage(1)
	_hide_sidekick_containers()

	# Highlight the correct container
	_highlight_correct_container(correct_id)
	_play_sfx()
	show_notification("Correct! The Wish Scroll is in container %d." % correct_id, 2.5)
	await get_tree().create_timer(1.2).timeout
	_show_reward()


func _highlight_correct_container(container_id: int) -> void:
	for i in range(_container_buttons.size()):
		var btn := _container_buttons[i] as Button
		if not is_instance_valid(btn):
			continue
		if i + 1 == container_id or _get_container_id_by_index(i) == container_id:
			var s_win := StyleBoxFlat.new()
			s_win.bg_color = Color(0.3, 0.7, 0.3, 0.9)
			s_win.border_color = UI_SUCCESS
			s_win.set_border_width_all(3)
			s_win.set_corner_radius_all(10)
			btn.add_theme_stylebox_override("normal", s_win)


func _get_container_id_by_index(index: int) -> int:
	if index >= 0 and index < _containers.size():
		return int(_containers[index].get("id", index + 1))
	return -1


# ── Reward sequence ────────────────────────────────────────────────────────────
func _show_reward() -> void:
	if _reward_active:
		return
	_reward_active = true
	_waiting_tap = true
	_reward_stage = 1
	_collect_started = false

	if is_instance_valid(reward_layer):
		reward_layer.visible = true
	get_tree().paused = true

	if is_instance_valid(reward_dark):
		reward_dark.modulate.a = 0.45
	if is_instance_valid(sparkle):
		sparkle.visible = true
		sparkle.scale = Vector2(SPARKLE_MIN, SPARKLE_MIN)
		_anim_time = 0.0
		_sparkle_on = true
	if is_instance_valid(clue_sprite):
		clue_sprite.visible = true
	if is_instance_valid(reward_banner):
		reward_banner.visible = true
		reward_banner.text = "ARTIFACT FOUND!"
	if is_instance_valid(reward_panel_node):
		reward_panel_node.visible = false
	if is_instance_valid(reward_text):
		reward_text.text = ""
	if is_instance_valid(tap_instruction):
		tap_instruction.visible = true
		tap_instruction.text = "Tap anywhere to continue."
	if is_instance_valid(tap_catcher):
		tap_catcher.visible = true
		tap_catcher.disabled = false
	if is_instance_valid(collect_button):
		collect_button.visible = false
	if is_instance_valid(briefcase_reveal):
		briefcase_reveal.visible = false


func _show_stage_text(text: String) -> void:
	if is_instance_valid(reward_panel_node):
		reward_panel_node.visible = true
	if is_instance_valid(reward_text):
		reward_text.text = text
	if is_instance_valid(tap_instruction):
		tap_instruction.visible = true
		tap_instruction.text = "Tap anywhere to continue."


func _on_tap_catcher_pressed() -> void:
	if not _waiting_tap:
		return
	match _reward_stage:
		1:
			_reward_stage = 2
			_show_stage_text("Inside the container was a rolled scroll, bound with old string.")
		2:
			_reward_stage = 3
			_show_stage_text("The scroll bore a mother's wish for her daughter.")
		3:
			_reward_stage = 4
			_show_stage_text("\"I wished you had many eyes, so you could find what you seek…\"")
		4:
			_reward_stage = 5
			_waiting_tap = false
			if is_instance_valid(tap_instruction):
				tap_instruction.visible = false
			if is_instance_valid(tap_catcher):
				tap_catcher.visible = false
				tap_catcher.disabled = true
			if is_instance_valid(reward_panel_node):
				reward_panel_node.visible = false
			if is_instance_valid(reward_text):
				reward_text.text = ""
			if is_instance_valid(collect_button):
				var can := GameState.local_role == GameState.Role.SIDEKICK or not multiplayer.has_multiplayer_peer()
				collect_button.visible = can
				collect_button.disabled = not can


func _on_collect_pressed() -> void:
	if _collect_started:
		return
	_collect_started = true
	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.disabled = true
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		rpc_show_briefcase_reveal.rpc()
	else:
		rpc_request_collect.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_collect() -> void:
	if multiplayer.is_server():
		rpc_show_briefcase_reveal.rpc()


@rpc("authority", "reliable", "call_local")
func rpc_show_briefcase_reveal() -> void:
	_hide_reward_for_briefcase()
	if is_instance_valid(briefcase_reveal):
		var tex: Texture2D = GameState.get_briefcase_texture("storage_hut_reveal")
		briefcase_reveal.texture = tex
		briefcase_reveal.visible = tex != null
	await get_tree().create_timer(1.5).timeout
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		rpc_finalize_clue.rpc()


@rpc("authority", "reliable", "call_local")
func rpc_finalize_clue() -> void:
	GameState.collect_clue(ZONE_ID)
	_clue_collected = true
	_sparkle_on = false
	_update_quest()
	get_tree().paused = false
	if is_instance_valid(briefcase_reveal):
		briefcase_reveal.visible = false
		briefcase_reveal.texture = null
	if is_instance_valid(reward_layer):
		reward_layer.visible = false
	await _fade_out(0.6)
	_play_ending_cutscene()
	await _fade_in(0.6)


func _hide_reward_for_briefcase() -> void:
	_sparkle_on = false
	for node in [sparkle, clue_sprite, reward_banner, reward_panel_node, tap_instruction, tap_catcher, collect_button]:
		if is_instance_valid(node):
			node.visible = false
	if is_instance_valid(reward_banner):
		reward_banner.text = ""
	if is_instance_valid(reward_text):
		reward_text.text = ""


# ── Quest panel ───────────────────────────────────────────────────────────────
func _setup_quest_panel() -> void:
	if not is_instance_valid(quest_layer):
		return

	var header := quest_layer.get_node_or_null("QuestHeaderBar") as ColorRect
	if not is_instance_valid(header):
		header = ColorRect.new()
		header.name = "QuestHeaderBar"
		quest_layer.add_child(header)
		quest_layer.move_child(header, 0)
	header.position = QUEST_POS
	header.size = Vector2(QUEST_W, QUEST_H_HDR)
	header.color = UI_BROWN
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.z_index = 0

	if is_instance_valid(quest_title_label):
		quest_title_label.text = "STORAGE HUT QUEST"
		quest_title_label.position = QUEST_POS + Vector2(12, 0)
		quest_title_label.size = Vector2(QUEST_W - 24, QUEST_H_HDR)
		quest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		quest_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quest_title_label.add_theme_font_size_override("font_size", 17)
		quest_title_label.add_theme_color_override("font_color", Color.WHITE)
		quest_title_label.add_theme_constant_override("outline_size", 2)
		quest_title_label.add_theme_color_override("font_outline_color", Color(0,0,0,0.86))
		quest_title_label.z_index = 3

	_quest_toggle = quest_layer.get_node_or_null("QuestToggleButton") as Button
	if not is_instance_valid(_quest_toggle):
		_quest_toggle = Button.new()
		_quest_toggle.name = "QuestToggleButton"
		quest_layer.add_child(_quest_toggle)
	_quest_toggle.position = QUEST_POS
	_quest_toggle.size = Vector2(QUEST_W, QUEST_H_HDR)
	_quest_toggle.flat = true
	_quest_toggle.text = ""
	_quest_toggle.focus_mode = Control.FOCUS_NONE
	_quest_toggle.self_modulate = Color(1,1,1,0)
	_quest_toggle.z_index = 10
	if not _quest_toggle.pressed.is_connected(_on_quest_toggle):
		_quest_toggle.pressed.connect(_on_quest_toggle)

	var task_names := [
		"Detective: note the spirit water volume",
		"Sidekick: calculate container volumes",
		"Find the matching container",
		"Collect the Wish Scroll"
	]
	_quest_labels.clear()
	_quest_bgs.clear()
	for i in range(task_names.size()):
		var row_pos := QUEST_POS + Vector2(0, QUEST_H_HDR + 8 + i * (QUEST_H_ROW + QUEST_GAP))
		var bg := quest_layer.get_node_or_null("QuestRowBG%d" % (i+1)) as ColorRect
		if not is_instance_valid(bg):
			bg = ColorRect.new()
			bg.name = "QuestRowBG%d" % (i+1)
			quest_layer.add_child(bg)
			quest_layer.move_child(bg, 0)
		bg.position = row_pos
		bg.size = Vector2(QUEST_W, QUEST_H_ROW)
		bg.color = Color(0.19, 0.12, 0.06, 0.64)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.z_index = 0
		_quest_bgs.append(bg)

		var lbl := quest_layer.get_node_or_null("QuestTask%d" % (i+1)) as Label
		if not is_instance_valid(lbl):
			lbl = Label.new()
			lbl.name = "QuestTask%d" % (i+1)
			quest_layer.add_child(lbl)
		lbl.text = task_names[i]
		lbl.position = row_pos + Vector2(QUEST_PAD, 0)
		lbl.size = Vector2(QUEST_W - QUEST_PAD * 2, QUEST_H_ROW)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.add_theme_color_override("font_outline_color", Color(0,0,0,0.9))
		lbl.z_index = 2
		_quest_labels.append(lbl)

	_quest_style_ready = true


func _on_quest_toggle() -> void:
	_quest_expanded = not _quest_expanded
	_update_quest()


func _update_quest() -> void:
	if not _quest_style_ready:
		_setup_quest_panel()
	if not is_instance_valid(quest_layer):
		return

	var done_states := [
		_zone_active,
		_zone_active and GameState.local_role == GameState.Role.SIDEKICK,
		_puzzle_solved,
		_clue_collected
	]
	_quest_active_index = done_states.find(false)
	if _quest_active_index == -1:
		_quest_active_index = done_states.size() - 1

	for i in range(_quest_labels.size()):
		var lbl := _quest_labels[i] as Label
		var bg  := _quest_bgs[i]  as ColorRect
		if not is_instance_valid(lbl):
			continue
		var done   := done_states[i]
		var active := i == _quest_active_index
		lbl.visible = _quest_expanded or active
		if is_instance_valid(bg):
			bg.visible = _quest_expanded or active
		if done:
			lbl.add_theme_color_override("font_color", Color(0.72,0.68,0.61,1))
			lbl.modulate = Color(1,1,1,0.45)
		else:
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.modulate = Color.WHITE

	quest_layer.visible = _zone_active and not _clue_collected and not _zone_failed


# ── Pause handlers ────────────────────────────────────────────────────────────
func _on_pause_pressed() -> void:
	if is_instance_valid(pause_panel): pause_panel.visible = true
	if is_instance_valid(option_panel): option_panel.visible = false
	if is_instance_valid(inside_zone_control): inside_zone_control.visible = false
	MusicController.pause_music()
	get_tree().paused = true


func _on_resume_pressed() -> void:
	if is_instance_valid(pause_panel): pause_panel.visible = false
	if is_instance_valid(pause_canvas): pause_canvas.visible = false
	get_tree().paused = false
	MusicController.resume_music()
	if is_instance_valid(inside_zone_control): inside_zone_control.visible = true


func _on_option_pressed() -> void:
	if is_instance_valid(option_panel): option_panel.visible = true
	if is_instance_valid(volume_slider):
		volume_slider.value = MusicController.get_volume() * 100
	if is_instance_valid(volume_label):
		volume_label.text = str(int(volume_slider.value)) + "%"


func _on_exit_pressed() -> void:
	if is_instance_valid(pause_canvas): pause_canvas.visible = false
	get_tree().paused = false
	MusicController.resume_music()
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _on_volume_changed(value: float) -> void:
	MusicController.set_volume(value / 100.0)
	if is_instance_valid(volume_label):
		volume_label.text = str(int(value)) + "%"


# ── Sidekick UI buttons ───────────────────────────────────────────────────────
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


# ── Notification ──────────────────────────────────────────────────────────────
func show_notification(text: String, duration: float = 2.0) -> void:
	if not is_instance_valid(notification_panel) or not is_instance_valid(notification_label):
		return
	notification_label.text = text
	notification_panel.visible = true
	var id := Time.get_ticks_msec()
	notification_panel.set_meta("msg_id", id)
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration, true).timeout
	if is_instance_valid(notification_panel) and notification_panel.get_meta("msg_id", -1) == id:
		notification_panel.visible = false


# ── Signals ───────────────────────────────────────────────────────────────────
func _on_clue_signal(zone_id: String, _data: Dictionary) -> void:
	if zone_id == ZONE_ID and not _clue_collected:
		_clue_collected = true
		_update_quest()


func _on_back_pressed() -> void:
	if not _dialogue_locked:
		_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	MusicController.resume_music()
	get_tree().change_scene_to_file(SCENE_FOREST_HUB)


func _set_lock(locked: bool) -> void:
	_dialogue_locked = locked
	if is_instance_valid(back_button):
		back_button.disabled = locked


# ── Progress tracker ──────────────────────────────────────────────────────────
func _set_progress_stage(stage: int) -> void:
	if not is_instance_valid(progress_sprite):
		return
	match stage:
		0: progress_sprite.texture = progress_default_tex
		1: progress_sprite.texture = progress_solved_tex if progress_solved_tex else progress_default_tex
		_: progress_sprite.texture = progress_default_tex


# ── Audio ─────────────────────────────────────────────────────────────────────
func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		var last := AudioServer.bus_count - 1
		AudioServer.set_bus_name(last, "SFX")
		AudioServer.set_bus_volume_db(last, 0.0)


func _play_sfx() -> void:
	if not is_instance_valid(_sfx_player) or not _COMPLETION_SFX:
		return
	MusicController.pause_music()
	_sfx_player.stream = _COMPLETION_SFX
	_sfx_player.play()
	if not _sfx_player.finished.is_connected(_on_sfx_done):
		_sfx_player.finished.connect(_on_sfx_done, CONNECT_ONE_SHOT)


func _on_sfx_done() -> void:
	MusicController.resume_music()


# ── Cutscene & fades ──────────────────────────────────────────────────────────
func _play_ending_cutscene() -> void:
	if not is_instance_valid(ending_cutscene):
		_return_to_forest()
		return
	var dark := get_node_or_null("Cutscene/DarkOverlay")
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
	var dark := get_node_or_null("Cutscene/DarkOverlay")
	if is_instance_valid(dark):
		dark.visible = false
	await _fade_out(0.6)
	get_tree().paused = false
	await get_tree().process_frame
	if is_inside_tree():
		get_tree().change_scene_to_file(SCENE_FOREST_HUB)


func _input(event: InputEvent) -> void:
	if is_instance_valid(ending_cutscene) and ending_cutscene.visible:
		var skip := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
		skip = skip or (event is InputEventScreenTouch and event.pressed)
		if skip:
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
