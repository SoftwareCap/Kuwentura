//==============================================================================
// KWENTURA GAME SERVER
// WebSocket Protocol Implementation
// Node.js + Express + ws
//==============================================================================

const express = require('express');
const cors = require('cors');
const { WebSocketServer } = require('ws');
const http = require('http');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

//==============================================================================
// LOGGER UTILITY
//==============================================================================

const LOG_LEVELS = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 };
const CURRENT_LOG_LEVEL = LOG_LEVELS[process.env.LOG_LEVEL || 'INFO'];

function log(level, context, message, data = null) {
    const levelNum = LOG_LEVELS[level] || 1;
    if (levelNum < CURRENT_LOG_LEVEL) return;
    
    const timestamp = new Date().toISOString();
    const prefix = `[${timestamp}] [${level}] [${context}]`;
    
    if (data) {
        console.log(`${prefix} ${message}`, typeof data === 'object' ? JSON.stringify(data) : data);
    } else {
        console.log(`${prefix} ${message}`);
    }
}

const logger = {
    debug: (ctx, msg, data) => log('DEBUG', ctx, msg, data),
    info: (ctx, msg, data) => log('INFO', ctx, msg, data),
    warn: (ctx, msg, data) => log('WARN', ctx, msg, data),
    error: (ctx, msg, data) => log('ERROR', ctx, msg, data)
};

//==============================================================================
// CONFIGURATION
//==============================================================================

const PORT = process.env.PORT || 10000;
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'kwentura-89df4';

const RATE_LIMITS = {
    INPUT_MOVE: { max: 60, window: 1000 },      // 60 per second
    INPUT_ACTION: { max: 10, window: 1000 },    // 10 per second
    PUZZLE_ATTEMPT: { max: 1, window: 1000 },   // 1 per second
    REQUEST_SYNC: { max: 1, window: 5000 },     // 1 per 5 seconds
};

const GAME_CONSTANTS = {
    MAX_WALK_SPEED: 200,
    MAX_SPRINT_SPEED: 400,
    MAX_INTERACT_DISTANCE: 100,
    SESSION_TIMEOUT_MS: 5 * 60 * 1000,  // 5 minutes
    AUTO_SAVE_INTERVAL_MS: 30000,        // 30 seconds
};

//==============================================================================
// FIREBASE INITIALIZATION
//==============================================================================

initializeApp({
    credential: cert(require('./service-account.json')),
    projectId: FIREBASE_PROJECT_ID
});

const db = getFirestore();
const auth = getAuth();

logger.info('FIREBASE', 'Firebase initialized successfully', { projectId: FIREBASE_PROJECT_ID });

//==============================================================================
// DATA MODELS
//==============================================================================

class World {
    constructor(data) {
        this.worldId = data.world_id;
        this.name = data.name;
        this.detectiveId = data.detective_id;
        this.sidekickId = data.sidekick_id;
        this.progress = data.progress || {};
        this.checkpoint = data.checkpoint || {};
        this.status = data.status || 'active';
        this.createdAt = data.created_at;
    }

    static async load(worldId) {
        logger.debug('WORLD', `Loading world: ${worldId}`);
        const doc = await db.collection('worlds').doc(worldId).get();
        if (!doc.exists) {
            logger.warn('WORLD', `World not found: ${worldId}`);
            return null;
        }
        logger.debug('WORLD', `World loaded: ${worldId}`);
        return new World(doc.data());
    }

    async save() {
        logger.debug('WORLD', `Saving world: ${this.worldId}`);
        await db.collection('worlds').doc(this.worldId).update({
            progress: this.progress,
            checkpoint: this.checkpoint,
            last_saved: Date.now()
        });
        logger.info('WORLD', `World saved: ${this.worldId}`);
    }

    getPlayerRole(userId) {
        if (userId === this.detectiveId) return 'detective';
        if (userId === this.sidekickId) return 'sidekick';
        return null;
    }

    hasPlayer(userId) {
        return userId === this.detectiveId || userId === this.sidekickId;
    }
}

