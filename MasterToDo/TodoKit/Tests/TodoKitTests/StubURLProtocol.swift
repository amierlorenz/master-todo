import Foundation
import Synchronization

/// Serves canned responses keyed by URL path and records requests. Each
/// session gets its own table, so suites can run in parallel.
final class StubURLProtocol: URLProtocol {
    struct Response: Sendable {
        var status = 200
        var body: String
        var headers: [String: String] = [:]
    }

    struct Stub: Sendable {
        let session: URLSession
        let id: String

        var requests: [URLRequest] {
            StubURLProtocol.requests.withLock { $0[id] ?? [] }
        }
    }

    private static let header = "X-Stub-ID"
    private static let responses = Mutex<[String: [String: Response]]>([:])
    private static let requests = Mutex<[String: [URLRequest]]>([:])

    static func stub(_ responses: [String: Response]) -> Stub {
        let id = UUID().uuidString
        Self.responses.withLock { $0[id] = responses }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [header: id]
        return Stub(session: URLSession(configuration: configuration), id: id)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: Self.header) ?? ""
        Self.requests.withLock { $0[id, default: []].append(request) }
        let url = request.url!
        let key = url.query().map { "\(url.path())?\($0)" } ?? url.path()
        let stub = Self.responses.withLock { $0[id]?[key] ?? $0[id]?[url.path()] } ?? Response(status: 404, body: "[]")
        let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: stub.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
