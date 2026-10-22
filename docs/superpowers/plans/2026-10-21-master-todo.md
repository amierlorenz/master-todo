# Master To-Do Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A SwiftUI to-do app for iOS and macOS that merges the user's own tasks with open Canvas assignments, verifies Canvas check-offs, and sends a daily summary plus 3-hours-before reminders.

**Architecture:** One multiplatform app target holds only SwiftUI screens and thin `@Observable` services. A local Swift package, `TodoKit`, holds everything testable: the SwiftData models, the Canvas client (copied and extended from StudyTool), sync reconciliation, check-off verification, list ordering, and notification planning. SwiftData uses a CloudKit-backed container so iPhone and Mac share data. Canvas duplicates created by two devices syncing are merged by Canvas id.

**Tech Stack:** Swift 6 language mode, swift-tools 6.4, Xcode 27, SwiftUI with Liquid Glass, SwiftData with CloudKit, UserNotifications, BackgroundTasks (iOS), and Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-21-master-todo-design.md`

## Global Constraints

- Deployment target: iOS 26.0 and macOS 26.0, in both the app target and `Package.swift`.
- Bundle id `com.mieracle.MasterToDo`, iCloud container `iCloud.com.mieracle.MasterToDo`.
- CloudKit model rules: no `.unique`, every property defaulted or optional, every relationship optional.
- The Canvas token is stored only in the Keychain (`KeychainStore`, synchronizable). Never put it in source, `@AppStorage`, SwiftData, logs, or error text.
- macOS App Sandbox is on, with `com.apple.security.network.client` only.
- A Canvas task is never deleted by sync. Only the user removes one, and removal leaves a tombstone.
- Never dismiss an online-submission Canvas task unless Canvas reports it submitted.
- Pattern: MV with services, as in StudyTool. Views use `@Query`/`modelContext` directly. Testable logic goes in `TodoKit`.
- UI: stock SwiftUI controls with system Liquid Glass. Animate list changes (`.animation(.default, value:)` / `withAnimation`). No custom design system, because prototypes come later.
- DocC `///` on public or non-obvious API, and nearly no inline comments (see the `swift-docc-pro` skill). Use the `swiftdata-pro`, `swiftui-pro`, `swift-concurrency-pro`, and `swift-testing-pro` skills for that kind of code.
- Run package tests with `cd TodoKit && swift test --scratch-path ~/Library/Caches/TodoKit-build`. Building inside iCloud-synced Documents breaks codesign.
- Verify app builds with `xcodebuild -project MasterToDo.xcodeproj -scheme MasterToDo -destination <dest> -derivedDataPath ~/Library/Caches/MasterToDo-DD CODE_SIGNING_ALLOWED=NO build`, for `platform=macOS` and `generic/platform=iOS Simulator`.
- Commits: Conventional Commits, `git add` and `git commit` as separate commands. Follow the project's git workflow mode set up in Task 1. In hands-on mode, stop and ask before each commit.

## Review Focus

1. **A failed fetch for one course** (network drop, 401, 5xx) must not flag that course's tasks "Removed from Canvas". Fetch everything first, then reconcile. If any fetch throws, change nothing. Test: Task 4 `failedFetchChangesNothing`.
2. **A course switched off** must not flag its tasks gone and must not count them in notifications. Test: Task 4 `untrackedCourseTasksUntouched`, Task 6 `hiddenTasksExcluded`.
3. **A task the user already checked off** whose Canvas date later moves must stay done. It must not resurface or get the "date changed" badge. Test: Task 4 `doneTaskDateMoveStaysDone`.
4. **An assignment excused or graded-without-submission at first sync** is not imported. Test: Task 2 `excusedAndGradedCountAsSubmitted`, Task 4 `firstSyncFilters`.
5. **Daylight-saving and day boundaries:** an 11:30 PM task counts for its own calendar day, and the 8:00 AM summary stays 8:00 local across a DST change. Test: Task 6 `summaryAcrossDSTStaysLocal`.

