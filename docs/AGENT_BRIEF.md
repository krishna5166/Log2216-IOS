# Brief for a second agent (reviewer / helper)

## Project
Fit2216: a private two-person workout, body-weight and macros app. The web version (React + Firebase + Vercel) already works
(`github.com/krishna5166/log2216`). This repo (`github.com/krishna5166/Log2216-IOS`) is the native SwiftUI rebuild for iPhone. No Apple Watch app planned.

## Fixed decisions (do not reopen)
- Backend stays: Firebase Auth (email + password) and Firestore (same documents and rules as the web app) hold the data; a Vercel
  serverless endpoint `/api/ai` does the AI (keys stay on the server). The phone keeps a local copy and computes on-device.
- Firestore stays for sync between the two people, backup, and multiple devices.
- The iPhone is the only device that talks to Firestore.
- Logic lives in `Packages/Fit2216Core` (Foundation only, no UI or Firebase) so it stays shareable if a Watch app is ever added later.
- Distribution: unlisted App Store link for friends (not public search). TestFlight also available. No public App Store release planned.
- App name Fit2216; bundle ID `com.mohankrishna.Fit2216`.
- No HealthKit workout session. Apple Fitness (or another app) owns the rings. Fit2216 logs sets locally and optionally writes energy/strength samples to HealthKit as separate entries — no session, no ring fight.
- Circle tab is dropped entirely. The only social feature kept is copy-workout: copy an entire session from the other person's recent log into your own log. Accessible from the Plan tab or a share sheet on a logged session. No Circle members tab, no macro sync toggle, no circle requests.
- Strength tracking blends two metrics: total weekly volume (weight × reps) as the main signal, with estimated one-RM as a secondary reference. One-RM alone is too peak-focused; volume alone rewards junk volume.
- Insights page does NOT show individual per-lift graphs. Per-lift trend (sparkline) lives on the exercise's set page during a workout, so the user sees progressive overload at the moment of loading the bar.

## Navigation (iOS)
- **Summary** (landing tab): activity rings at the top (HealthKit read-only, or a custom SwiftUI approximation if HealthKit entitlement is not yet wired — see open items). Below the rings, today's session card: day name, target muscles, planned sets, sets-done vs planned, streak count. Fixed Start button anchored at the bottom of the screen above the tab bar (never scrolls off). Tapping the card opens the deeper progress view.
- **Workout** tab: the planned schedule — list of upcoming days with muscle focus, tap a day for the full session (exercises, sets, reps, weights).
- **Macros** tab: carried over from the PWA as-is; layout tweaks later. No "Add again" history chips (removed by request).
- **Insights** tab: overall strength progress graph as the headline. A dropdown filters the graph: Overall (default), Lower body, Upper body, Chest, Legs, and other muscle groups the core already categorizes. Each option plots that group's weekly blended metric (volume main line, one-RM secondary). Muscle groups below a minimum session count should be hidden or grayed out to avoid noisy lines. Also carries weekly recap, consistency grid, balance flags, PRs, and food-target chart from the PWA.
- Settings moves to a **profile icon** top-right (standard iOS pattern). Tab bar: Summary, Workout, Macros, Insights.

## State
`Fit2216Core` is at 115 tests. The Xcode app shell is built: Summary (hero card, up-next, week strip, body weight, recent best, pinned Start), Workout (list + day detail + start), full logging flow (steppers, set picker, rest timer, swap today/always, skip, finish, personal best banner, earlier sessions), Macros (AI parse, cards, draft saving, food memory, no add-again), Insights (weight chart with goal band, next-week suggestions, weekly recap, consistency grid, balance flags, strength by muscle, PRs, weekly bars, food-target chart, lift list), Plan editor, past sessions, settings with backup and CSV, sign-in with forgot password, cache-first loading, offline sync notices, midnight day rollover. Dark theme, Fitness-style visual pass, app icon for TestFlight. Claude's Workout redesign (dark background, big rounded weight/reps with minus-plus circles, lime Log set button, numbered set circles in a horizontal picker, yellow pill rest timer, Previous/Next bottom bar) is in place but not yet matching the target set-page design below.

Reference implementation of every rule: web code in `app/src/lib/*.ts` of the web repo, with its tests.

## Open items / next sprint (priority order)
1. **Copy-workout UI** — `WorkoutCopy` logic exists in core; no button or share-sheet entry point yet. Add even a single "Copy workout" action on Past Sessions or the Workout tab.
2. **HealthKit rings decision** — brief says read-only HealthKit rings on Summary; current build uses a custom SwiftUI approximation (sets-today, workouts-this-week). Either wire the real HealthKit API or rewrite this brief line to match the custom rings.
3. **Macros auto-retry on reconnect** — PWA re-submitted AI calls when the network returned; iOS currently waits for a manual Retry tap.
4. **Overall strength graph on Insights** — headline chart, dropdown filter: Overall (default), Lower body, Upper body, Chest, Legs, plus other core muscle groups. Blended metric: weekly volume as main line, estimated one-RM as secondary. Hide or gray out groups below a minimum session count.
5. **Per-lift sparkline on the set page** — during a workout, on each exercise's set screen, show that lift's one-RM trend as a compact sparkline so the user sees at a glance whether today's number is progressive or declining.
6. **Set-page redesign (Fitness lock-screen style)** — redesign the exercise set screen to match the Apple Fitness workout lock screen aesthetic:
   - Stacked set numbers vertically (numbered circles, one per planned set for that exercise — e.g. three squats show three numbered entries), not a horizontal scroller.
   - Big weight and reps display per set with minus/plus controls, matching the current dark-theme number style.
   - Thin one-RM sparkline for that lift across the bottom of the set area (no axes or labels — just the trend line).
   - Prominent overall session timer (elapsed time since workout start, yellow digits like Fitness's 60:35 counter).
   - Next button pinned at the bottom to advance to the following exercise; Previous available too.
   - Rest timer pill retained from the current redesign.
   Reference: Apple Fitness lock screen during a strength workout (active calories, total calories, heart rate, elapsed timer, set count).
7. Insights empty states for zero weights or zero logs.
8. README title still says "iPhone and Apple Watch" — minor cleanup.
9. AGENT_BRIEF state block must stay current as the app evolves.
10. Real-phone testing pass, then TestFlight to Sri, then unlisted listing.

## What you may do
- Read code and report problems. For each finding give file and line, a concrete input that triggers it, and what the user would see. Label every finding "read from code" or "ran it".
- Check the Swift port against the web logic for differences in behaviour (rounding, week boundaries, Monday vs Sunday, daylight saving, null handling).
- Suggest missing test cases (give the input and the expected output).
- Answer Xcode, signing, TestFlight, Firebase-on-iOS and HealthKit questions.
- Write requirements as "when I do X, I expect Y".

## What you must not do
- Do not push to `main` or change files without being asked. Propose changes as a patch or a branch and a pull request.
- Do not commit secrets: `GoogleService-Info.plist`, API keys, tokens, signing files, passwords.
- Do not propose new features, new screens or new dependencies unless asked.
- Do not claim you ran or built something you did not. You cannot run the iOS app on a phone.
- If unsure, say "not sure" instead of guessing. If you find nothing, say "nothing found".

## How to report
One list, most serious first. Each item: title, file:line, trigger, visible result, suggested fix, confidence (certain / likely / not sure).
Whoever owns the change (the primary agent) verifies each finding against the code before acting.
