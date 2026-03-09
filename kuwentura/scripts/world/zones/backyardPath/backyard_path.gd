extends Node2D

## Backyard Path - Test zone with position save/restore

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton

var clue_collected: bool = false


func _ready():
	print("[BackyardPath] Scene loaded!")
	
	var role_text = "Unknown"
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"
	
	role_label.text = "Role: " + role_text
	print("[BackyardPath] Local role: ", role_text, " | Peer ID: ", multiplayer.get_unique_id())
	
	var saved_pos = GameState.get_spawn_position(multiplayer.get_unique_id())
	if saved_pos != Vector2.ZERO:
		print("[BackyardPath] Will return to Forest Hub at position: ", saved_pos)
	
	GameState.clue_collected.connect(_on_clue_collected)


func _on_back_pressed():
	print("[BackyardPath] Returning to Forest Hub...")
	_return_to_forest()


func _on_clue_collected(zone_id: String, _clue_data: Dictionary):
	if zone_id == "backyard_path" and not clue_collected:
		clue_collected = true
		print("[BackyardPath] Clue collected! Auto-returning in 3 seconds...")
		role_label.text = "Clue collected! Returning..."
		await get_tree().create_timer(3.0).timeout
		_return_to_forest()


func _return_to_forest():
	print("[BackyardPath] Teleporting back to Forest Hub")
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
