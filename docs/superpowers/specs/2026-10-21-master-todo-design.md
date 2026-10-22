# Master To-Do — Design

Date: 2026-10-21
Status: draft for approval

## Intent

One master to-do list on iPhone and Mac that holds both the user's own tasks and every open Canvas assignment, so nothing due slips by. The user picks up to 3 items from it for a physical sticky note. That happens outside the app and needs no feature, but it is why the list has to be complete and trustworthy: every open assignment is listed, dates stay current, and nothing silently disappears or is silently marked done.

Single user, personal app, not for distribution.

## Goals

1. Add, edit, check off, and delete the user's own tasks.
2. Sync Canvas assignments from courses the user picked, keeping names and due dates current.
3. Never auto-remove a Canvas task. Closed or submitted tasks get flagged, and the user removes them.
4. Checking off a Canvas task is verified against Canvas before it is dismissed.
5. Notifications: a daily summary ("5 things due today") at a configurable time, plus one reminder 3 hours before each due time.
6. Native SwiftUI on iOS and macOS with Liquid Glass and SwiftUI animations.
7. iPhone and Mac show the same list.

## Non-goals (for now)

- UI/UX polish. The functional app comes first. Different looks and flows will be explored later through separate `/prototype` spikes, so keep views thin and swappable.
- Tags, priorities, subtasks, recurring tasks, notes, or attachments on tasks.
- A "sticky note / top 3" feature.
- Canvas calendar events (assignments only).
- Submitting to Canvas or writing anything back to Canvas.
- Widgets, Apple Watch, and Shortcuts.

## Anti-goals (failure even if it "works")

- A Canvas task vanishes without the user removing it.
- A task is dismissed as done when Canvas says it wasn't turned in (online submissions only).
- A due date in the app is stale after the instructor moves it.
- The Canvas token ends up anywhere except the Keychain.
- Duplicate tasks appear because both devices synced Canvas.

## Platform & stack

- One Xcode multiplatform SwiftUI app target (iOS + macOS).
  *Builder's call:* a local Swift package for testable logic (Canvas client, sync/reconcile, notification planning), mirroring StudyTool's `MieracleKit` split.
- Swift 6 language mode. SwiftData for storage, with a CloudKit-backed container so iPhone and Mac share the list.
  - CloudKit model rules apply: no `.unique`, every property has a default or is optional, every relationship is optional.
- *My call:* deployment target iOS 26 / macOS 26, the first versions with Liquid Glass. StudyTool's iPhone hit trouble with 27.
- Liquid Glass through the stock SwiftUI APIs (`glassEffect`, system bars and controls), with SwiftUI animations on list changes, check-off, and state badges.
- *My call:* macOS App Sandbox **on**, with only the outgoing network entitlement. Unlike StudyTool, nothing here needs it off.
- Tests: Swift Testing, run against the logic package.

## Canvas

### Reuse from StudyTool

Copy, don't link, these files from `../StudyTool/MieracleStudy/MieracleKit/Sources/MieracleKit/Canvas/`:

- `CanvasClient`: bearer token, `Link`-header paging, `activeCourses()`, `assignments(courseID:)`.
- `KeychainStore`: a synchronizable generic password, so the iPhone gets the token entered on the Mac.
- The diff-and-update pattern in `CanvasSync`.

Extend the models and client:

- `CanvasAssignment` also decodes `lock_at`, `submission_types`, `submission.submitted_at`, and `submission.excused`.
- Add `assignment(courseID:id:)` for single-assignment verification, using `include[]=submission`.

### Settings

- Canvas base URL and personal access token, entered in Settings. Keep the token in the Keychain only, never in source, `@AppStorage`, SwiftData, or logs.
- Course selection is stored in SwiftData so both devices share it.

### Course picking

- **First sync:** after the token is entered, show active courses and let the user choose which to track. Nothing is imported until they confirm.
- **Later:** Settings lists active courses with on/off toggles. Turning one on imports it under first-sync rules. Turning one off hides its tasks; *my call* is to keep them in storage so turning it back on restores the state.
- New active courses (a new semester) are not auto-added. *My call:* Settings shows a small "N new courses" hint.

### Definitions

- **Submitted:** `submission.workflow_state` is `submitted`, `graded`, or `pending_review`, or `submission.excused == true`.
  - Watch out: Canvas can report `graded` with no submission when an instructor enters a grade for a missing assignment. *My call:* count it as submitted, since the work is no longer open.
- **Closed:** `lock_at` is in the past.
- **Online submission:** `submission_types` contains any of `online_upload`, `online_text_entry`, `online_url`, `online_quiz`, `media_recording`, `student_annotation`, or `discussion_topic`. Anything else is offline: `none`, `on_paper`, `not_graded`, or `external_tool`.
- **Gone from Canvas:** previously synced, but no longer returned for a tracked course (deleted or unpublished).

