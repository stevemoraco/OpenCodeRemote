# OpenCode Remote Relay Server Specifications

## Overview
A WebSocket relay server that enables iPhone-to-Mac communication when direct network connection isn't available.

## Server URL
- Production: `wss://opencoderemote.replit.app`

## Protocol

### Connection Flow
1. **Mac (Server) connects**: Sends `{"type": "mac-register"}`
2. **Server responds**: `{"type": "room-created", "roomID": "ABCD-1234"}`
3. **iPhone (Client) connects**: Sends `{"type": "phone-join", "roomID": "ABCD-1234"}`
4. **Server responds**: `{"type": "join-success"}`

### Message Types

#### Control Messages
```json
// Mac Registration
{"type": "mac-register"}

// Phone Join
{"type": "phone-join", "roomID": "ABCD-1234"}

// Room Created (server -> mac)
{"type": "room-created", "roomID": "ABCD-1234"}

// Join Success (server -> phone)
{"type": "join-success"}

// Error
{"type": "error", "message": "Room not found", "code": "ROOM_NOT_FOUND"}

// Heartbeat
{"type": "ping"}
{"type": "pong"}
```

#### Data Messages (Relayed Between Devices)
```json
// HTTP Request (phone -> mac)
{
  "type": "http-request",
  "id": "unique-request-id",
  "method": "POST",
  "path": "/api/sessions",
  "headers": {"Content-Type": "application/json"},
  "body": "{\"provider\":\"openai\"}"
}

// HTTP Response (mac -> phone)
{
  "type": "http-response",
  "id": "unique-request-id",
  "status": 200,
  "headers": {"Content-Type": "application/json"},
  "body": "{\"sessionId\":\"123\"}"
}

// SSE Event (mac -> phone)
{
  "type": "sse-event",
  "event": "message",
  "data": "{\"content\":\"Hello\"}"
}
```

## Implementation Requirements

1. **Room Management**
   - Generate 8-character room codes (format: XXXX-XXXX)
   - Room expires after 24 hours or when Mac disconnects
   - One Mac per room, multiple phones can join

2. **Message Relay**
   - All messages from phone are forwarded to Mac
   - All messages from Mac are broadcast to all phones in room

3. **Connection Handling**
   - Send pong response to ping messages
   - Clean up room when Mac disconnects
   - Remove phone from room on disconnect

4. **Error Handling**
   - Send error message for invalid room codes
   - Handle malformed JSON gracefully

## Example Replit Implementation

```javascript
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: process.env.PORT || 3000 });

const rooms = new Map(); // roomID -> { mac: ws, phones: Set<ws> }

function generateRoomCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    if (i === 4) code += '-';
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

wss.on('connection', (ws) => {
  let currentRoom = null;
  let clientType = null;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      
      switch (data.type) {
        case 'mac-register':
          const roomID = generateRoomCode();
          rooms.set(roomID, { mac: ws, phones: new Set() });
          currentRoom = roomID;
          clientType = 'mac';
          ws.send(JSON.stringify({ type: 'room-created', roomID }));
          break;
          
        case 'phone-join':
          const room = rooms.get(data.roomID);
          if (room) {
            room.phones.add(ws);
            currentRoom = data.roomID;
            clientType = 'phone';
            ws.send(JSON.stringify({ type: 'join-success' }));
          } else {
            ws.send(JSON.stringify({ 
              type: 'error', 
              message: 'Room not found',
              code: 'ROOM_NOT_FOUND'
            }));
          }
          break;
          
        case 'ping':
          ws.send(JSON.stringify({ type: 'pong' }));
          break;
          
        default:
          // Relay messages
          if (currentRoom && rooms.has(currentRoom)) {
            const room = rooms.get(currentRoom);
            if (clientType === 'phone' && room.mac) {
              room.mac.send(message);
            } else if (clientType === 'mac') {
              room.phones.forEach(phone => phone.send(message));
            }
          }
      }
    } catch (e) {
      console.error('Error handling message:', e);
    }
  });

  ws.on('close', () => {
    if (currentRoom) {
      if (clientType === 'mac') {
        rooms.delete(currentRoom);
      } else if (clientType === 'phone') {
        const room = rooms.get(currentRoom);
        if (room) {
          room.phones.delete(ws);
        }
      }
    }
  });
});

console.log('Relay server running on port', process.env.PORT || 3000);
```