extends Node

const API_KEY: String = "AIzaSyBbfAbGualst8-7qpa7CwefDk-j2Xe1aHU"
const PROJECT_ID: String = "kuwentura"
const AUTH_DOMAIN: String = "https://identitytoolkit.googleapis.com/v1"
const FIRESTORE_URL: String = (
	"https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID
)

var auth_token: String = ""
var user_id: String = ""
var is_authenticated: bool = false

signal auth_success(user_id: String)
signal auth_failed(error: String)
signal save_success
signal save_failed(error: String)
signal load_success(data: Dictionary)
signal load_failed(error: String)


func _ready():
	# Connect to auth signals
	FirebaseAuth.auth_success.connect(_on_auth_success)
	FirebaseAuth.auth_failed.connect(_on_auth_failed)

	# Attempt anonymous login on startup
	FirebaseAuth.anonymous_login()


func _on_auth_success(new_user_id: String, token: String):
	user_id = new_user_id
	auth_token = token
	is_authenticated = true
	print("Firebase Manager: Auth success for ", user_id)
	emit_signal("auth_success", user_id)

	# Try to load existing save
	load_progress()


func _on_auth_failed(error: String):
	is_authenticated = false
	print("Firebase Manager: Auth failed - ", error)
	emit_signal("auth_failed", error)


func save_progress():
	if not is_authenticated or user_id.is_empty():
		print("Cannot save: Not authenticated")
		emit_signal("save_failed", "Not authenticated")
		return

	print("Saving progress for user: ", user_id)

	# Get fresh data from GameState
	var game_data = GameState.get_save_data()

	# Use Firestore to save
	FirebaseFirestore.save_game_state(user_id, game_data)


func load_progress():
	if not is_authenticated or user_id.is_empty():
		print("Cannot load: Not authenticated")
		emit_signal("load_failed", "Not authenticated")
		return

	print("Loading progress for user: ", user_id)
	FirebaseFirestore.load_game_state()


# Called by Firestore when save completes successfully
func _on_firestore_save_success():
	print("Save completed successfully")
	emit_signal("save_success")


# Called by Firestore when save fails
func _on_firestore_save_failed(error: String):
	print("Save failed: ", error)
	emit_signal("save_failed", error)


# Called by Firestore when load completes
func _on_firestore_load_success(data: Dictionary):
	print("Load completed successfully")
	if data.size() > 0:
		GameState.load_save_data(data)
	emit_signal("load_success", data)


func _on_firestore_load_failed(error: String):
	print("Load failed: ", error)
	emit_signal("load_failed", error)