class Player {
    constructor(userId, role) {
        this.userId = userId;
        this.role = role;
        this.ws = null;
        this.position = { x: 0, y: 0 };
        this.velocity = { x: 0, y: 0 };
        this.facing = 'down';
        this.animation = 'idle';
        this.health = 100;
        this.stamina = 100;
        this.inventory = [];
        this.isControllable = true;
        this.isReady = false;
        this.lastInputTime = 0;
        this.inputCount = 0;
        this.lastPingTime = Date.now();
    }

    getState() {
        return {
            player_id: this.userId,
            role: this.role,
            position: this.position,
            velocity: this.velocity,
            facing: this.facing,
            animation: this.animation,
            health: this.health,
            stamina: this.stamina,
            inventory: this.inventory,
            is_controllable: this.isControllable
        };
    }
}

class GameSession {
    constructor(sessionId, world) {
        this.sessionId = sessionId;
        this.world = world;
        this.players = new Map();  // userId -> Player
        this.status = 'starting';  // starting, playing, paused, ended
        this.createdAt = Date.now();
        this.lastActivity = Date.now();
        this.sequenceNumber = 0;
        this.autoSaveInterval = null;
        this.sessionState = {
            time_of_day: 'day',
            weather: 'clear',
            active_objects: [],
            active_npcs: [],
            triggered_events: []
        };
    }

    addPlayer(userId, role, ws) {
        logger.info('SESSION', `Adding player to session ${this.sessionId}: ${userId} (${role})`);
        
        const player = new Player(userId, role);
        player.ws = ws;
        
        // Load position from checkpoint
        if (this.world.checkpoint) {
            const posKey = role === 'detective' ? 'position_detective' : 'position_sidekick';
            if (this.world.checkpoint[posKey]) {
                player.position = { ...this.world.checkpoint[posKey] };
                logger.debug('SESSION', `Loaded checkpoint position for ${role}`, player.position);
            }
        }
        
        this.players.set(userId, player);
        logger.info('SESSION', `Player added. Total players: ${this.players.size}`);
        
        // Start auto-save when both players are present
        if (this.players.size === 2 && !this.autoSaveInterval) {
            logger.info('SESSION', 'Both players connected, starting auto-save');
            this.startAutoSave();
        }
        
        return player;
    }

    removePlayer(userId) {
        logger.info('SESSION', `Removing player from session ${this.sessionId}: ${userId}`);
        this.players.delete(userId);
        
        // Pause game if someone disconnects during play
        if (this.status === 'playing') {
            logger.warn('SESSION', 'Game paused - player disconnected during play');
            this.status = 'paused';
            this.saveProgress();
            this.broadcastToOthers(userId, 'partner_status', {
                status: 'disconnected',
                player_id: userId
            });
        }
        
        // End session if no one left
        if (this.players.size === 0) {
            logger.info('SESSION', 'No players remaining, ending session');
            this.end();
        }
    }

    getPartner(userId) {
        for (const [id, player] of this.players) {
            if (id !== userId) return player;
        }
        return null;
    }

    startGame() {
        logger.info('SESSION', `Starting game in session ${this.sessionId}`);
        this.status = 'playing';
        this.broadcast('game_started', {
            checkpoint: this.world.checkpoint?.zone_id || 'starting_zone'
        });
        logger.info('SESSION', 'Game started broadcast sent');
    }

    resumeGame() {
        if (this.status === 'paused' && this.players.size === 2) {
            this.status = 'playing';
            this.broadcast('game_resumed', {
                progress: this.world.progress
            });
        }
    }

    startAutoSave() {
        this.autoSaveInterval = setInterval(() => {
            this.saveProgress();
        }, GAME_CONSTANTS.AUTO_SAVE_INTERVAL_MS);
    }

    async saveProgress() {
        logger.debug('SESSION', `Saving progress for session ${this.sessionId}`);
        
        // Update checkpoint with current positions
        const detective = Array.from(this.players.values()).find(p => p.role === 'detective');
        const sidekick = Array.from(this.players.values()).find(p => p.role === 'sidekick');
        
        if (detective) {
            this.world.checkpoint.position_detective = detective.position;
            logger.debug('SESSION', 'Saved detective position', detective.position);
        }
        if (sidekick) {
            this.world.checkpoint.position_sidekick = sidekick.position;
            logger.debug('SESSION', 'Saved sidekick position', sidekick.position);
        }
        
        await this.world.save();
        logger.info('SESSION', `Progress saved for session ${this.sessionId}`);
    }

