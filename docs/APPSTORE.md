# App Store launch pack (unlisted link)

Decisions made by the owner (2026-11-07): **unlisted distribution** (only people with the link), **no in-app account deletion** for now, **EU excluded**. The app has no public sign-up: accounts are created by the owner in Firebase.

Nothing here has been submitted. Items marked **(owner)** can only be done by the account holder. Wording below is a draft to change freely; check every App Store Connect answer against what is true when you submit.

## Order of work
1. **Verify the build on a phone** (`docs/VERIFY.md`, rows 1 to 12) and commit `Fit2216.xcodeproj` so a fresh clone builds (finding F5).
2. **Publish the privacy and support pages** (web repo `log2216-api`, `app/retired/privacy` and `support`; needs the contact email, see below). Check `https://log2216.vercel.app/privacy` and `/support` open.
3. **Reviewer account (owner):** Firebase console, Authentication, add a user (for example `reviewer@...` with a password you choose). Copy its UID into the `ALLOWED_UIDS` list in Vercel (Project Settings, Environment Variables) and redeploy, so Macros works for the reviewer. Add a few sample workouts and weights to it so the screens are not empty.
4. **Build settings (owner, Xcode):** `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`, portrait only (see `docs/RELEASE.md`). Raise Build above the last upload (version 1.0).
5. **App Store Connect (owner):** open the app record. Remove the stray macOS platform (Fit2216 was first created as macOS). Fill the sections below. Under Pricing and Availability: price Free; countries: all except the EU member states (this skips the EU trader declaration; if App Store Connect still asks, answer it truthfully).
6. **Archive and upload** the new build (`docs/RELEASE.md`), select it under the 1.0 version, add the review notes below, **Submit for Review**.
7. **Unlisted request (owner):** Apple says the app must be ready for final distribution and already submitted to App Review before you ask. File the request at `https://developer.apple.com/contact/request/unlisted-app` (the account holder only). Apple may take a day or more to answer; the app still goes through App Review. After approval the link is under General, Pricing and Availability, App Distribution Methods ([Apple](https://developer.apple.com/support/unlisted-app-distribution)).
8. Give Sreeja and friends the link; they install like any App Store app. TestFlight is no longer needed for them.

## Listing text (draft)
- **Name:** Fit2216
- **Subtitle (30 characters max):** Workouts, weight and meals
- **Category:** Health & Fitness
- **Promotional text:** Log every set, see your strength trend, and keep an eye on calories.
- **Description:**
  Fit2216 is a small, private training log.
  - Follow your weekly plan and log each set with big, easy numbers, a rest timer and suggestions from your last session.
  - See where you are today: sets done, workouts this week, your streak.
  - Track body weight against your goal.
  - Optional: describe a meal in plain words and get an estimate of calories and macros that you can check and correct before saving. This uses an AI service and is off until you allow it.
  - See strength trends, personal bests and a consistency calendar.
  Your data lives in your own account and syncs between your devices. No ads. No tracking.
  Calorie and macro numbers are estimates, not medical advice.
- **Keywords (100 characters max):** workout,strength,gym,lifting,sets,reps,weight,macros,calories,training,log
- **What's new (first version):** First release.
- **Support URL:** `https://log2216.vercel.app/support`
- **Privacy policy URL:** `https://log2216.vercel.app/privacy`

## App Privacy answers (suggested; you answer the form)
Tracking: **No**. The app does not track people and uses no analytics or advertising SDK (it uses Firebase Authentication and Firestore only).

| Data type in App Store Connect | Collected | Linked to the person | Used for tracking | Purpose |
|---|---|---|---|---|
| Contact Info, Email Address | Yes (sign-in) | Yes | No | App functionality |
| Health & Fitness, Health (body weight and measurements entered) | Yes | Yes | No | App functionality |
| Health & Fitness, Fitness (workouts, sets) | Yes | Yes | No | App functionality |
| User Content, Other User Content (meal text and estimates) | Yes | Yes | No | App functionality |
| Identifiers, User ID (the sign-in ID) | Yes | Yes | No | App functionality |

Meal text is also sent to an AI service (Google Gemini; Groq or NVIDIA as fallbacks) through the developer's server, only after the person allows "AI calculation". Say so in the policy (it is in the draft policy) and in the review notes. `Fit2216/Fit2216/PrivacyInfo.xcprivacy` declares the same five data types.

## Age rating (suggested answers, you answer the form)
None of: violence, sexual content, profanity, horror, gambling, alcohol or drugs, contests, unrestricted web access, user-generated content shared with others, or in-app purchases. Medical or treatment information: none (nutrition numbers are estimates, with a "not medical advice" line). Expected result: 4+. Confirm in the form.

## Review notes (paste into App Review Information)
```
This is a private training log. There is no public sign-up: accounts are created by the developer, so account deletion inside the app does not apply (no in-app account creation).

Sign-in for review (Sign-in required):
  Email: <reviewer email>
  Password: <reviewer password>

The app is intended for unlisted distribution (link only) to a small group of people the developer knows.

Optional feature: Macros, "AI calculation". It is off by default. When the person allows it, the text of a meal they type is sent through the developer's server to an AI service (Google Gemini; Groq or NVIDIA if Gemini is busy) to estimate calories and macros, and the person can check and edit the estimate before it is saved. Nothing else is sent. The reviewer account is allowed to use it.

No in-app purchases, no ads, no tracking. Nutrition values are estimates, not medical advice.
```

## Screenshots (owner)
Take them on your iPhone with the **reviewer** account (so no personal data shows): side button plus volume up. Suggested five, in this order: Summary, a set page mid-workout, Workout complete, Macros rings, Insights strength. App Store Connect shows the exact pixel sizes it accepts for the iPhone size class when you upload; the largest iPhone class is enough, Apple scales for the rest. Do not use a Simulator unless you have to.

## Risks to know
- Apple may reject on first review for missing information (one developer reported guideline 2.1 for an unlisted app); the answer is usually to supply the review notes and demo account above ([BuddyBoss guide](https://buddyboss.com/docs/how-to-publish-an-unlisted-app-to-the-apple-app-store/)).
- Apple's rule on sharing personal data with third-party AI needs explicit permission and a matching policy ([TechCrunch](https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai)). The app asks first (default off, with an Allow dialog naming the providers).
- The app has never been verified end to end on a phone by an agent; do step 1 first.
- Every statement in the privacy policy must stay true; if the server changes AI provider, change the policy and the in-app wording together (`AIConsentText`).