---

## File Structure

```
masterToDo/
  MasterToDo.xcodeproj                 # objectVersion 90, filesystem-synchronized groups (like StudyTool)
  MasterToDo/
    MasterToDoApp.swift                # ModelContainer (CloudKit), services, background task
    MasterToDo.entitlements            # iCloud/CloudKit, push (CloudKit), sandbox + network client
    Info.plist                         # BGTaskSchedulerPermittedIdentifiers, UIBackgroundModes fetch
    Features/TaskList/                 # TaskListView, TaskRow, AddTaskBar, EditTaskSheet, DoneSection
    Features/Settings/                 # SettingsView, CanvasAccountSection, CourseToggleList
    Features/CoursePicker/             # CoursePickerView (first-sync picker)
    Services/SyncService.swift         # @Observable: triggers, staleness, errors, then replan
    Services/NotificationService.swift # @Observable: permission, apply planner output
  TodoKit/
    Package.swift
    Sources/TodoKit/Canvas/            # CanvasClient, CanvasModels, KeychainStore, CanvasSync
    Sources/TodoKit/Models/            # TaskItem, TaskState, TrackedCourse, RemovedCanvasItem, TodoSchema
    Sources/TodoKit/Logic/             # CanvasReconciler, TaskCompletion, TaskOrdering, DuplicateMerger
    Sources/TodoKit/Notifications/     # NotificationPlanner
    Tests/TodoKitTests/                # one file per logic type + StubURLProtocol + TestContainer
```

---

### Task 1: Repo, package skeleton, and Canvas client

**Files:**
- Create: `.gitignore` (`.DS_Store`, `xcuserdata/`, `.build/`, `DerivedData/`)
- Create: `TodoKit/Package.swift`
- Create: `TodoKit/Sources/TodoKit/Canvas/{CanvasClient,CanvasModels,KeychainStore}.swift`, copied from `../StudyTool/MieracleStudy/MieracleKit/Sources/MieracleKit/Canvas/`
- Create: `TodoKit/Tests/TodoKitTests/{StubURLProtocol,CanvasClientTests}.swift`, copied from StudyTool's tests

**Interfaces:**
- Produces:
  - `CanvasClient(baseURL:token:session:)` with `activeCourses() async throws -> [CanvasCourse]`, `assignments(courseID: Int) async throws -> [CanvasAssignment]`, and the new `assignment(courseID: Int, id: Int) async throws -> CanvasAssignment`.
  - `CanvasAssignment` with new fields `lockAt: Date?`, `submissionTypes: [String]`, and `Submission.excused: Bool?`, plus `isSubmitted: Bool`, `hasOnlineSubmission: Bool`, and `isClosed(now: Date) -> Bool`.
  - `KeychainStore.canvasToken`.

- [ ] **Step 1: Set up git.** Run `git init`. Then run the `git-workflow` skill and the commit-attribution choice from the global CLAUDE.md, writing both to `.claude/settings.local.json` and adding that file to `.gitignore`.
- [ ] **Step 2: Create `Package.swift`.** Use `// swift-tools-version: 6.4`, `platforms: [.macOS(.v26), .iOS(.v26)]`, library `TodoKit`, and test target `TodoKitTests` with `resources: [.copy("Fixtures")]`.
- [ ] **Step 3: Copy the files.** Drop `CanvasEvent`, `events(courseID:)`, and the events test, and set `KeychainStore.canvasToken` to service `com.mieracle.MasterToDo.canvas`. Run the tests and expect the copied ones to PASS.
- [ ] **Step 4: Write the failing tests** in `CanvasClientTests`:

