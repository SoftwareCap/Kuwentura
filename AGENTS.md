# Kwentura - AI Agent Documentation

## Project Overview

**Kwentura** is a 2D detective mobile game built with Godot 4.5 featuring 2-player cooperative multiplayer. Players take on asymmetric roles:
- **Detective (Host)**: Visual gameplay, explores environments, finds clues
- **Sidekick**: Audio-based navigation, assists the detective through sound cues

The game follows a Philippine folklore-inspired narrative where players investigate the mystery of "Pina" across multiple zones, collecting clues to unlock the climax sequence.

## Technology Stack

### Client (Game)
- **Engine**: Godot 4.5 (Forward Plus renderer)
- **Language**: GDScript
- **Resolution**: 1920x1080 (canvas_items stretch mode)
- **Platform**: Mobile-first 2D game
- **Multiplayer**: Built-in ENetMultiplayerPeer (LAN Listen Server)
- **Cloud Save**: Firebase REST API (optional, for cross-device sync)

### Cloud Save (Optional)
- **Service**: Firebase (Firestore + Anonymous Auth)
- **Integration**: Direct REST API via HTTPRequest node
- **Purpose**: Cross-device save sync, progress backup
- **Note**: Works independently of multiplayer - pure client-side cloud storage

### Server
- **Architecture**: No dedicated server required
- **Model**: Listen Server (peer-hosted)
- **Network**: UDP (ENet) for game data, UDP Broadcast for discovery
- **Authentication**: None required for LAN play

## Project Structure

```
Kwentura/
├── kwentura/                   # Godot game project
│   ├── project.godot          # Godot project configuration
│   ├── scripts/               # GDScript source files
│   │   ├── systems/           # Core systems (autoloaded)
│   │   │   ├── firebase_auth.gd      # (Optional) Anonymous auth
│   │   │   ├── firebase_firestore.gd # (Optional) Cloud save
│   │   │   ├── firebase_manager.gd   # Save/load coordinator
│   │   │   ├── game_state.gd         # Game progression state
│   │   │   ├── network_manager.gd    # LAN multiplayer manager
│   │   │   └── puzzle_manager.gd     # Puzzle system
│   │   ├── mainMenu/          # Menu scenes logic
│   │   ├── players/           # Player controllers
│   │   ├── world/             # Game world scripts
│   │   │   ├── zones/         # Zone-specific logic
│   │   │   └── climax/        # End-game sequences
│   │   ├── puzzles/           # Puzzle implementations
│   │   └── cutscenes/         # Cutscene scripts
│   ├── scenes/                # Godot scene files (.tscn)
│   │   ├── mainMenu/          # Menu scenes
│   │   ├── players/           # Player scene files
│   │   ├── world/             # World scenes
│   │   └── ui/                # UI components
│   └── assets/                # Game assets
│       ├── sprites/
│       ├── audio/
│       ├── backgrounds/
│       ├── buttons/
│       └── fonts/
└── README.md
```

## Autoloaded Singletons (Godot)

The following nodes are autoloaded in `project.godot`:

| Singleton | Purpose | Optional |
|-----------|---------|----------|
| `FirebaseAuth` | Anonymous Firebase authentication | ✅ Yes |
| `FirebaseManager` | Save/load coordination (local or cloud) | ✅ Yes |
| `FirebaseFirestore` | Firestore database operations | ✅ Yes |
| `GameState` | Game progression, clues, zones status | ❌ No |
| `NetworkManager` | LAN multiplayer, host/join, sync | ❌ No |
| `PuzzleManager` | Puzzle state management | ❌ No |

**Note**: Firebase singletons gracefully fail if no internet connection. Game works 100% offline without them.

## Build and Run Commands

### Prerequisites
- Godot 4.5+ (for client)
- No server setup required!

### Running the Game

1. Open `kwentura/project.godot` in Godot 4.5+ editor
2. Press F5 (Play) to run
3. For multiplayer testing:
   - **Player 1**: Click "Host Game" (becomes Detective)
   - **Player 2**: Click "Join Game" and enter the room code or use LAN discovery

### LAN Multiplayer Setup

Both devices must be on the same Wi-Fi network:

1. **Host (Detective)**:
   - Select "Host Game" from main menu
   - Share the 6-character room code with partner
   - Wait for Sidekick to connect
   - Click "Start Game" when ready

