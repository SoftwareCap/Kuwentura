#game_state.gd
extends Node

## Game State - Central Game Progression Manager
##
## Manages all game progression data:
## - Collected clues and zone completion
## - Player roles and session data
## - Puzzle seeds and game reset handling
##
## Save system: LocalSaveManager (primary) â†’ FirebaseManager (cloud backup)

signal zone_visited(zone_id: String)

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
enum DeveloperStartMode { NORMAL, SKIP_OPENING, START_BAKUNAWA }

const START_CHECKPOINT_OPENING := "opening_cutscene"
const START_CHECKPOINT_FOREST_HUB := "forest_hub"
const START_CHECKPOINT_BAKUNAWA := "bakunawa"

var local_role: Role = Role.NONE
var is_host: bool = false
var developer_start_mode: DeveloperStartMode = DeveloperStartMode.NORMAL
var forest_tutorial_shown: bool = false  # â† persisted now

var current_zone: String = "forest_hub"
var zones_status: Dictionary = {
	"pinas_house":      ZoneStatus.AVAILABLE,
	"backyard_path":    ZoneStatus.AVAILABLE,
	"old_well":         ZoneStatus.AVAILABLE,
	"storage_hut":      ZoneStatus.AVAILABLE,
	"abandoned_house":  ZoneStatus.AVAILABLE,
}

var visited_zones: Dictionary = {
	"pinas_house": false,
	"backyard_path": false,
	"old_well": false,
	"storage_hut": false,
	"abandoned_house": false,
}

