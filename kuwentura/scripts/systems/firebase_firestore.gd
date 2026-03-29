extends Node

## Firebase Firestore - Cloud Database Operations
##
## Handles saving/loading game state to/from Firestore.
## Called by FirebaseManager - do not call directly from game logic.

const PROJECT_ID = "kuwentura"
const BASE_URL = (
	"https://firestore.googleapis.com/v1/projects/" + PROJECT_ID + "/databases/(default)/documents"
)

# Pending HTTP requests tracking
var _pending_requests: Dictionary = {}


func _is_configured() -> bool:
	"""Check if Firebase is properly configured."""
	return FirebaseAuth.API_KEY != "YOUR_API_KEY_HERE" and not FirebaseAuth.API_KEY.is_empty()


# SAVE OPERATIONS

func save_game_state(user_id: String, data: Dictionary):
	"""Save game state to Firestore (async, signals result)"""
	if not _is_configured():
		print("[Firestore] Skipping save - Firebase not configured")
		FirebaseManager.on_cloud_save_failed("Firebase not configured")
		return
	
	if user_id.is_empty():
		FirebaseManager.on_cloud_save_failed("No user ID")
		return
	
	var id_token = FirebaseAuth.id_token
	if id_token.is_empty():
		FirebaseManager.on_cloud_save_failed("Not authenticated")
		return
	
	var url = BASE_URL + "/users/" + user_id + "/game_state"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]
	
	var doc = _convert_to_firestore_format(data)
	var body = JSON.stringify(doc)
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var request_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	_pending_requests[request_id] = {"type": "save", "http": http}
	
	http.request_completed.connect(_on_save_response.bind(request_id))
	
	var error = http.request(url, headers, HTTPClient.METHOD_PATCH, body)
	if error != OK:
		FirebaseManager.on_cloud_save_failed("HTTP request failed: " + str(error))
		http.queue_free()
		_pending_requests.erase(request_id)


func save_game_state_async(user_id: String, data: Dictionary) -> Dictionary:
	"""Save game state and return result (for await)"""
	var result = {"success": false, "error": ""}
	
	if not _is_configured():
		result.error = "Firebase not configured"
		return result
	
	if user_id.is_empty():
		result.error = "No user ID"
		return result
	
	var id_token = FirebaseAuth.id_token
	if id_token.is_empty():
		result.error = "Not authenticated"
		return result
	
	var url = BASE_URL + "/users/" + user_id + "/game_state"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]
	
	var doc = _convert_to_firestore_format(data)
	var body = JSON.stringify(doc)
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request(url, headers, HTTPClient.METHOD_PATCH, body)
	
	# Wait for response
	var response = await http.request_completed
	http.queue_free()
	
	var response_code = response[1]
	if response_code == 200 or response_code == 201:
		result.success = true
	else:
		result.error = "HTTP " + str(response_code) + ": " + response[3].get_string_from_utf8()
	
	return result


func _on_save_response(_result, response_code, _headers, body, request_id):
	var request_data = _pending_requests.get(request_id)
	if request_data:
		var http = request_data.http
		http.queue_free()
		_pending_requests.erase(request_id)
	
	if response_code == 200 or response_code == 201:
		print("[Firestore] Save successful")
		FirebaseManager.on_cloud_save_success()
	else:
		var error_text = body.get_string_from_utf8()
		print("[Firestore] Save failed: ", response_code, " - ", error_text)
		FirebaseManager.on_cloud_save_failed("HTTP " + str(response_code))


# LOAD OPERATIONS

func load_game_state():
	"""Load game state from Firestore"""
	if not _is_configured():
		print("[Firestore] Skipping load - Firebase not configured")
		FirebaseManager.on_cloud_load_failed("Firebase not configured")
		return
	
	var user_id = FirebaseAuth.current_user_id
	var id_token = FirebaseAuth.id_token
	
	if user_id.is_empty():
		FirebaseManager.on_cloud_load_failed("No user ID")
		return
	
	if id_token.is_empty():
		FirebaseManager.on_cloud_load_failed("Not authenticated")
		return
	
	var url = BASE_URL + "/users/" + user_id + "/game_state"
	var headers = ["Authorization: Bearer " + id_token]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var request_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	_pending_requests[request_id] = {"type": "load", "http": http}
	
	http.request_completed.connect(_on_load_response.bind(request_id))
	
	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		FirebaseManager.on_cloud_load_failed("HTTP request failed: " + str(error))
		http.queue_free()
		_pending_requests.erase(request_id)


func load_game_state_async() -> Dictionary:
	"""Load game state and return result (for await)"""
	var result = {"success": false, "data": {}, "error": ""}
	
	if not _is_configured():
		result.error = "Firebase not configured"
		return result
	
	var user_id = FirebaseAuth.current_user_id
	var id_token = FirebaseAuth.id_token
	
	if user_id.is_empty():
		result.error = "No user ID"
		return result
	
	if id_token.is_empty():
		result.error = "Not authenticated"
		return result
	
	var url = BASE_URL + "/users/" + user_id + "/game_state"
	var headers = ["Authorization: Bearer " + id_token]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request(url, headers, HTTPClient.METHOD_GET)
	
	var response = await http.request_completed
	http.queue_free()
	
	var response_code = response[1]
	var body = response[3]
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("fields"):
			result.success = true
			result.data = _convert_from_firestore(json["fields"])
		else:
			result.error = "Invalid response format"
	elif response_code == 404:
		result.error = "No save found"
	else:
		result.error = "HTTP " + str(response_code) + ": " + body.get_string_from_utf8()
	
	return result