```swift
@Test func decodesNewAssignmentFields() async throws {
    let stub = StubURLProtocol.stub(["/api/v1/courses/7/assignments": .init(body: #"""
      [{"id":1,"name":"Essay","due_at":"2026-10-20T15:00:00Z","lock_at":"2026-10-22T05:00:00Z",
        "submission_types":["online_upload"],"submission":{"workflow_state":"unsubmitted","excused":false}}]
      """#)])
    let a = try await CanvasClient(baseURL: base, token: "t", session: stub.session).assignments(courseID: 7)[0]
    #expect(a.lockAt == ISO8601DateFormatter().date(from: "2026-10-22T05:00:00Z"))
    #expect(a.submissionTypes == ["online_upload"])
    #expect(a.hasOnlineSubmission)
    #expect(!a.isSubmitted)
}

@Test func fetchesSingleAssignmentWithSubmission() async throws {
    let stub = StubURLProtocol.stub(["/api/v1/courses/7/assignments/1": .init(body: #"{"id":1,"name":"Essay","submission":{"workflow_state":"submitted"}}"#)])
    let a = try await CanvasClient(baseURL: base, token: "t", session: stub.session).assignment(courseID: 7, id: 1)
    #expect(a.isSubmitted)
    #expect(stub.requests.first?.url?.query()?.contains("submission") == true)
}
```

  Add this in a new `CanvasModelsTests`:

```swift
@Test(arguments: [("submitted", false, true), ("graded", false, true), ("pending_review", false, true),
                  ("unsubmitted", true, true), ("unsubmitted", false, false)])
func excusedAndGradedCountAsSubmitted(state: String, excused: Bool, expected: Bool) throws { /* decode one assignment JSON; #expect(isSubmitted == expected) */ }

@Test(arguments: [(["none"], false), (["on_paper"], false), (["not_graded"], false), (["external_tool"], false),
                  (["online_quiz"], true), (["discussion_topic"], true), (["on_paper", "online_url"], true)])
func onlineSubmissionTypes(types: [String], expected: Bool) throws { /* … */ }

@Test func closedOnlyAfterLockAt() { /* lockAt nil → false; lockAt past → true; lockAt future → false */ }
```

- [ ] **Step 5: Run the tests** and confirm the new ones FAIL to compile because the members are missing.
- [ ] **Step 6: Implement the new members.**
  - Online types are exactly `["online_upload", "online_text_entry", "online_url", "online_quiz", "media_recording", "student_annotation", "discussion_topic"]`.
  - `isSubmitted` also returns true when `submission?.excused == true`.
  - `assignment(courseID:id:)` does a single GET on `api/v1/courses/\(courseID)/assignments/\(id)` with `include[]=submission`. Factor the request and status handling out of `getAll` so both use it.
  - `submissionTypes` defaults to `[]` when the key is missing (custom `init(from:)` or an optional with an accessor).
- [ ] **Step 7: Run the tests** and confirm all PASS.
- [ ] **Step 8: Commit** with `feat: add TodoKit package with Canvas client`.

---

### Task 2: Models and list ordering

**Files:**
- Create: `TodoKit/Sources/TodoKit/Models/{TaskItem,TrackedCourse,RemovedCanvasItem,TodoSchema}.swift`
- Create: `TodoKit/Sources/TodoKit/Logic/TaskOrdering.swift`
- Create: `TodoKit/Tests/TodoKitTests/{TestContainer,TaskItemTests,TaskOrderingTests}.swift`

