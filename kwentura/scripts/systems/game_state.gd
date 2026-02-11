extends Node

signal clue_collected(zone_id: String, clue_data: Dictionary)
signal zone_completed(zone_id: String)
signal all_clues_collected
signal game_reset
signal player_role_assigned(role: Role)
signal data_synced

enum Role { NONE, DETECTIVE, SIDEKICK }
enum ZoneStatus { LOCKED, AVAILABLE, COMPLETED }

# Player Identity
var local_role: Role = Role.NONE
var is_host: bool = false  # Network authority

# Game Progression
var current_zone: String = "forest_hub"
var zones_status: Dictionary = {
	"pinas_house": ZoneStatus.AVAILABLE,
	"backyard_path": ZoneStatus.AVAILABLE,
	"old_well": ZoneStatus.AVAILABLE,
	"storage_hut": ZoneStatus.AVAILABLE,
	"abandoned_house": ZoneStatus.AVAILABLE
}

# Clue System - Stores both physical clues and story fragments
var collected_clues: Dictionary = {
	"pinas_house":
	{
		"collected": false,
		"item": "Ladle",
		"text": "We use our eyes to find things, but Pina never used hers…",
		"zone_name": "Pina's House"
	},
	"backyard_path":
	{
		"collected": false,
		"item": "Pineapple_Sapling",
		"text": "Pina didn't run away; she became the garden.",
		"zone_name": "Backyard Path"
	},
	"old_well":
	{
		"collected": false,
		"item": "Eye_Symbol",
		"text": "She had eyes but chose not to see.",
		"zone_name": "Old Well"
	},
	"storage_hut":
	{
		"collected": false,
		"item": "Wish_Scroll",
		"text": "I wished you had many eyes, so you could find what you seek...",
		"zone_name": "Storage Hut"
	},
	"abandoned_house":
	{
		"collected": false,
		"item": "Tiara",
		"text": "Treated like a princess, she never learned to look.",
		"zone_name": "Abandoned House"
	}
}

# Dynamic Puzzle Data - Resets on game over
var puzzle_seeds: Dictionary = {}  # Stores random seeds for puzzle generation
var attempt_count: int = 0  # Tracks failed attempts for difficulty scaling
var _session_seed: int = 0  # Master seed from NetworkManager

# Story Ledger (Sidekick's Book)
var ledger_entries: Array = []

# Completion State
var climax_triggered: bool = false
var game_completed: bool = false

# Bakunawa Nightfall State
var nightfall_attempts: int = 0
var max_nightfall_attempts: int = 3


func _ready():
	randomize()
	# Note: puzzle seeds are now initialized via set_session_seed()
	# when NetworkManager establishes connection


func _initialize_puzzle_seeds():
	# Generate unique seeds for each zone's puzzles
	# These regenerate if game resets (Bakunawa catches player)
	# If no session seed set yet, use random (for offline/testing)
	if _session_seed == 0:
		_session_seed = randi()
	
	# Derive zone seeds deterministically from session seed
	for zone in zones_status.keys():
		puzzle_seeds[zone] = hash(_session_seed + zone.hash())


func set_session_seed(session_seed: int):
	# Called by NetworkManager when joining/hosting
	_session_seed = session_seed
	_initialize_puzzle_seeds()
	print("[GameState] Session seed set: ", _session_seed)
	print("[GameState] Zone seeds derived: ", puzzle_seeds)


func assign_role(role: Role):
	local_role = role
	is_host = (role == Role.DETECTIVE)
	emit_signal("player_role_assigned", role)
	print("Role assigned: ", Role.keys()[role], " | Is Host: ", is_host)


func collect_clue(zone_id: String) -> bool:
	if not collected_clues.has(zone_id):
		return false

	collected_clues[zone_id].collected = true
	var clue_data = collected_clues[zone_id]

	# Add to ledger
	ledger_entries.append(
		{
			"zone": zone_id,
			"item": clue_data.item,
			"text": clue_data.text,
			"timestamp": Time.get_unix_time_from_system()
		}
	)

	zones_status[zone_id] = ZoneStatus.COMPLETED
	emit_signal("clue_collected", zone_id, clue_data)
	emit_signal("zone_completed", zone_id)

	# Check for all clues
	if _check_all_clues_collected():
		climax_triggered = true
		emit_signal("all_clues_collected")

	# Auto-save
	if FirebaseManager:
		FirebaseManager.save_progress()

	return true


func _check_all_clues_collected() -> bool:
	for zone_id in collected_clues.keys():
		if not collected_clues[zone_id].collected:
			return false
	return true


func get_collected_count() -> int:
	var count = 0
	for zone_data in collected_clues.values():
		if zone_data.collected:
			count += 1
	return count


func reset_game_after_nightfall():
	# Called when Bakunawa catches players
	attempt_count += 1
	nightfall_attempts += 1

	# Reset clues but keep zones available
	for zone_id in collected_clues.keys():
		collected_clues[zone_id].collected = false

	# Generate NEW session seed for new puzzle variations
	_session_seed = randi()
	_initialize_puzzle_seeds()
	print("[GameState] Nightfall reset - new session seed: ", _session_seed)

	# Reset position
	current_zone = "forest_hub"
	climax_triggered = false

	emit_signal("game_reset")

	# Save the reset state
	if FirebaseManager:
		FirebaseManager.save_progress()


func get_puzzle_seed(zone_id: String) -> int:
	# Return cached seed or derive if not initialized
	if puzzle_seeds.has(zone_id):
		return puzzle_seeds[zone_id]
	# Fallback: derive from session seed or generate random
	if _session_seed != 0:
		return hash(_session_seed + zone_id.hash())
	return randi()


func get_save_data() -> Dictionary:
	return {
		"collected_clues": collected_clues,
		"zones_status": zones_status,
		"current_zone": current_zone,
		"climax_triggered": climax_triggered,
		"game_completed": game_completed,
		"attempt_count": attempt_count,
		"nightfall_attempts": nightfall_attempts,
		"ledger_entries": ledger_entries,
		"puzzle_seeds": puzzle_seeds,
		"session_seed": _session_seed,
		"timestamp": Time.get_unix_time_from_system()
	}


func load_save_data(data: Dictionary):
	if data.has("collected_clues"):
		collected_clues = data.collected_clues
	if data.has("zones_status"):
		zones_status = data.zones_status
	if data.has("current_zone"):
		current_zone = data.current_zone
	if data.has("climax_triggered"):
		climax_triggered = data.climax_triggered
	if data.has("game_completed"):
		game_completed = data.game_completed
	if data.has("attempt_count"):
		attempt_count = data.attempt_count
	if data.has("nightfall_attempts"):
		nightfall_attempts = data.nightfall_attempts
	if data.has("ledger_entries"):
		ledger_entries = data.ledger_entries
	if data.has("puzzle_seeds"):
		puzzle_seeds = data.puzzle_seeds
	if data.has("session_seed"):
		_session_seed = data.session_seed
		# Re-derive zone seeds from loaded session seed
		_initialize_puzzle_seeds()

	emit_signal("data_synced")
