# Kwentura Multiplayer Lobby - Expectation Document

## Overview
This document defines the expected behavior for the Kwentura 2-player cooperative game lobby system. It covers the flow from hosting a game to both players being ready in the lobby, including the PubSub (Publisher-Subscriber) architecture for real-time updates.

---

## 1. Host Creates a Game

### 1.1 Host Action
- Player clicks "Host Game" button in main menu
- System validates authentication (Firebase auth token must be present)

### 1.2 Expected Server Behavior
- Server creates a new "world" entity
- Server assigns the host the role of "detective"
- Server generates a unique 6-character invite code (e.g., "ABC123")
- Server returns:
  ```json
  {
    "world_id": "uuid-string",
    "invite_code": "ABC123",
    "status": "waiting_for_partner"
  }
  ```

### 1.3 Expected Client Behavior
- Host transitions to `detective_lobby.tscn`
- Room code is displayed prominently (gold color)
- Host sees their own avatar (Detective) on the left side
- **Sidekick avatar is HIDDEN initially**
- Status shows: "Waiting for Sidekick..."
- Start button is **disabled/hidden** until sidekick joins
- Host's cached partner data from previous sessions is **cleared**

### 1.4 Lobby WebSocket Connection (PubSub)
- Host connects to lobby WebSocket: `ws://localhost:10000/ws/lobby?world_id=<id>&token=<auth>`
- Connection state: `_is_in_lobby = true`
- Host listens for `partner_joined` messages

---

## 2. Sidekick Joins Using Code

### 2.1 Sidekick Action
- Player clicks "Join Game" button
- Enter 6-character invite code in popup
- Clicks "OK" to submit

### 2.2 Expected Server Behavior
- Server validates the invite code exists
- Server checks world status is "waiting_for_partner"
- Server assigns player the role of "sidekick"
- Server associates sidekick with the world
- Server returns:
  ```json
  {
    "world_id": "uuid-string",
    "partner_id": "host-user-id",
    "partner_name": "DetectivePlayerName",
    "status": "joined"
  }
  ```
- Server **publishes** `partner_joined` message to the world's lobby channel

### 2.3 Expected Client Behavior
- Sidekick transitions to `detective_lobby.tscn`
- Sidekick does NOT see the room code
- Sidekick sees both avatars (Detective on left, Sidekick on right)
- Status shows: "Connected! Waiting for detective to start..."
- Sidekick connects to lobby WebSocket for notifications

---

## 3. Real-Time Synchronization (PubSub)

### 3.1 Server PubSub Implementation
The server MUST implement WebSocket-based PubSub for the lobby:

#### Lobby Channel: `/ws/lobby?world_id=<world_id>&token=<token>`

**Messages Server Sends (Pub):**

| Message Type | Recipient | Payload | Description |
|--------------|-----------|---------|-------------|
| `partner_joined` | Host | `{"partner_id": "...", "partner_name": "..."}` | Sidekick has joined |
| `partner_left` | Host | `{"partner_id": "..."}` | Sidekick has disconnected |
| `session_starting` | Both | `{}` | Detective clicked start |
| `error` | Both | `{"message": "..."}` | Lobby error occurred |

### 3.2 Host Receives `partner_joined` (PubSub)
- **Trigger**: Sidekick successfully joins via HTTP POST
- **Server Action**: Broadcast `partner_joined` to host's lobby WebSocket
- **Host Client Action**:
  1. `sidekick_connected = true`
  2. Status updates to: "Sidekick Connected! Click START when ready!" (green)
  3. Start button becomes **visible and enabled**
  4. Sidekick avatar **fades in** (alpha 0 → 1 over 0.5s)
  5. Sidekick name label becomes visible with partner's name
  6. Sidekick status label shows: "{PartnerName} is ready!"

### 3.3 Connection State Management
```
Host State Flow:
DISCONNECTED → CONNECTING_HTTP → LOADING (lobby) → CONNECTING_WS (game) → PLAYING
                    ↑                      ↑
              create_world()         start_game_session()
                    ↓
              _connect_lobby_websocket()

Sidekick State Flow:
DISCONNECTED → CONNECTING_HTTP → LOADING (lobby) → CONNECTING_WS (game) → PLAYING
                    ↑                      ↑
              join_world()             (auto on session_start)
                    ↓
              _connect_lobby_websocket()
```

---

## 4. Lobby UI Expectations

