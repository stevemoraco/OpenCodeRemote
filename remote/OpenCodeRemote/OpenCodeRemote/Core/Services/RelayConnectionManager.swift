import Foundation
import Combine

class RelayConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var roomCode: String?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var error: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var relayURL: URL
    private var pingTimer: Timer?
    private var messageHandler: ((RelayMessage) -> Void)?
    
    static let defaultRelayURL = "wss://opencoderemote.replit.app"
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case registering
        case ready
    }
    
    enum RelayMessage: Codable {
        case macRegister
        case phoneJoin(roomID: String)
        case httpRequest(request: HTTPRequest)
        case httpResponse(response: HTTPResponse)
        case sseEvent(event: SSEEvent)
        case roomCreated(roomID: String)
        case joinSuccess
        case error(message: String, code: String)
        
        struct HTTPRequest: Codable {
            let id: String
            let method: String
            let path: String
            let headers: [String: String]?
            let body: String?
        }
        
        struct HTTPResponse: Codable {
            let id: String
            let status: Int
            let headers: [String: String]?
            let body: String?
        }
        
        struct SSEEvent: Codable {
            let event: String
            let data: String
        }
    }
    
    init(relayURL: String? = nil) {
        self.urlSession = URLSession(configuration: .default)
        
        // Use provided URL or load from UserDefaults, fallback to default
        let urlString = relayURL ?? UserDefaults.standard.string(forKey: "RelayServerURL") ?? Self.defaultRelayURL
        self.relayURL = URL(string: urlString) ?? URL(string: Self.defaultRelayURL)!
    }
    
    // MARK: - Configuration
    
    func updateRelayURL(_ urlString: String) {
        // Disconnect if connected
        if isConnected {
            disconnect()
        }
        
        // Update URL and save to UserDefaults
        if let url = URL(string: urlString) {
            self.relayURL = url
            UserDefaults.standard.set(urlString, forKey: "RelayServerURL")
        }
    }
    
    func getCurrentRelayURL() -> String {
        return relayURL.absoluteString
    }
    
    // MARK: - Mac Functions
    
    func registerAsMac() {
        connectionState = .connecting
        connect { [weak self] in
            self?.sendMessage(.macRegister)
            self?.connectionState = .registering
        }
    }
    
    // MARK: - iPhone Functions
    
    func joinAsPhone(roomCode: String) {
        self.roomCode = roomCode
        connectionState = .connecting
        connect { [weak self] in
            self?.sendMessage(.phoneJoin(roomID: roomCode))
            self?.connectionState = .registering
        }
    }
    
    // MARK: - Connection Management
    
    private func connect(completion: @escaping () -> Void) {
        webSocketTask = urlSession.webSocketTask(with: relayURL)
        webSocketTask?.resume()
        
        isConnected = true
        connectionState = .connected
        
        // Start receiving messages
        receiveMessage()
        
        // Start ping timer
        startPingTimer()
        
        completion()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        isConnected = false
        connectionState = .disconnected
        roomCode = nil
        error = nil
    }
    
    // MARK: - Message Handling
    
    private func sendMessage(_ message: RelayMessage) {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(message)
            let string = String(data: data, encoding: .utf8)!
            
            webSocketTask.send(.string(string)) { [weak self] error in
                if let error = error {
                    self?.handleError(error)
                }
            }
        } catch {
            handleError(error)
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving
                self?.receiveMessage()
                
            case .failure(let error):
                self?.handleError(error)
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let decoder = JSONDecoder()
            
            // First try to decode the type
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String {
                
                switch type {
                case "room-created":
                    if let roomID = json["roomID"] as? String {
                        DispatchQueue.main.async {
                            self.roomCode = roomID
                            self.connectionState = .ready
                        }
                    }
                    
                case "join-success":
                    DispatchQueue.main.async {
                        self.connectionState = .ready
                    }
                    
                case "error":
                    if let message = json["message"] as? String {
                        DispatchQueue.main.async {
                            self.error = message
                        }
                    }
                    
                case "http-response":
                    // Handle HTTP response
                    messageHandler?(.httpResponse(response: try decoder.decode(RelayMessage.HTTPResponse.self, from: data)))
                    
                case "sse-event":
                    // Handle SSE event
                    messageHandler?(.sseEvent(event: try decoder.decode(RelayMessage.SSEEvent.self, from: data)))
                    
                case "pong":
                    // Heartbeat response
                    break
                    
                default:
                    print("Unknown message type: \(type)")
                }
            }
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.error = error.localizedDescription
            self.disconnect()
        }
    }
    
    // MARK: - Heartbeat
    
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        guard let webSocketTask = webSocketTask else { return }
        
        let pingMessage = "{\"type\":\"ping\"}"
        webSocketTask.send(.string(pingMessage)) { error in
            if error != nil {
                // Connection might be dead
            }
        }
    }
    
    // MARK: - HTTP Proxy
    
    func sendHTTPRequest(_ request: RelayMessage.HTTPRequest) {
        sendMessage(.httpRequest(request: request))
    }
    
    func onMessage(_ handler: @escaping (RelayMessage) -> Void) {
        self.messageHandler = handler
    }
}