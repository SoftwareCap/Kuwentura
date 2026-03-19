extends Node2D

const TOTAL_TIME_SEC := 300
const MAX_STRIKES := 3
const ZONE_ID := "backyard_path"
const _SERVER_PEER_ID := 1

@onready var role_label: Label = get_node_or_null("RoleLabel")
@onready var back_button: Button = $BackButton

# Role visuals
@onready var detective_overlays: Control = $RoleLayer/Control/DetectiveOverlays
@onready var sidekick_overlays: Control = $RoleLayer/Control/SidekickOverlays

@onready var pina_spirit: TextureRect = $RoleLayer/Control/DetectiveOverlays/Pina
@onready var detective_height_label: Label = $RoleLayer/Control/DetectiveOverlays/PinasHeight

@onready var pineapple_plant: TextureRect = $RoleLayer/Control/SidekickOverlays/PineapplePlant
@onready var pineapple_fruit: TextureRect = $RoleLayer/Control/SidekickOverlays/PineappleFruit
@onready var sidekick_height_label: Label = $RoleLayer/Control/SidekickOverlays/PlantsHeight
@onready var revealed_pineapple: Sprite2D = $RoleLayer/Control/Pineapple
@onready var revealed_plant: TextureRect = $RoleLayer/Control/PineapplePlant

# Mobile-safe hotspots
@onready var board_tap_button: TextureButton = $RoleLayer/Control/BoardTapButton
@onready var fruit_tap_button: TextureButton = $RoleLayer/Control/FruitTapButton

# Deduction board
@onready var board_layer: CanvasLayer = $"Deduction Board"
@onready var board_sprite: Sprite2D = $"Deduction Board/Control/BoardSprite"
@onready var board_height_label: Label = $"Deduction Board/Control/PlantHeight"
@onready var x_input: LineEdit = $"Deduction Board/Control/XInput"
@onready var submit_button: Button = $"Deduction Board/Control/SubmitButton"
@onready var feedback_label: Label = $"Deduction Board/Control/FeedbackLabel"

# Notification
@onready var notification_ui: CanvasLayer = get_node_or_null("NotificationUI")
@onready var notification_panel: Panel = get_node_or_null("NotificationUI/Panel")
@onready var notification_label: Label = get_node_or_null("NotificationUI/Panel/Label")

# Ledger guidance
@onready var guidance_arrow: CanvasItem = get_node_or_null("RoleLayer/Control/GuidanceArrow")
@onready var touch_controls: Node = get_node_or_null("InsideZoneControl")
@onready var ledger_touch_button: TouchScreenButton = get_node_or_null("InsideZoneControl/Ledger")
@onready var briefcase_touch_button: TouchScreenButton = get_node_or_null("InsideZoneControl/Briefcase")

@onready var ledger_panel: Panel = get_node_or_null("SidekickLayer/Ledger")
@onready var ledger_title_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerTitle")
@onready var ledger_body_label: Label = get_node_or_null("SidekickLayer/Ledger/Control/LedgerBody")

# Consequence visuals
@onready var fog_overlay: ColorRect = $FogOverlay

#zone controls
@onready var inside_zone_control: CanvasLayer = get_node_or_null("InsideZoneControl")

@onready var pause_canvas_layer: CanvasLayer = get_node_or_null("PauseCanvasLayer")
@onready var in_game_pause_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel")
@onready var option_sub_panel: Panel = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel")
@onready var volume_slider: HSlider = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider")
@onready var volume_value_label: Label = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue")

@onready var briefcase_panel: Panel = get_node_or_null("SidekickLayer/Briefcase")
@onready var briefcase_display: TextureRect = get_node_or_null("SidekickLayer/Briefcase/BriefcaseDisplay")

# Reward
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

# Audio
var _sfx_player: AudioStreamPlayer
var _zone_completion_sfx: AudioStream = preload("res://assets/audios/ZoneCompletionSFX.mp3")

# Puzzle data
var puzzle_data: Dictionary = {}

var _waiting_reward_continue := false
var _reward_stage := 0
var _collect_sequence_started := false

# Cached values from puzzle_data
var spirit_height_cm: int
var plant_height_dali: int
var solution_cm: int

# State
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

var _timer_node: Timer
var _ledger_hint_shown := false
var _dialogue_input_locked := false

const SPARKLE_MIN_SCALE := 0.45
const SPARKLE_MAX_SCALE := 0.55
const SPARKLE_PULSE_SPEED := 4.0

var _animation_time: float = 0.0
var _sparkle_animating: bool = false

func _load_puzzle_data() -> void:
	puzzle_data = PuzzleManager.get_puzzle_for_zone(ZONE_ID)

	print("[BackyardPath] RAW puzzle_data: ", puzzle_data)

	if puzzle_data.is_empty():
		push_error("[BackyardPath] Puzzle data missing for zone: " + ZONE_ID)
		return

	spirit_height_cm = int(puzzle_data.get("spirit_height_cm", 0))
	plant_height_dali = int(round(float(puzzle_data.get("plant_height_dali", 0.0))))
	solution_cm = int(puzzle_data.get("solution", 0))

	print("[BackyardPath] spirit_height_cm: ", spirit_height_cm)
	print("[BackyardPath] plant_height_dali: ", plant_height_dali)
	print("[BackyardPath] solution_cm: ", solution_cm)

