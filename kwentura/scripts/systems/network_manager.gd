extends Node

#==============================================================================
# NETWORK MANAGER - WebSocket Protocol Implementation
# For Kwentura 2-Player Co-op
#==============================================================================

#------------------------------------------------------------------------------
# Enums & Constants
#------------------------------------------------------------------------------

enum ConnectionState {
	DISCONNECTED,
	CONNECTING_HTTP,
	CONNECTING_WS,
	HANDSHAKE,
	LOADING,
	READY,
	PLAYING,
	PAUSED,
	RECONNECTING,
	DISCONNECTING
}

enum MessageTypeBinary {
	INPUT_MOVE = 0x01,
	STATE_PLAYER = 0x02,
	PING = 0xFF,
	PONG = 0xFE
}

# Production URLs
# const API_BASE: String = "https://api.kwentura.game"
# const WS_BASE: String = "wss://api.kwentura.game/ws"

# Development URLs (localhost)
const API_BASE: String = "http://localhost:10000"
const WS_BASE: String = "ws://localhost:10000/ws"

# Rate limits
const INPUT_SEND_RATE: float = 1.0 / 60.0  # 60Hz
const PING_INTERVAL: float = 1.0  # 1Hz
const MAX_RECONNECT_ATTEMPTS: int = 3
const RECONNECT_DELAY: float = 3.0

# Physics constants for validation
const MAX_WALK_SPEED: float = 200.0
const MAX_SPRINT_SPEED: float = 400.0

#------------------------------------------------------------------------------
# Signals
#------------------------------------------------------------------------------

# New signals
signal connection_state_changed(new_state: int, old_state: int)
signal session_started(world_data: Dictionary)
signal game_started(checkpoint: String)
signal game_paused(reason: String)
signal game_resumed
signal partner_connected(player_data: Dictionary)
signal partner_disconnected(player_data: Dictionary)
signal player_state_received(player_id: String, state: Dictionary)
signal action_result_received(result: Dictionary)
signal puzzle_result_received(result: Dictionary)
signal story_event_received(event: Dictionary)
signal inventory_changed(change: Dictionary)
signal error_received(error: Dictionary)
signal latency_updated(latency_ms: int)

# Backward compatibility signals (old API)
signal connection_established(peer_id: int)
signal connection_failed(error: String)
signal player_joined(peer_id: int, role: int)
signal player_left(peer_id: int)
signal role_assignment_received(role: int)
signal room_code_generated(code: String)
signal snapshot_received(data: Dictionary)
signal restart_requested
signal restart_confirmed

#------------------------------------------------------------------------------
# Exported Properties
#------------------------------------------------------------------------------

@export var enable_prediction: bool = true
@export var enable_interpolation: bool = true
@export var interpolation_delay_ms: int = 100

#------------------------------------------------------------------------------
# Private State
#------------------------------------------------------------------------------

var _state: ConnectionState = ConnectionState.DISCONNECTED
var _ws: WebSocketPeer = null
var _http: HTTPRequest = null

# Authentication
var _auth_token: String = ""
var _user_id: String = ""

# Session
var _session_id: String = ""
var _world_id: String = ""
var _invite_code: String = ""  # For sharing with partner
var _my_role: String = ""  # "detective" or "sidekick"
var _my_player_id: String = ""
var _partner_id: String = ""
var _partner_name: String = ""

# Networking
var _last_input_send_time: float = 0.0
var _last_ping_time: float = 0.0
var _last_pong_time: float = 0.0
var _server_time_offset: float = 0.0
var _sequence_number: int = 0
var _last_received_seq: int = 0

# Reconnection
var _reconnect_attempts: int = 0
var _last_checkpoint: String = ""
var _pending_actions: Array = []

# Prediction & Interpolation
var _predicted_states: Dictionary = {}  # For client-side prediction
var _received_states: Dictionary = {}   # For interpolation

# World State Cache
var _world_progress: Dictionary = {}
var _session_state: Dictionary = {}

#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

