import Foundation

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
            return
        }

        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported JSON value."
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        guard case .string(let value) = self else {
            return nil
        }

        return value
    }

    var numberValue: Double? {
        guard case .number(let value) = self else {
            return nil
        }

        return value
    }

    var boolValue: Bool? {
        guard case .bool(let value) = self else {
            return nil
        }

        return value
    }

    var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else {
            return nil
        }

        return value
    }

    var arrayValue: [JSONValue]? {
        guard case .array(let value) = self else {
            return nil
        }

        return value
    }

    var rawValue: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            return value.mapValues(\.rawValue)
        case .array(let value):
            return value.map(\.rawValue)
        case .null:
            return NSNull()
        }
    }

    var isTruthy: Bool {
        switch self {
        case .bool(let value):
            return value
        case .number(let value):
            return value > 0
        case .string(let value):
            return !value.isEmpty
        default:
            return false
        }
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let value) = self else {
            return nil
        }

        return value[key]
    }

    static func fromRaw(_ value: Any) -> JSONValue {
        switch value {
        case let value as String:
            return .string(value)
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .number(Double(value))
        case let value as Double:
            return .number(value)
        case let value as Float:
            return .number(Double(value))
        case let value as [String: Any]:
            return .object(value.mapValues(JSONValue.fromRaw))
        case let value as [Any]:
            return .array(value.map(JSONValue.fromRaw))
        default:
            return .null
        }
    }

    func value(atPath path: String) -> JSONValue? {
        let segments = path
            .split(separator: ".")
            .map(String.init)
            .filter { !$0.isEmpty }

        return value(atPathSegments: segments)
    }

    private func value(atPathSegments segments: [String]) -> JSONValue? {
        guard let segment = segments.first else {
            return self
        }

        let wantsArrayValue = segment.hasSuffix("[]")
        let normalizedSegment = wantsArrayValue ? String(segment.dropLast(2)) : segment

        guard case .object(let object) = self,
              let next = object[normalizedSegment] else {
            return nil
        }

        if wantsArrayValue, case .array = next {
            return segments.count == 1 ? next : next.value(atPathSegments: Array(segments.dropFirst()))
        }

        return next.value(atPathSegments: Array(segments.dropFirst()))
    }
}

extension JSONValue: CustomStringConvertible {
    var description: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let value):
            return "{\(value.keys.sorted().joined(separator: ", "))}"
        case .array(let value):
            return "[\(value.map(\.description).joined(separator: ", "))]"
        case .null:
            return "null"
        }
    }
}
