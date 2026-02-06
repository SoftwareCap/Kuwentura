# Kwentura Network Integration Guide

> How to use the NetworkManager in your Godot scenes

---

## Quick Start

### 1. Autoload Setup (Already done in project.godot)

Your `project.godot` already has:
```ini
[autoload]
NetworkManager="*res://scripts/systems/network_manager.gd"
```

### 2. Connect to Signals

In your main menu or game scene:

```gdscript
extends Control  # or Node

func _ready():
    # Connection events
    NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
    NetworkManager.session_started.connect(_on_session_started)
    NetworkManager.game_started.connect(_on_game_started)
    NetworkManager.game_paused.connect(_on_game_paused)
    NetworkManager.game_resumed.connect(_on_game_resumed)
    NetworkManager.partner_connected.connect(_on_partner_connected)
    NetworkManager.partner_disconnected.connect(_on_partner_disconnected)
    
    # Game events
    NetworkManager.action_result_received.connect(_on_action_result)
    NetworkManager.puzzle_result_received.connect(_on_puzzle_result)
    NetworkManager.error_received.connect(_on_error)

func _on_connection_state_changed(new_state, old_state):
    print("State changed from ", old_state, " to ", new_state)

func _on_session_started(world_data):
    print("Session started! World: ", world_data.world_progress.story_chapter)

func _on_game_started(checkpoint):
    print("Game started at checkpoint: ", checkpoint)
    get_tree().change_scene_to_file("res://scenes/world/zones/" + checkpoint + ".tscn")

func _on_game_paused(reason):
    show_pause_screen("Partner disconnected!")

func _on_game_resumed():
    hide_pause_screen()

func _on_partner_connected(player_data):
    print("Partner connected: ", player_data.display_name)

func _on_partner_disconnected(player_data):
    print("Partner disconnected!")

func _on_action_result(result):
    print("Action result: ", result.result)
    if result.outcome:
        handle_outcome(result.outcome)

func _on_puzzle_result(result):
    if result.status == "solved":
        show_puzzle_solved_ui(result)
    else:
        show_puzzle_failed_ui(result)

func _on_error(error):
    push_error("Network error: ", error.message)
    if error.fatal:
        show_error_dialog(error.message)
```

---

## Host Flow (Detective)

### Main Menu - Create World

```gdscript
extends Control

@onready var world_name_input: LineEdit = $WorldNameInput
@onready var create_button: Button = $CreateButton
@onready var status_label: Label = $StatusLabel

func _ready():
    create_button.pressed.connect(_on_create_pressed)

func _on_create_pressed():
    create_button.disabled = true
    status_label.text = "Creating world..."
    
    var result = await NetworkManager.create_and_start_world(world_name_input.text)
    
    if result.has("error"):
        status_label.text = "Error: " + result.error
        create_button.disabled = false
        return
    
    # Show invite code
    status_label.text = "Invite code: " + result.invite_code
    
    # Wait for partner to join...
    await NetworkManager.partner_joined
    
    # Partner joined! Now start the game
    status_label.text = "Partner joined! Starting..."
    
    var start_result = await NetworkManager.start_session()
    
    if start_result:
        # Game will start via game_started signal
        pass
    else:
        status_label.text = "Failed to start session"
```

### In-Game (Host)

```gdscript
extends Node2D

func _ready():
    # Only process if we're the detective
    if NetworkManager.get_my_role() != "detective":
        return
    
    # Host-specific logic
    setup_host_authority()

func setup_host_authority():
    # Host can trigger story events
    pass
```

---

## Client Flow (Sidekick)

### Main Menu - Join World

```gdscript
extends Control

@onready var code_input: LineEdit = $CodeInput
@onready var join_button: Button = $JoinButton
@onready var status_label: Label = $StatusLabel

func _ready():
    join_button.pressed.connect(_on_join_pressed)

func _on_join_pressed():
    join_button.disabled = true
    status_label.text = "Joining..."
    
    var result = await NetworkManager.join_world(code_input.text)
    
    if result.has("error"):
        status_label.text = "Error: " + result.error
        join_button.disabled = false
        return
    
    status_label.text = "Joined! Waiting for detective to start..."
    
    # Wait for game to start (detective clicks start)
    await NetworkManager.game_started
    
    # Game started!
```

