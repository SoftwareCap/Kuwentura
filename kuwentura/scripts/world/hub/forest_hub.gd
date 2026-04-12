extends Node2D

## Forest Hub - Main world scene with zone portals and player spawning.

@onready var player_host_scene: PackedScene = preload("res://scenes/players/PlayerHost.tscn")
@onready var player_sidekick_scene: PackedScene = preload("res://scenes/players/PlayerSidekick.tscn")

@export var detective_scale: Vector2 = Vector2(0.2, 0.2)
@export var sidekick_scale: Vector2 = Vector2(0.2, 0.2)
@export var ground_y: float = 750.0

@onready var dialogue_panel: Panel = $DialogueLayer/DialoguePanel
@onready var speaker_label: Label = $DialogueLayer/DialoguePanel/SpeakerLabel
@onready var dialogue_label: Label = $DialogueLayer/DialoguePanel/DialogueLabel

@onready var spawn_points: Node2D = $SpawnPoints
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var pause_canvas_layer: CanvasLayer = $PauseCanvasLayer
@onready var in_game_pause_panel: Panel = $PauseCanvasLayer/InGamePausePanel
@onready var option_sub_panel: Panel = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel
@onready var volume_slider: HSlider = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $PauseCanvasLayer/InGamePausePanel/OptionSubPanel/VolumeSliderControl/VolumeValue
@onready var room_code_label: Label = $HUDLayer/RoomCode
@onready var finish_zone_indicator: Node = $FinishZoneIndicator

@onready var forest_ledger_title_label: Label = $SidekickLayer/Ledger/Control/LedgerTitle
@onready var forest_ledger_left_header_label: Label = $SidekickLayer/Ledger/Control/LedgerLeftHeader
@onready var forest_ledger_left_body_label: Label = $SidekickLayer/Ledger/Control/LedgerLeftBody
@onready var forest_ledger_right_header_label: Label = $SidekickLayer/Ledger/Control/LedgerRightHeader
@onready var forest_ledger_right_body_label: Label = $SidekickLayer/Ledger/Control/LedgerRightBody
@onready var forest_prev_page_button: Button = $SidekickLayer/Ledger/Control/PrevPageButton
@onready var forest_next_page_button: Button = $SidekickLayer/Ledger/Control/NextPageButton
@onready var forest_page_indicator_label: Label = $SidekickLayer/Ledger/Control/PageIndicator
@onready var forest_ledger_control: Control = $SidekickLayer/Ledger/Control

@onready var sidekick_layer: CanvasLayer = $SidekickLayer
@onready var ledger_panel: Panel = $SidekickLayer/Ledger
@onready var briefcase_panel: Panel = $SidekickLayer/Briefcase
@onready var briefcase_display: TextureRect = $SidekickLayer/Briefcase/BriefcaseDisplay
@onready var map_layer: CanvasLayer = $MapLayer
@onready var map_panel: Panel = $MapLayer/Map
@onready var portals: Node2D = $"Zone Portals"
@onready var pinas_house_door: Sprite2D = $"Zone Portals/PortalPinasHouse/DoorOpen"

const PANEL_ANIMATION_DURATION: float = 0.4
const DIALOGUE_SPEED: float = 0.04
const LEDGER_PAGE_TURN_DURATION: float = 0.16
const DOOR_ANIMATION_DURATION: float = 0.5
const LEDGER_EMPTY_TEXT := "Solve a zone puzzle to unlock \nledger notes in the forest."
const LEDGER_OPEN_SCALE: Vector2 = Vector2(1.0, 1.0)
const LEDGER_CLOSED_SCALE: Vector2 = Vector2(0.1, 1.0)
const BRIEFCASE_OPEN_SCALE: Vector2 = Vector2(1.0, 1.0)
const BRIEFCASE_CLOSED_SCALE: Vector2 = Vector2(1.0, 0.1)
const SCENE_MAIN_MENU := "res://scenes/mainMenu/MainMenu.tscn"
const SETTINGS_FILE := "user://settings.json"
const FIND_PARTNER_DURATION: float = 1.2
const FIND_PARTNER_HOLD: float = 2.0

var _spawned_players: Dictionary = {}
var _is_finding_partner: bool = false
var _current_open_panel: String = ""
var _is_animating: bool = false
var _ledger_pages: Array[Dictionary] = []
var _current_ledger_page: int = 0
var _ledger_page_animating: bool = false