func _ready():
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	
	# Connect to Firebase auth
	FirebaseAuth.auth_success.connect(_on_auth_success)

func _on_auth_success(user_id: String, token: String):
	_user_id = user_id
	_auth_token = token

func _process(delta: float):
	match _state:
		ConnectionState.PLAYING, ConnectionState.PAUSED:
			_process_game_loop(delta)
		ConnectionState.RECONNECTING:
			pass  # Handled by timer
	
	_poll_websocket()

#------------------------------------------------------------------------------
# Connection Management
#------------------------------------------------------------------------------

## Create a new world (Detective/Host only) - does NOT start session yet
func create_world(world_name: String) -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		return {"error": "Already connected"}
	
	_change_state(ConnectionState.CONNECTING_HTTP)
	
	# Create world via HTTP
	var create_result = await _http_request(
		"/worlds",
		HTTPClient.METHOD_POST,
		{"name": world_name, "role": "detective"}
	)
	
	if create_result.has("error"):
		_change_state(ConnectionState.DISCONNECTED)
		return create_result
	
	_world_id = create_result.world_id
	_invite_code = create_result.get("invite_code", "")
	_my_role = "detective"
	
	_change_state(ConnectionState.LOADING)  # Waiting for partner
	
	# Emit signals for backward compatibility
	emit_signal("room_code_generated", _invite_code)
	
	return create_result

## Check world status (to see if sidekick joined)
func get_world_status() -> Dictionary:
	if _world_id.is_empty():
		return {"error": "No world created"}
	
	var result = await _http_request("/worlds/" + _world_id, HTTPClient.METHOD_GET)
	return result

## Start the game session (call this when ready - after sidekick joined)
func start_game_session() -> Dictionary:
	if _my_role != "detective":
		return {"error": "Only detective can start session"}
	
	if _world_id.is_empty():
		return {"error": "No world created"}
	
	return await _start_session()

## Join an existing world by invite code (Sidekick)
func join_world(invite_code: String) -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		return {"error": "Already connected"}
	
	_change_state(ConnectionState.CONNECTING_HTTP)
	
	# Join world via HTTP
	var join_result = await _http_request(
		"/worlds/" + invite_code.to_upper() + "/join",
		HTTPClient.METHOD_POST
	)
	
	if join_result.has("error"):
		_change_state(ConnectionState.DISCONNECTED)
		return join_result
	
	_world_id = join_result.world_id
	_my_role = "sidekick"
	_partner_id = join_result.partner_id
	_partner_name = join_result.partner_name
	
	emit_signal("partner_connected", {
		"player_id": _partner_id,
		"display_name": _partner_name,
		"role": "detective" if _my_role == "sidekick" else "sidekick"
	})
	
	# Wait for detective to start session
	_change_state(ConnectionState.LOADING)
	return join_result

## Start session (called by detective after both in lobby)
func start_session() -> Dictionary:
	if _my_role != "detective":
		return {"error": "Only detective can start session"}
	
	return await _start_session()

## Continue an existing world
func continue_world(world_id: String) -> Dictionary:
	if _state != ConnectionState.DISCONNECTED:
		return {"error": "Already connected"}
	
	_change_state(ConnectionState.CONNECTING_HTTP)
	
	_world_id = world_id
	
	# Get world info
	var world_info = await _http_request("/worlds/" + world_id, HTTPClient.METHOD_GET)
	
	if world_info.has("error"):
		_change_state(ConnectionState.DISCONNECTED)
		return world_info
	
	_my_role = world_info.my_role
	_partner_id = world_info.partner_id
	_partner_name = world_info.partner_name
	
	# Try to start/join session
	return await _start_session()

## Disconnect from current session
func disconnect_from_session():
	if _state == ConnectionState.DISCONNECTED:
		return
	
	_change_state(ConnectionState.DISCONNECTING)
	
	if _ws:
		_ws.close(1000, "Client disconnect")
	
	_cleanup()
	_change_state(ConnectionState.DISCONNECTED)

