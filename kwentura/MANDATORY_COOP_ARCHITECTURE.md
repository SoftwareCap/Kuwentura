# Mandatory 2-Player Co-op Architecture

> Both players MUST be connected. No solo play. Session is ephemeral, world progress persists.

---

## Core Constraint

**FUNDAMENTAL RULE**: Game requires BOTH players online
- No single-player mode
- Game pauses if either disconnects
- Session ends when either player leaves
- Only WORLD PROGRESS saves (not session state)

---

## Session Lifecycle

```
Session States:

[NO SESSION] 
	 |
	 | Host creates world
	 | Client joins world
	 v
[LOBBY] -------- Both players in menu, not playing
	 |
	 | Host clicks "Start Game"
	 v
[ACTIVE] ------- Both playing, world loaded
	 |          Server validates all actions
	 |          Auto-save progress every 30s
	 |
	 +- Player disconnects --> [PAUSED] --> Auto-save --> [SESSION END]
	 |
	 +- Host clicks "End Game" --> Auto-save --> [SESSION END]
											  
[SESSION END]
	 |
	 | Both return to main menu
	 | Can rejoin later to continue world
	 v
[NO SESSION]
```

---

## Architecture

### Simplified Model: Session = Game Instance

```
+-------------------------------------------------------------+
|                     CLOUD SERVER                            |
+-------------------------------------------------------------+
|                                                             |
|  +-----------------------------------------------------+   |
|  |  WORLD DATABASE (Persistent)                         |   |
|  |  +------------+  +------------+  +------------+      |   |
|  |  |  World A   |  |  World B   |  |  World C   |      |   |
|  |  |  - Progress|  |  - Progress|  |  - Progress|      |   |
|  |  |  - Puzzles |  |  - Puzzles |  |  - Puzzles |      |   |
|  |  |  - Chapter |  |  - Chapter |  |  - Chapter |      |   |
|  |  +------------+  +------------+  +------------+      |   |
|  +-----------------------------------------------------+   |
|                              ^                              |
|                              | Load at start / Save at end  |
|  +-----------------------------------------------------+   |
|  |  GAME SESSION (Ephemeral - only while playing)      |   |
|  |                                                      |   |
|  |     Player A <------> Server <------> Player B       |   |
|  |     (Detective)       (Authority)      (Sidekick)    |   |
|  |                                                      |   |
|  |  - Both must be connected                            |   |
|  |  - Server validates all actions                      |   |
|  |  - Session ends if either disconnects                |   |
|  |  - Progress saved to World DB                        |   |
|  +-----------------------------------------------------+   |
|                                                             |
+-------------------------------------------------------------+
```

---

## Data Model

### What Gets Saved (Persistent)

```javascript
// worlds/{world_id} - SURVIVES between sessions
{
  "world_id": "w_abc123",
  "name": "Mystery Island",
  "created_by": "user_A",
  "created_at": 1704067200,
  
  // PLAYERS in this world (fixed pair)
  "detective_id": "user_A",    // Host
  "sidekick_id": "user_B",     // Client
  
  // WORLD PROGRESS (accumulates over multiple sessions)
  "progress": {
	"story_chapter": 3,
	"zones_unlocked": ["forest", "cave", "village"],
	"puzzles_solved": ["p1", "p2", "p5"],
	"clues_found": ["c1", "c3", "c7"],
	"story_flags": {
	  "met_villager": true,
	  "found_key": false
	},
	"inventory_shared": ["lantern", "map"],
	"playtime_total_minutes": 450
  },
  
  // SESSION HISTORY
  "last_session": {
	"ended_at": 1706659200,
	"duration_minutes": 45,
	"ended_by": "disconnect",
	"checkpoint": "cave_entrance"
  },
  
  // STATUS
  "status": "active",
  "can_continue": true
}
```

### What Does NOT Get Saved (Session-Only)

```javascript
// GAME SESSION - EXISTS ONLY DURING PLAY
{
  "session_id": "s_xyz789",
  "world_id": "w_abc123",
  "started_at": 1706745600,
  
  // CURRENT POSITIONS - Reset to checkpoint on rejoin
  "player_positions": {
	"user_A": { "x": 100, "y": 200, "zone": "cave" },
	"user_B": { "x": 105, "y": 200, "zone": "cave" }
  },
  
  // TEMPORARY STATES
  "active_effects": [],
  "current_dialogue": null,
  "cutscene_playing": false,
  
  // CONNECTION STATUS
  "detective_connected": true,
  "sidekick_connected": true
}
```

