import Foundation

struct MokelayPage: Decodable, Identifiable, Equatable {
    let uuid: String
    let name: String
    let blocks: [MokelayBlock]
    let createdAt: String?
    let updatedAt: String?

    var id: String {
        uuid
    }

    private enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case blocks
        case createdAt
        case updatedAt
        case createdAtSnake = "created_at"
        case updatedAtSnake = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        blocks = try container.decodeIfPresent([MokelayBlock].self, forKey: .blocks) ?? []
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .createdAtSnake)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
            ?? container.decodeIfPresent(String.self, forKey: .updatedAtSnake)
    }
}

struct MokelayBlock: Decodable, Identifiable, Equatable {
    let id: String
    let type: String
    let data: [String: JSONValue]

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        data = try container.decodeIfPresent([String: JSONValue].self, forKey: .data) ?? [:]
    }

    func stringData(_ key: String) -> String? {
        data[key]?.stringValue
    }
}
