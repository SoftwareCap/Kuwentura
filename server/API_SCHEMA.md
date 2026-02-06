# Kwentura API Response Schema

## POST /worlds
Create a new game world.

### Response (200 OK)
```json
{
  "world_id": "string",      // Internal world identifier (e.g., "w_1770402539799_0akid1yjf")
  "invite_code": "string",   // 6-character code for friends to join (e.g., "FHY3ZU")
  "role": "string",          // "detective" | "sidekick"
  "status": "string"         // "waiting" (until partner joins)
}
```

---

## POST /worlds/:inviteCode/join
Join an existing world using invite code.

### Response (200 OK)
```json
{
  "world_id": "string",
  "name": "string",          // World name (e.g., "Game")
  "role": "string",          // "detective" | "sidekick" (assigned automatically)
  "partner_id": "string",    // Firebase UID of the host
  "partner_name": "string",  // Display name of partner
  "status": "string"         // "ready" (both players present)
}
```

### Response (404 Not Found)
```json
{
  "error": "World not found"
}
```

### Response (403 Forbidden)
```json
{
  "error": "World is full"
}
```

---

## GET /users/me/worlds
List all worlds the authenticated user is part of.

### Response (200 OK)
```json
{
  "worlds": [
    {
      "world_id": "string",
      "name": "string",
      "role": "string",        // "detective" | "sidekick"
      "progress": {
        "story_chapter": 1,
        "zones_unlocked": ["starting_zone"],
        "puzzles_solved": [],
        "clues_found": [],
        "story_flags": {},
        "inventory_shared": [],
        "playtime_total_minutes": 0
      },
      "status": "string"       // "waiting" | "ready" | "active"
    }
  ]
}
```

---

## POST /worlds/:worldId/start
Start the game session (requires both players).

### Response (200 OK)
```json
{
  "session_id": "string",           // e.g., "s_1770402539799_xxxxxxxx"
  "ws_url": "string",               // WebSocket URL for game connection
  "checkpoint": "string",           // Starting zone ID
  "world_progress": {
    "story_chapter": 1,
    "zones_unlocked": ["starting_zone"],
    "puzzles_solved": [],
    "clues_found": [],
    "story_flags": {},
    "inventory_shared": [],
    "playtime_total_minutes": 0
  }
}
```

### Response (400 Bad Request)
```json
{
  "error": "PARTNER_NOT_CONNECTED",
  "message": "Waiting for sidekick"
}
```

### Response (403 Forbidden)
```json
{
  "error": "NOT_DETECTIVE",
  "message": "Only detective can start"
}
```

---

## GET /worlds/:worldId
Get detailed world information.

### Response (200 OK)
```json
{
  "world_id": "string",
  "name": "string",
  "my_role": "string",             // "detective" | "sidekick"
  "partner_id": "string | null",
  "partner_name": "string",
  "progress": {
    "story_chapter": 1,
    "zones_unlocked": ["starting_zone"],
    "puzzles_solved": [],
    "clues_found": [],
    "story_flags": {},
    "inventory_shared": [],
    "playtime_total_minutes": 0
  },
  "checkpoint": {
    "zone_id": "string",
    "position_detective": { "x": 100, "y": 200 },
    "position_sidekick": { "x": 110, "y": 200 }
  }
}
```

### Response (404 Not Found)
```json
{
  "error": "World not found"
}
```

### Response (403 Forbidden)
```json
{
  "error": "Not authorized"
}
```

---

## Error Response (401 Unauthorized)
Returned when authentication fails.

```json
{
  "error": "Unauthorized",
  "message": "Missing token" | "Invalid token"
}
```

---

## WebSocket Connection

### URL
```
ws://host:port/ws?session={sessionId}&token={jwt}
```

### Initial Message (Server → Client)
```json
{
  "type": "session_start",
  "timestamp": 1770402539799,
  "seq": 1,
  "data": {
    "session_id": "string",
    "your_role": "string",
    "your_player_id": "string",
    "partner": {
      "player_id": "string",
      "display_name": "string",
      "connected": true
    } | null,
    "checkpoint": {
      "zone_id": "string",
      "position_detective": { "x": 100, "y": 200 },
      "position_sidekick": { "x": 110, "y": 200 }
    },
    "world_progress": { ... },
    "session_state": {
      "time_of_day": "day",
      "weather": "clear",
      "active_objects": [],
      "active_npcs": [],
      "triggered_events": []
    }
  }
}
```

### Game Started Event
```json
{
  "type": "game_started",
  "timestamp": 1770402539799,
  "seq": 2,
  "data": {
    "checkpoint": "starting_zone"
  }
}
```

### Partner Status Event
```json
{
  "type": "partner_status",
  "timestamp": 1770402539799,
  "seq": 3,
  "data": {
    "status": "connected" | "disconnected",
    "player_id": "string",
    "display_name": "string"
  }
}
```

### Error Event
```json
{
  "type": "error",
  "timestamp": 1770402539799,
  "seq": 4,
  "data": {
    "code": "string",
    "message": "string",
    "fatal": false
  }
}
```

---

## Common Fields

### Progress Object
```json
{
  "story_chapter": 1,
  "zones_unlocked": ["string"],
  "puzzles_solved": ["string"],
  "clues_found": ["string"],
  "story_flags": {},
  "inventory_shared": ["string"],
  "playtime_total_minutes": 0
}
```

### Checkpoint Object
```json
{
  "zone_id": "string",
  "position_detective": { "x": number, "y": number },
  "position_sidekick": { "x": number, "y": number }
}
```
