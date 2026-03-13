# Continue Button Feature Design

## Overview

Add a "Continue" button to the Main Menu that allows players to resume their saved game progress directly. This follows standard game UX patterns and leverages the existing `LocalSaveManager` system.

## User Experience Flow

```
┌─────────────────────────────────┐
│           KUWENTURA             │
│                                 │
│      ┌──────────────┐          │
│      │   CONTINUE   │  ← Only shows if save exists
│      └──────────────┘          │
│         3/5 zones              │  ← Progress hint
│                                 │
│      ┌──────────────┐          │
│      │  HOST GAME   │          │
│      └──────────────┘          │
│                                 │
│      ┌──────────────┐          │
│      │  JOIN GAME   │          │
│      └──────────────┘          │
│                                 │
└─────────────────────────────────┘
```

### Behavior

| Scenario | Behavior |
|----------|----------|
| No save file | Continue button hidden |
| Save exists | Continue button visible with progress hint |
| Click Continue | Load save and spawn in `current_zone` |
| Host/Join clicked | Normal multiplayer flow (save still exists) |

## Save Data Used

The Continue button uses data from `LocalSaveManager.get_save_info()`:

```gdscript
{
    "exists": true,
    "current_zone": "forest_hub",      # Where to spawn
    "zones_completed": 3,               # For progress display
    "play_time": 3600,                  # Optional: display play time
    "game_completed": false             # Check if game was finished
}
```

## Implementation Guide

### 1. Scene Changes (MainMenu.tscn)

Add a new `TextureButton` node for the Continue button, positioned above the Host button:

```
MainMenu (Control)
├── Panel (background)
├── Title (Label)
├── ContinueButton (TextureButton)  ← NEW
├── HostButton (TextureButton)
├── JoinButton (TextureButton)
├── StatusLabel (Label)
├── SidekickPopup (Panel)
├── SettingsControl (CanvasLayer)
└── SettingsPanel (Panel)
```

**Suggested position:** Centered, above Host button with ~20px spacing.

### 2. Script Changes (main_menu.gd)

#### New Node Reference

```gdscript
@onready var continue_button: TextureButton = $ContinueButton
```

#### New Constants

```gdscript
# Zone name mapping for display
const ZONE_DISPLAY_NAMES: Dictionary = {
    "forest_hub": "Forest Hub",
    "pinas_house": "Pina's House",
    "backyard_path": "Backyard Path",
    "old_well": "Old Well",
    "storage_hut": "Storage Hut",
    "abandoned_house": "Abandoned House"
}
```

#### Modified _ready() Function

```gdscript
func _ready():
    # Ensure main menu music is playing
    MusicController.play_track(MusicController.MusicTrack.MAIN_MENU)
    
    # Load saved settings
    _load_settings()
    
    # Setup visual feedback for main menu buttons
    _setup_button_visuals(host_button)
    _setup_button_visuals(join_button)
    
    # NEW: Setup and check continue button
    if continue_button:
        _setup_button_visuals(continue_button)
        _update_continue_button()
    
    # Connect button signals
    _connect_texture_button(host_button, _on_host_pressed)
    _connect_texture_button(join_button, _on_join_pressed)
    
    # NEW: Connect continue button
    if continue_button:
        _connect_texture_button(continue_button, _on_continue_pressed)
    
    # ... rest of existing connections
```

#### New Functions

```gdscript
## Update Continue button visibility and text based on save data
func _update_continue_button() -> void:
    if not continue_button:
        return
    
    var save_info = LocalSaveManager.get_save_info()
    
    if save_info.exists:
        continue_button.visible = true
        
        # Optional: Update button text with progress
        var zones_completed = save_info.zones_completed
        var total_zones = 5  # Total collectible zones
        
        # You can update a child label or use a different texture
        # For now, we'll just show the button
        print("[MainMenu] Save found: ", zones_completed, "/", total_zones, " zones")
    else:
        continue_button.visible = false
        print("[MainMenu] No save found, hiding Continue button")


## Handle Continue button press
func _on_continue_pressed() -> void:
    print("[MainMenu] Continue pressed - loading saved game...")
    
    var save_info = LocalSaveManager.get_save_info()
    if not save_info.exists:
        push_warning("[MainMenu] Continue pressed but no save exists!")
        return
    
    # Load the save data into GameState
    var save_data = LocalSaveManager.load_game()
    if save_data.is_empty():
        _show_status("Failed to load save file!")
        return
    
    GameState.load_save_data(save_data)
    
    # Determine where to spawn
    var target_zone = save_info.current_zone
    print("[MainMenu] Spawning in zone: ", target_zone)
    
    # For single-player or host mode, go directly to the zone
    # The player becomes the Detective (host) when continuing
    GameState.assign_role(GameState.Role.DETECTIVE)
    
    # Navigate to the saved zone
    _load_zone(target_zone)


## Load a specific zone scene
func _load_zone(zone_id: String) -> void:
    var scene_path = _get_zone_scene_path(zone_id)
    
    if ResourceLoader.exists(scene_path):
        get_tree().change_scene_to_file(scene_path)
    else:
        push_error("[MainMenu] Zone scene not found: " + scene_path)
        _show_status("Error: Zone not found!")


## Get scene path for a zone ID
func _get_zone_scene_path(zone_id: String) -> String:
    match zone_id:
        "forest_hub":
            return "res://scenes/world/hub/ForestHub.tscn"
        "pinas_house":
            return "res://scenes/world/zones/pinasHouse/PinasHouseZone.tscn"
        "backyard_path":
            return "res://scenes/world/zones/backyardPath/BackyardPathZone.tscn"
        "old_well":
            return "res://scenes/world/zones/oldWell/OldWellZone.tscn"
        "storage_hut":
            return "res://scenes/world/zones/storageHut/StorageHutZone.tscn"
        "abandoned_house":
            return "res://scenes/world/zones/abandonedHouse/AbandonedHouseZone.tscn"
        _:
            return "res://scenes/world/hub/ForestHub.tscn"  # Default fallback
```

