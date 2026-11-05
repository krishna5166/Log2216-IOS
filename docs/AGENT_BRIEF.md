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

## Navigation (iOS)
- **Summary** (landing tab): HealthKit activity rings rendered at the top (read-only, Apple's ring style — cannot customize). Below the rings, today's session card: day name, target muscles, planned sets, sets-done vs planned, streak count. Fixed Start button anchored at the bottom of the screen above the tab bar (never scrolls off). Tapping the card opens the deeper progress view (weekly volume charts, PR history, muscle balance).
- **Workout** tab: the planned schedule — list of upcoming days with muscle focus, tap a day for the full session (exercises, sets, reps, weights).
- **Macros** tab: carried over from the PWA as-is; layout tweaks later.
- **Insights** tab: carried over from the PWA as-is; same charts and muscle analysis, rebuilt in SwiftUI.
- Settings moves to a **profile icon** top-right (standard iOS pattern), freeing the tab bar for the four content tabs above. Wait — with Circle dropped, the tab bar is Summary, Workout, Macros, Insights. Profile icon top-right for settings.

## State
Done in `Fit2216Core` (50 tests, all passing; `swift test` in `Packages/Fit2216Core`): models that repair bad data while decoding, units, dates (Monday-first weeks),
which workout is due / done / missed, muscle guessing, insights and goal projection.
Next: CSV import/export, then the Xcode app (sign-in, Summary, Workout, logging, rest timer). Macros and Insights screens come after the core app loop works.
The reference implementation of every rule is the web code in `app/src/lib/*.ts` of the web repo, with its tests.

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
