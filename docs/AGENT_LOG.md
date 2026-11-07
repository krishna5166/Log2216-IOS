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

### 2026-11-07 · Agent A · claim
Owner gave full approval ("I give full approval") for the remaining Agent A work. Re-read the log, `FINDINGS.md` and the PR list first: no merges since `daa235c`, only PR #2 (Codex release review, evidence only) from another agent. Claimed, each its own branch and pull request: (5) `agent-a/summary-now-card` (Summary "what now" guidance and one status banner, F12 part), then (6) `agent-a/macros-estimate-review` (review step before a meal is saved, F12 part). Still not claimed: web repo (Agent C), F5 (owner), deployments and configuration.

### 2026-11-07 · Agent A · handoff (task 5, branch `agent-a/summary-now-card`)
Work completed: (a) the Summary hero card now leads with what to do now (Ready when you are / Keep going / Done for today / Rest day / Skipped / Next up) with a one-line detail and a legend that says what the two rings measure. (b) The four separate top-of-screen banners (load failed, offline, change refused, still syncing) are replaced by one banner that shows only the most important notice, folding "N changes waiting to sync" into the offline line.
Files: core `Summary.swift` (`Summary.guidance`), new `StatusNotice.swift` (`Status.notice`), `Tests/.../StatusAndGuidanceTests.swift`; app `Summary/SummaryView.swift`, `App/AppGate.swift`; `docs/FINDINGS.md` (F12), this log.
Tests actually run: core `swift test` on Linux, 133 passed (3 new); `swiftc -parse` on all app files, clean. NOT run: Xcode build, device test; the rendered layout has not been seen by an agent.
Unresolved risks: (1) uncompiled app target; (2) the Summary headline text is new copy the owner may want to reword; (3) the Retry button on the offline notice also shows while the app is just refreshing from this phone's copy (same as before).
Next suggested action: owner builds on the Mac and screenshots Summary in three states (not started, finished, rest day) and the banner when offline. Next for Agent A: task 6, Macros estimate review.
