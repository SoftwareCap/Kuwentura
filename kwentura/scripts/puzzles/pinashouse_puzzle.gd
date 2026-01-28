extends Node

var host_view = "x + y = 10\ny - z = 2\nz = 3"
var sidekick_view = "□ + □ = 10\n□ - □ = 2\n□ = 3"
var solution = "x=5, y=5, z=3"

func is_correct_answer(answer: String) -> bool:
	return answer.strip_edges().to_lower() == "5,5,3"

func on_player_submit(answer: String):
	if is_correct_answer(answer):
		# Use Autoload for global state (safer than /root/World)
		GameState.add_clue("ladle")
		# Emit signal or notify UI manager to hide puzzle
		emit_signal("puzzle_solved")
