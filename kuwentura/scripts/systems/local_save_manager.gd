extends Node

## Local Save Manager - Primary save system (Local-First Architecture)
## Uses FileAccess for JSON-based save files in user:// directory
##
## This is the PRIMARY save system. Firebase is only used for cloud backup.
## Game works 100% offline without any internet connection.

signal save_completed(success: bool, error_message: String)
signal load_completed(success: bool, data: Dictionary, error_message: String)
signal auto_save_triggered
signal backup_restored(backup_index: int)

const SAVE_FILE_NAME: String = "user://kwentura_save.json"
const BACKUP_FILE_NAME: String = "user://kwentura_save.backup"
const MAX_BACKUP_COUNT: int = 3
const SAVE_VERSION: String = "1.0"

# Save metadata (persisted in save file)
var last_save_time: int = 0
var total_saves: int = 0

# Auto-save settings
var auto_save_enabled: bool = true
var auto_save_interval_sec: float = 30.0
var auto_save_on_progress: bool = true  # Save when clues collected, zones completed
var _auto_save_timer: float = 0.0

# Play time tracking
var _session_start_time: int = 0
var _total_play_time_seconds: int = 0

# Cloud sync settings
var cloud_sync_enabled: bool = true
var cloud_sync_interval_minutes: int = 5
var _last_cloud_sync: int = 0


func _ready():
	print("[LocalSaveManager] Initialized")
	_session_start_time = Time.get_unix_time_from_system()
	_ensure_save_directory()
	
	# Connect to GameState signals for auto-save
	call_deferred("_connect_game_state_signals")


func _process(delta: float):
	if auto_save_enabled:
		_auto_save_timer += delta
		if _auto_save_timer >= auto_save_interval_sec:
			_auto_save_timer = 0.0
			_trigger_auto_save()


func _connect_game_state_signals():
	if GameState:
		GameState.clue_collected.connect(_on_clue_collected)
		GameState.zone_completed.connect(_on_zone_completed)
		GameState.game_reset.connect(_on_game_reset)


# ============================================================================
# PUBLIC API - Save Operations
# ============================================================================

## Save game data to local storage
## Returns true if successful, false otherwise
func save_game(data: Dictionary = {}) -> bool:
	# Use GameState data if none provided
	if data.is_empty() and GameState:
		data = GameState.get_save_data()
	
	if data.is_empty():
		push_warning("[LocalSaveManager] No data to save")
		return false
	
	var enriched_data = _enrich_save_data(data)
	
	# Create backup of existing save before overwriting
	_create_backup()
	
	# Write to temp file first (atomic write prevents corruption)
	var temp_path = SAVE_FILE_NAME + ".tmp"
	var json_string = JSON.stringify(enriched_data, "\t")
	
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("[LocalSaveManager] Failed to open temp file: " + str(error))
		emit_signal("save_completed", false, "Failed to open file: " + str(error))
		return false
	
	file.store_string(json_string)
	file.close()
	
	# Atomic rename (prevents corruption if crash during write)
	var rename_error = DirAccess.rename_absolute(temp_path, SAVE_FILE_NAME)
	if rename_error != OK:
		push_error("[LocalSaveManager] Failed to rename temp file: " + str(rename_error))
		emit_signal("save_completed", false, "Failed to finalize save")
		return false
	
	last_save_time = Time.get_unix_time_from_system()
	total_saves += 1
	
	print("[LocalSaveManager] Game saved successfully")
	emit_signal("save_completed", true, "")
	
	# Trigger cloud sync if enabled (non-blocking)
	_trigger_cloud_sync()
	
	return true


## Quick save - save current GameState immediately
func quick_save() -> bool:
	if GameState:
		return save_game(GameState.get_save_data())
	return false


## Save with custom callback
func save_game_async(data: Dictionary = {}) -> Dictionary:
	var result = save_game(data)
	return {
		"success": result,
		"timestamp": last_save_time,
		"file_path": SAVE_FILE_NAME
	}


# ============================================================================
# PUBLIC API - Load Operations
# ============================================================================

