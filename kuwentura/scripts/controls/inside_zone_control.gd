extends CanvasLayer

signal pause_pressed
signal ledger_pressed
signal briefcase_pressed

enum VisibilityMode {
	AUTO,
	ALWAYS_SHOW,
	ALWAYS_HIDE
}

@export var visibility_mode: VisibilityMode = VisibilityMode.ALWAYS_SHOW
@export var fade_duration: float = 0.2
@export var button_scale_pressed: float = 0.9

@onready var pause_button: TouchScreenButton = $Pause
@onready var ledger_button: TouchScreenButton = get_node_or_null("Ledger")
@onready var briefcase_button: TouchScreenButton = get_node_or_null("Briefcase")

var _is_visible: bool = true
var _original_scales: Dictionary = {}

var _enabled: Dictionary = {}

const NORMAL_COLOR := Color(1, 1, 1, 1)
const DISABLED_COLOR := Color(0.65, 0.65, 0.65, 1.0)
const TRANSPARENT := Color(1, 1, 1, 0)

# Buttons that are only visible to the sidekick role
const SIDEKICK_ONLY := ["ledger", "briefcase"]

# Central registry — single source of truth for all button wiring
# key: id  →  { button, signal (or null), role_gated }
var _button_registry: Dictionary = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for id in _button_registry:
			_disconnect_button(id)


func _ready() -> void:
	_button_registry = {
		"pause" : { "button" : pause_button, "signal" : pause_pressed, "role_gated" : false },
		"ledger" : { "button" : ledger_button, "signal" : ledger_pressed, "role_gated" : true  },
		"briefcase" : { "button" : briefcase_button, "signal" : briefcase_pressed, "role_gated" : true  },
	}

	for id in _button_registry:
		var entry: Dictionary = _button_registry[id]
		var button: TouchScreenButton = entry.button
		_enabled[id] = true
		if button:
			_original_scales[button] = button.scale
			_connect_button(id)

	_apply_visibility_mode()


# Connection helpers
func _connect_button(id: String) -> void:
	var entry: Dictionary = _button_registry[id]
	var button: TouchScreenButton = entry.button
	if not button:
		return
	button.pressed.connect(_on_button_pressed.bind(id))
	button.released.connect(_on_button_released.bind(id))


func _disconnect_button(id: String) -> void:
	var entry: Dictionary = _button_registry[id]
	var button: TouchScreenButton = entry.button
	if not button:
		return
	if button.pressed.is_connected(_on_button_pressed):
		button.pressed.disconnect(_on_button_pressed)
	if button.released.is_connected(_on_button_released):
		button.released.disconnect(_on_button_released)


# Generic button handlers
func _on_button_pressed(id: String) -> void:
	if not _enabled.get(id, false):
		return
	var entry: Dictionary = _button_registry[id]
	_animate_button_press(entry.button, true)
	entry.signal.emit()


func _on_button_released(id: String) -> void:
	if not _enabled.get(id, false):
		return
	_animate_button_press(_button_registry[id].button, false)


# Visibility
func _apply_visibility_mode() -> void:
	match visibility_mode:
		VisibilityMode.AUTO:
			visible = _should_show_on_this_device()
		VisibilityMode.ALWAYS_SHOW:
			visible = true
		VisibilityMode.ALWAYS_HIDE:
			visible = false
	_is_visible = visible


func _should_show_on_this_device() -> bool:
	return OS.get_name() in ["Android", "iOS", "Web"]


func show_controls() -> void:
	if _is_visible:
		return
	_is_visible = true
	visible = true
	_fade_children(TRANSPARENT, NORMAL_COLOR)


func hide_controls() -> void:
	if not _is_visible:
		return
	_is_visible = false
	var tween := _fade_children(NORMAL_COLOR, TRANSPARENT)
	tween.tween_callback(func(): visible = false)


func toggle_controls() -> void:
	if _is_visible:
		hide_controls()
	else:
		show_controls()


func _fade_children(from: Color, to: Color) -> Tween:
	"""Fade all CanvasItem children from one modulate color to another."""
	for child in get_children():
		if child is CanvasItem:
			child.modulate = from
	var tween := create_tween()
	for child in get_children():
		if child is CanvasItem:
			tween.parallel().tween_property(child, "modulate", to, fade_duration)
	return tween


# Enable / disable
func set_button_enabled(id: String, enabled: bool) -> void:
	"""Enable or disable any button by id. Role-gated buttons also respect sidekick visibility."""
	if not _button_registry.has(id):
		push_warning("[HUDControls] Unknown button id: " + id)
		return

	_enabled[id] = enabled
	var entry: Dictionary = _button_registry[id]
	var button: TouchScreenButton = entry.button
	if button:
		button.modulate = NORMAL_COLOR if enabled else DISABLED_COLOR


# Convenience wrappers kept for backward compatibility with existing callers
func set_pause_enabled(enabled: bool) -> void: set_button_enabled("pause", enabled)
func set_ledger_enabled(enabled: bool) -> void: set_button_enabled("ledger", enabled)
func set_briefcase_enabled(enabled: bool) -> void: set_button_enabled("briefcase", enabled)


func set_sidekick_ui_visible(is_sidekick: bool) -> void:
	"""Show or hide all role-gated buttons based on the local player's role."""
	for id in SIDEKICK_ONLY:
		var entry: Dictionary = _button_registry.get(id, {})
		var button: TouchScreenButton = entry.get("button")
		if button:
			button.visible = is_sidekick


# Animation
func _animate_button_press(button: TouchScreenButton, pressed: bool) -> void:
	if not button:
		return
	var original_scale: Vector2 = _original_scales.get(button, Vector2.ONE)
	var target_scale: Vector2   = original_scale * button_scale_pressed if pressed else original_scale
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", target_scale, 0.05)


# Queries
func is_showing() -> bool:
	return _is_visible
