# Product Requirements Document: OpenCode for iPhone

## Executive Summary

OpenCode for iPhone is a mobile companion app that enables users to remotely control and monitor their OpenCode AI coding sessions from their iOS device. Leveraging OpenCode's client/server architecture, the app provides a streamlined interface for managing coding tasks, viewing progress, and interacting with the AI assistant while away from the terminal.

## Product Vision

Transform the iPhone into a powerful remote control for OpenCode, enabling developers to:
- Monitor and guide AI coding sessions from anywhere
- Review code changes and approve actions on the go
- Orchestrate multiple OpenCode instances across different machines
- Maintain coding momentum during commutes or meetings

## Target Users

### Primary Users
- **Mobile Developers**: Need to monitor long-running tasks while away from desk
- **DevOps Engineers**: Managing multiple servers/instances remotely
- **Tech Leads**: Reviewing AI-generated code changes during meetings
- **Digital Nomads**: Working from various locations without consistent desktop access

### User Personas

1. **Sarah, Senior Developer**
   - Commutes 1 hour daily
   - Wants to review AI progress during transit
   - Needs to approve/reject changes before meetings

2. **Mike, DevOps Lead**
   - Manages 5+ development servers
   - Needs to monitor multiple OpenCode instances
   - Requires quick access to abort/restart sessions

3. **Alex, Freelance Developer**
   - Works from cafes and co-working spaces
   - Uses phone to check on long-running refactoring tasks
   - Needs secure remote access to home workstation

## Core Features

### 1. Session Management
- **Session List View**
  - Display all active/recent sessions
  - Show session status, duration, and last activity
  - Quick actions: Resume, Archive, Delete
  - Search and filter capabilities

- **Session Creation**
  - Start new session with custom prompts
  - Select target directory/project
  - Choose AI model and provider
  - Set session parameters (temperature, max tokens)

### 2. Chat Interface
- **Message View**
  - Real-time streaming of AI responses
  - Syntax-highlighted code blocks
  - Collapsible tool invocations
  - File change previews
  - Cost and token usage display

- **Message Composition**
  - Text input with keyboard shortcuts
  - Voice-to-text for hands-free operation
  - Quick prompt templates
  - File/image attachment support

### 3. Code Review
- **Diff Viewer**
  - Side-by-side or unified diff view
  - Syntax highlighting
  - Swipe to approve/reject changes
  - Inline comments

- **File Browser**
  - Navigate project structure
  - View file contents
  - Search within files
  - Recent changes highlight

### 4. Real-time Monitoring
- **Live Activity Widget**
  - Current task progress
  - Active tool invocations
  - Error notifications
  - Quick abort button

- **Push Notifications**
  - Task completion alerts
  - Error/warning notifications
  - Permission requests
  - Cost threshold warnings

### 5. Multi-Instance Management
- **Server Dashboard**
  - List connected OpenCode servers
  - Server health status
  - Resource usage metrics
  - Quick connect/disconnect

- **Instance Switching**
  - Swipe between active instances
  - Grouped by project/server
  - Visual indicators for activity

## Technical Architecture

### iOS App Architecture

```
OpenCodeiOS/
├── Core/
│   ├── API/
│   │   ├── OpenCodeClient.swift      # Main API client
│   │   ├── SSEClient.swift           # Server-sent events
│   │   ├── Models/                   # Codable models
│   │   └── Authentication/           # Auth handling
│   ├── Storage/
│   │   ├── CoreData/                 # Local persistence
│   │   ├── KeychainManager.swift     # Secure storage
│   │   └── CacheManager.swift        # Response caching
│   └── Services/
│       ├── SessionService.swift      # Session management
│       ├── MessageService.swift      # Message handling
│       └── NotificationService.swift # Push notifications
├── Features/
│   ├── Sessions/                     # Session list/detail
│   ├── Chat/                         # Chat interface
│   ├── CodeReview/                   # Diff viewer
│   ├── FileBrowser/                  # File navigation
│   └── Settings/                     # App configuration
├── Shared/
│   ├── UI/                           # Reusable components
│   ├── Extensions/                   # Swift extensions
│   └── Utilities/                    # Helper functions
└── Resources/
    ├── Assets.xcassets
    └── Localizations/
```

