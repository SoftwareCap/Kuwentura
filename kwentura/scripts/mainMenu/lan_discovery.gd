## LAN Discovery UI Controller
## Attach this to a Control node in your lobby/join game scene
## Handles finding and displaying available hosts on the local network

extends Control

#------------------------------------------------------------------------------
# Signals
#------------------------------------------------------------------------------

signal host_selected(host_info: Dictionary)
signal refresh_started
signal refresh_stopped

#------------------------------------------------------------------------------
# Exported Properties
#------------------------------------------------------------------------------

@export var host_button_scene: PackedScene  # Button scene for each host
@export var host_list_container: NodePath   # Container for host buttons
@export var refresh_button: NodePath        # Button to trigger refresh
@export var status_label: NodePath          # Label for status messages
@export var discovery_duration: float = 3.0  # How long to search for hosts

#------------------------------------------------------------------------------
# Private State
#------------------------------------------------------------------------------

var _discovered_hosts: Dictionary = {}
var _is_refreshing: bool = false

#------------------------------------------------------------------------------
# Godot Lifecycle
#------------------------------------------------------------------------------

func _ready():
	# Connect NetworkManager signals
	NetworkManager.host_discovered.connect(_on_host_discovered)
	NetworkManager.discovery_started.connect(_on_discovery_started)
	NetworkManager.discovery_stopped.connect(_on_discovery_stopped)
	
	# Connect UI signals
	if refresh_button:
		var btn = get_node(refresh_button)
		if btn:
			btn.pressed.connect(start_discovery)


func _exit_tree():
	stop_discovery()

#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

## Start searching for hosts on the local network
func start_discovery():
	if _is_refreshing:
		return
	
	# Clear previous results
	_clear_host_list()
	_discovered_hosts.clear()
	
	# Start discovery
	NetworkManager.start_discovery()
	
	# Auto-stop after duration
	await get_tree().create_timer(discovery_duration).timeout
	stop_discovery()


## Stop the discovery process
func stop_discovery():
	NetworkManager.stop_discovery()


## Check if currently discovering
func is_refreshing() -> bool:
	return _is_refreshing


## Get list of discovered hosts
func get_discovered_hosts() -> Array:
	return _discovered_hosts.values()

#------------------------------------------------------------------------------
# Signal Handlers
#------------------------------------------------------------------------------

func _on_host_discovered(host_info: Dictionary):
	var host_id = host_info.ip + ":" + str(host_info.port)
	
	# Check if we already have this host
	if _discovered_hosts.has(host_id):
		# Update existing host info
		_discovered_hosts[host_id] = host_info
		_update_host_button(host_id, host_info)
	else:
		# Add new host
		_discovered_hosts[host_id] = host_info
		_create_host_button(host_id, host_info)
	
	_update_status("Found " + str(_discovered_hosts.size()) + " host(s)")


func _on_discovery_started():
	_is_refreshing = true
	emit_signal("refresh_started")
	_update_status("Searching for games...")
	
	# Disable refresh button
	if refresh_button:
		var btn = get_node(refresh_button)
		if btn:
			btn.disabled = true
			btn.text = "Searching..."


func _on_discovery_stopped():
	_is_refreshing = false
	emit_signal("refresh_stopped")
	
	if _discovered_hosts.is_empty():
		_update_status("No games found. Make sure you're on the same Wi-Fi.")
	
	# Re-enable refresh button
	if refresh_button:
		var btn = get_node(refresh_button)
		if btn:
			btn.disabled = false
			btn.text = "Refresh"

#------------------------------------------------------------------------------
# UI Helpers
#------------------------------------------------------------------------------

func _create_host_button(host_id: String, host_info: Dictionary):
	if not host_list_container:
		return
	
	var container = get_node(host_list_container)
	if not container:
		return
	
	# Create button for this host
	var btn: Button
	if host_button_scene:
		btn = host_button_scene.instantiate()
	else:
		btn = Button.new()
	
	btn.name = "Host_" + host_id.replace(":", "_")
	_update_button_text(btn, host_info)
	
	# Connect pressed signal
	btn.pressed.connect(_on_host_button_pressed.bind(host_id))
	
	container.add_child(btn)


func _update_host_button(host_id: String, host_info: Dictionary):
	if not host_list_container:
		return
	
	var container = get_node(host_list_container)
	if not container:
		return
	
	var btn_name = "Host_" + host_id.replace(":", "_")
	var btn = container.get_node_or_null(btn_name)
	
	if btn:
		_update_button_text(btn, host_info)


func _update_button_text(btn: Button, host_info: Dictionary):
	var host_name = host_info.get("host_name", "Unknown Host")
	var code = host_info.get("invite_code", "")
	
	if code.is_empty():
		btn.text = host_name
	else:
		btn.text = host_name + " [" + code + "]"
	
	# Store host info in button metadata
	btn.set_meta("host_info", host_info)


func _clear_host_list():
	if not host_list_container:
		return
	
	var container = get_node(host_list_container)
	if not container:
		return
	
	# Remove all host buttons
	for child in container.get_children():
		if child.name.begins_with("Host_"):
			child.queue_free()


func _on_host_button_pressed(host_id: String):
	var host_info = _discovered_hosts.get(host_id)
	if host_info:
		emit_signal("host_selected", host_info)


func _update_status(message: String):
	if status_label:
		var label = get_node(status_label)
		if label:
			label.text = message
	print("[LAN Discovery] ", message)
