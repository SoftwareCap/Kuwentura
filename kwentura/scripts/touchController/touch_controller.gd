extends CanvasLayer

## TouchControls handles visibility of on-screen touch controls
## The TouchScreenButton nodes automatically trigger input actions when pressed

enum VisibilityMode {
	AUTO,       ## Show on mobile/tablet, hide on desktop
	ALWAYS_SHOW,## Always visible
	ALWAYS_HIDE ## Always hidden
}

@export var visibility_mode: VisibilityMode = VisibilityMode.ALWAYS_SHOW
@export var fade_duration: float = 0.2
@export var button_scale_pressed: float = 0.9

@onready var left_button: TouchScreenButton = $Left
@onready var right_button: TouchScreenButton = $Right
@onready var jump_button: TouchScreenButton = $Jump
@onready var settings_button: TouchScreenButton = $Settings

var _is_visible: bool = true

# Button original scales for press animation
var _original_scales: Dictionary = {}


func _ready():
	# Store original scales for press animations
	_original_scales[left_button] = left_button.scale
	_original_scales[right_button] = right_button.scale
	_original_scales[jump_button] = jump_button.scale
	_original_scales[settings_button] = settings_button.scale
	
	_connect_button_signals()
	_apply_visibility_mode()


func _connect_button_signals():
	# Connect signals programmatically to avoid editor setup
	left_button.pressed.connect(_on_left_pressed)
	left_button.released.connect(_on_left_released)
	right_button.pressed.connect(_on_right_pressed)
	right_button.released.connect(_on_right_released)
	jump_button.pressed.connect(_on_jump_pressed)
	jump_button.released.connect(_on_jump_released)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_button.released.connect(_on_settings_released)


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


## Enable/disable specific buttons
func set_movement_enabled(enabled: bool):
	left_button.visible = enabled
	right_button.visible = enabled


func set_jump_enabled(enabled: bool):
	jump_button.visible = enabled


func set_settings_enabled(enabled: bool):
	settings_button.visible = enabled


## Check if controls are currently visible
func is_showing() -> bool:
	return _is_visible


# ==================== BUTTON SIGNAL HANDLERS ====================

func _on_left_pressed() -> void:
	_animate_button_press(left_button, true)


func _on_left_released() -> void:
	_animate_button_press(left_button, false)


func _on_right_pressed() -> void:
	_animate_button_press(right_button, true)


func _on_right_released() -> void:
	_animate_button_press(right_button, false)


func _on_jump_pressed() -> void:
	_animate_button_press(jump_button, true)


func _on_jump_released() -> void:
	_animate_button_press(jump_button, false)


func _on_settings_pressed() -> void:
	_animate_button_press(settings_button, true)


func _on_settings_released() -> void:
	_animate_button_press(settings_button, false)
