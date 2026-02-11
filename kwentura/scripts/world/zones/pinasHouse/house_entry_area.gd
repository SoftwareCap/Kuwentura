extends Area2D

var players_inside = []

func _on_body_entered(body):

	if body.is_in_group("players"):
		if body not in players_inside:
			players_inside.append(body)

		check_players()

func _on_body_exited(body):

	if body in players_inside:
		players_inside.erase(body)

func check_players():

	var unique_players = {}

	for p in players_inside:
		unique_players[p.get_multiplayer_authority()] = true

	if unique_players.size() >= 2:
		allow_enter_house()

func allow_enter_house():

	if multiplayer.is_server():
		rpc("enter_house")

@rpc("call_local")
func enter_house():
	get_tree().get_root().get_node("UI").show_puzzle("pinashouse_puzzle")
	get_node("/root/Main").puzzle_ui.show_puzzle("pinashouse_puzzle")
