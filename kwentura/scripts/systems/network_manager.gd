extends Node

const PORT: int = 7777
const MAX_PLAYERS: int = 2
const DEFAULT_IP: String = "127.0.0.1"

# WebSocket relay server (localhost for testing)
const RELAY_SERVER_URL: String = "ws://localhost:10001"  # ws:// for localhost (not wss://)
const USE_RELAY: bool = true  # Toggle between direct and relay connection

var is_hosting: bool = false

enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED, HOSTING }

var multiplayer_peer: WebSocketMultiplayerPeer  # Changed to WebSocket for relay
var connection_state: ConnectionState = ConnectionState.DISCONNECTED
var players: Dictionary = {}
var local_peer_id: int = 0

# Room code system
var current_room_code: String = ""
var target_room_code: String = ""

# HTTP for matchmaking
var http_request: HTTPRequest

# Signals
signal connection_established(peer_id: int)
signal player_joined(peer_id: int, role: GameState.Role)
signal player_left(peer_id: int)
signal connection_failed(error: String)
signal role_assignment_received(role: GameState.Role)
signal game_started
signal peer_disconnected
signal restart_requested
signal restart_confirmed
signal room_code_generated(code: String)

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Setup HTTP for matchmaking
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
	# Poll WebSocket in process
	set_process(true)

func _process(_delta):
	# Required for WebSocket multiplayer to work
	if multiplayer_peer:
		multiplayer_peer.poll()

# Generate a random 6-character room code
func _generate_room_code() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code = ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	return code

func host_game() -> bool:
	if USE_RELAY:
		return _host_with_relay()
	else:
		return _host_direct()

func _host_direct() -> bool:
	# Direct connection (LAN only) - uses ENet
	var enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_server(PORT, MAX_PLAYERS)
	
	if error != OK:
		emit_signal("connection_failed", "Failed to create server: " + str(error))
		return false
	
	multiplayer.multiplayer_peer = enet_peer
	_setup_host_common()
	
	current_room_code = _generate_room_code()
	emit_signal("room_code_generated", current_room_code)
	
	print("Direct server started on port ", PORT)
	emit_signal("connection_established", local_peer_id)
	return true

func _host_with_relay() -> bool:
	# Use WebSocket relay for connections
	multiplayer_peer = WebSocketMultiplayerPeer.new()
	
	# Create WebSocket server on local port
	var error = multiplayer_peer.create_server(PORT)
	
	if error != OK:
		emit_signal("connection_failed", "Failed to create WebSocket server: " + str(error))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	_setup_host_common()
	
	# Generate and register room code
	current_room_code = _generate_room_code()
	_register_room_with_matchmaker(current_room_code, true)
	
	emit_signal("room_code_generated", current_room_code)
	print("Relay host created, code: ", current_room_code)
	emit_signal("connection_established", local_peer_id)
	return true

func _setup_host_common():
	connection_state = ConnectionState.HOSTING
	is_hosting = true
	local_peer_id = multiplayer.get_unique_id()
	GameState.assign_role(GameState.Role.DETECTIVE)
	players[local_peer_id] = {"role": GameState.Role.DETECTIVE, "ready": false}

func _register_room_with_matchmaker(room_code: String, is_host: bool):
	# Register with local relay server via HTTP
	var url = RELAY_SERVER_URL.replace("ws://", "http://") + "/register"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"room_code": room_code,
		"is_host": is_host,
		"local_port": PORT
	})
	
	http_request.set_meta("action", "register")
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func join_game_with_code(room_code: String) -> bool:
	room_code = room_code.to_upper().strip_edges()
	target_room_code = room_code
	
	if USE_RELAY:
		return _join_with_relay(room_code)
	else:
		return join_game(DEFAULT_IP)

func _join_with_relay(room_code: String) -> bool:
	# Query relay server for connection info
	var url = RELAY_SERVER_URL.replace("ws://", "http://") + "/join?room=" + room_code
	http_request.set_meta("action", "join_room")
	http_request.set_meta("room_code", room_code)
	http_request.request(url)
	
	print("Looking up room: ", room_code)
	return true

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if _result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP request failed: ", _result)
		return
	
	var action = http_request.get_meta("action", "")
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	match action:
		"register":
			if response_code == 200:
				print("Room registered with relay server")
			else:
				print("Failed to register room: ", response_code)
		
		"join_room":
			_handle_join_response(json)

func _handle_join_response(json: Dictionary):
	if json == null or json.has("error"):
		var error_msg = json.get("error", "Room not found") if json else "Invalid response"
		emit_signal("connection_failed", error_msg)
		return
	
	# Connect to the relay server
	var host_url = json.get("relay_url", RELAY_SERVER_URL + "?room=" + target_room_code)
	_connect_to_relay(host_url)

