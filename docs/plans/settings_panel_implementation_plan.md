# Settings Panel Implementation Plan

## Overview
This document outlines the implementation of:
1. **Button visibility toggle** when settings panel opens/closes (Main Menu & Detective Lobby)
2. **"View User Profile" button functionality** to show the User Profile panel

---

## Current Implementation Status

### ✅ Completed

All three main menu scenes now have consistent settings panel behavior:

| Scene | Buttons Hidden on Settings Open | Has User Profile |
|-------|--------------------------------|------------------|
| MainMenu | Host, Join, Exit | ✅ Yes |
| DetectiveLobby | Back | ✅ Yes |
| SidekickWaiting | Cancel | ✅ Yes |

---

## Architecture Pattern

### Scene Structure (Consistent across all scenes)

```
Control (root)
├── Main UI Buttons (Host, Join, Exit / Start, Back / Cancel)
├── SettingsControl (CanvasLayer)
│   └── Settings (TouchScreenButton)
└── SettingsPanel (Panel - hidden by default)
    ├── Label ("Settings")
    ├── Back (TouchScreenButton - closes settings)
    ├── ViewUserProfile (Button - opens user profile)
    ├── VolumeSliderControl
    └── UserProfile (Panel - hidden by default)
        ├── Label ("User Profile")
        ├── BackToPrevious (TouchScreenButton - back to settings)
        ├── UserContent
        │   ├── AvatarTexture
        │   └── UserInfo
        │       ├── DisplayName
        │       └── ProviderLabel
        └── AuthButtons
            ├── SignInButton
            ├── GuestButton
            └── LinkGoogleButton
```

### Code Pattern (Reusable)

```gdscript
# Node References
@onready var settings_control: CanvasLayer = $SettingsControl
@onready var settings_panel: Panel = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSliderControl/VolumeSlider
@onready var volume_value_label: Label = $SettingsPanel/VolumeSliderControl/VolumeValue
@onready var back_button_settings: TouchScreenButton = $SettingsPanel/Back
@onready var view_user_profile_button: Button = $SettingsPanel/ViewUserProfile
@onready var user_profile_panel: Panel = $SettingsPanel/UserProfile
@onready var user_profile_back_button: TouchScreenButton = $SettingsPanel/UserProfile/BackToPrevious

# User Auth UI (inside UserProfile panel)
@onready var avatar_texture: TextureRect = $SettingsPanel/UserProfile/UserContent/AvatarTexture
@onready var display_name_label: Label = $SettingsPanel/UserProfile/UserContent/UserInfo/DisplayName
@onready var provider_label: Label = $SettingsPanel/UserProfile/UserContent/UserInfo/ProviderLabel
@onready var sign_in_button: Button = $SettingsPanel/UserProfile/AuthButtons/SignInButton
@onready var guest_button: Button = $SettingsPanel/UserProfile/AuthButtons/GuestButton
@onready var link_google_button: Button = $SettingsPanel/UserProfile/AuthButtons/LinkGoogleButton

# Main UI button(s) to hide when settings opens
@onready var back_button: Button = %BackButton  # or cancel_button, etc.

#------------------------------------------------------------------------------
# Settings Button Visibility Pattern
#------------------------------------------------------------------------------

func _set_main_buttons_visible(visible: bool) -> void:
    """Toggle visibility of main UI buttons.
    Only hide buttons that should be hidden when settings opens.
    The settings button itself is handled by settings_control.hide_button()/show_button().
    """
    if back_button:
        back_button.visible = visible


func _on_settings_pressed() -> void:
    print("[SceneName] Opening settings panel")
    if settings_panel:
        settings_panel.visible = true
        # Hide main UI button(s)
        _set_main_buttons_visible(false)
        # Hide the settings button itself
        if settings_control:
            settings_control.hide_button()
        # Ensure user profile is hidden when opening settings
        if user_profile_panel:
            user_profile_panel.visible = false
        # Show view user profile button
        if view_user_profile_button:
            view_user_profile_button.visible = true
        # Update volume slider
        if volume_slider:
            volume_slider.value = MusicController.get_volume() * 100
        if volume_value_label:
            volume_value_label.text = str(int(volume_slider.value)) + "%"


func _on_back_settings_pressed() -> void:
    print("[SceneName] Closing settings panel")
    if settings_panel:
        settings_panel.visible = false
    # Also hide user profile panel
    if user_profile_panel:
        user_profile_panel.visible = false
    # Show main UI button(s)
    _set_main_buttons_visible(true)
    # Show the settings button
    if settings_control:
        settings_control.show_button()
    _save_settings()


#------------------------------------------------------------------------------
# User Profile Panel Pattern
#------------------------------------------------------------------------------

func _on_view_user_profile_pressed() -> void:
    print("[SceneName] Opening user profile panel")
    if user_profile_panel:
        user_profile_panel.visible = true
    # Hide the view user profile button while in profile view
    if view_user_profile_button:
        view_user_profile_button.visible = false


func _on_back_from_profile_pressed() -> void:
    print("[SceneName] Closing user profile panel")
    if user_profile_panel:
        user_profile_panel.visible = false
    # Show the view user profile button again
    if view_user_profile_button:
        view_user_profile_button.visible = true
```

