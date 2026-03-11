extends StaticBody2D


func _on_body_entered(body):
	if body.name == "Player":
		# Show puzzle UI (we'll build this next)
		get_tree().get_root().get_node("UI").show_puzzle("pinashouse_puzzle")
		get_node("/root/Main").puzzle_ui.show_puzzle("pinashouse_puzzle")