## Load game data from local storage
## Returns Dictionary with save data, or empty {} if no save exists
func load_game() -> Dictionary:
	if not has_save_file():
		print("[LocalSaveManager] No save file found")
		emit_signal("load_completed", false, {}, "No save file found")
		return {}
	
	var file = FileAccess.open(SAVE_FILE_NAME, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("[LocalSaveManager] Failed to open save file: " + str(error))
		return _restore_from_backup()
	
	var json_string = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json_string)
	if data == null or not data is Dictionary:
		push_error("[LocalSaveManager] Save file is corrupted (invalid JSON)")
		return _restore_from_backup()
	
	# Validate save version
	if not _validate_save_version(data):
		push_warning("[LocalSaveManager] Save version mismatch, attempting migration")
		data = _migrate_save_data(data)
	
	# Update play time tracking
	_total_play_time_seconds = data.get("play_time_seconds", 0)
	
	print("[LocalSaveManager] Game loaded successfully")
	emit_signal("load_completed", true, data, "")
	return data


## Check if save file exists
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_NAME)


## Get save file size in bytes (for display)
func get_save_file_size() -> int:
	if not has_save_file():
		return 0
	var file = FileAccess.open(SAVE_FILE_NAME, FileAccess.READ)
	if file:
		var size = file.get_length()
		file.close()
		return size
	return 0


# ============================================================================
# PUBLIC API - Delete/Reset
# ============================================================================

## Delete save file (for reset/new game)
## Returns true if successful or no file exists
func delete_save() -> bool:
	if has_save_file():
		var error = DirAccess.remove_absolute(SAVE_FILE_NAME)
		if error != OK:
			push_error("[LocalSaveManager] Failed to delete save: " + str(error))
			return false
	
	# Also delete backups
	for i in range(1, MAX_BACKUP_COUNT + 1):
		var backup_path = SAVE_FILE_NAME + ".backup" + str(i)
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
	
	print("[LocalSaveManager] Save file and backups deleted")
	return true


## Reset all progress and start fresh
func reset_all_progress() -> bool:
	if delete_save():
		total_saves = 0
		last_save_time = 0
		_total_play_time_seconds = 0
		return true
	return false


# ============================================================================
# PUBLIC API - Save Info / Metadata
# ============================================================================

## Get save file info for display (main menu, etc.)
func get_save_info() -> Dictionary:
	if not has_save_file():
		return {
			"exists": false,
			"last_save_time": 0,
			"play_time": 0,
			"zones_completed": 0,
			"game_completed": false
		}
	
	var data = load_game()
	if data.is_empty():
		return {"exists": false, "error": "Failed to load save"}
	
	var clues = data.get("collected_clues", {})
	var completed_zones = 0
	for zone_id in clues.keys():
		if clues[zone_id].get("collected", false):
			completed_zones += 1
	
	return {
		"exists": true,
		"last_save_time": data.get("_metadata", {}).get("timestamp", 0),
		"play_time": data.get("play_time_seconds", 0),
		"zones_completed": completed_zones,
		"game_completed": data.get("game_completed", false),
		"current_zone": data.get("current_zone", "forest_hub"),
		"save_version": data.get("_metadata", {}).get("version", "unknown"),
		"platform": data.get("_metadata", {}).get("platform", "unknown"),
		"total_saves": data.get("_metadata", {}).get("total_saves", 0),
		"file_size": get_save_file_size()
	}


## Format play time for display (HH:MM:SS)
func format_play_time(seconds: int) -> String:
	var hours = seconds / 3600
	var minutes = (seconds % 3600) / 60
	var secs = seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]


## Format timestamp for display
func format_timestamp(unix_time: int) -> String:
	if unix_time == 0:
		return "Never"
	
	var datetime = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute
	]


# ============================================================================
# PUBLIC API - Cloud Sync
# ============================================================================

## Enable/disable cloud sync
func set_cloud_sync(enabled: bool):
	cloud_sync_enabled = enabled


## Manually trigger cloud sync
func sync_to_cloud() -> bool:
	if not cloud_sync_enabled:
		return false
	
	_trigger_cloud_sync()
	return true


## Check if cloud sync is due
func is_cloud_sync_due() -> bool:
	if not cloud_sync_enabled:
		return false
	
	var now = Time.get_unix_time_from_system()
	return (now - _last_cloud_sync) >= (cloud_sync_interval_minutes * 60)


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _enrich_save_data(data: Dictionary) -> Dictionary:
	"""Add metadata to save data"""
	var enriched = data.duplicate(true)
	
	# Calculate total play time
	var session_duration = Time.get_unix_time_from_system() - _session_start_time
	enriched["play_time_seconds"] = _total_play_time_seconds + session_duration
	
	# Add metadata
	enriched["_metadata"] = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"platform": OS.get_name(),
		"total_saves": total_saves + 1
	}
	
	return enriched


func _validate_save_version(data: Dictionary) -> bool:
	var version = data.get("_metadata", {}).get("version", "0.0")
	return version == SAVE_VERSION


