extends Node

## Firebase Manager - Cloud Backup & Cross-Device Sync
##
## ROLE: Secondary/Backup System
## This manager ONLY handles cloud backup functionality.
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

# ============================================================================
# CONFIGURATION
# ============================================================================

## Set to true to completely disable Firebase (pure offline mode)
const FORCE_OFFLINE: bool = false

## Minimum time between cloud syncs (to prevent excessive API calls)
const SYNC_INTERVAL_MINUTES: int = 2

## Auto-sync on save (non-blocking)
var auto_sync_enabled: bool = true

# ============================================================================
# STATE
# ============================================================================

var auth_token: String = ""
var user_id: String = ""
var is_authenticated: bool = false
var is_initialized: bool = false

# Sync tracking
var _last_sync_time: int = 0
var _pending_sync: bool = false
var _sync_in_progress: bool = false

# Cloud save metadata
var _cloud_save_timestamp: int = 0
var _cloud_save_exists: bool = false

# Signals
signal auth_success(user_id: String)
signal auth_failed(error: String)
signal cloud_save_success(timestamp: int)
signal cloud_save_failed(error: String)
signal cloud_load_success(data: Dictionary)
signal cloud_load_failed(error: String)
signal sync_completed(success: bool, message: String)
signal cloud_status_changed(has_cloud_save: bool, timestamp: int)


func _ready():
	# Check if Firebase is configured
	if not _is_configured():
		print("[FirebaseManager] Firebase not configured - running in offline mode")
		return
	
	if FORCE_OFFLINE:
		print("[FirebaseManager] Force offline mode enabled")
		return
	
	# Connect to auth signals
	if FirebaseAuth:
		FirebaseAuth.auth_success.connect(_on_auth_success)
		FirebaseAuth.auth_failed.connect(_on_auth_failed)
		
		# Attempt anonymous login
		FirebaseAuth.anonymous_login()
	else:
		push_warning("[FirebaseManager] FirebaseAuth not available")
	
	is_initialized = true


# ============================================================================
# PUBLIC API - Authentication
# ============================================================================

## Check if Firebase is properly configured
func is_configured() -> bool:
	return _is_configured()


func _is_configured() -> bool:
	return API_KEY != "YOUR_API_KEY_HERE" and not API_KEY.is_empty() and not FORCE_OFFLINE


## Check if we can use cloud features
func is_cloud_available() -> bool:
	return is_configured() and is_authenticated and not FORCE_OFFLINE


## Get current user ID
func get_user_id() -> String:
	return user_id if is_authenticated else ""


# ============================================================================
# PUBLIC API - Cloud Save (Non-Blocking)
# ============================================================================

## Save current local progress to cloud (non-blocking)
## This is called automatically after local saves
func sync_to_cloud() -> bool:
	if not is_cloud_available():
		return false
	
	if _sync_in_progress:
		_pending_sync = true
		return true
	
	# Check if enough time has passed since last sync
	var now = Time.get_unix_time_from_system()
	if (now - _last_sync_time) < (SYNC_INTERVAL_MINUTES * 60):
		# Schedule for later
		_pending_sync = true
		return true
	
	_perform_cloud_sync()
	return true


## Force immediate cloud save (blocking call with callback)
func force_cloud_save() -> Dictionary:
	if not is_cloud_available():
		return {"success": false, "error": "Cloud not available"}
	
	if _sync_in_progress:
		return {"success": false, "error": "Sync already in progress"}
	
	return await _perform_cloud_sync_async()


## Load from cloud and merge with local
## By default, cloud data wins if newer
func restore_from_cloud(_overwrite_local: bool = true) -> bool:
	if not is_cloud_available():
		emit_signal("cloud_load_failed", "Cloud not available")
		return false
	
	print("[FirebaseManager] Restoring from cloud...")
	FirebaseFirestore.load_game_state()
	return true


## Check if cloud save exists and get its info
func check_cloud_save() -> bool:
	if not is_cloud_available():
		return false
	
	FirebaseFirestore.check_save_exists()
	return true


## Get cloud save info (for display)
func get_cloud_save_info() -> Dictionary:
	return {
		"exists": _cloud_save_exists,
		"timestamp": _cloud_save_timestamp,
		"formatted_time": _format_timestamp(_cloud_save_timestamp),
		"is_available": is_cloud_available()
	}


# ============================================================================
# PUBLIC API - Settings
# ============================================================================

## Enable/disable auto cloud sync
func set_auto_sync(enabled: bool):
	auto_sync_enabled = enabled


## Get last sync time
func get_last_sync_time() -> int:
	return _last_sync_time


## Format last sync time for display
func get_last_sync_formatted() -> String:
	return _format_timestamp(_last_sync_time)


# ============================================================================
# PRIVATE - Sync Implementation
# ============================================================================

func _perform_cloud_sync():
	"""Perform actual cloud sync (async)"""
	if _sync_in_progress:
		return
	
	_sync_in_progress = true
	
	# Get local data
	var local_data = {}
	if LocalSaveManager:
		local_data = LocalSaveManager.load_game()
	elif GameState:
		local_data = GameState.get_save_data()
	
	if local_data.is_empty():
		print("[FirebaseManager] No local data to sync")
		_sync_in_progress = false
		return
	
	# Add sync metadata
	local_data["_cloud_sync"] = {
		"device": OS.get_name(),
		"sync_time": Time.get_unix_time_from_system()
	}
	
	# Save to Firestore
	FirebaseFirestore.save_game_state(user_id, local_data)
	print("[FirebaseManager] Cloud sync started")


