## SettingsPanelBase - Reusable base class for settings panel functionality
## Attach this as a script to the root Control node of scenes with settings panels
## or use as a reference for implementing the pattern

extends Control
class_name SettingsPanelBase

#------------------------------------------------------------------------------
# Node References - Override these in child classes with @onready vars
#------------------------------------------------------------------------------

## Reference to the SettingsControl (CanvasLayer with settings button)
var settings_control: CanvasLayer

## Reference to the SettingsPanel (main settings panel container)
var settings_panel: Control

## Reference to the volume slider (optional)
var volume_slider: HSlider

## Reference to the volume value label (optional)
var volume_value_label: Label

## Reference to the back button in settings panel (closes settings)
var settings_back_button: TouchScreenButton

## Reference to the "View User Profile" button
var view_user_profile_button: Button

## Reference to the UserProfile sub-panel
var user_profile_panel: Control

## Reference to the back button in user profile (returns to settings)
var user_profile_back_button: TouchScreenButton

#------------------------------------------------------------------------------
# Button Groups - Nodes to hide/show when settings opens/closes
#------------------------------------------------------------------------------

## Array of buttons to hide when settings panel is open
var main_ui_buttons: Array[Control] = []

#------------------------------------------------------------------------------
# Setup Methods - Call these in _ready()
#------------------------------------------------------------------------------

## Connect all settings-related signals. Call this in _ready()
func setup_settings_signals() -> void:
	# Settings button pressed (from SettingsControl)
	if settings_control:
		if not settings_control.settings_pressed.is_connected(_on_settings_pressed):
			settings_control.settings_pressed.connect(_on_settings_pressed)
	
	# Settings panel back button
	if settings_back_button:
		if not settings_back_button.pressed.is_connected(_on_back_settings_pressed):
			settings_back_button.pressed.connect(_on_back_settings_pressed)
	
	# Volume slider
	if volume_slider:
		if not volume_slider.value_changed.is_connected(_on_volume_changed):
			volume_slider.value_changed.connect(_on_volume_changed)
	
	# View User Profile button
	if view_user_profile_button:
		if not view_user_profile_button.pressed.is_connected(_on_view_user_profile_pressed):
			view_user_profile_button.pressed.connect(_on_view_user_profile_pressed)
	
	# Back from profile button
	if user_profile_back_button:
		if not user_profile_back_button.pressed.is_connected(_on_back_from_profile_pressed):
			user_profile_back_button.pressed.connect(_on_back_from_profile_pressed)


## Set the main UI buttons that should be hidden when settings opens
func set_main_ui_buttons(buttons: Array[Control]) -> void:
	main_ui_buttons = buttons


#------------------------------------------------------------------------------
# Core Functionality
#------------------------------------------------------------------------------

## Toggle visibility of main UI buttons
func set_main_buttons_visible(is_visible: bool) -> void:
	for button in main_ui_buttons:
		if is_instance_valid(button):
			button.visible = is_visible


## Open the settings panel
func open_settings() -> void:
	print("[%s] Opening settings panel" % name)
	
	if settings_panel:
		settings_panel.visible = true
		
		# Ensure user profile is hidden when opening settings
		if user_profile_panel:
			user_profile_panel.visible = false
		
		# Hide main UI buttons
		set_main_buttons_visible(false)
		
		# Hide settings button itself
		if settings_control:
			settings_control.hide_button()
		
		# Update volume slider
		_update_volume_display()
		
		# Show view user profile button (in case it was hidden)
		if view_user_profile_button:
			view_user_profile_button.visible = true


## Close the settings panel
func close_settings() -> void:
	print("[%s] Closing settings panel" % name)
	
	if settings_panel:
		settings_panel.visible = false
	
	# Also hide user profile if it's open
	if user_profile_panel:
		user_profile_panel.visible = false
	
	# Show main UI buttons
	set_main_buttons_visible(true)
	
	# Show settings button
	if settings_control:
		settings_control.show_button()
	
	# Save settings
	_save_settings()


## Open the user profile panel (from within settings)
func open_user_profile() -> void:
	print("[%s] Opening user profile panel" % name)
	
	if user_profile_panel:
		user_profile_panel.visible = true
	
	# Hide view user profile button while in profile view
	if view_user_profile_button:
		view_user_profile_button.visible = false


## Close user profile and return to settings
func close_user_profile() -> void:
	print("[%s] Closing user profile panel" % name)
	
	if user_profile_panel:
		user_profile_panel.visible = false
	
	# Show view user profile button again
	if view_user_profile_button:
		view_user_profile_button.visible = true


#------------------------------------------------------------------------------
# Virtual Methods - Override these in child classes
#------------------------------------------------------------------------------

func _on_settings_pressed() -> void:
	open_settings()


func _on_back_settings_pressed() -> void:
	close_settings()


func _on_view_user_profile_pressed() -> void:
	open_user_profile()


func _on_back_from_profile_pressed() -> void:
	close_user_profile()


func _on_volume_changed(value: float) -> void:
	var volume = value / 100.0
	MusicController.set_volume(volume)
	if volume_value_label:
		volume_value_label.text = str(int(value)) + "%"
	print("[%s] Volume changed to: %s" % [name, volume])


func _update_volume_display() -> void:
	if volume_slider:
		volume_slider.value = MusicController.get_volume() * 100
	if volume_value_label:
		volume_value_label.text = str(int(volume_slider.value)) + "%"


func _save_settings() -> void:
	# Override in child class to save settings
	pass