func _ready() -> void:
	print("[BackyardPath] Scene loaded")

	# 1 Load puzzle data FIRST
	_load_puzzle_data()

	# 2 Core systems
	_create_timer()
	_connect_signals()
	_setup_role_label()

	# 3 UI initialization
	_setup_initial_ui()
	_setup_role_visibility()

	# 4 Apply puzzle values to UI
	_populate_heights()
	_populate_ledger_content()
	_ensure_briefcase_display()
	_refresh_briefcase_display()

	# 5 Connect clue signal
	if not GameState.clue_collected.is_connected(_on_clue_collected):
		GameState.clue_collected.connect(_on_clue_collected)

	if not GameState.briefcase_updated.is_connected(_on_briefcase_updated):
		GameState.briefcase_updated.connect(_on_briefcase_updated)

	# 6 Start backyard background music
	if Engine.has_singleton("MusicController") or MusicController:
		MusicController.play_track(MusicController.MusicTrack.BACKYARD_PATH)

	# 7 Setup SFX player
	_ensure_sfx_bus()
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

	# 8 Start intro dialogue
	_start_intro_dialogue_delayed()

func _create_timer() -> void:
	_timer_node = Timer.new()
	_timer_node.one_shot = true
	_timer_node.wait_time = TOTAL_TIME_SEC
	add_child(_timer_node)

	if not _timer_node.timeout.is_connected(_on_board_timer_timeout):
		_timer_node.timeout.connect(_on_board_timer_timeout)


func _ensure_sfx_bus() -> void:
	"""Create SFX audio bus if it doesn't exist."""
	var sfx_bus_index := AudioServer.get_bus_index("SFX")
	if sfx_bus_index == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_volume_db(AudioServer.bus_count - 1, 0.0)


func _play_zone_completion_sfx() -> void:
	"""Play zone completion SFX and resume music when done (non-blocking)."""
	if not is_instance_valid(_sfx_player) or not _zone_completion_sfx:
		return
	
	# Pause background music
	if Engine.has_singleton("MusicController") or MusicController:
		MusicController.pause_music()
	
	# Play SFX
	_sfx_player.stream = _zone_completion_sfx
	_sfx_player.play()
	
	# Resume music when SFX finishes (using signal, not await)
	if not _sfx_player.finished.is_connected(_on_sfx_finished_resume_music):
		_sfx_player.finished.connect(_on_sfx_finished_resume_music, CONNECT_ONE_SHOT)


func _on_sfx_finished_resume_music() -> void:
	"""Callback to resume music after SFX finishes."""
	if Engine.has_singleton("MusicController") or MusicController:
		MusicController.resume_music()
		print("[BackyardPath] SFX finished, music resumed")


func _connect_signals() -> void:
	
	if is_instance_valid(touch_controls):
		print("[BackyardPath] TouchControls found")

	if touch_controls.has_signal("ledger_pressed"):
		print("[BackyardPath] Connecting ledger signal")
		touch_controls.ledger_pressed.connect(_on_ledger_pressed)
		
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

	if is_instance_valid(touch_controls):
		if touch_controls.has_signal("ledger_pressed"):
			if not touch_controls.ledger_pressed.is_connected(_on_ledger_pressed):
				touch_controls.ledger_pressed.connect(_on_ledger_pressed)
	
	if is_instance_valid(tap_catcher) and not tap_catcher.pressed.is_connected(_on_reward_tap_catcher_pressed):
		tap_catcher.pressed.connect(_on_reward_tap_catcher_pressed)

		if is_instance_valid(touch_controls):
			if touch_controls.has_signal("pause_pressed"):
				if not touch_controls.pause_pressed.is_connected(_on_pause_button_pressed):
					touch_controls.pause_pressed.connect(_on_pause_button_pressed)

			if touch_controls.has_signal("briefcase_pressed"):
				if not touch_controls.briefcase_pressed.is_connected(_on_briefcase_button_pressed):
					touch_controls.briefcase_pressed.connect(_on_briefcase_button_pressed)

	var resume_button: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/Resume_PlayButton")
	if is_instance_valid(resume_button) and not resume_button.pressed.is_connected(_on_resume_play_button_pressed):
		resume_button.pressed.connect(_on_resume_play_button_pressed)

	var option_button: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionButton")
	if is_instance_valid(option_button) and not option_button.pressed.is_connected(_on_option_button_pressed):
		option_button.pressed.connect(_on_option_button_pressed)

	var exit_button: BaseButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/ExitButton")
	if is_instance_valid(exit_button) and not exit_button.pressed.is_connected(_on_exit_to_main_menu_button_pressed):
		exit_button.pressed.connect(_on_exit_to_main_menu_button_pressed)

	var option_back_button: TouchScreenButton = get_node_or_null("PauseCanvasLayer/InGamePausePanel/OptionSubPanel/BackToPrevious")
	if is_instance_valid(option_back_button) and not option_back_button.pressed.is_connected(_on_in_game_option_back_pressed):
		option_back_button.pressed.connect(_on_in_game_option_back_pressed)

	if is_instance_valid(volume_slider) and not volume_slider.value_changed.is_connected(_on_in_game_volume_changed):
		volume_slider.value_changed.connect(_on_in_game_volume_changed)
		
