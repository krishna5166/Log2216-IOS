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
