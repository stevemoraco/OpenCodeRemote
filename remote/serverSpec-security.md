# Security & Scaling Addendum for WebSocket Relay Server

## Security Requirements for Production Scale

### 1. Room ID Security
- **Longer Room IDs**: For production with thousands of users, use 8-12 character room IDs instead of 8
- **Rate Limiting**: Limit room creation to 5 per IP per hour
- **Brute Force Protection**: After 10 failed join attempts, block IP for 15 minutes
- **Room Passwords (Optional)**: Add optional password field for extra security

### 2. Connection Limits
```javascript
const limits = {
  maxRoomsPerIP: 10,
  maxPhonesPerRoom: 5,
  maxMessageSize: 10 * 1024 * 1024, // 10MB
  maxRequestsPerMinute: 100,
  maxConcurrentConnections: 10000
}
```

### 3. Authentication & Authorization
- **Device Tokens**: Generate unique tokens for each device on first connection
- **Room Ownership**: Only the Mac that created a room can register as its Mac
- **Message Validation**: Verify all messages match expected schema before forwarding

### 4. Data Isolation
- **No Cross-Room Access**: Ensure rooms are completely isolated
- **No Message History**: Don't store any messages - pure relay only
- **Connection Mapping**: Use WeakMaps where possible to prevent memory leaks

### 5. Rate Limiting Implementation
```javascript
const rateLimiter = {
  connections: new Map(), // IP -> { count, resetTime }
  messages: new Map(),    // connectionId -> { count, resetTime }
  
  checkLimit(identifier, limit, windowMs) {
    const now = Date.now();
    const record = this.get(identifier) || { count: 0, resetTime: now + windowMs };
    
    if (now > record.resetTime) {
      record.count = 0;
      record.resetTime = now + windowMs;
    }
    
    record.count++;
    return record.count <= limit;
  }
}
```

### 6. Monitoring & Alerts
- **Metrics to Track**:
  - Active rooms count
  - Connections per room
  - Message throughput
  - Error rates
  - Memory usage
  - CPU usage

- **Alert Thresholds**:
  - > 80% memory usage
  - > 1000 rooms active
  - > 50 errors per minute
  - Any room with > 10 phones

### 7. Scaling Architecture

For thousands of users, consider:

**Option A: Single Replit Instance** (Good for ~1000 concurrent users)
- Use Node.js cluster module
- Implement connection pooling
- Add Redis for room state (if Replit supports)

**Option B: Multiple Replit Instances** (For 1000+ users)
- Use consistent hashing for room assignment
- Implement instance discovery
- Add health check endpoints

### 8. Security Headers
```javascript
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000');
  next();
});
```

### 9. Input Validation
- **Room ID Format**: Strict regex validation `^[A-Z]{4}-[0-9]{4}$`
- **Message Size**: Reject messages > 10MB
- **JSON Parsing**: Wrap in try-catch, disconnect on invalid JSON
- **Path Validation**: Ensure paths don't contain `..` or absolute paths

### 10. Graceful Degradation
- **Connection Limits**: Return friendly error when at capacity
- **Automatic Cleanup**: Remove inactive rooms after 1 hour (not 24)
- **Memory Management**: Implement circuit breaker if memory > 90%

## Implementation Priority

1. **Must Have** (for any production use):
   - Rate limiting
   - Input validation
   - Connection limits
   - Basic monitoring

2. **Should Have** (for 100+ users):
   - Longer room IDs
   - IP blocking
   - Metrics dashboard
   - Memory management

3. **Nice to Have** (for 1000+ users):
   - Multiple instances
   - Redis backing
   - Advanced analytics
   - DDoS protection

## Testing for Scale

1. **Load Testing Script**:
```javascript
// Simulate 1000 concurrent connections
for (let i = 0; i < 1000; i++) {
  const ws = new WebSocket('wss://relay.repl.co');
  // Simulate Mac registration and iPhone connections
}
```

2. **Security Testing**:
- Try to access other rooms
- Send malformed messages
- Attempt rapid reconnections
- Test large message payloads

3. **Monitoring During Test**:
- Watch memory usage
- Check response times
- Monitor error rates
- Verify room isolation