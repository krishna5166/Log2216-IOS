# Fit2216 for iPhone and Apple Watch

Native (SwiftUI) rebuild of the Fit2216 web app (Couple Fit) (`krishna5166/log2216`). The backend does not change: Firebase Auth and
Firestore hold the data and rules, and the Vercel `/api/ai` server does the AI. This app and the web app read and write the
same documents, so history carries over and both can be used side by side while this one is built.

## What is here
- `Packages/Fit2216Core`: platform-neutral Swift package (Foundation only, no UI or Firebase). The rules shared by the iPhone and
  watch apps: models that repair bad data while decoding, units, dates (Monday-first weeks), which workout is due, done / missed,
  muscle guessing, rest and set helpers. Ported from `app/src/lib/*.ts` in the web repo with the same test cases.

## Run the tests
In Xcode: File → Open → `Packages/Fit2216Core`, then Product → Test (⌘U). From a terminal: `cd Packages/Fit2216Core && swift test`.

## Roadmap (see docs/AGENT_BRIEF.md for the decisions behind it)
1. Core logic package: models, units, dates, plan, muscles, insights and goal projection. **Done** (50 tests).
2. Core, continued: spreadsheet (CSV) import/export, copy-workout from the other person's log.
3. iPhone app shell: sign-in, load the plan, tab bar (Summary, Workout, Macros, Insights), profile icon for Settings.
4. Summary: HealthKit rings (read-only), today's session card with target muscles, sets done vs planned and streak, fixed Start button.
5. Logging: exercise screen, rest timer as a local notification, Previous and the jump list.
6. Macros and Insights screens, rebuilt in SwiftUI from the web app.
7. Optional HealthKit samples (separate entries, no workout session).
No Apple Watch app and no Circle tab. Distribution: unlisted App Store link, TestFlight also available.

## Rules
- Never commit `GoogleService-Info.plist`, keys or signing files (the `.gitignore` blocks them).
- Keep the Swift rules in step with the web app's (`muscles`, `plan`): a rule change should land in both.
