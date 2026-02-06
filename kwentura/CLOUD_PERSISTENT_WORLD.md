# Cloud-Persistent World Architecture

> Server owns the map, both players can rejoin anytime. Only host can create rooms.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLOUD SERVER                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  WORLD DATABASE (Firestore / Redis / PostgreSQL)            │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │   │
│  │  │  World ABC   │  │  World DEF   │  │  World GHI   │      │   │
│  │  │  - Terrain   │  │  - Terrain   │  │  - Terrain   │      │   │
│  │  │  - Objects   │  │  - Objects   │  │  - Objects   │      │   │
│  │  │  - Puzzles   │  │  - Puzzles   │  │  - Puzzles   │      │   │
│  │  │  - Player A  │  │  - Player A  │  │  - Player A  │      │   │
│  │  │  - Player B  │  │  - Player B  │  │  - Player B  │      │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  RELAY SERVER (WebSocket)                                   │   │
│  │  ┌─────────────┐        ┌─────────────┐                     │   │
│  │  │  Room ABC   │◄──────►│  Session 1  │  (Active game)      │   │
│  │  │  host_id: A │        │  - Realtime │                     │   │
│  │  │  world_id:X │        │  - Sync     │                     │   │
│  │  └─────────────┘        └─────────────┘                     │   │
│  │  ┌─────────────┐        ┌─────────────┐                     │   │
│  │  │  Room DEF   │◄──────►│  Session 2  │  (Active game)      │   │
│  │  │  host_id: C │        │  - Realtime │                     │   │
│  │  │  world_id:Y │        │  - Sync     │                     │   │
│  │  └─────────────┘        └─────────────┘                     │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                               ▲
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
   │  Player A   │      │  Player B   │      │  Player C   │
   │  (Host)     │      │  (Client)   │      │  (Host)     │
   │             │      │             │      │             │
   │ Can create  │      │ Can join    │      │ Can create  │
   │ worlds      │      │ any world   │      │ worlds      │
   │ they own    │      │ they're in  │      │ they own    │
   └─────────────┘      └─────────────┘      └─────────────┘
```

---

## Key Principles

| Principle | Description |
|-----------|-------------|
| **Server Owns World** | World data lives in cloud, not on host device |
| **Host = Session Creator** | Only host can start a session to a world |
| **Both Can Rejoin** | Either player can reconnect to an existing world |
| **Host ≠ World Owner** | Host owns the *session*, server owns the *world* |
| **Auto-Save** | World saves to cloud continuously, not just on disconnect |

---

## Data Flow

### Creating a World (Host Only)

```
Player A (Host)                 Cloud Server
     │                               │
     │  1. POST /create-world        │
     │  { world_name: "Island" }     │
     │ ─────────────────────────────>│
     │                               │
     │  2. Create world document     │
     │     world_id: "w_abc123"      │
     │     owner: "user_A"           │
     │     players: ["user_A"]       │
     │                               │
     │<──────────────────────────────│
     │  { world_id, invite_code }    │
     │                               │
     │  3. POST /host-session        │
     │  { world_id: "w_abc123" }     │
     │ ─────────────────────────────>│
     │                               │
     │  4. Create room + WebSocket   │
     │     room_code: "XYZ789"       │
     │                               │
     │<──────────────────────────────│
     │  { ws_url, room_code }        │
     │                               │
```

### Joining a World (Both Players)

```
Player B (Client)               Cloud Server
     │                               │
     │  1. GET /worlds?user=user_B   │
     │ ─────────────────────────────>│
     │                               │
     │  2. Returns list of worlds    │
     │     where user_B is player    │
     │     - "Island" (with user_A)  │
     │     - "Cave" (with user_C)    │
     │                               │
     │<──────────────────────────────│
     │                               │
     │  3. User selects "Island"     │
     │                               │
     │  4. POST /join-session        │
     │  { world_id: "w_abc123" }     │
     │ ─────────────────────────────>│
     │                               │
     │  5. Check if session exists   │
     │     - YES: Return WS URL      │
     │     - NO: Tell user to wait   │
     │       for host                │
     │                               │
     │<──────────────────────────────│
     │  { ws_url } or { wait: true } │