#------------------------------------------------------------------------------
# Game Actions (Client → Server)
#------------------------------------------------------------------------------

## Send movement input (binary, 60Hz)
func send_move_input(direction: Vector2, sprinting: bool = false, crouching: bool = false) -> bool:
	if _state != ConnectionState.PLAYING:
		return false
	
	var now := Time.get_time_dict_from_system()
	var current_time: float = now.hour * 3600.0 + now.minute * 60.0 + now.second + now.millisecond / 1000.0
	
	if current_time - _last_input_send_time < INPUT_SEND_RATE:
		return false  # Rate limited
	
	_last_input_send_time = current_time
	
	# Build binary message: [type(1), x(4), y(4), flags(1)] = 10 bytes
	var packet := PackedByteArray()
	packet.resize(10)
	
	packet[0] = MessageTypeBinary.INPUT_MOVE
	packet.encode_float(1, direction.x)
	packet.encode_float(5, direction.y)
	
	var flags: int = 0
	if sprinting:
		flags |= 0x01
	if crouching:
		flags |= 0x02
	packet[9] = flags
	
	# Client-side prediction
	if enable_prediction:
		_apply_prediction(direction, sprinting)
	
	return _send_binary(packet)

## Send interaction action (JSON, reliable)
func send_action(action: String, target_id: String = "", target_type: String = "", 
				item_id: String = "", metadata: Dictionary = {}) -> bool:
	if _state != ConnectionState.PLAYING:
		return false
	
	return _send_json({
		"type": "input_action",
		"data": {
			"action": action,
			"target_id": target_id,
			"target_type": target_type,
			"item_id": item_id,
			"metadata": metadata
		}
	})

## Submit puzzle solution (JSON, reliable)
func submit_puzzle(puzzle_id: String, solution: Variant, attempt_time_ms: int) -> bool:
	if _state != ConnectionState.PLAYING:
		return false
	
	return _send_json({
		"type": "puzzle_attempt",
		"data": {
			"puzzle_id": puzzle_id,
			"solution": solution,
			"attempt_time_ms": attempt_time_ms
		}
	})

## Select dialogue choice (JSON, reliable)
func select_dialogue(dialogue_id: String, choice_index: int, choice_id: String = "") -> bool:
	if _state != ConnectionState.PLAYING:
		return false
	
	return _send_json({
		"type": "dialogue_choice",
		"data": {
			"dialogue_id": dialogue_id,
			"choice_index": choice_index,
			"choice_id": choice_id
		}
	})

## Request full state resync (on desync)
func request_state_sync(reason: String = "manual") -> bool:
	return _send_json({
		"type": "request_sync",
		"data": {
			"reason": reason,
			"last_known_seq": _last_received_seq
		}
	})

#------------------------------------------------------------------------------
# State Queries
#------------------------------------------------------------------------------

func get_state() -> ConnectionState:
	return _state

func has_active_connection() -> bool:
	return _state == ConnectionState.PLAYING or _state == ConnectionState.PAUSED

func is_playing() -> bool:
	return _state == ConnectionState.PLAYING

func get_my_role() -> String:
	return _my_role

func get_partner_status() -> Dictionary:
	return {
		"connected": _state == ConnectionState.PLAYING,
		"player_id": _partner_id,
		"display_name": _partner_name
	}

func get_world_progress() -> Dictionary:
	return _world_progress.duplicate()

## Get invite code for sharing with partner
func get_invite_code() -> String:
	return _invite_code

func get_current_latency_ms() -> int:
	if _last_pong_time <= _last_ping_time:
		return 999
	return int((_last_pong_time - _last_ping_time) * 1000)

#------------------------------------------------------------------------------
# Private Implementation
#------------------------------------------------------------------------------

func _change_state(new_state: ConnectionState):
	if _state == new_state:
		return
	
	var old_state := _state
	_state = new_state
	emit_signal("connection_state_changed", new_state, old_state)
	
	print("[Network] State: ", _state_name(old_state), " -> ", _state_name(new_state))