### First sync of a course

Import assignments that are neither submitted nor closed. Include ones past due but not yet locked, since late work is still open. Include ones with no due date.

### Later syncs

For each tracked course, fetch all assignments and reconcile them by Canvas assignment id.

- **New assignment** (an id not seen before) that is not submitted and not closed: add it.
- **Known, still in the list:** update the name, due date, lock date, submission types, and submitted/closed state. Animate due-date changes. *My call:* show a "date changed" badge until the user opens or touches the task.
- **Known, user already removed it:** never re-add it, even if its date changes. Keep a tombstone record of removed Canvas ids so a removal sticks.
- **Gone from Canvas:** flag it "Removed from Canvas". Don't delete it.

Flagged states (Submitted, Closed, Removed from Canvas) appear on the task with a clear badge and a one-tap "Remove". The user always does the removal.

### Checking off a Canvas task

1. Offline submission type: dismiss immediately.
2. Online submission type: call `assignment(courseID:id:)`.
   - **Submitted:** dismiss.
   - **Not submitted:** the task stays in the list, marked "Done in app — not turned in on Canvas", and stays visible and counted. Each later sync re-checks it and dismisses it once Canvas shows it submitted. The user can uncheck it to return to normal.
   - **Network or auth error:** same as not submitted, and re-check on the next sync. Never dismiss when verification fails.

"Dismiss" means moving the task to a Done state that is hidden from the main list. *My call:* keep a simple "Done" section or filter for undoing mistakes. Removing a flagged task deletes it from the list (with a tombstone).

### When sync runs

- On app launch and on return to the foreground, if the last sync was more than 15 minutes ago (*my call*).
- Pull-to-refresh on iOS and a refresh button or ⌘R on macOS.
- *My call:* on iOS, a `BGAppRefreshTask` roughly every few hours, so date changes and notifications stay fresh when the app isn't opened. iOS decides the actual timing; this is best effort.

### Two devices both syncing

Both devices may sync Canvas and insert the same assignment before CloudKit merges. Every Canvas task stores its Canvas assignment id. After each sync and after CloudKit imports, merge duplicates by that id. StudyTool has a `DuplicateMerger` for this pattern.

Merge rules: keep the most advanced state, in order removed > done > pending-verification > open. Take the newest Canvas fields.

## Own tasks

- Fields: title (required), optional due date, and an optional due time. With a date but no time, the task counts as due at end of day for sorting and summary purposes.
- Add from a single field plus an optional date picker.
- Edit, check off (dismisses immediately), uncheck from Done, and delete.

## The list

One list, sorted:

1. Overdue
2. Due today
3. Later, by due date
4. No due date

Ties are broken by creation date.

- A Canvas task shows its course name and opens the assignment page in Canvas from the row.
- Flagged and pending-verification tasks show their badge in place. They are not moved to a separate section.

## Notifications

Local notifications (`UNUserNotificationCenter`), scheduled on each device. The user accepted getting them on both iPhone and Mac.

- **Daily summary:** at a time set in Settings (*my call:* default 8:00 AM), "N things due today". Counts every not-done task due that calendar day, own and Canvas, including pending-verification tasks. No notification when N is 0.
- **3 hours before:** one per not-done task that has a due time: "‹title› is due at ‹time›". Skip tasks whose due time is under 3 hours away when scheduled. A Canvas task with a date-only due falls back to 11:59 PM, which is what Canvas sends anyway.

Planning is a pure function that turns the current tasks, settings, and current time into pending notification requests. Re-plan after every sync, every task change, and settings changes, replacing all pending requests.

Notification content is fixed when scheduled, so the summary count is computed then. Plan summaries for the next 7 days. iOS caps pending notifications at 64, so schedule the nearest ones first and leave the rest to the next re-plan.

## Testing

Swift Testing on the logic package. At minimum:

- Reconcile: first-sync filter, new, updated date, submitted flag, closed flag, gone flag, tombstone not re-added, and duplicate merge.
- Check-off verification: offline types dismiss; online types dismiss only when submitted; errors keep the task.
- Notification planner: summary count per day, zero suppression, the 3-hour skip, the 64 cap, and date-only handling.
- Canvas client decoding, using fixture JSON for the new fields.

## Left to the builder

- Exact SwiftData model shapes and file layout. Follow StudyTool's MV-with-services pattern: views use `@Query` directly, logic lives in the package, and shared state lives in `@Observable` services.
- Visual details of badges, animations, and glass. Keep them stock and simple; prototypes come later.
- Bundle id and iCloud container name. *Suggest:* `com.mieracle.MasterToDo` and `iCloud.com.mieracle.MasterToDo`.

## Open questions

None blocking.
