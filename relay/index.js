// relay-server.js
const WebSocket = require("ws");
const http = require("http");
const url = require("url");

const HTTP_PORT = 10000;
const WS_PORT = 10001; // WebSocket port

const rooms = new Map(); // room_code -> {host_ws, client_ws, host_port}

// HTTP server for matchmaking
const httpServer = http.createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Content-Type", "application/json");

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  if (pathname === "/register" && req.method === "POST") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        const data = JSON.parse(body);
        const roomCode = data.room_code;
        const hostPort = data.local_port || 7777;

        rooms.set(roomCode, {
          host_ws: null,
          client_ws: null,
          host_port: hostPort,
          created_at: Date.now(),
        });

        console.log(`Room ${roomCode} registered`);
        res.writeHead(200);
        res.end(JSON.stringify({ status: "registered", room: roomCode }));
      } catch (e) {
        res.writeHead(400);
        res.end(JSON.stringify({ error: "Invalid data" }));
      }
    });
  } else if (pathname === "/join" && req.method === "GET") {
    const roomCode = parsedUrl.query.room;

    if (!roomCode || !rooms.has(roomCode)) {
      res.writeHead(404);
      res.end(JSON.stringify({ error: "Room not found" }));
      return;
    }

    const room = rooms.get(roomCode);
    if (room.client_ws) {
      res.writeHead(409);
      res.end(JSON.stringify({ error: "Room full" }));
      return;
    }

    // Return WebSocket URL for client to connect
    res.writeHead(200);
    res.end(
      JSON.stringify({
        room: roomCode,
        relay_url: `ws://localhost:${WS_PORT}?room=${roomCode}&role=client`,
      }),
    );
  } else {
    res.writeHead(404);
    res.end(JSON.stringify({ error: "Not found" }));
  }
});

// WebSocket server for actual game traffic
const wss = new WebSocket.Server({ port: WS_PORT });

wss.on("connection", (ws, req) => {
  const parsedUrl = url.parse(req.url, true);
  const roomCode = parsedUrl.query.room;
  const role = parsedUrl.query.role; // 'host' or 'client'

  console.log(`WS Connection: room=${roomCode}, role=${role}`);

  if (!roomCode || !rooms.has(roomCode)) {
    ws.close(1008, "Invalid room");
    return;
  }

  const room = rooms.get(roomCode);

  if (role === "host") {
    room.host_ws = ws;
    ws.role = "host";
    ws.roomCode = roomCode;
    console.log(`Host joined room ${roomCode}`);
  } else {
    room.client_ws = ws;
    ws.role = "client";
    ws.roomCode = roomCode;
    console.log(`Client joined room ${roomCode}`);

    // Notify host that client connected
    if (room.host_ws && room.host_ws.readyState === WebSocket.OPEN) {
      room.host_ws.send(JSON.stringify({ type: "peer_connected" }));
    }
    // Notify client they're connected
    ws.send(JSON.stringify({ type: "connected_to_host" }));
  }

  ws.on("message", (data) => {
    const room = rooms.get(ws.roomCode);
    if (!room) return;

    // Relay to other peer
    const target = ws.role === "host" ? room.client_ws : room.host_ws;
    if (target && target.readyState === WebSocket.OPEN) {
      target.send(data);
    }
  });

  ws.on("close", () => {
    const room = rooms.get(ws.roomCode);
    if (room) {
      // Notify other peer
      const other = ws.role === "host" ? room.client_ws : room.host_ws;
      if (other && other.readyState === WebSocket.OPEN) {
        other.send(JSON.stringify({ type: "peer_disconnected" }));
        other.close();
      }
      rooms.delete(ws.roomCode);
      console.log(`Room ${ws.roomCode} closed`);
    }
  });

  ws.on("error", (err) => {
    console.error("WebSocket error:", err);
  });
});

httpServer.listen(HTTP_PORT, () => {
  console.log(`HTTP matchmaker running on http://localhost:${HTTP_PORT}`);
  console.log(`WebSocket relay running on ws://localhost:${WS_PORT}`);
});

// Cleanup old rooms every 5 minutes
setInterval(
  () => {
    const now = Date.now();
    for (const [code, room] of rooms.entries()) {
      if (now - room.created_at > 30 * 60 * 1000) {
        // 30 minutes
        if (room.host_ws) room.host_ws.close();
        if (room.client_ws) room.client_ws.close();
        rooms.delete(code);
        console.log(`Cleaned up old room ${code}`);
      }
    }
  },
  5 * 60 * 1000,
);