func _migrate_save_data(data: Dictionary) -> Dictionary:
	"""Migrate older save versions to current version"""
	var version = data.get("_metadata", {}).get("version", "0.0")
	
	# Migration from version 0.x to 1.0
	if version.begins_with("0."):
		# Add any missing fields with defaults
		if not data.has("play_time_seconds"):
			data["play_time_seconds"] = 0
		if not data.has("solved_puzzles"):
			data["solved_puzzles"] = {}
	
	# Update version
	if not data.has("_metadata"):
		data["_metadata"] = {}
	data["_metadata"]["version"] = SAVE_VERSION
	data["_metadata"]["migrated"] = true
	data["_metadata"]["original_version"] = version
	
	return data


func _create_backup():
	"""Create rotating backups of save file"""
	if not has_save_file():
		return
	
	# Shift existing backups (rotate: 2->3, 1->2)
	for i in range(MAX_BACKUP_COUNT - 1, 0, -1):
		var old_backup = SAVE_FILE_NAME + ".backup" + str(i)
		var new_backup = SAVE_FILE_NAME + ".backup" + str(i + 1)
		if FileAccess.file_exists(old_backup):
			DirAccess.remove_absolute(new_backup)  # Remove if exists
			DirAccess.rename_absolute(old_backup, new_backup)
	
	# Create new backup from current save
	DirAccess.copy_absolute(SAVE_FILE_NAME, BACKUP_FILE_NAME)


func _restore_from_backup() -> Dictionary:
	"""Attempt to restore from backup files"""
	print("[LocalSaveManager] Attempting to restore from backup...")
	
	for i in range(1, MAX_BACKUP_COUNT + 1):
		var backup_path = SAVE_FILE_NAME + ".backup" + str(i)
		if FileAccess.file_exists(backup_path):
			var file = FileAccess.open(backup_path, FileAccess.READ)
			if file:
				var data = JSON.parse_string(file.get_as_text())
				file.close()
				if data != null and data is Dictionary:
					print("[LocalSaveManager] Restored from backup ", i)
					emit_signal("backup_restored", i)
					emit_signal("load_completed", true, data, "Restored from backup")
					return data
	
	emit_signal("load_completed", false, {}, "All save files corrupted")
	return {}


func _ensure_save_directory():
	"""Ensure the save directory exists"""
	var dir = DirAccess.open("user://")
	if dir == null:
		push_error("[LocalSaveManager] Cannot access user directory")


func _trigger_auto_save():
	"""Trigger auto-save if game is active"""
	if GameState and GameState.get_collected_count() > 0:
		emit_signal("auto_save_triggered")
		save_game()


func _trigger_cloud_sync():
	"""Non-blocking cloud sync trigger"""
	if not cloud_sync_enabled:
		return
	
	if FirebaseManager and FirebaseManager.is_authenticated:
		if is_cloud_sync_due():
			FirebaseManager.sync_to_cloud()
			_last_cloud_sync = Time.get_unix_time_from_system()


# ============================================================================
# GAME STATE SIGNAL HANDLERS (for auto-save)
# ============================================================================

func _on_clue_collected(_zone_id: String, _clue_data: Dictionary):
	if auto_save_on_progress:
		save_game()


func _on_zone_completed(_zone_id: String):
	if auto_save_on_progress:
		save_game()


func _on_game_reset():
	# Optional: Auto-save after reset to preserve the reset state
	if auto_save_on_progress:
		call_deferred("save_game")


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Export save data as string (for sharing/debugging)
func export_save_as_string() -> String:
	var data = load_game()
	if data.is_empty():
		return "{}"
	return JSON.stringify(data, "\t")


## Import save data from string (for restore from cloud)
func import_save_from_string(json_string: String) -> bool:
	var data = JSON.parse_string(json_string)
	if data == null or not data is Dictionary:
		push_error("[LocalSaveManager] Invalid import data")
		return false
	
	return save_game(data)


## Get all backup files info
func get_backups_info() -> Array:
	var backups = []
	for i in range(1, MAX_BACKUP_COUNT + 1):
		var backup_path = SAVE_FILE_NAME + ".backup" + str(i)
		if FileAccess.file_exists(backup_path):
			var file = FileAccess.open(backup_path, FileAccess.READ)
			if file:
				var data = JSON.parse_string(file.get_as_text())
				file.close()
				if data != null:
					backups.append({
						"index": i,
						"timestamp": data.get("_metadata", {}).get("timestamp", 0),
						"version": data.get("_metadata", {}).get("version", "unknown")
					})
	return backups