func _setup_role_label() -> void:
	var role_text := "Unknown"
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"

	if is_instance_valid(role_label):
		role_label.text = "Role: " + role_text

	print("[BackyardPath] Local role: ", role_text, " | Peer ID: ", multiplayer.get_unique_id())


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

	if is_instance_valid(board_layer):
		board_layer.visible = true

	if is_instance_valid(board_tap_button):
		board_tap_button.disabled = true
		board_tap_button.visible = true
		board_tap_button.z_index = 100

	if is_instance_valid(x_input):
		x_input.visible = false
		x_input.text = ""
		x_input.editable = false
		x_input.placeholder_text = "Answer"
		x_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER

	if is_instance_valid(submit_button):
		submit_button.visible = false
		submit_button.disabled = true

	#if is_instance_valid(feedback_label):
		#feedback_label.text = "Deduction Board locked."
		
	if is_instance_valid(reward_layer):
		reward_layer.visible = true

	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = true

	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null

	if is_instance_valid(sparkle):
		sparkle.visible = true
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
		_animation_time = 0.0
		_sparkle_animating = true

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

	if is_instance_valid(fog_overlay):
		fog_overlay.visible = true
		fog_overlay.modulate.a = 0.0
		fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	# Prevent role overlays from blocking mobile touch
	if is_instance_valid(detective_overlays):
		detective_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(sidekick_overlays):
		sidekick_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null
		briefcase_reveal_sprite.modulate = Color(1, 1, 1, 1)

	if is_instance_valid(pause_canvas_layer):
		pause_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	if is_instance_valid(in_game_pause_panel):
		in_game_pause_panel.visible = false
		in_game_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = false
		option_sub_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	if is_instance_valid(volume_slider):
		volume_slider.value = MusicController.get_volume() * 100

	if is_instance_valid(volume_value_label):
		volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"

	if is_instance_valid(briefcase_panel):
		briefcase_panel.visible = false

	# Detective must never type or submit
	if GameState.local_role == GameState.Role.DETECTIVE:
		if is_instance_valid(x_input):
			x_input.editable = false
		if is_instance_valid(submit_button):
			submit_button.disabled = true

func _set_dialogue_input_lock(locked: bool) -> void:
	_dialogue_input_locked = locked

	var is_sidekick: bool = GameState.local_role == GameState.Role.SIDEKICK
	var dim_color := Color(0.65, 0.65, 0.65, 1.0)
	var normal_color := Color(1, 1, 1, 1)

	# Pause must stay enabled
	if is_instance_valid(touch_controls) and touch_controls.has_method("set_pause_enabled"):
		touch_controls.set_pause_enabled(true)

	# World interactions should not work during dialogue
	# TouchScreenButton has no "disabled", so only gray it out here.
	# Actual blocking is handled by _dialogue_input_locked checks in the pressed handlers.
	if is_instance_valid(board_tap_button):
		board_tap_button.modulate = dim_color if locked else normal_color

	if is_instance_valid(fruit_tap_button):
		fruit_tap_button.modulate = dim_color if locked else normal_color

	# Board input
	if is_instance_valid(x_input):
		if locked:
			x_input.editable = false
			x_input.release_focus()
			x_input.modulate = dim_color
		else:
			if GameState.local_role == GameState.Role.SIDEKICK and _board_opened and _board_unlocked and not _puzzle_solved and not _zone_failed:
				x_input.editable = true
			else:
				x_input.editable = false
			x_input.modulate = normal_color

	if is_instance_valid(submit_button):
		if locked:
			submit_button.disabled = true
		else:
			if GameState.local_role == GameState.Role.SIDEKICK and _board_opened and _board_unlocked and not _puzzle_solved and not _zone_failed:
				submit_button.disabled = false
			else:
				submit_button.disabled = true

		submit_button.modulate = dim_color if submit_button.disabled else normal_color

	# Only ledger / briefcase in inside_zone_control should turn gray during dialogue
	if is_instance_valid(touch_controls):
		if touch_controls.has_method("set_ledger_enabled"):
			touch_controls.set_ledger_enabled(is_sidekick and not locked)

		if touch_controls.has_method("set_briefcase_enabled"):
			touch_controls.set_briefcase_enabled(is_sidekick and not locked and _reward_active)

	# Direct TouchScreenButton nodes for ledger / briefcase:
	# keep visible, gray them out, but do NOT use .disabled
	if is_instance_valid(ledger_touch_button):
		ledger_touch_button.visible = is_sidekick
		ledger_touch_button.modulate = dim_color if locked else normal_color

	if is_instance_valid(briefcase_touch_button):
		briefcase_touch_button.visible = is_sidekick
		briefcase_touch_button.modulate = dim_color if locked else normal_color

	# Reward tap catcher should not work during dialogue
	if is_instance_valid(tap_catcher):
		tap_catcher.disabled = locked or not tap_catcher.visible

	# Restore normal zone state after dialogue ends
	if not locked:
		_refresh_inside_zone_buttons()

