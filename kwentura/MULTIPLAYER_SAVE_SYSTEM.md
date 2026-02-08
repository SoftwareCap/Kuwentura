# Multiplayer Save/Load System for 2-Player Co-op

> For games like Minecraft and The Forest where the world and player progress must persist across sessions.

---

## Core Concepts

### Types of Data to Save

| Data Type | Owner | Example | Persistence |
|-----------|-------|---------|-------------|
| **World State** | Host | Terrain, buildings, puzzles solved, items placed | Saved with host |
| **Player Progress** | Each Player | Inventory, skills, unlocked zones, stats | Cloud (Firebase) |
| **Session State** | Ephemeral | Current position, active effects, temp buffs | Not saved (or auto-save) |
| **Shared Progress** | Both | Story milestones, unlocked endings | Both players get it |

### Minecraft/The Forest Model

```
Player A (Host)                          Player B (Client)
     |                                         |
     |  [World Save File]                      |  [Character Save]
     |  - Terrain data                         |  - Inventory
     |  - Buildings                            |  - Skills
     |  - Chest contents                       |  - Position (last session)
     |  - Story progress                       |  
     |                                         |
     +------------------+----------------------+
                        |
                 [Cloud Sync]
                 - Firebase Firestore
                 - Both can access world metadata
```