func _connect_to_relay(relay_url: String):
	multiplayer_peer = WebSocketMultiplayerPeer.new()
	
	# Connect as client to relay server
	var error = multiplayer_peer.create_client(relay_url)
	
	if error != OK:
		emit_signal("connection_failed", "Failed to connect to relay: " + str(error))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	connection_state = ConnectionState.CONNECTING
	local_peer_id = multiplayer.get_unique_id()
	
	print("Connecting to relay: ", relay_url)
	return true

func join_game(ip_address: String = DEFAULT_IP) -> bool:
	# Fallback direct connection
	var enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_client(ip_address, PORT)
	
	if error != OK:
		emit_signal("connection_failed", "Failed to create client: " + str(error))
		return false
	
	multiplayer.multiplayer_peer = enet_peer
	connection_state = ConnectionState.CONNECTING
	local_peer_id = multiplayer.get_unique_id()
	
	print("Connecting directly to ", ip_address, ":", PORT)
	return true

func _on_connected_to_server():
	connection_state = ConnectionState.CONNECTED
	local_peer_id = multiplayer.get_unique_id()
	print("Connected! Peer ID: ", local_peer_id)
	emit_signal("connection_established", local_peer_id)

func _on_connection_failed():
	connection_state = ConnectionState.DISCONNECTED
	emit_signal("connection_failed", "Connection failed")
	print("Connection failed")

func _on_server_disconnected():
	connection_state = ConnectionState.DISCONNECTED
	emit_signal("connection_failed", "Server disconnected")
	print("Server disconnected")

func _on_peer_connected(peer_id: int):
	print("Peer connected: ", peer_id)
	
	if multiplayer.is_server():
		var role = GameState.Role.SIDEKICK
		players[peer_id] = {"role": role, "ready": false}
		_rpc_assign_role.rpc_id(peer_id, role)
		emit_signal("player_joined", peer_id, role)
		_sync_game_state.rpc_id(peer_id, GameState.get_save_data())

func _on_peer_disconnected(peer_id: int):
	print("Peer disconnected: ", peer_id)
	players.erase(peer_id)
	emit_signal("player_left", peer_id)
	
	if not multiplayer.is_server():
		connection_state = ConnectionState.DISCONNECTED
		emit_signal("peer_disconnected")

@rpc("authority", "reliable")
func _rpc_assign_role(role: GameState.Role):
	GameState.assign_role(role)
	emit_signal("role_assignment_received", role)
	print("Role assigned: ", GameState.Role.keys()[role])

@rpc("authority", "reliable")
func _sync_game_state(state_data: Dictionary):
	GameState.load_save_data(state_data)
	print("State synced")

func start_game():
	if multiplayer.is_server():
		_rpc_start_game.rpc()

@rpc("authority", "reliable")
func _rpc_start_game():
	emit_signal("game_started")
	print("Game started!")

func disconnect_network():
	if multiplayer_peer:
		multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	connection_state = ConnectionState.DISCONNECTED
	is_hosting = false
	current_room_code = ""
	target_room_code = ""
	players.clear()
	print("Disconnected")

@rpc("any_peer", "reliable")
func sync_clue_collection(zone_id: String):
	if multiplayer.is_server():
		GameState.collect_clue(zone_id)
		_broadcast_clue_collection.rpc(zone_id)

@rpc("authority", "reliable")
func _broadcast_clue_collection(zone_id: String):
	if not multiplayer.is_server():
		GameState.collect_clue(zone_id)

@rpc("any_peer", "reliable")
func request_zone_change(zone_id: String):
	if multiplayer.is_server():
		_approve_zone_change.rpc(zone_id)

@rpc("authority", "reliable")
func _approve_zone_change(zone_id: String):
	GameState.current_zone = zone_id
	get_tree().change_scene_to_file("res://scenes/world/zones/%s/%s.tscn" % [zone_id, zone_id.to_pascal_case()])

func request_restart():
	if multiplayer.is_server():
		_broadcast_restart_request.rpc()

@rpc("authority", "reliable")
func _broadcast_restart_request():
	emit_signal("restart_requested")
	_show_restart_dialog()

func _show_restart_dialog():
	var dialog = ConfirmationDialog.new()
	dialog.title = "Play Again?"
	dialog.dialog_text = "Detective wants to play again. Join?"
	dialog.ok_button_text = "Yes!"
	dialog.cancel_button_text = "No"
	dialog.confirmed.connect(_accept_restart)
	dialog.canceled.connect(_decline_restart)
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _accept_restart():
	_confirm_restart.rpc_id(1)

func _decline_restart():
	disconnect_network()
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")

@rpc("any_peer", "reliable")
func _confirm_restart():
	emit_signal("restart_confirmed")
	_start_restart_sequence()

func _start_restart_sequence():
	_rpc_start_game.rpc()
