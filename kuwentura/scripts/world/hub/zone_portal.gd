extends Area2D

## Zone Portal - Handles player detection and zone entry for a specific zone.

signal players_entering(zone_name: String)
signal players_entered(zone_name: String)

@export var zone_name: String
@export var scene_path: String

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var _hint: Node = get_node_or_null("Hint")

var _detective_present: bool = false
var _sidekick_present: bool = false
var _detective_peer_id: int = 0
var _sidekick_peer_id: int = 0
var _detective_ready: bool = false
var _sidekick_ready: bool = false
var _detective_confirming: bool = false
var _sidekick_confirming: bool = false
var _detective_entry_position: Vector2 = Vector2.ZERO
var _sidekick_entry_position: Vector2 = Vector2.ZERO
var _is_entering: bool = false
var _enter_button: Button = null
var _base_button_text: String = "Enter Zone"

const ENTRY_ANIMATION_DURATION: float = 1.5


func _ready() -> void:
	await get_tree().process_frame
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_enter_button = _find_enter_button()
	if _enter_button:
		_base_button_text = _enter_button.text
		_enter_button.visible = false
		_enter_button.pressed.connect(_on_enter_button_pressed)
	else:
		push_warning("[ZonePortal] " + zone_name + " could not find enter button!")
	if _hint:
		_hint.visible = false


func _find_enter_button() -> Button:
	for child in get_children():
		if child is Button:
			return child
	var btn_name := "Enter" + zone_name.to_pascal_case() + "Button"
	var btn := get_node_or_null(btn_name)
	if btn is Button:
		return btn
	var parent := get_parent()
	if parent:
		btn = parent.get_node_or_null(btn_name)
		if btn is Button:
			return btn
	return null


func _is_network_ready() -> bool:
	return is_inside_tree() and multiplayer != null and multiplayer.multiplayer_peer != null


func _is_zone_locked() -> bool:
	var zid := zone_name.strip_edges()
	return GameState.is_zone_locked_temp(zid)


func _set_player_present(peer_id: int, present: bool, entry_pos: Vector2 = Vector2.ZERO) -> void:
	if peer_id == 1:
		_detective_present = present
		_detective_peer_id = peer_id if present else 0
		_detective_entry_position = entry_pos if present else Vector2.ZERO
		if not present:
			_detective_ready = false
	else:
		_sidekick_present = present
		_sidekick_peer_id = peer_id if present else 0
		_sidekick_entry_position = entry_pos if present else Vector2.ZERO
		if not present:
			_sidekick_ready = false


func _set_player_confirming(peer_id: int, confirming: bool) -> void:
	if peer_id == 1:
		_detective_confirming = confirming
		_detective_ready = confirming
	else:
		_sidekick_confirming = confirming
		_sidekick_ready = confirming


func _resolve_return_position(pos: Vector2, fallback_offset: Vector2) -> Vector2:
	if pos != Vector2.ZERO:
		return pos
	var marker := get_node_or_null("ReturnMarker")
	var fallback: Vector2 = marker.global_position if marker else global_position + fallback_offset
	push_warning("[ZonePortal] Entry position was ZERO, using fallback: " + str(fallback))
	return fallback


func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D:
		return
		
	if body.name == str(multiplayer.get_unique_id()):
		if _sprite:
			_sprite.visible = false
		if _hint:
			_hint.visible = true
			
	var peer_id := int(body.name) if body.name.is_valid_int() else 0
	if peer_id <= 0 or not _is_network_ready():
		return
	if multiplayer.is_server():
		_set_player_present(peer_id, true, body.global_position)
		_update_button_visibility()
	else:
		_report_entered.rpc_id(1, peer_id, body.global_position)


func _on_body_exited(body: Node2D) -> void:
	if not body is CharacterBody2D:
		return
		
	if body.name == str(multiplayer.get_unique_id()):
		if _sprite:
			_sprite.visible = true
		if _hint:
			_hint.visible = false
		
	var peer_id := int(body.name) if body.name.is_valid_int() else 0
	if peer_id <= 0 or not _is_network_ready():
		return
	if multiplayer.is_server():
		_set_player_present(peer_id, false)
		_update_button_visibility()
	else:
		_report_exited.rpc_id(1, peer_id)


