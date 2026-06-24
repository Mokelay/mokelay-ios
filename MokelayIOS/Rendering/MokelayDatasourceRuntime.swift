import Foundation

struct MokelayDatasourceKeyValue: Equatable {
    let key: String
    let value: JSONValue
}

struct MokelayDatasourceBodyItem: Equatable {
    let key: String
    let dataType: String
    let value: JSONValue
}

struct MokelaySchemaSelection: Equatable {
    let path: String
    let type: String
    let label: String
}

struct MokelayMatchingExternalField: Equatable {
    let label: String
    let variable: String
    let matchFieldPath: String
}

struct MokelayDatasource: Equatable {
    let type: String
    let domain: String
    let path: String
    let method: String
    let headerData: [MokelayDatasourceKeyValue]
    let bodyData: [MokelayDatasourceBodyItem]
    let queryData: [MokelayDatasourceKeyValue]
    let schemaSelections: [MokelaySchemaSelection]
    let matchingExternalFields: [MokelayMatchingExternalField]

    init?(value: JSONValue?) {
        guard let object = value?.objectValue,
              object["type"]?.stringValue == "API" else {
            return nil
        }

        type = "API"
        domain = object["domain"]?.stringValue ?? ""
        path = object["path"]?.stringValue ?? ""
        method = object["method"]?.stringValue == "POST" ? "POST" : "GET"
        headerData = Self.keyValues(from: object["headerData"])
        bodyData = Self.bodyItems(from: object["bodyData"])
        queryData = Self.keyValues(from: object["queryData"])
        schemaSelections = Self.schemaSelections(from: object["schemaSelections"])
        matchingExternalFields = Self.matchingExternalFields(from: object["matchingExternalFields"])
    }

