## Main Menu Controller
## Example integration showing how to use the LAN NetworkManager
## Attach this to your main menu scene root node

extends Control

#------------------------------------------------------------------------------
# Exported UI References (assign in inspector)
#------------------------------------------------------------------------------

@export_group("Main Menu Buttons")
@export var host_button: Button
@export var join_button: Button
@export var discover_button: Button
@export var settings_button: Button
@export var quit_button: Button

@export_group("Host UI")
@export var host_panel: Control
@export var room_code_label: Label
@export var start_game_button: Button
@export var cancel_host_button: Button
@export var waiting_label: Label

@export_group("Join UI")
@export var join_panel: Control
@export var code_input: LineEdit
@export var connect_button: Button
@export var cancel_join_button: Button
@export var discover_panel: Control

@export_group("Status UI")
@export var status_label: Label
@export var loading_spinner: Control

#------------------------------------------------------------------------------
# Private State
#------------------------------------------------------------------------------

var _lan_discovery: Node = null

#------------------------------------------------------------------------------
# Godot Lifecycle
#------------------------------------------------------------------------------

func _ready():
	# Connect to NetworkManager signals
	NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
	NetworkManager.connection_established.connect(_on_connection_established)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.partner_connected.connect(_on_partner_connected)
	NetworkManager.partner_disconnected.connect(_on_partner_disconnected)
	NetworkManager.game_started.connect(_on_game_started)
	
	# Connect button signals
	_connect_buttons()
	
	# Hide panels initially
	_hide_all_panels()
	
	# Check for existing connection
	_update_ui_for_state()


func _exit_tree():
	# Clean up if needed
	if _lan_discovery:
		_lan_discovery.queue_free()

#------------------------------------------------------------------------------
# Button Connections
#------------------------------------------------------------------------------

func _connect_buttons():
	if host_button:
		host_button.pressed.connect(_on_host_pressed)
	
	if join_button:
		join_button.pressed.connect(_on_join_pressed)
	
	if discover_button:
		discover_button.pressed.connect(_on_discover_pressed)
	
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	# Host panel buttons
	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
		start_game_button.disabled = true  # Disabled until partner connects
	
	if cancel_host_button:
		cancel_host_button.pressed.connect(_on_cancel_host_pressed)
	
	# Join panel buttons
	if connect_button:
		connect_button.pressed.connect(_on_connect_pressed)
	
	if cancel_join_button:
		cancel_join_button.pressed.connect(_on_cancel_join_pressed)

#------------------------------------------------------------------------------
# Button Handlers - Main Menu
#------------------------------------------------------------------------------

func _on_host_pressed():
	_show_host_panel()
	
	# Start hosting
	var result = await NetworkManager.host_game()
	
	if result.success:
		_show_room_code(result.invite_code)
		_update_status("Waiting for Sidekick to join...")
	else:
		_show_error("Failed to host: " + result.get("error", "Unknown error"))
		_hide_all_panels()


func _on_join_pressed():
	_show_join_panel()


func _on_discover_pressed():
	_show_discover_panel()
	
	# Initialize LAN discovery if not already
	if not _lan_discovery:
		_lan_discovery = preload("res://scripts/mainMenu/lan_discovery.gd").new()
		_lan_discovery.host_selected.connect(_on_discovered_host_selected)
		add_child(_lan_discovery)
	
	# Configure discovery UI
	_lan_discovery.host_list_container = discover_panel.get_node("HostListContainer").get_path() if discover_panel.has_node("HostListContainer") else ""
	_lan_discovery.refresh_button = discover_panel.get_node("RefreshButton").get_path() if discover_panel.has_node("RefreshButton") else ""
	_lan_discovery.status_label = discover_panel.get_node("StatusLabel").get_path() if discover_panel.has_node("StatusLabel") else ""
	
	# Start discovery
	_lan_discovery.start_discovery()


func _on_settings_pressed():
	# TODO: Open settings menu
	print("Settings not implemented yet")


func _on_quit_pressed():
	get_tree().quit()

#------------------------------------------------------------------------------
# Button Handlers - Host Panel
#------------------------------------------------------------------------------

func _on_start_game_pressed():
	if NetworkManager.is_host():
		NetworkManager.start_game()
		# Game started signal will handle scene transition


func _on_cancel_host_pressed():
	NetworkManager.disconnect_network()
	_hide_all_panels()


func _on_room_code_copy_pressed():
	# Copy room code to clipboard
	if room_code_label:
		DisplayServer.clipboard_set(room_code_label.text)
		_update_status("Room code copied to clipboard!")

