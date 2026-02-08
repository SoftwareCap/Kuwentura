# WebSocket Protocol Specification

> Client-Server Interface for Kwentura 2-Player Co-op

---

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     CONNECTION MODEL                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   CLIENT (Godot)              SERVER (Node.js/WebSocket)       │
│        │                              │                         │
│        │  1. HTTP POST /worlds/:id    │                         │
│        │     /start                   │                         │
│        │◄────────────────────────────►│                         │
│        │     Returns: ws_url          │                         │
│        │                              │                         │
│        │  2. WebSocket Connect        │                         │
│        │     wss://server/ws?token=   │                         │
│        │◄════════════════════════════►│                         │
│        │                              │                         │
│        │  3. Binary/Text Protocol     │                         │
│        │     (defined below)          │                         │
│        │◄────────────────────────────►│                         │
│        │                              │                         │
└─────────────────────────────────────────────────────────────────┘
```

**Key Principles:**
- All game logic is **server-authoritative**
- Client sends **intentions** (inputs/actions), server sends **results** (state changes)
- Connection is **persistent** during gameplay
- **Binary format** for frequent updates (position), **JSON** for events

---

## Connection Lifecycle

### 1. Handshake (HTTP)

```http
# Request
POST /worlds/w_abc123/start
Authorization: Bearer <firebase_jwt_token>

# Response 200
{
  "session_id": "s_xyz789",
  "ws_url": "wss://api.kwentura.game/ws?session=s_xyz789",
  "checkpoint": "forest_hub",
  "world_progress": {
    "story_chapter": 3,
    "zones_unlocked": ["forest", "cave"],
    "puzzles_solved": ["p1", "p2"]
  }
}

# Response 400 - Partner not ready
{
  "error": "PARTNER_NOT_CONNECTED",
  "message": "Sidekick has not joined yet"
}

# Response 403 - Not authorized
{
  "error": "NOT_DETECTIVE",
  "message": "Only detective can start the session"
}
```

### 2. WebSocket Connection

```javascript
// Client connects
ws = new WebSocket('wss://api.kwentura.game/ws?session=s_xyz789&token=<jwt>');

// Server validates token and session
// Server checks if both players are present

// On successful connection, server sends initial state
```

### 3. Message Format

All WebSocket messages use this envelope:

```typescript
interface Message {
  type: string;        // Message type (see below)
  timestamp: number;   // Server timestamp (ms since epoch)
  seq: number;         // Sequence number for ordering
  data: any;          // Payload (type-specific)
}
```

**Serialization:**
- **JSON** for event messages (reliable, ordered)
- **Binary** for input/state sync (compact, frequent)

---

## Message Types

### Client → Server

| Type | Direction | Frequency | Reliability | Description |
|------|-----------|-----------|-------------|-------------|
| `input_move` | C→S | 60Hz | Unreliable | Movement input vector |
| `input_action` | C→S | On demand | Reliable | Interaction request |
| `puzzle_attempt` | C→S | On demand | Reliable | Submit puzzle solution |
| `dialogue_choice` | C→S | On demand | Reliable | Select dialogue option |
| `ping` | C→S | 1Hz | Unreliable | Connection health check |
| `ready` | C→S | Once | Reliable | Client loaded and ready |
| `request_sync` | C→S | On demand | Reliable | Request full state resync |

### Server → Client

| Type | Direction | Frequency | Reliability | Description |
|------|-----------|-----------|-------------|-------------|
| `session_start` | S→C | Once | Reliable | Initial world state |
| `state_player` | S→C | 20Hz | Unreliable | Player position/velocity |
| `state_world` | S→C | 1Hz | Unreliable | World state snapshot |
| `event_action` | S→C | On demand | Reliable | Action result |
| `event_puzzle` | S→C | On demand | Reliable | Puzzle solved/failed |
| `event_story` | S→C | On demand | Reliable | Story progression |
| `event_inventory` | S→C | On demand | Reliable | Inventory change |
| `partner_status` | S→C | On change | Reliable | Connect/disconnect |
| `error` | S→C | On demand | Reliable | Error message |
| `pong` | S→C | 1Hz | Unreliable | Ping response |
| `force_sync` | S→C | On demand | Reliable | Force client state update |

---

## Detailed Message Specifications

### 1. Input Messages (Client → Server)

#### `input_move` (Binary - 8 bytes)

High-frequency movement input. Sent every frame (~60Hz).

```
Binary Format (little-endian):
┌─────────┬─────────┬─────────┬─────────┐
│  Type   │   X     │   Y     │  Flags  │
│  (1B)   │  (4B)   │  (4B)   │  (1B)   │
│  0x01   │  float  │  float  │  bits   │
└─────────┴─────────┴─────────┴─────────┘
Total: 10 bytes

