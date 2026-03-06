extends CanvasLayer

## TouchControls handles visibility of on-screen touch controls
## The TouchScreenButton nodes automatically trigger input actions when pressed

signal pause_pressed
signal ledger_pressed
signal briefcase_pressed
signal map_pressed

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
@onready var pause_button: TouchScreenButton = $Pause
@onready var map_button: TouchScreenButton = $Map
@onready var ledger_button: TouchScreenButton = $Ledger
@onready var briefcase_button: TouchScreenButton = $Briefcase


func _notification(what: int):
	# Handle node being removed from tree (scene change)
	if what == NOTIFICATION_PREDELETE:
		# Disconnect signals to prevent errors during cleanup
		if left_button and left_button.pressed.is_connected(_on_left_pressed):
			left_button.pressed.disconnect(_on_left_pressed)
			left_button.released.disconnect(_on_left_released)
		if right_button and right_button.pressed.is_connected(_on_right_pressed):
			right_button.pressed.disconnect(_on_right_pressed)
			right_button.released.disconnect(_on_right_released)
		if jump_button and jump_button.pressed.is_connected(_on_jump_pressed):
			jump_button.pressed.disconnect(_on_jump_pressed)
			jump_button.released.disconnect(_on_jump_released)
		if pause_button and pause_button.pressed.is_connected(_on_pause_pressed):
			pause_button.pressed.disconnect(_on_pause_pressed)
			pause_button.released.disconnect(_on_pause_released)
		if ledger_button and ledger_button.pressed.is_connected(_on_ledger_pressed):
			ledger_button.pressed.disconnect(_on_ledger_pressed)
		if map_button and map_button.pressed.is_connected(_on_map_pressed):
			map_button.pressed.disconnect(_on_map_pressed)
		if ledger_button and ledger_button.pressed.is_connected(_on_ledger_pressed):
			ledger_button.pressed.disconnect(_on_ledger_pressed)
		if briefcase_button and briefcase_button.pressed.is_connected(_on_briefcase_pressed):
			briefcase_button.pressed.disconnect(_on_briefcase_pressed)

var _is_visible: bool = true

# Button original scales for press animation
var _original_scales: Dictionary = {}


func _ready():
	# Store original scales for press animations (with null checks)
	if left_button:
		_original_scales[left_button] = left_button.scale
	if right_button:
		_original_scales[right_button] = right_button.scale
	if jump_button:
		_original_scales[jump_button] = jump_button.scale
	if pause_button:
		_original_scales[pause_button] = pause_button.scale
	if map_button:
		_original_scales[map_button] = map_button.scale
		print("[TouchControls] Map button found at ", map_button.position, " with scale ", map_button.scale)
	else:
		print("[TouchControls] WARNING: Map button NOT found in scene!")
	
	_connect_button_signals()
	_apply_visibility_mode()


func _connect_button_signals():
	# Connect signals programmatically to avoid editor setup (with null checks)
	if left_button:
		left_button.pressed.connect(_on_left_pressed)
		left_button.released.connect(_on_left_released)
	if right_button:
		right_button.pressed.connect(_on_right_pressed)
		right_button.released.connect(_on_right_released)
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
		jump_button.released.connect(_on_jump_released)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
		pause_button.released.connect(_on_pause_released)
	if map_button:
		map_button.pressed.connect(_on_map_pressed)
		print("[TouchControls] Map button connected: visible=", map_button.visible, " shape=", map_button.shape)
	else:
		print("[TouchControls] WARNING: Map button not found!")
	if ledger_button:
		ledger_button.pressed.connect(_on_ledger_pressed)
	if briefcase_button:
		briefcase_button.pressed.connect(_on_briefcase_pressed)


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


func set_pause_enabled(enabled: bool):
	if pause_button:
		pause_button.visible = enabled


func set_map_enabled(enabled: bool):
	if map_button:
		map_button.visible = enabled


func set_ledger_enabled(enabled: bool):
	if ledger_button:
		ledger_button.visible = enabled


func set_briefcase_enabled(enabled: bool):
	if briefcase_button:
		briefcase_button.visible = enabled


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


func _on_pause_pressed() -> void:
	_animate_button_press(pause_button, true)
	print("[TouchControls] Pause button pressed, emitting signal")
	pause_pressed.emit()


func _on_pause_released() -> void:
	_animate_button_press(pause_button, false)


func _on_ledger_pressed() -> void:
	print("[TouchControls] Ledger button pressed, emitting signal")
	ledger_pressed.emit()


func _on_briefcase_pressed() -> void:
	print("[TouchControls] Briefcase button pressed, emitting signal")
	briefcase_pressed.emit()


func _on_map_pressed() -> void:
	print("[TouchControls] Map button PRESSED! Emitting map_pressed signal")
	map_pressed.emit()
	print("[TouchControls] map_pressed signal emitted")