---

## Game Flow

### Creating a World (Host Only)

1. Player A clicks "Create New Story"
2. Enters name: "The Missing Idol"
3. Selects role: Detective (host)
4. Server creates world with:
   - world_id: "w_abc123"
   - detective_id: "user_A"
   - sidekick_id: null (waiting)
   - invite_code: "XYZ789"
5. Shows waiting screen with invite code

### Joining a World (Partner)

1. Player B clicks "Join Story"
2. Enters code: "XYZ789"
3. Server assigns sidekick_id: "user_B"
4. Both players in LOBBY
5. Both show "Ready"
6. Host (Detective) clicks "Start Game"

### Playing the Game

1. Server creates GAME SESSION
2. Loads world progress
3. Resets positions to checkpoint
4. Both players spawn
5. Game is ACTIVE
6. All actions validated by server
7. Progress auto-saves every 30s

### If Disconnect Happens

1. Game PAUSES immediately
2. "Waiting for partner..." screen
3. Auto-save triggers
4. Options: "Save and Exit" or "Wait"
5. If partner reconnects within timeout: Resume
6. If timeout: Session ends

### Rejoining Later

1. Player A opens game
2. Sees "The Missing Idol" in Continue menu
3. Clicks "Invite Partner"
4. Partner gets notification
5. Partner joins
6. Both in lobby, continue from checkpoint

---

## Server Implementation

### Key API Endpoints

```javascript
// POST /worlds
// Create new world (host only)
Request: {
  "name": "The Missing Idol",
  "role": "detective"  // or "sidekick"
}
Response: {
  "world_id": "w_abc123",
  "invite_code": "XYZ789",
  "role": "detective",
  "status": "waiting"
}

// POST /worlds/:inviteCode/join
// Join existing world
Response: {
  "world_id": "w_abc123",
  "name": "The Missing Idol",
  "role": "sidekick",
  "partner_id": "user_A",
  "status": "ready"
}

// GET /users/me/worlds
// List my worlds for Continue menu
Response: {
  "worlds": [
	{
	  "world_id": "w_abc123",
	  "name": "The Missing Idol",
	  "role": "detective",
	  "partner_name": "PlayerB",
	  "partner_online": false,
	  "progress": { ... },
	  "can_continue": true
	}
  ]
}

// POST /worlds/:worldId/start
// Start game session (detective only)
Response: {
  "session_id": "s_xyz789",
  "ws_url": "wss://server.com/ws?session=s_xyz789",
  "checkpoint": "cave_entrance"
}
```

### WebSocket Messages

```javascript
// Client -> Server
{
  "type": "player_input",
  "data": { "direction": { "x": 1, "y": 0 } }
}

{
  "type": "action",
  "data": { "type": "collect_clue", "clue_id": "c8" }
}

{
  "type": "puzzle_attempt",
  "data": { "puzzle_id": "p3", "solution": [...] }
}

// Server -> Client
{
  "type": "session_joined",
  "data": {
	"role": "detective",
	"checkpoint": "cave_entrance",
	"progress": { ... },
	"partner_connected": true
  }
}

{
  "type": "partner_disconnected",
  "data": { "message": "Partner disconnected. Game paused." }
}

{
  "type": "action_result",
  "data": {
	"action": "collect_clue",
	"result": { "success": true, "clue_id": "c8" },
	"performed_by": "user_A"
  }
}

{
  "type": "game_resumed",
  "data": { "checkpoint": "cave_entrance", "progress": { ... } }
}
```

### Game Session Class (Pseudocode)