func _setup_role_visibility() -> void:
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

	_refresh_inside_zone_buttons()


func _populate_heights() -> void:
	if is_instance_valid(detective_height_label):
		detective_height_label.text = str(spirit_height_cm) + " cm"
		print("[BackyardPath] Detective height label: ", detective_height_label.text)

	if is_instance_valid(sidekick_height_label):
		sidekick_height_label.text = str(plant_height_dali) + " Dali"
		print("[BackyardPath] Sidekick height label: ", sidekick_height_label.text)

	if is_instance_valid(board_height_label):
		board_height_label.text = str(plant_height_dali) + " Dali"
		print("[BackyardPath] Board height label: ", board_height_label.text)

func _populate_ledger_content() -> void:
	var ledger_view: Dictionary = PuzzleManager.get_zone_ledger_display(ZONE_ID)

	if ledger_view.is_empty():
		return

	if is_instance_valid(ledger_title_label):
		ledger_title_label.text = str(ledger_view.get("title", ""))

	if is_instance_valid(ledger_body_label):
		ledger_body_label.text = str(ledger_view.get("body", ""))
		

func _start_intro_dialogue_delayed() -> void:
	if _intro_dialogue_played:
		return

	_intro_dialogue_played = true
	_run_intro_sequence()
	
func _get_backyard_intro_dialogue() -> Array:
	var lines: Array = DialogueLibrary.BACKYARD_PATH_ENTER.duplicate(true)

	lines.append(
		{"speaker":"sidekick","text":"But the numbers here say " + str(plant_height_dali) + " Dali."}
	)
	lines.append(
		{"speaker":"detective","text":"And Pina’s height says " + str(spirit_height_cm) + " centimeters."}
	)
	lines.append(
		{"speaker":"sidekick","text":"How can we compare those if they’re not in the same unit?"}
	)

	return lines


func _run_intro_sequence() -> void:
	_set_dialogue_input_lock(true)

	DialogueSystems.play("backyard_path_intro", _get_backyard_intro_dialogue())

	await DialogueSystems.wait_finished("backyard_path_intro")
	_set_dialogue_input_lock(false)
	_report_intro_ready()


func _report_intro_ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		rpc_unlock_board_phase()
		return

	if multiplayer.is_server():
		_mark_intro_ready(multiplayer.get_unique_id())
	else:
		rpc_report_intro_ready.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_report_intro_ready() -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	_mark_intro_ready(peer_id)


func _mark_intro_ready(peer_id: int) -> void:
	_intro_ready_peers[peer_id] = true

	if not multiplayer.is_server():
		return

	var needed := multiplayer.get_peers().size() + 1
	print("[BackyardPath] intro ready peer=", peer_id, " count=", _intro_ready_peers.size(), "/", needed)

	if _intro_ready_peers.size() >= needed:
		rpc_unlock_board_phase.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_unlock_board_phase() -> void:
	_zone_active = true
	_board_unlocked = true

	if is_instance_valid(board_tap_button):
		board_tap_button.disabled = false

	if is_instance_valid(feedback_label):
		if GameState.local_role == GameState.Role.SIDEKICK:
			feedback_label.text = "Enter the plant height in centimeters."
		else:
			feedback_label.text = "Tap the Deduction Board to view the conversion."

	# Hide the tap button for sidekick since board auto-opens
	if GameState.local_role == GameState.Role.SIDEKICK:
		if is_instance_valid(board_tap_button):
			board_tap_button.visible = false

	show_notification("Convert Dali to centimeters in the Deduction Board to uncover the clue.", 0.0)
	pulse_ledger_guidance(true)

	_set_dialogue_input_lock(true)

	DialogueSystems.play("backyard_ledger_hint", DialogueLibrary.BACKYARD_PATH_LEDGER_HINT)

	await DialogueSystems.wait_finished("backyard_ledger_hint")
	_set_dialogue_input_lock(false)

	# Auto-open the board for sidekick - no need to tap first!
	if GameState.local_role == GameState.Role.SIDEKICK:
		_open_board_local()
		_request_start_timer()


func _on_board_tap_pressed() -> void:
	if _dialogue_input_locked:
		return

	if not _board_unlocked or _zone_failed or _puzzle_solved:
		return

	_open_board_local()
	_request_start_timer()


func _open_board_local() -> void:
	_board_opened = true

	# Only show input and submit button to SIDEKICK
	var is_sidekick := GameState.local_role == GameState.Role.SIDEKICK

	if is_instance_valid(x_input):
		x_input.visible = is_sidekick
		x_input.editable = is_sidekick
		if is_sidekick:
			x_input.grab_focus()

	if is_instance_valid(submit_button):
		submit_button.visible = is_sidekick
		submit_button.disabled = not is_sidekick

	# Update feedback text based on role
	if is_instance_valid(feedback_label):
		if is_sidekick:
			feedback_label.text = "Convert " + str(plant_height_dali) + " Dali into centimeters."
		else:
			feedback_label.text = "The sidekick is solving the puzzle..."

	# Only show notification to sidekick (they're the only ones who can enter)
	if is_sidekick and _board_unlocked and not _puzzle_solved:
		show_notification("Enter the plant height in centimeters.", 2.5)


