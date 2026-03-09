## UserManager - Manages user authentication state and profile data
extends Node

# User data structure
var user_data: Dictionary = {
	"user_id": "",
	"display_name": "Guest",
	"email": "",
	"photo_url": "",
	"provider": "anonymous",  # "anonymous" | "google"
	"is_linked": false,
	"anonymous_uid": ""  # Store original anonymous UID for account linking
}

# Signals
signal user_data_changed(data: Dictionary)
signal profile_picture_loaded(texture: Texture2D)

# Cached profile texture
var _profile_texture: Texture2D = null

func _ready():
	# Load saved user data from local storage
	_load_user_data()

func get_user_data() -> Dictionary:
	return user_data.duplicate()

func is_logged_in() -> bool:
	return not user_data.user_id.is_empty()

func is_google_linked() -> bool:
	return user_data.provider == "google" and user_data.is_linked

func update_user_data(new_data: Dictionary) -> void:
	user_data.merge(new_data, true)
	_save_user_data()
	emit_signal("user_data_changed", user_data.duplicate())

func clear_user_data() -> void:
	user_data = {
		"user_id": "",
		"display_name": "Guest",
		"email": "",
		"photo_url": "",
		"provider": "anonymous",
		"is_linked": false,
		"anonymous_uid": ""
	}
	_profile_texture = null
	_save_user_data()
	emit_signal("user_data_changed", user_data.duplicate())

# Profile picture loading
func load_profile_picture(url: String) -> void:
	if url.is_empty():
		emit_signal("profile_picture_loaded", null)
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_profile_image_downloaded.bind(http))
	http.request(url)

func _on_profile_image_downloaded(result, response_code, _headers, body, http):
	if result == OK and response_code == 200:
		var image = Image.new()
		var image_error = image.load_jpg_from_buffer(body)
		if image_error != OK:
			image_error = image.load_png_from_buffer(body)
		
		if image_error == OK:
			var texture = ImageTexture.create_from_image(image)
			_profile_texture = texture
			emit_signal("profile_picture_loaded", texture)
	
	http.queue_free()

func get_cached_profile_texture() -> Texture2D:
	return _profile_texture

# Local persistence
func _save_user_data() -> void:
	var file = FileAccess.open("user://user_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(user_data))
		file.close()

func _load_user_data() -> void:
	if FileAccess.file_exists("user://user_data.json"):
		var file = FileAccess.open("user://user_data.json", FileAccess.READ)
		if file:
			var json = JSON.new()
			var error = json.parse(file.get_as_text())
			if error == OK:
				var loaded = json.get_data()
				if loaded is Dictionary:
					user_data.merge(loaded, true)
			file.close()
