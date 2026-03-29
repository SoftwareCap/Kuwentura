extends Node

## Game State - Central Game Progression Manager
##
## Manages all game progression data:
## - Collected clues and zone completion
## - Player roles and session data
## - Puzzle seeds and game reset handling
##
## Save system: LocalSaveManager (primary) → FirebaseManager (cloud backup)

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

var local_role: Role = Role.NONE
var is_host: bool = false

var current_zone: String = "forest_hub"
var zones_status: Dictionary = {
	"pinas_house":      ZoneStatus.AVAILABLE,
	"backyard_path":    ZoneStatus.AVAILABLE,
	"old_well":         ZoneStatus.AVAILABLE,
	"storage_hut":      ZoneStatus.AVAILABLE,
	"abandoned_house":  ZoneStatus.AVAILABLE,
}

var collected_clues: Dictionary = {
	"pinas_house": {
		"collected": false,
		"item": "Ladle",
		"text": "We use our eyes to find things, but Pina never used hers…",
		"zone_name": "Pina's House",
	},
	"backyard_path": {
		"collected": false,
		"item": "Pineapple_Sapling",
		"text": "Pina didn't run away; she became the garden.",
		"zone_name": "Backyard Path",
	},
	"old_well": {
		"collected": false,
		"item": "Eye_Symbol",
		"text": "She had eyes but chose not to see.",
		"zone_name": "Old Well",
	},
	"storage_hut": {
		"collected": false,
		"item": "Wish_Scroll",
		"text": "I wished you had many eyes, so you could find what you seek...",
		"zone_name": "Storage Hut",
	},
	"abandoned_house": {
		"collected": false,
		"item": "Tiara",
		"text": "Treated like a princess, she never learned to look.",
		"zone_name": "Abandoned House",
	},
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
	"abandoned_house",
]

var ledger_entries: Array = []
var climax_triggered: bool = false
var game_completed: bool = false
var nightfall_attempts: int = 0
var max_nightfall_attempts: int = 3
var saved_spawn_positions: Dictionary = {}
var solved_puzzles: Dictionary = {}

const COSTUMES_IMPLEMENTED: bool = false

const COSTUMES: Dictionary = {
	"detective": [
		{
			"id": "default",
			"name": "Classic Outfit",
			"description": "The traditional detective look",
			"sprite_folder": "Detective",
			"unlocked": true,
		}
	],
	"sidekick": [
		{
			"id": "default",
			"name": "Classic Outfit",
			"description": "The traditional sidekick look",
			"sprite_folder": "Sidekick",
			"unlocked": true,
		}
	],
}

const CLUE_PINAS_HOUSE   := "pinas_house"
const CLUE_BACKYARD_PATH := "backyard_path"

const BRIEFCASE_ASSETS := {
	"no_clue":                    "res://assets/briefcase/NoClue.png",
	"ladle_first_reveal":         "res://assets/briefcase/LadleFirstReveal.png",
	"ladle_first_global":         "res://assets/briefcase/LadleFirstGlobal.png",
	"pineapple_first_reveal":     "res://assets/briefcase/PineappleFirstReveal.png",
	"pineapple_first_global":     "res://assets/briefcase/PineappleFirstGlobal.png",
	"pineapple_with_ladle_reveal":"res://assets/briefcase/PineappleWithLadleReveal.png",
	"ladle_with_pineapple_reveal":"res://assets/briefcase/LadleWithPineappleReveal.png",
	"ladle_and_pineapple_global": "res://assets/briefcase/LadleAndPineapple.png",
}

var selected_costumes: Dictionary = {
	"detective": "default",
	"sidekick":  "default",
}

var _costume_confirmed_status: Dictionary = {
	"detective": false,
	"sidekick":  false,
}

var _zone_lock_until: Dictionary = {}


func _ready() -> void:
	randomize()
	_load_from_local_save()


func _load_from_local_save() -> void:
	if not LocalSaveManager:
		push_warning("[GameState] LocalSaveManager not available")
		_initialize_puzzle_seeds()
		return
	var data := LocalSaveManager.load_game()
	if data.size() > 0:
		load_save_data(data)
	else:
		_attempt_cloud_restore()


func _attempt_cloud_restore() -> void:
	if FirebaseManager and FirebaseManager.is_cloud_available():
		FirebaseManager.restore_from_cloud()


func _save_progress(source: String = "auto") -> void:
	save_triggered.emit(source)
	if LocalSaveManager:
		LocalSaveManager.save_game(get_save_data())
	if FirebaseManager and FirebaseManager.is_cloud_available():
		FirebaseManager.sync_to_cloud()


func assign_role(role: Role) -> void:
	local_role = role
	is_host = (role == Role.DETECTIVE)
	player_role_assigned.emit(role)