### In-Game (Sidekick)

```gdscript
extends Node2D

func _ready():
    # Check role
    if NetworkManager.get_my_role() != "sidekick":
        return
    
    # Sidekick-specific setup
    setup_sidekick_abilities()

func setup_sidekick_abilities():
    # Sidekick has different UI or abilities
    pass
```

---

## Player Controller

```gdscript
extends CharacterBody2D

@export var speed: float = 200.0
@export var sprint_speed: float = 400.0

var _is_sprinting: bool = false
var _last_input: Vector2 = Vector2.ZERO

func _physics_process(delta):
    # Only send input if we're playing and controllable
    if not NetworkManager.is_playing():
        return
    
    if not NetworkManager.is_player_controllable():
        return
    
    # Get input
    var input_dir = Input.get_vector("left", "right", "up", "down")
    var sprinting = Input.is_action_pressed("sprint")
    var crouching = Input.is_action_pressed("crouch")
    
    # Send to server (60Hz rate limiting inside NetworkManager)
    if input_dir != _last_input or sprinting != _is_sprinting:
        NetworkManager.send_move_input(input_dir, sprinting, crouching)
        _last_input = input_dir
        _is_sprinting = sprinting
    
    # Visual-only: Interpolate to received position
    var received_pos = NetworkManager.get_interpolated_position(NetworkManager._my_player_id)
    if received_pos != Vector2.ZERO:
        position = position.lerp(received_pos, 0.3)

func _input(event):
    if not NetworkManager.is_playing():
        return
    
    # Interaction
    if event.is_action_pressed("interact"):
        var target = get_target_under_cursor()
        NetworkManager.send_action("interact", target.id, target.type)
    
    # Use item
    if event.is_action_pressed("use_item"):
        var selected_item = get_selected_item()
        NetworkManager.send_action("use_item", "", "", selected_item)
```

---

## Remote Player (Partner)

```gdscript
extends CharacterBody2D

@export var partner_role: String = "detective"  # or "sidekick"

var _target_position: Vector2 = Vector2.ZERO
var _target_velocity: Vector2 = Vector2.ZERO

func _ready():
    NetworkManager.player_state_received.connect(_on_player_state_received)

func _on_player_state_received(player_id: String, state: Dictionary):
    # Check if this is our partner
    var partner_status = NetworkManager.get_partner_status()
    if player_id != partner_status.player_id:
        return
    
    _target_position = state.position
    _target_velocity = state.velocity
    
    # Update visual facing
    update_facing(state.facing)
    update_animation(state.animation)

func _physics_process(delta):
    # Interpolate to target position
    if _target_position != Vector2.ZERO:
        position = position.lerp(_target_position, 0.3)

func update_facing(facing: String):
    match facing:
        "left": $Sprite.flip_h = true
        "right": $Sprite.flip_h = false
        "up": $Sprite.rotation = -90
        "down": $Sprite.rotation = 90

func update_animation(anim: String):
    $AnimationPlayer.play(anim)
```

---

## Puzzle Integration

```gdscript
extends Control

@export var puzzle_id: String = "pin_pad_cabinet"

var _start_time: int = 0
var _attempt_count: int = 0

func _ready():
    NetworkManager.puzzle_result_received.connect(_on_puzzle_result)
    _start_time = Time.get_ticks_msec()

func submit_solution(solution: Array):
    _attempt_count += 1
    
    var attempt_time = Time.get_ticks_msec() - _start_time
    
    NetworkManager.submit_puzzle(puzzle_id, solution, attempt_time)
    
    show_submitting_ui()

func _on_puzzle_result(result: Dictionary):
    if result.puzzle_id != puzzle_id:
        return
    
    match result.status:
        "solved":
            hide()
            show_success_animation()
            
            # Apply rewards if needed
            if result.rewards:
                for zone in result.rewards.zones_unlocked:
                    unlock_zone(zone)
        
        "failed":
            show_failure_message(result.hint)
            
        "hint_requested":
            show_hint(result.hint)
```