func _ready() -> void:
	_ensure_spawn_points()
	MusicController.play_track(MusicController.MusicTrack.FOREST_HUB)
	_connect_signals()
	_setup_room_code_label()
	_setup_pause_panel()
	_spawn_local_player()
	_setup_ui_controls()
	_setup_forest_ledger_navigation()
	_refresh_forest_ledger_pages()
	_connect_portal_signals()
	_setup_zone_completion_indicators()
	_refresh_briefcase_display()
	_animate_location_diamond()

	if briefcase_panel:
		briefcase_panel.visible = false
		briefcase_panel.scale = BRIEFCASE_CLOSED_SCALE

	if dialogue_panel:
		dialogue_panel.visible = false

	for peer_id in multiplayer.get_peers():
		if peer_id != multiplayer.get_unique_id() and not _spawned_players.has(peer_id):
			_spawn_player_for_peer(peer_id)
	if multiplayer.is_server():
		await get_tree().process_frame
		var host_pos := GameState.get_spawn_position(1)
		for peer_id in multiplayer.get_peers():
			if peer_id != multiplayer.get_unique_id():
				_rpc_spawn_player_with_pos.rpc_id(peer_id, 1, true, host_pos)
				var peer_pos := GameState.get_spawn_position(peer_id)
				for other_peer in multiplayer.get_peers():
					if other_peer != peer_id and other_peer != multiplayer.get_unique_id():
						_rpc_spawn_player_with_pos.rpc_id(other_peer, peer_id, false, peer_pos)

	await get_tree().process_frame
	_run_forest_dialogue()


func _exit_tree() -> void:
	var signal_pairs := [
		[NetworkManager.player_connected, _on_player_connected],
		[NetworkManager.player_disconnected, _on_player_disconnected],
		[NetworkManager.partner_disconnected, _on_partner_disconnected],
		[NetworkManager.spawn_player_requested, _on_spawn_player_requested],
		[NetworkManager.despawn_player_requested, _on_despawn_player_requested],
		[NetworkManager.rejoin_game_requested, _on_rejoin_game_requested],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)


func _connect_signals() -> void:
	var signal_pairs := [
		[NetworkManager.player_connected, _on_player_connected],
		[NetworkManager.player_disconnected, _on_player_disconnected],
		[NetworkManager.partner_disconnected, _on_partner_disconnected],
		[NetworkManager.spawn_player_requested, _on_spawn_player_requested],
		[NetworkManager.despawn_player_requested, _on_despawn_player_requested],
		[NetworkManager.rejoin_game_requested, _on_rejoin_game_requested],
	]
	for pair in signal_pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if not sig.is_connected(cb):
			sig.connect(cb)
	if not GameState.zone_completed.is_connected(_on_zone_completed):
		GameState.zone_completed.connect(_on_zone_completed)
	if not GameState.briefcase_updated.is_connected(_on_briefcase_updated):
		GameState.briefcase_updated.connect(_on_briefcase_updated)
	if touch_controls:
		if touch_controls.has_signal("pause_pressed") and not touch_controls.pause_pressed.is_connected(_on_pause_button_pressed):
			touch_controls.pause_pressed.connect(_on_pause_button_pressed)


func _ensure_spawn_points() -> void:
	if spawn_points:
		return
	push_error("[ForestHub] SpawnPoints node not found — creating fallback.")
	spawn_points = Node2D.new()
	spawn_points.name = "SpawnPoints"
	add_child(spawn_points)
	for cfg in [["DetectiveSpawn", Vector2(400, ground_y)], ["SidekickSpawn", Vector2(600, ground_y)]]:
		var m := Marker2D.new()
		m.name = cfg[0]
		m.position = cfg[1]
		spawn_points.add_child(m)


func _setup_room_code_label() -> void:
	if not room_code_label:
		return
	if multiplayer.is_server():
		var code := NetworkManager.get_invite_code()
		room_code_label.text = "Code: " + (code if not code.is_empty() else "N/A")
		room_code_label.visible = true
	else:
		room_code_label.visible = false


func _setup_pause_panel() -> void:
	if not in_game_pause_panel:
		push_error("[ForestHub] InGamePausePanel not found!")
		return
	in_game_pause_panel.visible = false
	_sync_volume_ui()
	if volume_slider and not volume_slider.value_changed.is_connected(_on_in_game_volume_changed):
		volume_slider.value_changed.connect(_on_in_game_volume_changed)


func _sync_volume_ui() -> void:
	if volume_slider:
		volume_slider.value = MusicController.get_volume() * 100
	if volume_value_label:
		volume_value_label.text = str(int(MusicController.get_volume() * 100)) + "%"


func _on_pause_button_pressed() -> void:
	if not in_game_pause_panel:
		push_error("[ForestHub] Cannot open pause — in_game_pause_panel is null!")
		return
	in_game_pause_panel.visible = true
	if option_sub_panel:
		option_sub_panel.visible = false
	get_tree().paused = true
	MusicController.pause_music()


func _on_resume_play_button_pressed() -> void:
	if in_game_pause_panel:
		in_game_pause_panel.visible = false
	if option_sub_panel:
		option_sub_panel.visible = false
	MusicController.resume_music()
	get_tree().paused = false


func _on_option_button_pressed() -> void:
	if not option_sub_panel:
		push_error("[ForestHub] Cannot open options — option_sub_panel is null!")
		return
	option_sub_panel.visible = true
	_sync_volume_ui()


func _on_in_game_option_back_pressed() -> void:
	if option_sub_panel and option_sub_panel.visible:
		option_sub_panel.visible = false


