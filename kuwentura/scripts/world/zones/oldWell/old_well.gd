extends Node2D

const ZONE_ID := "old_well"
const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const SERVER_PEER_ID := 1
const MAX_LIVES := 3
const ROUNDS_TO_WIN := 3

const TEX_BG := preload("res://assets/sprites/places/oldWellZone.png")
const TEX_EYE_CLUE := preload("res://assets/sprites/clues/eyeClue_old_well.png")
const TEX_SIYOKOY_WELL := preload("res://assets/sprites/enemies/siyokoy_well.png")
const TEX_SIYOKOY_ATTACK := preload("res://assets/sprites/enemies/siyokoy_attack.png")
const FONT_DISPLAY := preload("res://assets/fonts/Arabica.ttf")
const FONT_BODY := preload("res://assets/fonts/ocraextended.ttf")

const UI_CREAM := Color(0.98, 0.93, 0.82, 1.0)
const UI_INK := Color(0.20, 0.11, 0.06, 1.0)
const UI_PANEL := Color(0.19, 0.11, 0.06, 0.93)
const UI_BROWN := Color(0.53, 0.32, 0.16, 1.0)
const UI_GOLD := Color(0.95, 0.70, 0.30, 1.0)
const UI_GREEN := Color(0.43, 0.78, 0.38, 1.0)
const UI_RED := Color(0.88, 0.26, 0.20, 1.0)

const ROMAN_POOL: Array[Dictionary] = [
	{"roman": "I", "value": 1}, {"roman": "II", "value": 2}, {"roman": "III", "value": 3}, {"roman": "IV", "value": 4}, {"roman": "V", "value": 5},
	{"roman": "VI", "value": 6}, {"roman": "VII", "value": 7}, {"roman": "VIII", "value": 8}, {"roman": "IX", "value": 9}, {"roman": "X", "value": 10},
	{"roman": "XI", "value": 11}, {"roman": "XII", "value": 12}, {"roman": "XIII", "value": 13}, {"roman": "XIV", "value": 14}, {"roman": "XV", "value": 15},
	{"roman": "XVI", "value": 16}, {"roman": "XVII", "value": 17}, {"roman": "XVIII", "value": 18}, {"roman": "XIX", "value": 19}, {"roman": "XX", "value": 20},
	{"roman": "XXI", "value": 21}, {"roman": "XXII", "value": 22}, {"roman": "XXIII", "value": 23}, {"roman": "XXIV", "value": 24}, {"roman": "XXV", "value": 25},
	{"roman": "XXVI", "value": 26}, {"roman": "XXVII", "value": 27}, {"roman": "XXVIII", "value": 28}, {"roman": "XXIX", "value": 29}, {"roman": "XXX", "value": 30},
	{"roman": "XXXI", "value": 31}, {"roman": "XXXII", "value": 32}, {"roman": "XXXIII", "value": 33}, {"roman": "XXXIV", "value": 34}, {"roman": "XXXV", "value": 35},
	{"roman": "XXXVI", "value": 36}, {"roman": "XXXVII", "value": 37}, {"roman": "XXXVIII", "value": 38}, {"roman": "XXXIX", "value": 39}, {"roman": "XL", "value": 40},
	{"roman": "XLI", "value": 41}, {"roman": "XLII", "value": 42}, {"roman": "XLIII", "value": 43}, {"roman": "XLIV", "value": 44}, {"roman": "XLV", "value": 45},
	{"roman": "XLVI", "value": 46}, {"roman": "XLVII", "value": 47}, {"roman": "XLVIII", "value": 48}, {"roman": "XLIX", "value": 49}, {"roman": "L", "value": 50}
]