    end() {
        logger.info('SESSION', `Ending session ${this.sessionId}`);
        this.status = 'ended';
        
        if (this.autoSaveInterval) {
            clearInterval(this.autoSaveInterval);
            this.autoSaveInterval = null;
            logger.debug('SESSION', 'Auto-save interval cleared');
        }
        
        // Final save
        this.saveProgress();
        
        // Close all connections
        for (const player of this.players.values()) {
            if (player.ws && player.ws.readyState === 1) {
                player.ws.close(1000, 'Session ended');
            }
        }
        
        logger.info('SESSION', `Session ${this.sessionId} ended`);
    }

    // Rate limiting
    checkRateLimit(player, actionType) {
        const limit = RATE_LIMITS[actionType];
        if (!limit) return true;
        
        const now = Date.now();
        
        if (now - player.lastInputTime > limit.window) {
            player.inputCount = 0;
            player.lastInputTime = now;
        }
        
        player.inputCount++;
        
        return player.inputCount <= limit.max;
    }

    // Validation
    validateMove(player, input) {
        // Check rate limit
        if (!this.checkRateLimit(player, 'INPUT_MOVE')) {
            return { valid: false, error: 'Rate limited' };
        }
        
        // Check if controllable
        if (!player.isControllable) {
            return { valid: false, error: 'Not controllable' };
        }
        
        // Check speed (prevent teleport hacks)
        const speed = Math.sqrt(input.x ** 2 + input.y ** 2);
        const maxSpeed = input.sprint ? 1.0 : 0.5; // Normalized
        
        if (speed > maxSpeed * 1.1) {  // 10% tolerance
            return { valid: false, error: 'Speed exceeded' };
        }
        
        return { valid: true };
    }

    validateAction(player, action) {
        if (!this.checkRateLimit(player, 'INPUT_ACTION')) {
            return { valid: false, error: 'Rate limited' };
        }
        
        return { valid: true };
    }

    // Apply game logic
    applyMove(player, input) {
        const speed = input.sprint ? GAME_CONSTANTS.MAX_SPRINT_SPEED : GAME_CONSTANTS.MAX_WALK_SPEED;
        
        player.velocity.x = input.x * speed;
        player.velocity.y = input.y * speed;
        
        player.position.x += player.velocity.x * (1/60);  // Assuming 60Hz
        player.position.y += player.velocity.y * (1/60);
        
        // Update facing direction
        if (Math.abs(input.x) > Math.abs(input.y)) {
            player.facing = input.x > 0 ? 'right' : 'left';
        } else if (input.y !== 0) {
            player.facing = input.y > 0 ? 'down' : 'up';
        }
        
        player.animation = (input.x !== 0 || input.y !== 0) ? (input.sprint ? 'run' : 'walk') : 'idle';
    }

    applyAction(player, action) {
        switch (action.action) {
            case 'interact':
                return this.handleInteract(player, action);
            case 'use_item':
                return this.handleUseItem(player, action);
            case 'examine':
                return this.handleExamine(player, action);
            default:
                return { success: false, error: 'Unknown action' };
        }
    }

    handleInteract(player, action) {
        // TODO: Implement game-specific interaction logic
        return {
            success: true,
            outcome: {
                type: 'interaction_blocked',
                reason: 'Not implemented yet'
            }
        };
    }

    handleUseItem(player, action) {
        // Check if player has item
        if (!player.inventory.includes(action.item_id)) {
            return { success: false, error: 'Item not in inventory' };
        }
        
        return { success: true };
    }

    handleExamine(player, action) {
        return {
            success: true,
            outcome: {
                type: 'examine_result',
                description: `You examine the ${action.target_id}`
            }
        };
    }