func _state_name(s: int) -> String:
	match s:
		ConnectionState.DISCONNECTED: return "DISCONNECTED"
		ConnectionState.CONNECTING_HTTP: return "CONNECTING_HTTP"
		ConnectionState.CONNECTING_WS: return "CONNECTING_WS"
		ConnectionState.HANDSHAKE: return "HANDSHAKE"
		ConnectionState.LOADING: return "LOADING"
		ConnectionState.READY: return "READY"
		ConnectionState.PLAYING: return "PLAYING"
		ConnectionState.PAUSED: return "PAUSED"
		ConnectionState.RECONNECTING: return "RECONNECTING"
		ConnectionState.DISCONNECTING: return "DISCONNECTING"
		_: return "UNKNOWN"

func _http_request(path: String, method: int, body: Dictionary = {}) -> Dictionary:
	# Debug: Check auth token
	if _auth_token.is_empty():
		push_warning("[Network] Auth token is empty! Make sure FirebaseAuth is working.")
		return {"error": "Not authenticated", "message": "Auth token is empty"}
	
	print("[Network] HTTP Request: ", API_BASE + path)
	print("[Network] Auth token (first 20 chars): ", _auth_token.substr(0, 20), "...")
	
	var headers := [
		"Authorization: Bearer " + _auth_token,
		"Content-Type: application/json",
		"X-Client-Version: " + ProjectSettings.get_setting("application/config/version", "1.0.0")
	]
	
	var body_str := ""
	if not body.is_empty():
		body_str = JSON.stringify(body)
		print("[Network] Request body: ", body_str)
	
	var err := _http.request(API_BASE + path, headers, method, body_str)
	
	if err != OK:
		print("[Network] Request setup failed: ", err)
		return {"error": "Request failed", "code": err}
	
	print("[Network] Waiting for response...")
	var result: Array = await _http.request_completed
	
	print("[Network] Response received: result_code=", result[0], ", http_code=", result[1])
	
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		print("[Network] HTTP request failed with result code: ", result[0])
		return {"error": "HTTP error", "result": result[0]}
	
	var response_code: int = result[1]
	var response_body: String = result[3].get_string_from_utf8()
	
	print("[Network] Response body: ", response_body.substr(0, 200))
	
	var json: Variant = JSON.parse_string(response_body)
	
	if json == null:
		print("[Network] Failed to parse JSON response")
		return {"error": "Invalid JSON", "body": response_body}
	
	if response_code >= 400:
		print("[Network] HTTP error code: ", response_code)
		json["http_code"] = response_code
		return json
	
	print("[Network] Request successful")
	return json

func _start_session() -> Dictionary:
	_change_state(ConnectionState.CONNECTING_HTTP)
	
	var result := await _http_request(
		"/worlds/" + _world_id + "/start",
		HTTPClient.METHOD_POST
	)
	
	if result.has("error"):
		_change_state(ConnectionState.DISCONNECTED)
		return result
	
	_session_id = result.session_id
	_last_checkpoint = result.checkpoint
	_world_progress = result.world_progress
	
	# Connect WebSocket
	_change_state(ConnectionState.CONNECTING_WS)
	
	var ws_url: String = result.ws_url + "&token=" + _auth_token.uri_encode()
	
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(ws_url)
	
	if err != OK:
		_change_state(ConnectionState.DISCONNECTED)
		return {"error": "WebSocket connection failed", "code": err}
	
	# Wait for connection
	var timeout := 0.0
	while _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_ws.poll()
		await get_tree().process_frame
		timeout += get_process_delta_time()
		if timeout > 10.0:
			_change_state(ConnectionState.DISCONNECTED)
			return {"error": "Connection timeout"}
	
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_change_state(ConnectionState.DISCONNECTED)
		return {"error": "WebSocket failed to open"}
	
	_change_state(ConnectionState.HANDSHAKE)
	return {"success": true}

