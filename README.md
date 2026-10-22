# Master To-Do

One to-do list on iPhone and Mac that merges your own tasks with open Canvas assignments.

- **Your tasks:** add with an optional due date and time; check off, edit, delete.
- **Canvas:** pick courses on first sync; only open, unsubmitted assignments are imported. Later syncs add new ones and update names and due dates. Submitted, closed, or deleted assignments are flagged, never removed — you remove them.
- **Check-off:** online-submission assignments are verified with Canvas; if not turned in, they stay as "Not turned in on Canvas" until a sync confirms the submission. Paper/no-submission ones dismiss right away.
- **Notifications:** a daily "N things due today" summary (time set in Settings) and a reminder 3 hours before each due time.
- **Sync:** on launch/foreground when older than 15 min, pull-to-refresh, ⌘R, and iOS background refresh. iPhone and Mac share data through iCloud (CloudKit).

## Build

Open `MasterToDo/MasterToDo.xcodeproj` (Xcode 27, iOS/macOS 26+). Logic lives in the local package `MasterToDo/TodoKit`:

```sh
cd MasterToDo/TodoKit && swift test --scratch-path ~/Library/Caches/TodoKit-build
```

Build outside the iCloud-synced folder (`-derivedDataPath ~/Library/Caches/MasterToDo-DD`); codesign breaks inside it. Unsigned simulator runs need the launch argument `-localStore YES`.

## Canvas token

Settings → Canvas: enter your school's Canvas address and a personal access token (Canvas → Account → Settings → New Access Token). The token is stored only in the iCloud Keychain.

## CloudKit

Container `iCloud.com.mieracle.MasterToDo`. After any model change, deploy the schema in CloudKit Console → *Deploy Schema Changes to Production* (Xcode runs use Development).
