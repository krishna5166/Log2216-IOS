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

### 2026-11-07 · Agent A · handoff (task 6, branch `agent-a/macros-estimate-review`)
Work completed: Add meal no longer saves the AI's answer straight away. A "Check estimate" sheet shows the estimate (labelled "Estimated by AI" or "From an earlier estimate or correction on this phone"), lets the person edit each food's name, calories, protein, carbs and fat, remove a food, and see the live total; Save meal / Update meal or Cancel (the sheet cannot be swiped away by accident). A correction is remembered for the same text, so the same words are not mis-estimated again. Saved values are cleaned first (core `Food.cleaned`: plausible ranges, rounding, names capped, empty foods dropped).
Files: core `FoodReview.swift` + `Tests/.../FoodReviewTests.swift`; app `Macros/MacrosModel.swift`, `Macros/MacrosView.swift`, new `Macros/EstimateReviewSheet.swift`; `docs/FINDINGS.md` (F12), this log.
Tests actually run: core `swift test` on Linux, 133 passed (3 new); `swiftc -parse` on all app files, clean. NOT run: Xcode build, device test; the sheet has not been rendered or used by an agent.
Unresolved risks: (1) uncompiled app target; (2) `TextField(value:format:)` with decimal pad: a half-typed number keeps the previous value until it parses, which should be tested by hand; (3) one more tap per meal (the price of the review); (4) portion sizes are not modelled.
Next suggested action: owner builds on the Mac and adds one real meal, then edits a number, saves, and types the same text again (should show the corrected amounts). Agent B: propose edge cases for the number fields.
Open Agent A work after this: none claimed. Candidates for the next approval: Insights one weekly conclusion (F12), import preview, accessibility pass (F13), all-time bests as a stored aggregate (F7 full fix).
