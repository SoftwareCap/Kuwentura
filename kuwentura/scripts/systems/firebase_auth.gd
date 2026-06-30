extends Node

# Firebase project settings — see https://console.firebase.google.com → Project Settings
const API_KEY := FirebaseConfig.API_KEY
const PROJECT_ID := FirebaseConfig.PROJECT_ID
const OFFLINE_MODE := false

const AUTH_BASE_URL := "https://identitytoolkit.googleapis.com/v1/accounts:"

signal auth_success(user_id: String, token: String)
signal auth_failed(error: String)

var current_user_id: String = ""
var id_token: String = ""
var is_authenticated: bool = false


func _ready() -> void:
	if not _is_configured():
		return


func anonymous_login() -> void:
	if not _is_configured():
		auth_failed.emit("Firebase not configured - running in offline mode")
		return
	if OFFLINE_MODE:
		auth_failed.emit("Offline mode")
		return

	var url := AUTH_BASE_URL + "signUp?key=" + API_KEY
	var headers := ["Content-Type: application/json"]
	var body := JSON.stringify({"returnSecureToken": true})

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_anon_login_response.bind(http))

	var error := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		auth_failed.emit("HTTP request failed: " + str(error))


func _on_anon_login_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if response_code == 200:
		var json: Variant = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("localId") and json.has("idToken"):
			current_user_id = json["localId"]
			id_token = json["idToken"]
			is_authenticated = true
			auth_success.emit(current_user_id, id_token)
		else:
			auth_failed.emit("Invalid response format")
	else:
		auth_failed.emit(body.get_string_from_utf8())
	http.queue_free()


func get_id_token() -> String:
	return id_token if is_authenticated else ""


func _is_configured() -> bool:
	return not (API_KEY == "YOUR_API_KEY_HERE" or API_KEY.is_empty())
