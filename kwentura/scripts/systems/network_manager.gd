extends Node

const PORT := 7777
const MAX_PLAYERS := 2

var multiplayer_peer: ENetMultiplayerPeer
var players := {}

signal player_connected(peer_id)
signal player_disconnected(peer_id)

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# HOST GAME
func host_game():
	multiplayer_peer = ENetMultiplayerPeer.new()
	multiplayer_peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Server started")

# JOIN GAME
func join_game(ip_address: String):
	multiplayer_peer = ENetMultiplayerPeer.new()
	multiplayer_peer.create_client(ip_address, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Joining server at ", ip_address)

func _on_peer_connected(peer_id):
	print("Player connected: ", peer_id)
	players[peer_id] = {}
	emit_signal("player_connected", peer_id)

func _on_peer_disconnected(peer_id):
	print("Player disconnected: ", peer_id)
	players.erase(peer_id)
	emit_signal("player_disconnected", peer_id)