```

### Gameplay - State Synchronization

```
Player A (Host)                 Server                    Player B (Client)
     │                            │                              │
     │  Input: Move Right         │                              │
     │  RPC: move_input(vec)      │                              │
     │ ───────────────────────────>│                              │
     │                            │  1. Validate & apply           │
     │                            │  2. Update world state         │
     │                            │  3. Broadcast to all           │
     │  RPC: state_update(pos)    │                              │
     │<───────────────────────────│─────────────────────────────>│
     │  Apply to visual           │  RPC: state_update(pos)        │
     │                            │                              │  Apply to visual
     │                            │                              │
     │                            │  [Auto-save every 30s]         │
     │                            │  Save world state to DB        │
```

---

## Server Implementation

### 1. World Service (REST API)

```javascript
// server/services/worldService.js
const { Firestore } = require('@google-cloud/firestore');
const db = new Firestore();

class WorldService {
    
    // Create new world (host only)
    async createWorld(hostUserId, worldName) {
        const worldId = `w_${this.generateId()}`;
        const inviteCode = this.generateCode(6);
        
        const worldData = {
            world_id: worldId,
            name: worldName,
            created_by: hostUserId,
            created_at: Date.now(),
            players: [hostUserId],  // Both players stored here
            host_id: hostUserId,    // Current session host
            invite_code: inviteCode,
            status: 'active',
            
            // Initial world state
            state: {
                version: 1,
                terrain_seed: Math.floor(Math.random() * 1000000),
                zones_unlocked: ['starting_zone'],
                puzzles_solved: [],
                objects_placed: [],
                story_chapter: 1,
                game_time: 0  // In-game time tracking
            },
            
            // Player states within this world
            player_states: {
                [hostUserId]: {
                    role: 'detective',
                    position: { x: 0, y: 0 },
                    inventory: [],
                    stats: {},
                    last_online: Date.now()
                }
            }
        };
        
        await db.collection('worlds').doc(worldId).set(worldData);
        
        // Add to user's world list
        await db.collection('users').doc(hostUserId)
            .collection('worlds').doc(worldId)
            .set({
                world_id: worldId,
                name: worldName,
                role: 'host',
                joined_at: Date.now(),
                last_played: Date.now()
            });
        
        return { worldId, inviteCode };
    }
    
    // Join existing world (by invite code)
    async joinWorld(userId, inviteCode) {
        const worldsRef = db.collection('worlds');
        const snapshot = await worldsRef
            .where('invite_code', '==', inviteCode.toUpperCase())
            .where('status', '==', 'active')
            .limit(1)
            .get();
        
        if (snapshot.empty) {
            throw new Error('World not found');
        }
        
        const worldDoc = snapshot.docs[0];
        const worldData = worldDoc.data();
        
        // Check if world already has 2 players
        if (worldData.players.length >= 2 && !worldData.players.includes(userId)) {
            throw new Error('World is full');
        }
        
        // Add player if not already in
        if (!worldData.players.includes(userId)) {
            worldData.players.push(userId);
            worldData.player_states[userId] = {
                role: 'sidekick',
                position: { x: 10, y: 0 },  // Spawn near host
                inventory: [],
                stats: {},
                last_online: Date.now()
            };
            
            await worldDoc.ref.update({
                players: worldData.players,
                player_states: worldData.player_states
            });
            
            // Add to user's world list
            await db.collection('users').doc(userId)
                .collection('worlds').doc(worldData.world_id)
                .set({
                    world_id: worldData.world_id,
                    name: worldData.name,
                    role: 'client',
                    joined_at: Date.now(),
                    last_played: Date.now()
                });
        }
        
        return worldData;
    }
    