```javascript
class GameSession {
  constructor(worldId, detectiveId, sidekickId) {
	this.worldId = worldId;
	this.detectiveId = detectiveId;
	this.sidekickId = sidekickId;
	this.connections = new Map(); // userId -> WebSocket
	this.status = 'starting'; // starting, playing, paused, ended
	this.progress = loadProgress(worldId);
  }
  
  connect(userId, ws) {
	// Verify user is part of this world
	if (userId !== this.detectiveId && userId !== this.sidekickId) {
	  return false;
	}
	
	this.connections.set(userId, ws);
	
	// If both connected, start playing
	if (this.connections.size === 2) {
	  this.status = 'playing';
	  this.broadcast('game_resumed', { ... });
	}
	
	return true;
  }
  
  handleDisconnect(userId) {
	this.connections.delete(userId);
	this.status = 'paused';
	this.saveProgress();
	
	// Notify partner
	const partner = this.getPartner(userId);
	if (partner) {
	  partner.send('partner_disconnected', { ... });
	}
	
	// If no one left, end session
	if (this.connections.size === 0) {
	  this.end();
	}
  }
  
  handleAction(userId, action) {
	if (this.status !== 'playing') return;
	
	// Validate action
	if (!this.isValidAction(userId, action)) {
	  return;
	}
	
	// Apply action
	const result = this.applyAction(action);
	
	// Update progress
	if (result.progressUpdate) {
	  Object.assign(this.progress, result.progressUpdate);
	  this.saveProgress();
	}
	
	// Broadcast to both
	this.broadcast('action_result', {
	  action: action.type,
	  result: result,
	  performed_by: userId
	});
  }
  
  saveProgress() {
	saveToDatabase(this.worldId, this.progress);
  }
  
  end() {
	this.saveProgress();
	this.status = 'ended';
  }
}
```

---

## Godot Client Implementation

```gdscript
# scripts/systems/coop_network_manager.gd
extends Node

enum ConnectionState { 
	DISCONNECTED, 
	CONNECTING,
	IN_LOBBY,      # Both in menu, waiting to start
	STARTING,      # Loading game
	PLAYING,       # Game active
	PAUSED,        # Partner disconnected
	ENDED          # Session ended
}

var state: ConnectionState = ConnectionState.DISCONNECTED
var current_world: Dictionary = {}
var my_role: String = ""  # "detective" or "sidekick"
var ws: WebSocketPeer

signal world_created(world_data: Dictionary)
signal partner_joined(user_data: Dictionary)
signal game_started(checkpoint: String)
signal game_paused(reason: String)
signal game_resumed
signal partner_disconnected
signal progress_saved

const API_BASE: String = "https://your-api.com"

# ==================== WORLD CREATION (Host Only) ====================

func create_world(world_name: String, my_role_pref: String) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	
	var result = await http.request(
		API_BASE + "/worlds",
		["Authorization: Bearer " + auth_token, "Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"name": world_name,
			"role": my_role_pref
		})
	)
	
	var response = JSON.parse_string(result[3].get_string_from_utf8())
	
	if response.has("error"):
		return response
	
	current_world = response
	my_role = response.role
	state = ConnectionState.IN_LOBBY
	
	emit_signal("world_created", response)
	return response

# ==================== JOINING WORLD (Both) ====================

func join_world(invite_code: String) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	
	var result = await http.request(
		API_BASE + "/worlds/" + invite_code + "/join",
		["Authorization: Bearer " + auth_token],
		HTTPClient.METHOD_POST
	)
	
	var response = JSON.parse_string(result[3].get_string_from_utf8())
	
	if response.has("error"):
		return response
	
	current_world = response
	my_role = response.role
	state = ConnectionState.IN_LOBBY
	
	emit_signal("partner_joined", {
		"user_id": response.partner_id,
		"name": response.partner_name
	})
	
	return response

# ==================== STARTING GAME (Host Only) ====================

func start_game() -> bool:
	if my_role != "detective":
		push_error("Only detective can start the game")
		return false
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var result = await http.request(
		API_BASE + "/worlds/" + current_world.world_id + "/start",
		["Authorization: Bearer " + auth_token],
		HTTPClient.METHOD_POST
	)
	
	var response = JSON.parse_string(result[3].get_string_from_utf8())
	
	if not response.has("ws_url"):
		return false
	
	# Connect to game session
	return await _connect_session(response.ws_url, response.checkpoint)

# ==================== GAME SESSION ====================

func _connect_session(ws_url: String, checkpoint: String) -> bool:
	ws = WebSocketPeer.new()
	var err = ws.connect_to_url(ws_url + "?token=" + auth_token)
	
	if err != OK:
		return false
	
	state = ConnectionState.STARTING
	set_process(true)
	
	# Wait for connection
	var timeout = 0.0
	while ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		ws.poll()
		await get_tree().process_frame
		timeout += get_process_delta_time()
		if timeout > 10.0:
			return false
	
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	
	return true

func _process(delta):
	if not ws:
		return
	
	ws.poll()
	
	while ws.get_available_packet_count() > 0:
		var packet = ws.get_packet()
		var message = JSON.parse_string(packet.get_string_from_utf8())
		_handle_message(message)

func _handle_message(msg: Dictionary):
	match msg.type:
		"session_joined":
			_on_session_joined(msg.data)
			
		"partner_connected":
			if state == ConnectionState.IN_LOBBY:
				emit_signal("partner_joined", msg.data)
			elif state == ConnectionState.PAUSED:
				emit_signal("game_resumed")
				state = ConnectionState.PLAYING
				
		"partner_disconnected":
			state = ConnectionState.PAUSED
			emit_signal("game_paused", "partner_disconnected")
			emit_signal("partner_disconnected")
			
		"game_resumed":
			state = ConnectionState.PLAYING
			GameState.load_progress(msg.data.progress)
			emit_signal("game_resumed")
			
		"game_started":
			state = ConnectionState.PLAYING
			GameState.load_checkpoint(msg.data.checkpoint)
			GameState.load_progress(msg.data.progress)
			emit_signal("game_started", msg.data.checkpoint)
			
		"action_result":
			_apply_action_result(msg.data)
			
		"progress_saved":
			emit_signal("progress_saved")
			
		"session_ended":
			state = ConnectionState.ENDED
			emit_signal("session_ended", msg.data.final_progress)
			_cleanup()

func _on_session_joined(data: Dictionary):
	my_role = data.role
	
	if data.partner_connected:
		state = ConnectionState.PLAYING
		GameState.load_checkpoint(data.checkpoint)
		GameState.load_progress(data.progress)
		emit_signal("game_started", data.checkpoint)
	else:
		state = ConnectionState.IN_LOBBY
		show_waiting_for_partner()

# ==================== GAME ACTIONS ====================

func send_input(direction: Vector2):
	if state != ConnectionState.PLAYING:
		return
	_send("player_input", { "direction": { "x": direction.x, "y": direction.y }})

func perform_action(action_type: String, data: Dictionary = {}):
	if state != ConnectionState.PLAYING:
		return
	_send("action", { "type": action_type, "data": data })

func submit_puzzle(puzzle_id: String, solution: Dictionary):
	if state != ConnectionState.PLAYING:
		return
	_send("puzzle_attempt", { "puzzle_id": puzzle_id, "solution": solution })

func _send(type: String, data: Dictionary):
	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify({"type": type, "data": data}))

# ==================== SESSION MANAGEMENT ====================

func leave_session():
	if ws:
		ws.close()
	_cleanup()

func _cleanup():
	ws = null
	state = ConnectionState.DISCONNECTED
	set_process(false)
```