#### Modified Settings Panel Handling

When settings panel opens, hide the Continue button (following existing pattern):

```gdscript
func _on_settings_pressed() -> void:
    print("[MainMenu] Opening settings panel")
    if settings_panel:
        settings_panel.visible = true
    if settings_overlay:
        settings_overlay.visible = true
    if user_section:
        user_section.visible = false
    if view_user_profile_button:
        view_user_profile_button.visible = true
    if volume_slider:
        volume_slider.value = MusicController.get_volume() * 100
    if volume_value_label:
        volume_value_label.text = str(int(volume_slider.value)) + "%"
    
    # Hide settings button
    if settings_control:
        settings_control.hide_button()
    
    # NEW: Hide Continue button when settings open
    if continue_button:
        continue_button.visible = false


func _on_back_settings_pressed() -> void:
    print("[MainMenu] Closing settings panel")
    if settings_panel:
        settings_panel.visible = false
    if settings_overlay:
        settings_overlay.visible = false
    
    # Show settings button again
    if settings_control:
        settings_control.show_button()
    
    # NEW: Restore Continue button visibility if save exists
    _update_continue_button()
    
    _save_settings()
```

### 3. Alternative: Continue as Sidekick?

If you want to support continuing as either role, you could add a popup:

```gdscript
func _on_continue_pressed() -> void:
    var save_info = LocalSaveManager.get_save_info()
    
    # Show role selection popup
    # "Continue as Detective" / "Continue as Sidekick"
    # Or detect from save data if role was saved
```

**Note:** The current `GameState.get_save_data()` includes `selected_costumes` but not the active role. You may want to add `local_role` to the save data if you want to restore the exact role.

### 4. Edge Cases to Handle

| Edge Case | Handling |
|-----------|----------|
| Save file corrupted | Hide Continue button, show "New Game" only |
| Save from older version | Attempt migration via `LocalSaveManager._migrate_save_data()` |
| All zones completed | Show "Continue (Complete!)" or hide and show "New Game+" |
| Save exists but zone scene missing | Default to Forest Hub |

## Visual Design Suggestions

### Button States

| State | Visual |
|-------|--------|
| Normal | Standard continue button texture |
| Hover | Highlighted/glow effect |
| Pressed | Slight scale down (0.9x) - already implemented |
| Disabled | Grayed out (if save corrupted) |

### Progress Display Options

1. **Minimal:** Just "Continue" text
2. **Progress bar:** Small bar under button showing % complete
3. **Text hint:** "Continue (3/5 zones)" as button text or subtitle
4. **Zone name:** "Continue - Forest Hub" showing current location

## Testing Checklist

- [ ] Continue button hidden when no save exists
- [ ] Continue button visible when save exists
- [ ] Clicking Continue loads correct zone
- [ ] GameState properly restored from save
- [ ] Settings panel hides Continue button
- [ ] Closing settings restores Continue button
- [ ] Continue works after game reset
- [ ] Continue works after nightfall (reset progress)
- [ ] Corrupted save hides Continue button gracefully

## Future Enhancements

1. **Multiple Save Slots:** Support for multiple save files with selection UI
2. **Save Preview:** Show thumbnail/screenshot of saved location
3. **Play Time Display:** Show "Played: 2h 30m" on Continue button
4. **Cloud Save Indicator:** Show cloud icon if save is synced
5. **New Game+:** Special button after completing game once

## Related Files

- `kuwentura/scripts/mainMenu/main_menu.gd` - Main menu logic
- `kuwentura/scenes/mainMenu/MainMenu.tscn` - Main menu scene
- `kuwentura/scripts/systems/local_save_manager.gd` - Save system
- `kuwentura/scripts/systems/game_state.gd` - Game state management