    handlePuzzleAttempt(player, data) {
        if (!this.checkRateLimit(player, 'PUZZLE_ATTEMPT')) {
            return { success: false, error: 'Rate limited' };
        }
        
        // TODO: Validate puzzle solution
        return {
            success: true,
            status: 'solved',
            puzzle_id: data.puzzle_id,
            solved_by: player.userId,
            rewards: {
                clues: [],
                items: [],
                zones_unlocked: []
            }
        };
    }

    // Broadcasting
    sendTo(ws, type, data) {
        if (ws.readyState !== 1) return;  // OPEN
        
        this.sequenceNumber++;
        
        const message = JSON.stringify({
            type,
            timestamp: Date.now(),
            seq: this.sequenceNumber,
            data
        });
        
        ws.send(message);
    }

    broadcast(type, data) {
        for (const player of this.players.values()) {
            this.sendTo(player.ws, type, data);
        }
    }

    broadcastToOthers(excludeUserId, type, data) {
        for (const [userId, player] of this.players) {
            if (userId !== excludeUserId) {
                this.sendTo(player.ws, type, data);
            }
        }
    }

    broadcastPlayerStates() {
        // Binary format for efficiency
        const count = this.players.size;
        const packet = Buffer.alloc(2 + count * 18);
        
        packet[0] = 0x02;  // STATE_PLAYER type
        packet[1] = count;
        
        let offset = 2;
        let index = 1;
        
        for (const player of this.players.values()) {
            packet[offset] = index++;  // Player ID (1 or 2)
            packet.writeFloatLE(player.position.x, offset + 1);
            packet.writeFloatLE(player.position.y, offset + 5);
            packet.writeFloatLE(player.velocity.x, offset + 9);
            packet.writeFloatLE(player.velocity.y, offset + 13);
            
            // State byte
            let stateByte = 0;
            switch (player.facing) {
                case 'down': stateByte |= 0x00; break;
                case 'up': stateByte |= 0x01; break;
                case 'left': stateByte |= 0x02; break;
                case 'right': stateByte |= 0x03; break;
            }
            
            const animIndex = ['idle', 'walk', 'run', 'jump', 'fall', 'interact'].indexOf(player.animation);
            stateByte |= (animIndex << 2) & 0x3C;
            
            if (player.isControllable) {
                stateByte |= 0x40;
            }
            
            packet[offset + 17] = stateByte;
            
            offset += 18;
        }
        
        for (const player of this.players.values()) {
            if (player.ws.readyState === 1) {
                player.ws.send(packet);
            }
        }
    }
}

// Session manager
const sessions = new Map();

//==============================================================================
// EXPRESS HTTP API
//==============================================================================

const app = express();
app.use(cors());  // Enable CORS for all origins (dev only)
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
    const start = Date.now();
    logger.info('HTTP', `${req.method} ${req.path}`, { ip: req.ip });
    
    res.on('finish', () => {
        const duration = Date.now() - start;
        logger.info('HTTP', `${req.method} ${req.path} - ${res.statusCode} (${duration}ms)`);
    });
    
    next();
});

// Authentication middleware
async function authenticate(req, res, next) {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        logger.warn('AUTH', 'Authentication failed: Missing token');
        return res.status(401).json({ error: 'Unauthorized', message: 'Missing token' });
    }
    
    const token = authHeader.substring(7);
    
    try {
        const decoded = await auth.verifyIdToken(token);
        req.user = decoded;
        logger.debug('AUTH', `Token verified for user: ${decoded.uid}`);
        next();
    } catch (error) {
        logger.error('AUTH', 'Token verification failed', error.message);
        return res.status(401).json({ error: 'Unauthorized', message: 'Invalid token' });
    }
}