@rpc("any_peer", "reliable")
func _report_entered(peer_id: int, entry_position: Vector2 = Vector2.ZERO) -> void:
	if not is_inside_tree() or multiplayer == null or not multiplayer.is_server():
		return
	_set_player_present(peer_id, true, entry_position)
	_update_button_visibility()
	if _detective_present and _sidekick_present:
		_update_button_text()


@rpc("any_peer", "reliable")
func _report_exited(peer_id: int) -> void:
	if not is_inside_tree() or multiplayer == null or not multiplayer.is_server():
		return
	_set_player_present(peer_id, false)
	_update_button_visibility()


func _update_button_visibility() -> void:
	if not _is_network_ready():
		return
	var is_completed: bool = GameState.zones_status.get(zone_name, GameState.ZoneStatus.AVAILABLE) == GameState.ZoneStatus.COMPLETED
	if is_completed:
		if _enter_button:
			_enter_button.visible = false
		return
		
	var my_peer_id := multiplayer.get_unique_id()
	var i_am_present := (my_peer_id == 1 and _detective_present) or (my_peer_id != 1 and _sidekick_present)
	if _enter_button:
		_enter_button.visible = i_am_present
	if not (_detective_present or _sidekick_present):
		_detective_ready = false
		_sidekick_ready = false
		_detective_confirming = false
		_sidekick_confirming = false
		_update_button_text()
	_sync_button_visibility.rpc(_detective_present, _sidekick_present, _detective_ready, _sidekick_ready)


@rpc("authority", "reliable")
func _sync_button_visibility(detective_present: bool, sidekick_present: bool, detective_ready: bool, sidekick_ready: bool) -> void:
	if not is_inside_tree():
		return

	_detective_present = detective_present
	_sidekick_present = sidekick_present
	_detective_ready = detective_ready
	_sidekick_ready = sidekick_ready
	
	if not detective_ready and not sidekick_ready:
		_detective_confirming = false
		_sidekick_confirming = false

	# Each client shows the button only if THEY are present
	var my_peer_id := multiplayer.get_unique_id()
	var i_am_present := (my_peer_id == 1 and _detective_present) or (my_peer_id != 1 and _sidekick_present)
	if _enter_button:
		_enter_button.visible = i_am_present
		
	_update_button_text()


func _on_enter_button_pressed() -> void:
	if not is_inside_tree() or multiplayer == null:
		return
	var my_peer_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		var was_confirming := _detective_confirming
		_set_player_confirming(1, not was_confirming)
		_sync_confirming_state.rpc(_detective_confirming, _sidekick_confirming)
		_update_button_text()
		if not was_confirming:
			_check_and_enter()
	else:
		if _sidekick_confirming:
			_player_cancel_rpc.rpc_id(1, my_peer_id)
			_sidekick_confirming = false
			_sidekick_ready = false
		else:
			_player_confirm_rpc.rpc_id(1, my_peer_id)
			_sidekick_confirming = true
			_sidekick_ready = true
		_update_button_text()


@rpc("any_peer", "reliable")
func _player_confirm_rpc(peer_id: int) -> void:
	if not is_inside_tree() or multiplayer == null or not multiplayer.is_server():
		return
	_set_player_confirming(peer_id, true)
	_update_button_text()
	_sync_confirming_state.rpc(_detective_confirming, _sidekick_confirming)
	_check_and_enter()


@rpc("any_peer", "reliable")
func _player_cancel_rpc(peer_id: int) -> void:
	if not is_inside_tree() or multiplayer == null or not multiplayer.is_server():
		return
	_set_player_confirming(peer_id, false)
	_update_button_text()
	_sync_confirming_state.rpc(_detective_confirming, _sidekick_confirming)


