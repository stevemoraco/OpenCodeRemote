import Foundation

struct Session: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let createdAt: Date
    let updatedAt: Date
    let parentID: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case updatedAt
        case parentID = "parentId"
    }
}

struct SessionListResponse: Codable {
    let sessions: [Session]
}

struct CreateSessionRequest: Codable {
    let parentID: String?
    
    enum CodingKeys: String, CodingKey {
        case parentID = "parentId"
    }
}

struct InitSessionRequest: Codable {
    let agentsMD: String
    
    enum CodingKeys: String, CodingKey {
        case agentsMD = "agentsMd"
    }
}