### 4.1 Host (Detective) View
```
┌─────────────────────────────────────────────┐
│                  KWENTURA                   │
│                                             │
│              Code: ABC123                   │
│                                             │
│    [DETECTIVE]         [SIDEKICK]           │
│    ┌─────┐             ┌─────┐             │
│    │  🕵️ │             │ 🦊  │  ← fades in │
│    └─────┘             └─────┘    on join  │
│    Detective           SidekickName         │
│                              ↑              │
│                        hidden initially     │
│                                             │
│         "Sidekick Connected!               │
│          Click START when ready!"           │
│                                             │
│         [    START GAME    ]                │
│                    ↑                        │
│            disabled until join              │
│                                             │
└─────────────────────────────────────────────┘
```

### 4.2 Sidekick View
```
┌─────────────────────────────────────────────┐
│                  KWENTURA                   │
│                                             │
│    [DETECTIVE]         [SIDEKICK]           │
│    ┌─────┐             ┌─────┐             │
│    │  🕵️ │             │ 🦊  │             │
│    └─────┘             └─────┘             │
│    Detective           SidekickName         │
│                                             │
│    "Connected! Waiting for detective       │
│     to start..."                            │
│                                             │
│         [START GAME] ← HIDDEN               │
│                                             │
└─────────────────────────────────────────────┘
```

### 4.3 UI Elements Visibility Matrix

| Element | Host Initial | Host After Join | Sidekick Initial | Sidekick After Join |
|---------|--------------|-----------------|------------------|---------------------|
| Room Code | ✅ Visible | ✅ Visible | ❌ Hidden | ❌ Hidden |
| Detective Avatar | ✅ Visible | ✅ Visible | ✅ Visible | ✅ Visible |
| Sidekick Avatar | ❌ Hidden | ✅ Visible | ✅ Visible | ✅ Visible |
| Detective Name | ✅ Visible | ✅ Visible | ✅ Visible | ✅ Visible |
| Sidekick Name | ❌ Hidden | ✅ Visible | ✅ Visible | ✅ Visible |
| Start Button | ❌ Hidden | ✅ Enabled | ❌ Hidden | ❌ Hidden |
| Status Text | "Waiting..." | "Connected!" | "Connected!" | "Connected!" |

---

## 5. Server API Endpoints

### 5.1 HTTP Endpoints

#### POST `/worlds`
Create a new world (host only).

**Request:**
```json
{
  "name": "Game",
  "role": "detective"
}
```

**Response:**
```json
{
  "world_id": "uuid",
  "invite_code": "ABC123",
  "status": "waiting_for_partner"
}
```

#### POST `/worlds/{invite_code}/join`
Join an existing world (sidekick).

**Response:**
```json
{
  "world_id": "uuid",
  "partner_id": "host-user-id",
  "partner_name": "HostName",
  "status": "joined"
}
```

#### POST `/worlds/{world_id}/start`
Start the game session (host only).

**Response:**
```json
{
  "session_id": "uuid",
  "ws_url": "ws://localhost:10000/ws/game?session_id=...",
  "checkpoint": "forest_hub",
  "world_progress": {}
}
```

### 5.2 WebSocket Endpoints

#### Lobby WebSocket: `/ws/lobby?world_id={id}&token={token}`
- **Purpose**: PubSub notifications while waiting in lobby
- **Connection**: Established after create_world() or join_world()
- **Disconnection**: Called when session starts or player leaves

#### Game WebSocket: `/ws/game?session_id={id}&token={token}`
- **Purpose**: Real-time game state synchronization
- **Connection**: Established after start_game_session()

---

## 6. Error Handling

### 6.1 Host Errors
| Scenario | Expected Behavior |
|----------|-------------------|
| Auth token missing | Show "Waiting for authentication..." then error |
| Server unreachable | Show "Failed to create world: Connection failed" |
| World creation fails | Return to main menu with error message |

### 6.2 Sidekick Errors
| Scenario | Expected Behavior |
|----------|-------------------|
| Invalid code | Shake input field, show "Invalid code" |
| World full | Show "Game already in progress" |
| Host disconnected | Show "Detective disconnected!", return to menu after 2s |
| Server unreachable | Show "Connection failed", return to menu after 2s |

### 6.3 Lobby WebSocket Errors
| Scenario | Expected Behavior |
|----------|-------------------|
| Lobby WS fails to connect | Log warning, fallback to no real-time updates |
| Lobby WS disconnects | Set `_is_in_lobby = false`, cleanup |

