extends Node
## Tracks collected clues for the Bakunawa challenge.

signal clue_added(zone_name: String)

var collected_clues: Array[String] = []


func add_clue(zone_name: String, _clue_data: Dictionary = {}) -> void:
	if has_clue(zone_name):
		return
	collected_clues.append(zone_name)
	clue_added.emit(zone_name)


func get_clue_count() -> int:
	return collected_clues.size()


func has_clue(zone_name: String) -> bool:
	return zone_name in collected_clues