func _poll_websocket():
	if not _ws:
		return
	
	_ws.poll()
	
	var state: int = _ws.get_ready_state()
	
	match state:
		WebSocketPeer.STATE_CLOSED:
			if _state != ConnectionState.DISCONNECTED and _state != ConnectionState.DISCONNECTING:
				_handle_disconnect()
			return
		
		WebSocketPeer.STATE_CLOSING:
			return
		
		WebSocketPeer.STATE_CONNECTING:
			return
	
	# Process incoming messages
	while _ws.get_available_packet_count() > 0:
		var packet := _ws.get_packet()
		_handle_packet(packet)

func _handle_packet(packet: PackedByteArray):
	if packet.is_empty():
		return
	
	var first_byte := packet[0]
	
	# Check if binary or JSON
	if first_byte == MessageTypeBinary.STATE_PLAYER or first_byte == MessageTypeBinary.PONG:
		_handle_binary_message(packet)
	else:
		# Try JSON
		var text := packet.get_string_from_utf8()
		var json: Variant = JSON.parse_string(text)
		
		if json != null and json.has("type"):
			_handle_json_message(json)
		else:
			push_warning("[Network] Unknown message format: ", text)

func _handle_binary_message(packet: PackedByteArray):
	var msg_type := packet[0]
	
	match msg_type:
		MessageTypeBinary.STATE_PLAYER:
			_parse_player_state(packet)
		
		MessageTypeBinary.PONG:
			_last_pong_time = Time.get_unix_time_from_system()
			var server_time := packet.decode_double(1)
			_server_time_offset = server_time - _last_pong_time
			emit_signal("latency_updated", get_current_latency_ms())

func _parse_player_state(packet: PackedByteArray):
	# Format: [type(1), count(1), [player_id(1), x(4), y(4), vx(4), vy(4), state(1)]...]
	if packet.size() < 2:
		return
	
	var count := packet[1]
	var offset := 2
	var player_size := 15  # 1 + 4 + 4 + 4 + 4 + 1 + 4 (facing as int) = 22? Let me recalculate
	# Actually: player_id(1) + x(4) + y(4) + vx(4) + vy(4) + state(1) = 18 bytes
	player_size = 18
	
	for i in range(count):
		if offset + player_size > packet.size():
			break
		
		var player_id_byte := packet[offset]
		var x := packet.decode_float(offset + 1)
		var y := packet.decode_float(offset + 5)
		var vx := packet.decode_float(offset + 9)
		var vy := packet.decode_float(offset + 13)
		var state_byte := packet[offset + 17]
		
		var player_id := "player_" + str(player_id_byte)
		
		var facing := "down"
		match state_byte & 0x03:
			0: facing = "down"
			1: facing = "up"
			2: facing = "left"
			3: facing = "right"
		
		var animation_states := ["idle", "walk", "run", "jump", "fall", "interact"]
		var anim_index := (state_byte >> 2) & 0x0F
		var animation: String = animation_states[mini(anim_index, animation_states.size() - 1)]
		
		var controllable := (state_byte & 0x40) != 0
		
		var player_state := {
			"player_id": player_id,
			"position": Vector2(x, y),
			"velocity": Vector2(vx, vy),
			"facing": facing,
			"animation": animation,
			"controllable": controllable
		}
		
		_received_states[player_id] = player_state
		emit_signal("player_state_received", player_id, player_state)
		
		offset += player_size

func _handle_json_message(msg: Dictionary):
	# Update sequence number
	if msg.has("seq"):
		_last_received_seq = msg.seq
	
	if msg.has("timestamp"):
		# Could use for lag compensation
		pass
	
	var msg_type: String = msg.get("type", "")
	var data: Dictionary = msg.get("data", {})
	
	match msg_type:
		"session_start":
			_handle_session_start(data)
		
		"game_started":
			_handle_game_started(data)
		
		"game_resumed":
			_handle_game_resumed(data)
		
		"state_world":
			_handle_state_world(data)
		
		"event_action":
			emit_signal("action_result_received", data)
		
		"event_puzzle":
			emit_signal("puzzle_result_received", data)
		
		"event_story":
			emit_signal("story_event_received", data)
		
		"event_inventory":
			emit_signal("inventory_changed", data)
		
		"partner_status":
			_handle_partner_status(data)
		
		"error":
			_handle_error(data)
		
		"force_sync":
			_handle_force_sync(data)
		
		_:
			push_warning("[Network] Unknown message type: ", msg_type)