    // Get all worlds for a user (for "Continue" menu)
    async getUserWorlds(userId) {
        const worldsSnapshot = await db.collection('users').doc(userId)
            .collection('worlds')
            .orderBy('last_played', 'desc')
            .get();
        
        const worlds = [];
        for (const doc of worldsSnapshot.docs) {
            const userWorld = doc.data();
            const worldDoc = await db.collection('worlds').doc(userWorld.world_id).get();
            
            if (worldDoc.exists) {
                const worldData = worldDoc.data();
                worlds.push({
                    world_id: worldData.world_id,
                    name: worldData.name,
                    invite_code: worldData.invite_code,
                    host_id: worldData.host_id,
                    is_host: worldData.created_by === userId,
                    last_played: userWorld.last_played,
                    story_chapter: worldData.state.story_chapter,
                    other_player: worldData.players.find(p => p !== userId),
                    session_active: await this.isSessionActive(worldData.world_id)
                });
            }
        }
        
        return worlds;
    }
    
    // Check if there's an active session for this world
    async isSessionActive(worldId) {
        const sessionRef = db.collection('sessions').doc(worldId);
        const session = await sessionRef.get();
        return session.exists && session.data().status === 'active';
    }
    
    // Save world state (called frequently during gameplay)
    async saveWorldState(worldId, state, playerStates) {
        await db.collection('worlds').doc(worldId).update({
            state: state,
            player_states: playerStates,
            last_saved: Date.now()
        });
    }
    
    generateId() {
        return Math.random().toString(36).substring(2, 10);
    }
    
    generateCode(length) {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        let code = '';
        for (let i = 0; i < length; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return code;
    }
}

module.exports = WorldService;
```

### 2. Session Service (WebSocket)

```javascript
// server/services/sessionService.js
const WebSocket = require('ws');

class SessionService {
    constructor(worldService) {
        this.worldService = worldService;
        this.sessions = new Map(); // worldId -> session
    }
    
    // Create new game session (host starts playing)
    async createSession(worldId, hostUserId) {
        // Verify user is host of this world
        const world = await this.worldService.getWorld(worldId);
        if (!world.players.includes(hostUserId)) {
            throw new Error('Not authorized to host this world');
        }
        
        const session = {
            world_id: worldId,
            host_id: hostUserId,
            clients: new Map(), // userId -> WebSocket
            state: world.state,
            player_states: world.player_states,
            last_activity: Date.now(),
            auto_save_interval: null
        };
        
        this.sessions.set(worldId, session);
        
        // Start auto-save
        session.auto_save_interval = setInterval(async () => {
            await this.saveSession(worldId);
        }, 30000); // Save every 30 seconds
        
        return session;
    }
    
    // Player connects to session
    async joinSession(worldId, userId, ws) {
        const session = this.sessions.get(worldId);
        
        if (!session) {
            // Session doesn't exist yet - host hasn't started
            return { error: 'session_not_started', message: 'Host has not started the session yet' };
        }
        
        if (!session.player_states[userId]) {
            return { error: 'not_in_world', message: 'You are not a player in this world' };
        }
        
        // Add to session
        session.clients.set(userId, ws);
        ws.userId = userId;
        ws.worldId = worldId;
        
        // Send initial state
        this.sendToClient(ws, 'initial_state', {
            world_state: session.state,
            your_state: session.player_states[userId],
            other_player: this.getOtherPlayerState(session, userId)
        });
        
        // Notify other player
        this.broadcastToOthers(worldId, userId, 'player_joined', {
            user_id: userId,
            state: session.player_states[userId]
        });
        
        return { success: true };
    }
    
    // Handle game messages
    handleMessage(worldId, userId, message) {
        const session = this.sessions.get(worldId);
        if (!session) return;
        
        const { type, data } = JSON.parse(message);
        
        switch (type) {
            case 'player_input':
                this.handlePlayerInput(session, userId, data);
                break;
                
            case 'player_action':
                this.handlePlayerAction(session, userId, data);
                break;
                
            case 'puzzle_solved':
                this.handlePuzzleSolved(session, userId, data);
                break;
                
            case 'zone_change':
                this.handleZoneChange(session, userId, data);
                break;
                
            case 'request_full_sync':
                this.sendFullSync(session, userId);
                break;
        }
    }
    