func _request_start_timer() -> void:
	if _timer_started:
		return

	if not multiplayer.has_multiplayer_peer():
		_start_board_timer_server()
		return

	if multiplayer.is_server():
		_start_board_timer_server()
	else:
		rpc_request_start_timer.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_start_timer() -> void:
	if not multiplayer.is_server():
		return

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
	if not multiplayer.is_server():
		return

	if _puzzle_solved or _zone_failed:
		return

	_server_fail_zone("The forest rejects your presence.\nReturn in 1 minute to try again.")

func _on_ledger_pressed() -> void:
	if _dialogue_input_locked:
		return

	if GameState.local_role != GameState.Role.SIDEKICK:
		return

	if not is_instance_valid(ledger_panel):
		return

	var should_open: bool = not ledger_panel.visible

	if should_open and is_instance_valid(briefcase_panel):
		briefcase_panel.visible = false

	ledger_panel.visible = should_open

	if ledger_panel.visible:
		hide_notification()
		pulse_ledger_guidance(false)
	else:
		if _board_unlocked and not _puzzle_solved:
			show_notification("Convert Dali to centimeters in the Deduction Board to uncover the clue.", 0.0)
			
func _on_briefcase_button_pressed() -> void:
	if _dialogue_input_locked:
		return

	if GameState.local_role != GameState.Role.SIDEKICK:
		return

	if not is_instance_valid(briefcase_panel):
		return

	_refresh_briefcase_display()

	var should_open: bool = not briefcase_panel.visible

	if should_open and is_instance_valid(ledger_panel):
		ledger_panel.visible = false

	briefcase_panel.visible = should_open


func _ensure_briefcase_display() -> void:
	if not is_instance_valid(briefcase_panel):
		return

	if is_instance_valid(briefcase_display):
		return

	briefcase_display = TextureRect.new()
	briefcase_display.name = "BriefcaseDisplay"
	briefcase_display.visible = false
	briefcase_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefcase_display.offset_left = -152.0
	briefcase_display.offset_top = 40.0
	briefcase_display.offset_right = 185.0
	briefcase_display.offset_bottom = 67.0
	briefcase_display.expand_mode = 1
	briefcase_display.stretch_mode = 5
	briefcase_display.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	if is_instance_valid(in_game_pause_panel):
		in_game_pause_panel.visible = true

	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = false

	if is_instance_valid(inside_zone_control):
		inside_zone_control.visible = false

	MusicController.pause_music()
	get_tree().paused = true


func _on_resume_play_button_pressed() -> void:
	if is_instance_valid(in_game_pause_panel):
		in_game_pause_panel.visible = false

	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = false

	get_tree().paused = false
	MusicController.resume_music()

	if is_instance_valid(inside_zone_control):
		inside_zone_control.visible = true


func _on_option_button_pressed() -> void:
	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = true

	if is_instance_valid(volume_slider):
		volume_slider.value = MusicController.get_volume() * 100

	if is_instance_valid(volume_value_label):
		volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


func _on_in_game_option_back_pressed() -> void:
	if is_instance_valid(option_sub_panel):
		option_sub_panel.visible = false


func _on_exit_to_main_menu_button_pressed() -> void:
	get_tree().paused = false
	MusicController.resume_music()

	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout

	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _on_in_game_volume_changed(value: float) -> void:
	var volume: float = value / 100.0
	MusicController.set_volume(volume)

	if is_instance_valid(volume_value_label):
		volume_value_label.text = str(int(value)) + "%"


func pulse_ledger_guidance(enable: bool) -> void:
	if GameState.local_role != GameState.Role.SIDEKICK:
		if is_instance_valid(guidance_arrow):
			guidance_arrow.visible = false
		return

	if _puzzle_solved:
		enable = false

	_ledger_hint_shown = enable

	if is_instance_valid(guidance_arrow):
		guidance_arrow.visible = enable

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
				if old_tw:
					old_tw.kill()
				ledger_touch_button.remove_meta("pulse_tween")

			ledger_touch_button.scale = Vector2(0.06, 0.06)


func _on_submit_pressed() -> void:
	if _dialogue_input_locked:
		return
		
	if GameState.local_role != GameState.Role.SIDEKICK:
		return

	if not _board_unlocked or _zone_failed or _puzzle_solved:
		return

	var answer_text := x_input.text.strip_edges()

	if answer_text.is_empty():
		if is_instance_valid(feedback_label):
			feedback_label.text = "Enter an answer first."
		return

	if not answer_text.is_valid_int():
		if is_instance_valid(feedback_label):
			feedback_label.text = "Numbers only."
		show_notification("Numbers only, sidekick. Try again.", 1.8)
		return

	var value := int(answer_text)

	if not multiplayer.has_multiplayer_peer():
		_server_validate_answer(value)
		return

	if multiplayer.is_server():
		_server_validate_answer(value)
	else:
		rpc_request_validate_answer.rpc_id(_SERVER_PEER_ID, value)