func _on_load_response(_result, response_code, _headers, body, request_id):
	var request_data = _pending_requests.get(request_id)
	if request_data:
		var http = request_data.http
		http.queue_free()
		_pending_requests.erase(request_id)
	
	print("[Firestore] Load response code: ", response_code)
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("fields"):
			print("[Firestore] Load successful")
			var game_data = _convert_from_firestore(json["fields"])
			FirebaseManager.on_cloud_load_success(game_data)
		else:
			FirebaseManager.on_cloud_load_failed("Invalid response format")
	elif response_code == 404:
		print("[Firestore] No save found (404)")
		FirebaseManager.on_cloud_load_failed("No save found")
	else:
		var error_text = body.get_string_from_utf8()
		print("[Firestore] Load failed: ", response_code, " - ", error_text)
		FirebaseManager.on_cloud_load_failed("HTTP " + str(response_code))


# CHECK EXISTS

func check_save_exists():
	"""Check if a cloud save exists (HEAD request)"""
	if not _is_configured():
		return
	
	var user_id = FirebaseAuth.current_user_id
	var id_token = FirebaseAuth.id_token
	
	if user_id.is_empty() or id_token.is_empty():
		return
	
	var url = BASE_URL + "/users/" + user_id + "/game_state"
	var headers = ["Authorization: Bearer " + id_token]
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_check_response.bind(http))
	http.request(url, headers, HTTPClient.METHOD_HEAD)


func _on_check_response(_result, response_code, _headers, _body, http):
	http.queue_free()
	
	var exists = (response_code == 200)
	var timestamp = 0
	
	# Note: HEAD response doesn't include body, so we can't get timestamp
	# Full load would be needed for that
	FirebaseManager.emit_signal("cloud_status_changed", exists, timestamp)


# DELETE

func delete_document(document_path: String):
	"""Delete a document from Firestore"""
	if not _is_configured():
		return
	
	var id_token = FirebaseAuth.id_token
	if id_token.is_empty():
		return
	
	var url = BASE_URL + "/" + document_path
	var headers = ["Authorization: Bearer " + id_token]
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_delete_response.bind(http))
	http.request(url, headers, HTTPClient.METHOD_DELETE)


func _on_delete_response(_result, response_code, _headers, _body, http):
	http.queue_free()
	print("[Firestore] Delete response: ", response_code)


# DATA CONVERSION

func _convert_to_firestore_format(data: Dictionary) -> Dictionary:
	"""Convert Godot Dictionary to Firestore document format"""
	var fields = {}
	
	for key in data.keys():
		if key.begins_with("_"):
			# Internal fields go in metadata
			continue
		fields[key] = _godot_value_to_firestore(data[key])
	
	# Handle metadata specially
	if data.has("_metadata"):
		fields["_metadata"] = {"mapValue": {"fields": {}}}
		for meta_key in data["_metadata"].keys():
			fields["_metadata"]["mapValue"]["fields"][meta_key] = _godot_value_to_firestore(data["_metadata"][meta_key])
	
	if data.has("_cloud_sync"):
		fields["_cloud_sync"] = {"mapValue": {"fields": {}}}
		for sync_key in data["_cloud_sync"].keys():
			fields["_cloud_sync"]["mapValue"]["fields"][sync_key] = _godot_value_to_firestore(data["_cloud_sync"][sync_key])
	
	return {"fields": fields}


func _godot_value_to_firestore(value) -> Dictionary:
	"""Convert a single Godot value to Firestore format"""
	match typeof(value):
		TYPE_NIL:
			return {"nullValue": null}
		TYPE_BOOL:
			return {"booleanValue": value}
		TYPE_INT:
			return {"integerValue": str(value)}
		TYPE_FLOAT:
			return {"doubleValue": value}
		TYPE_STRING:
			return {"stringValue": value}
		TYPE_ARRAY:
			var values = []
			for item in value:
				values.append(_godot_value_to_firestore(item))
			return {"arrayValue": {"values": values}}
		TYPE_DICTIONARY:
			var fields = {}
			for dict_key in value.keys():
				fields[dict_key] = _godot_value_to_firestore(value[dict_key])
			return {"mapValue": {"fields": fields}}
		TYPE_VECTOR2:
			return {"mapValue": {"fields": {
				"x": {"doubleValue": value.x},
				"y": {"doubleValue": value.y}
			}}}
		_:
			# Fallback to string
			return {"stringValue": str(value)}


func _convert_from_firestore(fields: Dictionary) -> Dictionary:
	"""Convert Firestore document fields to Godot Dictionary"""
	var result = {}
	
	for key in fields.keys():
		result[key] = _firestore_value_to_godot(fields[key])
	
	return result


func _firestore_value_to_godot(field: Dictionary):
	"""Convert a single Firestore value to Godot value"""
	if field.has("nullValue"):
		return null
	elif field.has("booleanValue"):
		return field["booleanValue"]
	elif field.has("integerValue"):
		return int(field["integerValue"])
	elif field.has("doubleValue"):
		return float(field["doubleValue"])
	elif field.has("stringValue"):
		return field["stringValue"]
	elif field.has("arrayValue"):
		var arr = []
		if field["arrayValue"].has("values"):
			for item in field["arrayValue"]["values"]:
				arr.append(_firestore_value_to_godot(item))
		return arr
	elif field.has("mapValue") and field["mapValue"].has("fields"):
		return _convert_from_firestore(field["mapValue"]["fields"])
	else:
		return null
