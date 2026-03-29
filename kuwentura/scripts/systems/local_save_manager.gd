extends Node

## Local Save Manager - Primary save system (Local-First Architecture)
## Uses FileAccess for JSON-based save files in user:// directory.

## PRIMARY save system — Firebase is only used for cloud backup.
## Game works 100% offline without any internet connection.

signal save_completed(success: bool, error_message: String)
signal load_completed(success: bool, data: Dictionary, error_message: String)
signal auto_save_triggered
signal backup_restored(backup_index: int)

const SAVE_FILE_NAME: String = "user://kwentura_save.json"
const MAX_BACKUP_COUNT: int = 3
const SAVE_VERSION: String = "1.0"

var last_save_time: int  = 0
var total_saves: int = 0

var auto_save_enabled: bool = true
var auto_save_interval_sec: float = 30.0
var auto_save_on_progress: bool = true
var _auto_save_timer: float = 0.0

var _session_start_time: int = 0
var _total_play_time_seconds: int = 0

var cloud_sync_enabled: bool = true
var cloud_sync_interval_minutes: int = 5
var _last_cloud_sync: int = 0


func _ready() -> void:
	_session_start_time = int(Time.get_unix_time_from_system())
	_ensure_save_directory()
	call_deferred("_connect_game_state_signals")


func _process(delta: float) -> void:
	if auto_save_enabled:
		_auto_save_timer += delta
		if _auto_save_timer >= auto_save_interval_sec:
			_auto_save_timer = 0.0
			_trigger_auto_save()


func _connect_game_state_signals() -> void:
	if GameState:
		GameState.clue_collected.connect(_on_clue_collected)
		GameState.zone_completed.connect(_on_zone_completed)
		GameState.game_reset.connect(_on_game_reset)


func save_game(data: Dictionary = {}) -> bool:
	if data.is_empty() and GameState:
		data = GameState.get_save_data()
	if data.is_empty():
		push_warning("[LocalSaveManager] No data to save")
		return false

	var enriched_data := _enrich_save_data(data)
	_create_backup()

	# Atomic write: write to temp then rename to prevent corruption on crash
	var temp_path := SAVE_FILE_NAME + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("[LocalSaveManager] Failed to open temp file: " + str(error))
		save_completed.emit(false, "Failed to open file: " + str(error))
		return false

	file.store_string(JSON.stringify(enriched_data, "\t"))
	file.close()

	var rename_error := DirAccess.rename_absolute(temp_path, SAVE_FILE_NAME)
	if rename_error != OK:
		push_error("[LocalSaveManager] Failed to rename temp file: " + str(rename_error))
		save_completed.emit(false, "Failed to finalize save")
		return false

	last_save_time = int(Time.get_unix_time_from_system())
	total_saves += 1
	save_completed.emit(true, "")
	_trigger_cloud_sync()
	return true


func quick_save() -> bool:
	if GameState:
		return save_game(GameState.get_save_data())
	return false


func save_game_async(data: Dictionary = {}) -> Dictionary:
	return {
		"success": save_game(data),
		"timestamp": last_save_time,
		"file_path": SAVE_FILE_NAME,
	}


func load_game() -> Dictionary:
	if not has_save_file():
		load_completed.emit(false, {}, "No save file found")
		return {}

	var file := FileAccess.open(SAVE_FILE_NAME, FileAccess.READ)
	if file == null:
		push_error("[LocalSaveManager] Failed to open save file: " + str(FileAccess.get_open_error()))
		return _restore_from_backup()

	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if data == null or not data is Dictionary:
		push_error("[LocalSaveManager] Save file is corrupted (invalid JSON)")
		return _restore_from_backup()

	if not _validate_save_version(data):
		push_warning("[LocalSaveManager] Save version mismatch, attempting migration")
		data = _migrate_save_data(data)

	_total_play_time_seconds = data.get("play_time_seconds", 0)
	load_completed.emit(true, data, "")
	return data


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_NAME)


func get_save_file_size() -> int:
	if not has_save_file():
		return 0
	var file := FileAccess.open(SAVE_FILE_NAME, FileAccess.READ)
	if file:
		var size := file.get_length()
		file.close()
		return size
	return 0


func delete_save() -> bool:
	if has_save_file():
		var error := DirAccess.remove_absolute(SAVE_FILE_NAME)
		if error != OK:
			push_error("[LocalSaveManager] Failed to delete save: " + str(error))
			return false

	for i in range(1, MAX_BACKUP_COUNT + 1):
		var path := _backup_path(i)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	return true


func reset_all_progress() -> bool:
	if delete_save():
		total_saves = 0
		last_save_time = 0
		_total_play_time_seconds = 0
		return true
	return false


func get_save_info() -> Dictionary:
	if not has_save_file():
		return {
			"exists": false, "last_save_time": 0, "play_time": 0,
			"zones_completed": 0, "game_completed": false,
		}
	var data := load_game()
	if data.is_empty():
		return {"exists": false, "error": "Failed to load save"}

	var clues: Dictionary = data.get("collected_clues", {})
	var completed_zones := 0
	for zone_id in clues:
		if clues[zone_id].get("collected", false):
			completed_zones += 1

	var meta: Dictionary = data.get("_metadata", {})
	return {
		"exists": true,
		"last_save_time": meta.get("timestamp", 0),
		"play_time": data.get("play_time_seconds", 0),
		"zones_completed":completed_zones,
		"game_completed": data.get("game_completed", false),
		"current_zone": data.get("current_zone", "forest_hub"),
		"save_version": meta.get("version", "unknown"),
		"platform": meta.get("platform", "unknown"),
		"total_saves": meta.get("total_saves", 0),
		"file_size": get_save_file_size(),
	}


