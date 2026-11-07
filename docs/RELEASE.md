# Release runbook (TestFlight)

Bundle ID `com.mohankrishna.Fit2216`, team X4UN3W4A65. Distribution is invite-only through TestFlight (not listed).

## Every new build
1. `git pull` in `Log2216-IOS`. Never commit `GoogleService-Info.plist`.
2. Xcode: target Fit2216, General tab, **Build** must be higher than the last upload (Version stays 1.0 until a bigger change).
3. Run `swift test` in `Packages/Fit2216Core` (or check the Core tests badge on GitHub).
4. Run on your iPhone once and check: sign in, log a set, force-quit and reopen, Macros calculates, rest notification with the phone locked.
5. Product, Archive. Organizer, select the archive, Validate App (optional), then **Distribute App, App Store Connect, Upload**.
6. App Store Connect, My Apps, Fit2216, TestFlight, iOS builds: wait for Processing to finish (5 to 15 minutes). The group has automatic distribution, so testers get it in TestFlight.

## Settings that save a step
- Add build setting `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` so the export-compliance question is not asked every upload (the app only uses standard HTTPS).
- Warnings "Upload Symbols Failed" for Firebase frameworks are harmless.

## Xcode settings to check once (needs your Mac)
- **Portrait only:** target Fit2216, General, Deployment Info, tick only Portrait for iPhone (the layouts are built for portrait).
- **Encryption:** add `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` under Build Settings (search "Info.plist Values", or add a User-Defined setting).
- **Deployment target** iOS 17.6, **iPhone only**, display name Fit2216, Version 1.0.
- **Privacy manifest** (`PrivacyInfo.xcprivacy`) should show under the Fit2216 folder and be in the target's Copy Bundle Resources.
- **Live Activity (later):** File, New, Target, Widget Extension, tick Include Live Activity; then add `NSSupportsLiveActivities = YES` to the app's Info. Tell Claude when the target exists and the activity code can be written.

## Testers
- Internal testers must be App Store Connect users (Users and Access, role Marketing, access to Fit2216 only), then ticked in the TestFlight group.
- An invite is single-use and tied to the Apple Account that redeemed it. If someone uses the wrong one: remove the tester from the group and add them again (new invite).
- The AI proxy only accepts allowlisted accounts: add a new person's Firebase UID to `ALLOWED_UIDS` in Vercel and redeploy.

## Calendar
- Builds expire 90 days after upload: upload a fresh build before then.
- Keep a JSON backup (Settings, Backup) before any bulk change such as the exercise-name tidy.

## If something breaks
- Upload rejected for icon: the AppIcon needs a 1024x1024 PNG without transparency (done: `AppIcon.appiconset`).
- Build error about missing imports: with member-import visibility on, each file must import every module whose members it uses.
- Xcode edits `Package.swift` of `Fit2216Core` (a `// xcode:` line): `git restore` it before pulling.

## Production checklist
| Item | State |
|---|---|
| Core logic tested (130 tests, CI on every push) | done |
| Data safety: no writes before load, fresh read before logging, narrow profile writes, backups | done |
| Offline: opens from the phone's copy, unsent changes tracked and shown | done |
| Diagnostics screen and shareable report | done |
| Crash reports | automatic for TestFlight builds, in Xcode Organizer |
| Privacy manifest | done (update when data types or system APIs change) |
| App icon, export compliance answered | done (build setting for compliance: your Mac) |
| Portrait lock, encryption build setting | your Mac, see above |
| Live Activity for the rest timer | needs the Widget Extension target |
| Versioned AI API and repo rename | after PR #60 (web retirement) is merged |
