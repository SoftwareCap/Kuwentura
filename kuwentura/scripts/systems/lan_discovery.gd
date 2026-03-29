extends Control

## LAN Discovery UI Controller
## Handles finding and displaying available hosts on the local network.

signal host_selected(host_info: Dictionary)
signal refresh_started
signal refresh_stopped

@export var host_button_scene: PackedScene
@export var host_list_container: NodePath
@export var refresh_button: NodePath
@export var status_label: NodePath
@export var discovery_duration: float = 3.0

var _discovered_hosts: Dictionary = {}
var _is_refreshing: bool = false


func _ready() -> void:
	NetworkManager.host_discovered.connect(_on_host_discovered)
	NetworkManager.discovery_started.connect(_on_discovery_started)
	NetworkManager.discovery_stopped.connect(_on_discovery_stopped)
	var btn := _get_refresh_btn()
	if btn:
		btn.pressed.connect(start_discovery)


func _exit_tree() -> void:
	stop_discovery()


func start_discovery() -> void:
	if _is_refreshing:
		return
	_clear_host_list()
	_discovered_hosts.clear()
	NetworkManager.start_discovery()
	await get_tree().create_timer(discovery_duration).timeout
	stop_discovery()


func stop_discovery() -> void:
	NetworkManager.stop_discovery()


func is_refreshing() -> bool:
	return _is_refreshing


func get_discovered_hosts() -> Array:
	return _discovered_hosts.values()


func _on_host_discovered(host_info: Dictionary) -> void:
	var host_id: String = host_info.ip + ":" + str(host_info.port)
	if _discovered_hosts.has(host_id):
		_discovered_hosts[host_id] = host_info
		_update_host_button(host_id, host_info)
	else:
		_discovered_hosts[host_id] = host_info
		_create_host_button(host_id, host_info)
	_update_status("Found " + str(_discovered_hosts.size()) + " host(s)")


func _on_discovery_started() -> void:
	_is_refreshing = true
	refresh_started.emit()
	_update_status("Searching for games...")
	_set_refresh_button_state(true)


func _on_discovery_stopped() -> void:
	_is_refreshing = false
	refresh_stopped.emit()
	if _discovered_hosts.is_empty():
		_update_status("No games found. Make sure you're on the same Wi-Fi.")
	_set_refresh_button_state(false)


func _set_refresh_button_state(searching: bool) -> void:
	var btn := _get_refresh_btn()
	if btn:
		btn.disabled = searching
		btn.text = "Searching..." if searching else "Refresh"


func _get_refresh_btn() -> Button:
	if not refresh_button:
		return null
	return get_node(refresh_button) as Button


func _get_container() -> Node:
	if not host_list_container:
		return null
	return get_node(host_list_container)


func _create_host_button(host_id: String, host_info: Dictionary) -> void:
	var container := _get_container()
	if not container:
		return
	var btn: Button = host_button_scene.instantiate() if host_button_scene else Button.new()
	btn.name = "Host_" + host_id.replace(":", "_")
	_update_button_text(btn, host_info)
	btn.pressed.connect(_on_host_button_pressed.bind(host_id))
	container.add_child(btn)


func _update_host_button(host_id: String, host_info: Dictionary) -> void:
	var container := _get_container()
	if not container:
		return
	var btn := container.get_node_or_null("Host_" + host_id.replace(":", "_")) as Button
	if btn:
		_update_button_text(btn, host_info)


func _update_button_text(btn: Button, host_info: Dictionary) -> void:
	var host_name := host_info.get("host_name", "Unknown Host") as String
	var code := host_info.get("invite_code", "") as String
	btn.text = host_name if code.is_empty() else host_name + " [" + code + "]"
	btn.set_meta("host_info", host_info)


func _clear_host_list() -> void:
	var container := _get_container()
	if not container:
		return
	for child in container.get_children():
		if child.name.begins_with("Host_"):
			child.queue_free()


func _on_host_button_pressed(host_id: String) -> void:
	var host_info: Variant = _discovered_hosts.get(host_id)
	if host_info:
		host_selected.emit(host_info)


func _update_status(message: String) -> void:
	if not status_label:
		return
	var label := get_node(status_label) as Label
	if label:
		label.text = message
