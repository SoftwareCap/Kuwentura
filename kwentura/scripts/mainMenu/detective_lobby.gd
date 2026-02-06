extends Control

@onready var start_button = $Button
@onready var back_button = $Button2
@onready var room_code_label = $RoomCode
@onready var status_label = $StatusLabel
@onready var sidekick_label = $SidekickLabel

@onready var detective_sprite = $PlayerHost/AnimatedSprite2D
@onready var sidekick_sprite = $PlayerSidekick/AnimatedSprite2D

var sidekick_connected: bool = false
var _world_ready: bool = false

func _ready():
	if detective_sprite:
		detective_sprite.play("idle")
	if sidekick_sprite:
		sidekick_sprite.play("idle")
	
	# Determine role and setup UI accordingly
	if NetworkManager.get_my_role() == "detective":
		_setup_host_view()
	else:
		_setup_sidekick_view()
	
	# Connect signals
	NetworkManager.room_code_generated.connect(_on_room_code_generated)
	NetworkManager.partner_connected.connect(_on_partner_connected)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	
	# Check if partner already connected (for sidekick joining)
	if NetworkManager.get_my_role() == "sidekick":
		var partner = NetworkManager.get_partner_status()
		if partner.connected:
			status_label.text = "Connected to " + partner.display_name + "! Waiting for start..."

func _setup_host_view():
	# Host (Detective) setup
	start_button.visible = false
	start_button.disabled = true
	
	# Get invite code from NetworkManager (set when creating world)
	var invite_code = NetworkManager.get_invite_code()
	if not invite_code.is_empty():
		_show_room_code(invite_code)
	else:
		room_code_label.text = "Code: ???"
	
	# Sidekick sprite hidden initially
	if sidekick_sprite:
		sidekick_sprite.visible = false
	sidekick_label.visible = false
	
	# Poll for sidekick to join
	status_label.text = "Waiting for Sidekick..."
	_poll_for_sidekick()

func _setup_sidekick_view():
	# Sidekick setup
	start_button.visible = false  # Sidekick can't start game
	room_code_label.visible = false  # Sidekick doesn't see code
	
	if sidekick_sprite:
		sidekick_sprite.visible = true
	
	if detective_sprite:
		detective_sprite.visible = true
	
	status_label.text = "Connected! Waiting for detective to start..."

func _poll_for_sidekick():
	"""Poll world status until sidekick joins"""
	while not sidekick_connected:
		await get_tree().create_timer(1.0).timeout
		
		var status = await NetworkManager.get_world_status()
		print("Lobby - World status: ", status)
		
		if status.has("error"):
			continue
		
		# Check if sidekick joined (partner_id will be non-null)
		# According to API schema: partner_id is "string | null"
		if status.get("partner_id") != null and not status.get("partner_id", "").is_empty():
			print("Sidekick joined! partner_id: ", status.get("partner_id"))
			sidekick_connected = true
			_world_ready = true
			_on_partner_connected({})
			return

func _show_room_code(code: String):
	room_code_label.text = "Code: " + code
	room_code_label.modulate = Color(1, 0.9, 0.2)  # Gold

func _on_room_code_generated(code: String):
	if NetworkManager.get_my_role() == "detective":
		_show_room_code(code)

func _on_partner_connected(_data: Dictionary):
	sidekick_connected = true
	
	if NetworkManager.get_my_role() == "detective":
		# Host sees sidekick joined
		status_label.text = "Sidekick Connected! Click START when ready!"
		status_label.modulate = Color(0, 1, 0)
		
		# Show start button
		start_button.visible = true
		start_button.disabled = false
		
		# Show sidekick sprite with fade in
		if sidekick_sprite:
			sidekick_sprite.visible = true
			sidekick_sprite.modulate = Color(1, 1, 1, 0)
			var tween = create_tween()
			tween.tween_property(sidekick_sprite, "modulate", Color(1, 1, 1, 1), 0.5)
	else:
		# Sidekick sees they're connected
		status_label.text = "Connected! Waiting for host to start..."
		status_label.modulate = Color(0, 1, 0)

func _on_start_pressed() -> void:
	if NetworkManager.get_my_role() != "detective":
		return  # Only host can start
	
	if not sidekick_connected:
		print("Waiting for sidekick to connect...")
		return
	
	print("Starting game session...")
	start_button.disabled = true
	status_label.text = "Starting game..."
	
	# Start the session
	var result = await NetworkManager.start_game_session()
	if result.has("error"):
		status_label.text = "Failed to start: " + result.get("error", "Unknown error")
		start_button.disabled = false
	else:
		status_label.text = "Game starting!"

func _on_back_pressed() -> void:
	NetworkManager.disconnect_network()
	get_tree().change_scene_to_file("res://scenes/mainMenu/main_menu.tscn")

func _on_game_started():
	# Both players fade out and go to game
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 1.0)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/cutscenes/OpeningCutscene.tscn")

func _on_connection_failed(error: String):
	status_label.text = "Connection failed: " + error
	status_label.modulate = Color(1, 0, 0)
