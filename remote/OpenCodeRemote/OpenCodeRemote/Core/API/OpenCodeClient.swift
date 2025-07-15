import Foundation

enum OpenCodeError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

class OpenCodeClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Session Management
    
    func listSessions() async throws -> [Session] {
        let response: SessionListResponse = try await request(
            method: "GET",
            path: "/session"
        )
        return response.sessions
    }
    
    func createSession(parentID: String? = nil) async throws -> Session {
        let body = CreateSessionRequest(parentID: parentID)
        return try await request(
            method: "POST",
            path: "/session",
            body: body
        )
    }
    
    func deleteSession(id: String) async throws {
        let _: EmptyResponse = try await request(
            method: "DELETE",
            path: "/session/\(id)"
        )
    }
    
    func abortSession(id: String) async throws {
        let _: EmptyResponse = try await request(
            method: "POST",
            path: "/session/\(id)/abort"
        )
    }
    
    func initSession(id: String, agentsMD: String) async throws {
        let body = InitSessionRequest(agentsMD: agentsMD)
        let _: EmptyResponse = try await request(
            method: "POST",
            path: "/session/\(id)/init",
            body: body
        )
    }
    
    // MARK: - Message Management
    
    func listMessages(sessionID: String) async throws -> [MessageWithParts] {
        let response: MessageListResponse = try await request(
            method: "GET",
            path: "/session/\(sessionID)/message"
        )
        return response.messages
    }
    
    func sendMessage(sessionID: String, message: MessageRequest) async throws {
        let _: EmptyResponse = try await request(
            method: "POST",
            path: "/session/\(sessionID)/message",
            body: message
        )
    }
    
    // MARK: - Provider Management
    
    func listProviders() async throws -> [Provider] {
        let response: ProvidersResponse = try await request(
            method: "GET",
            path: "/config/providers"
        )
        return response.providers
    }
    
    // MARK: - Private Methods
    
    private func request<T: Decodable>(
        method: String,
        path: String,
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw OpenCodeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenCodeError.invalidResponse
            }
            
            if httpResponse.statusCode >= 400 {
                if let errorData = try? decoder.decode(ErrorResponse.self, from: data) {
                    throw OpenCodeError.serverError(errorData.message)
                } else {
                    throw OpenCodeError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw OpenCodeError.decodingError(error)
            }
        } catch let error as OpenCodeError {
            throw error
        } catch {
            throw OpenCodeError.networkError(error)
        }
    }
}

// MARK: - Helper Types

private struct EmptyResponse: Codable {}

private struct ErrorResponse: Codable {
    let message: String
}