# Architecture

Two people, one Firebase project, one native app. Keep it small: no server of our own except the AI proxy.

## Layers
```
Views (SwiftUI)  ->  App models (@Observable)  ->  FirestoreService / AIClient  ->  Firebase, Vercel
                              |
                       Fit2216Core (pure logic, Foundation only)
```
- **`Packages/Fit2216Core`**: every rule that could be wrong lives here and is tested (`swift test`, also run by CI on Linux): plan and week logic, logging rules, rest and suggestions, personal bests, strength series, nutrition targets and food totals, backup/CSV validation, exercise-name tidying, workout copy/share. No UI, no Firebase, no clock reads except where `now` is passed in. If a Watch app or widget ever happens, it imports this package.
- **App models** (`Fit2216/Fit2216/App`): `AuthModel` (sign-in state), `AppModel` (plan, logs, weights, profile, load phase, write tracking), `MacrosModel` (today's food, AI submit, auto-retry), `LoggingSession` (one workout being logged), `RestTimer`. Views read these; nothing else holds app state.
- **Services**: `FirestoreService` (reads, and writes that return immediately and are tracked) and `AIClient` (one POST to `/api/ai`).
- **Views**: one folder per tab (`Summary`, `Workout`, `Logging`, `Macros`, `Insights`) plus `PlanEditor`, `History`, `Body`, `Settings`, `Charts`, `Common` (theme, format, haptics).

## Data (Firestore, owner-only rules)
| Path | Holds |
|---|---|
| `users/{uid}` | `plan`, `library` (exercise names ever used), `profile`, `templates` |
| `users/{uid}/logs/{date_dayIndex}` | one workout: `sets` keyed by plan exercise name, `swaps`, `template` (a copied workout), `unit`, `done`, `skipped` |
| `users/{uid}/weights/{date}` | one weigh-in (kg) |
| `users/{uid}/foodDays/{date}` | food cards, unsent draft, completion % (only once there is a meal) |

Rules: `firestore.rules` in the web repo (owner-only wildcard covers new subcollections). Weights are stored in kg, sets in the unit stored on the log.

## Principles that shape the code
1. **Nothing is written before data has loaded.** Logging and Macros wait for the first read so an empty copy can never overwrite a real day.
2. **Open from the phone's copy, refresh behind it.** Firestore offline persistence plus a cache-first load; writes return at once and are tracked (`unsent`, `writeProblem`, `slowSync` notices).
3. **Read leniently, write narrowly.** Decoding repairs bad data (`LossyArray`, `Skip`, `JSONValue`); profile writes touch only changed fields.
4. **One source for derived numbers.** The blended strength series (volume 70%, estimated max 30%) is computed once in core and feeds both the Insights graph and the set-page sparkline.
5. **History is keyed by exercise name**, tidied and alias-mapped (`ExerciseNames`). Drift (one exercise under several spellings) is detected at launch (card on Summary) and can be tidied on request (Settings, Data). Stable exercise IDs were considered and deferred: not needed for two users, and a data-model change is bigger than the problem.

## Backend contract (AI proxy)
`POST {base}/api/ai`, header `Authorization: Bearer <Firebase ID token>`, body `{"task":"macros","data":{"text":"..."}}`, reply `{"meals":[{"name","kcal","protein","carbs","fat"}]}`. The server verifies the token, checks `ALLOWED_UIDS`, and tries Gemini, then Groq, then NVIDIA. Keys never reach the phone. The web repo owns this function; the app only knows the URL in `AppConfig.swift`.

## Local settings (UserDefaults)
`haptics`, `smartNotes` (AI calculation consent, per phone, default off), `autoAdvance`. Food memory (text to meals) is cached per user to avoid repeat AI calls.

## Testing and checks
- Core: `swift test` (130 tests). CI: `.github/workflows/core-tests.yml`.
- App: build and run in Xcode; the screens are not covered by automated UI tests.
- Data safety nets: Settings backup (.json) and spreadsheet (.csv) export/import with validation.

## Known limits
- The elapsed workout timer counts from when the workout screen opened (no stored start time on the log).
- Live Activity for the rest timer needs a Widget Extension target created in Xcode (not done).
- TestFlight builds expire after 90 days; upload a new build before then.