@rpc("any_peer", "reliable")
func rpc_request_validate_answer(value: int) -> void:
	if not multiplayer.is_server():
		return

	_server_validate_answer(value)


func _server_validate_answer(value: int) -> void:
	if _puzzle_solved or _zone_failed:
		return

	print("[BackyardPath] Submitted value: ", value, " | Expected solution: ", solution_cm)

	if value == solution_cm:
		rpc_puzzle_solved.rpc()
	else:
		_strikes += 1

		var strike_message := ""
		match _strikes:
			1:
				strike_message = "The forest grows uneasy..."
			2:
				strike_message = "The forest is watching you..."
			_:
				strike_message = "The forest consumes the path."

		rpc_apply_strike.rpc(_strikes, strike_message)

		if _strikes >= MAX_STRIKES:
			_server_fail_zone("The forest rejects your presence.\nReturn in 1 minute to try again.")


@rpc("any_peer", "reliable", "call_local")
func rpc_apply_strike(strike_count: int, strike_message: String) -> void:
	_strikes = strike_count

	if is_instance_valid(feedback_label):
		feedback_label.text = strike_message

	if is_instance_valid(fog_overlay):
		var alpha := 0.0
		match strike_count:
			1:
				alpha = 0.18
			2:
				alpha = 0.38
			_:
				alpha = 0.65
		fog_overlay.modulate.a = alpha

	show_notification(strike_message, 2.0)


func _server_fail_zone(message: String) -> void:
	if _zone_failed:
		return

	_zone_failed = true
	GameState.lock_zone_temp(ZONE_ID, 30)
	rpc_fail_zone.rpc(message)


@rpc("any_peer", "reliable", "call_local")
func rpc_fail_zone(message: String) -> void:
	_zone_failed = true
	_board_unlocked = false

	if is_instance_valid(board_tap_button):
		board_tap_button.disabled = true

	if is_instance_valid(submit_button):
		submit_button.disabled = true

	show_notification(message, 2.5)

	_set_dialogue_input_lock(true)

	DialogueSystems.play("backyard_fail", DialogueLibrary.BACKYARD_PATH_FAIL)

	await DialogueSystems.wait_finished("backyard_fail")
	_set_dialogue_input_lock(false)

	await get_tree().create_timer(2.5).timeout
	_return_to_forest()

@rpc("any_peer", "reliable", "call_local")
func rpc_puzzle_solved() -> void:
	_puzzle_solved = true
	GameState.set_puzzle_solved(ZONE_ID, true)
	_board_unlocked = false

	if is_instance_valid(board_tap_button):
		board_tap_button.disabled = true

	if is_instance_valid(submit_button):
		submit_button.visible = false
		submit_button.disabled = true

	if is_instance_valid(x_input):
		x_input.visible = false
		x_input.editable = false

	if is_instance_valid(feedback_label):
		feedback_label.text = str(plant_height_dali) + " Dali = " + str(solution_cm) + " cm. The plant and Pina share the same height."

	hide_notification()
	pulse_ledger_guidance(false)

	await _blink_board()

	if is_instance_valid(pina_spirit):
		pina_spirit.visible = false

	if is_instance_valid(detective_height_label):
		detective_height_label.visible = false

	if is_instance_valid(pineapple_plant):
		pineapple_plant.visible = false

	if is_instance_valid(pineapple_fruit):
		pineapple_fruit.visible = false

	if is_instance_valid(sidekick_height_label):
		sidekick_height_label.visible = false

	if is_instance_valid(revealed_plant):
		revealed_plant.visible = true
		revealed_plant.scale = Vector2.ONE
		revealed_plant.modulate = Color(1, 1, 1, 1)

	if is_instance_valid(revealed_pineapple):
		revealed_pineapple.visible = true
		revealed_pineapple.modulate = Color(1, 1, 1, 1)

	_sync_fruit_tap_button_to_revealed_pineapple()

	if is_instance_valid(fruit_tap_button):
		fruit_tap_button.visible = true
		fruit_tap_button.disabled = false

	_set_dialogue_input_lock(true)

	DialogueSystems.play("backyard_solved", DialogueLibrary.BACKYARD_PATH_SOLVED)

	await DialogueSystems.wait_finished("backyard_solved")
	_set_dialogue_input_lock(false)
	
func _sync_fruit_tap_button_to_revealed_pineapple() -> void:
	if not is_instance_valid(fruit_tap_button):
		return
	if not is_instance_valid(revealed_pineapple):
		return

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


