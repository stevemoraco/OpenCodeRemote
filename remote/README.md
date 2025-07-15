# OpenCode Remote Apps

This directory contains mobile companion apps for OpenCode that enable remote control and monitoring of AI coding sessions.

## OpenCode for iPhone

OpenCode for iPhone is a mobile companion app that enables users to remotely control and monitor their OpenCode AI coding sessions from their iOS device. By leveraging OpenCode's client/server architecture, the app provides a streamlined interface for managing coding tasks, viewing progress, and interacting with the AI assistant while away from the terminal.

### Key Features

#### Session Management
- View and manage all active/recent OpenCode sessions
- Start new sessions with custom prompts
- Quick actions: Resume, Archive, Delete
- Search and filter capabilities

#### Real-time Chat Interface
- Live streaming of AI responses
- Syntax-highlighted code blocks
- Collapsible tool invocations
- File change previews
- Cost and token usage tracking

#### Code Review
- Side-by-side or unified diff views
- Swipe gestures to approve/reject changes
- Inline commenting
- Full syntax highlighting

#### Remote Monitoring
- Live Activity widgets for current tasks
- Push notifications for important events
- Real-time progress tracking
- Quick abort capabilities

#### Multi-Instance Support
- Connect to multiple OpenCode servers
- Switch between active instances
- Monitor server health and resource usage
- Visual activity indicators

### Technical Overview

The iOS app is built with:
- **SwiftUI** for the user interface
- **URLSession** for API communication
- **Server-Sent Events (SSE)** for real-time updates
- **Keychain** for secure credential storage
- **Core Data** for local persistence

### Security

- Biometric authentication (Face ID/Touch ID)
- Secure API key storage in Keychain
- Certificate pinning for HTTPS connections
- Support for VPN and local network connections

### Getting Started

1. Open the Xcode project in `remote/OpenCodeRemote/`
2. Configure your development team and bundle identifier
3. Build and run on your iOS device or simulator

### Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### Documentation

For detailed product requirements and technical architecture, see [OPENCODE_IPHONE_PRD.md](./OPENCODE_IPHONE_PRD.md).

## Future Platforms

- **Android**: Native Android app using Kotlin and Jetpack Compose
- **Apple Watch**: Companion app for quick status checks and actions
- **Web**: Progressive Web App for cross-platform access