func _on_exit_to_main_menu_button_pressed() -> void:
	get_tree().paused = false
	if NetworkManager.has_active_connection():
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.2).timeout
	_save_settings()
	if is_inside_tree():
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _on_in_game_volume_changed(value: float) -> void:
	MusicController.set_volume(value / 100.0)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"
	_save_settings()


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"volume": MusicController.get_volume()}))
		file.close()


func _on_spawn_player_requested(peer_id: int, is_detective: bool) -> void:
	var saved_pos := GameState.get_spawn_position(peer_id)
	_rpc_spawn_player(peer_id, is_detective, saved_pos)


func _on_despawn_player_requested(peer_id: int) -> void:
	_rpc_despawn_player(peer_id)


func _spawn_local_player() -> void:
	_spawn_player_for_peer(multiplayer.get_unique_id())


func _instantiate_player(is_detective: bool) -> CharacterBody2D:
	var player: CharacterBody2D
	if is_detective:
		player = player_host_scene.instantiate()
		player.role = "Detective"
		player.avatar_scale = detective_scale
	else:
		player = player_sidekick_scene.instantiate()
		player.role = "Sidekick"
		player.avatar_scale = sidekick_scale
	return player


func _resolve_spawn_position(peer_id: int, is_detective: bool, forced_pos: Vector2 = Vector2.ZERO) -> Vector2:
	if forced_pos != Vector2.ZERO:
		return forced_pos
	var saved_pos := GameState.get_spawn_position(peer_id)
	if saved_pos != Vector2.ZERO:
		return saved_pos
	var marker_name := "DetectiveSpawn" if is_detective else "SidekickSpawn"
	var marker := spawn_points.get_node_or_null(marker_name) as Marker2D
	if marker:
		return marker.global_position
	var default_pos := Vector2(200 if is_detective else 600, ground_y)
	push_warning("[ForestHub] Spawn marker not found for %s, using default: %s" % [
		"Detective" if is_detective else "Sidekick", str(default_pos)
	])
	return default_pos


func _finalize_spawn(player: CharacterBody2D, peer_id: int, spawn_pos: Vector2) -> void:
	player.global_position = spawn_pos
	if NetworkManager.has_method("clear_partner_state"):
		NetworkManager.clear_partner_state(peer_id)
	_stabilize_player_physics(player)
	player.set_multiplayer_authority(peer_id)
	_force_visibility_recursive(player)
	_spawned_players[peer_id] = player
	add_child(player, true)
	_call_stabilize_after_frame(player)
	if peer_id == multiplayer.get_unique_id():
		await get_tree().process_frame
		if is_instance_valid(player) and player.has_method("_force_initial_sync"):
			player._force_initial_sync()
			if multiplayer.is_server():
				_sync_player_position_to_all.rpc(peer_id, spawn_pos)
	_call_deferred_visibility_check(player)


func _spawn_player_for_peer(peer_id: int) -> void:
	if _spawned_players.has(peer_id):
		return
	var is_detective := (peer_id == 1)
	var spawn_pos := _resolve_spawn_position(peer_id, is_detective)
	var player := _instantiate_player(is_detective)
	player.name = str(peer_id)
	await _finalize_spawn(player, peer_id, spawn_pos)
	if peer_id == multiplayer.get_unique_id():
		GameState.clear_spawn_position(peer_id)


