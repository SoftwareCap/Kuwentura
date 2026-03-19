extends Node

## Game State - Central Game Progression Manager
##
## This singleton manages all game progression data including:
## - Collected clues and zone completion
## - Player roles and session data
## - Puzzle seeds and game reset handling
##
## SAVE SYSTEM INTEGRATION:
## - Primary: LocalSaveManager (always works offline)
## - Secondary: FirebaseManager (cloud backup when online)

signal clue_collected(zone_id: String, clue_data: Dictionary)
signal zone_completed(zone_id: String)
signal all_clues_collected
signal game_reset
signal player_role_assigned(role: Role)
signal data_synced
signal costume_changed(role: String, costume_id: String)
signal costume_confirmed(role: String, confirmed: bool)
signal save_triggered(source: String)
signal briefcase_updated

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

var puzzle_seeds: Dictionary = {} 
var puzzle_variation_indices: Dictionary = {} 
var attempt_count: int = 0 
var _session_seed: int = 0 

const PUZZLE_ZONE_ORDER := [
	"pinas_house",
	"backyard_path",
	"old_well",
	"storage_hut",
	"abandoned_house"
]

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

# Puzzle Completion State (per zone)
var solved_puzzles: Dictionary = {}  # zone_id -> bool

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

const CLUE_PINAS_HOUSE := "pinas_house"
const CLUE_BACKYARD_PATH := "backyard_path"

