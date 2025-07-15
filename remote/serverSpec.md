# WebSocket Relay Server for Remote HTTP Proxy

## Project Overview
You need to build a WebSocket relay server that acts as a middleman between mobile devices (iPhones) and desktop computers (Macs). The Mac runs a local HTTP server on port 4096 that the iPhone needs to access, but they might not be on the same network. Your relay server solves this by proxying HTTP requests through WebSocket connections.

Think of it like TeamViewer but for HTTP requests - the Mac and iPhone both connect to your relay server, and you forward messages between them.

## Technical Architecture

**The Problem:**
- Mac runs an HTTP server locally on `http://127.0.0.1:4096`
- iPhone needs to make HTTP requests to this server
- They might be on different networks (iPhone on cellular, Mac at home)
- We can't expose the Mac's ports directly to the internet

**The Solution:**
- Both devices connect to your relay server via WebSocket
- iPhone sends HTTP requests as WebSocket messages to your server
- Your server forwards them to the Mac
- Mac executes the HTTP request locally and sends response back
- Your server forwards the response to the iPhone

## Detailed Requirements

### 1. WebSocket Server Setup
Create a WebSocket server using Node.js or Bun that:
- Listens on the default port Replit provides
- Accepts WebSocket connections from any client
- Handles JSON messages for all communication
- Maintains persistent connections

### 2. Room System
Implement a room-based system where:
- Each Mac creates a "room" (like a private channel)
- Each room gets a unique ID that's easy to type, like "ABCD-1234" (4 letters + 4 numbers)
- iPhones can join a room by providing the room ID
- One Mac per room, but multiple iPhones can join the same room
- Store rooms in memory using a Map or object

Room structure:
```javascript
{
  "ABCD-1234": {
    "mac": WebSocketConnection,
    "phones": Set([WebSocketConnection, WebSocketConnection]),
    "createdAt": Date,
    "lastActivity": Date
  }
}
```

### 3. Message Protocol

All messages are JSON with a `type` field. Here are all the message types you need to handle:

**Mac Registration (Mac → Server):**
```json
{
  "type": "mac-register",
  "version": "1.0"
}
```
When received:
- Generate a new room ID
- Store the Mac's WebSocket connection
- Send back:
```json
{
  "type": "room-created",
  "roomId": "ABCD-1234"
}
```

**iPhone Join (iPhone → Server):**
```json
{
  "type": "phone-join",
  "roomId": "ABCD-1234"
}
```
When received:
- Check if room exists
- Add iPhone's WebSocket to the room's phones Set
- Send back success or error:
```json
{
  "type": "join-success",
  "roomId": "ABCD-1234"
}
```
or
```json
{
  "type": "error",
  "code": "ROOM_NOT_FOUND",
  "message": "Room ABCD-1234 does not exist"
}
```

**HTTP Request Proxy (iPhone → Server → Mac):**
```json
{
  "type": "http-request",
  "id": "unique-request-id-12345",
  "method": "GET",
  "path": "/api/sessions",
  "headers": {
    "Content-Type": "application/json",
    "Accept": "application/json"
  },
  "body": "base64-encoded-string-if-POST-or-PUT"
}
```
When received from iPhone:
- Find the room this iPhone belongs to
- Forward the exact message to the Mac in that room
- The Mac will process it locally

**HTTP Response Proxy (Mac → Server → iPhone):**
```json
{
  "type": "http-response",
  "id": "unique-request-id-12345",
  "status": 200,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "base64-encoded-response-body"
}
```
When received from Mac:
- Find which iPhone sent the request with this ID
- Forward the response to that specific iPhone

**Server-Sent Events (SSE) Proxy (Mac → Server → All iPhones):**
```json
{
  "type": "sse-event",
  "data": "event: message\ndata: {\"type\":\"session.updated\",\"payload\":{...}}\n\n"
}
```
When received from Mac:
- Forward to ALL iPhones in the same room
- This is for real-time updates

### 4. Connection Management

**Heartbeat:**
- Send ping to all clients every 30 seconds
- Disconnect clients that don't respond to 2 consecutive pings

**Cleanup:**
- When a Mac disconnects, notify all iPhones in that room:
```json
{
  "type": "mac-disconnected",
  "message": "The Mac has disconnected"
}
```
- Remove the room after Mac disconnects
- When an iPhone disconnects, just remove it from the room's phones Set

**Room Expiration:**
- Delete rooms that have no activity for 24 hours
- Update `lastActivity` on every message

### 5. HTTP Endpoints

Besides WebSocket, add these HTTP endpoints:

**Health Check:**
```
GET /health
Response: { "status": "ok", "rooms": 5, "connections": 12 }
```

**Home Page:**
```
GET /
Response: HTML page explaining:
- "This is a relay server for OpenCode Remote"
- "Connect your devices using WebSocket"
- Current number of active rooms
```

### 6. Error Handling

Send error messages for:
- Invalid JSON
- Unknown message types  
- Room not found
- Missing required fields

Error format:
```json
{
  "type": "error",
  "code": "INVALID_JSON|UNKNOWN_TYPE|ROOM_NOT_FOUND|MISSING_FIELD",
  "message": "Human-readable description"
}
```

### 7. Logging

Log these events for debugging:
- New connections (Mac/iPhone)
- Room creation with ID
- iPhone joining room
- Disconnections
- Errors

## Implementation Tips

1. **Generate Room IDs:**
```javascript
function generateRoomId() {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const numbers = '0123456789';
  let id = '';
  for (let i = 0; i < 4; i++) {
    id += letters[Math.floor(Math.random() * letters.length)];
  }
  id += '-';
  for (let i = 0; i < 4; i++) {
    id += numbers[Math.floor(Math.random() * numbers.length)];
  }
  return id;
}
```

2. **Message Forwarding Pattern:**
```javascript
// When iPhone sends http-request
const room = findRoomByPhone(ws);
if (room && room.mac) {
  room.mac.send(JSON.stringify(message));
}

// When Mac sends http-response
const room = findRoomByMac(ws);
const targetPhone = findPhoneByRequestId(room, message.id);
if (targetPhone) {
  targetPhone.send(JSON.stringify(message));
}
```

3. **Use the `ws` library for WebSocket in Node.js**

4. **Enable CORS for HTTP endpoints**

## Testing

You can test with these tools:
- `wscat` for WebSocket testing
- Postman/curl for HTTP endpoints
- Multiple browser tabs simulating different clients

Test scenarios:
1. Mac connects and gets room ID
2. iPhone joins with room ID
3. iPhone sends http-request
4. Mac responds with http-response
5. Mac sends sse-event (should go to all phones)
6. Mac disconnects (phones should be notified)

## Deployment

This should run on Replit with zero configuration. Just:
1. Create a new Node.js or Bun repl
2. Install `ws` package
3. Set up the WebSocket server
4. Replit will automatically expose it with SSL

The final URLs will be:
- `wss://your-repl-name.your-username.repl.co` - WebSocket endpoint
- `https://your-repl-name.your-username.repl.co/health` - Health check
- `https://your-repl-name.your-username.repl.co/` - Info page