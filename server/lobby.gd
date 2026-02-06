extends Control

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var poll_timer: Timer = $PollTimer
@onready var invite_code_label: Label = $InviteCodeLabel
@onready var partner_status_label: Label = $PartnerStatusLabel
@onready var start_button: Button = $StartButton
@onready var waiting_label: Label = $WaitingLabel

var world_id: String
var auth_token: String
var partner_joined: bool = false

const SERVER_URL = "http://localhost:10000"

func _ready():
	start_button.disabled = true
	start_button.hide()
	waiting_label.show()
	
	poll_timer.wait_time = 1.0
	poll_timer.timeout.connect(_on_poll_timer_timeout)
	poll_timer.start()
	
	http_request.request_completed.connect(_on_http_request_completed)

func setup(created_world_id: String, invite_code: String, token: String):
	world_id = created_world_id
	auth_token = token
	invite_code_label.text = "Invite Code: " + invite_code
	partner_status_label.text = "Waiting for partner..."

func _on_poll_timer_timeout():
	if partner_joined:
		return
	
	var headers = ["Authorization: Bearer " + auth_token]
	var url = SERVER_URL + "/worlds/" + world_id
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("Failed to send poll request: ", error)

func _on_http_request_completed(result, response_code, headers, body):
	if response_code != 200:
		print("Poll failed with code: ", response_code)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		print("Failed to parse response")
		return
	
	var data = json.get_data()
	print("Poll result: ", data)
	
	# Check if sidekick joined
	var partner_id = data.get("partner_id")
	var partner_name = data.get("partner_name", "")
	
	if partner_id != null and partner_id != "":
		_on_partner_joined(partner_name)
	else:
		partner_status_label.text = "Waiting for partner..."

func _on_partner_joined(partner_name: String):
	partner_joined = true
	print("Partner joined: ", partner_name)
	
	# Update UI
	var display_name = partner_name if partner_name != "" else "Player 2"
	partner_status_label.text = "Partner: " + display_name + " ✓"
	partner_status_label.modulate = Color(0, 1, 0)  # Green
	
	waiting_label.hide()
	start_button.show()
	start_button.disabled = false

func _on_start_button_pressed():
	print("Starting game...")
	
	var headers = ["Authorization: Bearer " + auth_token, "Content-Type: application/json"]
	var url = SERVER_URL + "/worlds/" + world_id + "/start"
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, "{}")
	if error != OK:
		print("Failed to send start request: ", error)
		return
	
	# Wait for response in a temporary callback
	var temp_callback = func(result, response_code, headers, body):
		if response_code == 200:
			var json = JSON.new()
			json.parse(body.get_string_from_utf8())
			var data = json.get_data()
			print("Game started! Session: ", data.get("session_id"))
			print("WebSocket URL: ", data.get("ws_url"))
			
			# Transition to game scene
			# get_tree().change_scene_to_file("res://game_scene.tscn")
			
		elif response_code == 400:
			var json = JSON.new()
			json.parse(body.get_string_from_utf8())
			var data = json.get_data()
			print("Cannot start: ", data.get("message"))
		else:
			print("Start failed with code: ", response_code)
	
	http_request.request_completed.disconnect(_on_http_request_completed)
	http_request.request_completed.connect(temp_callback, CONNECT_ONE_SHOT)
	http_request.request_completed.connect(_on_http_request_completed)
