extends Node2D

## Forest Hub - Main world scene with zone portals and player spawning.

# ─── PRELOADS ────────────────────────────────────────────────────────────────

@onready var player_host_scene: PackedScene = preload("res://scenes/players/PlayerHost.tscn")
@onready var player_sidekick_scene: PackedScene = preload("res://scenes/players/PlayerSidekick.tscn")

# ─── EXPORTS ─────────────────────────────────────────────────────────────────

@export var detective_scale: Vector2 = Vector2(0.2, 0.2)
@export var sidekick_scale: Vector2 = Vector2(0.2, 0.2)
@export var ground_y: float = 750.0

# ─── NODE REFERENCES ─────────────────────────────────────────────────────────

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
@onready var map_panel: Sprite2D = $MapLayer/Map
@onready var map_ph_marker: Sprite2D = $MapLayer/MapPH
@onready var map_ow_marker: Sprite2D = $MapLayer/MapOW
@onready var map_bp_marker: Sprite2D = $MapLayer/MapBP
@onready var map_sh_marker: Sprite2D = $MapLayer/MapSH
@onready var map_ah_marker: Sprite2D = $MapLayer/MapAH
@onready var art_ladle_marker: Sprite2D = $MapLayer/ArtLadle
@onready var art_eye_marker: Sprite2D = $MapLayer/ArtEye
@onready var art_pineapple_marker: Sprite2D = $MapLayer/ArtPineapple
@onready var art_scroll_marker: Sprite2D = $MapLayer/ArtScroll
@onready var art_tiara_marker: Sprite2D = $MapLayer/ArtTiara

@onready var portals: Node2D = $"Zone Portals"
@onready var pinas_house_door: Sprite2D = $"Zone Portals/PortalPinasHouse/PinasHouseDoorOpen"
@onready var storage_hut_door: Sprite2D = $"Zone Portals/StorageHut/StorageHutDoorOpen"
@onready var abandoned_house_door: Sprite2D = $"Zone Portals/AbandonedHouse/AbandonedHouseDoorOpen"

@onready var clue_ladle: Sprite2D = $SidekickLayer/Briefcase/BriefcaseDisplay/ClueLadle
@onready var clue_pineapple: Sprite2D = $SidekickLayer/Briefcase/BriefcaseDisplay/CluePineapple
@onready var clue_eyes: Sprite2D = $SidekickLayer/Briefcase/BriefcaseDisplay/ClueEyes
@onready var clue_tiara: Sprite2D = $SidekickLayer/Briefcase/BriefcaseDisplay/ClueTiara
@onready var clue_scroll: Sprite2D = $SidekickLayer/Briefcase/BriefcaseDisplay/ClueScroll

@onready var objective_label_1: Label = $MapLayer/Quest/Objective/ObjectiveLabel1
@onready var objective_label_2: Label = $MapLayer/Quest/Objective/ObjectiveLabel2
@onready var objective_label_3: Label = $MapLayer/Quest/Objective/ObjectiveLabel3
@onready var objective_label_4: Label = $MapLayer/Quest/Objective/ObjectiveLabel4
@onready var objective_label_5: Label = $MapLayer/Quest/Objective/ObjectiveLabel5

# ─── CONSTANTS ───────────────────────────────────────────────────────────────

const PANEL_ANIMATION_DURATION: float = 0.4
const DIALOGUE_SPEED: float = 0.04
const LEDGER_PAGE_TURN_DURATION: float = 0.16
const DOOR_ANIMATION_DURATION: float = 0.5
const FIND_PARTNER_DURATION: float = 1.2
const FIND_PARTNER_HOLD: float = 2.0
const ZONE_THOUGHT_HOLD: float = 2.0

const LEDGER_EMPTY_TEXT := "Solve a zone puzzle to unlock \nledger notes in the forest."
const LEDGER_OPEN_SCALE: Vector2 = Vector2(1.0, 1.0)
const LEDGER_CLOSED_SCALE: Vector2 = Vector2(0.1, 1.0)
const BRIEFCASE_OPEN_SCALE: Vector2 = Vector2(1.0, 1.0)
const BRIEFCASE_CLOSED_SCALE: Vector2 = Vector2(1.0, 0.1)
const SCENE_MAIN_MENU := "res://scenes/mainMenu/MainMenu.tscn"
const SETTINGS_FILE := "user://settings.json"
const MAP_LAYER_FOCUS_LAYER := 105
const MAP_OVERLAY_ALPHA := 0.72
const MAP_CONTENT_OPEN_SCALE := Vector2(1.0, 1.0)
const MAP_CONTENT_CLOSED_SCALE := Vector2(0.92, 0.92)