**Interfaces:**
- Produces:
  - `enum TaskState: String, Codable { case open, pendingVerification, done }`, with `rank: Int` (open 0, pendingVerification 1, done 2).
  - `@Model final class TaskItem` (all properties defaulted):
    - Identity and dates: `id: UUID`, `title: String`, `dueAt: Date?`, `hasDueTime: Bool`, `createdAt: Date`, `stateRaw: String` (via `state: TaskState`).
    - Canvas fields: `canvasAssignmentID: Int?`, `canvasCourseID: Int?`, `courseName: String?`, `htmlURL: String?`, `lockAt: Date?`, `submissionTypesRaw: String` (comma-joined), `isSubmittedOnCanvas: Bool`, `isGoneFromCanvas: Bool`, `dueDateChanged: Bool`, `lastSyncedAt: Date?`.
    - Computed: `isCanvas: Bool`, `hasOnlineSubmission: Bool`, `effectiveDue(calendar:) -> Date?`, and `canvasFlag(now:) -> CanvasFlag?`.
  - `enum CanvasFlag { case submitted, closed, removedFromCanvas }`. Priority: removedFromCanvas > submitted > closed. Only for a Canvas task not in the `done` state.
  - `@Model final class TrackedCourse`: `canvasCourseID: Int`, `name: String`, `isTracked: Bool`, `hasBeenOffered: Bool`, `firstSyncedAt: Date?`.
  - `@Model final class RemovedCanvasItem`: `canvasAssignmentID: Int`, `removedAt: Date`.
  - `TaskItem.remove(in: ModelContext)`: inserts a `RemovedCanvasItem` when Canvas, then deletes.
  - `TodoSchema.models: [any PersistentModel.Type]`.
  - `TaskOrdering.sorted(_ tasks: [TaskItem], now: Date, calendar: Calendar) -> [TaskItem]`.
  - `TaskItem.isVisible(trackedCourseIDs: Set<Int>) -> Bool`: own tasks are always visible, Canvas tasks only when their course is tracked.
  - Test helper `TestContainer.make() -> ModelContainer` (in-memory).

- [ ] **Step 1: Write the failing tests.**
  - `effectiveDueDateOnlyIsEndOfDay`: an own task with `hasDueTime == false` due 2026-10-21 has `effectiveDue` of 2026-10-21 23:59 local.
  - `canvasFlagPriority`: gone + submitted → `.removedFromCanvas`; submitted + closed → `.submitted`; lockAt past only → `.closed`; done → `nil`; own task → `nil`.
  - `removeLeavesTombstoneForCanvasOnly`: removing a Canvas task leaves 1 `RemovedCanvasItem` and 0 tasks. Removing an own task leaves 0 tombstones.
  - `orderingBuckets`: with `now` = 2026-10-21 12:00, the input `[noDate, later(10-25), today(10-21 18:00), overdue(10-20)]` sorts to `[overdue, today, later, noDate]`, with ties broken by `createdAt` ascending.
  - `lateNightCountsForOwnDay`: a task due 2026-10-21 23:30 lands in the "today" bucket when `now` is 2026-10-21 09:00.
- [ ] **Step 2: Run the tests** and confirm they FAIL.
- [ ] **Step 3: Implement the models, the schema list, and `TaskOrdering`.** Bucket by `calendar.startOfDay` of `effectiveDue` against `now`, where overdue means `effectiveDue < now`.
- [ ] **Step 4: Run the tests** and confirm they PASS.
- [ ] **Step 5: Commit** with `feat: add task models and list ordering`.

---

### Task 3: Check-off verification

**Files:**
- Create: `TodoKit/Sources/TodoKit/Logic/TaskCompletion.swift`
- Test: `TodoKit/Tests/TodoKitTests/TaskCompletionTests.swift`

**Interfaces:**
- Consumes: `TaskItem`, `CanvasAssignment`.
- Produces: `TaskCompletion.complete(_ task: TaskItem, fetch: (_ courseID: Int, _ assignmentID: Int) async throws -> CanvasAssignment) async -> TaskState`, which sets and returns the new state and updates `isSubmittedOnCanvas` from the fetch. Also produces `TaskCompletion.uncheck(_ task: TaskItem)`, which sets the state to `.open`.

- [ ] **Step 1: Write the failing tests.** Use a `fetch` closure that counts its calls.
  - `ownTaskDismissesWithoutFetch`: the result is `.done` and the fetch count is 0.
  - `offlineTypeDismissesWithoutFetch`: `submissionTypesRaw = "on_paper"` gives `.done` with a fetch count of 0.
  - `onlineSubmittedDismisses`: a fetch returning `workflow_state: "submitted"` gives `.done` and `isSubmittedOnCanvas == true`.
  - `onlineNotSubmittedStaysPending`: an `"unsubmitted"` result gives `.pendingVerification`.
  - `fetchErrorStaysPending`: a fetch that throws `CanvasClient.ClientError.unauthorized` gives `.pendingVerification`.
  - `uncheckReturnsToOpen`: `pendingVerification` → `.open`.
