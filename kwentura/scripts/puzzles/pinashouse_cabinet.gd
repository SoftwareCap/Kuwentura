extends StaticBody2D

func _on_body_entered(body):
	if body.name == "Player":
		# Show puzzle UI (we'll build this next)
		get_tree().get_root().get_node("UI").show_puzzle("zone1_algebra")