    // Server-authoritative: Process input and update state
    handlePlayerInput(session, userId, input) {
        const playerState = session.player_states[userId];
        
        // Validate and apply movement
        const newPosition = this.calculateNewPosition(
            playerState.position, 
            input.direction,
            input.delta
        );
        
        // Check collisions, bounds, etc.
        if (this.isValidPosition(session.state, newPosition)) {
            playerState.position = newPosition;
            
            // Broadcast to all clients
            this.broadcast(session.world_id, 'player_moved', {
                user_id: userId,
                position: newPosition,
                velocity: input.direction
            });
        }
    }
    
    // Server-authoritative: Handle important actions
    handlePlayerAction(session, userId, action) {
        switch (action.type) {
            case 'collect_clue':
                if (this.canCollectClue(session, userId, action.clue_id)) {
                    // Update world state
                    if (!session.state.clues_collected) {
                        session.state.clues_collected = [];
                    }
                    session.state.clues_collected.push(action.clue_id);
                    
                    // Notify both players
                    this.broadcast(session.world_id, 'clue_collected', {
                        clue_id: action.clue_id,
                        collected_by: userId
                    });
                    
                    // Immediate save for important events
                    this.saveSession(session.world_id);
                }
                break;
                
            case 'interact':
                // Validate interaction
                const result = this.processInteraction(session, userId, action.target);
                this.broadcast(session.world_id, 'interaction_result', {
                    target: action.target,
                    result: result,
                    triggered_by: userId
                });
                break;
        }
    }
    
    // Handle puzzle completion
    handlePuzzleSolved(session, userId, data) {
        const { puzzle_id, solution } = data;
        
        // Server validates the solution
        if (this.validatePuzzleSolution(session, puzzle_id, solution)) {
            session.state.puzzles_solved.push(puzzle_id);
            
            // Unlock new zones, etc.
            const rewards = this.getPuzzleRewards(puzzle_id);
            for (const zone of rewards.unlocked_zones || []) {
                session.state.zones_unlocked.push(zone);
            }
            
            // Broadcast success
            this.broadcast(session.world_id, 'puzzle_solved', {
                puzzle_id: puzzle_id,
                solved_by: userId,
                rewards: rewards
            });
            
            // Immediate save
            this.saveSession(session.world_id);
        } else {
            // Notify player of failure
            this.sendToClient(session.clients.get(userId), 'puzzle_failed', {
                puzzle_id: puzzle_id
            });
        }
    }
    
    // Save session state to database
    async saveSession(worldId) {
        const session = this.sessions.get(worldId);
        if (!session) return;
        
        await this.worldService.saveWorldState(
            worldId,
            session.state,
            session.player_states
        );
        
        session.last_activity = Date.now();
    }
    
    // Player disconnects
    async handleDisconnect(worldId, userId) {
        const session = this.sessions.get(worldId);
        if (!session) return;
        
        session.clients.delete(userId);
        session.player_states[userId].last_online = Date.now();
        
        // Save immediately on disconnect
        await this.saveSession(worldId);
        
        // Notify other player
        this.broadcastToOthers(worldId, userId, 'player_disconnected', {
            user_id: userId
        });
        
        // If host disconnects, session continues but marks host as offline
        // If both disconnect, clean up after delay
        if (session.clients.size === 0) {
            setTimeout(async () => {
                const currentSession = this.sessions.get(worldId);
                if (currentSession && currentSession.clients.size === 0) {
                    await this.endSession(worldId);
                }
            }, 60000); // Wait 1 minute before ending session
        }
    }
    
    // End session (both players left)
    async endSession(worldId) {
        const session = this.sessions.get(worldId);
        if (!session) return;
        
        // Final save
        await this.saveSession(worldId);
        
        // Clear auto-save
        if (session.auto_save_interval) {
            clearInterval(session.auto_save_interval);
        }
        
        // Remove session
        this.sessions.delete(worldId);
        
        console.log(`Session ended for world ${worldId}`);
    }
    