---

## UI Screens

### Main Menu

```
+-------------------------+
|      KWENTURA           |
+-------------------------+
|                         |
| [Continue Story]        |
|   Continue with partner |
|                         |
| [New Story]             |
|   Create new world      |
|   (Detective only)      |
|                         |
| [Join Story]            |
|   Enter invite code     |
|                         |
| [Settings]              |
+-------------------------+
```

### Continue Story List

```
+-------------------------+
|      YOUR STORIES       |
+-------------------------+
|                         |
| The Missing Idol        |
| You: Detective          |
| Partner: PlayerB        |
| Status: Offline         |
| Chapter 3 | 7.5 hours   |
|                         |
| [Invite Partner]        |
|                         |
+-------------------------+
|                         |
| The Cave Mystery        |
| You: Sidekick           |
| Partner: PlayerC        |
| Status: Online          |
| Chapter 1 | 2 hours     |
|                         |
| [Join Now]              |
|                         |
+-------------------------+
```

### Paused (Partner Disconnected)

```
+-------------------------+
|                         |
|   PARTNER DISCONNECTED  |
|                         |
| Your partner lost       |
| connection.             |
| Game is paused.         |
|                         |
| Progress saved.         |
|                         |
| [Save and Exit]         |
| [Wait for Partner]      |
|                         |
+-------------------------+
```

---

## Summary

| Aspect | Implementation |
|--------|---------------|
| **World Persistence** | Cloud database (Firestore) |
| **Session** | Ephemeral - only while both connected |
| **Roles** | Fixed at world creation (Detective = Host) |
| **Start Game** | Only Detective can initiate session |
| **Disconnect** | Game pauses, progress saved |
| **Rejoin** | Either can rejoin, game resumes from checkpoint |
| **Progress** | Accumulates across sessions |
| **Solo Play** | NOT POSSIBLE - requires partner |

This is the **"It Takes Two" / Portal 2 Co-op"** model - story only advances when both play together, but you can pause and continue later.
