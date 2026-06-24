import Foundation

enum MokelayProcessorError: LocalizedError {
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let name):
            return "Unsupported processor: \(name)"
        }
    }
}

enum MokelayProcessors {
    static func apply(_ value: JSONValue, processors: [JSONValue]) throws -> JSONValue {
        try processors.reduce(value) { current, processor in
            try apply(current, processor: processor)
        }
    }

    static func apply(_ value: JSONValue, processor: JSONValue) throws -> JSONValue {
        let name: String

        if let string = processor.stringValue {
            name = string
        } else if let object = processor.objectValue,
                  let processorName = object["processor"]?.stringValue {
            name = processorName
        } else {
            return value
        }

        switch name {
        case "trim":
            guard let string = value.stringValue else {
                return value
            }

            return .string(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            throw MokelayProcessorError.unsupported(name)
        }
    }
}
