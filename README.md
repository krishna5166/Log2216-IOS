# Fit2216 for iPhone

Native (SwiftUI) rebuild of the Fit2216 web app (Couple Fit) (`krishna5166/log2216-api`, formerly `krishna5166/log2216`). The backend does not change: Firebase Auth and
Firestore hold the data and rules, and the Vercel `/api/ai` server does the AI. This app and the web app read and write the
same documents, so history carries over and both can be used side by side while this one is built.

## What is here
- `Packages/Fit2216Core`: platform-neutral Swift package (Foundation only, no UI or Firebase). The rules shared by the iPhone and
  watch apps: models that repair bad data while decoding, units, dates (Monday-first weeks), which workout is due, done / missed,
  muscle guessing, rest and set helpers. Ported from `app/src/lib/*.ts` in the web repo with the same test cases.

## Run the tests
In Xcode: File → Open → `Packages/Fit2216Core`, then Product → Test (⌘U). From a terminal: `cd Packages/Fit2216Core && swift test`.

## Status
The iPhone app now covers the web app's features (see `docs/IOS_STATUS.md` for the table, what is deliberately left out, and the setup only you can do).
Next: your review on a real phone, then Sreeja's phone (TestFlight or unlisted link), then two weeks side by side before the PWA is frozen.

## Rules
- Never commit `GoogleService-Info.plist`, keys or signing files (the `.gitignore` blocks them).
- Keep the Swift rules in step with the web app's (`muscles`, `plan`): a rule change should land in both.