    // Helper methods
    sendToClient(ws, type, data) {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type, data }));
        }
    }
    
    broadcast(worldId, type, data) {
        const session = this.sessions.get(worldId);
        if (!session) return;
        
        const message = JSON.stringify({ type, data });
        for (const [userId, ws] of session.clients) {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(message);
            }
        }
    }
    
    broadcastToOthers(worldId, excludeUserId, type, data) {
        const session = this.sessions.get(worldId);
        if (!session) return;
        
        const message = JSON.stringify({ type, data });
        for (const [userId, ws] of session.clients) {
            if (userId !== excludeUserId && ws.readyState === WebSocket.OPEN) {
                ws.send(message);
            }
        }
    }
    
    getOtherPlayerState(session, userId) {
        for (const [id, state] of Object.entries(session.player_states)) {
            if (id !== userId) {
                return { user_id: id, ...state };
            }
        }
        return null;
    }
}

module.exports = SessionService;
```

### 3. WebSocket Server Setup

```javascript
// server/websocket.js
const WebSocket = require('ws');
const http = require('http');

function createWebSocketServer(sessionService) {
    const server = http.createServer();
    const wss = new WebSocket.Server({ server });
    
    wss.on('connection', async (ws, req) => {
        // Parse URL parameters
        const url = new URL(req.url, 'http://localhost');
        const worldId = url.searchParams.get('world');
        const token = url.searchParams.get('token');
        
        // Verify token and get userId (implement JWT verification)
        const userId = await verifyToken(token);
        if (!userId) {
            ws.close(1008, 'Invalid token');
            return;
        }
        
        // Join session
        const result = await sessionService.joinSession(worldId, userId, ws);
        
        if (result.error) {
            ws.close(1008, result.error);
            return;
        }
        
        // Handle messages
        ws.on('message', (message) => {
            sessionService.handleMessage(worldId, userId, message);
        });
        
        // Handle disconnect
        ws.on('close', () => {
            sessionService.handleDisconnect(worldId, userId);
        });
        
        // Send heartbeat to keep connection alive
        const heartbeat = setInterval(() => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.ping();
            }
        }, 30000);
        
        ws.on('close', () => {
            clearInterval(heartbeat);
        });
    });
    
    return server;
}

module.exports = createWebSocketServer;
```

---

## Godot Client Implementation

### 1. Network Manager (Updated)

```gdscript
# scripts/systems/network_manager.gd
extends Node

const API_BASE: String = "https://your-api.com"
const WS_BASE: String = "wss://your-api.com/ws"

enum State { DISCONNECTED, CONNECTING, CONNECTED, IN_GAME }
var state: State = State.DISCONNECTED

var auth_token: String = ""
var current_world: Dictionary = {}
var ws: WebSocketPeer

signal world_created(world_data: Dictionary)
signal world_joined(world_data: Dictionary)
signal player_connected(user_id: String)
signal player_disconnected(user_id: String)
signal state_synced(world_state: Dictionary)
signal connection_error(error: String)

# ==================== WORLD MANAGEMENT ====================

# HOST: Create new world
func create_world(world_name: String) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)
    
    var headers = [
        "Authorization: Bearer " + auth_token,
        "Content-Type: application/json"
    ]
    
    var body = JSON.stringify({ "world_name": world_name })
    
    var result = await http.request(
        API_BASE + "/worlds",
        headers,
        HTTPClient.METHOD_POST,
        body
    )
    
    if result[0] != HTTPRequest.RESULT_SUCCESS:
        return { "error": "Request failed" }
    
    var response = JSON.parse_string(result[3].get_string_from_utf8())
    
    if response.has("error"):
        return response
    
    current_world = response
    emit_signal("world_created", current_world)
    return response

# HOST: Start session (host the world)
func host_session() -> bool:
    if current_world.is_empty():
        push_error("No world selected")
        return false
    
    # Tell server to create session
    var http = HTTPRequest.new()
    add_child(http)
    
    var headers = ["Authorization: Bearer " + auth_token]
    var result = await http.request(
        API_BASE + "/worlds/" + current_world.world_id + "/host",
        headers,
        HTTPClient.METHOD_POST
    )
    
    var response = JSON.parse_string(result[3].get_string_from_utf8())
    
    if response.has("ws_url"):
        return await _connect_websocket(response.ws_url)
    
    return false

