import Foundation
import Observation
import SwiftData
import TodoKit
#if os(iOS)
import BackgroundTasks
#endif

/// Runs Canvas syncs and remembers how the last one went.
@MainActor
@Observable
final class SyncService {
    static let staleAfter: TimeInterval = 15 * 60
    static let backgroundTaskID = "com.mieracle.MasterToDo.refresh"
    private static let lastSyncKey = "lastCanvasSync"

    private(set) var isSyncing = false
    private(set) var lastError: String?
    private(set) var hasCanvasAccount = CanvasConnection.client() != nil
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private var lastSync: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastSyncKey) }
    }

    /// Call after the Canvas address or token changes.
    func accountChanged() {
        hasCanvasAccount = CanvasConnection.client() != nil
        lastSync = nil
        lastError = nil
    }

    func syncIfStale(now: Date = .now) async {
        if let lastSync, now.timeIntervalSince(lastSync) < Self.staleAfter { return }
        await syncNow()
    }

    func syncNow() async {
        guard !isSyncing, let client = CanvasConnection.client() else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let sync = CanvasSync(context: context, client: client)
            try await sync.refreshCourses()
            try await sync.run()
            lastSync = .now
            lastError = nil
        } catch {
            lastError = Self.message(for: error)
        }
    }

    /// Updates the course list from Canvas. Returns how many courses the user hasn't been shown.
    @discardableResult
    func refreshCourses() async -> Int {
        guard let client = CanvasConnection.client() else { return 0 }
        do {
            return try await CanvasSync(context: context, client: client).refreshCourses()
        } catch {
            lastError = Self.message(for: error)
            return 0
        }
    }

    /// Error text safe to show: never includes the token.
    static func message(for error: any Error) -> String {
        switch error {
        case CanvasClient.ClientError.unauthorized: "Canvas rejected the token — check Settings."
        case CanvasClient.ClientError.http(let status): "Canvas returned an error (\(status)). Try again later."
        case is URLError: "Couldn't reach Canvas. Check your connection."
        default: "Sync failed. Try again later."
        }
    }

    #if os(iOS)
    func backgroundRefresh() async {
        Self.scheduleBackgroundRefresh()
        await syncNow()
        await NotificationService.replan(context: context)
    }

    /// iOS decides when this actually runs; three hours is only the earliest.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(3 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
    #endif
}