- [ ] **Step 2: Run the tests** and confirm they FAIL.
- [ ] **Step 3: Implement it.** This is a `@MainActor enum` with static functions, because `TaskItem` is main-actor bound.
- [ ] **Step 4: Run the tests** and confirm they PASS.
- [ ] **Step 5: Commit** with `feat: verify Canvas submission on check-off`.

---

### Task 4: Sync reconciliation and duplicate merge

**Files:**
- Create: `TodoKit/Sources/TodoKit/Logic/{CanvasReconciler,DuplicateMerger}.swift`
- Create: `TodoKit/Sources/TodoKit/Canvas/CanvasSync.swift`
- Test: `TodoKit/Tests/TodoKitTests/{CanvasReconcilerTests,DuplicateMergerTests,CanvasSyncTests}.swift`

**Interfaces:**
- Consumes: the models, `CanvasClient`, and `CanvasAssignment.isSubmitted/isClosed/hasOnlineSubmission`.
- Produces:
  - `CanvasReconciler.reconcile(course: TrackedCourse, assignments: [CanvasAssignment], in: ModelContext, now: Date) throws -> ReconcileResult`, where `ReconcileResult { added, updated, flaggedGone, autoDismissed: Int }`. It treats the course as a first sync when `course.firstSyncedAt == nil`, and sets that field afterward.
  - `DuplicateMerger.mergeAll(in: ModelContext) throws -> Int`.
  - `CanvasSync(context:client:)`:
    - `refreshCourses() async throws -> Int` upserts `TrackedCourse` from `activeCourses()`. New courses get `isTracked = false, hasBeenOffered = false`. Returns the count of courses not yet offered.
    - `run(now:) async throws -> ReconcileResult` fetches assignments for every `isTracked` course, then reconciles each, then merges duplicates, then saves. It throws before touching any model if any fetch fails.

Reconcile rules, applied per fetched assignment `a`, with `existing` matched by `canvasAssignmentID`:

| Case | Action |
|---|---|
| id is tombstoned | skip |
| no existing, `a.isSubmitted \|\| a.isClosed(now)` | skip, on both first and later syncs (the spec adds only open work) |
| no existing, otherwise | insert, copying Canvas fields; `hasDueTime = dueAt != nil` |
| existing | update the name, lockAt, types, `isSubmittedOnCanvas`, and courseName, and set `isGoneFromCanvas = false`. If `dueAt` differs, set it, and set `dueDateChanged = true` only when the state is not `.done`. If the state is `.pendingVerification` and `a.isSubmitted`, set `.done` and count it as `autoDismissed`. |
| existing task of this course, not fetched | `isGoneFromCanvas = true` |

DuplicateMerger groups `TaskItem` by non-nil `canvasAssignmentID`, `TrackedCourse` by `canvasCourseID`, and `RemovedCanvasItem` by `canvasAssignmentID`.
- **Task keeper:** the highest `state.rank`, then the earliest `createdAt`. The keeper takes the Canvas fields of the copy with the newest `lastSyncedAt`.
- **Tombstones:** a tombstoned id deletes every task copy.
- **Courses:** `isTracked` is the OR of the copies, and `firstSyncedAt` is the earliest non-nil value.

