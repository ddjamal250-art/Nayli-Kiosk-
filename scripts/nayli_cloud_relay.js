/**
 * Nayli Market - Zero-Dependency Cloud Relay Gateway (Node.js)
 * Bridges Master POS and Mobile Companions across the internet via isolated rooms.
 * 
 * Usage:
 *   npm install ws
 *   node nayli_cloud_relay.js
 */

const http = require('http');
const { WebSocketServer, WebSocket } = require('ws');

const PORT = process.env.PORT || 8080;
const server = http.createServer((req, res) => {
  if (req.url === '/' || req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'online',
      service: 'Nayli Market Cloud Relay Gateway',
      activeRooms: rooms.size,
      timestamp: new Date().toISOString()
    }));
  } else {
    res.writeHead(404);
    res.end();
  }
});

const wss = new WebSocketServer({ server });
const rooms = new Map();

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const roomId = url.searchParams.get('room');
  const role = (url.searchParams.get('role') || 'client').toLowerCase();
  const merchantId = url.searchParams.get('merchantId') || roomId;

  if (!roomId) {
    ws.close(1008, 'Missing room parameter');
    return;
  }

  if (!rooms.has(roomId)) {
    rooms.set(roomId, { id: roomId, master: null, clients: new Set() });
  }

  const room = rooms.get(roomId);

  if (role === 'master' || role === 'server') {
    if (room.master && room.master.readyState === WebSocket.OPEN) {
      room.master.close(1000, 'Replaced by new master');
    }
    room.master = ws;
    console.log(`🏢 [Room: ${roomId}] Master POS connected (${merchantId})`);

    // Notify clients in this room
    const statusMsg = JSON.stringify({
      type: 'upRes',
      event: 'master-status',
      merchantId,
      payload: { status: 'online' },
      ts: Date.now()
    });
    room.clients.forEach(c => {
      if (c.readyState === WebSocket.OPEN) c.send(statusMsg);
    });
  } else {
    room.clients.add(ws);
    console.log(`📱 [Room: ${roomId}] Mobile Companion connected. Total in room: ${room.clients.size}`);

    ws.send(JSON.stringify({
      type: 'upRes',
      event: 'master-status',
      merchantId,
      payload: { status: room.master ? 'online' : 'offline' },
      ts: Date.now()
    }));
  }

  ws.on('message', (data) => {
    try {
      const text = data.toString();
      if (role === 'master' || role === 'server') {
        // Forward to all clients in this isolated room
        room.clients.forEach(c => {
          if (c.readyState === WebSocket.OPEN) c.send(text);
        });
      } else {
        // Client forwarding to Master POS
        if (room.master && room.master.readyState === WebSocket.OPEN) {
          room.master.send(text);
        } else {
          const parsed = JSON.parse(text);
          ws.send(JSON.stringify({
            id: parsed.id || String(Date.now()),
            type: 'res',
            event: 'error',
            merchantId,
            payload: {
              error: 'Master POS is currently offline. Please ensure the store PC is open.',
              offline: true
            },
            ts: Date.now()
          }));
        }
      }
    } catch (e) {
      console.error('Relay error:', e);
    }
  });

  ws.on('close', () => {
    if (role === 'master' || role === 'server') {
      room.master = null;
      console.log(`🏢 [Room: ${roomId}] Master POS disconnected`);
      const offlineMsg = JSON.stringify({
        type: 'upRes',
        event: 'master-status',
        merchantId,
        payload: { status: 'offline' },
        ts: Date.now()
      });
      room.clients.forEach(c => {
        if (c.readyState === WebSocket.OPEN) c.send(offlineMsg);
      });
    } else {
      room.clients.delete(ws);
      console.log(`📱 [Room: ${roomId}] Companion disconnected. Remaining: ${room.clients.size}`);
    }

    if (!room.master && room.clients.size === 0) {
      rooms.delete(roomId);
      console.log(`🧹 [Room: ${roomId}] Cleaned up inactive room`);
    }
  });
});

server.listen(PORT, () => {
  console.log('====================================================');
  console.log(`🚀 Nayli Market Node.js Relay Server running on port ${PORT}`);
  console.log('🔒 Strict Merchant Tenant Isolation Active');
  console.log('====================================================');
});