func _handle_session_start(data: Dictionary):
	_my_player_id = data.your_player_id
	_my_role = data.your_role
	_world_progress = data.world_progress
	_session_state = data.session_state
	
	if data.has("partner"):
		_partner_id = data.partner.player_id
		_partner_name = data.partner.display_name
	
	_last_checkpoint = data.checkpoint.zone_id
	
	_change_state(ConnectionState.LOADING)
	emit_signal("session_started", data)
	
	# Backward compatibility
	emit_signal("connection_established", 1 if _my_role == "detective" else 2)
	if _my_role == "sidekick":
		emit_signal("role_assignment_received", 1)  # SIDEKICK role

func _handle_game_started(data: Dictionary):
	_change_state(ConnectionState.PLAYING)
	emit_signal("game_started", data.checkpoint)
	
	# Backward compatibility
	emit_signal("player_joined", 2 if _my_role == "detective" else 1, 1 if _my_role == "detective" else 0)

func _handle_game_resumed(data: Dictionary):
	_world_progress = data.progress
	_change_state(ConnectionState.PLAYING)
	emit_signal("game_resumed")

func _handle_state_world(data: Variant):
	# Update world state
	if data is Dictionary:
		_session_state["time_of_day"] = data.get("time_of_day", "day")
		_session_state["active_objects"] = data.get("active_objects", [])
		_session_state["active_npcs"] = data.get("active_npcs", [])

func _handle_partner_status(data: Variant):
	if data is Dictionary:
		match data.get("status", ""):
			"connected":
				if int(_state) == int(ConnectionState.PAUSED):
					_change_state(ConnectionState.PLAYING)
				emit_signal("partner_connected", data)
				emit_signal("game_resumed")
			"disconnected":
				if int(_state) == int(ConnectionState.PLAYING):
					_change_state(ConnectionState.PAUSED)
				emit_signal("partner_disconnected", data)
				emit_signal("game_paused", "partner_disconnected")

func _handle_error(data: Dictionary):
	emit_signal("error_received", data)
	
	# Backward compatibility
	if data.has("message"):
		emit_signal("connection_failed", data.message)
	
	if data.get("fatal", false):
		disconnect_from_session()

func _handle_force_sync(data: Dictionary):
	# Apply forced state update
	if data.has("player_states"):
		for player_id in data.player_states:
			var state: Dictionary = data.player_states[player_id]
			_received_states[player_id] = state
	
	if data.has("world_state"):
		_session_state = data.world_state
	
	if data.has("sequence_reset"):
		_last_received_seq = data.sequence_reset

func _process_game_loop(_delta: float):
	var now := Time.get_unix_time_from_system()
	
	# Send ping every second
	if now - _last_ping_time >= PING_INTERVAL:
		_last_ping_time = now
		_send_ping()

func _send_ping() -> bool:
	var packet := PackedByteArray()
	packet.resize(1)
	packet[0] = MessageTypeBinary.PING
	return _send_binary(packet)

func _send_binary(packet: PackedByteArray) -> bool:
	if not _ws or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	
	return _ws.send(packet, WebSocketPeer.WRITE_MODE_BINARY) == OK

func _send_json(data: Dictionary) -> bool:
	if not _ws or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	
	_sequence_number += 1
	
	var envelope := {
		"type": data.type,
		"timestamp": int(Time.get_unix_time_from_system() * 1000),
		"seq": _sequence_number,
		"data": data.data
	}
	
	var json := JSON.stringify(envelope)
	return _ws.send_text(json) == OK