- [ ] **Step 1: Write the failing `CanvasReconcilerTests`.** Build assignments from JSON fixtures in `Tests/TodoKitTests/Fixtures/`.
  - `firstSyncFilters`: open, submitted, excused, graded-no-submission, locked-past, past-due-unlocked, and no-due-date assignments import only open, past-due-unlocked, and no-due-date.
  - `laterSyncAddsNewOpenOnly`.
  - `dueDateMoveUpdatesAndBadges`: the new `dueAt` is stored and `dueDateChanged == true`.
  - `doneTaskDateMoveStaysDone`: the state stays `.done` and `dueDateChanged == false`.
  - `submittedFlagsNotRemoves`: an open task whose Canvas copy is now submitted is still present, with `canvasFlag == .submitted`.
  - `missingFlagsGone`, and `reappearingClearsGone`.
  - `tombstonedNotReAdded`: still not re-added after its `dueAt` changes.
  - `pendingBecomesDoneWhenSubmitted`: `autoDismissed == 1`.
  - `untrackedCourseTasksUntouched`: reconciling course A leaves course B's tasks unflagged.
- [ ] **Step 2: Write the failing `DuplicateMergerTests`.**
  - `keepsMostAdvancedState`: open plus done copies leave one `.done` task.
  - `tombstoneDeletesAllCopies`.
  - `mergesCourses`: copies with `isTracked` true and false leave one course with `isTracked == true`.
- [ ] **Step 3: Write the failing `CanvasSyncTests`,** using `StubURLProtocol`.
  - `failedFetchChangesNothing`: with two tracked courses where the second returns 500, `run` throws and the first course's existing task has `isGoneFromCanvas == false` with an unchanged `dueAt`.
  - `refreshCoursesAddsUntrackedAndCountsNew`.
- [ ] **Step 4: Run the tests** and confirm they FAIL.
- [ ] **Step 5: Implement the three types.**
- [ ] **Step 6: Run the tests** and confirm all PASS.
- [ ] **Step 7: Commit** with `feat: reconcile Canvas assignments into tasks`.

---

### Task 5: Notification planner

**Files:**
- Create: `TodoKit/Sources/TodoKit/Notifications/NotificationPlanner.swift`
- Test: `TodoKit/Tests/TodoKitTests/NotificationPlannerTests.swift`

**Interfaces:**
- Consumes: `TaskItem.effectiveDue`, `state`, `hasDueTime`, and `isVisible`.
- Produces:
  - `struct PlannedNotification: Equatable { id: String; fireDate: Date; title: String; body: String }`.
  - `NotificationPlanner.plan(tasks: [TaskItem], trackedCourseIDs: Set<Int>, summaryTime: DateComponents, now: Date, calendar: Calendar) -> [PlannedNotification]`.

Rules:
- **Countable tasks:** visible, with `state != .done`. Pending-verification tasks count.
- **Summaries:**
  - For each day d in today through today+6, fire at d with `summaryTime` (hour and minute, via `calendar.date(bySettingHour:minute:second:of:)`).
  - Skip it if the fire date is ≤ now or the count is 0. The count is the countable tasks whose `effectiveDue` falls on day d.
  - id `summary-yyyy-MM-dd`, title `Due today`, body `"\(n) things due today"`, or `"1 thing due today"` when n is 1.
- **Reminders:**
  - For each countable task with `hasDueTime` and `dueAt - 3h > now`, fire at `dueAt - 10800s`.
  - id `due-\(task.id)`, title `Due in 3 hours`, body `"\(title) is due at \(dueAt.formatted(date: .omitted, time: .shortened))"`.
- **Cap:** sort everything by `fireDate`, then take the first 64.

- [ ] **Step 1: Write the failing tests,** with `now` = 2026-10-21 07:00 America/New_York and the summary at 8:00.
  - `summaryCountsTodayIncludingPending`: tasks due today are 2 open, 1 pending, 1 done, and 1 from an untracked course. That gives one summary at today 08:00 with the body `"3 things due today"`. A second case with one open task gives `"1 thing due today"`.
  - `noSummaryWhenZero`.
  - `summaryAlreadyPassedSkipped`: with `now` at 09:00, there is no summary for today.
  - `reminderThreeHoursBefore`: due 15:00 fires at 12:00.
  - `reminderSkippedInsideWindow`: due 09:30 with `now` 07:00 gives no reminder.
  - `dateOnlyOwnTaskNoReminder`.
  - `hiddenTasksExcluded`.
  - `capsAt64Earliest`: 100 tasks give 64 results whose `fireDate`s are ascending.
  - `summaryAcrossDSTStaysLocal`: with `now` 2026-10-31, the summary on 2026-11-02 fires at 08:00 local after the 11-01 change.
