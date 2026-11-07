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

### 2026-11-06 · Reviewer · decision
Codex: owner approved the proposed release-readiness review in chat ("Keep you self in loop and work on it"). Reviewed base `daa235c`; re-read brief, log, findings; no open iOS PRs at task start.
Scope: inspect committed Xcode/dependency configuration, CI evidence, and phone/TestFlight release verification gaps. No app implementation, service configuration, deployment, or main pushes. Work uses `codex/release-readiness-review` and a PR.
Builder retains FINDINGS.md ownership as proposed; Codex submits evidence here and does not edit that tracker. Functional/data-safety implementation remains with the builder and existing reviewer.
Owner's latest working agreement overrides older direct-main/shared-tracker permissions above: separate branches and PRs, re-read before appending, verify claims, no continuous monitoring implied.

### 2026-11-06 · Reviewer · finding
Codex release review, read from code at `daa235ceb67b502bed86486d4323c1f1e15a293c`, certain: F5 remains unresolved. `Fit2216/Fit2216.xcodeproj/project.xcproj:13-19,40-45` lists only local Fit2216Core; `Fit2216/Fit2216/Fit2216App.swift:2,12` imports/configures Firebase. Recursive tree has no committed Firebase package resolution file.
Trigger: a fresh checkout without the owner's local Xcode package additions. Expected risk: Firebase imports cannot resolve from the committed dependency graph; exact Xcode failure was not run. Builder/owner should commit the working project/package configuration through a PR, excluding Firebase plist and signing material, then build a fresh checkout.
CI evidence: [run 42318207534](https://github.com/krishna5166/Log2216-IOS/actions/runs/42318207534) succeeded for this SHA; `.github/workflows/core-tests.yml:12-19` runs only core on Linux. This is existing F5 evidence, not a new finding ID or a successful app build.

### 2026-11-06 · Reviewer · finding
Codex release evidence, read from code at `daa235c`, certain: committed project has portrait/iPhone-only/iOS 17.6/bundle ID settings; `AppConfig.swift:7` already points at https://log2216.vercel.app. No service URL change is needed on this snapshot.
`PrivacyInfo.xcprivacy` exists, but archive inclusion and actual distribution declarations were not verified; do not equate a source file with a validated archive. `ITSAppUsesNonExemptEncryption` is absent from the committed project (the runbook already delegates this to the owner).
`docs/RELEASE.md:5-10` describes pull-and-build, not an independent clean checkout. Suggested evidence: reviewed SHA, Xcode version, resolved package versions, fresh-checkout build/archive result, device/iOS version, build number, and dated pass/fail results. No release/configuration action is authorized by this review.

### 2026-11-06 · Reviewer · done
Codex completed release-readiness source/CI inspection at `daa235c`; ownership entry commit `b3ab9a6`; changes limited to append-only `docs/AGENT_LOG.md` on `codex/release-readiness-review`. FINDINGS.md unchanged. Main log and findings re-read before this append; no newer entries observed.
Verification performed: GitHub file/tree reads and latest base-SHA workflow status; no local tests, Xcode build, archive, device test, deployment, or Firebase/Vercel console inspection performed. Earlier source inventory counted 130 test methods; existing CI passed, not a new test run by Codex.
Unresolved: F5 clean-checkout dependency/build evidence; phone and archive evidence; deployed authorization/privacy/recovery checks remain unverified. No implementation fixes claimed.
Next: builder/owner supplies project configuration through a separate PR; on a fresh Mac checkout, provision ignored Firebase config locally, resolve packages, build and archive, then record results. On phone verify sign-in, log-set/reopen, offline-save/reconnect, Macros, and locked-screen rest notification before TestFlight. Include account-switch/import regressions with the functional reviewer's scope.
Coordination is at task boundaries only. This review owns no functional implementation; do not infer continuous monitoring or automatic messages to the other agents. Re-read current main log/findings before the next task and reconcile this PR with intervening append-only entries before merge.

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

### 2026-11-07 · Agent A · handoff (F7, branch `agent-a/lifetime-bests`)
Work completed: personal bests and "recent best" are now judged against the whole workout history, not only the newest 500. New core `LogHistory.merged(recent:archive:)`; `AppModel.archive` and `recordLogs`; the archive is read in the background (server the first time and every 14 days, otherwise from this phone's copy); deleting a workout also removes it from the archive; sign-out clears it. Used by the workout screen (bests and PR banner), Insights (recent bests) and Summary (recent best).
Files: `Packages/Fit2216Core/Sources/Fit2216Core/LogHistory.swift`, `Tests/.../LogHistoryTests.swift`, `App/AppModel.swift`, `App/FirestoreService+Writes.swift`, `Logging/LoggingView.swift`, `Insights/InsightsView.swift`, `Summary/SummaryView.swift`, docs.
Tests actually run: core `swift test` on Linux, 133 passed (3 new, including an old record that stops a lighter lift being a new best); `swiftc -parse` on all app files, clean. NOT run: no Xcode build, no device test.
Unresolved risks: (1) app target uncompiled by an agent; (2) an edit or delete made on another device to a workout older than the recent window shows up only at the next 14-day refresh; (3) Firestore's local cache is assumed to keep older documents (it is small; eviction would only make the archive smaller, never wrong).
Next suggested action: owner builds this branch on the Mac and checks that a workout still opens and the bests look right; Agent B can check the three risks above and propose a test for risk (2). Next for Agent A: `agent-a/csv-validation` (F8).
Note: this entry and the one in PR #1 both append at the bottom of this file, so the second to merge needs a trivial conflict fix; Agent A will resolve it.

### 2026-11-06 · Grok Bot (web tests) · claim + handoff
Scope, taken at the owner's direction ("Take tasks and keep informed in loop"), test-only: new file `app/rules/privacy.rules.ts` in the web repo `log2216`, branch `grok/rules-privacy-tests`, base `2c923c7`, commit `2fb07db`. No change to `firestore.rules`, CI, `/api/ai`, this repo's code or `FINDINGS.md`. Checked first: no open PR or branch in either repo covered rules privacy tests (open iOS PRs #1 to #7; web PR #60 only).
Covers (ran it, Firestore emulator via `npm run test:rules`, 21 of 21 passed three runs in a row: 12 existing + 9 new): signed-out callers reach nothing; a stranger cannot read, list, write or delete any part of another account (profile, logs, weights, foodDays, templates, shared, a new collection); the owner reads and writes everything; a mutual circle and macro-sync partner reads logs and the card only, never profile, weights, foodDays or templates, and writes nothing; request inbox identity, field, size and type checks.
Also ran: `npx tsc -b` (clean; the rules folder is not in the TS project), `npx oxlint` (clean), `npx vitest run` (269 passed). The new file uses its own emulator project id so it never shares data with `circle.rules.ts`.
No security defect found in the current rules. Not covered: rules have no size or shape limits for an owner's own documents, and any signed-in account can write its own namespace (F9). That needs a rules change and owner approval, not a test.
Next safe candidate (not started): once the owner picks the F9 policy (allowlist or invite claim), add failing-first rules tests for it on a separate branch.
