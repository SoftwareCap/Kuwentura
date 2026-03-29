extends Node2D

## Main game controller — scene entry point.

const SCENE_PLAZA: String = "res://scenes/world/hub/Plaza.tscn"
const SCENE_ZONE_PATH: String = "res://scenes/world/zones/%s/%s.tscn"

@onready var hud: Node = $HUD

var puzzle_ui: Control = null

var _puzzle_ui_scene: PackedScene = preload("res://scenes/ui/PuzzleUI.tscn")


func _ready() -> void:
	puzzle_ui = _puzzle_ui_scene.instantiate()
	add_child(puzzle_ui)
	puzzle_ui.visible = false


func show_puzzle(puzzle_id: String) -> void:
	puzzle_ui.set_puzzle(puzzle_id, GameState.local_role)
	puzzle_ui.visible = true


func hide_puzzle() -> void:
	puzzle_ui.visible = false


func enter_zone(zone_name: String) -> void:
	if GameState.has_clue(zone_name):
		return
	GameState.current_zone = zone_name
	get_tree().change_scene_to_file(
		SCENE_ZONE_PATH % [zone_name, zone_name.to_pascal_case()]
	)


func return_to_hub() -> void:
	GameState.current_zone = "plaza"
	get_tree().change_scene_to_file(SCENE_PLAZA)


func collect_clue(zone_id: String) -> void:
	GameState.collect_clue(zone_id)
	if _all_clues_collected():
		start_climax()


func _all_clues_collected() -> bool:
	for zone_id in GameState.collected_clues:
		if not GameState.collected_clues[zone_id].get("collected", false):
			return false
	return true


func start_climax() -> void:
	return_to_hub()
