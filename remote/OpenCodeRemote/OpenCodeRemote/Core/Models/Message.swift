import Foundation

struct Message: Codable, Identifiable {
    let id: String
    let sessionID: String
    let role: MessageRole
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "sessionId"
        case role
        case createdAt
        case updatedAt
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

struct MessagePart: Codable, Identifiable {
    let id = UUID()
    let type: MessagePartType
    let text: String?
    let toolUseID: String?
    let toolName: String?
    let input: [String: Any]?
    let output: String?
    let isError: Bool?
    
    init(type: MessagePartType, text: String? = nil, toolUseID: String? = nil, toolName: String? = nil, input: [String: Any]? = nil, output: String? = nil, isError: Bool? = nil) {
        self.type = type
        self.text = text
        self.toolUseID = toolUseID
        self.toolName = toolName
        self.input = input
        self.output = output
        self.isError = isError
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case toolUseID = "toolUseId"
        case toolName
        case input
        case output
        case isError
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(MessagePartType.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        toolUseID = try container.decodeIfPresent(String.self, forKey: .toolUseID)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        output = try container.decodeIfPresent(String.self, forKey: .output)
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError)
        
        if let inputData = try? container.decodeIfPresent(Data.self, forKey: .input),
           let json = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] {
            input = json
        } else {
            input = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(toolUseID, forKey: .toolUseID)
        try container.encodeIfPresent(toolName, forKey: .toolName)
        try container.encodeIfPresent(output, forKey: .output)
        try container.encodeIfPresent(isError, forKey: .isError)
        
        if let input = input {
            let data = try JSONSerialization.data(withJSONObject: input)
            try container.encode(data, forKey: .input)
        }
    }
}

enum MessagePartType: String, Codable {
    case text
    case toolUse = "tool_use"
    case toolResult = "tool_result"
}

struct MessageRequest: Codable {
    let messageID: String
    let providerID: String
    let modelID: String
    let mode: String
    let parts: [MessagePart]
    
    enum CodingKeys: String, CodingKey {
        case messageID = "messageId"
        case providerID = "providerId"
        case modelID = "modelId"
        case mode
        case parts
    }
}

struct MessageListResponse: Codable {
    let messages: [MessageWithParts]
}

struct MessageWithParts: Codable, Identifiable {
    let info: Message
    let parts: [MessagePart]
    
    var id: String {
        info.id
    }
}