Flags:
  Bit 0: Sprinting (1) / Walking (0)
  Bit 1: Crouching
  Bit 2-7: Reserved

Example:
  Type: 0x01
  X: 0.5 (right)
  Y: -0.3 (down)
  Flags: 0x01 (sprinting)
```

JSON equivalent (for debugging):
```json
{
  "type": "input_move",
  "data": {
    "x": 0.5,
    "y": -0.3,
    "sprint": true,
    "crouch": false
  }
}
```

#### `input_action` (JSON)

Interaction requests (pick up, use, examine, etc.).

```typescript
interface InputActionMessage {
  type: "input_action";
  data: {
    action: "interact" | "use_item" | "examine" | "drop" | "emote";
    target_id?: string;        // Object/NPC ID
    target_type?: "object" | "npc" | "zone" | "item";
    item_id?: string;          // For use_item
    position?: { x: number; y: number }; // For position-based actions
    metadata?: Record<string, any>; // Action-specific data
  };
}
```

Examples:
```json
// Pick up clue
{
  "type": "input_action",
  "timestamp": 1706745600000,
  "seq": 42,
  "data": {
    "action": "interact",
    "target_id": "clue_old_photo",
    "target_type": "object"
  }
}

// Use lantern item
{
  "type": "input_action",
  "data": {
    "action": "use_item",
    "item_id": "lantern",
    "metadata": { "lit": true }
  }
}

// Examine suspicious door
{
  "type": "input_action",
  "data": {
    "action": "examine",
    "target_id": "door_basement",
    "target_type": "object"
  }
}
```

#### `puzzle_attempt` (JSON)

Submit puzzle solution.

```typescript
interface PuzzleAttemptMessage {
  type: "puzzle_attempt";
  data: {
    puzzle_id: string;         // Unique puzzle identifier
    solution: any;             // Puzzle-specific solution format
    attempt_time_ms: number;   // Time spent on puzzle
  };
}
```

Examples:
```json
// Pin pad puzzle
{
  "type": "puzzle_attempt",
  "data": {
    "puzzle_id": "pin_pad_cabinet",
    "solution": [1, 9, 4, 5],
    "attempt_time_ms": 45000
  }
}

// Riddle puzzle
{
  "type": "puzzle_attempt",
  "data": {
    "puzzle_id": "riddle_well",
    "solution": "shadow",
    "attempt_time_ms": 120000
  }
}

// Audio pattern puzzle
{
  "type": "puzzle_attempt",
  "data": {
    "puzzle_id": "audio_temple",
    "solution": ["low", "high", "mid", "low"],
    "attempt_time_ms": 89000
  }
}
```

#### `dialogue_choice` (JSON)

Select dialogue option.

```typescript
interface DialogueChoiceMessage {
  type: "dialogue_choice";
  data: {
    dialogue_id: string;       // Dialogue tree ID
    choice_index: number;      // Selected option index
    choice_id?: string;        // Option identifier (alternative to index)
  };
}
```

Example:
```json
{
  "type": "dialogue_choice",
  "data": {
    "dialogue_id": "npc_villager_greeting",
    "choice_index": 2,
    "choice_id": "ask_about_ruins"
  }
}
```

#### `ready` (JSON)

Client finished loading and is ready to start.

```typescript
interface ReadyMessage {
  type: "ready";
  data: {
    loaded_checkpoint: string;  // Confirm which checkpoint loaded
    client_version: string;     // Game version for compatibility
  };
}
```

#### `ping` (Binary - 1 byte)

Connection health check.

```
Binary Format:
┌─────────┐
│  Type   │
│  0xFF   │
└─────────┘

