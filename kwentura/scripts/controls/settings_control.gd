extends CanvasLayer

## SettingsControl - A reusable settings button that emits signal when pressed

signal settings_pressed

@onready var settings_button: TouchScreenButton = $Settings


func _ready() -> void:
	# Connect the settings button
	if settings_button and not settings_button.is_connected("pressed", _on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)


func _on_settings_pressed() -> void:
	print("[SettingsControl] Settings button pressed")
	settings_pressed.emit()


func show_button() -> void:
	if settings_button:
		settings_button.visible = true


func hide_button() -> void:
	if settings_button:
		settings_button.visible = false
