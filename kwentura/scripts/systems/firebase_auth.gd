extends Node

const API_KEY = "AIzaSyDvqAXKBbK8F4e6c_jg6_vBQ16bvqevhT0"
const PROJECT_ID = "kwentura-89df4"

var current_user_id = ""
var id_token = ""
var is_authenticated = false

signal auth_success(user_id: String, token: String)  # Added token to signal
signal auth_failed(error: String)

func anonymous_login():
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + API_KEY
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"returnSecureToken": true})
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_anon_login_response.bind(http))
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		emit_signal("auth_failed", "HTTP request failed: " + str(error))

func _on_anon_login_response(_result, response_code, _headers, body, http):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("localId") and json.has("idToken"):
			current_user_id = json["localId"]
			id_token = json["idToken"]  # ✅ Store the ID token
			is_authenticated = true
			print("Firebase anonymous login success: ", current_user_id)
			emit_signal("auth_success", current_user_id, id_token)  # ✅ Pass token
		else:
			emit_signal("auth_failed", "Invalid response format")
	else:
		print("Auth failed: ", body.get_string_from_utf8())
		emit_signal("auth_failed", body.get_string_from_utf8())
	
	http.queue_free()

func get_id_token() -> String:
	return id_token if is_authenticated else ""