**Key Rule**: 
- Host owns the **World** (world won't exist without them)
- Each player owns their **Character** (can join different worlds)
- **Shared progress** is copied to both players

---

## Architecture Options

### Option A: Host-Owned World (Minecraft Style) ⭐ RECOMMENDED

The host's save contains everything. Client's progress is stored separately.

```
Host Save (Local + Cloud Backup)
├── world_data/
│   ├── terrain.json           # World layout
│   ├── objects.json           # Placed items, buildings
│   ├── game_state.json        # Puzzles solved, zones unlocked
│   └── session.json           # Last played timestamp
├── player_host/
│   ├── inventory.json
│   ├── position.json
│   └── stats.json
└── player_client/
    ├── inventory.json         # Client's last known state
    ├── position.json
    └── user_id.json           # Link to Firebase user

Client Save (Cloud - Firebase)
├── character_data/
│   ├── inventory.json         # Own copy of inventory
│   ├── unlocked_zones.json    # Zones discovered with THIS host
│   └── story_progress.json    # Cutscenes seen
└── world_history/
    ├── world_abc123.json      # Metadata about this world
    └── last_played.json       # To show "Continue" button
```

**Pros**:
- Simple: Host is the source of truth
- Works offline for host
- Client can join multiple different hosts

**Cons**:
- If host deletes save, world is gone
- Client can't continue without original host

### Option B: Cloud-Owned World (Dedicated Server Style)

World is stored in cloud, host is just the current "active session host".

```
Firebase Firestore
├── worlds/
│   └── {world_id}/
│       ├── metadata/
│       │   ├── host_user_id     # Who created it
│       │   ├── created_at
│       │   └── last_played
│       ├── world_data/
│       │   ├── terrain
│       │   ├── objects
│       │   └── game_state
│       └── players/
│           ├── {user_id_1}/     # Host
│           └── {user_id_2}/     # Client
│
└── users/
    └── {user_id}/
        └── worlds_joined/
            └── {world_id}/      # Reference to world
```

**Pros**:
- World persists even if host quits
- Either player can "host" the session
- Better for async play (host not always online)

**Cons**:
- Requires constant cloud connectivity
- More complex sync logic
- Higher Firebase costs (more reads/writes)

### Option C: Hybrid (The Forest Style)

World saves locally but can be "shared" to client if host leaves.

```
Session Active:
  Host owns world → Client plays

Host Disconnects:
  Option 1: Client gets save (becomes new host)
  Option 2: World saved to cloud, either can resume
  Option 3: Game ends, progress saved, wait for host
```

---

## Implementation: Host-Owned World (Option A)

### 1. Data Structure

```gdscript
# game_state.gd - Extended for multiplayer saves
extends Node

# World State (Host Owned)
var world_data: Dictionary = {
    "world_id": "",           # Unique world identifier
    "version": 1,
    "created_at": 0,
    "host_user_id": "",
    "terrain_seed": 0,
    "zones_unlocked": [],
    "puzzles_solved": [],
    "clues_collected": [],
    "objects_placed": [],     # Player-built items
    "story_progress": 0
}

# Player States (Indexed by user_id)
var player_states: Dictionary = {}

# Current Session
var current_host_id: String = ""
var current_client_id: String = ""

func _ready():
    FirebaseAuth.auth_success.connect(_on_auth_success)

func _on_auth_success(user_id: String, token: String):
    # Load this player's character data
    load_player_data(user_id)
```

### 2. Save Flow

```gdscript
# Host initiates save
func save_game():
    if not multiplayer.is_server():
        return
    
    var save_data = {
        "world": world_data,
        "timestamp": Time.get_unix_time_from_system(),
        "players": player_states
    }
    
    # Save locally first (immediate)
    _save_local(save_data)
    
    # Backup to cloud (async)
    _backup_to_cloud(save_data)
    
    # Notify client their progress was saved
    _notify_client_save.rpc_id(int(current_client_id), player_states[current_client_id])

func _save_local(data: Dictionary):
    var file = FileAccess.open("user://saves/world_%s.save" % world_data.world_id, FileAccess.WRITE)
    file.store_var(data)
    file.close()

func _backup_to_cloud(data: Dictionary):
    # Store world metadata in Firebase
    FirebaseFirestore.save_world_data(world_data.world_id, {
        "world_id": world_data.world_id,
        "host_id": world_data.host_user_id,
        "last_saved": data.timestamp,
        "version": world_data.version,
        "has_client": not current_client_id.is_empty()
    })

@rpc("authority", "reliable")
func _notify_client_save(client_data: Dictionary):
    # Client saves their own character data locally
    var user_id = FirebaseAuth.user_id
    var file = FileAccess.open("user://saves/character_%s.save" % user_id, FileAccess.WRITE)
    file.store_var(client_data)
    file.close()
    
    # Also backup to cloud
    FirebaseFirestore.save_character_data(user_id, client_data)
```

### 3. Load Flow

```gdscript
# Host loads world
func load_world(world_id: String) -> bool:
    var file_path = "user://saves/world_%s.save" % world_id
    
    if FileAccess.file_exists(file_path):
        # Load local save
        var file = FileAccess.open(file_path, FileAccess.READ)
        var data = file.get_var()
        file.close()
        
        world_data = data.world
        player_states = data.players
        return true
    else:
        # Try cloud backup
        return await _load_from_cloud(world_id)

# Client joins and requests their data
@rpc("any_peer", "reliable")
func request_player_data(user_id: String):
    if not multiplayer.is_server():
        return
    
    var player_data
    
    if player_states.has(user_id):
        # Returning player - load their saved state
        player_data = player_states[user_id]
    else:
        # New player to this world - create fresh character
        player_data = _create_new_character(user_id)
        player_states[user_id] = player_data
    
    # Send to requesting client
    current_client_id = user_id
    _send_player_data.rpc_id(multiplayer.get_remote_sender_id(), player_data)

@rpc("authority", "reliable")
func _send_player_data(data: Dictionary):
    # Client receives their character data
    apply_player_data(data)
```

### 4. Synchronization During Gameplay

```gdscript
# Auto-save triggers
var last_save_time: float = 0
const AUTO_SAVE_INTERVAL: float = 60.0  # Every minute

func _process(delta):
    if multiplayer.is_server():
        if Time.get_unix_time_from_system() - last_save_time > AUTO_SAVE_INTERVAL:
            auto_save()

# Critical events trigger immediate save
func on_puzzle_solved(puzzle_id: String):
    world_data.puzzles_solved.append(puzzle_id)
    save_game()  # Immediate save for important events

func on_item_collected(item: String, player_id: String):
    player_states[player_id].inventory.append(item)
    # Don't save immediately for items - batch them

# Graceful disconnect handling
func _on_peer_disconnected(peer_id: int):
    # Save before client leaves
    save_game()
    
    # Mark client as offline but keep their data
    player_states[current_client_id]["last_disconnect"] = Time.get_unix_time_from_system()
    player_states[current_client_id]["is_online"] = false
```

---

## Firebase Integration

### World Metadata Schema

```javascript
// Firestore structure
{
  "worlds": {
    "world_abc123": {
      "metadata": {
        "world_id": "world_abc123",
        "host_user_id": "user_xyz789",
        "host_display_name": "DetectiveMike",
        "created_at": 1704067200,
        "last_played": 1706659200,
        "version": 3,
        "game_mode": "story",
        "day_count": 15,
        "story_chapter": 3
      },
      "player_history": {
        "user_abc456": {
          "display_name": "SidekickSam",
          "first_joined": 1704067200,
          "last_played": 1706659200,
          "total_playtime_minutes": 450,
          "character_snapshot": {
            "level": 5,
            "inventory_count": 12
          }
        }
      }
    }
  },
  "users": {
    "user_abc456": {
      "profile": { /* ... */ },
      "worlds_joined": {
        "world_abc123": {
          "world_name": "Mystery Island",
          "host_name": "DetectiveMike",
          "last_played": 1706659200,
          "can_continue": true,
          "save_exists_locally": true
        }
      }
    }
  }
}
```

### Cloud Functions for Server-side Logic

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// When host saves world, notify client
exports.onWorldSaved = functions.firestore
  .document('worlds/{worldId}/saves/{saveId}')
  .onCreate(async (snap, context) => {
    const saveData = snap.data();
    const worldId = context.params.worldId;
    
    // Notify all players in this world
    const worldRef = admin.firestore().doc(`worlds/${worldId}`);
    const world = await worldRef.get();
    
    for (const [userId, playerData] of Object.entries(world.data().players)) {
      if (userId !== saveData.host_id) {
        // Send FCM notification to client
        await admin.messaging().sendToTopic(`user_${userId}`, {
          notification: {
            title: 'Game Saved',
            body: 'Your progress has been saved!'
          }
        });
      }
    }
  });

// Handle host migration (if host quits, can client take over?)
exports.requestHostMigration = functions.https.onCall(async (data, context) => {
  const { worldId, requesterId } = data;
  
  const worldRef = admin.firestore().doc(`worlds/${worldId}`);
  const world = await worldRef.get();
  
  if (!world.exists) {
    throw new functions.https.HttpsError('not-found', 'World not found');
  }
  
  // Check if original host has been offline for > 24 hours
  const lastHostOnline = world.data().metadata.last_host_online;
  const hoursSinceHost = (Date.now() / 1000 - lastHostOnline) / 3600;
  
  if (hoursSinceHost > 24) {
    // Allow migration
    await worldRef.update({
      'metadata.host_user_id': requesterId,
      'metadata.migrated_from': world.data().metadata.host_user_id,
      'metadata.migrated_at': Date.now() / 1000
    });
    return { success: true, message: 'Host migrated' };
  }
  
  return { success: false, message: 'Original host still active' };
});
```

---

## UI/UX Considerations

### Host Menu

```
+----------------------------------+
|  DETECTIVE LOBBY                 |
+----------------------------------+
|                                  |
|  [Continue Story]                |
  - Mystery Island (Day 15)        |
  - Last played: 2 days ago        |
                                  |
|  [New Story]                     |
|  [Load Game]                     |
|    - World 1 (Day 8)             |
|    - World 2 (Day 3)             |
|                                  |
|  Invite Code: ABC123             |
|  [Copy] [Regenerate]             |
+----------------------------------+
```

### Client Menu

```
+----------------------------------+
|  SIDEKICK MENU                   |
+----------------------------------+
|                                  |
|  [Continue Adventure]            |
  - With DetectiveMike             |
  - Mystery Island, Chapter 3      |
  - Last played: 2 days ago        |
                                  |
|  [Join New Game]                 |
|    Enter Code: [________]        |
|                                  |
|  [Your Worlds]                   |
|    - 3 worlds played             |
|    - Total playtime: 12 hours    |
+----------------------------------+
```

### Join Flow with Save Check

```gdscript
# Client joining
func join_world(room_code: String):
    # 1. Look up world
    var world_meta = await FirebaseFirestore.get_world_metadata(room_code)
    
    if not world_meta:
        show_error("World not found")
        return
    
    # 2. Check if player has existing character in this world
    var existing_character = await FirebaseFirestore.get_character_in_world(
        FirebaseAuth.user_id, 
        world_meta.world_id
    )
    
    if existing_character:
        # Show "Continue with existing character?" dialog
        var dialog = ConfirmationDialog.new()
        dialog.title = "Existing Character Found"
        dialog.dialog_text = "You have a character in this world (Level %d). Continue?" % existing_character.level
        dialog.ok_button_text = "Continue"
        dialog.cancel_button_text = "Start Fresh"
        dialog.confirmed.connect(func(): _join_with_character(existing_character))
        dialog.canceled.connect(func(): _join_fresh())
        add_child(dialog)
        dialog.popup_centered()
    else:
        _join_fresh()
```

---

## Handling Edge Cases

### 1. Version Mismatch

```gdscript
const SAVE_VERSION: int = 3

func verify_save_compatibility(save_data: Dictionary) -> bool:
    var save_version = save_data.get("version", 1)
    
    if save_version > SAVE_VERSION:
        # Save is from newer game version
        show_error("Save is from a newer game version. Please update.")
        return false
    
    if save_version < SAVE_VERSION:
        # Migrate old save
        save_data = migrate_save(save_data, save_version)
    
    return true

func migrate_save(data: Dictionary, from_version: int) -> Dictionary:
    match from_version:
        1:
            # Add new fields
            data.player_stats = { "strength": 1, "intelligence": 1 }
            data.version = 2
            return migrate_save(data, 2)
        2:
            # Another migration
            data.achievements = []
            data.version = 3
            return data
    return data
```

### 2. Desync Recovery

```gdscript
# Client detects they're out of sync with host
@rpc("authority", "reliable")
func verify_state(checksum: int, tick: int):
    var local_checksum = calculate_world_checksum()
    
    if local_checksum != checksum:
        push_warning("State mismatch at tick %d! Requesting full sync..." % tick)
        request_full_sync.rpc_id(1)

@rpc("any_peer", "reliable")
func request_full_sync():
    if not multiplayer.is_server():
        return
    
    var sender = multiplayer.get_remote_sender_id()
    # Send full world state
    _send_full_state.rpc_id(sender, world_data, player_states)
```

### 3. Host Migration (Advanced)

```gdscript
# If host disconnects unexpectedly, can client take over?
func handle_host_disconnect():
    # Option 1: Try to migrate host
    var result = await FirebaseFunctions.request_host_migration(world_data.world_id)
    
    if result.success:
        # Become new host
        become_host()
    else:
        # Option 2: Save & Exit
        save_emergency_backup()
        show_message("Host disconnected. Your progress is saved.")
        return_to_menu()
```

---

## Recommended Implementation Order

### Phase 1: Basic Local Saves (Week 1)
- [ ] Host saves world to local file
- [ ] Client saves character to local file
- [ ] Manual save button
- [ ] Load world from file

### Phase 2: Cloud Backup (Week 2)
- [ ] Backup world metadata to Firebase
- [ ] Backup character data to Firebase
- [ ] "Continue" button in main menu
- [ ] List of joined worlds

### Phase 3: Auto-Save & Resilience (Week 3)
- [ ] Auto-save every 60 seconds
- [ ] Save on critical events (puzzle solved, item found)
- [ ] Graceful disconnect handling
- [ ] Save corruption detection

### Phase 4: Advanced Features (Week 4+)
- [ ] Multiple save slots per world
- [ ] Save migration between versions
- [ ] Host migration (optional)
- [ ] Save sharing (invite friend to your world)

---

## Integration with Your Existing Code

Your current `network_manager.gd` already has the foundation. Here's what to add:

```gdscript
# Add to network_manager.gd

# Called when host starts game
func on_host_start():
    var world_id = generate_world_id()
    GameState.create_new_world(world_id, FirebaseAuth.user_id)
    GameState.save_game()

# Called when client joins successfully
func _on_peer_connected(peer_id: int):
    if multiplayer.is_server():
        # Load client's existing data or create new
        GameState.request_player_data.rpc_id(peer_id, get_user_id_from_peer(peer_id))
        
        # Send current world state
        _sync_game_state.rpc_id(peer_id, GameState.get_save_data())

# Called periodically or on important events
func on_game_event(event_type: String, data: Dictionary):
    match event_type:
        "puzzle_solved", "clue_found", "zone_unlocked":
            GameState.save_game()  # Immediate save
        "item_moved", "player_moved":
            # Batch these for auto-save
            pass
```

---

## Summary

| Feature | Host Responsibility | Client Responsibility | Cloud (Firebase) |
|---------|---------------------|----------------------|------------------|
| **World Data** | Owns & saves locally | Receives snapshot | Metadata only |
| **Character Data** | Tracks during session | Saves own copy | Backup & cross-device |
| **Shared Progress** | Authority to update | Receives updates | Both have copy |
| **Session State** | Manages | Follows | None |

**Golden Rules**:
1. **Host is the source of truth** for the world
2. **Each player owns their character** (stored in Firebase)
3. **Save early, save often** - auto-save every minute
4. **Cloud is backup** - local saves are primary for performance
