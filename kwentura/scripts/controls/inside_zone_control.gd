extends CanvasLayer

## TouchControls handles visibility of on-screen touch controls
## The TouchScreenButton nodes automatically trigger input actions when pressed

signal pause_pressed

enum VisibilityMode {
	AUTO,       ## Show on mobile/tablet, hide on desktop
	ALWAYS_SHOW,## Always visible
	ALWAYS_HIDE ## Always hidden
}

@export var visibility_mode: VisibilityMode = VisibilityMode.ALWAYS_SHOW
@export var fade_duration: float = 0.2
@export var button_scale_pressed: float = 0.9

@onready var pause_button: TouchScreenButton = $Pause


func _notification(what: int):
	# Handle node being removed from tree (scene change)
	if what == NOTIFICATION_PREDELETE:
		# Disconnect signals to prevent errors during cleanup
		if pause_button and pause_button.pressed.is_connected(_on_pause_pressed):
			pause_button.pressed.disconnect(_on_pause_pressed)
			pause_button.released.disconnect(_on_pause_released)

var _is_visible: bool = true

# Button original scales for press animation
var _original_scales: Dictionary = {}


func _ready():
	# Store original scales for press animations (with null checks)
	if pause_button:
		_original_scales[pause_button] = pause_button.scale
	
	_connect_button_signals()
	_apply_visibility_mode()


func _connect_button_signals():
	# Connect signals programmatically to avoid editor setup (with null checks)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
		pause_button.released.connect(_on_pause_released)


func _apply_visibility_mode():
	match visibility_mode:
		VisibilityMode.AUTO:
			visible = _should_show_on_this_device()
		VisibilityMode.ALWAYS_SHOW:
			visible = true
		VisibilityMode.ALWAYS_HIDE:
			visible = false
	_is_visible = visible


func _should_show_on_this_device() -> bool:
	## Show touch controls on mobile platforms and web
	var platform = OS.get_name()
	return platform in ["Android", "iOS", "Web"]


## Animate button press
func _animate_button_press(button: TouchScreenButton, pressed: bool):
	var original_scale = _original_scales.get(button, Vector2.ONE)
	var target_scale = original_scale * button_scale_pressed if pressed else original_scale
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", target_scale, 0.05)


## Show the touch controls
func show_controls():
	if _is_visible:
		return
	_is_visible = true
	visible = true
	self.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), fade_duration)


## Hide the touch controls
func hide_controls():
	if not _is_visible:
		return
	_is_visible = false
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), fade_duration)
	tween.tween_callback(func(): visible = false)


## Toggle visibility
func toggle_controls():
	if _is_visible:
		hide_controls()
	else:
		show_controls()


func set_pause_enabled(enabled: bool):
	if pause_button:
		pause_button.visible = enabled


## Check if controls are currently visible
func is_showing() -> bool:
	return _is_visible


func _on_pause_pressed() -> void:
	_animate_button_press(pause_button, true)
	print("[TouchControls] Pause button pressed, emitting signal")
	pause_pressed.emit()


func _on_pause_released() -> void:
	_animate_button_press(pause_button, false)
