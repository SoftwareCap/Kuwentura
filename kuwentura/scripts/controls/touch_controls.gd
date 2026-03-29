class_name TouchControls
extends CanvasLayer

## TouchControls handles visibility of on-screen touch controls.
## TouchScreenButton nodes automatically trigger input actions when pressed.

signal pause_pressed
signal map_pressed
signal ledger_pressed
signal briefcase_pressed

enum VisibilityMode {
	AUTO, ## Show on mobile/tablet, hide on desktop
	ALWAYS_SHOW, ## Always visible
	ALWAYS_HIDE  ## Always hidden
}

@export var visibility_mode: VisibilityMode = VisibilityMode.ALWAYS_SHOW
@export var fade_duration: float = 0.2
@export var button_scale_pressed: float = 0.9

@onready var left_button: TouchScreenButton = $Left
@onready var right_button: TouchScreenButton = $Right
@onready var jump_button: TouchScreenButton = $Jump
@onready var pause_button: TouchScreenButton = $Pause
@onready var map_button: TouchScreenButton = $Map
@onready var ledger_button: TouchScreenButton = $Ledger
@onready var briefcase_button: TouchScreenButton = $Briefcase

var _is_visible: bool = true
var _original_scales: Dictionary = {}

const OPAQUE := Color(1, 1, 1, 1)
const TRANSPARENT := Color(1, 1, 1, 0)

# Central registry — single source of truth for all button wiring.
# key: id → { button, signal (or null) }
# Buttons without a signal (movement, jump) emit only animation.
var _button_registry: Dictionary = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for id in _button_registry:
			_disconnect_button(id)


func _ready() -> void:
	_button_registry = {
		"left" : { "button" : left_button, "signal" : null },
		"right" : { "button" : right_button, "signal" : null },
		"jump" : { "button" : jump_button, "signal" : null },
		"pause" : { "button" : pause_button, "signal" : pause_pressed },
		"map" : { "button" : map_button, "signal" : map_pressed },
		"ledger" : { "button" : ledger_button, "signal" : ledger_pressed },
		"briefcase" : { "button" : briefcase_button, "signal" : briefcase_pressed },
	}

	for id in _button_registry:
		var button: TouchScreenButton = _button_registry[id].button
		if button:
			_original_scales[button] = button.scale
			_connect_button(id)

	_apply_visibility_mode()


# Public getter — lets external scripts access buttons safely by id
# without accidentally resolving sibling nodes of the same name.
func get_button(id: String) -> TouchScreenButton:
	var entry: Dictionary = _button_registry.get(id, {})
	return entry.get("button", null) as TouchScreenButton


# Connection helpers
func _connect_button(id: String) -> void:
	var button: TouchScreenButton = _button_registry[id].button
	if not button:
		return
	button.pressed.connect(_on_button_pressed.bind(id))
	button.released.connect(_on_button_released.bind(id))


func _disconnect_button(id: String) -> void:
	var button: TouchScreenButton = _button_registry[id].button
	if not button:
		return
	if button.pressed.is_connected(_on_button_pressed):
		button.pressed.disconnect(_on_button_pressed)
	if button.released.is_connected(_on_button_released):
		button.released.disconnect(_on_button_released)


# Generic button handlers
func _on_button_pressed(id: String) -> void:
	var entry: Dictionary = _button_registry[id]
	_animate_button_press(entry.button, true)
	if entry.signal:
		entry.signal.emit()


func _on_button_released(id: String) -> void:
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
	self.modulate = TRANSPARENT
	_fade_modulate(OPAQUE)


func hide_controls() -> void:
	if not _is_visible:
		return
	_is_visible = false
	_fade_modulate(TRANSPARENT).tween_callback(func(): visible = false)


func toggle_controls() -> void:
	if _is_visible:
		hide_controls()
	else:
		show_controls()


func _fade_modulate(target: Color) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "modulate", target, fade_duration)
	return tween


# Enable / disable
func set_button_visible(id: String, value: bool) -> void:
	var entry: Dictionary = _button_registry.get(id, {})
	var button: TouchScreenButton = entry.get("button")
	if button:
		button.visible = value


# Convenience wrappers for common groups and backward compatibility
func set_movement_enabled(enabled: bool) -> void:
	set_button_visible("left", enabled)
	set_button_visible("right", enabled)


func set_jump_enabled(enabled: bool) -> void:
	set_button_visible("jump", enabled)


func set_pause_enabled(enabled: bool) -> void:
	set_button_visible("pause", enabled)


# Animation
func _animate_button_press(button: TouchScreenButton, pressed: bool) -> void:
	if not button:
		return
	var original_scale: Vector2 = _original_scales.get(button, Vector2.ONE)
	var target_scale: Vector2 = original_scale * button_scale_pressed if pressed else original_scale
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", target_scale, 0.05)


# Queries
func is_showing() -> bool:
	return _is_visible
