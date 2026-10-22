import Foundation
import TodoKit

/// Builds a Canvas client from the saved address and the Keychain token.
enum CanvasConnection {
    static let baseURLKey = "canvasBaseURL"

    static func client() -> CanvasClient? {
        guard let base = UserDefaults.standard.string(forKey: baseURLKey).flatMap(URL.init(string:)),
              let token = try? KeychainStore.canvasToken.read(), !token.isEmpty else { return nil }
        return CanvasClient(baseURL: base, token: token)
    }

    static func fetchAssignment(courseID: Int, assignmentID: Int) async throws -> CanvasAssignment {
        guard let client = client() else { throw CanvasClient.ClientError.unauthorized }
        return try await client.assignment(courseID: courseID, id: assignmentID)
    }
}
