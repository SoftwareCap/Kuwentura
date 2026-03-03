extends Node

signal clue_collected(zone_id: String, clue_data: Dictionary)
signal zone_completed(zone_id: String)
signal all_clues_collected
signal game_reset
signal player_role_assigned(role: Role)
signal data_synced
signal costume_changed(role: String, costume_id: String)
signal costume_confirmed(role: String, confirmed: bool)

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

# Saved spawn positions for returning from zones
# Key: peer_id, Value: {position: Vector2, zone: String}
var saved_spawn_positions: Dictionary = {}

# Costume System
# NOTE: Only classic outfit is available for now.
const COSTUMES_IMPLEMENTED: bool = false

const COSTUMES: Dictionary = {
	"detective": [
		{
			"id": "default",
			"name": "Classic Outfit",
			"description": "The traditional detective look",
			"sprite_folder": "Detective",
			"unlocked": true
		}
	],
	"sidekick": [
		{
			"id": "default",
			"name": "Classic Outfit",
			"description": "The traditional sidekick look",
			"sprite_folder": "Sidekick",
			"unlocked": true
		}
	]
}

# Current selections (persisted through game session)
var selected_costumes: Dictionary = {
	"detective": "default",
	"sidekick": "default"
}

# Selection status for lobby UI
var _costume_confirmed_status: Dictionary = {
	"detective": false,
	"sidekick": false
}


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
		"solved_puzzles": solved_puzzles,
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
	if data.has("solved_puzzles"):
		solved_puzzles = data.solved_puzzles
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


# === SPAWN POSITION SAVE/RESTORE ===

func save_spawn_position(peer_id: int, position: Vector2, zone: String = "forest_hub"):
	"""Save a player's position before entering a zone."""
	saved_spawn_positions[peer_id] = {
		"position": position,
		"zone": zone,
		"timestamp": Time.get_unix_time_from_system()
	}
	print("[GameState] Saved spawn position for peer ", peer_id, ": ", position)


func get_spawn_position(peer_id: int) -> Vector2:
	"""Get saved spawn position for a player, or Vector2.ZERO if none saved."""
	if saved_spawn_positions.has(peer_id):
		return saved_spawn_positions[peer_id].position
	return Vector2.ZERO


func clear_spawn_position(peer_id: int):
	"""Clear saved spawn position after using it."""
	if saved_spawn_positions.has(peer_id):
		saved_spawn_positions.erase(peer_id)
		print("[GameState] Cleared spawn position for peer ", peer_id)


func has_spawn_position(peer_id: int) -> bool:
	"""Check if a player has a saved spawn position."""
	return saved_spawn_positions.has(peer_id)


# === RPC FUNCTIONS FOR POSITION SYNC ===
# These are here because GameState is a singleton that exists in all scenes

@rpc("authority", "reliable", "call_local")
func _broadcast_position_rpc(peer_id: int, pos: Vector2):
	"""Host broadcasts a player's position to all clients."""
	save_spawn_position(peer_id, pos, "forest_hub")
	print("[GameState] Received position for peer ", peer_id, ": ", pos)


@rpc("any_peer", "reliable")
func _report_position_to_host_rpc(peer_id: int, pos: Vector2):
	"""Client reports their position to host."""
	if not multiplayer.is_server():
		return
	
	# Host saves and broadcasts to all
	save_spawn_position(peer_id, pos, "forest_hub")
	_broadcast_position_rpc.rpc(peer_id, pos)
	print("[GameState] Host received and broadcast position for peer ", peer_id, ": ", pos)


# === COSTUME SYSTEM FUNCTIONS ===

func get_costumes_for_role(role: String) -> Array:
	"""Get available costumes for a role (detective or sidekick)."""
	return COSTUMES.get(role, [])


func get_costume_by_id(role: String, costume_id: String) -> Dictionary:
	"""Get costume data by role and ID. Returns first costume if not found."""
	var costumes = get_costumes_for_role(role)
	for costume in costumes:
		if costume.id == costume_id:
			return costume
	return costumes[0] if costumes.size() > 0 else {}


func set_selected_costume(role: String, costume_id: String):
	"""Set the selected costume for a role."""
	selected_costumes[role] = costume_id
	emit_signal("costume_changed", role, costume_id)


func get_selected_costume(role: String) -> String:
	"""Get the selected costume ID for a role."""
	return selected_costumes.get(role, "default")


func confirm_costume_selection(role: String, confirmed: bool = true):
	"""Confirm or unconfirm costume selection for a role."""
	_costume_confirmed_status[role] = confirmed
	emit_signal("costume_confirmed", role, confirmed)


func is_costume_confirmed(role: String) -> bool:
	"""Check if costume selection is confirmed for a role."""
	return _costume_confirmed_status.get(role, false)


func reset_costume_selections():
	"""Reset all costume selections (called on game reset)."""
	selected_costumes = {"detective": "default", "sidekick": "default"}
	_costume_confirmed_status = {"detective": false, "sidekick": false}

# Puzzle Completion State (per zone)
var solved_puzzles: Dictionary = {}  # zone_id -> bool

func is_puzzle_solved(zone_id: String) -> bool:
	return bool(solved_puzzles.get(zone_id, false))

func set_puzzle_solved(zone_id: String, solved: bool = true) -> void:
	solved_puzzles[zone_id] = solved