---

## 7. Testing Checklist

### 7.1 Host Flow
- [ ] Click "Host Game" → Creates world successfully
- [ ] Room code is displayed immediately
- [ ] Sidekick avatar is NOT visible initially
- [ ] Sidekick name is NOT visible initially
- [ ] Start button is NOT visible initially
- [ ] Lobby WebSocket connects successfully
- [ ] When sidekick joins → Sidekick avatar fades in
- [ ] When sidekick joins → Sidekick name appears
- [ ] When sidekick joins → Start button becomes enabled
- [ ] Clicking Start → Game starts for both players

### 7.2 Sidekick Flow
- [ ] Click "Join Game" → Popup appears
- [ ] Enter 6-char code → Can submit
- [ ] Invalid code → Error shown
- [ ] Valid code → Joins world successfully
- [ ] Both avatars visible immediately
- [ ] Status shows "Waiting for detective"
- [ ] Cannot see room code
- [ ] Cannot see start button
- [ ] When host starts → Game starts automatically

### 7.3 PubSub/Real-time
- [ ] Host receives `partner_joined` within 1 second of sidekick joining
- [ ] No HTTP polling occurs after lobby WebSocket connects
- [ ] Sidekick joining is reflected immediately on host screen
- [ ] Sidekick leaving triggers `partner_left` message

### 7.4 Edge Cases
- [ ] Host leaves before sidekick joins → Sidekick sees error
- [ ] Sidekick leaves after joining → Host sees "disconnected" message
- [ ] Second sidekick tries to join → Error "World full"
- [ ] Host creates new world after previous → Old partner data cleared

---

## 8. Implementation Notes

### 8.1 Client-Side Files Modified
- `scripts/systems/network_manager.gd` - Added lobby WebSocket, PubSub handling
- `scripts/mainMenu/detective_lobby.gd` - Removed polling, uses PubSub signals
- `scripts/mainMenu/sidekick_waiting.gd` - Signal handling for connection
- `scripts/mainMenu/main_menu.gd` - Host/sidekick flow entry points

### 8.2 Key Variables
```gdscript
# NetworkManager
_lobby_ws: WebSocketPeer      # Separate from game WebSocket
_is_in_lobby: bool            # For polling loop control
_partner_id: String           # Cleared on create_world()
_partner_name: String         # Cleared on create_world()

# DetectiveLobby
sidekick_connected: bool      # Set true on partner_connected signal
```

### 8.3 Signals (PubSub Events)
```gdscript
# NetworkManager signals
partner_connected(player_data: Dictionary)
partner_disconnected(player_data: Dictionary)
game_started(checkpoint: String)
connection_failed(error: String)
```

---

## 9. Server Implementation Requirements

### 9.1 Required Features
1. **World Management**: Create, join, start worlds
2. **Invite Codes**: Generate unique 6-character codes
3. **PubSub Channel**: Lobby WebSocket endpoint for real-time notifications
4. **Message Broadcasting**: When sidekick joins, broadcast to host
5. **State Persistence**: Track world status (waiting/joined/playing)

### 9.2 PubSub Protocol
The server MUST implement the following message protocol on the lobby WebSocket:

**Client → Server:** (Optional heartbeat)
```json
{"type": "ping"}
```

**Server → Client:**
```json
// Partner joined
{
  "type": "partner_joined",
  "data": {
    "partner_id": "user-id",
    "partner_name": "PlayerName"
  }
}

// Partner left
{
  "type": "partner_left",
  "data": {
    "partner_id": "user-id"
  }
}

// Session starting
{
  "type": "session_starting",
  "data": {}
}
```

---

## 10. Success Criteria

✅ **Host can create a game and get a join code**  
✅ **Sidekick can join using the 6-character code**  
✅ **Sidekick enters the same lobby as the host**  
✅ **Host sees sidekick's avatar appear in real-time (no polling delay)**  
✅ **Both players can see each other's avatars**  
✅ **Host sees "Start Game" button only after sidekick joins**  
✅ **Sidekick does NOT see the start button**  
✅ **Both players start game when host clicks Start**  
✅ **System uses PubSub (WebSocket) instead of HTTP polling**  

---

*Document Version: 1.0*  
*Last Updated: 2026-02-07*  
*Related Files: NETWORK_IMPLEMENTATION_SUMMARY.md, WEBSOCKET_PROTOCOL_SPEC.md*
