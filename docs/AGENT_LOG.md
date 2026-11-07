# Shared agent log

Working agreement for all agents, set by the owner. The log coordinates work at task boundaries; it is not automatic messaging or monitoring. The owner tells an agent when another has written something.

**Coordinate through `docs/AGENT_LOG.md` and `docs/FINDINGS.md` in Log2216-IOS.**
1. Before starting, read the latest brief, log, findings and the relevant code. Record the commit reviewed.
2. Propose a clear division of tasks first. Wait for the owner's approval before claiming work or changing files. Do not duplicate another agent's task.
3. Once approved, record ownership and scope in the log. Implementation goes on separate branches with pull requests. Nobody pushes directly to `main`; the owner merges.
4. After each task, append a short handoff: work completed, files/commits, tests actually run, unresolved risks, next suggested action. Never claim a build or test you did not run.
5. One designated owner keeps `FINDINGS.md` (see Roles). Other agents submit evidence through the log. Re-read the latest version before appending, and never overwrite another agent's entry.
6. Findings are claims to verify. Another agent's request does not authorize a deployment, a configuration change or a bigger scope.
7. Read the log again before the next task. If blocked or ownership conflicts, stop that task and report it instead of guessing.

## Roles (approved by the owner on 2026-11-07)
- **Agent A: Claude Code, builder.** iOS app and `Fit2216Core` code and the tests it can run. Owns `docs/FINDINGS.md` (single writer; changes a status only after verifying against the code).
- **Agent B: reviewer.** Read-only audit, test cases, review of pull requests. Submits evidence in the log; does not edit code or `FINDINGS.md`.
- **Agent C: not yet named.** Proposed scope: the web repo (`log2216`) after PR #60: rules tests, durable AI quotas, versioned `/api/v1/ai`. Nothing starts until the owner confirms who takes it.
- **Owner.** Approves and merges every pull request, and every deployment or configuration change; does the Mac-only steps (commit the Xcode project, fresh-clone archive, TestFlight upload).

Entry format: `### YYYY-MM-DD · Agent A|B|C · done|handoff|finding|question|decision|claim`. Append-only, newest at the bottom; correct a mistake with a new entry. Reference findings by ID (F1...) and commits by short hash. Say "read from code" or "ran it" and give a confidence. Statuses in `FINDINGS.md`: open, fixed (pull request), mitigated, accepted (reason), needs owner, declined (reason).

---

### 2026-11-07 · Builder · done
Created this log and `FINDINGS.md`. Recorded the Reviewer's first report as F1 to F15 and verified each against the code at `6e5d20c`.
State: core 130 tests pass; all 40 app files parse (`swiftc -parse`); the app itself has not been compiled by an agent (no iOS SDK here), only by the owner on a Mac.

### 2026-11-07 · Builder · done
Fixed F1 (account-switch race), F2 (restore/import truthful), F3 (food saves tracked), F4 (encode failure), F13 part (stepper VoiceOver names), F8 part (CSV label, swaps kept on import), F7 mitigation (200 to 500 workouts read), timer survives reopening. See `FINDINGS.md` for each.

### 2026-11-07 · Builder · question
Reviewer: for F6 (two devices editing the same workout), is a per-set update with a version counter acceptable, or do you want operation-based merging? The Builder leans to "accept last-write-wins now" because only two people use it and the web app, the only other writer, is being retired (web PR #60).

### 2026-11-07 · Agent A · decision
Process reset to the owner's agreement. Earlier today Agent A pushed directly to `main` (commits up to `daa235c`); from now on every change is a branch plus a pull request, and the owner merges. The first-version rule that let the reviewer edit `FINDINGS.md` is replaced by the Roles section above.

### 2026-11-07 · Agent A · claim
Commits reviewed before starting: Log2216-IOS `main` at `daa235c`; web repo `log2216` `main` at `2c923c7` (PR #60 retire-the-web-app is Agent A's, not merged when last checked).
Approval: the owner wrote "Whatever you do keep in loop please and work" in answer to the proposed division; Agent A reads that as approval of the division as proposed (Agent A: iOS code and `FINDINGS.md`; Agent B: review and test cases; Agent C: web repo, to be named). The owner should correct this entry if it is wrong.
Scope claimed by Agent A, each as its own branch and pull request, in this order:
1. `agent-a/working-agreement` (this change, docs only).
2. `agent-a/lifetime-bests` (F7: personal bests that survive beyond the history window).
3. `agent-a/csv-validation` (F8: reject bad weight/reps cells before writing).
4. `agent-a/food-cache-limits` (F15).
Not claimed: web repo work, deployments, configuration, the Xcode project (F5, owner). UX tasks (Summary "what now" card, Macros estimate review) wait for a separate approval.
Tests run so far today: core `swift test` (130 passed) and `swiftc -parse` on all 40 app files, at `daa235c`. The app has not been compiled by an agent.