---

## Signal Connections

In `_ready()`, connect these signals:

```gdscript
# Settings button (from SettingsControl)
if settings_control and not settings_control.settings_pressed.is_connected(_on_settings_pressed):
    settings_control.settings_pressed.connect(_on_settings_pressed)

# Settings panel back button
if back_button_settings and not back_button_settings.pressed.is_connected(_on_back_settings_pressed):
    back_button_settings.pressed.connect(_on_back_settings_pressed)

# Volume slider
if volume_slider and not volume_slider.value_changed.is_connected(_on_volume_changed):
    volume_slider.value_changed.connect(_on_volume_changed)

# View User Profile button
if view_user_profile_button and not view_user_profile_button.pressed.is_connected(_on_view_user_profile_pressed):
    view_user_profile_button.pressed.connect(_on_view_user_profile_pressed)

# Back from profile button
if user_profile_back_button and not user_profile_back_button.pressed.is_connected(_on_back_from_profile_pressed):
    user_profile_back_button.pressed.connect(_on_back_from_profile_pressed)
```

---

## Per-Scene Button Visibility Configuration

### MainMenu
- **Buttons to hide**: HostButton, JoinButton, ExitButton
- **Implementation**: `_set_main_buttons_visible()` hides all three buttons

### DetectiveLobby  
- **Buttons to hide**: BackButton only
- **Implementation**: `_set_main_buttons_visible()` only toggles back_button
- **Note**: StartButton, RoomCodeLabel, and costume buttons remain visible

### SidekickWaiting
- **Buttons to hide**: CancelButton only  
- **Implementation**: `_set_main_buttons_visible()` only toggles cancel_button
- **Note**: StatusLabel and costume buttons remain visible

---

## Files Modified

| File | Changes |
|------|---------|
| `kwentura/scripts/controls/settings_panel_base.gd` | New reusable base class (optional) |
| `kwentura/scripts/mainMenu/main_menu.gd` | Updated node paths, added user profile navigation |
| `kwentura/scripts/mainMenu/detective_lobby.gd` | Updated to match MainMenu structure, simplified button visibility |
| `kwentura/scripts/mainMenu/sidekick_waiting.gd` | Updated to match MainMenu structure, simplified button visibility |
| `kwentura/scenes/mainMenu/DetectiveLobby.tscn` | Copied settings panel from MainMenu |
| `kwentura/scenes/mainMenu/SidekickWaiting.tscn` | Copied settings panel from MainMenu |

---

## Navigation Flow

```
Main UI
   │
   ▼ (click Settings button)
SettingsPanel
   ├── Volume Controls
   ├── ViewUserProfile button
   │
   ▼ (click ViewUserProfile)
UserProfile Panel
   ├── User info (avatar, name, provider)
   ├── Auth buttons (Sign in, Guest, Link Google)
   └── BackToPrevious button
       │
       ▼ (click Back)
   Returns to SettingsPanel
   │
   ▼ (click Back in SettingsPanel)
Returns to Main UI
```

---

## Key Design Decisions

1. **Minimal Button Hiding**: Only hide buttons that could interfere with the settings panel (Back/Cancel). Keep other UI visible for context.

2. **Consistent Structure**: All scenes use the same node structure for settings panels, making maintenance easier.

3. **SettingsControl Handles Its Own Visibility**: The settings button uses `settings_control.hide_button()` and `show_button()` rather than being in the main buttons array.

4. **UserProfile is a Sub-Panel**: Nested inside SettingsPanel, not a separate scene, for simpler state management.