- [ ] **Step 2: Run the tests** and confirm they FAIL.
- [ ] **Step 3: Implement the planner** as a `@MainActor enum`.
- [ ] **Step 4: Run the tests** and confirm they PASS.
- [ ] **Step 5: Commit** with `feat: plan daily summary and due reminders`.

---

### Task 6: App project and task list

**Files:**
- Create: `MasterToDo.xcodeproj`
  - Base it on `../StudyTool/MieracleStudy/MieracleStudy.xcodeproj/project.pbxproj` (objectVersion 90, filesystem-synchronized group for `MasterToDo/`, local package reference to `TodoKit`).
  - Use fresh object ids, the product name `MasterToDo`, the bundle id from Global Constraints, the deployment targets from Global Constraints, and the shared scheme `MasterToDo`.
- Create: `MasterToDo/MasterToDoApp.swift`, `MasterToDo/MasterToDo.entitlements`, `MasterToDo/Info.plist`
- Create: `MasterToDo/Features/TaskList/{TaskListView,TaskRow,AddTaskBar,EditTaskSheet}.swift`

**Interfaces:**
- Consumes: `TodoSchema.models`, `TaskOrdering.sorted`, `TaskItem.canvasFlag`, `TaskItem.remove(in:)`, `TaskCompletion`, and `TrackedCourse`.
- Produces: `TaskListView`, with a `onRefresh: () async -> Void` closure supplied by the app (wired up in Task 7).

Behavior:
- **Container and entitlements:** `ModelContainer(for: Schema(TodoSchema.models), configurations: ModelConfiguration(cloudKitDatabase: .private("iCloud.com.mieracle.MasterToDo")))`. When the launch argument `-localStore YES` is set, use `cloudKitDatabase: .none` (unsigned builds crash in CloudKit setup). Entitlements: iCloud CloudKit with that container, `aps-environment`, App Sandbox, and network client.
- **List:**
  - Show the active list (not done, visible), sorted with `TaskOrdering`.
  - Canvas rows show `courseName`, the due date, and a badge for `canvasFlag`, `pendingVerification` ("Not turned in on Canvas"), and `dueDateChanged` ("Date changed").
  - A flagged row has a "Remove" button that calls `remove(in:)`.
  - Tapping a Canvas row clears `dueDateChanged` and offers "Open in Canvas" (`openURL`).
- **Adding and editing:** a check-off button runs `TaskCompletion.complete` with a fetch closure built from the Keychain token and the stored base URL. When there is no token, the fetch throws, so the task goes to pending. `AddTaskBar` has a text field plus an optional date and an optional time toggle. `EditTaskSheet` edits own tasks' title, date, and time.
- **Done:** a collapsible `Section("Done")` shows done tasks, with uncheck (`TaskCompletion.uncheck`) and delete.
- **Platform:** pull-to-refresh with `.refreshable` on iOS. A toolbar refresh button with `.keyboardShortcut("r")` on both platforms. Animate state and list changes with `withAnimation`. System Liquid Glass comes from the stock toolbar and controls, plus `.glassEffect()` on `AddTaskBar`.

- [ ] **Step 1: Create the project files** and an empty `TaskListView`. Build for macOS and for the iOS Simulator using the Global Constraints command, and expect `BUILD SUCCEEDED` for both.
- [ ] **Step 2: Implement the list, row, add bar, edit sheet, and Done section** described above.
- [ ] **Step 3: Build both platforms** and expect `BUILD SUCCEEDED`. Then launch in the iPhone simulator with `-localStore YES`, add an own task with a date, check it off and uncheck it, and take a screenshot with `xcrun simctl io <sim> screenshot`.
- [ ] **Step 4: Commit** with `feat: add app target with task list`.

---

### Task 7: Settings, course picker, sync and notification services