func format_play_time(seconds: int) -> String:
	var s := float(seconds)
	return "%02d:%02d:%02d" % [int(s / 3600.0), int(fmod(s, 3600.0) / 60.0), int(fmod(s, 60.0))]


func format_timestamp(unix_time: int) -> String:
	if unix_time == 0:
		return "Never"
	var datetime := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute,
	]


func set_cloud_sync(enabled: bool) -> void:
	cloud_sync_enabled = enabled


func sync_to_cloud() -> bool:
	if not cloud_sync_enabled:
		return false
	_trigger_cloud_sync()
	return true


func is_cloud_sync_due() -> bool:
	if not cloud_sync_enabled:
		return false
	var now := int(Time.get_unix_time_from_system())
	return (now - _last_cloud_sync) >= (cloud_sync_interval_minutes * 60)


func _backup_path(index: int) -> String:
	return SAVE_FILE_NAME + ".backup" + str(index)


func _read_json_file(path: String) -> Variant:
	"""Open a file, parse its JSON content, and return the result or null."""
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return data


func _enrich_save_data(data: Dictionary) -> Dictionary:
	var enriched := data.duplicate(true)
	var session_duration := int(Time.get_unix_time_from_system()) - _session_start_time
	enriched["play_time_seconds"] = _total_play_time_seconds + session_duration
	enriched["_metadata"] = {
		"version": SAVE_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"platform": OS.get_name(),
		"total_saves": total_saves + 1,
	}
	return enriched


func _validate_save_version(data: Dictionary) -> bool:
	return data.get("_metadata", {}).get("version", "0.0") == SAVE_VERSION


func _migrate_save_data(data: Dictionary) -> Dictionary:
	var version: String = data.get("_metadata", {}).get("version", "0.0")
	if version.begins_with("0."):
		if not data.has("play_time_seconds"):
			data["play_time_seconds"] = 0
		if not data.has("solved_puzzles"):
			data["solved_puzzles"] = {}
	if not data.has("_metadata"):
		data["_metadata"] = {}
	data["_metadata"]["version"] = SAVE_VERSION
	data["_metadata"]["migrated"] = true
	data["_metadata"]["original_version"] = version
	return data


func _create_backup() -> void:
	if not has_save_file():
		return
	for i in range(MAX_BACKUP_COUNT - 1, 0, -1):
		var old_path := _backup_path(i)
		var new_path := _backup_path(i + 1)
		if FileAccess.file_exists(old_path):
			DirAccess.remove_absolute(new_path)
			DirAccess.rename_absolute(old_path, new_path)
	DirAccess.copy_absolute(SAVE_FILE_NAME, _backup_path(1))


func _restore_from_backup() -> Dictionary:
	for i in range(1, MAX_BACKUP_COUNT + 1):
		var path := _backup_path(i)
		if FileAccess.file_exists(path):
			var data: Variant = _read_json_file(path)
			if data != null and data is Dictionary:
				backup_restored.emit(i)
				load_completed.emit(true, data, "Restored from backup")
				return data
	load_completed.emit(false, {}, "All save files corrupted")
	return {}


func _ensure_save_directory() -> void:
	if DirAccess.open("user://") == null:
		push_error("[LocalSaveManager] Cannot access user directory")


func _trigger_auto_save() -> void:
	if GameState and GameState.get_collected_count() > 0:
		auto_save_triggered.emit()
		save_game()


func _trigger_cloud_sync() -> void:
	if cloud_sync_enabled and FirebaseManager and FirebaseManager.is_authenticated:
		if is_cloud_sync_due():
			FirebaseManager.sync_to_cloud()
			_last_cloud_sync = int(Time.get_unix_time_from_system())


func _auto_save_on_progress(deferred: bool = false) -> void:
	if not auto_save_on_progress:
		return
	if deferred:
		call_deferred("save_game")
	else:
		save_game()


func _on_clue_collected(_zone_id: String, _clue_data: Dictionary) -> void:
	_auto_save_on_progress()


func _on_zone_completed(_zone_id: String) -> void:
	_auto_save_on_progress()


func _on_game_reset() -> void:
	_auto_save_on_progress(true)


func export_save_as_string() -> String:
	var data := load_game()
	if data.is_empty():
		return "{}"
	return JSON.stringify(data, "\t")


func import_save_from_string(json_string: String) -> bool:
	var data: Variant = JSON.parse_string(json_string)
	if data == null or not data is Dictionary:
		push_error("[LocalSaveManager] Invalid import data")
		return false
	return save_game(data)


func get_backups_info() -> Array:
	var backups: Array = []
	for i in range(1, MAX_BACKUP_COUNT + 1):
		var path := _backup_path(i)
		if FileAccess.file_exists(path):
			var data: Variant = _read_json_file(path)
			if data != null:
				var meta: Dictionary = data.get("_metadata", {})
				backups.append({
					"index": i,
					"timestamp": meta.get("timestamp", 0),
					"version": meta.get("version", "unknown"),
				})
	return backups