@onready var background: Sprite2D = get_node_or_null("Background")
@onready var back_button: Button = get_node_or_null("BackButton")
@onready var role_label: Label = get_node_or_null("HUD/RoleLabel")
@onready var status_label: Label = get_node_or_null("HUD/StatusPanel/StatusLabel")
@onready var progress_label: Label = get_node_or_null("HUD/StatusPanel/ProgressLabel")
@onready var lives_label: Label = get_node_or_null("HUD/StatusPanel/LivesLabel")
@onready var instruction_label: Label = get_node_or_null("HUD/InstructionPanel/InstructionLabel")
@onready var siyokoy_sprite: TextureRect = get_node_or_null("GameLayer/SiyokoySprite")
@onready var sidekick_panel: Panel = get_node_or_null("GameLayer/SidekickPanel")
@onready var roman_label: Label = get_node_or_null("GameLayer/RomanFloating")
@onready var detective_panel: Control = get_node_or_null("GameLayer/DetectivePanel")
@onready var choice_buttons: Array[Button] = [
	get_node_or_null("GameLayer/DetectivePanel/Choices/Choice1") as Button,
	get_node_or_null("GameLayer/DetectivePanel/Choices/Choice2") as Button,
	get_node_or_null("GameLayer/DetectivePanel/Choices/Choice3") as Button
]
@onready var feedback_panel: Panel = get_node_or_null("GameLayer/FeedbackPanel")
@onready var feedback_label: Label = get_node_or_null("GameLayer/FeedbackPanel/FeedbackLabel")
@onready var reward_layer: CanvasLayer = get_node_or_null("RewardLayer")
@onready var reward_dark: ColorRect = get_node_or_null("RewardLayer/DarkOverlay")
@onready var reward_banner: Label = get_node_or_null("RewardLayer/BannerLabel")
@onready var clue_sprite: TextureRect = get_node_or_null("RewardLayer/ClueSprite")
@onready var reward_text: Label = get_node_or_null("RewardLayer/RewardPanel/RewardText")
@onready var tap_catcher: Button = get_node_or_null("RewardLayer/TapCatcher")
@onready var collect_button: Button = get_node_or_null("RewardLayer/CollectButton")
@onready var briefcase_reveal: TextureRect = get_node_or_null("RewardLayer/BriefcaseRevealSprite")

var _rng := RandomNumberGenerator.new()
var _round_index := 0
var _lives := MAX_LIVES
var _current_roman := ""
var _current_value := 0
var _current_choices: Array[int] = []
var _used_values: Array[int] = []
var _intro_ready_peers: Dictionary = {}
var _zone_active := false
var _dialogue_locked := false
var _reward_active := false
var _reward_stage := 0
var _waiting_reward_tap := false
var _collect_started := false
var _clue_collected := false
var _siyokoy_rest_position := Vector2.ZERO
var _attack_active := false


func _ready() -> void:
	_rng.randomize()
	_apply_scene_textures()
	_apply_fonts_and_theme()
	_connect_signals()
	_reset_visible_state()
	_update_role_text()
	call_deferred("_start_intro")


func _apply_scene_textures() -> void:
	if is_instance_valid(background):
		background.texture = TEX_BG
	if is_instance_valid(siyokoy_sprite):
		siyokoy_sprite.texture = TEX_SIYOKOY_WELL
		siyokoy_sprite.visible = false
		siyokoy_sprite.modulate = Color(1, 1, 1, 0)
		_siyokoy_rest_position = siyokoy_sprite.position
	if is_instance_valid(clue_sprite):
		clue_sprite.texture = TEX_EYE_CLUE


func _apply_fonts_and_theme() -> void:
	_apply_label_font_overrides(self)
	for label in [role_label, status_label, progress_label, lives_label, instruction_label, roman_label, feedback_label, reward_banner, reward_text]:
		if is_instance_valid(label):
			label.add_theme_font_override("font", FONT_BODY)
			label.add_theme_color_override("font_color", UI_CREAM)
			label.add_theme_constant_override("outline_size", 3)
			label.add_theme_color_override("font_outline_color", UI_INK)
	if is_instance_valid(roman_label):
		roman_label.add_theme_font_override("font", FONT_DISPLAY)
		roman_label.add_theme_font_size_override("font_size", 116)
		roman_label.add_theme_constant_override("outline_size", 8)
		roman_label.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.04, 1.0))
		roman_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.74, 1.0))
	if is_instance_valid(reward_banner):
		reward_banner.add_theme_font_override("font", FONT_DISPLAY)
		reward_banner.add_theme_font_size_override("font_size", 58)
	for panel in [sidekick_panel, detective_panel, feedback_panel, get_node_or_null("HUD/StatusPanel"), get_node_or_null("HUD/InstructionPanel"), get_node_or_null("RewardLayer/RewardPanel")]:
		if panel is Panel:
			panel.add_theme_stylebox_override("panel", _make_panel_style())
	for button in choice_buttons:
		_style_choice_button(button)
		if is_instance_valid(button):
			button.custom_minimum_size = Vector2(112, 112)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(back_button)
	_style_button(collect_button)
	if is_instance_valid(tap_catcher):
		tap_catcher.flat = true
		tap_catcher.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		tap_catcher.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		tap_catcher.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())


