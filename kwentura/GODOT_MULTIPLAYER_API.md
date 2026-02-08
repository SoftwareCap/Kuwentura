# Godot High-Level Multiplayer API

> **Goal**: Enable unique pairs of far-away players to play together without network/server interruption or failure.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Components](#core-components)
3. [Network Topology for 1v1 Pairs](#network-topology-for-1v1-pairs)
4. [Connection Protocol Schema](#connection-protocol-schema)
5. [RPC (Remote Procedure Call) System](#rpc-remote-procedure-call-system)
6. [MultiplayerSynchronizer & State Replication](#multiplayersynchronizer--state-replication)
7. [Resilience Patterns for Far-Away Players](#resilience-patterns-for-far-away-players)
8. [Implementation Example](#implementation-example)
9. [Common Pitfalls & Solutions](#common-pitfalls--solutions)

---

## Architecture Overview

Godot's High-Level Multiplayer API abstracts low-level networking into a **scene-aware** system. Instead of manually sending bytes, you work with:

- **Nodes** as the unit of network identity
- **RPCs** to call functions across the network
- **Automatic variable synchronization** via MultiplayerSynchronizer
- **Automatic node spawning** via MultiplayerSpawner

```
                    YOUR GAME SCENE
    +-------------+    +-------------+    +---------------------+
    |   Player 1  |<--> | Multiplayer |<--> |    Player 2         |
    |  (Local)    |    |   API       |    |  (Remote)           |
    +-------------+    +------+------+    +---------------------+
                              |
              +---------------+---------------+
              v               v               v
       +-----------+  +-----------+  +-----------+
       |    RPC    |  |   Sync    |  |   Spawn   |
       |  System   |  | Variables |  |  System   |
       +-----------+  +-----------+  +-----------+
```

---

## Core Components

### 1. MultiplayerPeer

The transport layer abstraction. Godot provides several implementations:

| Peer Type | Use Case | Best For |
|-----------|----------|----------|
| `ENetMultiplayerPeer` | UDP-based, low latency | LAN, direct connection with port forwarding |
| `WebSocketMultiplayerPeer` | TCP-based, NAT-friendly | WAN, relay servers, Web exports |
| `WebRTC` | P2P with NAT traversal | Direct browser-to-browser |

**For far-away players without port forwarding**: Use **WebSocket** with a relay server (as in your current project).

### 2. SceneMultiplayer

The default implementation of `MultiplayerAPI`. It:
- Assigns unique network IDs to peers (Server = 1, Clients = 2, 3, 4...)
- Routes RPCs to the correct nodes
- Manages network ownership (authority)

```gdscript
# Access the multiplayer API anywhere
var id = multiplayer.get_unique_id()  # Your network ID
var is_server = multiplayer.is_server()  # Are we the server?
```

### 3. Network Authority - SERVER IS THE SOURCE OF TRUTH

Every node has a **multiplayer authority** - the peer that "owns" it:

```gdscript
# Set authority (usually on spawn)
node.set_multiplayer_authority(peer_id)

# Check authority
if node.is_multiplayer_authority():
    # Only the authority can modify this node
    pass
```

**GOLDEN RULE FOR 1v1 GAMES**: 
- **Server (Host) = Authority**: Validates ALL game events, owns world state, prevents cheating
- **Client = Dumb Terminal**: Only sends inputs/actions, receives validated results

```gdscript
# WRONG - Client authoritative (vulnerable to cheating)
@rpc("any_peer", "reliable")
func player_moved_to(position: Vector2):
    # Client says "I'm at position X" - TRUSTED (BAD!)
    self.position = position

# CORRECT - Server authoritative
@rpc("any_peer", "reliable")
func player_input(direction: Vector2):
    if not multiplayer.is_server():
        return  # Only server processes
    
    # Server validates and applies movement
    if is_valid_move(direction):
        apply_movement(direction)
        broadcast_position.rpc(position)  # Server tells clients where player is
```

---

## Network Topology for 1v1 Pairs

For two far-away players, you have three architecture options:

### Option A: Listen Server (Host-Client)

```
Player A (Host) <-----> Player B (Client)
     |                       |
   [Acts as           [Connects to
   Server]            Host's IP]
```

- **Pros**: No dedicated server needed
- **Cons**: Host has advantage (0 latency), host disconnection = game over

### Option B: Dedicated Relay Server (Your Current Approach)

```
Player A <------> Relay Server <------> Player B
  (WebSocket)    (Cloud/Static IP)    (WebSocket)
```

- **Pros**: Works through NAT/firewalls, both players equal
- **Cons**: Relay server is a single point of failure

### Option C: Redundant Relay with Reconnection

```
         +----------+
Player A |  Relay   | Player B
<-------> |  Server  | <------->
         |  (Main)  |
         +-----+----+
               |
         +-----+-----+
         |  Backup   |
         |  Relay    |
         +-----------+
```

- **Pros**: High availability
- **Cons**: More complex, requires state synchronization between relays

---

## Connection Protocol Schema

### Binary Protocol (Godot's Built-in)

Godot uses a **binary serialization format** (not JSON/text). The protocol consists of:

```
+----------+----------+--------------+-------------+
|  Type    |  Flags   |  Target ID   |   Payload   |
|  (1 byte)|  (1 byte)|  (4 bytes)   |  (variable) |
+----------+----------+--------------+-------------+
```

**Message Types**:
| Type | Value | Description |
|------|-------|-------------|
| `REMOTE_CALL` | 0 | RPC invocation |
| `REMOTE_SET` | 1 | Variable replication |
| `NODE_ADD` | 2 | Spawn node |
| `NODE_REMOVE` | 3 | Despawn node |

**Variant Encoding**: All data is encoded using Godot's `Variant` system:
- Integers: Variable-length (zigzag + varint)
- Floats: 32-bit or 64-bit IEEE 754
- Strings: Length-prefixed UTF-8
- Objects: Type + property dictionary

### WebSocket Frame (Transport Layer)

When using WebSocketMultiplayerPeer:

```
+--------------------------------------------------+
|  WebSocket Frame (Binary Opcode = 0x02)          |
+--------------------------------------------------+
|  FIN | RSV | Opcode | MASK | Payload Length | ...|
|  1b  | 3b  |  4b    |  1b  |     7/16/64b   |    |
+--------------------------------------------------+
                         |
                         v
              +--------------------+
              | Godot Multiplayer  |
              |  Binary Payload    |
              +--------------------+
```

---

## RPC (Remote Procedure Call) System

**FUNDAMENTAL PRINCIPLE**: Clients request, Server decides.

### Server-Authoritative Pattern

```gdscript
extends Node

# CLIENT sends INPUT (not results)
@rpc("any_peer", "reliable")
func request_move(direction: Vector2):
    if not multiplayer.is_server():
        return  # SECURITY: Only server validates
    
    var player = get_player(multiplayer.get_remote_sender_id())
    
    # Server VALIDATES the request
    if can_move(player, direction):
        # Server APPLIES the action
        player.move(direction)
        # Server BROADCASTS the result to all clients
        sync_player_position.rpc(player.position)

# Server broadcasts final state
@rpc("authority", "reliable")
func sync_player_position(new_position: Vector2):
    # Clients receive and display (no validation needed)
    self.position = new_position
```

### RPC Configuration for Authority

| Mode | Use Case | Security Level |
|------|----------|----------------|
| `"authority"` | Server-owned functions (game rules, state changes) | High |
| `"any_peer"` | Client input submission (must be validated by server) | Medium |

### RPC Configuration Options

| Mode | Who Can Call | Where It Executes |
|------|--------------|-------------------|
| `"authority"` | Only the node's authority | Configured target |
| `"any_peer"` | Any connected peer | Configured target |

| Transfer Mode | Behavior | Use Case |
|---------------|----------|----------|
| `"reliable"` | Guaranteed, ordered delivery | Game events, state changes |
| `"unreliable"` | Fast, may drop/reorder | Player position, rotation |
| `"unreliable_ordered"` | Fast, ordered, may drop | Continuous animations |

| Call Target | Behavior |
|-------------|----------|
| `("call_remote",)` | Execute only on remote peers |
| `("call_local",)` | Execute on caller AND remotes |

### Calling RPCs

```gdscript
# Call on all peers (including self if call_local)
my_function.rpc()

# Call on specific peer only
my_function.rpc_id(target_peer_id)

# Call on server only (from client)
my_function.rpc_id(1)
```

---

## MultiplayerSynchronizer & State Replication

For automatic variable syncing without manual RPCs:

### Setup

```gdscript
# In your player scene
extends CharacterBody2D

@export var sync_position: Vector2
@export var sync_velocity: Vector2

func _ready():
    # Only simulate physics if we're the authority
    set_physics_process(is_multiplayer_authority())

func _physics_process(delta):
    # Local input -> movement
    velocity = Input.get_vector("left", "right", "up", "down") * speed
    move_and_slide()
    
    # Update sync variables (authority only)
    sync_position = position
    sync_velocity = velocity
```

### Configuration via Editor

1. Add **MultiplayerSynchronizer** node to your scene
2. Set **Replication Interval** (e.g., 0.05 for 20Hz)
3. Add properties to sync in the **Replication** tab
4. Choose **On Change** (delta compression) or **Always**

### Delta Compression

Godot automatically optimizes:

```
Frame 1: Send full position (100, 200)
Frame 2: Position unchanged -> Skip (or send minimal keepalive)
Frame 3: Position (102, 200) -> Send only delta (+2, 0)
```

**Bandwidth optimization for far-away players**:
- Use `unreliable` for position (slight jitter acceptable)
- Use `reliable` for critical state (health, inventory)
- Interpolate between sync frames for smooth visuals

---

## Resilience Patterns for Far-Away Players

### 1. Connection Health Monitoring

```gdscript
extends Node

const PING_INTERVAL := 2.0
const TIMEOUT_THRESHOLD := 10.0

var last_ping_time: Dictionary = {}  # peer_id -> time
var ping_results: Dictionary = {}    # peer_id -> latency_ms

func _ready():
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(peer_id: int):
    last_ping_time[peer_id] = Time.get_unix_time_from_system()
    start_ping_loop(peer_id)

@rpc("any_peer", "unreliable")
func ping(timestamp: float):
    # Echo back with same timestamp
    pong.rpc_id(multiplayer.get_remote_sender_id(), timestamp)

@rpc("authority", "unreliable")
func pong(original_timestamp: float):
    var latency = (Time.get_unix_time_from_system() - original_timestamp) * 1000
    var sender = multiplayer.get_remote_sender_id()
    ping_results[sender] = latency
    last_ping_time[sender] = Time.get_unix_time_from_system()
    
    if latency > 200:
        push_warning("High latency to peer %d: %.1f ms" % [sender, latency])
```

### 2. Graceful Degradation

```gdscript
# Detect poor connection and reduce sync frequency
func _process(delta):
    if ping_results.get(opponent_id, 0) > 150:
        # High latency - reduce sync rate, increase interpolation
        synchronizer.public_visibility = false
        synchronizer.replication_interval = 0.1  # 10Hz instead of 20Hz
    else:
        synchronizer.replication_interval = 0.05  # 20Hz
```

### 3. Disconnection Recovery

```gdscript
# Save game state periodically for reconnection
var state_checksum: int = 0
var state_history: Array = []  # Last 60 frames (1 second)

func _physics_process(_delta):
    if multiplayer.is_server():
        var state = capture_game_state()
        state_history.push_back(state)
        if state_history.size() > 60:
            state_history.pop_front()

# Allow reconnection with state sync
@rpc("authority", "reliable")
func request_state_sync():
    var current_state = capture_game_state()
    sync_full_state.rpc_id(multiplayer.get_remote_sender_id(), current_state)

@rpc("authority", "reliable")
func sync_full_state(state: Dictionary):
    restore_game_state(state)
```

### 4. Relay Server Fallback

```gdscript
const RELAY_URLS = [
    "wss://relay-us.example.com:10001",
    "wss://relay-eu.example.com:10001", 
    "wss://relay-asia.example.com:10001"
]

var current_relay_index: int = 0

func connect_with_fallback():
    while current_relay_index < RELAY_URLS.size():
        var url = RELAY_URLS[current_relay_index]
        if try_connect(url):
            return true
        current_relay_index += 1
    return false  # All relays failed
```

---

## Implementation Example

### Complete 1v1 Setup with Relay

```gdscript
# network_manager.gd - Simplified resilient version
extends Node

const MAX_PLAYERS := 2

enum State { DISCONNECTED, CONNECTING, CONNECTED, HOSTING }
var state: State = State.DISCONNECTED

var peer: WebSocketMultiplayerPeer
var opponent_id: int = -1

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_lost

func _ready():
    # Wire up multiplayer signals
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_failed)
    multiplayer.server_disconnected.connect(_on_server_lost)

func host_game(relay_url: String) -> bool:
    peer = WebSocketMultiplayerPeer.new()
    var err = peer.create_server(0)  # 0 = let OS assign port
    if err != OK:
        return false
    
    multiplayer.multiplayer_peer = peer
    state = State.HOSTING
    
    # Register with relay (your matchmaking service)
    register_with_relay(relay_url)
    return true

func join_game(relay_url: String) -> bool:
    peer = WebSocketMultiplayerPeer.new()
    var err = peer.create_client(relay_url)
    if err != OK:
        return false
    
    multiplayer.multiplayer_peer = peer
    state = State.CONNECTING
    return true

func _on_peer_connected(peer_id: int):
    if multiplayer.is_server():
        opponent_id = peer_id
    else:
        opponent_id = 1  # Server's ID is always 1
    
    state = State.CONNECTED
    player_connected.emit(peer_id)
    
    # Immediately sync initial state
    if multiplayer.is_server():
        sync_initial_state.rpc_id(peer_id)

func _on_peer_disconnected(peer_id: int):
    player_disconnected.emit(peer_id)
    opponent_id = -1
    state = State.DISCONNECTED

func _on_server_lost():
    connection_lost.emit()
    cleanup_connection()

# RPC EXAMPLES =========================================================

@rpc("any_peer", "reliable")
func player_moved(new_position: Vector2, velocity: Vector2):
    var sender = multiplayer.get_remote_sender_id()
    if sender != opponent_id:
        return  # Security: ignore unknown peers
    
    # Apply to remote player representation
    get_remote_player().update_state(new_position, velocity)

@rpc("any_peer", "reliable")
func game_action(action_type: String, data: Dictionary):
    var sender = multiplayer.get_remote_sender_id()
    if not multiplayer.is_server():
        return  # Only server processes actions
    
    # Validate and apply
    match action_type:
        "interact": handle_interact(sender, data)
        "use_item": handle_item_use(sender, data)

@rpc("authority", "reliable")
func sync_initial_state(game_data: Dictionary):
    # Client receives initial world state from host
    GameState.load(game_data)

@rpc("authority", "reliable")
func game_event(event_type: String, event_data: Dictionary):
    # Server broadcasts events to both players
    match event_type:
        "puzzle_solved": show_puzzle_complete(event_data)
        "zone_unlocked": unlock_new_zone(event_data)

func cleanup_connection():
    if peer:
        peer.close()
    multiplayer.multiplayer_peer = null
    state = State.DISCONNECTED
    opponent_id = -1
```

---

## Common Pitfalls & Solutions

| Problem | Cause | Solution |
|---------|-------|----------|
| Desync between players | Clock drift, packet loss | Use timestamped inputs, reconcile on server |
| "Rubber banding" | Late corrections from authority | Enable client-side prediction with server reconciliation |
| High latency spikes | Network jitter, relay overload | Implement input buffering (2-3 frame delay) |
| Client can cheat | Client authoritative design | Server validates all actions, client is "dumb terminal" |
| Memory leaks | Peers not properly cleaned up | Always set `multiplayer.multiplayer_peer = null` on disconnect |
| "Ghost" players | Disconnected peers not detected | Implement heartbeat/ping timeout |
| WebSocket fails to connect | Firewall, wrong port | Use standard ports (443 for WSS), implement fallback |

---

## Summary Checklist for Resilient 1v1

### Server Authority (Anti-Cheat)
- [ ] **NEVER trust the client** - All game logic runs on server
- [ ] **Server validates every action** - Position, inventory, game events
- [ ] **Clients only send inputs** - "I pressed W", not "I'm at (100, 200)"
- [ ] **Server broadcasts state** - "Player 1 is now at (100, 200)"
- [ ] **Use `multiplayer.is_server()` check** in ALL `@rpc("any_peer")` functions

### Network Infrastructure
- [ ] **Use WebSocketMultiplayerPeer** for NAT traversal (no port forwarding needed)
- [ ] **Implement relay/matchmaking server** for connection brokering
- [ ] **Use appropriate RPC modes** - `reliable` for actions, `unreliable` for movement
- [ ] **Implement heartbeat/ping** to detect disconnections early
- [ ] **Add reconnection logic** with state resync capability
- [ ] **Handle all multiplayer signals** - especially `server_disconnected`
- [ ] **Test with simulated packet loss** (use tools like Clumsy or Network Link Conditioner)
- [ ] **Consider multiple relay regions** for global player matching

---

## Further Reading

- [Godot Docs: High-Level Multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [WebRTC for true P2P](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html) (bypass relay, but complex NAT traversal)
- [ENet for LAN](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html) (lowest latency, requires port forwarding)
