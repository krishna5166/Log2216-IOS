# Findings tracker

Source: Reviewer report of 2026-11-07 (source-based, nothing ran on a device). Builder verified each against the code. See `AGENT_LOG.md` for the protocol.

| ID | Finding | Severity | Status | Notes |
|---|---|---|---|---|
| F1 | Account switch can show or save the previous account's data (late load applied after sign-out) | High | fixed | Read from code, certain. `AppModel` now has a load generation; stale results are dropped, other account's data is cleared before a different uid loads. Manual test: slow account A load, sign out, sign in B offline, let A finish; none of A's data may appear. |
| F2 | Restore and CSV import claim success before writes finish | Medium | fixed | Batches of 400 (each atomic), one report with saved and failed counts, shown when the cloud answers (offline: on reconnect). Not one atomic restore; safe to re-run. Row-level preview not built. |
| F3 | Food saves bypass save tracking | Medium | fixed | `MacrosModel.track` routes through `AppModel.tracked`, same notice as workouts. |
| F4 | Encode failure leaves "syncing" stuck | Low | fixed | `saveLog` and `saveFoodDay` return `SaveEncodingError`; `updateProfile` with nothing to write now completes. |
| F5 | Clean-clone app build not established | Release | needs owner | Read from code: committed `project.xcproj` has no Firebase package; the owner's local project does. Owner must commit `Fit2216.xcodeproj` (project and `Package.resolved` under the workspace), then verify with a fresh clone + archive. Never commit `GoogleService-Info.plist`. |
| F6 | Concurrent saves overwrite (whole-document writes; old PWA outbox could replay) | Medium | accepted (for now) | Two people, separate accounts: the same document is only written by one person's devices. The PWA replay risk ends when web PR #60 deploys (the old app code stops running; flush it first, see PR). Revisit with set IDs and versions if both phones of one account are used in parallel. |
| F7 | Personal bests forget history beyond the fetched window | Medium | fixed in PR (branch `agent-a/lifetime-bests`), awaiting owner merge and a phone check | Read from code, certain. The app now reads the whole history once (server first time and every 14 days, otherwise this phone's own copy) and judges records, the set-page bests and the Summary/Insights bests against it. Core `LogHistory.merged` with tests (133 pass). Not compiled by an agent; needs a build on the Mac. Risk: a workout deleted or edited on another device is picked up at the next 14-day refresh. |
| F8 | CSV is not a full backup; weak cell validation | Low | partly fixed | Label says so; import keeps a day's swaps and copied template. Cell validation (non-numeric weight or reps) still to harden in `Csv.parse`. |
| F9 | Firestore rules: any signed-in user has write access in their own namespace; AI allowlist does not cover the database | High for public launch | needs owner | Web repo. Owner: confirm in Firebase console that sign-up is OFF (`DEPLOY.md` says so) so only invited accounts exist. Builder: after web PR #60, add rules emulator tests for unrelated users and malformed docs, and an allowlist clause. |
| F10 | AI quotas live in process memory | Low now, high at scale | open | Web repo, after PR #60: durable per-user quota, concurrency limit, provider spend caps, no raw food text in logs. |
| F11 | Operational evidence missing (crash/sync metrics, budget alerts, backup drill, account deletion, retention) | Launch | partly | Crash reports arrive in Xcode Organizer for TestFlight builds; Diagnostics screen exists. Backup restore drill, budget alerts and deletion flow are open. |
| F12 | UX direction (Summary answers "what now", one status area, Macros estimate review, Insights one conclusion, import flow, a11y pass) | Product | backlog | See the list below; none are bugs. |
| F13 | Stepper VoiceOver says only Increase/Decrease; Dynamic Type capped | Low | partly fixed | Labels now "Decrease weight" etc. and the text fields are labelled. Cap at accessibility 2 stays until adaptive layouts exist; full VoiceOver/large-text pass open. |
| F14 | Architecture: keep Firebase, harden it; separate screen state, domain operations and persistence | Direction | accepted | Order adopted: account-scoped state (F1 done), one save-status path (partly: workouts, food, profile tracked; imports report), stable IDs and conflict policy (deferred), compact all-time summaries (F7), rules tests (F9), durable quotas (F10). |
| F15 | Food-estimate cache needs a retention limit and sign-out policy | Low | open | Already per account; add a size cap and clear on sign-out. |

## UX backlog from the review (Builder's take)
1. Summary: dominant "what to do now" card, labelled rings, one consolidated status area (offline, sync, data warnings). Do next.
2. Macros: estimate-review step (portion, calories, macros, correction) before saving; mark AI estimates as estimates.
3. Insights: one weekly conclusion + chart + one suggested action; detail behind drill-downs.
4. Imports: select, validate, preview changes, confirm, progress, results (results done, preview not).
5. Timer timestamps persisted: done (start time remembered per workout).
