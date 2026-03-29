extends StaticBody2D

const PUZZLE_ID := "pinashouse_puzzle"

@onready var puzzle_ui = get_node("/root/Main").puzzle_ui


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		puzzle_ui.show_puzzle(PUZZLE_ID)
