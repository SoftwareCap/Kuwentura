extends Node

# ============================================================================
# FIREBASE CONFIGURATION - UPDATE THESE WITH YOUR ACTUAL VALUES
# ============================================================================
# To get your API Key:
# 1. Go to https://console.firebase.google.com
# 2. Select your project (or create one)
# 3. Go to Project Settings → General → Web API Key
# 4. Copy the API Key and paste it below
const API_KEY = "AIzaSyBbfAbGualst8-7qpa7CwefDk-j2Xe1aHU"

const PROJECT_ID = "kuwentura"

# Set to true to disable Firebase (game will work without internet)
const OFFLINE_MODE = false

var current_user_id = ""
var id_token = ""
var is_authenticated = false

signal auth_success(user_id: String, token: String)
signal auth_failed(error: String)


func _ready():
	# Check if API key is configured
	if API_KEY == "YOUR_API_KEY_HERE" or API_KEY.is_empty():
		print("[FirebaseAuth] API Key not configured - running in offline mode")
		# Silently fail - game works without Firebase
		return


func anonymous_login():
	# Skip if API key not configured
	if API_KEY == "YOUR_API_KEY_HERE" or API_KEY.is_empty():
		print("[FirebaseAuth] Skipping auth - no API key configured")
		emit_signal("auth_failed", "Firebase not configured - running in offline mode")
		return
	
	if OFFLINE_MODE:
		print("[FirebaseAuth] Offline mode enabled - skipping auth")
		emit_signal("auth_failed", "Offline mode")
		return
	
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
