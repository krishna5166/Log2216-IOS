# Shared agent log

How the two agents (and the owner) stay in step. **Read this and `FINDINGS.md` before starting. Append an entry before you finish.**

- **Builder** = the agent that edits the code and pushes to `main` (Claude Code).
- **Reviewer** = the second agent that audits and reports. It may append to this file and to `FINDINGS.md` only (the owner allows that one exception to "do not change files"); everything else is proposed as a patch or a pull request.
- Append-only, newest at the bottom. One entry per piece of work. Never rewrite another agent's entry; correct it with a new entry.
- Entry format: `### YYYY-MM-DD · Builder|Reviewer · done|finding|question|decision` then 1 to 6 lines. Reference findings by ID (F1, F2 ...) and commits by short hash.
- A finding is a claim until the Builder has verified it against the code. Say "read from code" or "ran it" and give a confidence.
- Statuses in `FINDINGS.md`: `open`, `fixed (hash)`, `mitigated`, `accepted (reason)`, `needs owner`, `declined (reason)`.

---

### 2026-11-07 · Builder · done
Created this log and `FINDINGS.md`. Recorded the Reviewer's first report as F1 to F15 and verified each against the code at `6e5d20c`.
State: core 130 tests pass; all 40 app files parse (`swiftc -parse`); the app itself has not been compiled by an agent (no iOS SDK here), only by the owner on a Mac.

### 2026-11-07 · Builder · done
Fixed F1 (account-switch race), F2 (restore/import truthful), F3 (food saves tracked), F4 (encode failure), F13 part (stepper VoiceOver names), F8 part (CSV label, swaps kept on import), F7 mitigation (200 to 500 workouts read), timer survives reopening. See `FINDINGS.md` for each.

### 2026-11-07 · Builder · question
Reviewer: for F6 (two devices editing the same workout), is a per-set update with a version counter acceptable, or do you want operation-based merging? The Builder leans to "accept last-write-wins now" because only two people use it and the web app, the only other writer, is being retired (web PR #60).

### 2026-11-07 · Agent A · handoff (F7, branch `agent-a/lifetime-bests`)
Work completed: personal bests and "recent best" are now judged against the whole workout history, not only the newest 500. New core `LogHistory.merged(recent:archive:)`; `AppModel.archive` and `recordLogs`; the archive is read in the background (server the first time and every 14 days, otherwise from this phone's copy); deleting a workout also removes it from the archive; sign-out clears it. Used by the workout screen (bests and PR banner), Insights (recent bests) and Summary (recent best).
Files: `Packages/Fit2216Core/Sources/Fit2216Core/LogHistory.swift`, `Tests/.../LogHistoryTests.swift`, `App/AppModel.swift`, `App/FirestoreService+Writes.swift`, `Logging/LoggingView.swift`, `Insights/InsightsView.swift`, `Summary/SummaryView.swift`, docs.
Tests actually run: core `swift test` on Linux, 133 passed (3 new, including an old record that stops a lighter lift being a new best); `swiftc -parse` on all app files, clean. NOT run: no Xcode build, no device test.
Unresolved risks: (1) app target uncompiled by an agent; (2) an edit or delete made on another device to a workout older than the recent window shows up only at the next 14-day refresh; (3) Firestore's local cache is assumed to keep older documents (it is small; eviction would only make the archive smaller, never wrong).
Next suggested action: owner builds this branch on the Mac and checks that a workout still opens and the bests look right; Agent B can check the three risks above and propose a test for risk (2). Next for Agent A: `agent-a/csv-validation` (F8).
Note: this entry and the one in PR #1 both append at the bottom of this file, so the second to merge needs a trivial conflict fix; Agent A will resolve it.
