import Foundation

// MARK: - Remote Models

struct RemoteSession: Decodable {
    let id: Int
    let duration: Int
    let type: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case duration
        case type
        case createdAt = "created_at"
    }
}

private struct NewSessionPayload: Encodable {
    let duration: Int
    let type: String
}

// MARK: - API Error

enum APIError: Error {
    case invalidResponse
    case badStatus(Int)
}

// MARK: - Session API Client

final class SessionAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL = URL(string: "http://127.0.0.1:8000")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        encoder = JSONEncoder()

        decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) ?? fallbackFormatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
        }
    }

    func fetchSessions(limit: Int = 1000) async throws -> [RemoteSession] {
        var components = URLComponents(url: baseURL.appendingPathComponent("sessions/"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try decoder.decode([RemoteSession].self, from: data)
    }

    func createSession(duration: Int, type: String) async throws -> RemoteSession {
        var request = URLRequest(url: baseURL.appendingPathComponent("sessions/"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(NewSessionPayload(duration: duration, type: type))

        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try decoder.decode(RemoteSession.self, from: data)
    }

    func deleteAllSessions() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("sessions/"))
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try Self.validate(response)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.badStatus(httpResponse.statusCode)
        }
    }
}
