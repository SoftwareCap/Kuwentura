extends Node

var host_view = "x + y = 10\ny - z = 2\nz = 3"
var sidekick_view = "□ + □ = 10\n□ - □ = 2\n□ = 3"
var solution = "x=5, y=5, z=3"  # Correct answer

func solve(answer: String) -> bool:
	return answer.strip_edges().to_lower() == "5,5,3"