### Key Technical Components

1. **API Client**
   - URLSession-based HTTP client
   - Codable models matching OpenCode API
   - Async/await for modern Swift concurrency
   - Automatic retry with exponential backoff

2. **Real-time Updates**
   - EventSource implementation for SSE
   - Background task handling
   - Reconnection logic
   - Message queue for offline support

3. **Security**
   - Keychain storage for credentials
   - Certificate pinning for HTTPS
   - Biometric authentication
   - Encrypted local storage

4. **Performance**
   - Lazy loading for large files
   - Image/diff caching
   - Pagination for message history
   - Background refresh

## User Interface Design

### Design Principles
- **Clarity**: Clear visual hierarchy, readable code
- **Efficiency**: Minimal taps to complete tasks
- **Familiarity**: iOS-native patterns and gestures
- **Accessibility**: VoiceOver support, Dynamic Type

### Key Screens

1. **Home/Dashboard**
   - Active session cards
   - Quick action buttons
   - Server status indicators
   - Recent activity feed

2. **Session Detail**
   - Chat-like interface
   - Floating action button
   - Pull-to-refresh
   - Swipe actions

3. **Code Review**
   - Familiar diff interface
   - Pinch to zoom
   - Syntax highlighting
   - Quick approve/reject

4. **Settings**
   - Server configuration
   - Notification preferences
   - Theme selection
   - About/help

## Security & Privacy

### Authentication
- **Initial Setup**: QR code scanning or manual server entry
- **API Key Storage**: Secure enclave when available
- **Session Tokens**: Short-lived, refreshable tokens
- **Biometric Lock**: Face ID/Touch ID for app access

### Network Security
- **HTTPS Only**: Enforce encrypted connections
- **Certificate Pinning**: Prevent MITM attacks
- **VPN Support**: Work with corporate VPNs
- **Local Network**: Support for local server discovery

### Data Privacy
- **No Analytics**: No third-party tracking
- **Local First**: Cache data locally when possible
- **Clear Data**: Easy data deletion options
- **GDPR Compliant**: User data control

## Implementation Phases

### Phase 1: MVP
- Basic session list and detail
- Text-based chat interface
- Simple authentication
- Core API integration

### Phase 2: Enhanced Features
- Code diff viewer
- File browser
- Push notifications
- Live Activity widget

### Phase 3: Advanced Features
- Multi-server support
- Voice input
- Offline mode
- iPad optimization

### Phase 4: Polish & Scale
- Performance optimization
- Accessibility audit
- Localization
- App Store optimization

## Success Metrics

### User Engagement
- Daily Active Users (DAU)
- Session duration
- Messages sent per session
- Feature adoption rates

### Technical Performance
- API response times
- Crash-free rate (>99.5%)
- Network error rate (<1%)
- Battery impact (<5%)

### Business Impact
- User retention
- App Store ratings (>4.5)
- Support ticket volume
- Feature request patterns

## Risks & Mitigations

### Technical Risks
- **API Changes**: Version compatibility checks
- **Network Reliability**: Robust offline mode
- **Performance**: Efficient data handling
- **Security**: Regular security audits

### User Experience Risks
- **Complexity**: Progressive disclosure
- **Mobile Limitations**: Clear feature boundaries
- **Notification Fatigue**: Smart filtering
- **Learning Curve**: Onboarding flow

## Future Considerations

### Potential Features
- Apple Watch companion app
- Siri Shortcuts integration
- SharePlay for pair programming
- AR code visualization
- Multi-window support on iPad

### Platform Expansion
- Android version
- Web-based client
- VS Code extension integration
- CLI remote control

## Conclusion

OpenCode for iPhone represents a natural evolution of the OpenCode ecosystem, bringing the power of AI-assisted coding to mobile devices. By focusing on remote monitoring, quick interactions, and seamless synchronization, the app will enable developers to maintain productivity and control over their AI coding sessions from anywhere.

The phased approach ensures we can deliver value quickly while building toward a comprehensive mobile experience that complements the terminal-based interface. With careful attention to security, performance, and user experience, OpenCode for iPhone can become an indispensable tool for modern developers.