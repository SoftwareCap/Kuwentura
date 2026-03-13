extends Node

#==============================================================================
# CLUE MANAGER
# Tracks collected clues for the Bakunawa challenge
#==============================================================================

var collected_clues: Array = []
var clue_count: int = 0


func add_clue(zone_name: String, _clue_data: Dictionary) -> void:
	if zone_name in collected_clues:
		return

	collected_clues.append(zone_name)
	clue_count += 1

	print("Clue collected from zone:", zone_name)
	print("Total clues:", clue_count)


func get_clue_count() -> int:
	return clue_count


func has_clue(zone_name: String) -> bool:
	return zone_name in collected_clues
