# Verification record (Mac and iPhone)

Nothing in the app has been built or run by an agent: only the core package is tested (on Linux) and the app files are syntax-checked. This page is what a person does on the Mac and the iPhone to turn "written" into "verified". Fill in the tables and post the result as a log entry (format at the end) so all agents see what was actually tested.

## Record
| Item | Value |
|---|---|
| Date and tester | |
| Commit tested (`git rev-parse --short HEAD`) | |
| Xcode version | |
| iPhone model and iOS version | |
| Build number on the phone (Settings, bottom, or Diagnostics) | |
| Packages resolved (Firebase version from Xcode, Package Dependencies) | |

## Part A: build from a fresh clone (F5)
1. In a new empty folder: `git clone https://github.com/krishna5166/Log2216-IOS.git` and check out `main`.
2. Copy your `GoogleService-Info.plist` into `Fit2216/Fit2216/` (it is ignored by git; never commit it).
3. Open `Fit2216/Fit2216.xcodeproj`. Wait for packages to resolve. If Xcode says Firebase or another package is missing, the project file in git is incomplete: add the Firebase packages (FirebaseAuth, FirebaseFirestore), then commit `Fit2216.xcodeproj` and the package resolution file through a pull request.
4. Product, Build (iPhone selected). Then Product, Archive.
5. Write down: build result, number of errors, the first error text if any.

| Step | Result (pass / fail, and the error text) |
|---|---|
| Fresh clone builds | |
| Archive succeeds | |

## Part B: on the iPhone
Use a real account with a little data. "Expected" is what the code is written to do, not something already seen working.

| # | Do this | Expected | Covers | Result |
|---|---|---|---|---|
| 1 | Sign in, force-quit, reopen | Still signed in, data shows at once | basics | |
| 2 | Open a workout, log a set, force-quit, reopen | The set is still there; Past sessions lists it | data safety | |
| 3 | Log the last set of an exercise | After about a second it moves to the next exercise (turn off in Settings, While logging) | auto-advance | |
| 4 | Finish a workout | "Workout complete" with time, sets, total weight; Done closes it | summary | |
| 5 | Summary in three states: not started, partly done, finished (or a rest day) | Headline changes (Ready when you are, Keep going, Done for today / Rest day); legend under the rings | F12 | |
| 6 | Airplane mode on, log a set, wait 5 s | One banner at the top, not several; it mentions changes waiting to sync | F12, F3 | |
| 7 | Airplane mode off | Banner clears; Settings, Data, Diagnostics shows 0 unsent | sync | |
| 8 | Macros: turn on AI calculation, add a meal | "Check estimate" sheet opens with the foods, labelled "Estimated by AI" | F12 | |
| 9 | Change a calorie number, Save meal; add the same text again | Card shows your number; the sheet now says "From an earlier estimate or correction" with your number | F12 | |
| 10 | Add a meal, tap Cancel on the sheet | Nothing saved; the text stays in the box | F12 | |
| 11 | Macros with airplane mode on, then off | Says it could not calculate; when the connection returns the Check estimate sheet appears by itself | auto-retry | |
| 12 | Settings, Data, Diagnostics, Check the server | "HTTP 405" (the server is reachable and wants POST) | F10 | |
| 13 | Settings, Backup, Prepare backup, then Restore from backup (same account) | "Sending to the cloud…", then "Backup restore finished: N items saved" | F2 | |
| 14 | Settings, Spreadsheet: prepare, import it back | Accepted | F8 | |
| 15 | Edit one weight cell of that spreadsheet to `abc`, import | Refused, message names the row and the cell | F8 | |
| 16 | Sign out, sign in, add the same meal text as step 9 | It is estimated again (the food cache is cleared on sign-out) | F15 | |
| 17 | Sign in as account A, tap Sign out within two seconds, sign in as account B | B sees only B's plan and workouts; Diagnostics shows B's email | F1 | |
| 18 | Past sessions, open a workout, menu, Repeat today | A copy opens with no sets; refused if today already has a logged workout | copy | |
| 19 | Past sessions, open a workout, menu, Share workout; Workout tab, import icon, paste | Preview shows the exercises; Do this today opens it | copy | |
| 20 | Settings, Data, Check exercise names (after a backup) | Lists split names, or says they match; Tidy asks first | tidy | |
| 21 | Insights: Strength card filter menu | Overall, Lower body, Upper body and muscles; groups with few sessions are greyed | F12 | |
| 22 | Start a rest timer and lock the phone | A notification arrives when rest ends | notification | |
| 23 | VoiceOver on: Summary, a set page, Macros, Insights | Rings read as one sentence; chart and trend say up, down or steady; rest timer says seconds left | F13 | |
| 24 | Settings, Accessibility, Larger Text (large); Reduce Motion on | Big numbers stay inside their cards; rings fill without animation | F13 | |

## Part C: report
Post one entry in `docs/AGENT_LOG.md` (through a pull request, or give it to Agent A):

```
### YYYY-MM-DD · Owner · verification
Commit tested: <hash>. Xcode <version>. iPhone <model>, iOS <version>, build <n>.
Fresh clone build: pass/fail <first error>. Archive: pass/fail.
Phone checks passed: <numbers>. Failed: <numbers and what you saw>. Not tried: <numbers>.
```

Agent A then updates `FINDINGS.md` from the result: a finding is only marked verified when its row here passed on a device.
