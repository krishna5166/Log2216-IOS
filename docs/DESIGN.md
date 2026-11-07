# Design decisions

Reference: Apple Fitness (workout screen and Summary). The app should feel like a training tool, not a form.

## Look
- **Dark only.** Black background, dark gray rounded cards (`secondarySystemBackground`, corner radius 22), applied app-wide in `Fit2216App`. Light mode was considered and dropped: the number colours and white-on-dark controls are tuned for black.
- **Palette** (`Theme.swift`): lime `#C7FF1A`-ish for primary actions and progress, pink for sets/calories, cyan for body/carbs, purple for fat, yellow for time, orange for warnings. Secondary text uses the system secondary (at least 60% white).
- **Big numbers.** Anything you read mid-workout or at a glance is a large rounded number with a small bold unit (`BigValue`): weight, reps, sets, calories, time.
- **One primary action per screen**, a full-width lime capsule (`limeCapsule`): Start, Log set, Done, Do this today.
- **Rings** for progress: two on Summary (sets today, workouts this week), four on Macros (calories, protein, carbs, fat).
- **Cards, not lists**, for the five main screens. Settings, Plan editor and the history screens stay as standard dark lists on purpose (it is how Apple styles them, and they are rarely opened).

## Summary and the streak (owner decisions, 2026-11-07)
- The rings card (rest day, rings, sets, week, streak, legend) was removed: the owner found it of no use. Summary starts with the title and, beside it, a **flame with the streak number**.
- **The streak counts weeks in a row in which every planned workout was done**, on any days and in any order: a week shifted by a day (Monday missed, plan finished Tuesday to Saturday) still counts. This week adds one when its last workout is done and, while it is still going, neither adds nor breaks anything. A finished week with a workout missing resets it to 0. A workout skipped on purpose counts as not done. Weeks are judged against the current plan. Rule: `Summary.weekStreak` in core, same test as the week strip uses (`weekLog` and `Plan.isComplete`).
- The older day-by-day `Summary.streak` and the `Summary.guidance` text are still in core, tested, but no longer shown.

## Workout screen
- All planned sets stacked vertically with numbered circles; the current set is open with big weight and reps and a Log set button, others are one line. Nothing is saved until Log set.
- Drafts are prefilled from the suggestion (last time, plus one step when ready) or the bottom of the rep range.
- A quiet trend sparkline (faint midline, light fill, no axes or numbers) shows whether today keeps the lift's trend going.
- Yellow elapsed timer top right; rest timer is a dark pill with yellow digits; Previous/Next pinned at the bottom.
- After the last set, the app moves to the next exercise (setting: "Next exercise after the last set"). Finishing shows a Workout complete summary: time, sets, total weight, personal bests.

## Behaviour decisions
- **No HealthKit workout session.** Apple Fitness owns the rings; ours are our own measures (sets, workouts).
- **No Circle.** The only social feature is copying a workout: Repeat today (from Past sessions), and Share workout / Import workout as plain text through the share sheet. It never overwrites a workout already logged for today's slot.
- **AI is opt-in per phone** and only used for Macros.
- **Insights is short by design for now.** Strength (blended, with a filter), body weight, consistency, balance flags, recent bests, food targets. Weekly recap, next-week suggestions, strength by muscle and workouts per week are hidden, not deleted (logic and tests remain), until the page is redesigned.
- **Accessibility:** set rows read as "Squat set 2 of 4, logged 80 kg for 5"; Dynamic Type is supported up to the accessibility 2 size, beyond which number layouts would break.
