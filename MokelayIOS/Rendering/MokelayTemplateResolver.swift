import Foundation

struct MokelayActionRecord {
    var inputs: [String: JSONValue]
    var outputs: [String: JSONValue]

    var jsonValue: JSONValue {
        .object([
            "inputs": .object(inputs),
            "outputs": .object(outputs)
        ])
    }
}

struct MokelayActionState {
    var actions: [String: MokelayActionRecord] = [:]
    var blocks: [String: [String: JSONValue]] = [:]
    var sourceBlock: MokelayBlock
    var event: JSONValue = .null
    var now: String = ISO8601DateFormatter().string(from: Date())

    var jsonContext: JSONValue {
        .object([
            "actions": .object(actions.mapValues(\.jsonValue)),
            "blocks": .object(blocks.mapValues { .object($0) }),
            "sourceBlock": sourceBlock.jsonValue,
            "event": event,
            "now": .string(now)
        ])
    }
}

enum MokelayTemplateError: LocalizedError {
    case missingVariable(String)
    case invalidPath(String)

    var errorDescription: String? {
        switch self {
        case .missingVariable(let path):
            return "Template variable was not found: \(path)"
        case .invalidPath(let path):
            return "Template path is invalid: \(path)"
        }
    }
}

enum MokelayTemplateResolver {
    private static let wholeTemplatePattern = #"^\s*\{\{\s*([^}]+?)\s*\}\}\s*$"#
    private static let templatePattern = #"\{\{\s*([^}]+?)\s*\}\}"#

    static func resolve(_ value: JSONValue, state: MokelayActionState) throws -> JSONValue {
        switch value {
        case .array(let values):
            return .array(try values.map { try resolve($0, state: state) })
        case .object(let object):
            if let template = object["template"]?.stringValue {
                let rendered = try renderTemplate(template, state: state)
                let processors = object["processors"]?.arrayValue ?? []
                return try MokelayProcessors.apply(rendered, processors: processors)
            }

            return .object(try object.mapValues { try resolve($0, state: state) })
        default:
            return value
        }
    }

    static func resolveVariableConfig(_ value: JSONValue, blocks: [String: [String: JSONValue]]) throws -> JSONValue {
        guard let object = value.objectValue else {
            return value
        }

        if object["mode"]?.stringValue == "input" {
            return object["value"] ?? .string("")
        }

        if object["mode"]?.stringValue == "variable" {
            let blockId = object["blockId"]?.stringValue ?? ""
            let variable = object["variable"]?.stringValue ?? ""
            let processors = object["processors"]?.arrayValue ?? []
            let rawValue = blocks[blockId]?[variable] ?? .string("")
            return try MokelayProcessors.apply(rawValue, processors: processors)
        }

        return value
    }

    static func interpolateString(_ value: String, row: [String: JSONValue]) -> String {
        guard let regex = try? NSRegularExpression(pattern: templatePattern) else {
            return value
        }

        let nsValue = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: nsValue.length))
        var result = value

        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else {
                continue
            }

            let path = nsValue.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = stringify(readRowPath(path, row: row) ?? .string(""))
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }

        return result
    }

    static func interpolateJSON(_ value: JSONValue, row: [String: JSONValue]) -> JSONValue {
        switch value {
        case .string(let string):
            return .string(interpolateString(string, row: row))
        case .array(let values):
            return .array(values.map { interpolateJSON($0, row: row) })
        case .object(let object):
            return .object(object.mapValues { interpolateJSON($0, row: row) })
        default:
            return value
        }
    }

    static func readPath(_ path: String, in context: JSONValue) throws -> JSONValue {
        let segments = try tokenize(path)
        var cursor = context

        for segment in segments {
            switch cursor {
            case .object(let object):
                guard let next = object[segment] else {
                    throw MokelayTemplateError.missingVariable(path)
                }
                cursor = next
            case .array(let values):
                guard let index = Int(segment),
                      values.indices.contains(index) else {
                    throw MokelayTemplateError.missingVariable(path)
                }
                cursor = values[index]
            default:
                throw MokelayTemplateError.missingVariable(path)
            }
        }

        return cursor
    }

    static func stringify(_ value: JSONValue) -> String {
        switch value {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object, .array:
            guard let data = try? JSONEncoder().encode(value),
                  let string = String(data: data, encoding: .utf8) else {
                return value.description
            }
            return string
        case .null:
            return ""
        }
    }

    private static func renderTemplate(_ template: String, state: MokelayActionState) throws -> JSONValue {
        if let wholeMatch = template.range(of: wholeTemplatePattern, options: .regularExpression) {
            let matched = String(template[wholeMatch])
            let path = matched
                .replacingOccurrences(of: #"^\s*\{\{\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*\}\}\s*$"#, with: "", options: .regularExpression)
            return try readPath(path, in: state.jsonContext)
        }

        guard let regex = try? NSRegularExpression(pattern: templatePattern) else {
            return .string(template)
        }

        let nsTemplate = template as NSString
        let matches = regex.matches(in: template, range: NSRange(location: 0, length: nsTemplate.length))
        var result = template

        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else {
                continue
            }

            let path = nsTemplate.substring(with: match.range(at: 1))
            let value = try readPath(path, in: state.jsonContext)
            result = (result as NSString).replacingCharacters(in: match.range, with: stringify(value))
        }

        return .string(result)
    }

    private static func tokenize(_ path: String) throws -> [String] {
        var segments: [String] = []
        var cursor = ""
        let characters = Array(path.trimmingCharacters(in: .whitespacesAndNewlines))
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == "." {
                if !cursor.isEmpty {
                    segments.append(cursor)
                }
                cursor = ""
                index += 1
                continue
            }

            if character == "[" {
                if !cursor.isEmpty {
                    segments.append(cursor)
                }
                cursor = ""
                guard let endIndex = characters[index...].firstIndex(of: "]") else {
                    throw MokelayTemplateError.invalidPath(path)
                }
                let raw = String(characters[(index + 1)..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                segments.append(raw.trimmingCharacters(in: CharacterSet(charactersIn: "'\"")))
                index = endIndex + 1
                continue
            }

            cursor.append(character)
            index += 1
        }

        if !cursor.isEmpty {
            segments.append(cursor)
        }

        return segments
    }

    private static func readRowPath(_ path: String, row: [String: JSONValue]) -> JSONValue? {
        let segments = path
            .split(separator: ".")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard let first = segments.first,
              var cursor = row[first] else {
            return nil
        }

        for segment in segments.dropFirst() {
            guard case .object(let object) = cursor,
                  let next = object[segment] else {
                return nil
            }
            cursor = next
        }

        return cursor
    }
}