// Create new world
app.post('/worlds', authenticate, async (req, res) => {
    const { name, role } = req.body;
    const userId = req.user.uid;
    
    logger.info('API', `Creating world - User: ${userId}, Role: ${role}, Name: ${name || 'Untitled'}`);
    
    if (!['detective', 'sidekick'].includes(role)) {
        logger.warn('API', `Invalid role specified: ${role}`);
        return res.status(400).json({ error: 'Invalid role' });
    }
    
    const worldId = `w_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const inviteCode = Array.from({length: 6}, () => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[Math.floor(Math.random() * 36)]).join('');
    
    logger.info('API', `Generated world_id: ${worldId}, invite_code: ${inviteCode}`);
    
    const worldData = {
        world_id: worldId,
        name: name || 'Untitled Adventure',
        invite_code: inviteCode,
        detective_id: role === 'detective' ? userId : null,
        sidekick_id: role === 'sidekick' ? userId : null,
        created_by: userId,
        created_at: Date.now(),
        status: 'waiting',
        progress: {
            story_chapter: 1,
            zones_unlocked: ['starting_zone'],
            puzzles_solved: [],
            clues_found: [],
            story_flags: {},
            inventory_shared: [],
            playtime_total_minutes: 0
        },
        checkpoint: {
            zone_id: 'starting_zone',
            position_detective: { x: 100, y: 200 },
            position_sidekick: { x: 110, y: 200 }
        }
    };
    
    await db.collection('worlds').doc(worldId).set(worldData);
    
    // Add to user's worlds
    await db.collection('users').doc(userId).collection('worlds').doc(worldId).set({
        world_id: worldId,
        name: worldData.name,
        role: role,
        partner_id: null,
        joined_at: Date.now()
    });
    
    logger.info('API', `World created successfully: ${worldId}`);
    
    res.json({
        world_id: worldId,
        invite_code: inviteCode,
        role: role,
        status: 'waiting'
    });
});

// Join world by invite code
app.post('/worlds/:inviteCode/join', authenticate, async (req, res) => {
    const { inviteCode } = req.params;
    const userId = req.user.uid;
    
    logger.info('API', `Join attempt - User: ${userId}, InviteCode: ${inviteCode}`);
    
    const snapshot = await db.collection('worlds')
        .where('invite_code', '==', inviteCode.toUpperCase())
        .where('status', 'in', ['waiting', 'active'])
        .limit(1)
        .get();
    
    if (snapshot.empty) {
        logger.warn('API', `World not found for invite code: ${inviteCode}`);
        return res.status(404).json({ error: 'World not found' });
    }
    
    const worldDoc = snapshot.docs[0];
    const world = worldDoc.data();
    
    // Check if already in world
    if (world.detective_id === userId || world.sidekick_id === userId) {
        return res.json({
            world_id: world.world_id,
            name: world.name,
            role: world.detective_id === userId ? 'detective' : 'sidekick',
            partner_id: world.detective_id === userId ? world.sidekick_id : world.detective_id,
            status: world.status
        });
    }
    
    // Check if role available
    const availableRole = !world.detective_id ? 'detective' : 
                         !world.sidekick_id ? 'sidekick' : null;
    
    if (!availableRole) {
        logger.warn('API', `World ${world.world_id} is full - join rejected for ${userId}`);
        return res.status(403).json({ error: 'World is full' });
    }
    
    logger.info('API', `Assigning role ${availableRole} to user ${userId} in world ${world.world_id}`);
    
    // Assign role
    const updateData = {
        [`${availableRole}_id`]: userId,
        status: 'ready'
    };
    
    await worldDoc.ref.update(updateData);
    
    const partnerId = availableRole === 'detective' ? world.sidekick_id : world.detective_id;
    
    // Get partner name
    let partnerName = 'Unknown';
    try {
        const partnerUser = await auth.getUser(partnerId);
        partnerName = partnerUser.displayName || 'Unknown';
    } catch (e) {}
    
    // Add to user's worlds
    await db.collection('users').doc(userId).collection('worlds').doc(world.world_id).set({
        world_id: world.world_id,
        name: world.name,
        role: availableRole,
        partner_id: partnerId,
        joined_at: Date.now()
    });
    
    // Update partner's record
    await db.collection('users').doc(partnerId).collection('worlds').doc(world.world_id).update({
        partner_id: userId
    });
    
    logger.info('API', `User ${userId} successfully joined world ${world.world_id} as ${availableRole}`);
    
    res.json({
        world_id: world.world_id,
        name: world.name,
        role: availableRole,
        partner_id: partnerId,
        partner_name: partnerName,
        status: 'ready'
    });
});

// Get user's worlds
app.get('/users/me/worlds', authenticate, async (req, res) => {
    const userId = req.user.uid;
    
    logger.info('API', `Getting worlds for user: ${userId}`);
    
    const snapshot = await db.collection('users').doc(userId)
        .collection('worlds')
        .orderBy('joined_at', 'desc')
        .get();
    
    const worlds = [];
    for (const doc of snapshot.docs) {
        const userWorld = doc.data();
        const worldDoc = await db.collection('worlds').doc(userWorld.world_id).get();
        
        if (worldDoc.exists) {
            const world = worldDoc.data();
            worlds.push({
                world_id: world.world_id,
                name: world.name,
                role: userWorld.role,
                progress: world.progress,
                status: world.status
            });
        }
    }
    
    logger.info('API', `Returning ${worlds.length} worlds for user ${userId}`);
    res.json({ worlds });
});

// Start game session
app.post('/worlds/:worldId/start', authenticate, async (req, res) => {
    const { worldId } = req.params;
    const userId = req.user.uid;
    
    logger.info('API', `Start session request - User: ${userId}, World: ${worldId}`);
    
    const world = await World.load(worldId);
    
    if (!world) {
        logger.warn('API', `World not found: ${worldId}`);
        return res.status(404).json({ error: 'World not found' });
    }
    
    // Check if user is part of this world
    const role = world.getPlayerRole(userId);
    if (!role) {
        logger.warn('API', `User ${userId} is not a player in world ${worldId}`);
        return res.status(403).json({ error: 'Not a player in this world' });
    }
    
    logger.info('API', `User ${userId} role: ${role}, Detective: ${world.detectiveId}, Sidekick: ${world.sidekickId}`);
    
    // Only detective can start
    if (role !== 'detective') {
        logger.warn('API', `Non-detective ${userId} tried to start world ${worldId}`);
        return res.status(403).json({ error: 'NOT_DETECTIVE', message: 'Only detective can start' });
    }
    
    // Check if sidekick has joined
    if (!world.sidekickId) {
        logger.warn('API', `Start rejected - no sidekick in world ${worldId}`);
        return res.status(400).json({ error: 'PARTNER_NOT_CONNECTED', message: 'Waiting for sidekick' });
    }
    
    // Check if session already exists
    for (const [sid, session] of sessions) {
        if (session.world.worldId === worldId) {
            return res.json({
                session_id: sid,
                ws_url: `wss://${req.headers.host}/ws?session=${sid}`,
                checkpoint: world.checkpoint.zone_id,
                world_progress: world.progress
            });
        }
    }
    
    // Create new session
    const sessionId = `s_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    logger.info('API', `Creating new session: ${sessionId} for world ${worldId}`);
    
    const session = new GameSession(sessionId, world);
    sessions.set(sessionId, session);
    
    logger.info('API', `Session ${sessionId} created. Active sessions: ${sessions.size}`);
    
    const wsUrl = `ws://${req.headers.host}/ws?session=${sessionId}`;
    logger.info('API', `Returning WebSocket URL: ${wsUrl}`);
    
    res.json({
        session_id: sessionId,
        ws_url: wsUrl,
        checkpoint: world.checkpoint.zone_id,
        world_progress: world.progress
    });
});

