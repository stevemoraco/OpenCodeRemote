import Foundation
import Combine
import SwiftUI

// Manages both direct and relay connections
class HybridConnectionManager: ObservableObject {
    @Published var connectionMode: ConnectionMode = .none
    @Published var isConnected = false
    @Published var serverURL: URL?
    @Published var roomCode: String?
    @Published var sessions: [Session] = []
    @Published var currentSession: Session?
    @Published var messages: [MessageWithParts] = []
    @Published var error: String?
    @Published var connectionState: String = "Disconnected"
    @Published var connectionLogs: [ConnectionLog] = []
    
    private var directClient: OpenCodeClient?
    private var relayManager: RelayConnectionManager?
    private var sseClient: SSEClient?
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionMode {
        case none
        case direct
        case relay
    }
    
    init() {
        setupRelayManager()
    }
    
    private func setupRelayManager() {
        relayManager = RelayConnectionManager()
        
        // Subscribe to relay state changes
        relayManager?.$connectionState
            .sink { [weak self] state in
                if self?.connectionMode == .relay {
                    self?.updateConnectionState(for: state)
                }
            }
            .store(in: &cancellables)
        
        relayManager?.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.error = error
            }
            .store(in: &cancellables)
        
        relayManager?.$roomCode
            .sink { [weak self] code in
                self?.roomCode = code
            }
            .store(in: &cancellables)
        
