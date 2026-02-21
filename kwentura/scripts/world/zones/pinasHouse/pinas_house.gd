extends Node2D

## Temporary Pina's House - For testing zone portal with position save/restore

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton

# Flag to track if clue was collected (for auto-return)
var clue_collected: bool = false


func _ready():
	print("[PinasHouse] Scene loaded!")
	
	# Display role for testing
	var role_text = "Unknown"
	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"
	
	role_label.text = "Role: " + role_text
	print("[PinasHouse] Local role: ", role_text, " | Peer ID: ", multiplayer.get_unique_id())
	
	# Show saved position info
	var saved_pos = GameState.get_spawn_position(multiplayer.get_unique_id())
	if saved_pos != Vector2.ZERO:
		print("[PinasHouse] Will return to Forest Hub at position: ", saved_pos)
	
	# Connect to clue collection signal for auto-return
	GameState.clue_collected.connect(_on_clue_collected)


func _on_back_pressed():
	print("[PinasHouse] Returning to Forest Hub...")
	_return_to_forest()


func _on_clue_collected(zone_id: String, _clue_data: Dictionary):
	# Check if this is the clue for Pina's House
	if zone_id == "pinas_house" and not clue_collected:
		clue_collected = true
		print("[PinasHouse] Clue collected! Auto-returning to Forest Hub in 3 seconds...")
		
		# Update UI to show returning
		role_label.text = "Clue collected! Returning..."
		
		# Wait for the collection effect to show, then return
		await get_tree().create_timer(3.0).timeout
		_return_to_forest()


func _return_to_forest():
	"""Return to Forest Hub using saved positions."""
	print("[PinasHouse] Teleporting back to Forest Hub at saved position")
	
	# The spawn positions are already saved in GameState from when we entered
	# ForestHub._spawn_player_for_peer will use them automatically
	
	get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")
