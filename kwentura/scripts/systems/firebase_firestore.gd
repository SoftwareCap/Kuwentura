extends Node

const PROJECT_ID = "kuwentura"
const BASE_URL = (
	"https://firestore.googleapis.com/v1/projects/" + PROJECT_ID + "/databases/(default)/documents"
)


func save_game_state(user_id: String, data: Dictionary):
	if user_id.is_empty():
		print("Cannot save: No user ID")
		return

	var id_token = FirebaseAuth.id_token
	if id_token.is_empty():
		print("Cannot save: Not authenticated")
		return

	var url = BASE_URL + "/users/" + user_id + "/game_state"
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + id_token]  # ✅ Use ID token here

	var doc = {
		"fields":
		{
			"collected_clues": _convert_clues_to_firestore(data.get("collected_clues", {})),
			"zones_status": _convert_dict_to_firestore(data.get("zones_status", {})),
			"current_zone": {"stringValue": data.get("current_zone", "forest_hub")},
			"climax_triggered": {"booleanValue": data.get("climax_triggered", false)},
			"game_completed": {"booleanValue": data.get("game_completed", false)},
			"attempt_count": {"integerValue": str(data.get("attempt_count", 0))},
			"nightfall_attempts": {"integerValue": str(data.get("nightfall_attempts", 0))},
			"puzzle_seeds": _convert_dict_to_firestore(data.get("puzzle_seeds", {})),
			"timestamp": {"stringValue": str(Time.get_unix_time_from_system())}
		}
	}

	var body = JSON.stringify(doc)
	print("Saving to: ", url)
	print("Data: ", body)

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_save_response.bind(http))

	var error = http.request(url, headers, HTTPClient.METHOD_PATCH, body)
	if error != OK:
		print("Save request failed: ", error)


func _convert_clues_to_firestore(clues: Dictionary) -> Dictionary:
	var values = []
	for zone_id in clues.keys():
		var clue_data = clues[zone_id]
		if clue_data is Dictionary and clue_data.get("collected", false):
			values.append(
				{
					"mapValue":
					{
						"fields":
						{
							"zone_id": {"stringValue": zone_id},
							"item": {"stringValue": clue_data.get("item", "")},
							"text": {"stringValue": clue_data.get("text", "")}
						}
					}
				}
			)

	return {"arrayValue": {"values": values}}


func _convert_dict_to_firestore(dict: Dictionary) -> Dictionary:
	var fields = {}
	for key in dict.keys():
		var value = dict[key]
		match typeof(value):
			TYPE_BOOL:
				fields[key] = {"booleanValue": value}
			TYPE_INT:
				fields[key] = {"integerValue": str(value)}
			TYPE_STRING:
				fields[key] = {"stringValue": value}
			_:
				fields[key] = {"stringValue": str(value)}

	return {"mapValue": {"fields": fields}}


func _on_save_response(_result, response_code, _headers, body, http):
	print("Save response code: ", response_code)
	if response_code == 200 or response_code == 201:
		print("Game state saved to Firestore")
	else:
		var error_text = body.get_string_from_utf8()
		print("Save failed: ", response_code, " - ", error_text)

	http.queue_free()


func load_game_state():
	var user_id = FirebaseAuth.current_user_id
	var id_token = FirebaseAuth.id_token
	if user_id.is_empty():
		print("Cannot load: No user ID")
		return

	if id_token.is_empty():
		print("Cannot load: Not authenticated")
		return

	var url = BASE_URL + "/users/" + user_id + "/game_state"
	var headers = ["Authorization: Bearer " + id_token]

	print("Loading from: ", url)

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_load_response.bind(http))

	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("Load request failed: ", error)


func _on_load_response(_result, response_code, _headers, body, http):
	print("Load response code: ", response_code)
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("fields"):
			print("Game state loaded from Firestore")
			# Convert Firestore format back to game data
			var game_data = _convert_from_firestore(json["fields"])
			FirebaseManager.emit_signal("load_success", game_data)
		else:
			print("No data found or invalid format")
			FirebaseManager.emit_signal("load_failed", "No data found")
	elif response_code == 404:
		print("No existing save found (404)")
		FirebaseManager.emit_signal("load_failed", "No save found")
	else:
		var error_text = body.get_string_from_utf8()
		print("Load failed: ", response_code, " - ", error_text)
		FirebaseManager.emit_signal("load_failed", error_text)

	http.queue_free()


func _convert_from_firestore(fields: Dictionary) -> Dictionary:
	var result = {}

	for key in fields.keys():
		var field = fields[key]
		result[key] = _firestore_value_to_godot(field)

	return result


func _firestore_value_to_godot(field: Dictionary):
	if field.has("stringValue"):
		return field["stringValue"]
	elif field.has("integerValue"):
		return int(field["integerValue"])
	elif field.has("booleanValue"):
		return field["booleanValue"]
	elif field.has("doubleValue"):
		return field["doubleValue"]
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


# ============================================
# USER PROFILE FUNCTIONS
# ============================================

const USERS_COLLECTION = "users"

func save_user_profile(user_id: String, profile_data: Dictionary):
	"""Save user profile data to Firestore."""
	if user_id.is_empty():
		print("[Firestore] Cannot save: No user ID")
		return
	
	var id_token = FirebaseAuth.id_token
	if id_token.is_empty():
		print("[Firestore] Cannot save: Not authenticated")
		return
	
	var url = BASE_URL + "/" + USERS_COLLECTION + "/" + user_id
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + id_token]
	
	var doc = {
		"fields": {
			"display_name": {"stringValue": profile_data.get("display_name", "")},
			"email": {"stringValue": profile_data.get("email", "")},
			"photo_url": {"stringValue": profile_data.get("photo_url", "")},
			"provider": {"stringValue": profile_data.get("provider", "anonymous")},
			"is_linked": {"booleanValue": profile_data.get("is_linked", false)},
			"last_login": {"stringValue": str(Time.get_unix_time_from_system())}
		}
	}
	
	var body = JSON.stringify(doc)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_save_profile_response.bind(http))
	http.request(url, headers, HTTPClient.METHOD_PATCH, body)

func _on_save_profile_response(_result, response_code, _headers, body, http):
	if response_code == 200 or response_code == 201:
		print("[Firestore] User profile saved successfully")
	else:
		print("[Firestore] Profile save failed: ", response_code, " - ", body.get_string_from_utf8())
	http.queue_free()

func load_user_profile(user_id: String):
	"""Load user profile data from Firestore."""
	if user_id.is_empty():
		print("[Firestore] Cannot load: No user ID")
		return
	
	var id_token = FirebaseAuth.id_token
	if id_token.is_empty():
		print("[Firestore] Cannot load: Not authenticated")
		return
	
	var url = BASE_URL + "/" + USERS_COLLECTION + "/" + user_id
	var headers = ["Authorization: Bearer " + id_token]
	
	print("[Firestore] Loading profile from: ", url)
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_load_profile_response.bind(http))
	http.request(url, headers, HTTPClient.METHOD_GET)

func _on_load_profile_response(_result, response_code, _headers, body, http):
	print("[Firestore] Load profile response: ", response_code)
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("fields"):
			var profile = _convert_from_firestore(json["fields"])
			print("[Firestore] Profile loaded successfully")
			# Update UserManager with loaded data
			UserManager.update_user_data(profile)
		else:
			print("[Firestore] No profile data found")
	elif response_code == 404:
		print("[Firestore] Profile not found (new user)")
	else:
		print("[Firestore] Profile load failed: ", response_code)
	http.queue_free()
