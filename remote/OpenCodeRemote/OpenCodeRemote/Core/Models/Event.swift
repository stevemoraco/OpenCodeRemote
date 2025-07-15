import Foundation

struct OpenCodeEvent: Codable {
    let type: String
    let payload: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case type
        case payload
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        // Decode payload as generic dictionary
        if let payloadData = try? container.decode(Data.self, forKey: .payload),
           let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
            payload = json
        } else {
            payload = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try container.encode(data, forKey: .payload)
        }
    }
}

struct SessionUpdatedPayload: Codable {
    let sessionID: String
    let session: Session
    
    enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case session
    }
}

struct MessageUpdatedPayload: Codable {
    let sessionID: String
    let messageID: String
    let message: MessageWithParts
    
    enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case messageID = "messageId"
        case message
    }
}

struct SessionIdlePayload: Codable {
    let sessionID: String
    
    enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
    }
}