        // Handle relay messages
        relayManager?.onMessage { [weak self] message in
            self?.handleRelayMessage(message)
        }
    }
    
    // MARK: - Direct Connection
    
    func connectDirect(urlString: String) {
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            return
        }
        
        disconnect()
        
        serverURL = url
        directClient = OpenCodeClient(baseURL: url)
        connectionMode = .direct
        isConnected = true
        connectionState = "Connected (Direct)"
        
        // Setup SSE for direct connection
        setupSSE(baseURL: url)
        
        Task {
            await loadSessions()
        }
    }
    
    // MARK: - Relay Connection (Mac)
    
    func startRelayServer() {
        disconnect()
        connectionMode = .relay
        connectionState = "Starting relay..."
        relayManager?.registerAsMac()
    }
    
    // MARK: - Relay Connection (iPhone)
    
    func joinRelayRoom(code: String) {
        disconnect()
        connectionMode = .relay
        roomCode = code
        connectionState = "Joining room..."
        relayManager?.joinAsPhone(roomCode: code)
    }
    
    // MARK: - Relay Configuration
    
    func updateRelayURL(_ urlString: String) {
        relayManager?.updateRelayURL(urlString)
    }
    
    func getCurrentRelayURL() -> String {
        return relayManager?.getCurrentRelayURL() ?? RelayConnectionManager.defaultRelayURL
    }
    
    // MARK: - Common Functions
    
    func disconnect() {
        isConnected = false
        connectionMode = .none
        serverURL = nil
        directClient = nil
        sessions = []
        currentSession = nil
        messages = []
        connectionState = "Disconnected"
        
        sseClient?.disconnect()
        sseClient = nil
        
        relayManager?.disconnect()
    }
    
    func loadSessions() async {
        do {
            let sessions: [Session]
            
            switch connectionMode {
            case .direct:
                guard let client = directClient else { return }
                sessions = try await client.listSessions()
                
            case .relay:
                // For relay, send HTTP request through WebSocket
                let request = RelayConnectionManager.RelayMessage.HTTPRequest(
                    id: UUID().uuidString,
                    method: "GET",
                    path: "/api/sessions",
                    headers: nil,
                    body: nil
                )
                
                // This would need to be async with a completion handler
                // For now, we'll skip relay session loading
                return
                
            case .none:
                return
            }
            
            await MainActor.run {
                self.sessions = sessions
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    func createSession() async {
        do {
            let session: Session
            
            switch connectionMode {
            case .direct:
                guard let client = directClient else { return }
                session = try await client.createSession()
                
            case .relay:
                // For relay, this would need async handling
                return
                
            case .none:
                return
            }
            
            await MainActor.run {
                self.sessions.append(session)
                self.currentSession = session
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    func selectSession(_ session: Session) async {
        currentSession = session
        await loadMessages()
        
        // Setup SSE for this session
        if connectionMode == .direct, let url = serverURL {
            setupSSE(baseURL: url, sessionID: session.id)
        }
    }
    
    func loadMessages() async {
        do {
            guard let session = currentSession else { return }
            let messages: [MessageWithParts]
            
            switch connectionMode {
            case .direct:
                guard let client = directClient else { return }
                messages = try await client.listMessages(sessionID: session.id)
                
            case .relay:
                // For relay, this would need async handling
                return
                
            case .none:
                return
            }
            
            await MainActor.run {
                self.messages = messages
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    func sendMessage(_ text: String) async {
        do {
            guard let session = currentSession else { return }
            
            let request = MessageRequest(
                messageID: UUID().uuidString,
                providerID: "anthropic",
                modelID: "claude-3-5-sonnet-latest",
                mode: "build",
                parts: [MessagePart(type: .text, text: text)]
            )
            
            switch connectionMode {
            case .direct:
                guard let client = directClient else { return }
                try await client.sendMessage(sessionID: session.id, message: request)
                
            case .relay:
                // For relay, convert to HTTP request
                let encoder = JSONEncoder()
                let body = try encoder.encode(request)
                let bodyString = String(data: body, encoding: .utf8)
                
                let httpRequest = RelayConnectionManager.RelayMessage.HTTPRequest(
                    id: UUID().uuidString,
                    method: "POST",
                    path: "/api/sessions/\(session.id)/messages",
                    headers: ["Content-Type": "application/json"],
                    body: bodyString
                )
                
                relayManager?.sendHTTPRequest(httpRequest)
                
            case .none:
                return
            }
            
            await loadMessages()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    // MARK: - SSE Handling
    
    private func setupSSE(baseURL: URL, sessionID: String? = nil) {
        sseClient?.disconnect()
        
        let path = sessionID != nil ? "/api/sessions/\(sessionID!)/events" : "/api/events"
        guard let sseURL = URL(string: path, relativeTo: baseURL) else { return }
        
        sseClient = SSEClient(url: sseURL)
        
        sseClient?.delegate = self
        
        sseClient?.connect()
    }
    
    private func handleSSEEvent(_ event: SSEEvent) {
        // Handle different event types
        switch event.event {
        case "message":
            // Refresh messages
            Task {
                await loadMessages()
            }
            
        case "session":
            // Refresh sessions
            Task {
                await loadSessions()
            }
            
        default:
            print("Unhandled SSE event: \(event.event ?? "unknown")")
        }
    }
    
    // MARK: - Relay Message Handling
    
    private func handleRelayMessage(_ message: RelayConnectionManager.RelayMessage) {
        switch message {
        case .httpResponse(let response):
            // Handle HTTP responses from relay
            handleRelayHTTPResponse(response)
            
        case .sseEvent(let event):
            // Convert relay SSE event to our SSE event
            let sseEvent = SSEEvent(
                id: nil,
                event: event.event,
                data: event.data,
                retry: nil
            )
            handleSSEEvent(sseEvent)
            
        default:
            break
        }
    }
    
    private func handleRelayHTTPResponse(_ response: RelayConnectionManager.RelayMessage.HTTPResponse) {
        // This would need to be implemented to handle async responses
        // For now, we'll just log it
        print("Received HTTP response: \(response.id) - Status: \(response.status)")
    }
    
    private func updateConnectionState(for relayState: RelayConnectionManager.ConnectionState) {
        switch relayState {
        case .disconnected:
            isConnected = false
            connectionState = "Disconnected"
        case .connecting:
            connectionState = "Connecting..."
        case .connected:
            connectionState = "Connected to relay"
        case .registering:
            connectionState = "Registering..."
        case .ready:
            isConnected = true
            if roomCode != nil {
                connectionState = "Connected (Relay: \(roomCode!))"
            } else {
                connectionState = "Relay ready"
            }
        }
    }
    
    // MARK: - Auto Connect
    
    func autoConnect() {
        log("Starting auto-connect...", level: .info)
        
        // Check saved preferences
        let savedMode = UserDefaults.standard.string(forKey: "PreferredConnectionMode") ?? "auto"
        let savedServerURL = UserDefaults.standard.string(forKey: "DirectServerURL") ?? "http://localhost:5173"
        
        switch savedMode {
        case "direct":
            log("Attempting direct connection to \(savedServerURL)", level: .info)
            connectDirect(urlString: savedServerURL)
        case "relay":
            log("Starting relay connection", level: .info)
            #if os(macOS)
            startRelayServer()
            #else
            // On iPhone, check if we have a saved room code
            if let savedRoomCode = UserDefaults.standard.string(forKey: "LastRoomCode") {
                log("Attempting to rejoin room: \(savedRoomCode)", level: .info)
                joinRelayRoom(code: savedRoomCode)
            }
            #endif
        default:
            // Auto mode - try direct first, then relay
            log("Auto mode: Trying direct connection first", level: .info)
            attemptAutoConnection(serverURL: savedServerURL)
        }
    }
    
    private func attemptAutoConnection(serverURL: String) {
        // Try direct connection with a timeout
        connectDirect(urlString: serverURL)
        
        // Set a timer to fall back to relay if direct fails
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self, !self.isConnected else { return }
            
            self.log("Direct connection failed, falling back to relay", level: .warning)
            self.disconnect()
            
            #if os(macOS)
            self.startRelayServer()
            #else
            // On iPhone, show settings to enter room code
            self.log("Please enter a room code in settings", level: .info)
            #endif
        }
    }
    
    // MARK: - Logging
    
    struct ConnectionLog: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let level: LogLevel
        let message: String
        
        enum LogLevel {
            case info
            case warning
            case error
            case success
            
            var color: Color {
                switch self {
                case .info: return .blue
                case .warning: return .orange
                case .error: return .red
                case .success: return .green
                }
            }
        }
    }
    
    func log(_ message: String, level: ConnectionLog.LogLevel = .info) {
        let log = ConnectionLog(level: level, message: message)
        DispatchQueue.main.async {
            self.connectionLogs.append(log)
            
            // Keep only last 1000 logs
            if self.connectionLogs.count > 1000 {
                self.connectionLogs.removeFirst(self.connectionLogs.count - 1000)
            }
        }
    }
    
    func clearLogs() {
        connectionLogs.removeAll()
    }
    
    // MARK: - Session Management
    
    func sendMessage(_ text: String, to session: Session) async {
        currentSession = session
        await sendMessage(text)
    }
}

// MARK: - SSEClientDelegate

extension HybridConnectionManager: SSEClientDelegate {
    func sseClient(_ client: SSEClient, didReceiveEvent event: SSEEvent) {
        handleSSEEvent(event)
    }
    
    func sseClient(_ client: SSEClient, didFailWithError error: Error) {
        self.error = error.localizedDescription
    }
    
    func sseClientDidConnect(_ client: SSEClient) {
        // Connection established
    }
    
    func sseClientDidDisconnect(_ client: SSEClient) {
        // Connection lost
    }
}