    private static func keyValues(from value: JSONValue?) -> [MokelayDatasourceKeyValue] {
        value?.arrayValue?.compactMap { item in
            guard let object = item.objectValue else {
                return nil
            }

            let key = object["key"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !key.isEmpty else {
                return nil
            }

            return MokelayDatasourceKeyValue(key: key, value: object["value"] ?? .string(""))
        } ?? []
    }

    private static func bodyItems(from value: JSONValue?) -> [MokelayDatasourceBodyItem] {
        value?.arrayValue?.compactMap { item in
            guard let object = item.objectValue else {
                return nil
            }

            let key = object["key"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !key.isEmpty else {
                return nil
            }

            return MokelayDatasourceBodyItem(
                key: key,
                dataType: object["dataType"]?.stringValue ?? "string",
                value: object["value"] ?? .string("")
            )
        } ?? []
    }

    private static func schemaSelections(from value: JSONValue?) -> [MokelaySchemaSelection] {
        value?.arrayValue?.compactMap { item in
            guard let object = item.objectValue else {
                return nil
            }

            let path = object["path"]?.stringValue ?? ""

            guard !path.isEmpty else {
                return nil
            }

            return MokelaySchemaSelection(
                path: path,
                type: object["type"]?.stringValue ?? "",
                label: object["label"]?.stringValue ?? path
            )
        } ?? []
    }

    private static func matchingExternalFields(from value: JSONValue?) -> [MokelayMatchingExternalField] {
        value?.arrayValue?.compactMap { item in
            guard let object = item.objectValue else {
                return nil
            }

            let variable = object["variable"]?.stringValue ?? ""
            let matchFieldPath = object["matchFieldPath"]?.stringValue ?? ""

            guard !variable.isEmpty, !matchFieldPath.isEmpty else {
                return nil
            }

            return MokelayMatchingExternalField(
                label: object["label"]?.stringValue ?? variable,
                variable: variable,
                matchFieldPath: matchFieldPath
            )
        } ?? []
    }
}

struct MokelayDatasourceResult {
    let rawResponse: JSONValue
    let schemaSelectionData: [String: JSONValue]
    let matchingExternalFieldData: [String: JSONValue]
}

enum MokelayDatasourceRuntime {
    static func execute(
        datasource: MokelayDatasource,
        apiClient: MokelayPageAPI,
        blocks: [String: [String: JSONValue]]
    ) async throws -> MokelayDatasourceResult {
        let url = try requestURL(for: datasource, apiClient: apiClient, blocks: blocks)
        let headers = try requestHeaders(for: datasource, blocks: blocks)
        let body = try requestBody(for: datasource, blocks: blocks)
        let rawResponse = try await apiClient.sendJSONRequest(
            url: url,
            method: datasource.method,
            headers: headers,
            body: body
        )
        let schemaData = Dictionary(uniqueKeysWithValues: datasource.schemaSelections.map { selection in
            (selection.path, rawResponse.value(atPath: selection.path) ?? .null)
        })
        let matchingData = Dictionary(uniqueKeysWithValues: datasource.matchingExternalFields.map { field in
            (field.variable, schemaData[field.matchFieldPath] ?? .null)
        })

        return MokelayDatasourceResult(
            rawResponse: rawResponse,
            schemaSelectionData: schemaData,
            matchingExternalFieldData: matchingData
        )
    }

    static func requestURL(
        for datasource: MokelayDatasource,
        apiClient: MokelayPageAPI,
        blocks: [String: [String: JSONValue]]
    ) throws -> URL {
        let baseURL: URL

        if datasource.domain == "mokelay" || datasource.domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseURL = apiClient.baseURL
        } else if let url = URL(string: datasource.domain),
                  url.scheme == "http" || url.scheme == "https" {
            baseURL = url
        } else {
            baseURL = apiClient.baseURL
        }

        let pathIsAbsolute = datasource.path.range(of: #"^[a-z][a-z\d+\-.]*:"#, options: .regularExpression) != nil
        guard var components = URLComponents(url: pathIsAbsolute ? URL(string: datasource.path)! : URL(string: datasource.path, relativeTo: baseURL)!, resolvingAgainstBaseURL: true) else {
            throw MokelayPageAPIError.invalidURL
        }

        var queryItems = components.queryItems ?? []
        for item in datasource.queryData {
            let resolvedValue = try resolvedDatasourceValue(item.value, blocks: blocks)
            queryItems.append(URLQueryItem(name: item.key, value: MokelayTemplateResolver.stringify(resolvedValue)))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw MokelayPageAPIError.invalidURL
        }

        return url
    }

    static func requestBody(for datasource: MokelayDatasource, blocks: [String: [String: JSONValue]]) throws -> JSONValue? {
        guard datasource.method == "POST" else {
            return nil
        }

        let fields = try datasource.bodyData.reduce(into: [String: JSONValue]()) { result, item in
            result[item.key] = try normalizedBodyValue(item, blocks: blocks)
        }

        return .object(fields)
    }

    private static func requestHeaders(for datasource: MokelayDatasource, blocks: [String: [String: JSONValue]]) throws -> [String: String] {
        try datasource.headerData.reduce(into: [String: String]()) { result, item in
            let value = try resolvedDatasourceValue(item.value, blocks: blocks)
            result[item.key] = MokelayTemplateResolver.stringify(value)
        }
    }

    private static func normalizedBodyValue(_ item: MokelayDatasourceBodyItem, blocks: [String: [String: JSONValue]]) throws -> JSONValue {
        let resolved = try resolvedDatasourceValue(item.value, blocks: blocks)

        switch item.dataType {
        case "number":
            return resolved.numberValue.map(JSONValue.number) ?? .number(0)
        case "boolean":
            return resolved.boolValue.map(JSONValue.bool) ?? .bool(false)
        case "null":
            return .null
        case "object":
            return resolved.objectValue.map(JSONValue.object) ?? .object([:])
        case "array":
            return resolved.arrayValue.map(JSONValue.array) ?? .array([])
        default:
            if case .string = resolved {
                return resolved
            }

            return .string(MokelayTemplateResolver.stringify(resolved))
        }
    }

    private static func resolvedDatasourceValue(_ value: JSONValue, blocks: [String: [String: JSONValue]]) throws -> JSONValue {
        if let object = value.objectValue,
           object["mode"]?.stringValue != nil {
            return try MokelayTemplateResolver.resolveVariableConfig(value, blocks: blocks)
        }

        return value
    }
}