func _on_player_connected(peer_id: int, _role: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var existing := get_node_or_null(str(peer_id))
	if existing:
		existing.queue_free()
		_spawned_players.erase(peer_id)
	for child in get_children():
		if child is CharacterBody2D:
			var cid := int(child.name)
			if cid > 1 and cid != peer_id and not multiplayer.get_peers().has(cid):
				child.queue_free()
	if not _spawned_players.has(peer_id):
		_spawn_player_for_peer(peer_id)
		_ensure_player_visible(peer_id)
	var host_pos := GameState.get_spawn_position(1)
	_rpc_spawn_player_with_pos.rpc_id(peer_id, 1, true, host_pos)
	for other_peer in multiplayer.get_peers():
		if other_peer != peer_id:
			var new_pos := GameState.get_spawn_position(peer_id)
			_rpc_spawn_player_with_pos.rpc_id(other_peer, peer_id, false, new_pos)
			_ensure_player_visible_on_peer.rpc_id(other_peer, peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	var player_node := get_node_or_null(str(peer_id)) as Node
	if player_node:
		player_node.queue_free()
	_spawned_players.erase(peer_id)
	if multiplayer.is_server():
		NetworkManager.request_despawn_player(peer_id)
		_cleanup_orphaned_players()


func _on_partner_disconnected(reason: String) -> void:
	var my_role := NetworkManager.get_my_role()
	if reason == "host_disconnected" or (not NetworkManager.has_active_connection() and my_role != "detective"):
		get_tree().paused = false
		NetworkManager.disconnect_network()
		await get_tree().create_timer(0.5).timeout
		if is_inside_tree():
			get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _cleanup_orphaned_players() -> void:
	var connected_peers := multiplayer.get_peers()
	for child in get_children():
		if child is CharacterBody2D:
			var pid := int(child.name)
			if pid > 0 and not _spawned_players.has(pid) and not connected_peers.has(pid):
				child.queue_free()


func _rpc_spawn_player(peer_id: int, is_detective_role: bool, forced_pos: Vector2 = Vector2.ZERO) -> void:
	if _spawned_players.has(peer_id) or peer_id == multiplayer.get_unique_id():
		return
	var existing := get_node_or_null(str(peer_id))
	if existing:
		existing.queue_free()
	var spawn_pos := _resolve_spawn_position(peer_id, is_detective_role, forced_pos)
	var player := _instantiate_player(is_detective_role)
	player.name = str(peer_id)
	await _finalize_spawn(player, peer_id, spawn_pos)


func _stabilize_player_physics(player: CharacterBody2D) -> void:
	player.velocity = Vector2.ZERO
	player.set_meta("_needs_grounding", true)


func _call_stabilize_after_frame(player: CharacterBody2D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(player):
		return
	player.velocity = Vector2.ZERO
	if player.has_method("_force_grounded"):
		player._force_grounded()
	await get_tree().physics_frame
	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		if player.has_method("_force_grounded"):
			player._force_grounded()


func _force_visibility_recursive(node: Node) -> void:
	if node is CanvasItem:
		node.visible = true
		if node is AnimatedSprite2D:
			node.play("idle")
	for child in node.get_children():
		_force_visibility_recursive(child)


func _call_deferred_visibility_check(player: CharacterBody2D) -> void:
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(player):
		_force_visibility_recursive(player)


func _ensure_player_visible(peer_id: int) -> void:
	var player_node := get_node_or_null(str(peer_id))
	if player_node:
		_force_visibility_recursive(player_node)


@rpc("authority", "reliable")
func _ensure_player_visible_on_peer(peer_id: int) -> void:
	var player_node := get_node_or_null(str(peer_id))
	if player_node:
		_force_visibility_recursive(player_node)


func _rpc_despawn_player(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	var player_node := get_node_or_null(str(peer_id)) as Node
	if player_node:
		player_node.queue_free()
	_spawned_players.erase(peer_id)


func _on_rejoin_game_requested(rejoin_data: Dictionary) -> void:
	var player_positions: Dictionary = rejoin_data.get("player_positions", {})
	var detective_node := get_node_or_null("1")
	if detective_node and str(detective_node.name) == "1":
		var host_pos_data: Variant = player_positions.get("1", {})
		if host_pos_data is Dictionary and host_pos_data.has("position"):
			detective_node.global_position = Vector2(host_pos_data.position.x, host_pos_data.position.y)
	for peer_id_str in player_positions:
		var pid := int(peer_id_str)
		if pid != multiplayer.get_unique_id() and not _spawned_players.has(pid):
			var pos_data: Variant = player_positions.get(peer_id_str, {})
			var spawn_pos := Vector2.ZERO
			if pos_data is Dictionary and pos_data.has("position"):
				spawn_pos = Vector2(pos_data.position.x, pos_data.position.y)
			_rpc_spawn_player(pid, pid == 1, spawn_pos)
			_ensure_player_visible(pid)


@rpc("authority", "reliable", "call_local")
func _rpc_spawn_player_with_pos(peer_id: int, is_detective: bool, pos: Vector2) -> void:
	_rpc_spawn_player(peer_id, is_detective, pos)


@rpc("authority", "reliable", "call_local")
func _sync_player_position_to_all(peer_id: int, pos: Vector2) -> void:
	if multiplayer.is_server() and NetworkManager.has_method("_store_position"):
		NetworkManager._store_position(peer_id, pos)
	var player_node := get_node_or_null(str(peer_id))
	if is_instance_valid(player_node):
		player_node.global_position = pos
		player_node.velocity = Vector2.ZERO


func _setup_ui_controls() -> void:
	var is_sidekick := (NetworkManager.get_my_role() != "detective")

	if not touch_controls:
		push_error("[ForestHub] TouchControls not found")
		return

	var map_btn: TouchScreenButton = touch_controls.get_node_or_null("Map")
	if map_btn:
		map_btn.visible = true
		if not map_btn.pressed.is_connected(_on_map_button_pressed):
			map_btn.pressed.connect(_on_map_button_pressed)

	var ledger_btn: TouchScreenButton = touch_controls.get_node_or_null("Ledger")
	if ledger_btn:
		ledger_btn.visible = is_sidekick
		if not ledger_btn.pressed.is_connected(_on_ledger_button_pressed):
			ledger_btn.pressed.connect(_on_ledger_button_pressed)

	var briefcase_btn: TouchScreenButton = touch_controls.get_node_or_null("Briefcase")
	if briefcase_btn:
		briefcase_btn.visible = is_sidekick
		if not briefcase_btn.pressed.is_connected(_on_briefcase_button_pressed):
			briefcase_btn.pressed.connect(_on_briefcase_button_pressed)
	else:
		push_error("[ForestHub] Briefcase button not found inside TouchControls")

	var find_partner_btn = touch_controls.get_node_or_null("FindPartner")
	if find_partner_btn:
		find_partner_btn.text = "Find Partner"
		find_partner_btn.visible = true
		if not find_partner_btn.pressed.is_connected(_on_find_partner_pressed):
			find_partner_btn.pressed.connect(_on_find_partner_pressed)

# Hide jump button in forest hub
	var jump_btn = touch_controls.get_node_or_null("Jump")  # adjust name if different
	if jump_btn:
		jump_btn.visible = false

	_close_all_panels(false)


func _toggle_panel(panel_name: String) -> void:
	if _is_animating:
		return
	if _current_open_panel == panel_name:
		_close_all_panels()
	else:
		_close_all_panels(false)
		_open_panel(panel_name)


func _on_map_button_pressed() -> void:
	_toggle_panel("map")

func _on_ledger_button_pressed() -> void:
	_toggle_panel("ledger")

func _on_briefcase_button_pressed() -> void:
	print("[ForestHub] Briefcase button pressed")
	_toggle_panel("briefcase")


func _open_panel(panel_name: String) -> void:
	match panel_name:
		"map": _open_map()
		"ledger": _open_ledger()
		"briefcase": _open_briefcase()
	_current_open_panel = panel_name


func _close_all_panels(animate: bool = true) -> void:
	_close_map(animate)
	_close_ledger(animate)
	_close_briefcase(animate)
	_current_open_panel = ""


func _open_map() -> void:
	if not map_panel:
		return
	map_panel.visible = true
	map_panel.modulate = Color(1, 1, 1, 0)
	map_panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(map_panel, "modulate", Color(1, 1, 1, 1), PANEL_ANIMATION_DURATION)
	tween.parallel().tween_property(map_panel, "scale", Vector2.ONE, PANEL_ANIMATION_DURATION)


func _close_map(animate: bool = true) -> void:
	if not map_panel or not map_panel.visible:
		return
	if animate:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(map_panel, "modulate", Color(1, 1, 1, 0), PANEL_ANIMATION_DURATION * 0.5)
		tween.parallel().tween_property(map_panel, "scale", Vector2(0.8, 0.8), PANEL_ANIMATION_DURATION * 0.5)
		tween.tween_callback(func(): map_panel.visible = false)
	else:
		map_panel.visible = false


func _open_ledger() -> void:
	if not ledger_panel:
		return
	_refresh_forest_ledger_pages()
	_show_forest_ledger_page(_current_ledger_page, false)
	_is_animating = true
	ledger_panel.visible = true
	ledger_panel.scale = LEDGER_CLOSED_SCALE
	ledger_panel.pivot_offset = ledger_panel.size / 2
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ledger_panel, "scale", LEDGER_OPEN_SCALE, PANEL_ANIMATION_DURATION)
	tween.tween_callback(func(): _is_animating = false)


func _close_ledger(animate: bool = true) -> void:
	if not ledger_panel or not ledger_panel.visible:
		return
	if animate:
		_is_animating = true
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(ledger_panel, "scale", LEDGER_CLOSED_SCALE, PANEL_ANIMATION_DURATION * 0.5)
		tween.tween_callback(func():
			ledger_panel.visible = false
			_is_animating = false)
	else:
		ledger_panel.visible = false
		ledger_panel.scale = LEDGER_CLOSED_SCALE


func _setup_forest_ledger_navigation() -> void:
	if is_instance_valid(forest_prev_page_button) and not forest_prev_page_button.pressed.is_connected(_on_forest_prev_page_pressed):
		forest_prev_page_button.pressed.connect(_on_forest_prev_page_pressed)
	if is_instance_valid(forest_next_page_button) and not forest_next_page_button.pressed.is_connected(_on_forest_next_page_pressed):
		forest_next_page_button.pressed.connect(_on_forest_next_page_pressed)


func _refresh_forest_ledger_pages() -> void:
	_ledger_pages.clear()
	var entries: Array = PuzzleManager.get_unlocked_global_ledger_entries()
	if entries.is_empty():
		_ledger_pages.append({
			"title": "Ledger", "left_header": "Notes",
			"left_body": LEDGER_EMPTY_TEXT, "right_header": "", "right_body": "",
		})
	else:
		for entry in entries:
			_ledger_pages.append(_convert_entry_to_book_page(entry))
	_current_ledger_page = clamp(_current_ledger_page, 0, max(_ledger_pages.size() - 1, 0))


func _convert_entry_to_book_page(entry: Dictionary) -> Dictionary:
	var layout: String = str(entry.get("layout", "single_body"))
	if layout == "two_column":
		return {
			"title": str(entry.get("zone_name", entry.get("title", "Ledger"))),
			"left_header": str(entry.get("left_header", "")),
			"left_body": str(entry.get("left_body", "")),
			"right_header": str(entry.get("right_header", "")),
			"right_body": str(entry.get("right_body", "")),
		}
	var body_text := str(entry.get("body", ""))
	var split_pages := _split_body_into_book_pages(body_text)
	return {
		"title": str(entry.get("zone_name", entry.get("title", "Ledger"))),
		"left_header": str(entry.get("title", "Notes")),
		"left_body": str(split_pages.get("left", "")),
		"right_header": "Example" if str(split_pages.get("right", "")) != "" else "",
		"right_body": str(split_pages.get("right", "")),
	}


func _split_body_into_book_pages(body_text: String) -> Dictionary:
	var sections := body_text.split("\n\n", false)
	if sections.size() <= 1:
		return {"left": body_text, "right": ""}
	var midpoint := int(ceil(float(sections.size()) / 2.0))
	var left_parts: Array[String] = []
	var right_parts: Array[String] = []
	for i in range(sections.size()):
		if i < midpoint:
			left_parts.append(sections[i])
		else:
			right_parts.append(sections[i])
	return {"left": "\n\n".join(left_parts), "right": "\n\n".join(right_parts)}


func _show_forest_ledger_page(page_index: int, animate: bool = true) -> void:
	if _ledger_pages.is_empty():
		return
	page_index = clamp(page_index, 0, _ledger_pages.size() - 1)
	if animate and _ledger_page_animating:
		return
	if not animate:
		_current_ledger_page = page_index
		_apply_forest_ledger_page(_ledger_pages[_current_ledger_page])
		_update_forest_ledger_navigation()
		if is_instance_valid(forest_ledger_control):
			forest_ledger_control.scale = Vector2.ONE
		return
	_ledger_page_animating = true
	_current_ledger_page = page_index
	if is_instance_valid(forest_ledger_control):
		forest_ledger_control.pivot_offset = forest_ledger_control.size / 2
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(forest_ledger_control):
		tween.tween_property(forest_ledger_control, "scale", Vector2(0.05, 1.0), LEDGER_PAGE_TURN_DURATION)
	tween.tween_callback(func():
		_apply_forest_ledger_page(_ledger_pages[_current_ledger_page])
		_update_forest_ledger_navigation())
	if is_instance_valid(forest_ledger_control):
		tween.tween_property(forest_ledger_control, "scale", Vector2.ONE, LEDGER_PAGE_TURN_DURATION)
	tween.tween_callback(func(): _ledger_page_animating = false)


func _apply_forest_ledger_page(page_data: Dictionary) -> void:
	if is_instance_valid(forest_ledger_title_label):
		forest_ledger_title_label.text = str(page_data.get("title", ""))
	if is_instance_valid(forest_ledger_left_header_label):
		forest_ledger_left_header_label.text = str(page_data.get("left_header", ""))
	if is_instance_valid(forest_ledger_left_body_label):
		forest_ledger_left_body_label.text = str(page_data.get("left_body", ""))
	if is_instance_valid(forest_ledger_right_header_label):
		forest_ledger_right_header_label.text = str(page_data.get("right_header", ""))
	if is_instance_valid(forest_ledger_right_body_label):
		forest_ledger_right_body_label.text = str(page_data.get("right_body", ""))


func _update_forest_ledger_navigation() -> void:
	var total_pages := _ledger_pages.size()
	if is_instance_valid(forest_page_indicator_label):
		forest_page_indicator_label.text = str(_current_ledger_page + 1) + " / " + str(max(total_pages, 1))
	if is_instance_valid(forest_prev_page_button):
		forest_prev_page_button.visible = total_pages > 1
		forest_prev_page_button.disabled = _current_ledger_page <= 0
	if is_instance_valid(forest_next_page_button):
		forest_next_page_button.visible = total_pages > 1
		forest_next_page_button.disabled = _current_ledger_page >= total_pages - 1


func _on_forest_prev_page_pressed() -> void:
	if not _ledger_page_animating and _current_ledger_page > 0:
		_show_forest_ledger_page(_current_ledger_page - 1, true)


func _on_forest_next_page_pressed() -> void:
	if not _ledger_page_animating and _current_ledger_page < _ledger_pages.size() - 1:
		_show_forest_ledger_page(_current_ledger_page + 1, true)


func _open_briefcase() -> void:
	if not briefcase_panel:
		push_error("[ForestHub] briefcase_panel is null")
		return
	_refresh_briefcase_display()
	_is_animating = true
	briefcase_panel.visible = true
	briefcase_panel.modulate = Color(1, 1, 1, 1)
	briefcase_panel.scale = BRIEFCASE_CLOSED_SCALE
	briefcase_panel.pivot_offset = Vector2(briefcase_panel.size.x / 2, 0)
	print("[ForestHub] Opening briefcase panel")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(briefcase_panel, "scale", BRIEFCASE_OPEN_SCALE, PANEL_ANIMATION_DURATION)
	tween.tween_callback(func(): _is_animating = false)


func _close_briefcase(animate: bool = true) -> void:
	if not briefcase_panel or not briefcase_panel.visible:
		return
	if animate:
		_is_animating = true
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(briefcase_panel, "scale", BRIEFCASE_CLOSED_SCALE, PANEL_ANIMATION_DURATION * 0.5)
		tween.tween_callback(func():
			briefcase_panel.visible = false
			_is_animating = false)
	else:
		briefcase_panel.visible = false
		briefcase_panel.scale = BRIEFCASE_CLOSED_SCALE


func _on_briefcase_updated() -> void:
	_refresh_briefcase_display()


func _refresh_briefcase_display() -> void:
	if not is_instance_valid(briefcase_display):
		push_error("[ForestHub] briefcase_display is invalid")
		return
	var path := GameState.get_briefcase_texture_path("forest")
	print("[ForestHub] Forest briefcase path: ", path)
	var texture: Texture2D = GameState.get_briefcase_texture("forest")
	if texture == null:
		push_warning("[ForestHub] Forest briefcase texture is null for path: " + path)
		briefcase_display.visible = false
		return
	briefcase_display.texture = texture
	briefcase_display.visible = true


func _connect_portal_signals() -> void:
	if not portals:
		return
	await get_tree().process_frame
	for portal in portals.get_children():
		if portal.has_signal("players_entering") and not portal.players_entering.is_connected(_on_players_entering_zone):
			portal.players_entering.connect(_on_players_entering_zone)
		if portal.has_signal("players_entered") and not portal.players_entered.is_connected(_on_players_entered_zone):
			portal.players_entered.connect(_on_players_entered_zone)


func _on_players_entering_zone(zone_name: String) -> void:
	if zone_name == "pinas_house":
		_animate_pinas_house_door()


func _on_players_entered_zone(zone_name: String) -> void:
	var target_portal: Node = null
	for portal in portals.get_children():
		if portal.zone_name == zone_name:
			target_portal = portal
			break
	if not target_portal:
		push_warning("[ForestHub] Could not find portal for zone: " + zone_name)
		return
	target_portal.complete_zone_entry()


func _animate_pinas_house_door() -> void:
	if not pinas_house_door:
		push_warning("[ForestHub] Pina's house door sprite not found!")
		return
	pinas_house_door.visible = true
	pinas_house_door.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(pinas_house_door, "modulate:a", 1.0, 0.5)
	if not tree_exiting.is_connected(_on_tree_exiting_hide_door):
		tree_exiting.connect(_on_tree_exiting_hide_door)


func _on_tree_exiting_hide_door() -> void:
	if pinas_house_door:
		pinas_house_door.visible = false


func _setup_zone_completion_indicators() -> void:
	if not finish_zone_indicator:
		push_warning("[ForestHub] FinishZoneIndicator node not found!")
		return
	for portal in portals.get_children():
		var zone_name: String = portal.zone_name
		if finish_zone_indicator.has_method("set_portal_position"):
			finish_zone_indicator.set_portal_position(zone_name, portal.global_position)
		var enter_button := portal.get_node_or_null("EnterButton")
		var is_completed: bool = GameState.zones_status.get(zone_name, GameState.ZoneStatus.AVAILABLE) == GameState.ZoneStatus.COMPLETED
		if is_completed:
			if finish_zone_indicator.has_method("show_indicator"):
				finish_zone_indicator.show_indicator(zone_name)
			if enter_button:
				enter_button.visible = false
				enter_button.disabled = true
		else:
			if finish_zone_indicator.has_method("hide_indicator"):
				finish_zone_indicator.hide_indicator(zone_name)


func _on_zone_completed(completed_zone: String) -> void:
	for portal in portals.get_children():
		if portal.zone_name != completed_zone:
			continue
		if finish_zone_indicator.has_method("set_portal_position"):
			finish_zone_indicator.set_portal_position(completed_zone, portal.global_position)
		if finish_zone_indicator.has_method("show_indicator"):
			finish_zone_indicator.show_indicator(completed_zone)
		var enter_button := portal.get_node_or_null("EnterButton")
		if enter_button:
			enter_button.visible = false
			enter_button.disabled = true
		break


# ─── DIALOGUE ────────────────────────────────────────────────────────────────

func _run_forest_dialogue() -> void:
	# FOREST_PLAYERS_SPAWN
	await _say_auto("Sidekick", "Whoa. Okay. That was... not a normal elevator ride.", 1.0)
	await _say_auto("Sidekick", "One second we're looking at Grandma's fading book,", 1.0)
	await _say_auto("Sidekick", "and the next we're here.", 1.0)
	await _say_auto("Detective", "Stay sharp, partner. We aren't just in a forest.", 1.0)
	await _say_auto("Detective", "We've been pulled into the book.", 1.0)
	await _say_auto("Detective", "And if Grandma was right, the story is actively dying around us.", 1.0)
	await _say_auto("Sidekick", "It feels empty. Like life has been sucked out of it.", 1.0)

	# FOREST_PLAYERS_WALK
	await _say_auto("Sidekick", "So, what's the plan? We just walk around until we find her?", 1.0)
	await _say_auto("aDetective", "No. We look for the evidence. The story is fragmented.", 1.0)
	await _say_auto("Detective", "To understand the truth, we need to find five specific things scattered across this forest.", 1.0)
	await _say_auto("Sidekick", "Five things? Like clues?", 1.0)
	await _say_auto("Detective", "Artifacts. A Tiara. A Ladle. A Scroll. A Pineapple. And... an Eye.", 1.0)
	await _say_auto("Sidekick", "An eye? That's creepy. And a pineapple?", 1.0)
	await _say_auto("Sidekick", "What does fruit have to do with a missing girl?", 1.0)
	await _say_auto("Detective", "That's the question, isn't it? The old legend mentions a mother's frustration.", 1.0)
	await _say_auto("Sidekick", "Grandma mentioned that. Something about 'a thousand eyes'?", 1.0)
	await _say("Detective", "Exactly. 'I wish you would grow a thousand eyes so you could find what you're looking for.'")
	await _say("Detective", "We need to find out if that was just a figure of speech... or if it's the key to everything.")
	_clear_dialogue()


func _say(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	dialogue_label.text = ""
	dialogue_panel.modulate.a = 1.0
	dialogue_panel.visible = true
	var char_index: int = 0
	var elapsed: float = 0.0
	var length: int = text.length()
	while char_index <= length:
		elapsed += get_process_delta_time()
		if elapsed >= DIALOGUE_SPEED:
			elapsed -= DIALOGUE_SPEED
			char_index += 1
			dialogue_label.text = text.substr(0, char_index)
		await get_tree().process_frame
	dialogue_panel.visible = false


func _say_auto(speaker: String, text: String, hold: float) -> void:
	speaker_label.text = speaker
	dialogue_label.text = ""
	dialogue_panel.modulate.a = 1.0
	dialogue_panel.visible = true
	var char_index: int = 0
	var elapsed: float = 0.0
	var length: int = text.length()
	while char_index <= length:
		elapsed += get_process_delta_time()
		if elapsed >= DIALOGUE_SPEED:
			elapsed -= DIALOGUE_SPEED
			char_index += 1
			dialogue_label.text = text.substr(0, char_index)
		await get_tree().process_frame
	await _wait(hold)


func _wait(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		elapsed += get_process_delta_time()
		await get_tree().process_frame


func _clear_dialogue() -> void:
	dialogue_label.text = ""
	speaker_label.text = ""
	dialogue_panel.visible = false

func _on_find_partner_pressed() -> void:
	if _is_finding_partner:
		return

	var my_id := multiplayer.get_unique_id()
	var partner_id: int = -1

	for peer_id in _spawned_players.keys():
		if peer_id != my_id:
			partner_id = peer_id
			break

	if partner_id == -1:
		push_warning("[ForestHub] No partner found to locate.")
		return

	var partner_pos: Vector2
	var state := NetworkManager.get_partner_state(partner_id)

	if not state.is_empty() and state.has("position"):
		partner_pos = state.get("position", Vector2.ZERO)
	else:
		var partner_node := get_node_or_null(str(partner_id)) as CharacterBody2D
		if not is_instance_valid(partner_node):
			push_warning("[ForestHub] Partner state and node both unavailable.")
			return
		partner_pos = partner_node.global_position

	_slide_camera_to_partner(partner_pos)


func _slide_camera_to_partner(target_pos: Vector2) -> void:
	var my_id := multiplayer.get_unique_id()
	var my_player := get_node_or_null(str(my_id)) as CharacterBody2D
	if not is_instance_valid(my_player):
		push_warning("[ForestHub] Local player node not found.")
		return

	var cam := my_player.get_node_or_null("Camera2D") as Camera2D
	if not cam:
		push_warning("[ForestHub] Camera2D not found on local player.")
		return

	# Prevent double trigger
	_is_finding_partner = true

	# Detach camera so we can move it freely
	cam.set_as_top_level(true)
	cam.global_position = my_player.global_position  # anchor it here immediately after detach

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Slide to partner
	tween.tween_property(cam, "global_position", target_pos, FIND_PARTNER_DURATION)

	# Hold
	tween.tween_interval(FIND_PARTNER_HOLD)

	# Slide back to player's CURRENT position (not stale start_pos)
	tween.tween_method(func(_t: float):
		if is_instance_valid(cam) and is_instance_valid(my_player):
			cam.global_position = cam.global_position.lerp(my_player.global_position, 0.15)
	, 0.0, 1.0, FIND_PARTNER_DURATION)

	# Reattach
	tween.tween_callback(func():
		if not is_instance_valid(cam) or not is_instance_valid(my_player):
			_is_finding_partner = false
			return
		cam.set_as_top_level(false)
		cam.position = Vector2.ZERO
		_is_finding_partner = false
	)

func _animate_location_diamond() -> void:
	var diamond := get_node_or_null("LocationDiamond")
	if not diamond:
		return
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(diamond, "modulate:a", 0.4, 0.8)
	tween.tween_property(diamond, "modulate:a", 1.0, 0.8)
