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
    let events: [MokelayBlockEvent]

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case data
        case events
    }

    init(
        id: String = UUID().uuidString,
        type: String = "unknown",
        data: [String: JSONValue] = [:],
        events: [MokelayBlockEvent] = []
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.events = events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        data = try container.decodeIfPresent([String: JSONValue].self, forKey: .data) ?? [:]
        events = try container.decodeIfPresent([MokelayBlockEvent].self, forKey: .events) ?? []
    }

    func stringData(_ key: String) -> String? {
        data[key]?.stringValue
    }

    static func fromJSONValue(_ value: JSONValue) -> MokelayBlock? {
        guard let object = value.objectValue else {
            return nil
        }

        return fromJSONObject(object)
    }

    static func fromJSONObject(_ object: [String: JSONValue]) -> MokelayBlock? {
        let type = object["type"]?.stringValue ?? ""

        guard !type.isEmpty else {
            return nil
        }

        return MokelayBlock(
            id: object["id"]?.stringValue ?? UUID().uuidString,
            type: type,
            data: object["data"]?.objectValue ?? [:],
            events: MokelayBlockEvent.events(from: object["events"])
        )
    }

    var jsonValue: JSONValue {
        .object([
            "id": .string(id),
            "type": .string(type),
            "data": .object(data)
        ])
    }
}