2. **Client (Sidekick)**:
   - Select "Join Game" from main menu
   - Enter the room code from host, OR
   - Use "Find LAN Games" to auto-discover hosts
   - Wait for host to start the game

## Code Style Guidelines

### GDScript (Godot Client)
- Use **snake_case** for variables, functions, and file names
- Use **PascalCase** for class names and node names
- Use **UPPER_SNAKE_CASE** for constants and enums
- Indent with tabs (Godot convention)
- Signal names use **snake_case**
- Private methods prefixed with underscore: `_private_method()`
- Type hints encouraged: `func my_func(param: String) -> int:`
- Comments use `#` with space after
- Class documentation comments use `##` (Godot 4.x style)

Example:
```gdscript
## Brief description of what this does
func _process(delta: float) -> void:
    var local_position: Vector2 = global_position - _parent_position
    _velocity.x = lerp(_velocity.x, 0.0, FRICTION * delta)
```

## Key Architecture Concepts

### Two-System Architecture

Kwentura uses **two independent systems** that work together:

```
┌─────────────────────────────────────────────────────────────┐
│                      KWENTURA CLIENT                        │
│  ┌─────────────────────┐    ┌──────────────────────────┐   │
│  │   LAN MULTIPLAYER   │    │      CLOUD SAVE          │   │
│  │   (NetworkManager)  │    │   (FirebaseManager)      │   │
│  ├─────────────────────┤    ├──────────────────────────┤   │
│  │ • ENet UDP (LAN)    │    │ • HTTP REST API          │   │
│  │ • Port 17777/17778  │    │ • Firebase Auth          │   │
│  │ • No internet req.  │    │ • Firestore Database     │   │
│  │ • Real-time sync    │    │ • Optional, async        │   │
│  └─────────────────────┘    └──────────────────────────┘   │
│            │                           │                    │
│            ▼                           ▼                    │
│      Partner (2P)                Firebase Cloud             │
│   Same Wi-Fi only               Internet required           │
└─────────────────────────────────────────────────────────────┘
```

**Key Point**: Multiplayer works entirely offline. Firebase only activates when:
- Saving progress to cloud
- Loading progress from cloud  
- User wants cross-device sync

### Network Architecture: Listen Server (LAN)

The game uses a **listen server** model ideal for 2-player co-op:

```
┌─────────────────┐                      ┌─────────────────┐
│   DETECTIVE     │ ←──── Host/Server ─→ │    SIDEKICK     │
│   (Player 1)    │    UDP/ENet (LAN)    │   (Player 2)    │
│                 │                      │                 │
│ • Authority     │                      │ • Pure Client   │
│ • Validates     │                      │ • Sends inputs  │
│   puzzles       │                      │ • Receives sync │
│ • Syncs state   │                      │                 │
└─────────────────┘                      └─────────────────┘
```

**Why this architecture?**
- ✅ Zero server infrastructure needed
- ✅ Works offline on local Wi-Fi
- ✅ Low latency (direct LAN connection)
- ✅ Simple to develop and debug
- ✅ Perfect for thesis/demo/classroom settings

**Roles:**
- **Detective** = Host (ID: 1) - Has authority over game state
- **Sidekick** = Client (ID: >1) - Sends inputs, receives state updates

### LAN Discovery

Automatic host discovery using UDP broadcast:
- Host broadcasts presence every 1 second on port 17778
- Clients listen for broadcasts and display available games
- No IP address typing required

### Connection Flow

```
HOST (Detective)                    CLIENT (Sidekick)
     │                                     │
     │  1. Host Game                       │
     │  2. Generate invite code            │
     │  3. Start broadcast discovery  ───→ │
     │                                     │  4. Discover hosts
     │ ←─────────────────────────────────  │  5. Connect via ENet
     │  6. Accept connection               │
     │  7. Assign role (SIDEKICK)   ───→   │
     │                                     │  8. Ready to play
     │  9. Start Game (when ready)  ───→   │
     │                                     │  10. Begin gameplay!
```

### Game State Structure

```gdscript
# Core progression tracking
var current_zone: String = "forest_hub"
var zones_status: Dictionary = {
    "pinas_house": ZoneStatus.AVAILABLE,
    "backyard_path": ZoneStatus.AVAILABLE,
    "old_well": ZoneStatus.AVAILABLE,
    "storage_hut": ZoneStatus.AVAILABLE,
    "abandoned_house": ZoneStatus.AVAILABLE
}

# Clues system
var collected_clues: Dictionary = {
    "pinas_house": {
        "collected": false,
        "item": "Ladle",
        "text": "We use our eyes to find things..."
    },
    # ... more clues
}
```

