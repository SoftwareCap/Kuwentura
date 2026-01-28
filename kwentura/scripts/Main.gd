# res://scenes/Main.gd
# This is your main game controller.
# Attach this script to the root node of your main scene (e.g., Main.tscn).

extends Node2D

# --- References to key UI elements ---
@onready var hud = $HUD  # Your HUD/UI container (e.g., health, clues, etc.)
@onready var puzzle_ui = $PuzzleUI  # Your puzzle UI panel (from your file structure)

# --- Game State (temporary until you use LevelManager autoload) ---
var current_zone: String = "plaza"
var collected_clues: Dictionary = {
	"zone1": false,
	"zone2": false,
	"zone3": false,
	"zone4": false,
	"zone5": false
}

# --- Player Roles (for single-player prototype simulation) ---
enum Role { HOST, SIDEKICK }
var local_role: int = Role.HOST  # Change to SIDEKICK to test other view

var puzzle_ui_scene = preload("res://scenes/ui/PuzzleUI.tscn")

func _ready():
	# Hide all UI panels at start
	_hide_all_ui()
	
	puzzle_ui = puzzle_ui_scene.instantiate()  # Godot 4 syntax
	add_child(puzzle_ui)
	puzzle_ui.visible = true
	# Optional: Load player preferences or last zone
	# print("Kuwentura started in landscape mode.")

# --- UI Management ---
func show_puzzle(puzzle_id: String):
	puzzle_ui.set_puzzle(puzzle_id, local_role)
	puzzle_ui.visible = true

func hide_puzzle():
	puzzle_ui.visible = false

func _hide_all_ui():
	if puzzle_ui:
		puzzle_ui.visible = false
	# Add other UI panels here as needed

# --- Scene & Progression ---
func enter_zone(zone_name: String):
	if not collected_clues.get(zone_name, false):
		current_zone = zone_name
		get_tree().change_scene_to_file("res://scenes/world/zones/%s/%s.tscn" % [zone_name, zone_name.to_pascal_case()])
	else:
		print("Zone %s already completed." % zone_name)

func return_to_hub():
	current_zone = "plaza"
	get_tree().change_scene_to_file("res://scenes/world/hub/Plaza.tscn")

func collect_clue(zone_id: String):
	collected_clues[zone_id] = true
	print("Clue collected from: %s" % zone_id)
	
	# Check if all clues are collected → trigger climax
	if _all_clues_collected():
		start_climax()

func _all_clues_collected() -> bool:
	for value in collected_clues.values():
		if not value:
			return false
	return true

func start_climax():
	print("Bakunawa eats the moon! Starting climax sequence...")
	# TODO: Load climax scene or trigger event in Plaza
	return_to_hub()  # For now, just go back to hub

# --- Debug / Testing Helpers ---
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Press ESC or Back button to return to hub (useful for testing)
		if current_zone != "plaza":
			return_to_hub()
