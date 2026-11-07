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

### 2026-11-07 · Agent A · handoff (F8, branch `agent-a/csv-validation`)
Work completed: spreadsheet import validates every cell before anything is written. Weight and reps must be what the app itself would write (digits, one point for weight; weight at most 1100 kg or 2500 lb; reps whole numbers); names at most 100 characters; dates 1990 to 2100; at most 50,000 rows. The error names the row and the cell. A name that starts with = + - @ now round-trips (the export's guard apostrophe is removed on import).
Files: `Packages/Fit2216Core/Sources/Fit2216Core/Csv.swift`, `Tests/Fit2216CoreTests/CsvAndCopyTests.swift`, `docs/FINDINGS.md` (F8), this log.
Tests actually run: core `swift test` on Linux, 133 passed (3 new). One of my new tests was wrong at first (an unquoted comma shifted the columns); I fixed the test, not the code. NOT run: Xcode build, device test; the Settings import screen was not touched.
Unresolved risks: stricter than the web app's CSV reader (a hand-edited file with unusual values is refused with a clear message); no row-level import preview yet (counts are shown in the confirmation).
Next suggested action: owner (or Agent B) tries a real exported file plus one with a bad cell. Next for Agent A: `agent-a/food-cache-limits` (F15).