// Get world info
app.get('/worlds/:worldId', authenticate, async (req, res) => {
    const { worldId } = req.params;
    const userId = req.user.uid;
    
    logger.info('API', `Getting world info - User: ${userId}, World: ${worldId}`);
    
    const world = await World.load(worldId);
    
    if (!world) {
        logger.warn('API', `World not found: ${worldId}`);
        return res.status(404).json({ error: 'World not found' });
    }
    
    if (!world.hasPlayer(userId)) {
        logger.warn('API', `User ${userId} not authorized for world ${worldId}`);
        return res.status(403).json({ error: 'Not authorized' });
    }
    
    const partnerId = world.detective_id === userId ? world.sidekickId : world.detective_id;
    
    let partnerName = 'Unknown';
    if (partnerId) {
        try {
            const partnerUser = await auth.getUser(partnerId);
            partnerName = partnerUser.displayName || 'Unknown';
        } catch (e) {}
    }
    
    res.json({
        world_id: world.worldId,
        name: world.name,
        my_role: world.getPlayerRole(userId),
        partner_id: partnerId,
        partner_name: partnerName,
        progress: world.progress,
        checkpoint: world.checkpoint
    });
});

//==============================================================================
// WEBSOCKET SERVER
//==============================================================================

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', async (ws, req) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const sessionId = url.searchParams.get('session');
    const token = url.searchParams.get('token');
    
    logger.info('WS', `New WebSocket connection - Session: ${sessionId}`);
    
    if (!sessionId || !token) {
        logger.warn('WS', 'Connection rejected - missing session or token');
        ws.close(1008, 'Missing session or token');
        return;
    }
    
    // Verify token
    let userId;
    try {
        const decoded = await auth.verifyIdToken(token);
        userId = decoded.uid;
        logger.info('WS', `Token verified for user: ${userId}`);
    } catch (error) {
        logger.error('WS', 'Token verification failed', error.message);
        ws.close(1008, 'Invalid token');
        return;
    }
    
    // Get session
    const session = sessions.get(sessionId);
    if (!session) {
        logger.warn('WS', `Session not found: ${sessionId}`);
        ws.close(1008, 'Session not found');
        return;
    }
    
    // Check if user is part of this world
    const role = session.world.getPlayerRole(userId);
    if (!role) {
        logger.warn('WS', `User ${userId} not authorized for session ${sessionId}`);
        ws.close(1008, 'Not authorized for this session');
        return;
    }
    
    // Add player to session
    const player = session.addPlayer(userId, role, ws);
    
    console.log(`[Session ${sessionId}] Player ${userId} (${role}) connected`);
    
    // Send session start
    const partner = session.getPartner(userId);
    
    session.sendTo(ws, 'session_start', {
        session_id: sessionId,
        your_role: role,
        your_player_id: userId,
        partner: partner ? {
            player_id: partner.userId,
            display_name: 'Partner',
            connected: true
        } : null,
        checkpoint: session.world.checkpoint,
        world_progress: session.world.progress,
        session_state: session.sessionState
    });
    
    // If both players connected, notify everyone
    if (session.players.size === 2) {
        if (session.status === 'paused') {
            session.resumeGame();
        }
        
        session.broadcastToOthers(userId, 'partner_status', {
            status: 'connected',
            player_id: userId,
            display_name: 'Partner'
        });
    }
    
    // Handle messages
    ws.on('message', (data) => {
        try {
            if (data[0] === 0x01 || data[0] === 0xFF) {
                handleBinaryMessage(session, player, data);
            } else {
                const msg = JSON.parse(data.toString());
                logger.debug('WS', `JSON message from ${userId}: ${msg.type}`);
                handleJsonMessage(session, player, msg);
            }
        } catch (error) {
            logger.error('WS', `Message handling error from ${userId}`, error.message);
            session.sendTo(ws, 'error', {
                code: 'INVALID_MESSAGE',
                message: 'Failed to process message',
                fatal: false
            });
        }
    });
    
    // Handle disconnect
    ws.on('close', () => {
        logger.info('WS', `Player ${userId} disconnected from session ${sessionId}`);
        session.removePlayer(userId);
        
        if (session.status === 'ended') {
            logger.info('SESSION', `Removing ended session ${sessionId}. Remaining: ${sessions.size - 1}`);
            sessions.delete(sessionId);
        }
    });
    
    // Handle errors
    ws.on('error', (error) => {
        logger.error('WS', `WebSocket error in session ${sessionId}`, error.message);
    });
});