func _apply_prediction(direction: Vector2, sprinting: bool):
	# Simple client-side prediction
	var speed := MAX_SPRINT_SPEED if sprinting else MAX_WALK_SPEED
	var predicted_velocity := direction * speed
	
	_predicted_states[_my_player_id] = {
		"velocity": predicted_velocity,
		"timestamp": Time.get_unix_time_from_system()
	}

func _handle_disconnect():
	if _state == ConnectionState.DISCONNECTING:
		_cleanup()
		_change_state(ConnectionState.DISCONNECTED)
		return
	
	# Unexpected disconnect - try to reconnect
	if _reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
		_reconnect_attempts += 1
		_change_state(ConnectionState.RECONNECTING)
		
		print("[Network] Reconnecting... attempt ", _reconnect_attempts)
		
		await get_tree().create_timer(RECONNECT_DELAY).timeout
		
		if _state == ConnectionState.RECONNECTING:
			var result: Dictionary = await _start_session()
			
			if result.has("success"):
				_reconnect_attempts = 0
				request_state_sync("reconnect")
			else:
				# Try again or give up
				if _reconnect_attempts >= MAX_RECONNECT_ATTEMPTS:
					_cleanup()
					_change_state(ConnectionState.DISCONNECTED)
					emit_signal("error_received", {
						"code": "RECONNECT_FAILED",
						"message": "Failed to reconnect after " + str(MAX_RECONNECT_ATTEMPTS) + " attempts"
					})
	else:
		_cleanup()
		_change_state(ConnectionState.DISCONNECTED)

func _cleanup():
	if _ws:
		_ws.close()
		_ws = null
	
	_session_id = ""
	_world_id = ""
	_invite_code = ""
	_my_player_id = ""
	_partner_id = ""
	_partner_name = ""
	_reconnect_attempts = 0
	_predicted_states.clear()
	_received_states.clear()
	_pending_actions.clear()

#------------------------------------------------------------------------------
# Utility Functions
#------------------------------------------------------------------------------

## Get interpolated player position (for smooth rendering)
func get_interpolated_position(player_id: String) -> Vector2:
	if not _received_states.has(player_id):
		return Vector2.ZERO
	
	var state: Dictionary = _received_states[player_id]
	return state.position

## Check if player is controllable (not in cutscene)
func is_player_controllable() -> bool:
	if not _received_states.has(_my_player_id):
		return false
	
	return _received_states[_my_player_id].get("controllable", true)

#==============================================================================
# BACKWARD COMPATIBILITY API (Old NetworkManager interface)
#==============================================================================

## Legacy host game function - NOW only creates world, doesn't start session
## Use create_world() then poll for partner, then call start_game_session()
func host_game() -> bool:
	# DEV MODE: Skip server for UI testing
	# Uncomment the code below to test without server:
	# await get_tree().create_timer(0.5).timeout
	# _my_role = "detective"
	# emit_signal("connection_established", 1)
	# emit_signal("room_code_generated", "ABC123")
	# return true
	
	var result = await create_world("Game")
	if result.has("error"):
		emit_signal("connection_failed", result.error)
		return false
	emit_signal("room_code_generated", result.get("invite_code", ""))
	# Note: Session is NOT started yet - wait for sidekick to join!
	return true

## Legacy join game function
func join_game_with_code(code: String) -> bool:
	var result = await join_world(code)
	if result.has("error"):
		emit_signal("connection_failed", result.error)
		return false
	return true

## Legacy join game function (direct IP - not supported in new system)
func join_game(ip: String = "") -> bool:
	push_warning("Direct IP connection not supported. Use join_game_with_code().")
	return false

## Legacy disconnect function
func disconnect_network():
	disconnect_from_session()

## Legacy start game function
func start_game():
	if _my_role == "detective":
		start_session()

## Legacy role check
func get_player_role() -> String:
	return _my_role

## Legacy room code getter
func get_room_code() -> String:
	return _invite_code if not _invite_code.is_empty() else _world_id

## Legacy connection check
func is_network_connected() -> bool:
	return has_active_connection()

## Legacy player check
func is_player_connected() -> bool:
	return _state == ConnectionState.PLAYING