Server responds with `pong` containing server timestamp.
```

#### `request_sync` (JSON)

Request full state resync (on desync detection).

```typescript
interface RequestSyncMessage {
  type: "request_sync";
  data: {
    reason: "desync_detected" | "lag_spike" | "manual";
    last_known_seq: number;     // Last sequence number received
  };
}
```

---

### 2. State Messages (Server → Client)

#### `session_start` (JSON)

Initial state on successful connection.

```typescript
interface SessionStartMessage {
  type: "session_start";
  timestamp: number;
  seq: 0;
  data: {
    session_id: string;
    your_role: "detective" | "sidekick";
    your_player_id: string;
    partner: {
      player_id: string;
      display_name: string;
      connected: boolean;
    };
    checkpoint: {
      zone_id: string;
      spawn_position: { x: number; y: number };
    };
    world_progress: {
      story_chapter: number;
      zones_unlocked: string[];
      puzzles_solved: string[];
      clues_found: string[];
      inventory_shared: string[];
      story_flags: Record<string, boolean>;
    };
    session_state: {
      players: Record<string, PlayerState>;
      active_effects: Effect[];
      current_time_of_day: "day" | "night";
    };
  };
}

interface PlayerState {
  player_id: string;
  role: "detective" | "sidekick";
  position: { x: number; y: number };
  velocity: { x: number; y: number };
  facing: "left" | "right" | "up" | "down";
  animation_state: string;
  health: number;
  stamina: number;
  inventory: string[];
  is_controllable: boolean;  // false during cutscenes
}

interface Effect {
  effect_id: string;
  type: string;
  target_player: string;
  duration_remaining: number;
}
```

Example:
```json
{
  "type": "session_start",
  "timestamp": 1706745600000,
  "seq": 0,
  "data": {
    "session_id": "s_xyz789",
    "your_role": "detective",
    "your_player_id": "user_A",
    "partner": {
      "player_id": "user_B",
      "display_name": "SidekickSam",
      "connected": true
    },
    "checkpoint": {
      "zone_id": "forest_hub",
      "spawn_position": { "x": 100, "y": 200 }
    },
    "world_progress": {
      "story_chapter": 3,
      "zones_unlocked": ["forest_hub", "abandoned_house", "cave"],
      "puzzles_solved": ["pin_pad_cabinet", "riddle_well"],
      "clues_found": ["clue_photo", "clue_letter"],
      "inventory_shared": ["lantern"],
      "story_flags": {
        "met_villager": true,
        "found_basement_key": false
      }
    },
    "session_state": {
      "players": {
        "user_A": {
          "player_id": "user_A",
          "role": "detective",
          "position": { "x": 100, "y": 200 },
          "velocity": { "x": 0, "y": 0 },
          "facing": "down",
          "animation_state": "idle",
          "health": 100,
          "stamina": 100,
          "inventory": ["notebook", "pen"],
          "is_controllable": true
        },
        "user_B": {
          "player_id": "user_B",
          "role": "sidekick",
          "position": { "x": 105, "y": 200 },
          "velocity": { "x": 0, "y": 0 },
          "facing": "down",
          "animation_state": "idle",
          "health": 100,
          "stamina": 100,
          "inventory": ["map_fragment"],
          "is_controllable": true
        }
      },
      "active_effects": [],
      "current_time_of_day": "night"
    }
  }
}
```

#### `state_player` (Binary - 20 bytes per player)

Frequent player state updates (20Hz).

```
Binary Format (per player):
┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
│PlayerID │    X    │    Y    │   VelX  │   VelY  │  State  │
│  (1B)   │  (4B)   │  (4B)   │  (4B)   │  (4B)   │  (1B)   │
│  1 or 2 │  float  │  float  │  float  │  float  │  bits   │
└─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
Total: 18 bytes per player

