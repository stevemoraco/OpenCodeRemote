import SwiftUI

struct ContentView: View {
    @StateObject private var connectionManager = HybridConnectionManager()
    @State private var selectedSession: Session?
    @State private var messageText = ""
    @State private var showingSettings = false
    @State private var showingConnectionLogs = false
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationView {
            // Main content - Sessions list
            VStack(spacing: 0) {
                // Connection status bar
                ConnectionStatusBar(connectionManager: connectionManager)
                    #if os(macOS)
                    .background(Color(NSColor.controlBackgroundColor))
                    #else
                    .background(Color(UIColor.systemBackground))
                    #endif
                
                Divider()
                
                // Sessions list
                if connectionManager.sessions.isEmpty && connectionManager.isConnected {
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Active Sessions")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Button("Create New Session") {
                            Task {
                                await connectionManager.createSession()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !connectionManager.isConnected {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Connecting to OpenCode...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text(connectionManager.connectionState)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if connectionManager.connectionState.contains("Connecting") {
                            Button("Cancel") {
                                connectionManager.disconnect()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("View Connection Logs") {
                            showingConnectionLogs = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(connectionManager.sessions, selection: $selectedSession) { session in
                        SessionRow(session: session, isSelected: selectedSession?.id == session.id)
                            .tag(session)
                    }
                    #if os(macOS)
                    .listStyle(SidebarListStyle())
                    #else
                    .listStyle(InsetGroupedListStyle())
                    #endif
                }
            }
            
            // Detail view
            if let session = selectedSession {
                SessionDetailView(session: session, connectionManager: connectionManager)
            } else {
                Text("Select a session")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("OpenCode Remote")
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                Button(action: {}) {
                    Image(systemName: "sidebar.left")
                }
            }
            #endif
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingConnectionLogs = true }) {
                    Image(systemName: "text.alignleft")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(connectionManager: connectionManager)
        }
        .sheet(isPresented: $showingConnectionLogs) {
            ConnectionLogsView(connectionManager: connectionManager)
        }
        .onAppear {
            // Auto-connect based on saved preferences
            connectionManager.autoConnect()
        }
    }
}

struct SessionDetailView: View {
    let session: Session
    @ObservedObject var connectionManager: HybridConnectionManager
    @State private var messageText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(session.title ?? "Untitled Session")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(formatDate(session.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            #if os(macOS)
            .background(Color(NSColor.controlBackgroundColor))
            #else
            .background(Color(UIColor.systemBackground))
            #endif
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(connectionManager.messages.filter { $0.info.sessionID == session.id }) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: connectionManager.messages.count) { _ in
                    if let lastMessage = connectionManager.messages.filter({ $0.info.sessionID == session.id }).last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        sendMessage()
                    }
                
                Button("Send") {
                    sendMessage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(messageText.isEmpty)
            }
            .padding()
            #if os(macOS)
            .background(Color(NSColor.controlBackgroundColor))
            #else
            .background(Color(UIColor.systemBackground))
            #endif
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        Task {
            await connectionManager.sendMessage(messageText, to: session)
            messageText = ""
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ConnectionStatusBar: View {
    @ObservedObject var connectionManager: HybridConnectionManager
    
    var body: some View {
        HStack {
            // Connection indicator
            Circle()
                .fill(connectionManager.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(connectionManager.isConnected ? "Connected" : connectionManager.connectionState)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Connection mode
            if connectionManager.isConnected {
                Label(connectionManager.connectionMode == .direct ? "Direct" : "Relay", 
                      systemImage: connectionManager.connectionMode == .direct ? "wifi" : "cloud")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if connectionManager.connectionMode == .relay, let roomCode = connectionManager.roomCode {
                    Text("Room: \(roomCode)")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct SessionRow: View {
    let session: Session
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundColor(isSelected ? .white : .accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title ?? "Untitled Session")
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)
                Text(formatDate(session.createdAt))
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MessageView: View {
    let message: MessageWithParts
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(message.info.role.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ForEach(message.parts) { part in
                switch part.type {
                case .text:
                    Text(part.text ?? "")
                        .font(.body)
                case .toolUse:
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                        Text("Tool: \(part.toolName ?? "Unknown")")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                case .toolResult:
                    Text("Result: \(part.output ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}