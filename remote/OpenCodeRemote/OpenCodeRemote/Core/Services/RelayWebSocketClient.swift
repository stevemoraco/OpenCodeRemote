import Foundation

protocol RelayWebSocketClientDelegate: AnyObject {
    func relayClient(_ client: RelayWebSocketClient, didReceiveMessage message: RelayMessage)
    func relayClient(_ client: RelayWebSocketClient, didFailWithError error: Error)
    func relayClientDidConnect(_ client: RelayWebSocketClient)
    func relayClientDidDisconnect(_ client: RelayWebSocketClient)
}

struct RelayMessage: Codable {
    let type: String
    let data: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        if let dataValue = try? container.decode(Data.self, forKey: .data),
           let json = try? JSONSerialization.jsonObject(with: dataValue) as? [String: Any] {
            data = json
        } else {
            data = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        if let data = data,
           let dataValue = try? JSONSerialization.data(withJSONObject: data) {
            try container.encode(dataValue, forKey: .data)
        }
    }
}

// Placeholder implementation
class RelayWebSocketClient {
    weak var delegate: RelayWebSocketClientDelegate?
    private let url: URL
    private let roomID: String
    
    init(url: URL, roomID: String) {
        self.url = url
        self.roomID = roomID
    }
    
    func connect() {
        // TODO: Implement WebSocket connection
    }
    
    func disconnect() {
        // TODO: Implement disconnect
    }
    
    func send(_ message: RelayMessage) {
        // TODO: Implement send
    }
}