# BOTH: Join existing session
func join_session(world_id: String) -> bool:
    var http = HTTPRequest.new()
    add_child(http)
    
    var headers = ["Authorization: Bearer " + auth_token]
    var result = await http.request(
        API_BASE + "/worlds/" + world_id + "/join",
        headers,
        HTTPClient.METHOD_POST
    )
    
    var response = JSON.parse_string(result[3].get_string_from_utf8())
    
    if response.has("error"):
        if response.error == "session_not_started":
            emit_signal("connection_error", "Host hasn't started yet. Please wait.")
        return false
    
    if response.has("ws_url"):
        current_world = { "world_id": world_id }
        return await _connect_websocket(response.ws_url)
    
    return false

# Get list of worlds for "Continue" menu
func get_my_worlds() -> Array:
    var http = HTTPRequest.new()
    add_child(http)
    
    var headers = ["Authorization: Bearer " + auth_token]
    var result = await http.request(
        API_BASE + "/users/me/worlds",
        headers
    )
    
    var response = JSON.parse_string(result[3].get_string_from_utf8())
    return response.get("worlds", [])

# ==================== WEBSOCKET CONNECTION ====================

func _connect_websocket(ws_url: String) -> bool:
    ws = WebSocketPeer.new()
    var err = ws.connect_to_url(ws_url + "?token=" + auth_token)
    
    if err != OK:
        return false
    
    state = State.CONNECTING
    set_process(true)
    
    # Wait for connection
    var timeout = 0.0
    while ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
        ws.poll()
        await get_tree().process_frame
        timeout += get_process_delta_time()
        if timeout > 10.0:
            return false
    
    if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        state = State.CONNECTED
        return true
    
    return false

func _process(delta):
    if ws:
        ws.poll()
        
        while ws.get_available_packet_count() > 0:
            var packet = ws.get_packet()
            var message = JSON.parse_string(packet.get_string_from_utf8())
            _handle_message(message)

func _handle_message(message: Dictionary):
    match message.type:
        "initial_state":
            _apply_initial_state(message.data)
            
        "player_joined":
            emit_signal("player_connected", message.data.user_id)
            
        "player_disconnected":
            emit_signal("player_disconnected", message.data.user_id)
            
        "player_moved":
            _update_player_position(message.data)
            
        "clue_collected":
            GameState.collect_clue(message.data.clue_id)
            
        "puzzle_solved":
            _on_puzzle_solved(message.data)
            
        "state_update":
            _apply_world_state(message.data)

# ==================== GAME ACTIONS ====================

# Send input to server (server-authoritative)
func send_player_input(direction: Vector2, delta: float):
    if state != State.CONNECTED:
        return
    
    _send_message("player_input", {
        "direction": { "x": direction.x, "y": direction.y },
        "delta": delta
    })

# Request action (validated by server)
func request_action(action_type: String, data: Dictionary):
    _send_message("player_action", {
        "type": action_type,
        "data": data
    })

# Report puzzle solution
func submit_puzzle_solution(puzzle_id: String, solution: Dictionary):
    _send_message("puzzle_solved", {
        "puzzle_id": puzzle_id,
        "solution": solution
    })

func _send_message(type: String, data: Dictionary):
    if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        var message = JSON.stringify({ "type": type, "data": data })
        ws.send_text(message)

# ==================== STATE APPLICATION ====================

func _apply_initial_state(data: Dictionary):
    GameState.load_world_state(data.world_state)
    GameState.load_player_state(data.your_state)
    
    if data.other_player:
        GameState.load_other_player(data.other_player)
    
    state = State.IN_GAME
    emit_signal("state_synced", data.world_state)

func _update_player_position(data: Dictionary):
    var player = GameState.get_player(data.user_id)
    if player:
        player.sync_position = Vector2(data.position.x, data.position.y)

func _apply_world_state(data: Dictionary):
    GameState.load_world_state(data)

func _on_puzzle_solved(data: Dictionary):
    GameState.mark_puzzle_solved(data.puzzle_id)
    # Show rewards, unlock zones, etc.
    UIManager.show_puzzle_complete(data.rewards)
