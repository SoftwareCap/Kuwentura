extends Node

# SIGNALS
signal puzzle_solved

# CONSTANTS — single source of truth for all puzzle data
const CLUE_ID := "ladle"
const ANSWER := "5,5,3"

# Equation lines defined once; both views are derived from the same structure
const _LINES := [
	["x", "y", "+", "10"],
	["y", "z", "-", "2" ],
	["z", "", "=", "3" ],
]

const HOST_VIEW: String = (
	"x + y = 10\n"
	+ "y - z = 2\n"
	+ "z = 3"
)

const SIDEKICK_VIEW: String = (
	"□ + □ = 10\n"
	+ "□ - □ = 2\n"
	+ "□ = 3"
)

const SOLUTION: String = "x=5, y=5, z=3"


# LOGIC
func is_correct_answer(answer: String) -> bool:
	return answer.strip_edges().to_lower() == ANSWER


func on_player_submit(answer: String) -> void:
	if is_correct_answer(answer):
		GameState.add_clue(CLUE_ID)
		puzzle_solved.emit()