func collect_clue(zone_id: String) -> bool:
	if not collected_clues.has(zone_id):
		return false
	collected_clues[zone_id].collected = true
	var clue_data: Dictionary = collected_clues[zone_id]
	ledger_entries.append({
		"zone":      zone_id,
		"item":      clue_data.item,
		"text":      clue_data.text,
		"timestamp": int(Time.get_unix_time_from_system()),
	})
	zones_status[zone_id] = ZoneStatus.COMPLETED
	clue_collected.emit(zone_id, clue_data)
	zone_completed.emit(zone_id)
	briefcase_updated.emit()
	if _check_all_clues_collected():
		climax_triggered = true
		all_clues_collected.emit()
	_save_progress("clue_collected")
	return true


func _check_all_clues_collected() -> bool:
	for zone_id in collected_clues:
		if not collected_clues[zone_id].collected:
			return false
	return true


func get_collected_count() -> int:
	var count := 0
	for zone_data in collected_clues.values():
		if zone_data.collected:
			count += 1
	return count


func _reset_clues() -> void:
	for zone_id in collected_clues:
		collected_clues[zone_id].collected = false


func reset_game_after_nightfall() -> void:
	attempt_count += 1
	nightfall_attempts += 1
	_reset_clues()
	_session_seed = randi()
	_initialize_puzzle_seeds()
	current_zone = "forest_hub"
	climax_triggered = false
	solved_puzzles.clear()
	game_reset.emit()
	_save_progress("nightfall_reset")


func has_clue(zone_id: String) -> bool:
	if not collected_clues.has(zone_id):
		return false
	return bool(collected_clues[zone_id].get("collected", false))


func get_briefcase_texture(context: String) -> Texture2D:
	var path := get_briefcase_texture_path(context)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func get_briefcase_texture_path(context: String) -> String:
	var has_ladle     := has_clue(CLUE_PINAS_HOUSE)
	var has_pineapple := has_clue(CLUE_BACKYARD_PATH)
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
			return BRIEFCASE_ASSETS["ladle_with_pineapple_reveal"] if has_pineapple else BRIEFCASE_ASSETS["ladle_first_reveal"]
		"backyard_path_reveal":
			return BRIEFCASE_ASSETS["pineapple_with_ladle_reveal"] if has_ladle else BRIEFCASE_ASSETS["pineapple_first_reveal"]
	return BRIEFCASE_ASSETS["no_clue"]


