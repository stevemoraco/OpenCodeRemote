import Foundation

struct Provider: Codable, Identifiable {
    let id: String
    let name: String
    let models: [Model]
}

struct Model: Codable, Identifiable {
    let id: String
    let name: String
    let contextWindow: Int?
    let maxOutput: Int?
    let inputPrice: Double?
    let outputPrice: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case contextWindow
        case maxOutput
        case inputPrice
        case outputPrice
    }
}

struct ProvidersResponse: Codable {
    let providers: [Provider]
}