@rpc("authority", "reliable")
func _sync_confirming_state(detective_confirming: bool, sidekick_confirming: bool) -> void:
	if not is_inside_tree():
		return
	_detective_confirming = detective_confirming
	_sidekick_confirming = sidekick_confirming
	_detective_ready = detective_confirming
	_sidekick_ready = sidekick_confirming
	_update_button_text()


func _update_button_text() -> void:
	if not _enter_button or not is_inside_tree() or multiplayer == null:
		return
		
	var is_detective := (multiplayer.get_unique_id() == 1)
	var local_confirming := _detective_confirming if is_detective else _sidekick_confirming
	var both_present := _detective_present and _sidekick_present

	if local_confirming:
		# Only one player present or waiting for the other to confirm
		_enter_button.text = "Waiting for another player... \n Tap again to Cancel"
		return

	if both_present and _detective_ready and _sidekick_ready:
		_enter_button.text = _base_button_text + " (Entering...)"
	else:
		_enter_button.text = _base_button_text


func _check_and_enter() -> void:
	if not _is_network_ready() or not multiplayer.is_server():
		return
	if not (_detective_ready and _sidekick_ready and _detective_present and _sidekick_present):
		return
	if _is_zone_locked() or _is_entering:
		return
	_is_entering = true
	players_entering.emit(zone_name)
	_sync_entry_animation.rpc()
	if _enter_button:
		_enter_button.visible = false
	await get_tree().create_timer(ENTRY_ANIMATION_DURATION).timeout
	players_entered.emit(zone_name)


func _enter_zone() -> void:
	if not _is_network_ready():
		return
	if multiplayer.is_server():
		GameState.clear_spawn_position(1)
		for peer_id in multiplayer.get_peers():
			GameState.clear_spawn_position(peer_id)
	var detective_pos := _detective_entry_position
	var sidekick_pos := _sidekick_entry_position
	var sidekick_pid := _sidekick_peer_id
	_save_positions_direct(detective_pos, sidekick_pos, sidekick_pid)
	rpc_enter_zone_with_positions.rpc(scene_path, detective_pos, sidekick_pos, sidekick_pid)


func _save_positions_direct(detective_pos: Vector2, sidekick_pos: Vector2, sidekick_pid: int) -> void:
	var det_pos := _resolve_return_position(detective_pos, Vector2(0, 100))
	GameState.save_spawn_position(1, det_pos, "forest_hub")
	if sidekick_pid > 0:
		var sdk_pos := _resolve_return_position(sidekick_pos, Vector2(-50, 100))
		GameState.save_spawn_position(sidekick_pid, sdk_pos, "forest_hub")
		_sync_spawn_position_to_client.rpc_id(sidekick_pid, sidekick_pid, sdk_pos, "forest_hub")


@rpc("authority", "reliable", "call_local")
func rpc_enter_zone_with_positions(path: String, detective_pos: Vector2, sidekick_pos: Vector2, sidekick_pid: int) -> void:
	if detective_pos != Vector2.ZERO:
		GameState.save_spawn_position(1, detective_pos, "forest_hub")
	if sidekick_pid > 0 and sidekick_pos != Vector2.ZERO:
		GameState.save_spawn_position(sidekick_pid, sidekick_pos, "forest_hub")
	if is_inside_tree():
		if zone_name == "PinasHouse":
			get_tree().change_scene_to_file(path)  # no loading screen
		else:
			LoadingScreen.change_scene(path)


@rpc("authority", "reliable")
func _sync_spawn_position_to_client(peer_id: int, spawn_position: Vector2, zone: String) -> void:
	if is_inside_tree() and peer_id == multiplayer.get_unique_id():
		GameState.save_spawn_position(peer_id, spawn_position, zone)


@rpc("authority", "reliable")
func _sync_entry_animation() -> void:
	if not is_inside_tree():
		return
	if _enter_button:
		_enter_button.visible = false
	players_entering.emit(zone_name)


func complete_zone_entry() -> void:
	_enter_zone()