function handleBinaryMessage(session, player, data) {
    const msgType = data[0];
    const msgTypeName = msgType === 0x01 ? 'INPUT_MOVE' : msgType === 0xFF ? 'PING' : 'UNKNOWN';
    logger.debug('WS', `Binary message: ${msgTypeName} from ${player.userId}`);
    
    switch (msgType) {
        case 0x01:  // INPUT_MOVE
            if (data.length >= 10) {
                const input = {
                    x: data.readFloatLE(1),
                    y: data.readFloatLE(5),
                    sprint: (data[9] & 0x01) !== 0,
                    crouch: (data[9] & 0x02) !== 0
                };
                
                const validation = session.validateMove(player, input);
                if (validation.valid) {
                    session.applyMove(player, input);
                }
            }
            break;
            
        case 0xFF:  // PING
            const pong = Buffer.alloc(9);
            pong[0] = 0xFE;
            pong.writeDoubleLE(Date.now(), 1);
            player.ws.send(pong);
            break;
    }
}

function handleJsonMessage(session, player, msg) {
    const { type, data } = msg;
    
    logger.debug('GAME', `Handling ${type} from ${player.userId}`);
    
    switch (type) {
        case 'input_action':
            handleActionMessage(session, player, data);
            break;
            
        case 'puzzle_attempt':
            handlePuzzleMessage(session, player, data);
            break;
            
        case 'dialogue_choice':
            break;
            
        case 'ready':
            player.isReady = true;
            if (session.players.size === 2) {
                const allReady = Array.from(session.players.values()).every(p => p.isReady);
                if (allReady && session.status === 'starting') {
                    session.startGame();
                }
            }
            break;
            
        case 'request_sync':
            handleSyncRequest(session, player, data);
            break;
    }
}

