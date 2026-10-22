import Foundation

/// Reads courses and assignments from the Canvas REST API.
public struct CanvasClient: Sendable {
    public let baseURL: URL
    private let token: String
    private let session: URLSession

    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    public enum ClientError: Error, Equatable {
        case unauthorized
        case http(Int)
        case invalidResponse
    }

    public func activeCourses() async throws -> [CanvasCourse] {
        try await getAll("api/v1/courses", query: [URLQueryItem(name: "enrollment_state", value: "active")])
    }

    public func assignments(courseID: Int) async throws -> [CanvasAssignment] {
        try await getAll("api/v1/courses/\(courseID)/assignments", query: [URLQueryItem(name: "include[]", value: "submission")])
    }

    public func assignment(courseID: Int, id: Int) async throws -> CanvasAssignment {
        let url = baseURL.appending(path: "api/v1/courses/\(courseID)/assignments/\(id)").appending(queryItems: [URLQueryItem(name: "include[]", value: "submission")])
        return try Self.decoder.decode(CanvasAssignment.self, from: try await get(url).data)
    }

    /// Follows `Link: <…>; rel="next"` headers until every page is read.
    func getAll<Item: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> [Item] {
        var next: URL? = baseURL.appending(path: path).appending(queryItems: query + [URLQueryItem(name: "per_page", value: "100")])
        var items: [Item] = []
        while let url = next {
            let (data, http) = try await get(url)
            items += try Self.decoder.decode([Item].self, from: data)
            next = Self.nextPage(from: http.value(forHTTPHeaderField: "Link"))
        }
        return items
    }

    private func get(_ url: URL) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return (data, http)
        case 401: throw ClientError.unauthorized
        default: throw ClientError.http(http.statusCode)
        }
    }

    static func nextPage(from linkHeader: String?) -> URL? {
        guard let linkHeader else { return nil }
        for part in linkHeader.split(separator: ",") where part.contains("rel=\"next\"") {
            guard let start = part.firstIndex(of: "<"), let end = part.firstIndex(of: ">") else { continue }
            return URL(string: String(part[part.index(after: start)..<end]))
        }
        return nil
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
