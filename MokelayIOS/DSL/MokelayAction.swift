import Foundation

struct MokelayBlockEvent: Decodable, Equatable {
    let event: String
    let actions: [MokelayActionConfig]

    private enum CodingKeys: String, CodingKey {
        case event
        case actions
    }

    init(event: String, actions: [MokelayActionConfig]) {
        self.event = event
        self.actions = actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        event = try container.decodeIfPresent(String.self, forKey: .event)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        actions = try container.decodeIfPresent([MokelayActionConfig].self, forKey: .actions) ?? []
    }

    static func events(from value: JSONValue?) -> [MokelayBlockEvent] {
        guard let values = value?.arrayValue else {
            return []
        }

        return values.compactMap { item in
            guard let object = item.objectValue else {
                return nil
            }

            let event = object["event"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let actions = MokelayActionConfig.actions(from: object["actions"])

            guard !event.isEmpty, !actions.isEmpty else {
                return nil
            }

            return MokelayBlockEvent(event: event, actions: actions)
        }
    }
}

struct MokelayActionConfig: Decodable, Equatable {
    let uuid: String
    let action: String
    let alias: String?
    let type: String?
    let inputs: [String: JSONValue]
    let outputs: [String]
    let nextAction: String?
    let nodes: [MokelayActionNode]

    private enum CodingKeys: String, CodingKey {
        case uuid
        case action
        case alias
        case type
        case inputs
        case outputs
        case nextAction
        case nodes
    }

    init(
        uuid: String,
        action: String,
        alias: String? = nil,
        type: String? = nil,
        inputs: [String: JSONValue] = [:],
        outputs: [String] = [],
        nextAction: String? = nil,
        nodes: [MokelayActionNode] = []
    ) {
        self.uuid = uuid
        self.action = action
        self.alias = alias
        self.type = type
        self.inputs = inputs
        self.outputs = outputs
        self.nextAction = nextAction
        self.nodes = nodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        action = try container.decodeIfPresent(String.self, forKey: .action)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        inputs = try container.decodeIfPresent([String: JSONValue].self, forKey: .inputs) ?? [:]
        outputs = try container.decodeIfPresent([String].self, forKey: .outputs) ?? []
        nextAction = Self.normalizedNextAction(try container.decodeIfPresent(String.self, forKey: .nextAction))
        nodes = try container.decodeIfPresent([MokelayActionNode].self, forKey: .nodes) ?? []
    }

    static func actions(from value: JSONValue?) -> [MokelayActionConfig] {
        guard let values = value?.arrayValue else {
            return []
        }

        var seen = Set<String>()
        return values.compactMap { item in
            guard let object = item.objectValue else {
                return nil
            }

            let uuid = object["uuid"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let action = object["action"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !uuid.isEmpty, !action.isEmpty, !seen.contains(uuid) else {
                return nil
            }

            seen.insert(uuid)
            return MokelayActionConfig(
                uuid: uuid,
                action: action,
                alias: object["alias"]?.stringValue,
                type: object["type"]?.stringValue,
                inputs: object["inputs"]?.objectValue ?? [:],
                outputs: object["outputs"]?.arrayValue?.compactMap(\.stringValue) ?? [],
                nextAction: normalizedNextAction(object["nextAction"]?.stringValue),
                nodes: MokelayActionNode.nodes(from: object["nodes"])
            )
        }
    }

    private static func normalizedNextAction(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct MokelayActionNode: Decodable, Equatable {
    let uuid: String
    let alias: String?
    let type: String?
    let value: JSONValue?
    let nextAction: String?

    private enum CodingKeys: String, CodingKey {
        case uuid
        case alias
        case type
        case value
        case nextAction
    }

    init(uuid: String, alias: String? = nil, type: String? = nil, value: JSONValue? = nil, nextAction: String? = nil) {
        self.uuid = uuid
        self.alias = alias
        self.type = type
        self.value = value
        self.nextAction = nextAction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        value = try container.decodeIfPresent(JSONValue.self, forKey: .value)
        nextAction = Self.normalizedNextAction(try container.decodeIfPresent(String.self, forKey: .nextAction))
    }

    static func nodes(from value: JSONValue?) -> [MokelayActionNode] {
        guard let values = value?.arrayValue else {
            return []
        }

        return values.compactMap { item in
            guard let object = item.objectValue else {
                return nil
            }

            let uuid = object["uuid"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !uuid.isEmpty else {
                return nil
            }

            return MokelayActionNode(
                uuid: uuid,
                alias: object["alias"]?.stringValue,
                type: object["type"]?.stringValue,
                value: object["value"],
                nextAction: normalizedNextAction(object["nextAction"]?.stringValue)
            )
        }
    }

    private static func normalizedNextAction(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