**Files:**
- Create: `MasterToDo/Features/Settings/{SettingsView,CanvasAccountSection,CourseToggleList}.swift`
- Create: `MasterToDo/Features/CoursePicker/CoursePickerView.swift`
- Create: `MasterToDo/Services/{SyncService,NotificationService}.swift`
- Modify: `MasterToDo/MasterToDoApp.swift` and `TaskListView.swift` (inject services, show the picker and errors)

**Interfaces:**
- Consumes: `CanvasSync`, `KeychainStore.canvasToken`, `NotificationPlanner.plan`, and `DuplicateMerger.mergeAll`.
- Produces:
  - `@MainActor @Observable final class SyncService` with:
    - `lastSync: Date?` (`@AppStorage` backing key `lastCanvasSync`), `isSyncing`, and `lastError: String?`.
    - `syncIfStale(now:)` runs when the last sync is 15 minutes or more ago.
    - `syncNow() async`, `refreshCourses() async -> Int`, and `needsCoursePick: Bool`, which is true when a token exists and no `TrackedCourse` has `isTracked`.
  - `@MainActor @Observable final class NotificationService` with `requestAuthorization() async` and `replan(context: ModelContext) async`, which removes all pending requests and adds the planner output as `UNCalendarNotificationTrigger` from `fireDate` components.

Behavior:
- **Settings:**
  - Canvas base URL (`@AppStorage("canvasBaseURL")`) and a token `SecureField`, saved through `KeychainStore`, never displayed after saving.
  - The summary time (`@AppStorage("summaryHour")` default 8, `summaryMinute` default 0) via a `DatePicker(.hourAndMinute)`.
  - `CourseToggleList`, with a "N new courses" hint when `refreshCourses()` returns > 0. Opening the list sets `hasBeenOffered = true`.
- **First course pick:** when `needsCoursePick` is true, the list shows `CoursePickerView` as a sheet listing active courses with toggles. "Done" sets `isTracked` and runs `syncNow()`.
- **Sync triggers:**
  - On launch, and on the `scenePhase` change to `.active`, call `syncIfStale`.
  - After any sync, task change, or summary-time change, call `notificationService.replan`.
  - Also run `DuplicateMerger.mergeAll` at launch and after CloudKit import, using `NSPersistentStoreRemoteChange` or a scene-phase pass.
- **Errors:** sync errors show `lastError` inline (for example, "Canvas rejected the token — check Settings") without the token text.
- **iOS background refresh:**
  - Info.plist: `BGTaskSchedulerPermittedIdentifiers = [com.mieracle.MasterToDo.refresh]` and `UIBackgroundModes = [fetch, remote-notification]`.
  - `.backgroundTask(.appRefresh("com.mieracle.MasterToDo.refresh"))` runs `syncNow()` and `replan`, then submits the next `BGAppRefreshTaskRequest` with `earliestBeginDate = now + 3h`. Also submit it when the scene goes to the background.
  - Wrap all of it in `#if os(iOS)`.

- [ ] **Step 1: Implement the services and screens** described above.
- [ ] **Step 2: Build both platforms** and expect `BUILD SUCCEEDED`. Run the package tests and expect all PASS.
- [ ] **Step 3: Manual check on the Mac, signed, with a real Canvas token.**
  1. Enter the token. The picker appears. Choose courses, and only open, unsubmitted assignments appear.
  2. Check off an online assignment you haven't turned in, and confirm it shows "Not turned in on Canvas".
  3. Check off an on-paper one, and confirm it moves to Done.
  4. Set the summary time 2 minutes ahead, and confirm one summary notification arrives.
  5. Toggle a course off, and confirm its tasks hide.
- [ ] **Step 4: Commit** with `feat: add Canvas settings, course picker, sync and notifications`.
- [ ] **Step 5: Write `README.md`** (what the app is, how to build, where the token goes, and the CloudKit "Deploy Schema Changes to Production" reminder). Commit it with `docs: add README`.