State byte:
  Bit 0-1: Facing (0=down, 1=up, 2=left, 3=right)
  Bit 2-5: Animation state (0=idle, 1=walk, 2=run, etc.)
  Bit 6: Is controlled (1=true, 0=cutscene)
  Bit 7: Reserved

Example for 2 players:
  [0x01, 100.5, 200.0, 0.0, 0.0, 0x00]  // Detective, idle, facing down
  [0x02, 105.2, 200.0, 2.5, 0.0, 0x21]  // Sidekick, walking right, facing right
```

JSON equivalent (for comparison):
```json
{
  "type": "state_player",
  "timestamp": 1706745600000,
  "seq": 150,
  "data": {
    "players": [
      {
        "player_id": "user_A",
        "position": { "x": 100.5, "y": 200.0 },
        "velocity": { "x": 0.0, "y": 0.0 },
        "facing": "down",
        "animation": "idle",
        "controllable": true
      },
      {
        "player_id": "user_B",
        "position": { "x": 105.2, "y": 200.0 },
        "velocity": { "x": 2.5, "y": 0.0 },
        "facing": "right",
        "animation": "walk",
        "controllable": true
      }
    ]
  }
}
```

#### `state_world` (JSON)

Periodic world state snapshot (1Hz).

```typescript
interface StateWorldMessage {
  type: "state_world";
  timestamp: number;
  seq: number;
  data: {
    time_of_day: "day" | "night" | "dawn" | "dusk";
    weather?: "clear" | "rain" | "fog";
    active_objects: ActiveObject[];
    active_npcs: NPCState[];
    triggered_events: string[];
  };
}

interface ActiveObject {
  object_id: string;
  state: string;              // e.g., "open", "closed", "broken"
  position?: { x: number; y: number };
  properties: Record<string, any>;
}

interface NPCState {
  npc_id: string;
  position: { x: number; y: number };
  current_dialogue?: string;
  animation_state: string;
}
```

Example:
```json
{
  "type": "state_world",
  "timestamp": 1706745600000,
  "seq": 30,
  "data": {
    "time_of_day": "night",
    "weather": "clear",
    "active_objects": [
      {
        "object_id": "door_basement",
        "state": "locked",
        "properties": { "key_required": "basement_key" }
      },
      {
        "object_id": "lantern_post_1",
        "state": "lit",
        "properties": { "fuel_remaining": 0.8 }
      }
    ],
    "active_npcs": [
      {
        "npc_id": "villager_elder",
        "position": { "x": 500, "y": 300 },
        "animation_state": "idle"
      }
    ],
    "triggered_events": ["night_ambient_sounds"]
  }
}
```

---

### 3. Event Messages (Server → Client)

#### `event_action` (JSON)

Result of player action.

```typescript
interface EventActionMessage {
  type: "event_action";
  timestamp: number;
  seq: number;
  data: {
    action_type: string;
    result: "success" | "failure" | "partial";
    performed_by: string;       // Player ID
    target_id?: string;
    outcome: ActionOutcome;
    world_changes?: WorldChange[];
  };
}

type ActionOutcome = 
  | { type: "item_collected"; item_id: string; added_to: "detective" | "sidekick" | "shared" }
  | { type: "object_activated"; object_id: string; new_state: string }
  | { type: "zone_unlocked"; zone_id: string; entrance_position: { x: number; y: number } }
  | { type: "clue_discovered"; clue_id: string; description: string }
  | { type: "dialogue_started"; dialogue_id: string; npc_id: string }
  | { type: "interaction_blocked"; reason: string }
  | { type: "custom"; data: any };