## Zone thought lines: zone_name → { true: [speaker, line], false: [speaker, line] }
## true = detective, false = sidekick.
## zone_name must exactly match portal.zone_name in the Inspector.
const ZONE_THOUGHTS: Dictionary = {
	"pinas_house": {
		true:  ["Detective", "Pina's place... Come with me! I sense an artifact inside."],
		false: ["Sidekick",  "Lights are on! I bet there's an artifact. Let's go inside!"]
	},
	"old_well": {
		true:  ["Detective", "The well is deep. An artifact lies below. Let's check it together!"],
		false: ["Sidekick",  "Something's in the well wall! Help me look."]
	},
	"backyard_path": {
		true:  ["Detective", "Tracks lead this way. Come with me!"],
		false: ["Sidekick",  "The path is clear! Let's find that artifact together."]
	},
	"storage_hut": {
		true:  ["Detective", "The hut is unlocked. Let's go inside an artifact awaits."],
		false: ["Sidekick",  "It's small, but I bet there's an artifact inside!"]
	},
	"abandoned_house": {
		true:  ["Detective", "Eerie... but there is an artifact within."],
		false: ["Sidekick",  "Spooky! I'm not going in for that artifact alone."]
	},
}

# ─── STATE ───────────────────────────────────────────────────────────────────

var _spawned_players: Dictionary = {}
var _is_finding_partner: bool = false
var _current_open_panel: String = ""
var _is_animating: bool = false
var _ledger_pages: Array[Dictionary] = []
var _current_ledger_page: int = 0
var _ledger_page_animating: bool = false
var _quest_objective_labels: Dictionary = {}
var _quest_objective_texts: Dictionary = {}
var _map_zone_markers: Dictionary = {}
var _map_artifact_markers: Dictionary = {}
var _map_dim_overlay: ColorRect
var _map_open_tween: Tween
var _map_marker_tweens: Array = []
var _touch_controls_default_layer: int = 101
var _map_focus_controls_active: bool = false

# ─── LIFECYCLE ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_ensure_spawn_points()
	MusicController.play_track(MusicController.MusicTrack.FOREST_HUB)
	_connect_signals()
	_setup_room_code_label()
	_setup_pause_panel()
	_spawn_local_player()
	_setup_ui_controls()
	_setup_map_layer()
	_setup_quest_objectives()
	_setup_forest_ledger_navigation()
	_refresh_forest_ledger_pages()
	_connect_portal_signals()
	_setup_zone_completion_indicators()
	_refresh_briefcase_display()
	_animate_location_diamond()
	_setup_forest_tutorial()

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


func _exit_tree() -> void:
	_disconnect_network_signals()
	_clear_dialogue()

# ─── SIGNAL WIRING ───────────────────────────────────────────────────────────

func _get_network_signal_pairs() -> Array:
	return [
		[NetworkManager.player_connected,         _on_player_connected],
		[NetworkManager.player_disconnected,      _on_player_disconnected],
		[NetworkManager.partner_disconnected,     _on_partner_disconnected],
		[NetworkManager.spawn_player_requested,   _on_spawn_player_requested],
		[NetworkManager.despawn_player_requested, _on_despawn_player_requested],
		[NetworkManager.rejoin_game_requested,    _on_rejoin_game_requested],
	]


func _connect_signals() -> void:
	for pair in _get_network_signal_pairs():
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if not sig.is_connected(cb):
			sig.connect(cb)
	if not GameState.zone_completed.is_connected(_on_zone_completed):
		GameState.zone_completed.connect(_on_zone_completed)
	if not GameState.zone_visited.is_connected(_on_zone_visited):
		GameState.zone_visited.connect(_on_zone_visited)
	if not GameState.briefcase_updated.is_connected(_on_briefcase_updated):
		GameState.briefcase_updated.connect(_on_briefcase_updated)
	if touch_controls and touch_controls.has_signal("pause_pressed"):
		if not touch_controls.pause_pressed.is_connected(_on_pause_button_pressed):
			touch_controls.pause_pressed.connect(_on_pause_button_pressed)


func _disconnect_network_signals() -> void:
	for pair in _get_network_signal_pairs():
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)

# ─── SPAWN POINTS ────────────────────────────────────────────────────────────

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

# ─── ROOM CODE ───────────────────────────────────────────────────────────────

func _setup_room_code_label() -> void:
	if not room_code_label:
		return
	if multiplayer.is_server():
		var code := NetworkManager.get_invite_code()
		room_code_label.text = "Code: " + (code if not code.is_empty() else "N/A")
		room_code_label.visible = true
	else:
		room_code_label.visible = false

# ─── PAUSE ───────────────────────────────────────────────────────────────────

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

# ─── PLAYER SPAWNING ─────────────────────────────────────────────────────────

func _on_spawn_player_requested(peer_id: int, is_detective: bool) -> void:
	_rpc_spawn_player(peer_id, is_detective, GameState.get_spawn_position(peer_id))


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

