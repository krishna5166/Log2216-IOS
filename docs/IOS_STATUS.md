# Fit2216 for iPhone: where it stands

Native SwiftUI app on the same backend as the web app (Firebase Auth + Firestore, Vercel `/api/ai`). Both apps read and write the same documents.

## Setup that only you can do
1. `Fit2216/Fit2216/App/AppConfig.swift`: set `apiBaseURLString` to your Vercel address (for example `https://your-app.vercel.app`). Without it, Macros says the server address is not set.
2. `GoogleService-Info.plist` goes in `Fit2216/Fit2216/` and is never committed (`.gitignore`).
3. Commit `Fit2216.xcodeproj` after adding or changing packages in Xcode.

## Parity with the web app
| Area | iPhone |
|---|---|
| Sign-in (email + password, stays signed in) | done |
| Summary: today + what is left, week strip, streak, body weight + goal projection, recent best | done |
| Workout: week list, start any day | done |
| Logging: one exercise at a time, steppers, suggestions, native rest timer + notification, Previous/Next/jump list, finish | done |
| Swap exercise (today only / always), skip workout, finish from menu | done |
| Past sessions: edit sets, relabel unit, delete | done |
| Plan editor: days, exercises, reps, rest, optional, alternatives, muscles, reorder | done |
| Weigh-ins: log, history, delete | done |
| Insights: weight chart with goal band + pace stub, strength by muscle, lifts, balance, next-week suggestions, recap, consistency calendar, weekly workouts, food targets | done |
| Macros: AI estimate, entries, edit/remove, targets, completion % | done (no "add again" history chips, by request) |
| Body and targets (About me), units, haptics | done |
| Backup (.json) export/restore, spreadsheet (.csv) export/import | done |
| Dark mode | follows the phone |

## Deliberately not ported
- Circle, macro sync, copy a member's workout/plan (dropped in the plan; needs the Circle link).
- Smart notes and AI swap ideas (removed from the web app on purpose).
- Plan templates (save/load); use backup, or the starter plan for an empty plan.
- Scroll-wheel entry mode, rest sound choice, theme setting, Diagnostics screen, PWA install/update banners.

## Notes
- The Macros diary lives in Firestore (`users/{uid}/foodDays/{date}`), so it syncs between devices. The web app kept its diary on the device only, so the iPhone diary starts empty.
- Logic lives in `Packages/Fit2216Core` (Foundation only) with the same rules and test cases as the web app. `swift test` there.
- Apple Health is not connected (decision: Apple Fitness owns the rings).

## Review notes (what a deep pass against the web app found and fixed)
- Data safety: nothing is written before your data has loaded (logging, Macros); a workout is read fresh from the server when opened, so one started on the web app is continued, not overwritten; profile writes touch only the fields that changed; the exercise library only grows; weekday and set counts from bad data are clamped or dropped.
- Offline: opens from the phone's own copy first, then refreshes; a notice shows when changes are waiting to sync or were refused.
- Parity added after the review: personal-best banner, earlier sessions list, numeric input cleanup, Next up after finishing, edit a finished workout from Review progress, global rest timer bar, forgot password, Done button above number keypads, midnight rollover.
- Known gaps / suggestions: cursor auto-advance to the next set, wheel entry, a Live Activity for the rest timer, Dynamic Type at the largest sizes, copy-workout between accounts (needs the Circle link), Apple Health.