func _on_fruit_tap_pressed() -> void:
	if _dialogue_input_locked:
		return

	if not _puzzle_solved or _reward_active or _zone_failed:
		return

	if not multiplayer.has_multiplayer_peer():
		rpc_show_reward.rpc()
		return

	if multiplayer.is_server():
		rpc_show_reward.rpc()
	else:
		rpc_request_show_reward.rpc_id(_SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func rpc_request_show_reward() -> void:
	if not multiplayer.is_server():
		return

	rpc_show_reward.rpc()



@rpc("any_peer", "reliable", "call_local")
func rpc_show_reward() -> void:
	if _reward_active:
		return

	_reward_active = true
	_waiting_reward_continue = true
	_reward_stage = 1
	_collect_sequence_started = false

	# Play SFX immediately when clue is found (separate from tap-to-continue logic)
	_play_zone_completion_sfx()

	_hide_revealed_clue_after_touch()

	if is_instance_valid(fruit_tap_button):
		fruit_tap_button.disabled = true
		fruit_tap_button.visible = false

	if is_instance_valid(reward_layer):
		reward_layer.visible = true
		
	if is_instance_valid(clue_sprite):
		clue_sprite.visible = true

	if is_instance_valid(sparkle):
		sparkle.visible = true
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
		_animation_time = 0.0
		_sparkle_animating = true

	if is_instance_valid(reward_dark_overlay):
		reward_dark_overlay.modulate.a = 0.45

	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = true
		reward_banner_label.text = "CLUE FOUND!"

	if is_instance_valid(reward_text_label):
		reward_text_label.text = ""

	if is_instance_valid(reward_panel):
		reward_panel.visible = false

	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = true
		tap_instruction_label.text = "Tap anywhere to continue."

	if is_instance_valid(tap_catcher):
		tap_catcher.visible = true
		tap_catcher.disabled = false

	if is_instance_valid(collect_button):
		collect_button.visible = false
		
	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null

func _on_collect_pressed() -> void:
	if _collect_sequence_started:
		return

	_collect_sequence_started = true

	if is_instance_valid(collect_button):
		collect_button.visible = false
		collect_button.disabled = true

	if not multiplayer.has_multiplayer_peer():
		rpc_show_briefcase_reveal_then_finalize()
		return

	if multiplayer.is_server():
		rpc_show_briefcase_reveal_then_finalize.rpc()
	else:
		rpc_request_collect_clue.rpc_id(_SERVER_PEER_ID)

@rpc("any_peer", "reliable")
func rpc_request_collect_clue() -> void:
	if not multiplayer.is_server():
		return

	rpc_show_briefcase_reveal_then_finalize.rpc()


@rpc("any_peer", "reliable", "call_local")
func rpc_finalize_clue() -> void:
	GameState.collect_clue(ZONE_ID)

	_sparkle_animating = false

	if is_instance_valid(sparkle):
		sparkle.visible = false
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)
		
	if is_instance_valid(clue_sprite):
		clue_sprite.visible = false

	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = false
		reward_banner_label.text = ""

	if is_instance_valid(briefcase_reveal_sprite):
		briefcase_reveal_sprite.visible = false
		briefcase_reveal_sprite.texture = null

	if is_instance_valid(reward_layer):
		reward_layer.visible = false

	_return_to_forest()


func show_notification(text: String, duration: float = 2.0) -> void:
	if not is_instance_valid(notification_panel) or not is_instance_valid(notification_label):
		print("[Notification] ", text)
		return

	notification_label.text = text
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


func _on_clue_collected(zone_id: String, _clue_data: Dictionary) -> void:
	if zone_id == ZONE_ID:
		print("[BackyardPath] clue collected")


func _on_back_pressed() -> void:
	if _dialogue_input_locked:
		return
		
	_return_to_forest()


func _return_to_forest() -> void:
	get_tree().paused = false
	MusicController.resume_music()
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
	
func _refresh_inside_zone_buttons() -> void:
	var is_sidekick: bool = GameState.local_role == GameState.Role.SIDEKICK

	if is_instance_valid(touch_controls):
		if touch_controls.has_method("set_pause_enabled"):
			touch_controls.set_pause_enabled(true)

		if touch_controls.has_method("set_ledger_enabled"):
			touch_controls.set_ledger_enabled(is_sidekick)

		if touch_controls.has_method("set_briefcase_enabled"):
			touch_controls.set_briefcase_enabled(is_sidekick)

		if touch_controls.has_method("set_sidekick_ui_visible"):
			touch_controls.set_sidekick_ui_visible(is_sidekick)

	# Extra safety: force panels/buttons hidden for detective
	if not is_sidekick:
		if is_instance_valid(ledger_panel):
			ledger_panel.visible = false

		if is_instance_valid(briefcase_panel):
			briefcase_panel.visible = false

		if is_instance_valid(ledger_touch_button):
			ledger_touch_button.visible = false

		if is_instance_valid(briefcase_touch_button):
			briefcase_touch_button.visible = false

func _apply_solved_board_state() -> void:
	if is_instance_valid(board_height_label):
		board_height_label.text = str(plant_height_dali) + " Dali"

	if is_instance_valid(x_input):
		x_input.visible = false
		x_input.editable = false
		x_input.text = ""

	if is_instance_valid(submit_button):
		submit_button.visible = false
		submit_button.disabled = true

	if is_instance_valid(feedback_label):
		feedback_label.text = str(plant_height_dali) + " Dali = " + str(solution_cm) + " cm"

