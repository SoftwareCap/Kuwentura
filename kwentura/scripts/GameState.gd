extends Node

var collected_clues: Array[String] = []

func add_clue(clue: String):
	if not clue in collected_clues:
		collected_clues.append(clue)
		print("Clue collected:", clue)
