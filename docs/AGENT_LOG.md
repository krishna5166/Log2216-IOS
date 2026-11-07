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

### 2026-11-07 · Agent A · handoff (F8, branch `agent-a/csv-validation`)
Work completed: spreadsheet import validates every cell before anything is written. Weight and reps must be what the app itself would write (digits, one point for weight; weight at most 1100 kg or 2500 lb; reps whole numbers); names at most 100 characters; dates 1990 to 2100; at most 50,000 rows. The error names the row and the cell. A name that starts with = + - @ now round-trips (the export's guard apostrophe is removed on import).
Files: `Packages/Fit2216Core/Sources/Fit2216Core/Csv.swift`, `Tests/Fit2216CoreTests/CsvAndCopyTests.swift`, `docs/FINDINGS.md` (F8), this log.
Tests actually run: core `swift test` on Linux, 133 passed (3 new). One of my new tests was wrong at first (an unquoted comma shifted the columns); I fixed the test, not the code. NOT run: Xcode build, device test; the Settings import screen was not touched.
Unresolved risks: stricter than the web app's CSV reader (a hand-edited file with unusual values is refused with a clear message); no row-level import preview yet (counts are shown in the confirmation).
Next suggested action: owner (or Agent B) tries a real exported file plus one with a bad cell. Next for Agent A: `agent-a/food-cache-limits` (F15).

### 2026-11-07 · Agent A · handoff (F15, branch `agent-a/food-cache-limits`)
Work completed: the food-estimate cache (`FoodMemory`, UserDefaults, per account) is now bounded and cleared on sign-out. New core `Lru.touch` (3 tests). Limit 200 entries, texts over 500 characters are not stored, older entries are adopted once into an index, a lookup counts as use, and the Sign out button clears that account's entries.
Files: `Packages/Fit2216Core/Sources/Fit2216Core/Lru.swift`, `Tests/Fit2216CoreTests/LruTests.swift`, `Fit2216/Fit2216/App/AIClient.swift`, `Fit2216/Fit2216/App/AuthModel.swift`, `docs/FINDINGS.md` (F15), this log.
Tests actually run: core `swift test` on Linux, 133 passed (3 new); `swiftc -parse` on all app files, clean. NOT run: Xcode build, device test (UserDefaults behaviour itself is untested).
Unresolved risks: (1) app uncompiled by an agent; (2) clearing happens only on the Sign out button, not when Firebase ends a session; (3) the one-time adoption of old entries reads all UserDefaults keys once per account (small).
Decision flagged for the owner: clear-on-sign-out costs one repeat AI call per meal after signing back in; say if you would rather keep the cache across sign-outs.
Next suggested action: owner builds the branches on the Mac; Agent B can add a test case for risk (2). Agent A's claimed list (PRs #1, #3, #4, this one) is done; UX tasks (Summary "what now" card, Macros estimate review) need a separate approval.

### 2026-11-07 · Agent A · claim
Owner gave full approval ("I give full approval") for the remaining Agent A work. Re-read the log, `FINDINGS.md` and the PR list first: no merges since `daa235c`, only PR #2 (Codex release review, evidence only) from another agent. Claimed, each its own branch and pull request: (5) `agent-a/summary-now-card` (Summary "what now" guidance and one status banner, F12 part), then (6) `agent-a/macros-estimate-review` (review step before a meal is saved, F12 part). Still not claimed: web repo (Agent C), F5 (owner), deployments and configuration.

### 2026-11-07 · Agent A · handoff (task 5, branch `agent-a/summary-now-card`)
Work completed: (a) the Summary hero card now leads with what to do now (Ready when you are / Keep going / Done for today / Rest day / Skipped / Next up) with a one-line detail and a legend that says what the two rings measure. (b) The four separate top-of-screen banners (load failed, offline, change refused, still syncing) are replaced by one banner that shows only the most important notice, folding "N changes waiting to sync" into the offline line.
Files: core `Summary.swift` (`Summary.guidance`), new `StatusNotice.swift` (`Status.notice`), `Tests/.../StatusAndGuidanceTests.swift`; app `Summary/SummaryView.swift`, `App/AppGate.swift`; `docs/FINDINGS.md` (F12), this log.
Tests actually run: core `swift test` on Linux, 133 passed (3 new); `swiftc -parse` on all app files, clean. NOT run: Xcode build, device test; the rendered layout has not been seen by an agent.
Unresolved risks: (1) uncompiled app target; (2) the Summary headline text is new copy the owner may want to reword; (3) the Retry button on the offline notice also shows while the app is just refreshing from this phone's copy (same as before).
Next suggested action: owner builds on the Mac and screenshots Summary in three states (not started, finished, rest day) and the banner when offline. Next for Agent A: task 6, Macros estimate review.

### 2026-11-07 · Agent A · handoff (task 6, branch `agent-a/macros-estimate-review`)
Work completed: Add meal no longer saves the AI's answer straight away. A "Check estimate" sheet shows the estimate (labelled "Estimated by AI" or "From an earlier estimate or correction on this phone"), lets the person edit each food's name, calories, protein, carbs and fat, remove a food, and see the live total; Save meal / Update meal or Cancel (the sheet cannot be swiped away by accident). A correction is remembered for the same text, so the same words are not mis-estimated again. Saved values are cleaned first (core `Food.cleaned`: plausible ranges, rounding, names capped, empty foods dropped).
Files: core `FoodReview.swift` + `Tests/.../FoodReviewTests.swift`; app `Macros/MacrosModel.swift`, `Macros/MacrosView.swift`, new `Macros/EstimateReviewSheet.swift`; `docs/FINDINGS.md` (F12), this log.
Tests actually run: core `swift test` on Linux, 133 passed (3 new); `swiftc -parse` on all app files, clean. NOT run: Xcode build, device test; the sheet has not been rendered or used by an agent.
Unresolved risks: (1) uncompiled app target; (2) `TextField(value:format:)` with decimal pad: a half-typed number keeps the previous value until it parses, which should be tested by hand; (3) one more tap per meal (the price of the review); (4) portion sizes are not modelled.
Next suggested action: owner builds on the Mac and adds one real meal, then edits a number, saves, and types the same text again (should show the corrected amounts). Agent B: propose edge cases for the number fields.
Open Agent A work after this: none claimed. Candidates for the next approval: Insights one weekly conclusion (F12), import preview, accessibility pass (F13), all-time bests as a stored aggregate (F7 full fix).

### 2026-11-07 · Agent A · handoff (merges, done on the owner's instruction "Do it please")
Work completed: merged the open pull requests into `main` in this order: #2 (Codex release review), #1 (working agreement), #3 (F7), #4 (F8), #5 (F15), #6 (Summary guidance and one status banner), #7 (Macros estimate review, this entry rides in #7). Before each merge Agent A merged `main` into the branch, kept both sides of the log, resolved two real conflicts by hand (adjacent `FINDINGS.md` rows between #3 and #4; adjacent lines in `SummaryView.swift` between #3 and #6: both changes kept), re-ran the checks and pushed.
Tests actually run: after each branch update, core `swift test` on Linux: 133, 136, 139, 142, then 145 passed (0 failures); `swiftc -parse` on every app file, clean each time. CI check results on GitHub were not read before merging (mergeable state showed "unstable" while checks ran).
NOT run by any agent: an Xcode build or archive, a device test. `main` now holds unbuilt app changes from six pull requests (F7, F8, F15, Summary, Macros, plus Codex's docs); the owner must build `main` on the Mac before TestFlight. If the build fails, revert the failing PR (each merge commit is separate) and tell Agent A.
Statuses: F7, F8, F15 updated to "fixed, merged"; F12 partly; F5 now cites Codex's independent evidence. F1 to F4 were fixed earlier on `main` (commit `daa235c` and before) and are still unbuilt by agents too.
Unresolved risks: uncompiled app target; messy interactions between merged PRs are only syntax-checked (not type-checked) by an agent.
Next suggested action: owner commits `Fit2216.xcodeproj` (F5), fresh-clone builds `main`, and runs: sign in, log a set, finish a workout, add a meal and edit the estimate, offline banner, Insights bests. Then post results in the log (or tell Agent A).
Grok: Agent A saw no pull request or log entry from Grok at the time of merging. Under the agreement Grok should read the log and `FINDINGS.md`, then propose its role and wait for the owner's approval. Agent A suggests the unassigned scope (Agent C: the web repo `log2216`, after its PR #60) as the natural fit, so scopes do not overlap; the owner decides.

### 2026-11-07 · Agent A · handoff (web repo renamed to `log2216-api`)
What happened: the owner renamed the web repo `krishna5166/log2216` to `krishna5166/log2216-api` (GitHub redirects the old name). The Vercel project and `log2216.vercel.app` were not renamed, so the iPhone app is unaffected (read: `AppConfig.swift` points at the Vercel address, not GitHub). Checked just now, certain: `https://log2216.vercel.app/api/ai` answers 405 and the root shows the "has moved" page (this was before the rename took effect on any new deploy; the next deploy is the real test).
For Grok and Codex (action needed from the owner, not from the agents): tools scoped to the old name `krishna5166/log2216` will be denied under the new name until the repo is attached again. Agent A's session had to attach `krishna5166/log2216-api` (done, with the owner's confirmation). Branch names, PR numbers (#60 to #64) and history are unchanged. Web `main` is at `5072ab0` and contains PRs #60, #61, #62 and #64; PR #63 was left unmerged on purpose (Agent A advised holding it: it can refuse an estimate when the model leaves a macro blank, and the app's Check estimate sheet already lets the person fix numbers).
Work completed: web README and `docs/PLAN.md` note the rename (web PR, branch `main-qvqq4q`); this repo's `README.md` and `docs/AGENT_BRIEF.md` use the new name. Older log entries are left as written; they say `log2216`, which now redirects.
Tests actually run: none (documentation only). Vercel preview on the web PR was not read at the time of writing this entry.
Next suggested action: owner confirms the next Vercel deploy still happens (the web docs PR triggers a preview), then merges both docs PRs. Agent A will not rename or touch Vercel settings.
