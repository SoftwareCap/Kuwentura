extends Node

const API_KEY = "AIzaSyBbfAbGualst8-7qpa7CwefDk-j2Xe1aHU"
const PROJECT_ID = "kuwentura"

var current_user_id = ""
var id_token = ""
var is_authenticated = false

# Android plugin reference
var _android_plugin = null

signal auth_success(user_id: String, token: String)  # Added token to signal
signal auth_failed(error: String)
signal google_auth_success(user_data: Dictionary)
signal google_auth_failed(error: String)
signal account_linked_success(user_data: Dictionary)
signal account_link_failed(error: String)

func _ready():
	# Initialize Android plugin if available
	if Engine.has_singleton("KwenturaAuth"):
		_android_plugin = Engine.get_singleton("KwenturaAuth")
		_android_plugin.connect("google_sign_in_success", _on_android_google_sign_in_success)
		_android_plugin.connect("google_sign_in_failed", _on_android_google_sign_in_failed)
		_android_plugin.connect("account_link_success", _on_android_account_link_success)
		_android_plugin.connect("account_link_failed", _on_android_account_link_failed)
		print("[FirebaseAuth] Android plugin loaded successfully")

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


func sign_in_with_google():
	"""Initiate Google Sign-In flow."""
	if _android_plugin:
		# Use native Android plugin
		_android_plugin.signInWithGoogle()
	else:
		# Fallback for non-Android platforms or when plugin is not available
		_emit_google_auth_failed("Google Sign-In plugin not available")

func link_with_google():
	"""Link anonymous account with Google."""
	if not is_authenticated:
		_emit_account_link_failed("Not authenticated anonymously")
		return
	
	if _android_plugin:
		# Store current anonymous UID for potential migration
		UserManager.update_user_data({"anonymous_uid": current_user_id})
		_android_plugin.linkWithGoogle()
	else:
		_emit_account_link_failed("Google Sign-In plugin not available")

func sign_out_google():
	"""Sign out from Google account."""
	if _android_plugin:
		_android_plugin.signOut()
	# Clear local auth state
	current_user_id = ""
	id_token = ""
	is_authenticated = false
	UserManager.clear_user_data()


func _on_android_google_sign_in_success(json_data: String):
	"""Called when Google Sign-In succeeds on Android."""
	var json = JSON.new()
	var error = json.parse(json_data)
	if error == OK:
		var data = json.get_data()
		if data is Dictionary:
			# Update Firebase Auth state
			current_user_id = data.get("user_id", "")
			id_token = data.get("id_token", "")
			is_authenticated = true
			
			# Build user data for UserManager
			var user_data = {
				"user_id": current_user_id,
				"display_name": data.get("display_name", "Google User"),
				"email": data.get("email", ""),
				"photo_url": data.get("photo_url", ""),
				"provider": "google",
				"is_linked": false
			}
			
			print("[FirebaseAuth] Google sign-in success for user: ", current_user_id)
			emit_signal("google_auth_success", user_data)
			return
	
	_emit_google_auth_failed("Invalid response from Google Sign-In")

func _on_android_google_sign_in_failed(error_message: String):
	"""Called when Google Sign-In fails on Android."""
	print("[FirebaseAuth] Google sign-in failed: ", error_message)
	emit_signal("google_auth_failed", error_message)

func _on_android_account_link_success(json_data: String):
	"""Called when account linking succeeds on Android."""
	var json = JSON.new()
	var error = json.parse(json_data)
	if error == OK:
		var data = json.get_data()
		if data is Dictionary:
			# Update Firebase Auth state
			current_user_id = data.get("user_id", "")
			id_token = data.get("id_token", "")
			is_authenticated = true
			
			# Build user data for UserManager
			var user_data = {
				"user_id": current_user_id,
				"display_name": data.get("display_name", "Google User"),
				"email": data.get("email", ""),
				"photo_url": data.get("photo_url", ""),
				"provider": "google",
				"is_linked": true
			}
			
			print("[FirebaseAuth] Account linked successfully for user: ", current_user_id)
			emit_signal("account_linked_success", user_data)
			return
	
	_emit_account_link_failed("Invalid response from account linking")

func _on_android_account_link_failed(error_message: String):
	"""Called when account linking fails on Android."""
	print("[FirebaseAuth] Account link failed: ", error_message)
	emit_signal("account_link_failed", error_message)


func _emit_google_auth_failed(error: String):
	emit_signal("google_auth_failed", error)

func _emit_account_link_failed(error: String):
	emit_signal("account_link_failed", error)