func _perform_cloud_sync_async() -> Dictionary:
	"""Perform cloud sync and wait for result"""
	_sync_in_progress = true
	
	var local_data = {}
	if LocalSaveManager:
		local_data = LocalSaveManager.load_game()
	elif GameState:
		local_data = GameState.get_save_data()
	
	# Wait for save completion
	var result = await FirebaseFirestore.save_game_state_async(user_id, local_data)
	
	_sync_in_progress = false
	_last_sync_time = Time.get_unix_time_from_system()
	
	if result.success:
		emit_signal("cloud_save_success", _last_sync_time)
		emit_signal("sync_completed", true, "Sync successful")
	else:
		emit_signal("cloud_save_failed", result.error)
		emit_signal("sync_completed", false, result.error)
	
	return result


func _on_sync_complete(_success: bool):
	"""Handle sync completion"""
	_sync_in_progress = false
	_last_sync_time = Time.get_unix_time_from_system()
	
	if _pending_sync:
		_pending_sync = false
		# Schedule another sync after interval
		await get_tree().create_timer(SYNC_INTERVAL_MINUTES * 60).timeout
		sync_to_cloud()


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_auth_success(new_user_id: String, token: String):
	user_id = new_user_id
	auth_token = token
	is_authenticated = true
	print("[FirebaseManager] Auth success: ", user_id)
	emit_signal("auth_success", user_id)
	
	# Check for existing cloud save
	check_cloud_save()


func _on_auth_failed(error: String):
	is_authenticated = false
	if _is_configured():
		push_warning("[FirebaseManager] Auth failed: " + error)
	emit_signal("auth_failed", error)


## Called by Firestore when save completes
func on_cloud_save_success(timestamp: int = 0):
	print("[FirebaseManager] Cloud save successful")
	_cloud_save_exists = true
	_cloud_save_timestamp = timestamp if timestamp > 0 else Time.get_unix_time_from_system()
	_last_sync_time = _cloud_save_timestamp
	_sync_in_progress = false
	
	emit_signal("cloud_save_success", _cloud_save_timestamp)
	emit_signal("cloud_status_changed", true, _cloud_save_timestamp)
	
	if _pending_sync:
		_pending_sync = false


## Called by Firestore when save fails
func on_cloud_save_failed(error: String):
	print("[FirebaseManager] Cloud save failed: ", error)
	_sync_in_progress = false
	emit_signal("cloud_save_failed", error)


## Called by Firestore when load completes
func on_cloud_load_success(cloud_data: Dictionary):
	print("[FirebaseManager] Cloud load successful")
	
	if cloud_data.is_empty():
		emit_signal("cloud_load_failed", "No cloud save found")
		return
	
	_cloud_save_exists = true
	_cloud_save_timestamp = cloud_data.get("_metadata", {}).get("timestamp", 0)
	
	# Merge or overwrite local save
	if LocalSaveManager:
		var local_data = LocalSaveManager.load_game()
		var local_time = local_data.get("_metadata", {}).get("timestamp", 0)
		
		if _cloud_save_timestamp > local_time:
			# Cloud is newer, overwrite local
			print("[FirebaseManager] Cloud save is newer, restoring to local")
			LocalSaveManager.save_game(cloud_data)
			
			# Update GameState
			if GameState:
				GameState.load_save_data(cloud_data)
			
			emit_signal("cloud_load_success", cloud_data)
		else:
			# Local is newer or same, keep local
			print("[FirebaseManager] Local save is newer, keeping local")
			emit_signal("cloud_load_success", local_data)
	else:
		# No LocalSaveManager, just signal
		emit_signal("cloud_load_success", cloud_data)
	
	emit_signal("cloud_status_changed", true, _cloud_save_timestamp)


## Called by Firestore when load fails
func on_cloud_load_failed(error: String):
	print("[FirebaseManager] Cloud load failed: ", error)
	emit_signal("cloud_load_failed", error)


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _format_timestamp(unix_time: int) -> String:
	if unix_time == 0:
		return "Never"
	
	var datetime = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute
	]


## Delete cloud save (for testing/account reset)
func delete_cloud_save() -> bool:
	if not is_cloud_available():
		return false
	
	FirebaseFirestore.delete_document("users/" + user_id + "/game_state")
	_cloud_save_exists = false
	_cloud_save_timestamp = 0
	return true


## Get sync status for UI display
func get_sync_status() -> Dictionary:
	return {
		"is_syncing": _sync_in_progress,
		"pending_sync": _pending_sync,
		"last_sync": _last_sync_time,
		"last_sync_formatted": get_last_sync_formatted(),
		"cloud_available": is_cloud_available(),
		"cloud_save_exists": _cloud_save_exists,
		"auto_sync_enabled": auto_sync_enabled
	}


## Manual trigger for cloud operations from UI
func manual_sync_to_cloud() -> bool:
	return sync_to_cloud()


func manual_restore_from_cloud() -> bool:
	return restore_from_cloud()