### RPC (Remote Procedure Call) Usage

Key RPC functions for multiplayer sync:

```gdscript
# Host → Client: Assign role after connection
@rpc("authority", "reliable")
func _assign_role_rpc(role: Role, invite_code: String, session_seed: int)

# Host → Client: Start game
@rpc("authority", "reliable")
func _game_started_rpc(checkpoint: String)

# Client → Host: Submit puzzle solution
@rpc("any_peer", "reliable")
func submit_puzzle_solution(puzzle_id: String, solution: Variant, attempt_time_ms: int)

# Bidirectional: Sync player position (unreliable for speed)
@rpc("any_peer", "unreliable_ordered")
func sync_player_state(position: Vector2, velocity: Vector2, facing: String, animation_state: String)
```

## Testing

### Manual Testing Checklist
- [ ] Host game generates invite code
- [ ] LAN discovery finds hosts automatically
- [ ] Sidekick can join with invite code
- [ ] Game starts when host clicks "Start"
- [ ] Player movement syncs between clients
- [ ] Puzzle attempts validate correctly (host authority)
- [ ] Clue collection syncs to both players
- [ ] Disconnect handling works (pause game)
- [ ] Reconnection possible if partner drops

### Testing Multiplayer Locally

To test on a single computer:
1. Export the game as executable
2. Run one instance from Godot editor (Host)
3. Run second instance from exported executable (Join)
4. Use "127.0.0.1" as IP to connect to yourself

## Security Considerations

### LAN-Only Design
- Game only works on local network by default
- No external server = no server to hack
- Direct peer-to-peer UDP communication

### Host Authority
- All puzzle validation happens on host (Detective)
- Clients cannot cheat by modifying game state
- Host state is the "source of truth"

## Deployment Notes

### Godot Export
- Export presets configured in `export_presets.cfg`
- Mobile-focused (portrait/landscape depending on scene)
- ENet multiplayer works on all platforms (Windows, Mac, Linux, Android, iOS)

### Network Requirements
- Both devices on same Wi-Fi network
- Port 17777 (UDP) open for game data
- Port 17778 (UDP) open for discovery broadcast
- Most home routers allow this by default

## Common Development Tasks

### Adding a New Zone
1. Create scene in `scenes/world/zones/`
2. Add zone script in `scripts/world/zones/`
3. Update `GameState.zones_status` with new zone
4. Add clue entry in `GameState.collected_clues`

### Adding a Puzzle
1. Create puzzle scene in `scenes/puzzles/`
2. Implement logic in `scripts/puzzles/`
3. Connect to `PuzzleManager` for state tracking
4. Call `NetworkManager.submit_puzzle()` for validation (host authority)

### Debugging Network Issues
Enable verbose logging in NetworkManager:
```gdscript
# In network_manager.gd, look for print statements
# Add more debug prints as needed
print("[Network] Debug: ", variable)
```

## File Naming Conventions

- GDScript: `snake_case.gd`
- Scene files: `PascalCase.tscn`
- Assets: descriptive with suffix (e.g., `button_start.png`)
- Documentation: `UPPERCASE.md` for important docs

## Dependencies

### Godot Project
- **Core**: No external dependencies - uses built-in Godot 4.5 only
- **Multiplayer**: ENetMultiplayerPeer + PacketPeerUDP (built-in)
- **Cloud Save**: Firebase REST API via HTTPRequest (built-in, optional)

### Firebase Setup (Optional)
If you want cloud save functionality:
1. Create Firebase project at https://console.firebase.google.com
2. Enable Firestore Database and Anonymous Authentication
3. Replace `API_KEY` and `PROJECT_ID` in:
   - `firebase_auth.gd`
   - `firebase_manager.gd`
   - `firebase_firestore.gd`
4. Set up Firestore security rules for anonymous users

### Network Requirements
**For LAN Multiplayer (Required)**:
- Both devices on same Wi-Fi network
- Port 17777 (UDP) open for game data
- Port 17778 (UDP) open for discovery broadcast

**For Cloud Save (Optional)**:
- Internet connection
- Firebase project configured
