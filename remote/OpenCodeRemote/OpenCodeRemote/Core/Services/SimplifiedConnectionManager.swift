import Foundation
import Combine

// Simplified version for MVP
class ConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var serverURL: URL?
    @Published var sessions: [Session] = []
    @Published var currentSession: Session?
    @Published var messages: [MessageWithParts] = []
    @Published var error: String?
    
    private var apiClient: OpenCodeClient?
    
    func connectToServer(urlString: String) {
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            return
        }
        
        serverURL = url
        apiClient = OpenCodeClient(baseURL: url)
        isConnected = true
        
        Task {
            await loadSessions()
        }
    }
    
    func disconnect() {
        isConnected = false
        serverURL = nil
        apiClient = nil
        sessions = []
        currentSession = nil
        messages = []
    }
    
    func loadSessions() async {
        do {
            guard let client = apiClient else { return }
            let sessions = try await client.listSessions()
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
            guard let client = apiClient else { return }
            let session = try await client.createSession()
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
    }
    
    func loadMessages() async {
        do {
            guard let client = apiClient,
                  let session = currentSession else { return }
            
            let messages = try await client.listMessages(sessionID: session.id)
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
            guard let client = apiClient,
                  let session = currentSession else { return }
            
            let request = MessageRequest(
                messageID: UUID().uuidString,
                providerID: "anthropic",
                modelID: "claude-3-5-sonnet-latest",
                mode: "build",
                parts: [MessagePart(type: .text, text: text, toolUseID: nil, toolName: nil, input: nil, output: nil, isError: nil)]
            )
            
            try await client.sendMessage(sessionID: session.id, message: request)
            await loadMessages()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}