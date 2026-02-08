# Kwentura Server - Revised Expectations Document

## Priority: CORE FUNCTIONALITY FIRST
**Authentication is LOW PRIORITY for initial development.**

---

## 1. Development Mode (No Auth Required)

### 1.1 Client Configuration
The client is configured for development:
```gdscript
# scripts/systems/network_manager.gd
const API_BASE: String = "http://localhost:10000"
const WS_BASE: String = "ws://localhost:10000/ws"
```

### 1.2 Auth Bypass (DEV MODE)
**Option A: Accept any token**
- Server accepts `"Authorization: Bearer dev_token"` or any token
- User ID extracted from token or auto-generated

**Option B: No auth header required**
- Server doesn't require Authorization header
- Auto-generates user_id from connection or uses a default

**Option C: Dev endpoint prefix**
- All dev endpoints are under `/dev/` and skip auth
- Example: `POST /dev/worlds`, `POST /dev/worlds/ABC123/join`

### 1.3 Recommended: Simple Dev Token
Server should accept this minimal auth header:
```
Authorization: Bearer dev
```
And respond with auto-generated user ID.

---

## 2. Core Endpoints (MUST WORK)

### 2.1 POST `/worlds` - Host Creates Game
**NO AUTH REQUIRED FOR DEV**

**Request:**
```http
POST /worlds
Content-Type: application/json

{
  "name": "Game",
  "role": "detective",
  "player_name": "Player1"  // optional, for display
}
```

**Response (200 OK):**
```json
{
  "world_id": "world-uuid-123",
  "invite_code": "ABC123",
  "player_id": "player-uuid-456",
  "status": "waiting_for_partner"
}
```

**Server Actions:**
1. Generate `world_id` (UUID)
2. Generate `invite_code` (6 alphanumeric chars, uppercase)
3. Store world in memory/DB with status "waiting_for_partner"
4. Store host player info
5. Return invite code

---

### 2.2 POST `/worlds/{invite_code}/join` - Sidekick Joins
**NO AUTH REQUIRED FOR DEV**

**Request:**
```http
POST /worlds/ABC123/join
Content-Type: application/json

{
  "player_name": "Player2"  // optional
}
```

**Response (200 OK):**
```json
{
  "world_id": "world-uuid-123",
  "player_id": "player-uuid-789",
  "partner_id": "player-uuid-456",
  "partner_name": "Player1",
  "status": "joined"
}
```

**Response (404):**
```json
{
  "error": "World not found",
  "code": "INVALID_CODE"
}
```

**Response (409):**
```json
{
  "error": "World is full",
  "code": "WORLD_FULL"
}
```

**Server Actions:**
1. Validate invite code exists
2. Check world status is "waiting_for_partner"
3. Add sidekick to world
4. **BROADCAST** `partner_joined` to host's lobby WebSocket
5. Return partner info

---

### 2.3 POST `/worlds/{world_id}/start` - Start Game Session
**NO AUTH REQUIRED FOR DEV**

**Request:**
```http
POST /worlds/world-uuid-123/start
Content-Type: application/json

{}
```

**Response (200 OK):**
```json
{
  "session_id": "session-uuid-999",
  "ws_url": "ws://localhost:10000/ws/game?session_id=session-uuid-999",
  "checkpoint": "forest_hub",
  "world_progress": {
    "current_zone": "forest_hub",
    "completed_zones": []
  }
}
```

**Server Actions:**
1. Validate world exists and has 2 players
2. Create game session
3. **BROADCAST** `session_starting` to both lobby WebSockets
4. Generate game WebSocket URL
5. Return session info

---

## 3. WebSocket Endpoints (CRITICAL)

### 3.1 Lobby WebSocket: `/ws/lobby`
**Purpose:** Real-time notifications while waiting in lobby (PubSub)

**Connection:**
```
ws://localhost:10000/ws/lobby?world_id=world-uuid-123&token=dev
```

**Server Behavior:**
1. Accept connection
2. Parse `world_id` from query params
3. Add connection to world's lobby channel
4. Listen for messages (optional ping/pong)
5. Broadcast messages to appropriate clients

**Messages Server Sends:**