# ─── UI CONTROLS ─────────────────────────────────────────────────────────────

func _setup_ui_controls() -> void:
	var is_sidekick := (NetworkManager.get_my_role() != "detective")

	if not touch_controls:
		push_error("[ForestHub] TouchControls not found")
		return

	## [node_name, visible, handler] — Callable() means visible-only, no signal
	_touch_controls_default_layer = touch_controls.layer

	var button_configs := [
		["Map",         true,        _on_map_button_pressed],
		["Ledger",      is_sidekick, _on_ledger_button_pressed],
		["Briefcase",   is_sidekick, _on_briefcase_button_pressed],
		["FindPartner", true,        _on_find_partner_pressed],
		["Jump",        false,       Callable()],
	]

	for cfg in button_configs:
		var btn_name: String = cfg[0]
		var btn_visible: bool = cfg[1]
		var handler: Callable = cfg[2]
		var btn = touch_controls.get_node_or_null(btn_name)
		if not btn:
			push_warning("[ForestHub] Button not found in TouchControls: " + btn_name)
			continue
		btn.visible = btn_visible
		if handler.is_valid() and btn.has_signal("pressed") and not btn.pressed.is_connected(handler):
			btn.pressed.connect(handler)

	_close_all_panels(false)

# ─── PANEL MANAGEMENT ────────────────────────────────────────────────────────

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
	_toggle_panel("briefcase")


func _open_panel(panel_name: String) -> void:
	match panel_name:
		"map":       _open_map()
		"ledger":    _open_ledger()
		"briefcase": _open_briefcase()
	_current_open_panel = panel_name


func _close_all_panels(animate: bool = true) -> void:
	_close_map(animate)
	_close_ledger(animate)
	_close_briefcase(animate)
	_current_open_panel = ""


