import Foundation
import SwiftUI
import Combine

class HybridConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var sessions: [Session] = []
    @Published var connectionError: String?
    @Published var discoveredInstances: [OpenCodeInstance] = []
    @Published var isDiscovering = false
    @Published var connectionLogs: [ConnectionLog] = []
    
    struct ConnectionLog: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
    }
    
    enum LogLevel {
        case info
        case warning
        case error
        
        var color: Color {
            switch self {
            case .info: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    var baseURL: String
    private var discoveryTimer: Timer?
    private var eventSource: EventSource?
    
    init(baseURL: String = "http://localhost:5173") {
        self.baseURL = baseURL
        setupURLSession()
        startDiscovery()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: .main)
    }
    
    // MARK: - Connection Methods
    
    func connect() async {
        log("Connecting to \(baseURL)...")
        await connectToURL(baseURL)
    }
    
    private func connectToURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            connectionError = "Invalid URL"
            return
        }
        
        // First, verify the server is running by checking /app endpoint
        let appURL = URL(string: "\(urlString)/app")!
        
        do {
            log("Checking server at \(appURL)")
            let (data, response) = try await URLSession.shared.data(from: appURL)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                connectionError = "Server not responding"
                log("Server not responding at \(appURL)", level: .error)
                return
            }
            
            // Parse app info to verify it's OpenCode
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["hostname"] != nil && json["path"] != nil {
                log("Found OpenCode server, connecting to SSE...")
                // Connect to SSE endpoint
                await connectToSSE(baseURL: urlString)
            } else {
                connectionError = "Not an OpenCode server"
                log("Not an OpenCode server at \(appURL)", level: .warning)
            }
        } catch {
            connectionError = error.localizedDescription
            log("Error connecting: \(error.localizedDescription)", level: .error)
        }
    }
    
    private func connectToSSE(baseURL: String) async {
        guard let url = URL(string: baseURL) else { return }
        let eventsURL = url.appendingPathComponent("api/session/events")
        
        log("Connecting to SSE at \(eventsURL)")
        
        eventSource?.close()
        eventSource = EventSource(url: eventsURL)
        
        eventSource?.onMessage = { [weak self] event in
            Task { @MainActor in
                self?.log("Received SSE event")
                self?.handleSSEEvent(event)
            }
        }
        
        eventSource?.onError = { [weak self] error in
            Task { @MainActor in
                self?.connectionError = error.localizedDescription
                self?.isConnected = false
                self?.log("SSE error: \(error.localizedDescription)", level: .error)
            }
        }
        
        eventSource?.connect()
        isConnected = true
        log("SSE connection established")
    }
    
    private func handleSSEEvent(_ event: ServerSentEvent) {
        guard let data = event.data?.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "session.list":
            if let sessionsData = json["sessions"] as? [[String: Any]] {
                updateSessions(from: sessionsData)
            }
        case "session.created", "session.updated":
            if let sessionData = json["session"] as? [String: Any] {
                updateSession(from: sessionData)
            }
        case "session.deleted":
            if let sessionId = json["sessionId"] as? String {
                removeSession(id: sessionId)
            }
        default:
            break
        }
    }
    
    private func updateSessions(from data: [[String: Any]]) {
        sessions = data.compactMap { sessionData in
            guard let id = sessionData["id"] as? String else {
                return nil
            }
            
            let dateFormatter = ISO8601DateFormatter()
            let createdAt = sessionData["createdAt"] as? String ?? ""
            let updatedAt = sessionData["updatedAt"] as? String ?? ""
            
            return Session(
                id: id,
                title: sessionData["title"] as? String,
                createdAt: dateFormatter.date(from: createdAt) ?? Date(),
                updatedAt: dateFormatter.date(from: updatedAt) ?? Date(),
                parentID: sessionData["parentId"] as? String
            )
        }
    }
    
    private func updateSession(from data: [String: Any]) {
        guard let id = data["id"] as? String else {
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let createdAt = data["createdAt"] as? String ?? ""
        let updatedAt = data["updatedAt"] as? String ?? ""
        
        let session = Session(
            id: id,
            title: data["title"] as? String,
            createdAt: dateFormatter.date(from: createdAt) ?? Date(),
            updatedAt: dateFormatter.date(from: updatedAt) ?? Date(),
            parentID: data["parentId"] as? String
        )
        
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }
    
    private func removeSession(id: String) {
        sessions.removeAll { $0.id == id }
    }
    
    func sendMessage(_ text: String, to session: Session) async {
        guard let url = URL(string: baseURL) else { return }
        
        let messageURL = url.appendingPathComponent("sessions/\(session.id)/messages")
        var request = URLRequest(url: messageURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["content": text, "role": "user"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                connectionError = "Failed to send message"
            }
        } catch {
            connectionError = error.localizedDescription
        }
    }
    
    func disconnect() {
        eventSource?.close()
        eventSource = nil
        isConnected = false
        sessions = []
        connectionError = nil
        stopDiscovery()
    }
    
    // MARK: - Discovery Methods
    
    private func startDiscovery() {
        // Initial discovery
        Task {
            await discoverInstances()
        }
        
        // Periodic discovery every 5 seconds
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.discoverInstances()
            }
        }
    }
    
    private func stopDiscovery() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil
    }
    
    @MainActor
    func discoverInstances() async {
        isDiscovering = true
        let instances = await OpenCodeDiscovery.discoverRunningInstances()
        discoveredInstances = instances
        isDiscovering = false
        
        // If we're not connected and found instances, try to connect to the first one
        if !isConnected && !instances.isEmpty {
            await connectToFirstAvailableInstance()
        }
    }
    
    func connectToFirstAvailableInstance() async {
        for instance in discoveredInstances {
            baseURL = instance.url
            await connect()
            if isConnected {
                break
            }
        }
    }
    
    func connectToInstance(_ instance: OpenCodeInstance) async {
        baseURL = instance.url
        await connect()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String, level: LogLevel = .info) {
        let log = ConnectionLog(timestamp: Date(), level: level, message: message)
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
}

// Simple EventSource implementation
class EventSource {
    private let url: URL
    private var task: URLSessionDataTask?
    private var session: URLSession
    
    var onMessage: ((ServerSentEvent) -> Void)?
    var onError: ((Error) -> Void)?
    
    init(url: URL) {
        self.url = url
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        self.session = URLSession(configuration: config)
    }
    
    func connect() {
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.onError?(error)
                return
            }
            
            guard let data = data,
                  let string = String(data: data, encoding: .utf8) else {
                return
            }
            
            // Parse SSE data
            let lines = string.components(separatedBy: "\n")
            var eventData = ""
            
            for line in lines {
                if line.hasPrefix("data: ") {
                    eventData = String(line.dropFirst(6))
                } else if line.isEmpty && !eventData.isEmpty {
                    let event = ServerSentEvent(data: eventData)
                    self?.onMessage?(event)
                    eventData = ""
                }
            }
        }
        
        task?.resume()
    }
    
    func close() {
        task?.cancel()
        task = nil
    }
}

struct ServerSentEvent {
    let data: String?
}