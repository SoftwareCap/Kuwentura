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

func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		if pause_button and pause_button.pressed.is_connected(_on_pause_pressed):
			pause_button.pressed.disconnect(_on_pause_pressed)
			pause_button.released.disconnect(_on_pause_released)

		if ledger_button and ledger_button.pressed.is_connected(_on_ledger_pressed):
			ledger_button.pressed.disconnect(_on_ledger_pressed)
			ledger_button.released.disconnect(_on_ledger_released)

		if briefcase_button and briefcase_button.pressed.is_connected(_on_briefcase_pressed):
			briefcase_button.pressed.disconnect(_on_briefcase_pressed)
			briefcase_button.released.disconnect(_on_briefcase_released)

func _ready():
	if pause_button:
		_original_scales[pause_button] = pause_button.scale
	if ledger_button:
		_original_scales[ledger_button] = ledger_button.scale
	if briefcase_button:
		_original_scales[briefcase_button] = briefcase_button.scale

	_connect_button_signals()
	_apply_visibility_mode()

func _connect_button_signals():
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
		pause_button.released.connect(_on_pause_released)

	if ledger_button:
		ledger_button.pressed.connect(_on_ledger_pressed)
		ledger_button.released.connect(_on_ledger_released)

	if briefcase_button:
		briefcase_button.pressed.connect(_on_briefcase_pressed)
		briefcase_button.released.connect(_on_briefcase_released)

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
	var platform = OS.get_name()
	return platform in ["Android", "iOS", "Web"]

func _animate_button_press(button: TouchScreenButton, pressed: bool):
	if button == null:
		return

	var original_scale = _original_scales.get(button, Vector2.ONE)
	var target_scale = original_scale * button_scale_pressed if pressed else original_scale

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", target_scale, 0.05)

func show_controls():
	if _is_visible:
		return

	_is_visible = true
	visible = true

	for child in get_children():
		if child is CanvasItem:
			child.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	for child in get_children():
		if child is CanvasItem:
			tween.parallel().tween_property(child, "modulate", Color(1, 1, 1, 1), fade_duration)

func hide_controls():
	if not _is_visible:
		return

	_is_visible = false

	var tween = create_tween()
	for child in get_children():
		if child is CanvasItem:
			tween.parallel().tween_property(child, "modulate", Color(1, 1, 1, 0), fade_duration)
	tween.tween_callback(func(): visible = false)
	
func toggle_controls():
	if _is_visible:
		hide_controls()
	else:
		show_controls()

func set_pause_enabled(enabled: bool):
	if pause_button:
		pause_button.visible = enabled

func set_ledger_enabled(enabled: bool):
	if ledger_button:
		ledger_button.visible = enabled

func set_briefcase_enabled(enabled: bool):
	if briefcase_button:
		briefcase_button.visible = enabled

func set_sidekick_ui_visible(is_sidekick: bool):
	if ledger_button:
		ledger_button.visible = is_sidekick
	if briefcase_button:
		briefcase_button.visible = is_sidekick

func is_showing() -> bool:
	return _is_visible

func _on_pause_pressed() -> void:
	_animate_button_press(pause_button, true)
	pause_pressed.emit()

func _on_pause_released() -> void:
	_animate_button_press(pause_button, false)

func _on_ledger_pressed() -> void:
	_animate_button_press(ledger_button, true)
	ledger_pressed.emit()

func _on_ledger_released() -> void:
	_animate_button_press(ledger_button, false)

func _on_briefcase_pressed() -> void:
	_animate_button_press(briefcase_button, true)
	briefcase_pressed.emit()

func _on_briefcase_released() -> void:
	_animate_button_press(briefcase_button, false)