```json
// When sidekick joins
{
  "type": "partner_joined",
  "data": {
    "partner_id": "player-uuid-789",
    "partner_name": "Player2"
  }
}

// When partner leaves
{
  "type": "partner_left",
  "data": {
    "partner_id": "player-uuid-789"
  }
}

// When game starts
{
  "type": "session_starting",
  "data": {
    "session_id": "session-uuid-999",
    "ws_url": "ws://localhost:10000/ws/game?session_id=session-uuid-999"
  }
}

// Heartbeat (optional)
{
  "type": "ping",
  "data": {}
}
```

---

### 3.2 Game WebSocket: `/ws/game`
**Purpose:** Real-time gameplay state sync

**Connection:**
```
ws://localhost:10000/ws/game?session_id=session-uuid-999&token=dev
```

**Server Behavior:**
1. Validate session_id
2. Add player to game session
3. Handle game messages (input, state sync, etc.)
4. Broadcast player states 60Hz

**Messages:** See `WEBSOCKET_PROTOCOL_SPEC.md` for full protocol

---

## 4. Data Model (In-Memory is OK for Dev)

### 4.1 World Object
```javascript
{
  world_id: "uuid",
  invite_code: "ABC123",
  host_id: "player-uuid",
  sidekick_id: null,  // null until joined
  status: "waiting_for_partner", // "waiting_for_partner" | "ready" | "playing" | "closed"
  created_at: timestamp,
  lobby_connections: [], // WebSocket connections
  session_id: null
}
```

### 4.2 Player Object
```javascript
{
  player_id: "uuid",
  name: "Player1",
  role: "detective", // "detective" | "sidekick"
  world_id: "world-uuid"
}
```

### 4.3 Session Object
```javascript
{
  session_id: "uuid",
  world_id: "world-uuid",
  players: ["player1-uuid", "player2-uuid"],
  game_connections: [], // WebSocket connections
  started_at: timestamp,
  checkpoint: "forest_hub"
}
```

---

## 5. Sequence Diagrams

### 5.1 Host Creates Game
```
┌────────┐         ┌────────┐         ┌────────┐
│ Client │         │ Server │         │ Lobby  │
└───┬────┘         └───┬────┘         └───┬────┘
    │                  │                  │
    │ POST /worlds     │                  │
    │─────────────────>│                  │
    │                  │                  │
    │                  │ Create World     │
    │                  │ Generate Code    │
    │                  │                  │
    │  {world_id,      │                  │
    │   invite_code}   │                  │
    │<─────────────────│                  │
    │                  │                  │
    │ WS /ws/lobby     │                  │
    │─────────────────>│                  │
    │                  │ Connect to Lobby │
    │                  │─────────────────>│
    │                  │                  │
    │  Connected       │                  │
    │<─────────────────│                  │
    │                  │                  │
    │     [ WAITING FOR SIDEKICK ]        │
    │                  │                  │
```

### 5.2 Sidekick Joins
```
┌──────────┐       ┌────────┐       ┌────────┐       ┌────────┐
│ Sidekick │       │ Server │       │ Lobby  │       │  Host  │
└────┬─────┘       └───┬────┘       └───┬────┘       └───┬────┘
     │                 │                │                │
     │ POST /join      │                │                │
     │────────────────>│                │                │
     │                 │                │                │
     │                 │ Validate Code  │                │
     │                 │ Add Sidekick   │                │
     │                 │                │                │
     │  {world_id,     │                │                │
     │   partner_info} │                │                │
     │<────────────────│                │                │
     │                 │                │                │
     │ WS /ws/lobby    │                │                │
     │────────────────>│                │                │
     │                 │                │                │
     │                 │ Broadcast      │                │
     │                 │ partner_joined │                │
     │                 │───────────────>│───────────────>│
     │                 │                │                │
     │                 │                │  partner_joined│
     │                 │                │<───────────────│
     │                 │                │                │
     │     [ SIDEKICK APPEARS ON HOST SCREEN ]          │
```

