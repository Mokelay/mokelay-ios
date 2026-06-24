import Foundation

enum PageSource: String, Codable, Equatable {
    case user
    case system
}

final class MokelayPageAPI {
    static let shared = MokelayPageAPI()

    private static var defaultBaseURL: URL {
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8787")!
        #else
        return URL(string: "https://api.mokelay.com")!
        #endif
    }

    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = MokelayPageAPI.defaultBaseURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func fetchPage(uuid: String, source: PageSource = .user) async throws -> MokelayPage {
        let url = try makeReadPageURL(uuid: uuid, source: source)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MokelayPageAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw MokelayPageAPIError.httpStatus(httpResponse.statusCode)
        }

        let envelope = try decoder.decode(MokelayAPIEnvelope<MokelayReadPagePayload>.self, from: data)

        guard envelope.ok else {
            throw MokelayPageAPIError.api(envelope.error?.message ?? envelope.error?.code ?? "API request failed.")
        }

        guard let page = envelope.data?.page else {
            throw MokelayPageAPIError.pageNotFound(uuid)
        }

        return page
    }

    func sendJSONRequest(url: URL, method: String, headers: [String: String] = [:], body: JSONValue? = nil) async throws -> JSONValue {
        var request = URLRequest(url: url)
        request.httpMethod = method

        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = try encoder.encode(body)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MokelayPageAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw MokelayPageAPIError.httpStatus(httpResponse.statusCode)
        }

        return try decoder.decode(JSONValue.self, from: data)
    }

    private func makeReadPageURL(uuid: String, source: PageSource) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = source == .system ? "/api/mokelay/read_mokelay_page_json" : "/api/mokelay/read_page_by_uuid"
        components?.queryItems = [
            URLQueryItem(name: "uuid", value: uuid)
        ]

        guard let url = components?.url else {
            throw MokelayPageAPIError.invalidURL
        }

        return url
    }
}

private struct MokelayAPIEnvelope<Payload: Decodable>: Decodable {
    let ok: Bool
    let data: Payload?
    let error: MokelayAPIErrorPayload?
}

private struct MokelayReadPagePayload: Decodable {
    let page: MokelayPage?
}

private struct MokelayAPIErrorPayload: Decodable {
    let code: String?
    let message: String?
}

enum MokelayPageAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case api(String)
    case pageNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Mokelay page URL."
        case .invalidResponse:
            return "Invalid response from Mokelay server."
        case .httpStatus(let statusCode):
            return "Mokelay server returned HTTP \(statusCode)."
        case .api(let message):
            return message
        case .pageNotFound(let uuid):
            return "Page not found: \(uuid)"
        }
    }
}