func get_save_data() -> Dictionary:
	return {
		"collected_clues":          collected_clues.duplicate(true),
		"solved_puzzles":           solved_puzzles.duplicate(true),
		"zones_status":             zones_status.duplicate(true),
		"current_zone":             current_zone,
		"climax_triggered":         climax_triggered,
		"game_completed":           game_completed,
		"attempt_count":            attempt_count,
		"nightfall_attempts":       nightfall_attempts,
		"ledger_entries":           ledger_entries.duplicate(true),
		"puzzle_seeds":             puzzle_seeds.duplicate(true),
		"session_seed":             _session_seed,
		"selected_costumes":        selected_costumes.duplicate(true),
		"_costume_confirmed_status":_costume_confirmed_status.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("collected_clues"):          collected_clues             = data["collected_clues"].duplicate(true)
	if data.has("solved_puzzles"):           solved_puzzles              = data["solved_puzzles"].duplicate(true)
	if data.has("zones_status"):             zones_status                = data["zones_status"].duplicate(true)
	if data.has("current_zone"):             current_zone                = data["current_zone"]
	if data.has("climax_triggered"):         climax_triggered            = data["climax_triggered"]
	if data.has("game_completed"):           game_completed              = data["game_completed"]
	if data.has("attempt_count"):            attempt_count               = data["attempt_count"]
	if data.has("nightfall_attempts"):       nightfall_attempts          = data["nightfall_attempts"]
	if data.has("ledger_entries"):           ledger_entries              = data["ledger_entries"].duplicate(true)
	if data.has("puzzle_seeds"):             puzzle_seeds                = data["puzzle_seeds"].duplicate(true)
	if data.has("selected_costumes"):        selected_costumes           = data["selected_costumes"].duplicate(true)
	if data.has("_costume_confirmed_status"):_costume_confirmed_status   = data["_costume_confirmed_status"].duplicate(true)
	if data.has("session_seed"):
		_session_seed = data["session_seed"]
		_initialize_puzzle_seeds()
	data_synced.emit()


func _initialize_puzzle_seeds() -> void:
	if _session_seed == 0:
		_session_seed = randi()
	puzzle_seeds.clear()
	puzzle_variation_indices.clear()
	for zone in PUZZLE_ZONE_ORDER:
		var zone_index := PUZZLE_ZONE_ORDER.find(zone)
		puzzle_seeds[zone] = int((_session_seed * 1009) + (zone_index * 7919))


func set_session_seed(session_seed: int) -> void:
	_session_seed = session_seed
	_initialize_puzzle_seeds()


func get_puzzle_seed(zone_id: String) -> int:
	if puzzle_seeds.has(zone_id):
		return puzzle_seeds[zone_id]
	if _session_seed != 0:
		return hash(_session_seed + zone_id.hash())
	return randi()


func get_puzzle_variation_index(zone_id: String, variation_count: int) -> int:
	if variation_count <= 0:
		return 0
	if puzzle_variation_indices.has(zone_id):
		return clamp(int(puzzle_variation_indices[zone_id]), 0, variation_count - 1)
	var zone_index := PUZZLE_ZONE_ORDER.find(zone_id)
	if zone_index == -1:
		zone_index = 0
	var variation_index: int = abs(get_puzzle_seed(zone_id)) % variation_count
	puzzle_variation_indices[zone_id] = variation_index
	return variation_index


func is_puzzle_solved(zone_id: String) -> bool:
	return bool(solved_puzzles.get(zone_id, false))


func set_puzzle_solved(zone_id: String, solved: bool = true) -> void:
	solved_puzzles[zone_id] = solved


func lock_zone_temp(zone_id: String, duration_sec: int) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	_zone_lock_until[zone_id] = now + float(duration_sec)


func is_zone_locked_temp(zone_id: String) -> bool:
	var now   := float(Time.get_ticks_msec()) / 1000.0
	var until := float(_zone_lock_until.get(zone_id, 0.0))
	return now < until


func get_zone_lock_remaining(zone_id: String) -> int:
	var now   := float(Time.get_ticks_msec()) / 1000.0
	var until := float(_zone_lock_until.get(zone_id, 0.0))
	return max(0, int(ceil(until - now)))


func save_spawn_position(peer_id: int, position: Vector2, zone: String = "forest_hub") -> void:
	saved_spawn_positions[peer_id] = {
		"position":  position,
		"zone":      zone,
		"timestamp": int(Time.get_unix_time_from_system()),
	}


func get_spawn_position(peer_id: int) -> Vector2:
	if saved_spawn_positions.has(peer_id):
		return saved_spawn_positions[peer_id].position
	return Vector2.ZERO


func clear_spawn_position(peer_id: int) -> void:
	saved_spawn_positions.erase(peer_id)


func has_spawn_position(peer_id: int) -> bool:
	return saved_spawn_positions.has(peer_id)


func get_costumes_for_role(role: String) -> Array:
	return COSTUMES.get(role, [])


func get_costume_by_id(role: String, costume_id: String) -> Dictionary:
	var costumes := get_costumes_for_role(role)
	for costume in costumes:
		if costume.id == costume_id:
			return costume
	return costumes[0] if costumes.size() > 0 else {}


func set_selected_costume(role: String, costume_id: String) -> void:
	selected_costumes[role] = costume_id
	costume_changed.emit(role, costume_id)


func get_selected_costume(role: String) -> String:
	return selected_costumes.get(role, "default")


func confirm_costume_selection(role: String, confirmed: bool = true) -> void:
	_costume_confirmed_status[role] = confirmed
	costume_confirmed.emit(role, confirmed)


func is_costume_confirmed(role: String) -> bool:
	return _costume_confirmed_status.get(role, false)


func reset_costume_selections() -> void:
	selected_costumes         = {"detective": "default", "sidekick": "default"}
	_costume_confirmed_status = {"detective": false,     "sidekick": false}


@rpc("authority", "reliable", "call_local")
func _broadcast_position_rpc(peer_id: int, pos: Vector2) -> void:
	save_spawn_position(peer_id, pos, "forest_hub")


@rpc("any_peer", "reliable")
func _report_position_to_host_rpc(peer_id: int, pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	save_spawn_position(peer_id, pos, "forest_hub")
	_broadcast_position_rpc.rpc(peer_id, pos)


func reset_all_progress() -> void:
	_reset_clues()
	for zone_id in zones_status:
		zones_status[zone_id] = ZoneStatus.AVAILABLE
	current_zone      = "forest_hub"
	climax_triggered  = false
	game_completed    = false
	attempt_count     = 0
	nightfall_attempts = 0
	ledger_entries.clear()
	solved_puzzles.clear()
	_session_seed = randi()
	_initialize_puzzle_seeds()
	reset_costume_selections()
	if LocalSaveManager:
		LocalSaveManager.delete_save()
	game_reset.emit()


func get_role_display_text() -> String:
	match local_role:
		Role.DETECTIVE: return "DETECTIVE (Host)"
		Role.SIDEKICK:  return "SIDEKICK (Client)"
		_:              return "NO ROLE ASSIGNED"