interface WorldChange {
  type: "object_state" | "spawn_item" | "despawn" | "trigger_event";
  target_id: string;
  new_state?: any;
  position?: { x: number; y: number };
}
```

Examples:
```json
// Successfully collected clue
{
  "type": "event_action",
  "timestamp": 1706745601000,
  "seq": 45,
  "data": {
    "action_type": "interact",
    "result": "success",
    "performed_by": "user_A",
    "target_id": "clue_old_photo",
    "outcome": {
      "type": "clue_discovered",
      "clue_id": "clue_photo_1945",
      "description": "A faded photograph showing the temple in its prime"
    },
    "world_changes": [
      {
        "type": "despawn",
        "target_id": "clue_old_photo"
      }
    ]
  }
}

// Failed to open locked door
{
  "type": "event_action",
  "data": {
    "action_type": "interact",
    "result": "failure",
    "performed_by": "user_B",
    "target_id": "door_basement",
    "outcome": {
      "type": "interaction_blocked",
      "reason": "locked"
    }
  }
}

// Unlocked new zone
{
  "type": "event_action",
  "data": {
    "action_type": "puzzle_solved",
    "result": "success",
    "performed_by": "user_A",
    "outcome": {
      "type": "zone_unlocked",
      "zone_id": "underground_caverns",
      "entrance_position": { "x": 400, "y": 150 }
    },
    "world_changes": [
      {
        "type": "object_state",
        "target_id": "gate_caverns",
        "new_state": "open"
      }
    ]
  }
}
```

#### `event_puzzle` (JSON)

Puzzle completion/failure.

```typescript
interface EventPuzzleMessage {
  type: "event_puzzle";
  data: {
    puzzle_id: string;
    status: "solved" | "failed" | "hint_requested";
    solved_by?: string;
    attempts: number;
    time_taken_ms: number;
    rewards?: PuzzleReward;
    hint?: string;
  };
}

interface PuzzleReward {
  clues?: string[];
  items?: string[];
  zones_unlocked?: string[];
  story_progress?: string;
  experience?: number;
}
```

Example:
```json
// Puzzle solved
{
  "type": "event_puzzle",
  "data": {
    "puzzle_id": "pin_pad_cabinet",
    "status": "solved",
    "solved_by": "user_A",
    "attempts": 3,
    "time_taken_ms": 45000,
    "rewards": {
      "items": ["basement_key", "old_journal"],
      "clues": ["journal_entry_1"],
      "story_progress": "found_basement_access"
    }
  }
}

// Puzzle failed (max attempts)
{
  "type": "event_puzzle",
  "data": {
    "puzzle_id": "riddle_sphinx",
    "status": "failed",
    "attempts": 5,
    "time_taken_ms": 120000,
    "hint": "The answer is related to shadows and light"
  }
}
```

#### `event_story` (JSON)

Story progression events.

```typescript
interface EventStoryMessage {
  type: "event_story";
  data: {
    event_type: "chapter_complete" | "cutscene_trigger" | "dialogue_tree_complete" | "ending_unlocked";
    chapter?: number;
    cutscene_id?: string;
    dialogue_tree?: string;
    ending?: string;
    narration?: string;
    choices_available?: StoryChoice[];
  };
}

interface StoryChoice {
  choice_id: string;
  text: string;
  consequences_hint?: string;
}
```

Example:
```json
// Chapter complete
{
  "type": "event_story",
  "data": {
    "event_type": "chapter_complete",
    "chapter": 2,
    "narration": "With the basement key in hand, the mystery deepens..."
  }
}