function handleActionMessage(session, player, data) {
    const validation = session.validateAction(player, data);
    
    if (!validation.valid) {
        session.sendTo(player.ws, 'error', {
            code: 'INVALID_ACTION',
            message: validation.error,
            fatal: false
        });
        return;
    }
    
    const result = session.applyAction(player, data);
    
    session.broadcast('event_action', {
        action_type: data.action,
        result: result.success ? 'success' : 'failure',
        performed_by: player.userId,
        target_id: data.target_id,
        outcome: result.outcome || null
    });
}

function handlePuzzleMessage(session, player, data) {
    const result = session.handlePuzzleAttempt(player, data);
    
    if (result.success && result.status === 'solved') {
        if (!session.world.progress.puzzles_solved.includes(result.puzzle_id)) {
            session.world.progress.puzzles_solved.push(result.puzzle_id);
        }
        
        if (result.rewards) {
            if (result.rewards.zones_unlocked) {
                for (const zone of result.rewards.zones_unlocked) {
                    if (!session.world.progress.zones_unlocked.includes(zone)) {
                        session.world.progress.zones_unlocked.push(zone);
                    }
                }
            }
        }
    }
    
    session.broadcast('event_puzzle', result);
}

function handleSyncRequest(session, player, data) {
    session.sendTo(player.ws, 'force_sync', {
        reason: data.reason || 'manual',
        player_states: Object.fromEntries(
            Array.from(session.players.entries()).map(([id, p]) => [id, p.getState()])
        ),
        world_state: session.sessionState,
        sequence_reset: session.sequenceNumber
    });
}

// Broadcast player states at 20Hz
setInterval(() => {
    for (const session of sessions.values()) {
        if (session.status === 'playing') {
            session.broadcastPlayerStates();
        }
    }
}, 50);

// Log active sessions periodically (every 30 seconds)
setInterval(() => {
    const sessionCount = sessions.size;
    if (sessionCount > 0) {
        const sessionInfo = Array.from(sessions.values()).map(s => ({
            id: s.sessionId,
            status: s.status,
            players: s.players.size
        }));
        logger.info('STATS', `Active sessions: ${sessionCount}`, sessionInfo);
    }
}, 30000);

//==============================================================================
// START SERVER
//==============================================================================

server.listen(PORT, () => {
    logger.info('SERVER', `Kwentura Game Server started on port ${PORT}`);
    console.log(`
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║           KWENTURA GAME SERVER                             ║
║                                                            ║
║   HTTP:  http://localhost:${PORT}                          ║
║   WS:    ws://localhost:${PORT}/ws                         ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
    `);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
    logger.info('SERVER', 'SIGTERM received, shutting down gracefully');
    
    for (const session of sessions.values()) {
        await session.saveProgress();
        session.end();
    }
    
    server.close(() => {
        logger.info('SERVER', 'Server closed');
        process.exit(0);
    });
});
