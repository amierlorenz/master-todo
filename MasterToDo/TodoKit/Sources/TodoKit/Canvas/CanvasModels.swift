import Foundation

public struct CanvasCourse: Decodable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let courseCode: String?

    public init(id: Int, name: String, courseCode: String? = nil) {
        self.id = id
        self.name = name
        self.courseCode = courseCode
    }

    enum CodingKeys: String, CodingKey {
        case id, name, courseCode = "course_code"
    }
}

public struct CanvasAssignment: Decodable, Hashable, Sendable {
    public struct Submission: Decodable, Hashable, Sendable {
        public let workflowState: String?
        public let excused: Bool?

        enum CodingKeys: String, CodingKey {
            case excused, workflowState = "workflow_state"
        }
    }

    /// Submission types turned in through Canvas itself, so Canvas can confirm them.
    public static let onlineSubmissionTypes: Set<String> = [
        "online_upload", "online_text_entry", "online_url", "online_quiz",
        "media_recording", "student_annotation", "discussion_topic",
    ]

    public let id: Int
    public let name: String
    public let dueAt: Date?
    public let unlockAt: Date?
    /// After this, students can no longer submit.
    public let lockAt: Date?
    public let submissionTypes: [String]
    public let submission: Submission?
    /// The assignment's page in Canvas.
    public let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, submission, dueAt = "due_at", unlockAt = "unlock_at", lockAt = "lock_at",
             submissionTypes = "submission_types", htmlURL = "html_url"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
        unlockAt = try container.decodeIfPresent(Date.self, forKey: .unlockAt)
        lockAt = try container.decodeIfPresent(Date.self, forKey: .lockAt)
        submissionTypes = try container.decodeIfPresent([String].self, forKey: .submissionTypes) ?? []
        submission = try container.decodeIfPresent(Submission.self, forKey: .submission)
        htmlURL = try container.decodeIfPresent(URL.self, forKey: .htmlURL)
    }

    /// Whether the work is no longer open: turned in, graded, or excused.
    public var isSubmitted: Bool {
        submission?.excused == true || ["submitted", "graded", "pending_review"].contains(submission?.workflowState ?? "")
    }

    /// Whether Canvas can confirm a submission; otherwise the student's word is final.
    public var hasOnlineSubmission: Bool {
        submissionTypes.contains(where: Self.onlineSubmissionTypes.contains)
    }

    public func isClosed(now: Date) -> Bool {
        lockAt.map { $0 <= now } ?? false
    }
}