// Cutscene trigger
{
  "type": "event_story",
  "data": {
    "event_type": "cutscene_trigger",
    "cutscene_id": "basement_discovery",
    "players_controlled": false
  }
}
```

#### `event_inventory` (JSON)

Inventory changes.

```typescript
interface EventInventoryMessage {
  type: "event_inventory";
  data: {
    change_type: "add" | "remove" | "transfer" | "use";
    player: "detective" | "sidekick" | "shared";
    item_id: string;
    item_data?: {
      name: string;
      description: string;
      icon: string;
      usable: boolean;
    };
    quantity?: number;
    transferred_to?: "detective" | "sidekick" | "shared";
  };
}
```

---

### 4. System Messages

#### `partner_status` (JSON)

Partner connection state changes.

```typescript
interface PartnerStatusMessage {
  type: "partner_status";
  data: {
    status: "connected" | "disconnected" | "reconnecting";
    player_id: string;
    display_name: string;
    last_seen?: number;
    estimated_return?: number;
  };
}
```

Example:
```json
// Partner disconnected
{
  "type": "partner_status",
  "data": {
    "status": "disconnected",
    "player_id": "user_B",
    "display_name": "SidekickSam",
    "last_seen": 1706745605000
  }
}

// Partner reconnected
{
  "type": "partner_status",
  "data": {
    "status": "connected",
    "player_id": "user_B",
    "display_name": "SidekickSam"
  }
}
```

#### `error` (JSON)

Error messages from server.

```typescript
interface ErrorMessage {
  type: "error";
  data: {
    code: string;
    message: string;
    details?: any;
    fatal: boolean;  // If true, connection will close
  };
}
```

Error Codes:
| Code | Description | Action |
|------|-------------|--------|
| `INVALID_ACTION` | Action not valid in current state | Ignore / Show feedback |
| `OUT_OF_RANGE` | Target too far away | Move closer |
| `MISSING_ITEM` | Required item not in inventory | Find item |
| `PUZZLE_ALREADY_SOLVED` | Puzzle was already completed | Ignore |
| `RATE_LIMITED` | Too many requests | Slow down |
| `DESYNC_DETECTED` | Client state out of sync | Request full sync |
| `SESSION_ENDING` | Session is closing | Save and exit |
| `PARTNER_DISCONNECTED` | Partner left | Pause game |
| `VERSION_MISMATCH` | Client version incompatible | Force update |
| `AUTH_EXPIRED` | Authentication expired | Re-authenticate |

Example:
```json
{
  "type": "error",
  "data": {
    "code": "OUT_OF_RANGE",
    "message": "You are too far from the door to interact with it",
    "details": {
      "target_id": "door_basement",
      "distance": 5.2,
      "max_distance": 2.0
    },
    "fatal": false
  }
}
```

#### `force_sync` (JSON)

Server forces client to update state (on desync).

```typescript
interface ForceSyncMessage {
  type: "force_sync";
  data: {
    reason: "desync" | "cheat_detected" | "lag_correction";
    player_states: Record<string, PlayerState>;
    world_state?: WorldState;
    sequence_reset: number;
  };
}
```

---

## Connection States

### Client State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT STATES                            │
└─────────────────────────────────────────────────────────────────┘

[DISCONNECTED]
     │
     │ HTTP POST /worlds/:id/start
     ▼
[CONNECTING] ───────► Timeout? ───────► [ERROR] ───────► Retry?
     │
     │ WebSocket connected
     ▼
[HANDSHAKE]
     │
     │ Received session_start
     ▼
[LOADING] ───────────► Load checkpoint
     │                 Spawn players
     │                 Initialize world
     ▼
[READY] ─────────────► Send "ready" message
     │
     │ Both players ready?
     ▼
[PLAYING] ◄──────────────────────────────────────────────────┐
     │                                                      │
     │ input_move ─────┐                                    │
     │ input_action ───┼──► Server validates ──► Broadcast ─┤
     │ puzzle_attempt ─┘                                    │
     │                                                      │
     │ Partner disconnect?                                  │
     ▼                                                      │
[PAUSED] ─────────────► Show "Waiting for partner"          │
     │                                                      │
     │ Partner reconnect?                                   │
     └──────────────────────────────────────────────────────┘
     │
     │ Manual disconnect / Session end
     ▼
[DISCONNECTING] ──────► Save final state
     │
     ▼
[DISCONNECTED]
```