func _apply_solved_world_state() -> void:
	if is_instance_valid(pina_spirit):
		pina_spirit.visible = false

	if is_instance_valid(detective_height_label):
		detective_height_label.visible = false

	if is_instance_valid(pineapple_plant):
		pineapple_plant.visible = false

	if is_instance_valid(pineapple_fruit):
		pineapple_fruit.visible = false

	if is_instance_valid(sidekick_height_label):
		sidekick_height_label.visible = false

	if is_instance_valid(revealed_plant):
		revealed_plant.visible = true
		revealed_plant.modulate = Color(1, 1, 1, 1)

	if is_instance_valid(revealed_pineapple):
		revealed_pineapple.visible = true
		revealed_pineapple.modulate = Color(1, 1, 1, 1)
		
func _on_reward_tap_catcher_pressed() -> void:
	if _dialogue_input_locked:
		return
	
	if not _waiting_reward_continue:
		return

	# Stage 1 -> first line
	if _reward_stage == 1:
		_reward_stage = 2

		if is_instance_valid(reward_panel):
			reward_panel.visible = true

		if is_instance_valid(reward_text_label):
			reward_text_label.text = "Pina has become the pineapple in the backyard."

		if is_instance_valid(tap_instruction_label):
			tap_instruction_label.visible = true
			tap_instruction_label.text = "Tap anywhere to continue."

		return

	# Stage 2 -> second line
	if _reward_stage == 2:
		_reward_stage = 3

		if is_instance_valid(reward_panel):
			reward_panel.visible = true

		if is_instance_valid(reward_text_label):
			reward_text_label.text = "Pina cannot find the things she is looking for."

		if is_instance_valid(tap_instruction_label):
			tap_instruction_label.visible = true
			tap_instruction_label.text = "Tap anywhere to continue."

		return

	# Stage 3 -> third line
	if _reward_stage == 3:
		_reward_stage = 4

		if is_instance_valid(reward_panel):
			reward_panel.visible = true

		if is_instance_valid(reward_text_label):
			reward_text_label.text = "But if she had a thousand eyes like a pineapple,"

		if is_instance_valid(tap_instruction_label):
			tap_instruction_label.visible = true
			tap_instruction_label.text = "Tap anywhere to continue."

		return

	# Stage 4 -> fourth line
	if _reward_stage == 4:
		_reward_stage = 5

		if is_instance_valid(reward_panel):
			reward_panel.visible = true

		if is_instance_valid(reward_text_label):
			reward_text_label.text = "perhaps she could see them again."

		if is_instance_valid(tap_instruction_label):
			tap_instruction_label.visible = true
			tap_instruction_label.text = "Tap anywhere to continue."

		return

	# Stage 5 -> show collect button
	if _reward_stage == 5:
		_reward_stage = 6
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
			if multiplayer.has_multiplayer_peer():
				collect_button.visible = GameState.local_role == GameState.Role.SIDEKICK
			else:
				collect_button.visible = true

func _show_briefcase_reveal_local() -> void:
	if not is_instance_valid(briefcase_reveal_sprite):
		return

	var reveal_texture: Texture2D = GameState.get_briefcase_texture("backyard_path_reveal")
	briefcase_reveal_sprite.texture = reveal_texture
	briefcase_reveal_sprite.visible = reveal_texture != null
	briefcase_reveal_sprite.modulate = Color(1, 1, 1, 1)

@rpc("any_peer", "reliable", "call_local")
func rpc_show_briefcase_reveal_then_finalize() -> void:
	_hide_reward_visuals_for_briefcase()
	_show_briefcase_reveal_local()

	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = false
		tap_instruction_label.text = ""

	if is_instance_valid(tap_catcher):
		tap_catcher.visible = false
		tap_catcher.disabled = true

	await get_tree().create_timer(1.5).timeout

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			rpc_finalize_clue.rpc()
	else:
		rpc_finalize_clue()

#Sparkle Animation
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
		
func _hide_reward_visuals_for_briefcase() -> void:
	_sparkle_animating = false

	if is_instance_valid(sparkle):
		sparkle.visible = false
		sparkle.scale = Vector2(SPARKLE_MIN_SCALE, SPARKLE_MIN_SCALE)

	if is_instance_valid(clue_sprite):
		clue_sprite.visible = false

	if is_instance_valid(reward_banner_label):
		reward_banner_label.visible = false
		reward_banner_label.text = ""

	if is_instance_valid(reward_panel):
		reward_panel.visible = false

	if is_instance_valid(reward_text_label):
		reward_text_label.text = ""

	if is_instance_valid(tap_instruction_label):
		tap_instruction_label.visible = false
		tap_instruction_label.text = ""

	if is_instance_valid(tap_catcher):
		tap_catcher.visible = false
		tap_catcher.disabled = true

	if is_instance_valid(collect_button):
		collect_button.visible = false

func _hide_revealed_clue_after_touch() -> void:
	if is_instance_valid(revealed_plant):
		revealed_plant.visible = false

	if is_instance_valid(revealed_pineapple):
		revealed_pineapple.visible = false

	if is_instance_valid(fruit_tap_button):
		fruit_tap_button.visible = false
