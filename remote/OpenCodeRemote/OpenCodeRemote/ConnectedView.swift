import SwiftUI

struct ConnectedView: View {
    @ObservedObject var connectionManager: HybridConnectionManager
    @State private var selectedSession: Session?
    @State private var showingNewSession = false
    @State private var showingPhonePrompt = true
    @State private var messageText = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar with sessions
            VStack(spacing: 0) {
                // Connection Status Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("Connected to OpenCode")
                            .font(.headline)
                    }
                    
                    Text(connectionManager.baseURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if showingPhonePrompt {
                        HStack {
                            Image(systemName: "iphone")
                                .foregroundColor(.blue)
                            Text("Open the OpenCode app on your phone to enable remote access")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Button(action: {
                                showingPhonePrompt = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                
                Divider()
                
                // Sessions List
                if connectionManager.sessions.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No active sessions")
                            .foregroundColor(.secondary)
                        
                        Button("New Session") {
                            showingNewSession = true
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(connectionManager.sessions, selection: $selectedSession) { session in
                        SessionRow(session: session)
                            .tag(session)
                    }
                }
                
                Divider()
                
                // Bottom toolbar
                HStack {
                    Button(action: {
                        showingNewSession = true
                    }) {
                        Label("New Session", systemImage: "plus.circle")
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        connectionManager.disconnect()
                    }) {
                        Label("Disconnect", systemImage: "xmark.circle")
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .frame(width: 300)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Detail view
            if let session = selectedSession {
                SessionDetailView(
                    session: session,
                    connectionManager: connectionManager
                )
            } else {
                VStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Select a session to view messages")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingNewSession) {
            NewSessionView(connectionManager: connectionManager)
        }
        .task {
            await connectionManager.fetchSessions()
        }
    }
}

struct SessionRow: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title ?? "Untitled Session")
                .font(.headline)
            
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                Text(session.updatedAt, style: .relative)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SessionDetailView: View {
    let session: Session
    @ObservedObject var connectionManager: HybridConnectionManager
    @State private var messageText = ""
    @State private var messages: [MessageWithParts] = []
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title ?? "Untitled Session")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Session ID: \(session.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await connectionManager.deleteSession(session)
                    }
                }) {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            .padding()
            
            Divider()
            
            // Messages
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageView(message: message)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Input area
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .onAppear {
            loadMessages()
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        Task {
            await connectionManager.sendMessage(messageText, to: session)
            messageText = ""
            loadMessages()
        }
    }
    
    private func loadMessages() {
        // TODO: Implement message loading from connectionManager
        // For now, using placeholder
    }
}

struct MessageView: View {
    let message: MessageWithParts
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: message.info.role == .user ? "person.circle" : "cpu")
                    .foregroundColor(message.info.role == .user ? .blue : .green)
                
                Text(message.info.role == .user ? "You" : "Assistant")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(message.info.createdAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Display message parts
            ForEach(message.parts) { part in
                MessagePartView(part: part)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MessagePartView: View {
    let part: MessagePart
    
    var body: some View {
        switch part.type {
        case .text:
            if let text = part.text {
                Text(text)
                    .textSelection(.enabled)
            }
        case .toolUse:
            VStack(alignment: .leading) {
                Label(part.toolName ?? "Tool", systemImage: "wrench")
                    .font(.caption)
                    .foregroundColor(.orange)
                if let input = part.input {
                    Text("Input: \(String(describing: input))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        case .toolResult:
            VStack(alignment: .leading) {
                Label("Tool Result", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(part.isError == true ? .red : .green)
                if let output = part.output {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(4)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct NewSessionView: View {
    @ObservedObject var connectionManager: HybridConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var sessionTitle = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Session")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Title")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter title (optional)", text: $sessionTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Text("A new session will be created with the current context.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    Task {
                        await connectionManager.createSession(title: sessionTitle.isEmpty ? nil : sessionTitle)
                        dismiss()
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
    }
}