func _apply_label_font_overrides(node: Node) -> void:
	if node is Label:
		var label := node as Label
		label.add_theme_font_override("font", FONT_BODY)
		label.add_theme_color_override("font_color", UI_CREAM)
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", UI_INK)
	for child in node.get_children():
		_apply_label_font_overrides(child)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UI_PANEL
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = UI_GOLD
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	return style


func _style_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT_BODY)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", UI_CREAM)
	button.add_theme_stylebox_override("normal", _make_button_style(UI_BROWN))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.65, 0.42, 0.20, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.36, 0.20, 0.10, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.25, 0.19, 0.15, 0.75)))


func _make_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = UI_GOLD
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _style_choice_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT_BODY)
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", UI_CREAM)
	button.add_theme_stylebox_override("normal", _make_circle_button_style(UI_BROWN))
	button.add_theme_stylebox_override("hover", _make_circle_button_style(Color(0.65, 0.42, 0.20, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_circle_button_style(Color(0.36, 0.20, 0.10, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_circle_button_style(Color(0.25, 0.19, 0.15, 0.75)))


func _make_circle_button_style(color: Color) -> StyleBoxFlat:
	var style := _make_button_style(color)
	style.corner_radius_top_left = 56
	style.corner_radius_top_right = 56
	style.corner_radius_bottom_left = 56
	style.corner_radius_bottom_right = 56
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 8
	return style


func _connect_signals() -> void:
	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if is_instance_valid(tap_catcher) and not tap_catcher.pressed.is_connected(_on_reward_tap_pressed):
		tap_catcher.pressed.connect(_on_reward_tap_pressed)
	if is_instance_valid(collect_button) and not collect_button.pressed.is_connected(_on_collect_pressed):
		collect_button.pressed.connect(_on_collect_pressed)
	for i in range(choice_buttons.size()):
		var button := choice_buttons[i]
		if is_instance_valid(button) and not button.pressed.is_connected(_on_choice_pressed.bind(i)):
			button.pressed.connect(_on_choice_pressed.bind(i))
	if not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)


func _reset_visible_state() -> void:
	if is_instance_valid(back_button):
		back_button.visible = false
		back_button.disabled = true
	if is_instance_valid(siyokoy_sprite):
		siyokoy_sprite.visible = false
	if is_instance_valid(roman_label):
		roman_label.visible = false
	if is_instance_valid(reward_layer):
		reward_layer.visible = false
	if is_instance_valid(feedback_panel):
		feedback_panel.visible = false
	if is_instance_valid(briefcase_reveal):
		briefcase_reveal.visible = false
		briefcase_reveal.texture = null
	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.disabled = true
	_update_hud()
	_update_role_panels()


func _update_role_text() -> void:
	if is_instance_valid(role_label):
		role_label.text = "Role: " + _get_role_text()


func _get_role_text() -> String:
	if not multiplayer.has_multiplayer_peer() and GameState.local_role == GameState.Role.NONE:
		return "SOLO TEST"
	return GameState.get_role_display_text()


func _is_detective_view() -> bool:
	return GameState.local_role == GameState.Role.DETECTIVE or not multiplayer.has_multiplayer_peer()


func _is_sidekick_view() -> bool:
	return GameState.local_role == GameState.Role.SIDEKICK or not multiplayer.has_multiplayer_peer()


func _start_intro() -> void:
	_dialogue_locked = true
	_set_choice_buttons_enabled(false)
	_update_instruction("The Old Well stirs. Listen carefully before answering.")
	var lines: Array[Dictionary] = [
		{"speaker": "detective", "text": "The well is moving. Something is watching us."},
		{"speaker": "detective", "text": "I can see Roman numerals glowing on the stones."},
		{"speaker": "sidekick", "text": "Tell me what number they mean. I will choose the answer."},
		{"speaker": "sidekick", "text": "Hurry. The Siyokoy is waiting for a mistake."}
	]
	DialogueSystem.play("old_well_roman_intro", lines)
	await DialogueSystem.wait_finished("old_well_roman_intro")
	_dialogue_locked = false
	_report_intro_ready()


func _report_intro_ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		_server_start_puzzle()
		return
	if multiplayer.is_server():
		_mark_intro_ready(multiplayer.get_unique_id())
	else:
		rpc_report_intro_ready.rpc_id(SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_report_intro_ready() -> void:
	if multiplayer.is_server():
		_mark_intro_ready(multiplayer.get_remote_sender_id())


func _mark_intro_ready(peer_id: int) -> void:
	_intro_ready_peers[peer_id] = true
	if _intro_ready_peers.size() >= multiplayer.get_peers().size() + 1:
		_server_start_puzzle()


func _server_start_puzzle() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_round_index = 0
	_lives = MAX_LIVES
	_used_values.clear()
	_zone_active = true
	_server_next_round()


func _server_next_round() -> void:
	var item := _pick_unused_item()
	_current_roman = str(item["roman"])
	_current_value = int(item["value"])
	_used_values.append(_current_value)
	_current_choices = _build_choices(_current_value)
	if multiplayer.has_multiplayer_peer():
		rpc_sync_round.rpc(_current_roman, _current_value, _current_choices, _round_index, _lives)
	else:
		rpc_sync_round(_current_roman, _current_value, _current_choices, _round_index, _lives)


func _pick_unused_item() -> Dictionary:
	var available: Array[Dictionary] = []
	for item in ROMAN_POOL:
		if not _used_values.has(int(item["value"])):
			available.append(item)
	if available.is_empty():
		available = ROMAN_POOL.duplicate(true)
	var index := _rng.randi_range(0, available.size() - 1)
	return available[index]


func _build_choices(correct_value: int) -> Array[int]:
	var choices: Array[int] = [correct_value]
	while choices.size() < 3:
		var offset := _rng.randi_range(1, 9)
		var wrong := correct_value + (offset if _rng.randf() > 0.5 else -offset)
		wrong = clampi(wrong, 1, 50)
		if wrong != correct_value and not choices.has(wrong):
			choices.append(wrong)
	choices.shuffle()
	return choices


@rpc("authority", "reliable", "call_local")
func rpc_sync_round(roman: String, value: int, choices: Array, round_index: int, lives: int) -> void:
	_current_roman = roman
	_current_value = value
	_current_choices.clear()
	for choice in choices:
		_current_choices.append(int(choice))
	_round_index = round_index
	_lives = lives
	_zone_active = true
	_update_hud()
	_update_role_panels()
	_show_feedback("Round " + str(_round_index + 1) + ": communicate quickly.", UI_GOLD, 1.4)


func _update_hud() -> void:
	if is_instance_valid(progress_label):
		progress_label.text = "Progress: " + str(_round_index) + "/" + str(ROUNDS_TO_WIN)
	if is_instance_valid(lives_label):
		lives_label.text = "Lives: " + str(_lives) + "/" + str(MAX_LIVES)
	if is_instance_valid(status_label):
		if _reward_active:
			status_label.text = "Eye Clue unlocked"
		elif _zone_active:
			status_label.text = "Roman Numeral Challenge"
		else:
			status_label.text = "Old Well"


func _update_instruction(text: String = "") -> void:
	if not is_instance_valid(instruction_label):
		return
	if not text.is_empty():
		instruction_label.text = text
	elif _is_sidekick_view() and not _is_detective_view():
		instruction_label.text = "Listen to the Detective, then choose the matching number."
	elif _is_detective_view() and not _is_sidekick_view():
		instruction_label.text = "Read the Roman numeral aloud. The Sidekick chooses the number."
	else:
		instruction_label.text = "Solo test: Roman prompt and answer choices are both visible."


func _update_role_panels() -> void:
	var show_roman := _is_detective_view() and _zone_active and not _reward_active and not _clue_collected
	var show_choices := _is_sidekick_view() and _zone_active and not _reward_active and not _clue_collected and not _attack_active
	if is_instance_valid(sidekick_panel):
		sidekick_panel.visible = false
	if is_instance_valid(detective_panel):
		detective_panel.visible = show_choices
	if is_instance_valid(siyokoy_sprite):
		siyokoy_sprite.visible = false
	if is_instance_valid(roman_label):
		roman_label.visible = show_roman
		roman_label.text = _current_roman if show_roman else ""
	for i in range(choice_buttons.size()):
		var button := choice_buttons[i]
		if is_instance_valid(button):
			var has_choice := i < _current_choices.size()
			button.visible = has_choice
			button.disabled = not show_choices or not has_choice or _dialogue_locked
			button.text = str(_current_choices[i]) if has_choice else ""
			button.custom_minimum_size = Vector2(112, 112)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_update_instruction()


func _set_choice_buttons_enabled(enabled: bool) -> void:
	for button in choice_buttons:
		if is_instance_valid(button):
			button.disabled = not enabled


func _on_choice_pressed(choice_index: int) -> void:
	if _dialogue_locked or not _zone_active or _reward_active:
		return
	if not _is_sidekick_view():
		_show_feedback("Only the Sidekick can choose an answer.", UI_GOLD, 1.5)
		return
	if choice_index < 0 or choice_index >= _current_choices.size():
		return
	var selected := int(_current_choices[choice_index])
	_set_choice_buttons_enabled(false)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_server_submit_answer(selected)
	else:
		rpc_submit_answer.rpc_id(SERVER_PEER_ID, selected)


@rpc("any_peer", "reliable")
func rpc_submit_answer(selected: int) -> void:
	if multiplayer.is_server():
		_server_submit_answer(selected)


func _server_submit_answer(selected: int) -> void:
	if not _zone_active:
		return
	var correct := selected == _current_value
	if correct:
		_round_index += 1
		if multiplayer.has_multiplayer_peer():
			rpc_answer_feedback.rpc(true, _round_index, _lives, false)
		else:
			rpc_answer_feedback(true, _round_index, _lives, false)
		if _round_index >= ROUNDS_TO_WIN:
			await get_tree().create_timer(0.8).timeout
			_server_complete_puzzle()
		else:
			await get_tree().create_timer(0.8).timeout
			_server_next_round()
	else:
		_lives -= 1
		var reset := _lives <= 0
		if multiplayer.has_multiplayer_peer():
			rpc_answer_feedback.rpc(false, _round_index, max(_lives, 0), reset)
		else:
			rpc_answer_feedback(false, _round_index, max(_lives, 0), reset)
		await get_tree().create_timer(1.2).timeout
		if reset:
			_round_index = 0
			_lives = MAX_LIVES
			_used_values.clear()
			_server_next_round()
		else:
			if multiplayer.has_multiplayer_peer():
				rpc_sync_round.rpc(_current_roman, _current_value, _current_choices, _round_index, _lives)
			else:
				rpc_sync_round(_current_roman, _current_value, _current_choices, _round_index, _lives)


@rpc("authority", "reliable", "call_local")
func rpc_answer_feedback(correct: bool, round_index: int, lives: int, reset: bool) -> void:
	_round_index = round_index
	_lives = lives
	_update_hud()
	if correct:
		_show_feedback("Correct. The well calms for a moment.", UI_GREEN, 1.1)
	else:
		await _play_siyokoy_attack(reset)
		if reset:
			_show_feedback("No lives left. The Siyokoy resets the puzzle.", UI_RED, 1.8)
		else:
			_show_feedback("Wrong answer. The Siyokoy splashes the well.", UI_RED, 1.6)
		_update_role_panels()


func _server_complete_puzzle() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if multiplayer.has_multiplayer_peer():
		rpc_complete_puzzle.rpc()
	else:
		rpc_complete_puzzle()


@rpc("authority", "reliable", "call_local")
func rpc_complete_puzzle() -> void:
	_zone_active = false
	_reward_active = true
	GameState.set_puzzle_solved(ZONE_ID, true)
	_update_hud()
	_update_role_panels()
	_show_reward()


func _show_feedback(text: String, color: Color, duration: float) -> void:
	if not is_instance_valid(feedback_panel) or not is_instance_valid(feedback_label):
		return
	feedback_panel.visible = true
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", color)
	var token := Time.get_ticks_msec()
	feedback_panel.set_meta("feedback_token", token)
	await get_tree().create_timer(duration, true).timeout
	if is_instance_valid(feedback_panel) and feedback_panel.get_meta("feedback_token", -1) == token:
		feedback_panel.visible = false


func _play_siyokoy_attack(reset: bool) -> void:
	if not is_instance_valid(siyokoy_sprite):
		return
	_attack_active = true
	_update_role_panels()
	siyokoy_sprite.visible = true
	siyokoy_sprite.texture = TEX_SIYOKOY_ATTACK
	var base_pos := _siyokoy_rest_position
	if base_pos == Vector2.ZERO:
		base_pos = siyokoy_sprite.position
	siyokoy_sprite.position = base_pos + Vector2(0, 92 if reset else 70)
	siyokoy_sprite.modulate = Color(1.0, 0.78, 0.78, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(siyokoy_sprite, "modulate", Color(1.0, 0.78, 0.78, 1.0), 0.65)
	tween.tween_property(siyokoy_sprite, "position", base_pos + Vector2(0, -16 if reset else -8), 0.65)
	tween.chain().tween_property(siyokoy_sprite, "position", base_pos, 0.2)
	tween.chain().tween_interval(0.35)
	tween.chain().tween_callback(func():
		if is_instance_valid(siyokoy_sprite):
			siyokoy_sprite.texture = TEX_SIYOKOY_WELL
			siyokoy_sprite.modulate = Color(1, 1, 1, 0)
			siyokoy_sprite.position = base_pos
			siyokoy_sprite.visible = false
	)
	await tween.finished
	_attack_active = false


func _show_reward() -> void:
	if is_instance_valid(reward_layer):
		reward_layer.visible = true
	if is_instance_valid(reward_dark):
		reward_dark.modulate.a = 0.48
	if is_instance_valid(reward_banner):
		reward_banner.text = "ARTIFACT FOUND!"
	if is_instance_valid(clue_sprite):
		clue_sprite.visible = true
		clue_sprite.modulate.a = 1.0
	if is_instance_valid(reward_text):
		reward_text.text = ""
	if is_instance_valid(tap_catcher):
		tap_catcher.visible = true
		tap_catcher.disabled = false
	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.disabled = true
	if is_instance_valid(briefcase_reveal):
		briefcase_reveal.visible = false
		briefcase_reveal.texture = null
	_reward_stage = 1
	_waiting_reward_tap = true
	_collect_started = false


func _on_reward_tap_pressed() -> void:
	if not _waiting_reward_tap:
		return
	match _reward_stage:
		1:
			_reward_stage = 2
			_set_reward_text("The Roman numerals on the well revealed the Eye Clue.")
		2:
			_reward_stage = 3
			_set_reward_text("Pina had eyes, but chose not to see.")
		3:
			_reward_stage = 4
			_set_reward_text("\"She had eyes but chose not to see.\"")
		_:
			_waiting_reward_tap = false
			if is_instance_valid(tap_catcher):
				tap_catcher.visible = false
				tap_catcher.disabled = true
			if is_instance_valid(collect_button):
				var can_collect := _is_sidekick_view()
				collect_button.visible = can_collect
				collect_button.disabled = not can_collect


func _set_reward_text(text: String) -> void:
	if is_instance_valid(reward_text):
		reward_text.text = text


func _on_collect_pressed() -> void:
	if _collect_started:
		return
	_collect_started = true
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
	if is_instance_valid(briefcase_reveal):
		briefcase_reveal.texture = GameState.get_briefcase_texture("old_well_reveal")
		briefcase_reveal.visible = briefcase_reveal.texture != null
	await get_tree().create_timer(1.3, true).timeout
	if not multiplayer.has_multiplayer_peer():
		rpc_finalize_clue()
	elif multiplayer.is_server():
		rpc_finalize_clue.rpc()


func _hide_reward_visuals_for_briefcase() -> void:
	for node in [clue_sprite, reward_banner, tap_catcher, collect_button]:
		if is_instance_valid(node):
			node.visible = false
	if is_instance_valid(reward_text):
		reward_text.text = ""


@rpc("authority", "reliable", "call_local")
func rpc_finalize_clue() -> void:
	GameState.collect_clue(ZONE_ID)
	_clue_collected = true
	_reward_active = false
	if is_instance_valid(reward_layer):
		reward_layer.visible = false
	if is_instance_valid(briefcase_reveal):
		briefcase_reveal.visible = false
		briefcase_reveal.texture = null
	_show_feedback("Eye Clue added to the briefcase.", UI_GREEN, 1.2)
	await get_tree().create_timer(1.0).timeout
	_return_to_forest()


func _on_clue_collected(zone_id: String, _data: Dictionary) -> void:
	if zone_id == ZONE_ID:
		_clue_collected = true


func _on_back_pressed() -> void:
	if not _dialogue_locked:
		_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	if is_inside_tree():
		get_tree().change_scene_to_file(SCENE_FOREST_HUB)
