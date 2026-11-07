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

### 2026-11-07 · Agent A · handoff (F15, branch `agent-a/food-cache-limits`)
Work completed: the food-estimate cache (`FoodMemory`, UserDefaults, per account) is now bounded and cleared on sign-out. New core `Lru.touch` (3 tests). Limit 200 entries, texts over 500 characters are not stored, older entries are adopted once into an index, a lookup counts as use, and the Sign out button clears that account's entries.
Files: `Packages/Fit2216Core/Sources/Fit2216Core/Lru.swift`, `Tests/Fit2216CoreTests/LruTests.swift`, `Fit2216/Fit2216/App/AIClient.swift`, `Fit2216/Fit2216/App/AuthModel.swift`, `docs/FINDINGS.md` (F15), this log.
Tests actually run: core `swift test` on Linux, 133 passed (3 new); `swiftc -parse` on all app files, clean. NOT run: Xcode build, device test (UserDefaults behaviour itself is untested).
Unresolved risks: (1) app uncompiled by an agent; (2) clearing happens only on the Sign out button, not when Firebase ends a session; (3) the one-time adoption of old entries reads all UserDefaults keys once per account (small).
Decision flagged for the owner: clear-on-sign-out costs one repeat AI call per meal after signing back in; say if you would rather keep the cache across sign-outs.
Next suggested action: owner builds the branches on the Mac; Agent B can add a test case for risk (2). Agent A's claimed list (PRs #1, #3, #4, this one) is done; UX tasks (Summary "what now" card, Macros estimate review) need a separate approval.