---

## Pause Menu (On Disconnect)

```gdscript
extends CanvasLayer

@onready var status_label: Label = $Panel/StatusLabel
@onready var wait_button: Button = $Panel/WaitButton
@onready var exit_button: Button = $Panel/ExitButton

func _ready():
    hide()
    NetworkManager.game_paused.connect(_on_game_paused)
    NetworkManager.game_resumed.connect(_on_game_resumed)
    
    wait_button.pressed.connect(_on_wait_pressed)
    exit_button.pressed.connect(_on_exit_pressed)

func _on_game_paused(reason: String):
    show()
    status_label.text = "Partner disconnected!\nWaiting for reconnection..."
    get_tree().paused = true

func _on_game_resumed():
    hide()
    get_tree().paused = false

func _on_wait_pressed():
    status_label.text = "Waiting..."
    # Just wait, the signal will handle reconnection

func _on_exit_pressed():
    NetworkManager.disconnect_from_session()
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

---

## Continue Game Flow

```gdscript
extends Control

@onready var worlds_list: VBoxContainer = $WorldsList

func _ready():
    load_worlds()

func load_worlds():
    # Get worlds from NetworkManager (cached from Firebase)
    var worlds = await _fetch_worlds()
    
    for world in worlds:
        var button = Button.new()
        button.text = world.name + " (Chapter " + str(world.progress.story_chapter) + ")"
        
        if world.partner_online:
            button.text += " [Online]"
        else:
            button.text += " [Offline]"
        
        button.pressed.connect(func(): _continue_world(world.world_id))
        worlds_list.add_child(button)

func _continue_world(world_id: String):
    var result = await NetworkManager.continue_world(world_id)
    
    if result.has("error"):
        show_error(result.error)
        return
    
    # If partner is offline, show dialog
    if not result.partner_online:
        var dialog = ConfirmationDialog.new()
        dialog.title = "Partner Offline"
        dialog.dialog_text = "Your partner is currently offline. Send them a notification?"
        dialog.confirmed.connect(func(): _send_invite(result.partner_id))
        add_child(dialog)
        dialog.popup_centered()

func _send_invite(partner_id: String):
    # Send push notification via Firebase
    pass

func _fetch_worlds() -> Array:
    # This would come from Firebase/Firestore
    # For now, return placeholder
    return []
```

---

## Error Handling

```gdscript
extends Node

func _ready():
    NetworkManager.error_received.connect(_on_network_error)

func _on_network_error(error: Dictionary):
    match error.code:
        "OUT_OF_RANGE":
            show_toast("Too far away!")
        
        "MISSING_ITEM":
            show_toast("You don't have that item")
        
        "PUZZLE_ALREADY_SOLVED":
            show_toast("This puzzle is already solved")
        
        "RATE_LIMITED":
            show_toast("Slow down!")
        
        "RECONNECT_FAILED":
            show_error_dialog("Connection lost. Returning to menu.")
            await get_tree().create_timer(2.0).timeout
            get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
        
        "VERSION_MISMATCH":
            show_error_dialog("Game version outdated. Please update.")
        
        _:
            show_toast("Error: " + error.message)

func show_toast(message: String):
    # Show temporary notification
    pass

func show_error_dialog(message: String):
    # Show modal error dialog
    pass
```

---

## Testing Locally

### 1. Start Server

```bash
cd server
npm run dev
```

### 2. Run Two Game Instances

In Godot:
- Run Project (F5) - This will be Detective
- Run Project again with different user (use Firebase Auth anonymous with different IDs)

### 3. Test Flow

1. Instance A: Create world → Copy invite code
2. Instance B: Join with code
3. Instance A: Start game
4. Both should spawn in game
5. Test: Move around, interact, disconnect one, reconnect

---

## Debug Tools

Add to your scene for debugging:

```gdscript
extends Label

func _process(delta):
    text = """
    State: %s
    Role: %s
    Latency: %d ms
    Sequence: %d
    """ % [
        NetworkManager.get_state(),
        NetworkManager.get_my_role(),
        NetworkManager.get_current_latency_ms(),
        NetworkManager._sequence_number
    ]
```