```

---

## UI Flow

### Host Flow

```
Main Menu
    │
    ├── [Create New World]
    │       │
    │       ▼
    │   "Enter World Name:"
    │   [Mystery Island] [Create]
    │       │
    │       ▼
    │   World created!
    │   Invite Code: ABC123
    │   [Copy Code] [Start Game]
    │       │
    │       ▼
    │   Connecting to server...
    │   [Waiting for sidekick...]
    │
    └── [Continue]
            │
            ▼
    Your Worlds:
    ┌────────────────────────────────┐
    │ Mystery Island    [Host]       │
    │ Chapter 3 • Last: 2 days ago   │
    │ [Continue] [Invite New Player] │
    ├────────────────────────────────┤
    │ The Cave         [Host]        │
    │ Chapter 1 • Last: 1 week ago   │
    │ [Continue] [Invite New Player] │
    └────────────────────────────────┘
```

### Client Flow

```
Main Menu
    │
    ├── [Join with Code]
    │       │
    │       ▼
    │   "Enter Code:"
    │   [ABC123] [Join]
    │       │
    │       ▼
    │   Joining Mystery Island...
    │   Hosted by DetectiveMike
    │   [Connecting...]
    │
    └── [Continue]
            │
            ▼
    Worlds You've Joined:
    ┌────────────────────────────────┐
    │ Mystery Island                 │
    │ Host: DetectiveMike            │
    │ Chapter 3 • Last: 2 days ago   │
    │ Status: Host online [Join]     │
    │         Host offline [Wait]    │
    ├────────────────────────────────┤
    │ The Cave                       │
    │ Host: ExplorerJane             │
    │ Chapter 2 • Last: 3 days ago   │
    │ Status: Host offline [Notify]  │
    └────────────────────────────────┘
```

---

## Deployment Architecture

### Recommended Stack

| Component | Technology | Cost (Monthly) |
|-----------|-----------|----------------|
| **Database** | Firebase Firestore | Pay per use (~$5-20) |
| **API Server** | Cloud Run / Railway | $0-10 |
| **WebSocket Server** | Cloud Run (with WebSocket support) or Railway | $5-20 |
| **Hosting** | Cloudflare / Vercel (frontend) | $0-5 |

### Scaling Considerations

```
Small Scale (1-100 concurrent worlds):
├── Single API server (Cloud Run)
├── Single WebSocket server
└── Firestore (serverless)

Medium Scale (100-1000 concurrent worlds):
├── Load balanced API servers
├── Multiple WebSocket servers (sticky sessions)
└── Firestore with caching (Redis)

Large Scale (1000+ concurrent worlds):
├── Regional API servers
├── Regional WebSocket clusters
├── Firestore + BigQuery for analytics
└── CDN for static assets
```

---

## Migration from Current System

Your current system uses host-owned worlds. Here's how to migrate:

### Phase 1: Add Cloud Persistence (2 weeks)
1. Keep current P2P WebSocket relay
2. Add `save_world_to_cloud()` and `load_world_from_cloud()` RPCs
3. Host saves world to Firebase after every session

### Phase 2: Server Authority (2 weeks)  
1. Move game logic validation to server
2. Server validates all actions before applying
3. Host is just a "session initiator"

### Phase 3: Full Migration (2 weeks)
1. Replace P2P with client-server
2. Both players connect to server (not to each other)
3. Server owns world state completely

---

## Summary

| Feature | Old System (Host-Owned) | New System (Cloud-Owned) |
|---------|------------------------|--------------------------|
| **World Storage** | Host's device | Cloud database |
| **Who Can Host** | Only world creator | Anyone in the world |
| **Rejoin** | Only if original host online | Anytime, independent |
| **Cheat Prevention** | Client-side | Server-validated |
| **Offline Play** | Yes (host only) | No (requires connection) |
| **Complexity** | Low | Medium |
| **Cost** | Free | Small monthly cost |

This architecture gives you **Minecraft Realms** style functionality - persistent worlds that either player can access independently, with the server as the ultimate authority.