### Server State Machine

```
[SESSION_PENDING]
     │
     │ Detective connects
     ▼
[AWAITING_PLAYERS] ───► Sidekick connects? ───► [READY]
     │                                             │
     │ Timeout (5 min)                             │ Both send "ready"
     ▼                                             ▼
[SESSION_CANCELLED]                          [PLAYING]
                                                  │
     ┌────────────────────────────────────────────┤
     │                                            │ input_action
     │  Validate all actions                      │ puzzle_attempt
     │  Broadcast results                         │ dialogue_choice
     │                                            │
     │ Partner disconnect?                        │
     ▼                                            ▼
[PAUSED] ───────► Auto-save ──────► [WAITING_RECONNECT]
     │                                    │
     │                                    │ Timeout (5 min)?
     │ Partner reconnect?                 ▼
     └─────────────────────────────► [SESSION_ENDED]
```

---

## Error Handling & Recovery

### Client Recovery Strategies

| Scenario | Detection | Recovery |
|----------|-----------|----------|
| **Packet Loss** | Seq number gap | Request `request_sync` with last known seq |
| **Lag Spike** | Ping > 500ms | Show "Connection unstable" warning |
| **Desync** | Position mismatch > threshold | Server sends `force_sync` |
| **Disconnect** | WebSocket close | Show pause menu, attempt reconnect |
| **Auth Expire** | `AUTH_EXPIRED` error | Refresh Firebase token, reconnect |
| **Version Mismatch** | `VERSION_MISMATCH` error | Force app update |

### Reconnection Flow

```
Connection Lost
     │
     ▼
Show "Reconnecting..." (3 attempts)
     │
     ├─ Success ──────────────────────────┐
     │                                    │
     │ Send: { type: "request_sync",       │
     │         data: { last_seq: 150 } }  │
     │                                    │
     │ Server responds with:              │
     │ { type: "force_sync", ... }        │
     │                                    │
     │ Client applies new state           │
     ▼                                    ▼
Resume Game                    Failed after 3 attempts
                                      │
                                      ▼
                              Show "Partner Disconnected"
                              [Save & Exit] button
```

---

## Rate Limiting

To prevent spam and cheating:

| Message Type | Rate Limit | Burst |
|--------------|-----------|-------|
| `input_move` | 60/sec | 5 |
| `input_action` | 10/sec | 3 |
| `puzzle_attempt` | 1/sec | 5 |
| `request_sync` | 1/5sec | 1 |
| `ping` | 1/sec | 2 |

Exceeding limits results in `RATE_LIMITED` error.

---

## Security Considerations

### Client Trust Level: ZERO

```typescript
// Server MUST validate EVERYTHING:

function validateMove(player, input) {
  // 1. Check rate limit
  if (player.recentMoves > 60) return false;
  
  // 2. Check speed (prevent teleport hacks)
  const maxSpeed = input.sprint ? 8 : 4;
  const speed = Math.sqrt(input.x**2 + input.y**2);
  if (speed > maxSpeed) return false;
  
  // 3. Check position bounds
  if (!world.isValidPosition(newPosition)) return false;
  
  // 4. Check collision
  if (world.isCollision(newPosition)) return false;
  
  // 5. Check if player is controllable
  if (!player.isControllable) return false;
  
  return true;
}

function validateAction(player, action) {
  // 1. Check range
  const target = world.getObject(action.target_id);
  if (distance(player.position, target.position) > MAX_INTERACT_DISTANCE) {
    return false;
  }
  
  // 2. Check prerequisites
  if (action.type === "use_item") {
    if (!player.hasItem(action.item_id)) return false;
  }
  
  // 3. Check state validity
  if (action.type === "interact" && target.state === "broken") {
    return false;
  }
  
  return true;
}
```

