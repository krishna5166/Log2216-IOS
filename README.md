# Couple Fit for iPhone and Apple Watch

Native (SwiftUI) rebuild of the Couple Fit web app (`krishna5166/log2216`). The backend does not change: Firebase Auth and
Firestore hold the data and rules, and the Vercel `/api/ai` server does the AI. This app and the web app read and write the
same documents, so history carries over and both can be used side by side while this one is built.

## What is here
- `Packages/CoupleFitCore`: platform-neutral Swift package (Foundation only, no UI or Firebase). The rules shared by the iPhone and
  watch apps: models that repair bad data while decoding, units, dates (Monday-first weeks), which workout is due, done / missed,
  muscle guessing, rest and set helpers. Ported from `app/src/lib/*.ts` in the web repo with the same test cases.

## Run the tests
In Xcode: File → Open → `Packages/CoupleFitCore`, then Product → Test (⌘U). From a terminal: `cd Packages/CoupleFitCore && swift test`.

## Roadmap
1. Core logic package (this commit): models, units, dates, plan, muscles.
2. Core, continued: insights and goal projection, spreadsheet (CSV) import/export.
3. iPhone shell: sign-in, load the plan, Home (body figure, day strip, Start).
4. iPhone logging: exercise screen, rest timer as a local notification, Previous and the jump list.
5. Apple Watch: today's exercises, set entry with the Digital Crown, rest-timer haptic, sets sent to the phone (the phone is the only device that talks to Firestore).
6. Remaining screens (Macros, Insights, Circle, Settings), Apple Health weight.

## Rules
- Never commit `GoogleService-Info.plist`, keys or signing files (the `.gitignore` blocks them).
- Keep the Swift rules in step with the web app's (`muscles`, `plan`): a rule change should land in both.