const BRIEFCASE_ASSETS := {
	"no_clue": "res://assets/briefcase/NoClue.png",

	"ladle_first_reveal": "res://assets/briefcase/LadleFirstReveal.png",
	"ladle_first_global": "res://assets/briefcase/LadleFirstGlobal.png",

	"pineapple_first_reveal": "res://assets/briefcase/PineappleFirstReveal.png",
	"pineapple_first_global": "res://assets/briefcase/PineappleFirstGlobal.png",

	"pineapple_with_ladle_reveal": "res://assets/briefcase/PineappleWithLadleReveal.png",
	"ladle_with_pineapple_reveal": "res://assets/briefcase/LadleWithPineappleReveal.png",

	"ladle_and_pineapple_global": "res://assets/briefcase/LadleAndPineapple.png"
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

# Temporary zone lockouts (seconds-based)
var zone_lock_until_unix: Dictionary = {}  # zone_id -> unix_time (seconds)

# -------------------------
# Zone temporary lock system
# -------------------------
var _zone_lock_until: Dictionary = {}


func _ready():
	randomize()
	
	# Load from LOCAL storage first (always works)
	_load_from_local_save()


# ============================================================================
# SAVE/LOAD INTEGRATION
# ============================================================================

func _load_from_local_save():
	"""Load game data from local storage on startup"""
	if LocalSaveManager:
		var data = LocalSaveManager.load_game()
		if data.size() > 0:
			load_save_data(data)
			print("[GameState] Loaded from local save")
		else:
			print("[GameState] No local save found, starting fresh")
			# Optionally try cloud restore
			_attempt_cloud_restore()
	else:
		push_warning("[GameState] LocalSaveManager not available")
		_initialize_puzzle_seeds()


func _attempt_cloud_restore():
	"""Attempt to restore from cloud if no local save"""
	if FirebaseManager and FirebaseManager.is_cloud_available():
		print("[GameState] Attempting cloud restore...")
		FirebaseManager.restore_from_cloud()


func _save_progress(source: String = "auto"):
	"""Save progress to local storage (primary) and optionally cloud"""
	emit_signal("save_triggered", source)
	
	# Always save to local first (guaranteed to work)
	if LocalSaveManager:
		LocalSaveManager.save_game(get_save_data())
	
	# Optional cloud backup (non-blocking)
	if FirebaseManager and FirebaseManager.is_cloud_available():
		FirebaseManager.sync_to_cloud()


# ============================================================================
# PUBLIC API - Game Progression
# ============================================================================

func assign_role(role: Role):
	local_role = role
	is_host = (role == Role.DETECTIVE)
	emit_signal("player_role_assigned", role)
	print("[GameState] Role assigned: ", Role.keys()[role], " | Is Host: ", is_host)


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
	emit_signal("briefcase_updated")
	
	# Check for all clues
	if _check_all_clues_collected():
		climax_triggered = true
		emit_signal("all_clues_collected")
	
	# Auto-save to local storage
	_save_progress("clue_collected")
	
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
	"""Called when Bakunawa catches players"""
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
	solved_puzzles.clear()
	
	emit_signal("game_reset")
	
	# Save the reset state
	_save_progress("nightfall_reset")

func has_clue(zone_id: String) -> bool:
	if not collected_clues.has(zone_id):
		return false
	return bool(collected_clues[zone_id].get("collected", false))


func get_briefcase_texture(context: String) -> Texture2D:
	var path: String = get_briefcase_texture_path(context)
	if path.is_empty():
		return null
	return load(path) as Texture2D


func get_briefcase_texture_path(context: String) -> String:
	var has_ladle: bool = has_clue(CLUE_PINAS_HOUSE)
	var has_pineapple: bool = has_clue(CLUE_BACKYARD_PATH)

	match context:
		"forest":
			if has_ladle and has_pineapple:
				return BRIEFCASE_ASSETS["ladle_and_pineapple_global"]
			elif has_ladle:
				return BRIEFCASE_ASSETS["ladle_first_global"]
			elif has_pineapple:
				return BRIEFCASE_ASSETS["pineapple_first_global"]
			else:
				return BRIEFCASE_ASSETS["no_clue"]

		"pinas_house_reveal":
			if has_pineapple:
				return BRIEFCASE_ASSETS["ladle_with_pineapple_reveal"]
			else:
				return BRIEFCASE_ASSETS["ladle_first_reveal"]

		"backyard_path_reveal":
			if has_ladle:
				return BRIEFCASE_ASSETS["pineapple_with_ladle_reveal"]
			else:
				return BRIEFCASE_ASSETS["pineapple_first_reveal"]

	return BRIEFCASE_ASSETS["no_clue"]

# ============================================================================
# PUBLIC API - Save Data Serialization
# ============================================================================

func get_save_data() -> Dictionary:
	"""Get complete game state for saving"""
	return {
		"collected_clues": collected_clues.duplicate(true),
		"solved_puzzles": solved_puzzles.duplicate(true),
		"zones_status": zones_status.duplicate(true),
		"current_zone": current_zone,
		"climax_triggered": climax_triggered,
		"game_completed": game_completed,
		"attempt_count": attempt_count,
		"nightfall_attempts": nightfall_attempts,
		"ledger_entries": ledger_entries.duplicate(true),
		"puzzle_seeds": puzzle_seeds.duplicate(true),
		"session_seed": _session_seed,
		"selected_costumes": selected_costumes.duplicate(true),
		"_costume_confirmed_status": _costume_confirmed_status.duplicate(true)
	}


func load_save_data(data: Dictionary):
	"""Load game state from save data"""
	if data.has("collected_clues"):
		collected_clues = data.collected_clues.duplicate(true)
	if data.has("solved_puzzles"):
		solved_puzzles = data.solved_puzzles.duplicate(true)
	if data.has("zones_status"):
		zones_status = data.zones_status.duplicate(true)
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
		ledger_entries = data.ledger_entries.duplicate(true)
	if data.has("puzzle_seeds"):
		puzzle_seeds = data.puzzle_seeds.duplicate(true)
	if data.has("session_seed"):
		_session_seed = data.session_seed
		_initialize_puzzle_seeds()
	if data.has("selected_costumes"):
		selected_costumes = data.selected_costumes.duplicate(true)
	if data.has("_costume_confirmed_status"):
		_costume_confirmed_status = data._costume_confirmed_status.duplicate(true)
	
	emit_signal("data_synced")


# ============================================================================
# PUBLIC API - Puzzle System
# ============================================================================

func _initialize_puzzle_seeds():
	"""Generate unique seeds for each zone's puzzles"""
	if _session_seed == 0:
		_session_seed = randi()

	puzzle_seeds.clear()
	puzzle_variation_indices.clear()

	for zone in PUZZLE_ZONE_ORDER:
		var zone_index: int = PUZZLE_ZONE_ORDER.find(zone)
		var stable_seed: int = int((_session_seed * 1009) + (zone_index * 7919))
		puzzle_seeds[zone] = stable_seed


func set_session_seed(session_seed: int):
	"""Called by NetworkManager when joining/hosting"""
	_session_seed = session_seed
	_initialize_puzzle_seeds()
	print("[GameState] Session seed set: ", _session_seed)


func get_puzzle_seed(zone_id: String) -> int:
	"""Return cached seed or derive if not initialized"""
	if puzzle_seeds.has(zone_id):
		return puzzle_seeds[zone_id]
	if _session_seed != 0:
		return hash(_session_seed + zone_id.hash())
	return randi()

func get_puzzle_variation_index(zone_id: String, variation_count: int) -> int:
	"""Return one stable variation index per zone for the whole session."""
	if variation_count <= 0:
		return 0

	if puzzle_variation_indices.has(zone_id):
		var cached_index: int = int(puzzle_variation_indices[zone_id])
		return clamp(cached_index, 0, variation_count - 1)

	var zone_index: int = PUZZLE_ZONE_ORDER.find(zone_id)
	if zone_index == -1:
		zone_index = 0

	var base_seed: int = get_puzzle_seed(zone_id)
	var positive_seed: int = abs(base_seed)

	var variation_index: int = positive_seed % variation_count
	puzzle_variation_indices[zone_id] = variation_index
	return variation_index

func is_puzzle_solved(zone_id: String) -> bool:
	return bool(solved_puzzles.get(zone_id, false))


func set_puzzle_solved(zone_id: String, solved: bool = true) -> void:
	solved_puzzles[zone_id] = solved


# ============================================================================
# PUBLIC API - Zone Lock System
# ============================================================================

func lock_zone_temp(zone_id: String, duration_sec: int) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	_zone_lock_until[zone_id] = now + float(duration_sec)


func is_zone_locked_temp(zone_id: String) -> bool:
	var now := float(Time.get_ticks_msec()) / 1000.0
	var until := float(_zone_lock_until.get(zone_id, 0.0))
	return now < until


func get_zone_lock_remaining(zone_id: String) -> int:
	var now := float(Time.get_ticks_msec()) / 1000.0
	var until := float(_zone_lock_until.get(zone_id, 0.0))
	return max(0, int(ceil(until - now)))


# ============================================================================
# PUBLIC API - Spawn Position Management
# ============================================================================

func save_spawn_position(peer_id: int, position: Vector2, zone: String = "forest_hub"):
	"""Save a player's position before entering a zone."""
	print("[GameState] → SAVING spawn position for peer ", peer_id, " at ", position, " (zone: ", zone, ")")
	saved_spawn_positions[peer_id] = {
		"position": position,
		"zone": zone,
		"timestamp": Time.get_unix_time_from_system()
	}
	print("[GameState] Current saved positions: ", saved_spawn_positions.keys())


func get_spawn_position(peer_id: int) -> Vector2:
	"""Get saved spawn position for a player, or Vector2.ZERO if none saved."""
	if saved_spawn_positions.has(peer_id):
		var pos = saved_spawn_positions[peer_id].position
		print("[GameState] ← RETRIEVING spawn position for peer ", peer_id, ": ", pos)
		return pos
	print("[GameState] ○ No spawn position found for peer ", peer_id, " (saved keys: ", saved_spawn_positions.keys(), ")")
	return Vector2.ZERO


func clear_spawn_position(peer_id: int):
	"""Clear saved spawn position after using it."""
	if saved_spawn_positions.has(peer_id):
		print("[GameState] ✗ CLEARING spawn position for peer ", peer_id)
		saved_spawn_positions.erase(peer_id)
		print("[GameState] Remaining saved positions: ", saved_spawn_positions.keys())
	else:
		print("[GameState] ○ No position to clear for peer ", peer_id)


func has_spawn_position(peer_id: int) -> bool:
	"""Check if a player has a saved spawn position."""
	return saved_spawn_positions.has(peer_id)


# ============================================================================
# PUBLIC API - Costume System
# ============================================================================

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


# ============================================================================
# RPC FUNCTIONS - Position Sync
# ============================================================================

@rpc("authority", "reliable", "call_local")
func _broadcast_position_rpc(peer_id: int, pos: Vector2):
	"""Host broadcasts a player's position to all clients."""
	save_spawn_position(peer_id, pos, "forest_hub")


@rpc("any_peer", "reliable")
func _report_position_to_host_rpc(peer_id: int, pos: Vector2):
	"""Client reports their position to host."""
	if not multiplayer.is_server():
		return
	
	# Host saves and broadcasts to all
	save_spawn_position(peer_id, pos, "forest_hub")
	_broadcast_position_rpc.rpc(peer_id, pos)


# ============================================================================
# PUBLIC API - Game Reset
# ============================================================================

func reset_all_progress():
	"""Reset all game progress (for new game)"""
	# Reset clues
	for zone_id in collected_clues.keys():
		collected_clues[zone_id].collected = false
	
	# Reset zones
	for zone_id in zones_status.keys():
		zones_status[zone_id] = ZoneStatus.AVAILABLE
	
	# Reset state
	current_zone = "forest_hub"
	climax_triggered = false
	game_completed = false
	attempt_count = 0
	nightfall_attempts = 0
	ledger_entries.clear()
	solved_puzzles.clear()
	
	# Reset session
	_session_seed = randi()
	_initialize_puzzle_seeds()
	
	# Reset costumes
	reset_costume_selections()
	
	# Clear saves
	if LocalSaveManager:
		LocalSaveManager.delete_save()
	
	emit_signal("game_reset")
	print("[GameState] All progress reset")