---

## Implementation Checklist

### Server (Node.js/WebSocket)

- [ ] HTTP endpoints for session creation
- [ ] WebSocket connection handler with JWT validation
- [ ] Binary message parser (input_move)
- [ ] JSON message router
- [ ] Player state manager (position, velocity)
- [ ] World state manager (objects, NPCs)
- [ ] Action validator (range, prerequisites)
- [ ] Puzzle validator
- [ ] Broadcast system
- [ ] Rate limiter middleware
- [ ] Auto-save to Firestore
- [ ] Reconnection handler
- [ ] Error handler with descriptive codes

### Client (Godot)

- [ ] HTTP request wrapper with Firebase auth
- [ ] WebSocket client with binary support
- [ ] Input capture and binary serialization
- [ ] Message deserializer (binary + JSON)
- [ ] State interpolation (for smooth movement)
- [ ] Prediction system (client-side prediction)
- [ ] Desync detection
- [ ] Reconnection logic
- [ ] Error display UI
- [ ] Pause on disconnect UI
- [ ] Sequence number tracker
- [ ] Ping/latency display (debug)

---

## Message Type Reference (Quick)

### Client → Server

```
Binary:
  0x01 - input_move (10 bytes)
  0xFF - ping (1 byte)

JSON:
  "input_action"    - Interaction request
  "puzzle_attempt"  - Submit puzzle solution
  "dialogue_choice" - Select dialogue option
  "ready"           - Client finished loading
  "request_sync"    - Request state resync
```

### Server → Client

```
Binary:
  state_player (18 bytes per player)
  pong (1 byte)

JSON:
  "session_start"    - Initial state
  "state_world"      - World snapshot
  "event_action"     - Action result
  "event_puzzle"     - Puzzle outcome
  "event_story"      - Story progression
  "event_inventory"  - Inventory change
  "partner_status"   - Connect/disconnect
  "error"            - Error message
  "force_sync"       - Force state update
```

---

## Example: Full Session Flow

```
T+0ms   Client A        Server          Client B
        |               |               |
        | HTTP /start   |               |
        |-------------->|               |
        |               | Create Session|
        |<--------------|               |
        | WS Connect    |               |
        |==============>|               |
        |               | Validate      |
        |               | Wait for B    |
        |               |               |
T+500ms |               |               | HTTP /join
        |               |<--------------|
        |               | Validate      |
        |               |-------------->|
        |               |               | WS Connect
        |               |<==============|
        |               | Both Connected|
        |<-- session_start ------------>|
        |               |               |
        | Load Level    |               | Load Level
        | "ready"       |               | "ready"
        |-------------->|               |
        |               |-------------->|
        |               |               | "ready"
        |               |<--------------|
        |               | Both Ready    |
        |<-- "game_started" ----------->|
        |               |               |
        | [input_move]  |               | [input_move]
        |==============>|               |<==============
        |               | Validate      |
        |               | Apply         |
        |               | Broadcast     |
        |<-- [state_player] -----------|
        |               |-------------->|
        |               |               |<-- [state_player]
        |               |               |
T+5s    | [interact]    |               |
        |-------------->|               |
        |               | Validate      |
        |               | Apply         |
        |               | Save to DB    |
        |<-- event_action --------------|
        |               | event_action  |
        |               |-------------->|
        |               |               |<-- event_action
        |               |               |
        ... (gameplay continues) ...
        |               |               |
        |               | B Disconnects |
        |               |<==X           |
        |               | Pause         |
        |               | Save          |
        |<-- partner_status -----------|
        | "disconnected"|               |
        |               |               |
T+2min  |               | B Reconnects  |
        |               |<==============|
        |               | Validate      |
        |               | Resume        |
        |<-- "game_resumed" ------------|
        |               |-------------->|
        |               |               |<-- "game_resumed"
        |               |               |
        ... (gameplay continues) ...
```
