# MasterToDo

Personal to-do app (iOS + macOS, SwiftUI) that merges my own tasks with open Canvas assignments. Single user.

- Spec: `docs/superpowers/specs/2026-10-21-master-todo-design.md`. Plan: `docs/superpowers/plans/2026-10-21-master-todo.md`.
- Xcode project: `MasterToDo/MasterToDo.xcodeproj`. Testable logic: `MasterToDo/TodoKit` (local package).
- Tests: `cd MasterToDo/TodoKit && swift test --scratch-path ~/Library/Caches/TodoKit-build` (building inside iCloud-synced Documents breaks codesign).
- Canvas token lives only in the Keychain. Never in source, AppStorage, SwiftData, or logs.
- CloudKit model rules: no `.unique`, every property defaulted/optional, every relationship optional. After model changes: CloudKit Console → Deploy Schema Changes to Production.

## Git workflow (pr mode)
<!-- git-workflow:pr — checked by ~/.claude/hooks/git-workflow-guard.sh; keep this marker -->
- Never commit to main, never merge a PR, never force-push. If a branch falls behind main, merge main into it.
- One branch per issue or feature: `feat/<issue#>-<slug>`, `fix/<issue#>-<slug>`.
- Conventional Commits 1.0.0, subject line only unless the why isn't obvious from the diff.
  Breaking changes: `!` after the type and a `BREAKING CHANGE:` footer.
- Run `git add` and `git commit -m "<subject>"` as separate commands, never chained.
- PR title is a conventional commit (it becomes the squash commit on main).
  Body: what, why, how tested, open questions, `Closes #N`.
- Review comments: fix what's clear, ask on the PR when ambiguous, reply to every thread.