var collected_clues: Dictionary = {
	"pinas_house": {
		"collected": false,
		"item": "Ladle",
		"text": "We use our eyes to find things, but Pina never used hersâ€¦",
		"zone_name": "Pina's House",
	},
	"backyard_path": {
		"collected": false,
		"item": "Pineapple",
		"text": "After a few days, Aling Rosa saw a strange fruit in their yard. It had many eyes, and she felt that it was Pinang.",
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
var forest_intro_played: bool = false
var nightfall_attempts: int = 0
var max_nightfall_attempts: int = 3
var saved_spawn_positions: Dictionary = {}
var solved_puzzles: Dictionary = {}

var zone_inventory: Dictionary = {
	"abandoned_house": {
		"key_fragment_1": false,
		"key_fragment_2": false,
		"key_fragment_3": false,
		"card_piece": false,
		"light_bulb": false,
		"assembled_key": false,
		"pinas_tiara": false
	}
}

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
const CLUE_OLD_WELL := "old_well"
const CLUE_ABANDONED_HOUSE := "abandoned_house"
const CLUE_STORAGE_HUT := "storage_hut"

const BRIEFCASE_ASSETS := {
	# Forest / global base
	"no_clue": "res://assets/sprites/briefcase/global/NoClue.png",

	# Reward reveal images (inside zones)
	"pinas_house_reveal": "res://assets/sprites/briefcase/reveal/spoonReveal.png",
	"backyard_path_reveal": "res://assets/sprites/briefcase/reveal/pineappleReveal.png",
	"old_well_reveal": "res://assets/sprites/briefcase/reveal/eyeReveal.png",
	"abandoned_house_reveal": "res://assets/sprites/briefcase/reveal/tiaraReveal.png",
	"storage_hut_reveal": "res://assets/sprites/briefcase/reveal/scrollReveal.png",

	"ladle_first_reveal":         "res://assets/sprites/briefcase/LadleFirstReveal.png",
	"ladle_first_global":         "res://assets/sprites/briefcase/LadleFirstGlobal.png",
	"pineapple_first_reveal":     "res://assets/sprites/briefcase/PineappleFirstReveal.png",
	"pineapple_first_global":     "res://assets/sprites/briefcase/PineappleFirstGlobal.png",
	"pineapple_with_ladle_reveal":"res://assets/sprites/briefcase/PineappleWithLadleReveal.png",
	"ladle_with_pineapple_reveal":"res://assets/sprites/briefcase/LadleWithPineappleReveal.png",
	"ladle_and_pineapple_global": "res://assets/sprites/briefcase/LadleAndPineapple.png",

	# Abandoned House
	"abandoned_house_default":    "res://assets/sprites/zoneObjects/abandonedHouseObjects/defaultBC.png",
	"abandoned_house_puzzle_1":   "res://assets/sprites/zoneObjects/abandonedHouseObjects/puzzle1BC.png",
	"abandoned_house_puzzle_2":   "res://assets/sprites/zoneObjects/abandonedHouseObjects/puzzzle2BC.png",
	"abandoned_house_used_lighter": "res://assets/sprites/zoneObjects/abandonedHouseObjects/usedLighterBC.png",
	"abandoned_house_puzzle_3":    "res://assets/sprites/zoneObjects/abandonedHouseObjects/puzzle3BC.png",
	"abandoned_house_full_key":    "res://assets/sprites/zoneObjects/abandonedHouseObjects/KeyBC.png",
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


func mark_tutorial_shown() -> void:
	forest_tutorial_shown = true
	_save_progress("tutorial_shown")


func assign_role(role: Role) -> void:
	local_role = role
	is_host = (role == Role.DETECTIVE)
	player_role_assigned.emit(role)


func set_developer_start_mode(mode: DeveloperStartMode) -> void:
	developer_start_mode = mode


func get_developer_start_mode_label() -> String:
	match developer_start_mode:
		DeveloperStartMode.SKIP_OPENING:
			return "Skip Opening Cutscene"
		DeveloperStartMode.START_BAKUNAWA:
			return "Start Bakunawa Challenge"
		_:
			return "Play Normal Game"


func get_developer_start_checkpoint() -> String:
	match developer_start_mode:
		DeveloperStartMode.SKIP_OPENING:
			return START_CHECKPOINT_FOREST_HUB
		DeveloperStartMode.START_BAKUNAWA:
			return START_CHECKPOINT_BAKUNAWA
		_:
			return START_CHECKPOINT_OPENING


func prepare_selected_start_mode() -> void:
	match developer_start_mode:
		DeveloperStartMode.SKIP_OPENING:
			current_zone = "forest_hub"
			forest_intro_played = true
			_save_progress("developer_skip_opening")
		DeveloperStartMode.START_BAKUNAWA:
			_prepare_bakunawa_debug_state()
		_:
			current_zone = "forest_hub"
			forest_intro_played = false


func _prepare_bakunawa_debug_state() -> void:
	ledger_entries.clear()
	for zone_id in PUZZLE_ZONE_ORDER:
		if not collected_clues.has(zone_id):
			continue
		collected_clues[zone_id].collected = true
		zones_status[zone_id] = ZoneStatus.COMPLETED
		if visited_zones.has(zone_id):
			visited_zones[zone_id] = true
		solved_puzzles[zone_id] = true
		var clue_data: Dictionary = collected_clues[zone_id]
		ledger_entries.append({
			"zone": zone_id,
			"item": clue_data.get("item", ""),
			"text": clue_data.get("text", ""),
			"timestamp": int(Time.get_unix_time_from_system()),
		})
	climax_triggered = true
	game_completed = false
	current_zone = START_CHECKPOINT_BAKUNAWA
	forest_intro_played = true
	briefcase_updated.emit()
	_save_progress("developer_start_bakunawa")


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
	
	if visited_zones.has(zone_id):
		visited_zones[zone_id] = true
	
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


const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"
const SCENE_BAKUNAWA := "res://scenes/world/climax/Bakunawa.tscn"


func get_post_zone_scene() -> String:
	if climax_triggered:
		return SCENE_BAKUNAWA
	return SCENE_FOREST_HUB


func change_to_post_zone_scene(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.change_scene_to_file(get_post_zone_scene())


func _reset_clues() -> void:
	for zone_id in collected_clues:
		collected_clues[zone_id].collected = false


func reset_game_after_nightfall() -> void:
	attempt_count += 1
	nightfall_attempts += 1
	_reset_clues()
	_reset_visited_zones()
	_session_seed = randi()
	_initialize_puzzle_seeds()
	current_zone = "forest_hub"
	climax_triggered = false
	solved_puzzles.clear()
	forest_intro_played = false
	# â† Do NOT reset forest_tutorial_shown here â€” tutorial only shows once ever
	game_reset.emit()
	_save_progress("nightfall_reset")


func has_clue(zone_id: String) -> bool:
	if not collected_clues.has(zone_id):
		return false
	return bool(collected_clues[zone_id].get("collected", false))

func mark_zone_visited(zone_id: String) -> bool:
	if not visited_zones.has(zone_id):
		push_warning("[GameState] Unknown zone visited: " + zone_id)
		return false

	var was_already_visited: bool = bool(visited_zones.get(zone_id, false))

	visited_zones[zone_id] = true
	current_zone = zone_id

	if not was_already_visited:
		zone_visited.emit(zone_id)
		_save_progress("zone_visited")

	return true


func has_zone_visited(zone_id: String) -> bool:
	if bool(visited_zones.get(zone_id, false)):
		return true

	# For old saves: if the zone was already completed before this feature existed,
	# still show the zone marker on the map.
	if has_clue(zone_id):
		return true

	return GameState.zones_status.get(zone_id, GameState.ZoneStatus.AVAILABLE) == GameState.ZoneStatus.COMPLETED


func _reset_visited_zones() -> void:
	for zone_id in visited_zones.keys():
		visited_zones[zone_id] = false

func get_briefcase_texture(context: String) -> Texture2D:
	var path := get_briefcase_texture_path(context)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func get_briefcase_texture_path(context: String) -> String:
	match context:
		"forest":
			return BRIEFCASE_ASSETS["no_clue"]
		"pinas_house_reveal":
			return BRIEFCASE_ASSETS["pinas_house_reveal"]
		"backyard_path_reveal":
			return BRIEFCASE_ASSETS["backyard_path_reveal"]
		"old_well_reveal":
			return BRIEFCASE_ASSETS["old_well_reveal"]
		"abandoned_house_reveal":
			return BRIEFCASE_ASSETS["abandoned_house_reveal"]
		"storage_hut_reveal":
			return BRIEFCASE_ASSETS["storage_hut_reveal"]
		"abandoned_house":
			return _get_abandoned_house_briefcase_texture_path()
	return BRIEFCASE_ASSETS["no_clue"]


func _get_abandoned_house_briefcase_texture_path() -> String:
	var has_puzzle_1_items := (
		has_zone_item("abandoned_house", "key_fragment_1")
		or has_zone_item("abandoned_house", "card_piece")
	)
	var has_puzzle_2_items := (
		has_zone_item("abandoned_house", "key_fragment_2")
		or has_zone_item("abandoned_house", "light_bulb")
	)
	var has_key_fragment_3 := has_zone_item("abandoned_house", "key_fragment_3")
	var has_full_key := has_zone_item("abandoned_house", "assembled_key")
	var mirror_lit := is_puzzle_solved("abandoned_house_mirror_lit")
	var cabinet_opened := is_puzzle_solved("abandoned_house_cabinet_opened")

	if cabinet_opened:
		return BRIEFCASE_ASSETS["abandoned_house_default"]
	elif has_full_key:
		return BRIEFCASE_ASSETS["abandoned_house_full_key"]
	elif has_key_fragment_3:
		return BRIEFCASE_ASSETS["abandoned_house_puzzle_3"]
	elif mirror_lit:
		return BRIEFCASE_ASSETS["abandoned_house_used_lighter"]
	elif has_puzzle_2_items:
		return BRIEFCASE_ASSETS["abandoned_house_puzzle_2"]
	elif has_puzzle_1_items:
		return BRIEFCASE_ASSETS["abandoned_house_puzzle_1"]
	else:
		return BRIEFCASE_ASSETS["abandoned_house_default"]


func get_save_data() -> Dictionary:
	return {
		"collected_clues":           collected_clues.duplicate(true),
		"visited_zones": 			 visited_zones.duplicate(true),
		"solved_puzzles":            solved_puzzles.duplicate(true),
		"zones_status":              zones_status.duplicate(true),
		"current_zone":              current_zone,
		"climax_triggered":          climax_triggered,
		"game_completed":            game_completed,
		"attempt_count":             attempt_count,
		"nightfall_attempts":        nightfall_attempts,
		"ledger_entries":            ledger_entries.duplicate(true),
		"puzzle_seeds":              puzzle_seeds.duplicate(true),
		"puzzle_variation_indices":  puzzle_variation_indices.duplicate(true),
		"session_seed":              _session_seed,
		"selected_costumes":         selected_costumes.duplicate(true),
		"_costume_confirmed_status": _costume_confirmed_status.duplicate(true),
		"zone_inventory":            zone_inventory.duplicate(true),
		"forest_tutorial_shown":     forest_tutorial_shown,  # â† added
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("collected_clues"):
		collected_clues = data["collected_clues"].duplicate(true)
	if data.has("solved_puzzles"):
		solved_puzzles = data["solved_puzzles"].duplicate(true)
	if data.has("zones_status"):
		zones_status = data["zones_status"].duplicate(true)
	if data.has("current_zone"):
		current_zone = data["current_zone"]
	if data.has("visited_zones"):
		var saved_visited_zones: Dictionary = data["visited_zones"]
		for zone_id in visited_zones.keys():
			visited_zones[zone_id] = bool(saved_visited_zones.get(zone_id, false))
	if data.has("climax_triggered"):
		climax_triggered = data["climax_triggered"]
	if data.has("game_completed"):
		game_completed = data["game_completed"]
	if data.has("attempt_count"):
		attempt_count = data["attempt_count"]
	if data.has("nightfall_attempts"):
		nightfall_attempts = data["nightfall_attempts"]
	if data.has("ledger_entries"):
		ledger_entries = data["ledger_entries"].duplicate(true)
	if data.has("selected_costumes"):
		selected_costumes = data["selected_costumes"].duplicate(true)
	if data.has("_costume_confirmed_status"):
		_costume_confirmed_status = data["_costume_confirmed_status"].duplicate(true)
	if data.has("zone_inventory"):
		zone_inventory = data["zone_inventory"].duplicate(true)
	if data.has("forest_tutorial_shown"):
		forest_tutorial_shown = data["forest_tutorial_shown"]  # â† added
	if data.has("session_seed"):
		_session_seed = int(data["session_seed"])

	_initialize_puzzle_seeds()

	if data.has("puzzle_seeds"):
		puzzle_seeds = data["puzzle_seeds"].duplicate(true)
	if data.has("puzzle_variation_indices"):
		puzzle_variation_indices = data["puzzle_variation_indices"].duplicate(true)

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
		return int(puzzle_seeds[zone_id])
	if _session_seed == 0:
		_initialize_puzzle_seeds()
	if puzzle_seeds.has(zone_id):
		return int(puzzle_seeds[zone_id])
	return int(hash(str(_session_seed) + ":" + zone_id))


func force_puzzle_variation_index(zone_id: String, variation_index: int) -> void:
	puzzle_variation_indices[zone_id] = variation_index


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
	_reset_visited_zones()
	for zone_id in zone_inventory:
		for item_id in zone_inventory[zone_id]:
			zone_inventory[zone_id][item_id] = false
	for zone_id in zones_status:
		zones_status[zone_id] = ZoneStatus.AVAILABLE
	current_zone       = "forest_hub"
	climax_triggered   = false
	game_completed     = false
	attempt_count      = 0
	nightfall_attempts = 0
	ledger_entries.clear()
	solved_puzzles.clear()
	_session_seed = randi()
	_initialize_puzzle_seeds()
	reset_costume_selections()
	forest_intro_played = false
	forest_tutorial_shown = false  # â† reset only on full wipe, not nightfall
	if LocalSaveManager:
		LocalSaveManager.delete_save()
	game_reset.emit()


func get_role_display_text() -> String:
	match local_role:
		Role.DETECTIVE: return "DETECTIVE (Host)"
		Role.SIDEKICK:  return "SIDEKICK (Client)"
		_:              return "NO ROLE ASSIGNED"


func ensure_zone_inventory(zone_id: String) -> void:
	if not zone_inventory.has(zone_id):
		zone_inventory[zone_id] = {}


func has_zone_item(zone_id: String, item_id: String) -> bool:
	return bool(zone_inventory.get(zone_id, {}).get(item_id, false))


func grant_zone_item(zone_id: String, item_id: String, auto_save: bool = true) -> void:
	ensure_zone_inventory(zone_id)
	if bool(zone_inventory[zone_id].get(item_id, false)):
		return
	zone_inventory[zone_id][item_id] = true
	briefcase_updated.emit()
	if auto_save:
		_save_progress("zone_item_granted")


func grant_zone_items(zone_id: String, item_ids: Array) -> void:
	ensure_zone_inventory(zone_id)
	var changed: bool = false
	for raw_item_id in item_ids:
		var item_id: String = str(raw_item_id)
		if not bool(zone_inventory[zone_id].get(item_id, false)):
			zone_inventory[zone_id][item_id] = true
			changed = true
	if changed:
		briefcase_updated.emit()
		_save_progress("zone_items_granted")

func remove_zone_item(zone_id: String, item_id: String, auto_save: bool = true) -> void:
	ensure_zone_inventory(zone_id)

	if not bool(zone_inventory[zone_id].get(item_id, false)):
		return

	zone_inventory[zone_id][item_id] = false
	briefcase_updated.emit()

	if auto_save:
		_save_progress("zone_item_removed")


func remove_zone_items(zone_id: String, item_ids: Array) -> void:
	ensure_zone_inventory(zone_id)

	var changed: bool = false

	for raw_item_id in item_ids:
		var item_id: String = str(raw_item_id)

		if bool(zone_inventory[zone_id].get(item_id, false)):
			zone_inventory[zone_id][item_id] = false
			changed = true

	if changed:
		briefcase_updated.emit()
		_save_progress("zone_items_removed")
