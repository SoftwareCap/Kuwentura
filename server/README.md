# Kwentura Game Server

WebSocket server for Kwentura 2-player co-op game.

## Prerequisites

- Node.js 18+
- Firebase project with Firestore enabled
- Service account key from Firebase

## Setup

### 1. Install Dependencies

```bash
cd server
npm install
```

### 2. Firebase Setup

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save the JSON file as `service-account.json` in the `server/` folder

### 3. Environment Variables (Optional)

Create `.env` file:

```env
PORT=10000
FIREBASE_PROJECT_ID=kwentura-89df4
```

### 4. Firestore Security Rules

Set these rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Worlds collection
    match /worlds/{worldId} {
      allow read: if request.auth != null && 
        (resource.data.detective_id == request.auth.uid || 
         resource.data.sidekick_id == request.auth.uid);
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (resource.data.detective_id == request.auth.uid || 
         resource.data.sidekick_id == request.auth.uid);
    }
    
    // User worlds
    match /users/{userId}/worlds/{worldId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. Run Server

```bash
# Development (with auto-reload)
npm run dev

# Production
npm start
```

## API Endpoints

### HTTP

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/worlds` | Yes | Create new world |
| POST | `/worlds/:inviteCode/join` | Yes | Join world by code |
| POST | `/worlds/:worldId/start` | Yes | Start game session |
| GET | `/worlds/:worldId` | Yes | Get world info |
| GET | `/users/me/worlds` | Yes | List my worlds |

### WebSocket

Connect to: `wss://api.kwentura.game/ws?session={sessionId}&token={jwt}`

**Binary Messages:**
- `0x01` - Input move (client → server)
- `0x02` - Player state (server → client)
- `0xFF` - Ping (client → server)
- `0xFE` - Pong (server → client)

**JSON Messages:**

Client → Server:
- `input_action` - Interaction request
- `puzzle_attempt` - Submit puzzle solution
- `dialogue_choice` - Select dialogue option
- `ready` - Client finished loading
- `request_sync` - Request state resync

Server → Client:
- `session_start` - Initial state
- `game_started` - Game begins
- `game_resumed` - Game resumes after pause
- `state_world` - World state update
- `event_action` - Action result
- `event_puzzle` - Puzzle outcome
- `event_story` - Story progression
- `partner_status` - Partner connect/disconnect
- `error` - Error message
- `force_sync` - Force state update

## Deployment

### Railway (Recommended)

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Deploy
railway up
```

### Google Cloud Run

```bash
# Build container
gcloud builds submit --tag gcr.io/PROJECT_ID/kwentura-server

# Deploy
gcloud run deploy kwentura-server \
  --image gcr.io/PROJECT_ID/kwentura-server \
  --platform managed \
  --allow-unauthenticated
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GAME SERVER                             │
├─────────────────────────────────────────────────────────────┤
│  HTTP (Express)                                             │
│  ├── POST /worlds              - Create world               │
│  ├── POST /worlds/:code/join   - Join world                 │
│  ├── POST /worlds/:id/start    - Start session              │
│  └── GET  /users/me/worlds     - List worlds                │
│                                                             │
│  WebSocket (ws)                                             │
│  ├── Binary Protocol (60Hz input, 20Hz state)              │
│  ├── JSON Protocol (events)                                 │
│  ├── GameSession class (world state, validation)            │
│  └── Player class (connection, rate limiting)               │
│                                                             │
│  Firebase                                                   │
│  ├── Firestore (world data, progress)                       │
│  └── Auth (JWT verification)                                │
└─────────────────────────────────────────────────────────────┘
```

## Monitoring

Server logs to console. In production, integrate with:
- Google Cloud Logging
- Datadog
- Sentry

## License

Private - Kwentura Project
