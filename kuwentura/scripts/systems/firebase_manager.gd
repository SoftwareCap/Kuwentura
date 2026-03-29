extends Node

## Firebase Manager - Cloud Backup & Cross-Device Sync
##
## ROLE: Secondary/Backup System
## Primary save system is LocalSaveManager (always works offline).
##
## Flow:
## 1. Game always saves to LOCAL storage first (guaranteed to work)
## 2. If online and authenticated, sync to cloud (optional, non-blocking)
## 3. On new device, can restore from cloud to local

const API_KEY: String = "AIzaSyBbfAbGualst8-7qpa7CwefDk-j2Xe1aHU"
const PROJECT_ID: String = "kuwentura"
const AUTH_DOMAIN: String = "https://identitytoolkit.googleapis.com/v1"
const FIRESTORE_URL: String = (
	"https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID
)

const FORCE_OFFLINE: bool = false
const SYNC_INTERVAL_MINUTES: int = 2
const SYNC_INTERVAL_SECONDS: int = SYNC_INTERVAL_MINUTES * 60

signal auth_success(user_id: String)
signal auth_failed(error: String)
signal cloud_save_success(timestamp: int)
signal cloud_save_failed(error: String)
signal cloud_load_success(data: Dictionary)
signal cloud_load_failed(error: String)
signal sync_completed(success: bool, message: String)
signal cloud_status_changed(has_cloud_save: bool, timestamp: int)

var auto_sync_enabled: bool = true
var auth_token: String = ""
var user_id: String = ""
var is_authenticated: bool = false
var is_initialized: bool = false

var _last_sync_time: int = 0
var _pending_sync: bool = false
var _sync_in_progress: bool = false
var _cloud_save_timestamp: int = 0
var _cloud_save_exists: bool = false


func _ready() -> void:
	if not is_configured() or FORCE_OFFLINE:
		return
	if FirebaseAuth:
		FirebaseAuth.auth_success.connect(_on_auth_success)
		FirebaseAuth.auth_failed.connect(_on_auth_failed)
		FirebaseAuth.anonymous_login()
	else:
		push_warning("[FirebaseManager] FirebaseAuth not available")
	is_initialized = true


func is_configured() -> bool:
	return API_KEY != "YOUR_API_KEY_HERE" and not API_KEY.is_empty() and not FORCE_OFFLINE


func is_cloud_available() -> bool:
	return is_configured() and is_authenticated and not FORCE_OFFLINE


func get_user_id() -> String:
	return user_id if is_authenticated else ""


func sync_to_cloud() -> bool:
	if not is_cloud_available():
		return false
	if _sync_in_progress:
		_pending_sync = true
		return true
	var now := Time.get_unix_time_from_system()
	if (now - _last_sync_time) < SYNC_INTERVAL_SECONDS:
		_pending_sync = true
		return true
	_perform_cloud_sync()
	return true


func force_cloud_save() -> Dictionary:
	if not is_cloud_available():
		return {"success": false, "error": "Cloud not available"}
	if _sync_in_progress:
		return {"success": false, "error": "Sync already in progress"}
	return await _perform_cloud_sync_async()


func restore_from_cloud(_overwrite_local: bool = true) -> bool:
	if not is_cloud_available():
		cloud_load_failed.emit("Cloud not available")
		return false
	FirebaseFirestore.load_game_state()
	return true


func check_cloud_save() -> bool:
	if not is_cloud_available():
		return false
	FirebaseFirestore.check_save_exists()
	return true


func get_cloud_save_info() -> Dictionary:
	return {
		"exists": _cloud_save_exists,
		"timestamp": _cloud_save_timestamp,
		"formatted_time": _format_timestamp(_cloud_save_timestamp),
		"is_available": is_cloud_available(),
	}


func set_auto_sync(enabled: bool) -> void:
	auto_sync_enabled = enabled


func get_last_sync_time() -> int:
	return _last_sync_time


func get_last_sync_formatted() -> String:
	return _format_timestamp(_last_sync_time)