func _open_map() -> void:
	if not map_layer:
		push_error("[ForestHub] Cannot open map — MapLayer is null!")
		return

	_refresh_quest_objectives()
	_refresh_map_progress()
	_stop_map_marker_animations()
	_stop_map_panel_tween()
	_set_touch_controls_map_focus(true)

	map_layer.visible = true
	_is_animating = true

	if is_instance_valid(_map_dim_overlay):
		_map_dim_overlay.color = Color(0, 0, 0, 0.0)

	for visual in _get_map_visual_nodes():
		_cache_map_visual_state(visual)
		visual.modulate.a = 0.0
		_set_map_visual_scale(visual, _get_map_visual_base_scale(visual) * MAP_CONTENT_CLOSED_SCALE)

	_map_open_tween = create_tween()
	_map_open_tween.set_parallel(true)
	if is_instance_valid(_map_dim_overlay):
		_map_open_tween.tween_property(_map_dim_overlay, "color:a", MAP_OVERLAY_ALPHA, 0.22)
	for visual in _get_map_visual_nodes():
		_map_open_tween.tween_property(visual, "modulate:a", _get_map_visual_base_modulate(visual).a, 0.24)
		_map_open_tween.tween_property(visual, "scale", _get_map_visual_base_scale(visual) * MAP_CONTENT_OPEN_SCALE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_map_open_tween.finished.connect(func():
		_is_animating = false
		_start_map_marker_animations())



func _close_map(animate: bool = true) -> void:
	if not map_layer:
		return
	if not map_layer.visible:
		return

	_stop_map_marker_animations()
	_stop_map_panel_tween()

	if animate:
		_is_animating = true
		_map_open_tween = create_tween()
		_map_open_tween.set_parallel(true)
		if is_instance_valid(_map_dim_overlay):
			_map_open_tween.tween_property(_map_dim_overlay, "color:a", 0.0, 0.18)
		for visual in _get_map_visual_nodes():
			_map_open_tween.tween_property(visual, "modulate:a", 0.0, 0.16)
			_map_open_tween.tween_property(visual, "scale", _get_map_visual_base_scale(visual) * MAP_CONTENT_CLOSED_SCALE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_map_open_tween.finished.connect(func():
			map_layer.visible = false
			for visual in _get_map_visual_nodes():
				_restore_map_visual_state(visual)
			_set_touch_controls_map_focus(false)
			_is_animating = false)
	else:
		map_layer.visible = false
		if is_instance_valid(_map_dim_overlay):
			_map_dim_overlay.color = Color(0, 0, 0, MAP_OVERLAY_ALPHA)
		for visual in _get_map_visual_nodes():
			_restore_map_visual_state(visual)
		_set_touch_controls_map_focus(false)


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

# ─── LEDGER ──────────────────────────────────────────────────────────────────

func _setup_forest_ledger_navigation() -> void:
	_connect_button_once(forest_prev_page_button, _on_forest_prev_page_pressed)
	_connect_button_once(forest_next_page_button, _on_forest_next_page_pressed)


func _connect_button_once(btn: Button, handler: Callable) -> void:
	if is_instance_valid(btn) and not btn.pressed.is_connected(handler):
		btn.pressed.connect(handler)


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
			"title":        str(entry.get("zone_name", entry.get("title", "Ledger"))),
			"left_header":  str(entry.get("left_header", "")),
			"left_body":    str(entry.get("left_body", "")),
			"right_header": str(entry.get("right_header", "")),
			"right_body":   str(entry.get("right_body", "")),
		}
	var body_text := str(entry.get("body", ""))
	var split_pages := _split_body_into_book_pages(body_text)
	return {
		"title":        str(entry.get("zone_name", entry.get("title", "Ledger"))),
		"left_header":  str(entry.get("title", "Notes")),
		"left_body":    str(split_pages.get("left", "")),
		"right_header": "Example" if str(split_pages.get("right", "")) != "" else "",
		"right_body":   str(split_pages.get("right", "")),
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
	var label_map := [
		[forest_ledger_title_label,        "title"],
		[forest_ledger_left_header_label,  "left_header"],
		[forest_ledger_left_body_label,    "left_body"],
		[forest_ledger_right_header_label, "right_header"],
		[forest_ledger_right_body_label,   "right_body"],
	]
	for pair in label_map:
		var lbl: Label = pair[0]
		var key: String = pair[1]
		if is_instance_valid(lbl):
			lbl.text = str(page_data.get(key, ""))


func _update_forest_ledger_navigation() -> void:
	var total := _ledger_pages.size()
	if is_instance_valid(forest_page_indicator_label):
		forest_page_indicator_label.text = "%d / %d" % [_current_ledger_page + 1, max(total, 1)]
	_set_page_button_state(forest_prev_page_button, total > 1, _current_ledger_page <= 0)
	_set_page_button_state(forest_next_page_button, total > 1, _current_ledger_page >= total - 1)


func _set_page_button_state(btn: Button, should_show: bool, should_disabled: bool) -> void:
	if is_instance_valid(btn):
		btn.visible = should_show
		btn.disabled = should_disabled


func _on_forest_prev_page_pressed() -> void:
	if not _ledger_page_animating and _current_ledger_page > 0:
		_show_forest_ledger_page(_current_ledger_page - 1, true)


func _on_forest_next_page_pressed() -> void:
	if not _ledger_page_animating and _current_ledger_page < _ledger_pages.size() - 1:
		_show_forest_ledger_page(_current_ledger_page + 1, true)

# ─── BRIEFCASE ───────────────────────────────────────────────────────────────

func _on_briefcase_updated() -> void:
	_refresh_briefcase_display()


func _refresh_briefcase_display() -> void:
	if not is_instance_valid(briefcase_display):
		push_error("[ForestHub] briefcase_display is invalid")
		return

	# State-driven
	briefcase_display.visible = true
	_update_forest_briefcase_clues()
	
func _update_forest_briefcase_clues() -> void:
	if is_instance_valid(clue_ladle):
		clue_ladle.visible = GameState.has_clue("pinas_house")

	if is_instance_valid(clue_pineapple):
		clue_pineapple.visible = GameState.has_clue("backyard_path")

	if is_instance_valid(clue_eyes):
		clue_eyes.visible = GameState.has_clue("old_well")

	if is_instance_valid(clue_tiara):
		clue_tiara.visible = GameState.has_clue("abandoned_house")

	if is_instance_valid(clue_scroll):
		clue_scroll.visible = GameState.has_clue("storage_hut")
# ─── PORTALS ─────────────────────────────────────────────────────────────────

func _connect_portal_signals() -> void:
	if not portals:
		return
	await get_tree().process_frame
	for portal in portals.get_children():
		# Transition signals — fire only when both players confirm entry together
		if portal.has_signal("players_entering") and not portal.players_entering.is_connected(_on_players_entering_zone):
			portal.players_entering.connect(_on_players_entering_zone)
		if portal.has_signal("players_entered") and not portal.players_entered.is_connected(_on_players_entered_zone):
			portal.players_entered.connect(_on_players_entered_zone)

		# Zone thought trigger — portal IS the Area2D (see zone_portal.gd).
		# body_entered fires per body individually; we filter to local player only.
		if portal is Area2D:
			var zone: String = (portal as Area2D).zone_name
			if not portal.body_entered.is_connected(_on_zone_body_entered):
				portal.body_entered.connect(_on_zone_body_entered.bind(zone))


## Fires when any body enters a portal Area2D.
## Filtered to the local player's own CharacterBody2D only.
func _on_zone_body_entered(body: Node2D, zone_name: String) -> void:
	if not body is CharacterBody2D:
		return
	if body.name != str(multiplayer.get_unique_id()):
		return
	if not ZONE_THOUGHTS.has(zone_name):
		return
	if GameState.has_clue(zone_name):
		_show_zone_completed_thought(zone_name)
		return
	_show_zone_thought(zone_name)


## Fires when BOTH players have confirmed entry — used only for door animation.
func _on_players_entering_zone(zone_name: String) -> void:
	if is_instance_valid(touch_controls):
		touch_controls.visible = false
		
	match zone_name:
		"pinas_house": _animate_door(pinas_house_door, zone_name)
		"storage_hut": _animate_door(storage_hut_door, zone_name)
		"abandoned_house": _animate_door(abandoned_house_door, zone_name)


func _on_players_entered_zone(zone_name: String) -> void:
	if is_instance_valid(touch_controls):
		touch_controls.visible = false
		
	var target_portal: Node = null

	for portal in portals.get_children():
		if portal.zone_name == zone_name:
			target_portal = portal
			break

	if not target_portal:
		push_warning("[ForestHub] Could not find portal for zone: " + zone_name)
		return

	GameState.mark_zone_visited(zone_name)
	_refresh_map_progress()

	target_portal.complete_zone_entry()


func _animate_door(door_sprite: Sprite2D, zone_name: String) -> void:
	if not door_sprite:
		push_warning("[ForestHub] Door sprite not found for zone: " + zone_name)
		return
	door_sprite.visible = true
	door_sprite.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(door_sprite, "modulate:a", 1.0, DOOR_ANIMATION_DURATION)
	if not tree_exiting.is_connected(_on_tree_exiting_hide_doors):
		tree_exiting.connect(_on_tree_exiting_hide_doors)


func _on_tree_exiting_hide_doors() -> void:
	for door in [pinas_house_door, storage_hut_door, abandoned_house_door]:
		if door:
			door.visible = false

# ─── ZONE COMPLETION INDICATORS ──────────────────────────────────────────────

func _setup_zone_completion_indicators() -> void:
	if not finish_zone_indicator:
		push_warning("[ForestHub] FinishZoneIndicator node not found!")
		return
	for portal in portals.get_children():
		_apply_zone_indicator(portal)


func _apply_zone_indicator(portal: Node) -> void:
	var zone_name: String = portal.zone_name
	if finish_zone_indicator.has_method("set_portal_position"):
		finish_zone_indicator.set_portal_position(zone_name, portal.global_position)
	var is_completed: bool = GameState.zones_status.get(zone_name, GameState.ZoneStatus.AVAILABLE) == GameState.ZoneStatus.COMPLETED
	var enter_button := portal.get_node_or_null("EnterButton")
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

	_refresh_quest_objectives()
	_refresh_map_progress()
# ─── DIALOGUE ────────────────────────────────────────────────────────────────
## One-time zone thought triggered when the local player walks into a portal.
## Keys in ZONE_THOUGHTS must match portal.zone_name exactly (check Inspector).
func _show_zone_thought(zone_name: String) -> void:
	if not ZONE_THOUGHTS.has(zone_name):
		return
	var is_detective := (NetworkManager.get_my_role() == "detective")
	var line: Array = ZONE_THOUGHTS[zone_name][is_detective]
	await _say_auto(line[0], line[1], ZONE_THOUGHT_HOLD)
	_clear_dialogue()


const ZONE_DISPLAY_NAMES: Dictionary = {
	"pinas_house": "Pina's House",
	"old_well": "Old Well",
	"backyard_path": "Backyard Path",
	"storage_hut": "Storage Hut",
	"abandoned_house": "Abandoned House",
}

func _show_zone_completed_thought(zone_name: String) -> void:
	var is_detective := (NetworkManager.get_my_role() == "detective")
	var speaker: String = "Detective" if is_detective else "Sidekick"
	var display_name: String = ZONE_DISPLAY_NAMES.get(zone_name, zone_name)
	var line: String = "We already retrieved the artifact from %s. Let's move on!" % display_name
	await _say_auto(speaker, line, ZONE_THOUGHT_HOLD)
	_clear_dialogue()


## Sets speaker label, clears text, makes panel visible.
func _show_dialogue_panel(speaker: String) -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(speaker_label) or not is_instance_valid(dialogue_label) or not is_instance_valid(dialogue_panel):
		return

	speaker_label.text = speaker
	dialogue_label.text = ""
	dialogue_panel.modulate.a = 1.0
	dialogue_panel.visible = true


## Streams text into dialogue_label character by character.
func _typewrite(text: String) -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(dialogue_label):
		return

	var char_index: int = 0
	var elapsed: float = 0.0
	var length: int = text.length()

	while char_index <= length:
		if not is_inside_tree():
			return
		if not is_instance_valid(dialogue_label):
			return

		elapsed += get_process_delta_time()
		if elapsed >= DIALOGUE_SPEED:
			elapsed -= DIALOGUE_SPEED
			char_index += 1
			dialogue_label.text = text.substr(0, char_index)

		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame


## Typewriter + hides panel when text finishes (manual-advance style).
func _say(speaker: String, text: String) -> void:
	if not is_inside_tree():
		return

	_show_dialogue_panel(speaker)
	await _typewrite(text)

	if not is_inside_tree():
		return
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false


## Typewriter + auto-dismisses after [hold] seconds.
func _say_auto(speaker: String, text: String, hold: float) -> void:
	if not is_inside_tree():
		return

	_show_dialogue_panel(speaker)
	await _typewrite(text)

	if not is_inside_tree():
		return

	await _wait(hold)


func _wait(seconds: float) -> void:
	if not is_inside_tree():
		return

	var elapsed: float = 0.0
	while elapsed < seconds:
		if not is_inside_tree():
			return

		elapsed += get_process_delta_time()

		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame


func _clear_dialogue() -> void:
	if is_instance_valid(dialogue_label):
		dialogue_label.text = ""
	if is_instance_valid(speaker_label):
		speaker_label.text = ""
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false

# ─── FIND PARTNER ────────────────────────────────────────────────────────────

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
	_is_finding_partner = true
	cam.set_as_top_level(true)
	cam.global_position = my_player.global_position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cam, "global_position", target_pos, FIND_PARTNER_DURATION)
	tween.tween_interval(FIND_PARTNER_HOLD)
	tween.tween_method(func(_t: float):
		if is_instance_valid(cam) and is_instance_valid(my_player):
			cam.global_position = cam.global_position.lerp(my_player.global_position, 0.15)
	, 0.0, 1.0, FIND_PARTNER_DURATION)
	tween.tween_callback(func():
		if not is_instance_valid(cam) or not is_instance_valid(my_player):
			_is_finding_partner = false
			return
		cam.set_as_top_level(false)
		cam.position = Vector2.ZERO
		_is_finding_partner = false)

# ─── LOCATION DIAMOND ────────────────────────────────────────────────────────

func _animate_location_diamond() -> void:
	var diamond := get_node_or_null("LocationDiamond")
	if not diamond:
		return
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(diamond, "modulate:a", 0.4, 0.8)
	tween.tween_property(diamond, "modulate:a", 1.0, 0.8)


func _lock_player_movement() -> void:
	var my_id := multiplayer.get_unique_id()
	var player := get_node_or_null(str(my_id)) as CharacterBody2D
	if is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.set_movement_locked(true)


func _unlock_player_movement() -> void:
	var my_id := multiplayer.get_unique_id()
	var player := get_node_or_null(str(my_id)) as CharacterBody2D
	if is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.set_movement_locked(false)


# ─── FOREST TUTORIAL ─────────────────────────────────────────────────────────

func _setup_forest_tutorial() -> void:
	var tutorial := get_node_or_null("ForestTutorial")

	if GameState.forest_tutorial_shown:
		if tutorial:
			tutorial.visible = false
		return

	GameState.mark_tutorial_shown()

	if not tutorial:
		push_warning("[ForestHub] ForestTutorial node not found.")
		return

	if tutorial is CanvasLayer:
		tutorial.layer = 10
		tutorial.follow_viewport_enabled = false

	var overlay := ColorRect.new()
	overlay.name = "DimOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial.add_child(overlay)
	tutorial.move_child(overlay, 0)

	if touch_controls:
		touch_controls.visible = false

	tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var close_btn := tutorial.get_node_or_null("CloseTutorialButton")
	if close_btn:
		close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		if not close_btn.pressed.is_connected(_on_tutorial_closed):
			close_btn.pressed.connect(_on_tutorial_closed)
	else:
		push_warning("[ForestHub] CloseTutorialButton not found inside ForestTutorial.")


func _on_tutorial_closed() -> void:
	var tutorial := get_node_or_null("ForestTutorial")
	if tutorial:
		tutorial.queue_free()

	# Restore touch controls
	if touch_controls:
		touch_controls.visible = true
	
	get_tree().paused = false

func _setup_map_layer() -> void:
	if not map_layer:
		push_error("[ForestHub] MapLayer not found!")
		return

	map_layer.layer = MAP_LAYER_FOCUS_LAYER
	map_layer.follow_viewport_enabled = false
	map_layer.visible = false
	_ensure_map_focus_ui()

	if map_panel:
		map_panel.visible = true
		map_panel.modulate = Color(1, 1, 1, 1)

	_setup_map_progress_markers()


func _ensure_map_focus_ui() -> void:
	if not is_instance_valid(map_layer):
		return

	_map_dim_overlay = map_layer.get_node_or_null("DimOverlay") as ColorRect
	if not is_instance_valid(_map_dim_overlay):
		_map_dim_overlay = ColorRect.new()
		_map_dim_overlay.name = "DimOverlay"
		map_layer.add_child(_map_dim_overlay)
		map_layer.move_child(_map_dim_overlay, 0)

	_map_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_dim_overlay.color = Color(0, 0, 0, 0.72)
	_map_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_dim_overlay.z_index = -100

	var old_close_button := map_layer.get_node_or_null("CloseMapButton")
	if is_instance_valid(old_close_button):
		old_close_button.queue_free()


func _get_map_visual_nodes() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = []
	if is_instance_valid(map_panel):
		nodes.append(map_panel)
	var quest_panel := map_layer.get_node_or_null("Quest") as CanvasItem
	if is_instance_valid(quest_panel):
		nodes.append(quest_panel)
	for marker in _map_zone_markers.values():
		var marker_item := marker as CanvasItem
		if is_instance_valid(marker_item):
			nodes.append(marker_item)
	for marker in _map_artifact_markers.values():
		var marker_item := marker as CanvasItem
		if is_instance_valid(marker_item):
			nodes.append(marker_item)
	return nodes


func _set_touch_controls_map_focus(map_open: bool) -> void:
	if not is_instance_valid(touch_controls):
		return

	if map_open:
		if not _map_focus_controls_active:
			for child in touch_controls.get_children():
				if child is CanvasItem:
					child.set_meta("map_previous_visible", (child as CanvasItem).visible)
			_map_focus_controls_active = true
		touch_controls.visible = true
		touch_controls.layer = MAP_LAYER_FOCUS_LAYER + 1
		for child in touch_controls.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = child.name == "Map"
	else:
		if not _map_focus_controls_active:
			return
		for child in touch_controls.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = bool(child.get_meta("map_previous_visible", (child as CanvasItem).visible))
				if child.has_meta("map_previous_visible"):
					child.remove_meta("map_previous_visible")
		touch_controls.layer = _touch_controls_default_layer
		_map_focus_controls_active = false


func _stop_map_panel_tween() -> void:
	if is_instance_valid(_map_open_tween):
		_map_open_tween.kill()
	_map_open_tween = null


func _cache_map_visual_state(visual: CanvasItem) -> void:
	if not is_instance_valid(visual):
		return
	if not visual.has_meta("map_base_modulate"):
		visual.set_meta("map_base_modulate", visual.modulate)
	if not visual.has_meta("map_base_scale"):
		visual.set_meta("map_base_scale", _get_map_visual_current_scale(visual))
	if visual is Node2D and not visual.has_meta("map_base_rotation"):
		visual.set_meta("map_base_rotation", (visual as Node2D).rotation)


func _get_map_visual_current_scale(visual: CanvasItem) -> Vector2:
	if visual is Node2D:
		return (visual as Node2D).scale
	if visual is Control:
		return (visual as Control).scale
	return Vector2.ONE


func _get_map_visual_base_scale(visual: CanvasItem) -> Vector2:
	if not is_instance_valid(visual):
		return Vector2.ONE
	return visual.get_meta("map_base_scale", _get_map_visual_current_scale(visual)) as Vector2


func _get_map_visual_base_modulate(visual: CanvasItem) -> Color:
	if not is_instance_valid(visual):
		return Color.WHITE
	return visual.get_meta("map_base_modulate", visual.modulate) as Color


func _set_map_visual_scale(visual: CanvasItem, new_scale: Vector2) -> void:
	if visual is Node2D:
		(visual as Node2D).scale = new_scale
	elif visual is Control:
		(visual as Control).scale = new_scale


func _restore_map_visual_state(visual: CanvasItem) -> void:
	if not is_instance_valid(visual):
		return
	visual.modulate = _get_map_visual_base_modulate(visual)
	_set_map_visual_scale(visual, _get_map_visual_base_scale(visual))
	if visual is Node2D:
		(visual as Node2D).rotation = visual.get_meta("map_base_rotation", (visual as Node2D).rotation) as float


func _start_map_marker_animations() -> void:
	_stop_map_marker_animations()
	var marker_index := 0
	for marker in _map_zone_markers.values():
		var sprite := marker as Sprite2D
		if is_instance_valid(sprite) and sprite.visible:
			_play_map_marker_loop(sprite, false, marker_index)
			marker_index += 1
	for marker in _map_artifact_markers.values():
		var sprite := marker as Sprite2D
		if is_instance_valid(sprite) and sprite.visible:
			_play_map_marker_loop(sprite, true, marker_index)
			marker_index += 1


func _play_map_marker_loop(marker: Sprite2D, is_artifact: bool, marker_index: int) -> void:
	_cache_map_visual_state(marker)
	var base_scale: Vector2 = _get_map_visual_base_scale(marker)
	var base_modulate: Color = _get_map_visual_base_modulate(marker)
	var base_rotation: float = marker.get_meta("map_base_rotation", marker.rotation) as float
	var pulse_scale := base_scale * (1.14 if is_artifact else 1.08)
	var pulse_color := Color(1.0, 0.90, 0.48, base_modulate.a) if is_artifact else Color(1.0, 1.0, 1.0, base_modulate.a)
	var pulse_duration := 0.34 if is_artifact else 0.42
	var tween := create_tween()
	tween.set_loops()
	tween.tween_interval(float(marker_index) * 0.05)
	tween.tween_property(marker, "scale", pulse_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(marker, "modulate", pulse_color, pulse_duration)
	if is_artifact:
		tween.parallel().tween_property(marker, "rotation", base_rotation + 0.08, pulse_duration)
	tween.tween_property(marker, "scale", base_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(marker, "modulate", base_modulate, pulse_duration)
	if is_artifact:
		tween.parallel().tween_property(marker, "rotation", base_rotation - 0.05, pulse_duration)
		tween.tween_property(marker, "rotation", base_rotation, 0.16)
	tween.tween_interval(0.45 if is_artifact else 0.65)
	_map_marker_tweens.append(tween)


func _stop_map_marker_animations() -> void:
	for tween in _map_marker_tweens:
		if is_instance_valid(tween):
			(tween as Tween).kill()
	_map_marker_tweens.clear()
	for marker in _map_zone_markers.values():
		var marker_item := marker as CanvasItem
		if is_instance_valid(marker_item):
			_restore_map_visual_state(marker_item)
	for marker in _map_artifact_markers.values():
		var marker_item := marker as CanvasItem
		if is_instance_valid(marker_item):
			_restore_map_visual_state(marker_item)
	
func _setup_map_progress_markers() -> void:
	_map_zone_markers = {
		"pinas_house": map_ph_marker,
		"backyard_path": map_bp_marker,
		"old_well": map_ow_marker,
		"storage_hut": map_sh_marker,
		"abandoned_house": map_ah_marker,
	}

	_map_artifact_markers = {
		"pinas_house": art_ladle_marker,
		"backyard_path": art_pineapple_marker,
		"old_well": art_eye_marker,
		"storage_hut": art_scroll_marker,
		"abandoned_house": art_tiara_marker,
	}

	_refresh_map_progress()


func _refresh_map_progress() -> void:
	for zone_name in _map_zone_markers.keys():
		var zone_marker: Sprite2D = _map_zone_markers.get(zone_name, null) as Sprite2D

		if is_instance_valid(zone_marker):
			zone_marker.visible = GameState.has_zone_visited(zone_name)

	for zone_name in _map_artifact_markers.keys():
		var artifact_marker: Sprite2D = _map_artifact_markers.get(zone_name, null) as Sprite2D

		if not is_instance_valid(artifact_marker):
			continue

		var is_completed: bool = (
			GameState.has_clue(zone_name)
			or GameState.zones_status.get(zone_name, GameState.ZoneStatus.AVAILABLE) == GameState.ZoneStatus.COMPLETED
		)

		artifact_marker.visible = is_completed


func _on_zone_visited(_zone_name: String) -> void:
	_refresh_map_progress()
		
func _setup_quest_objectives() -> void:
	_quest_objective_labels = {
		"pinas_house": objective_label_1,
		"backyard_path": objective_label_2,
		"old_well": objective_label_3,
		"storage_hut": objective_label_4,
		"abandoned_house": objective_label_5,
	}

	for zone_name in _quest_objective_labels.keys():
		var label: Label = _quest_objective_labels[zone_name]
		if is_instance_valid(label):
			_quest_objective_texts[zone_name] = label.text

	_refresh_quest_objectives()


func _refresh_quest_objectives() -> void:
	for zone_name in _quest_objective_labels.keys():
		var label: Label = _quest_objective_labels[zone_name]
		if not is_instance_valid(label):
			continue

		var original_text: String = str(_quest_objective_texts.get(zone_name, label.text))
		var completed := _is_quest_zone_completed(zone_name)

		if completed:
			label.text = "✓ " + _make_strikethrough(original_text)
			label.modulate = Color(0.6, 0.6, 0.6, 1.0)
		else:
			label.text = "• " + original_text
			label.modulate = Color(1, 1, 1, 1)


func _is_quest_zone_completed(zone_name: String) -> bool:
	if GameState.has_clue(zone_name):
		return true

	return GameState.zones_status.get(zone_name, GameState.ZoneStatus.AVAILABLE) == GameState.ZoneStatus.COMPLETED


func _make_strikethrough(text: String) -> String:
	var result := ""

	for i in range(text.length()):
		var character := text.substr(i, 1)

		if character == " ":
			result += character
		else:
			result += character + "\u0336"

	return result