### 5.3 Start Game
```
┌────────┐         ┌────────┐         ┌──────────┐
│  Host  │         │ Server │         │ Sidekick │
└───┬────┘         └───┬────┘         └────┬─────┘
    │                  │                   │
    │ POST /start      │                   │
    │─────────────────>│                   │
    │                  │                   │
    │                  │ Create Session    │
    │                  │ Broadcast start   │
    │                  │──────────────────>│
    │                  │                   │
    │  {session_id,    │                   │
    │   ws_url}        │                   │
    │<─────────────────│                   │
    │                  │                   │
    │                  │ session_starting  │
    │                  │──────────────────>│
    │                  │                   │
    │ WS /ws/game      │                   │
    │─────────────────>│                   │
    │                  │<──────────────────│ WS /ws/game
    │                  │                   │
    │    [ GAME STARTED - BOTH IN GAME ]  │
```

---

## 6. Error Responses (Standard Format)

All errors should follow this format:
```json
{
  "error": "Human readable message",
  "code": "ERROR_CODE",
  "details": {}  // optional
}
```

### 6.1 Common Error Codes
| Code | HTTP | Description |
|------|------|-------------|
| `INVALID_CODE` | 404 | Invite code doesn't exist |
| `WORLD_FULL` | 409 | World already has 2 players |
| `ALREADY_STARTED` | 409 | Game session already started |
| `NOT_HOST` | 403 | Only host can start game |
| `MISSING_PLAYER` | 400 | Need 2 players to start |
| `INVALID_REQUEST` | 400 | Bad request body |

---

## 7. Quick Start Checklist (Server)

### Minimum Viable Server
- [ ] HTTP server running on port 10000
- [ ] POST `/worlds` - creates world, returns invite code
- [ ] POST `/worlds/{code}/join` - joins world, returns partner info
- [ ] POST `/worlds/{id}/start` - starts session, returns ws_url
- [ ] WebSocket `/ws/lobby` - accepts connections, broadcasts messages
- [ ] WebSocket `/ws/game` - accepts connections (basic implementation OK)

### PubSub Implementation
- [ ] When sidekick joins → host receives `partner_joined` message
- [ ] When host starts → both receive `session_starting` message
- [ ] Lobby WS connections cleaned up when game starts

### In-Memory Storage (OK for Dev)
- [ ] Worlds stored in Map/Dict: `worlds[world_id] = worldData`
- [ ] Invite codes mapped to worlds: `codes[invite_code] = world_id`
- [ ] Players stored in Map/Dict: `players[player_id] = playerData`
- [ ] Sessions stored in Map/Dict: `sessions[session_id] = sessionData`

---

## 8. Testing with curl

### Create World (Host)
```bash
curl -X POST http://localhost:10000/worlds \
  -H "Content-Type: application/json" \
  -d '{"name":"Game","role":"detective","player_name":"HostPlayer"}'
```

Expected:
```json
{"world_id":"...","invite_code":"ABC123","player_id":"...","status":"waiting_for_partner"}
```

### Join World (Sidekick)
```bash
curl -X POST http://localhost:10000/worlds/ABC123/join \
  -H "Content-Type: application/json" \
  -d '{"player_name":"SidekickPlayer"}'
```

Expected:
```json
{"world_id":"...","player_id":"...","partner_id":"...","partner_name":"HostPlayer","status":"joined"}
```

### Start Session (Host)
```bash
curl -X POST http://localhost:10000/worlds/{world_id}/start \
  -H "Content-Type: application/json"
```

---

## 9. Auth Implementation (FUTURE - Low Priority)

When ready to add auth:

1. **Firebase Auth Verify**
   - Verify Firebase ID tokens
   - Extract `user_id` from token

2. **Token Format**
   ```
   Authorization: Bearer <firebase_id_token>
   ```

3. **Protected Endpoints**
   - All endpoints require valid token
   - Token maps to `user_id`

4. **Migration Path**
   - Add auth middleware
   - Keep `/dev/*` endpoints for testing
   - Require auth on production endpoints

---

## 10. Success Criteria (Revised)

✅ **Host can create game without authentication**  
✅ **Server generates 6-character invite code**  
✅ **Sidekick can join with code (no auth)**  
✅ **Host receives real-time notification when sidekick joins (PubSub)**  
✅ **Sidekick avatar appears on host screen within 1 second**  
✅ **Both players see each other in lobby**  
✅ **Host can start game, both transition to gameplay**  
✅ **No HTTP polling used for lobby synchronization**  

**Authentication: OPTIONAL / LOW PRIORITY**

---

*Document Version: 2.0 (Dev Focus)*  
*Priority: Core Multiplayer > Polish > Auth*
