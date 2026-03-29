extends CanvasLayer

signal settings_pressed

@onready var settings_button: TouchScreenButton = $Settings


func _ready() -> void:
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func show_button() -> void:
	_set_button_visible(true)


func hide_button() -> void:
	_set_button_visible(false)


func _set_button_visible(value: bool) -> void:
	if settings_button:
		settings_button.visible = value