#------------------------------------------------------------------------------
# Button Handlers - Join Panel
#------------------------------------------------------------------------------

func _on_connect_pressed():
	if not code_input:
		return
	
	var code = code_input.text.strip_edges().to_upper()
	if code.is_empty():
		_show_error("Please enter a room code")
		return
	
	_update_status("Connecting...")
	_show_loading(true)
	
	var result = await NetworkManager.join_game_with_code(code)
	
	_show_loading(false)
	
	if not result.success:
		_show_error("Failed to join: " + result.get("error", "Unknown error"))


func _on_cancel_join_pressed():
	NetworkManager.disconnect_network()
	_hide_all_panels()


func _on_discovered_host_selected(host_info: Dictionary):
	# Auto-fill the code input with the discovered host info
	if code_input:
		code_input.text = host_info.get("invite_code", "")
	
	# Switch to join panel
	_hide_all_panels()
	_show_join_panel()
	
	# Optionally auto-connect
	_update_status("Found host: " + host_info.get("host_name", "Unknown"))

#------------------------------------------------------------------------------
# Signal Handlers - Network
#------------------------------------------------------------------------------

func _on_connection_state_changed(new_state: int, old_state: int):
	print("[MainMenu] State changed: ", old_state, " -> ", new_state)
	_update_ui_for_state()


func _on_connection_established(peer_id: int):
	_update_status("Connected! Peer ID: " + str(peer_id))


func _on_connection_failed(error: String):
	_show_error("Connection failed: " + error)
	_show_loading(false)


func _on_partner_connected(player_data: Dictionary):
	_update_status("Sidekick joined! Ready to start.")
	
	# Enable start game button for host
	if start_game_button and NetworkManager.is_host():
		start_game_button.disabled = false
	
	# Update waiting label
	if waiting_label:
		waiting_label.text = "Sidekick connected! Waiting to start..."


func _on_partner_disconnected(player_data: Dictionary):
	_update_status("Partner disconnected!")
	
	# Disable start game button
	if start_game_button:
		start_game_button.disabled = true
	
	# Update waiting label
	if waiting_label:
		waiting_label.text = "Waiting for Sidekick to join..."


func _on_game_started(checkpoint: String):
	_update_status("Game starting!")
	
	# Transition to game scene
	# Replace with your actual game scene path
	var game_scene_path = "res://scenes/world/zones/forest_hub.tscn"
	get_tree().change_scene_to_file(game_scene_path)

#------------------------------------------------------------------------------
# UI Helpers
#------------------------------------------------------------------------------

func _hide_all_panels():
	if host_panel:
		host_panel.hide()
	if join_panel:
		join_panel.hide()
	if discover_panel:
		discover_panel.hide()


func _show_host_panel():
	_hide_all_panels()
	if host_panel:
		host_panel.show()


func _show_join_panel():
	_hide_all_panels()
	if join_panel:
		join_panel.show()


func _show_discover_panel():
	_hide_all_panels()
	if discover_panel:
		discover_panel.show()


func _show_room_code(code: String):
	if room_code_label:
		room_code_label.text = code


func _show_loading(show: bool):
	if loading_spinner:
		loading_spinner.visible = show


func _show_error(message: String):
	_update_status("Error: " + message)
	push_warning("[MainMenu] " + message)
	
	# Could also show a popup dialog here
	# For now, just show in status label


func _update_status(message: String):
	if status_label:
		status_label.text = message
	print("[MainMenu] " + message)


func _update_ui_for_state():
	var state = NetworkManager.get_state()
	
	match state:
		NetworkManager.ConnectionState.DISCONNECTED:
			_show_loading(false)
			
		NetworkManager.ConnectionState.CONNECTING:
			_show_loading(true)
			_update_status("Connecting...")
			
		NetworkManager.ConnectionState.HOSTING:
			_show_loading(false)
			
		NetworkManager.ConnectionState.PLAYING:
			_show_loading(false)
			_update_status("Playing!")

#------------------------------------------------------------------------------
# Debug/Test Functions
#------------------------------------------------------------------------------

## Quick test: Host and start game immediately (single-player test mode)
func _debug_quick_host():
	var result = await NetworkManager.host_game()
	if result.success:
		await get_tree().create_timer(0.5).timeout
		NetworkManager.start_game()


## Quick test: Join localhost (for testing on same machine)
func _debug_quick_join():
	await NetworkManager.join_game_with_code("127.0.0.1")