func _load_local_data() -> Dictionary:
	"""Load game data from the best available local source."""
	if LocalSaveManager:
		return LocalSaveManager.load_game()
	if GameState:
		return GameState.get_save_data()
	return {}


func _perform_cloud_sync() -> void:
	if _sync_in_progress:
		return
	_sync_in_progress = true
	var local_data := _load_local_data()
	if local_data.is_empty():
		_sync_in_progress = false
		return
	local_data["_cloud_sync"] = {
		"device": OS.get_name(),
		"sync_time": Time.get_unix_time_from_system(),
	}
	FirebaseFirestore.save_game_state(user_id, local_data)


func _perform_cloud_sync_async() -> Dictionary:
	_sync_in_progress = true
	var local_data := _load_local_data()
	var result: Variant = await FirebaseFirestore.save_game_state_async(user_id, local_data)
	_sync_in_progress = false
	_last_sync_time = int(Time.get_unix_time_from_system())
	if result.success:
		cloud_save_success.emit(_last_sync_time)
		sync_completed.emit(true, "Sync successful")
	else:
		cloud_save_failed.emit(result.error)
		sync_completed.emit(false, result.error)
	return result


func _on_sync_complete(_success: bool) -> void:
	_sync_in_progress = false
	_last_sync_time = int(Time.get_unix_time_from_system())
	if _pending_sync:
		_pending_sync = false
		await get_tree().create_timer(SYNC_INTERVAL_SECONDS).timeout
		sync_to_cloud()


func _on_auth_success(new_user_id: String, token: String) -> void:
	user_id = new_user_id
	auth_token = token
	is_authenticated = true
	auth_success.emit(user_id)
	check_cloud_save()


func _on_auth_failed(error: String) -> void:
	is_authenticated = false
	if is_configured():
		push_warning("[FirebaseManager] Auth failed: " + error)
	auth_failed.emit(error)


func on_cloud_save_success(timestamp: int = 0) -> void:
	_cloud_save_exists = true
	_cloud_save_timestamp = timestamp if timestamp > 0 else int(Time.get_unix_time_from_system())
	_last_sync_time = _cloud_save_timestamp
	_sync_in_progress = false
	_pending_sync = false
	cloud_save_success.emit(_cloud_save_timestamp)
	cloud_status_changed.emit(true, _cloud_save_timestamp)


func on_cloud_save_failed(error: String) -> void:
	_sync_in_progress = false
	cloud_save_failed.emit(error)


func on_cloud_load_success(cloud_data: Dictionary) -> void:
	if cloud_data.is_empty():
		cloud_load_failed.emit("No cloud save found")
		return

	_cloud_save_exists = true
	_cloud_save_timestamp = cloud_data.get("_metadata", {}).get("timestamp", 0)

	if LocalSaveManager:
		var local_data := LocalSaveManager.load_game()
		var local_time: int = local_data.get("_metadata", {}).get("timestamp", 0)
		if _cloud_save_timestamp > local_time:
			LocalSaveManager.save_game(cloud_data)
			if GameState:
				GameState.load_save_data(cloud_data)
			cloud_load_success.emit(cloud_data)
		else:
			cloud_load_success.emit(local_data)
	else:
		cloud_load_success.emit(cloud_data)

	cloud_status_changed.emit(true, _cloud_save_timestamp)


func on_cloud_load_failed(error: String) -> void:
	cloud_load_failed.emit(error)


func _format_timestamp(unix_time: int) -> String:
	if unix_time == 0:
		return "Never"
	var datetime := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute,
	]


func delete_cloud_save() -> bool:
	if not is_cloud_available():
		return false
	FirebaseFirestore.delete_document("users/" + user_id + "/game_state")
	_cloud_save_exists = false
	_cloud_save_timestamp = 0
	return true


func get_sync_status() -> Dictionary:
	return {
		"is_syncing": _sync_in_progress,
		"pending_sync": _pending_sync,
		"last_sync": _last_sync_time,
		"last_sync_formatted": get_last_sync_formatted(),
		"cloud_available": is_cloud_available(),
		"cloud_save_exists": _cloud_save_exists,
		"auto_sync_enabled": auto_sync_enabled,
	}
