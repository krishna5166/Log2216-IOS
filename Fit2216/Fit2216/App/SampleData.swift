import Foundation
import Fit2216Core

/// A plan shaped like the real one, so the screens have something to show before sign-in and Firestore exist.
enum SampleData {
    private static func ex(_ name: String, _ sets: Int, _ reps: String) -> TemplateExercise {
        TemplateExercise(name: name, sets: sets, reps: reps)
    }

    static let plan: [TemplateDay] = [
        TemplateDay(day: 1, name: "Legs A", type: .strength, notes: "Heavy.", exercises: [
            ex("Barbell squats", 4, "4–6"), ex("Romanian deadlift", 3, "6–8"), ex("Hamstring curls", 3, "10–12"), ex("Standing calf raises", 3, "10–15"),
        ]),
        TemplateDay(day: 2, name: "Chest and triceps", type: .strength, exercises: [
            ex("Flat barbell bench press", 4, "4–6"), ex("Incline dumbbell press", 3, "6–10"), ex("High-to-low cable fly", 3, "12–15"),
            ex("Overhead cable triceps extension", 3, "10–12"), ex("V-bar triceps pushdowns", 3, "10–15"),
        ]),
        TemplateDay(day: 3, name: "Back and biceps", type: .strength, exercises: [
            ex("Lat pulldown", 4, "6–10"), ex("Seated cable row", 3, "6–10"), ex("Straight-arm pulldown", 3, "12–15"),
            ex("Face pulls", 2, "15"), ex("Dumbbell biceps curls", 3, "8–12"), ex("Hammer curls", 3, "10–12"),
        ]),
        TemplateDay(day: 4, name: "Shoulders and abs", type: .strength, exercises: [
            ex("Machine shoulder press", 4, "6–10"), ex("Machine lateral raises", 4, "12–15"), ex("Rear-delt cable pulls", 3, "12–15"),
            ex("Shrugs", 3, "10–12"), ex("Machine abdominal crunches", 3, "10–15"), ex("Torso Rotator Machine", 2, "10–15/side"),
        ]),
        TemplateDay(day: 5, name: "Legs B", type: .strength, notes: "No heavy squat.", exercises: [
            ex("Hip thrust", 3, "8–12"), ex("Leg press", 3, "10–15"), ex("Leg extensions", 3, "12–15"),
            ex("Hip abductor (outside)", 2, "12–15"), ex("Hip adductor (inside)", 2, "12–15"), ex("Seated calf raises", 3, "12–15"),
        ]),
        TemplateDay(day: 6, name: "Rest", type: .rest),
        TemplateDay(day: 0, name: "Hike", type: .rest),
    ]

    /// Finished workouts for the training days of this week that are already behind us, so the streak has something to count.
    static func logsThisWeek(plan: [TemplateDay], now: Date = Date()) -> [WorkoutLog] {
        let cal = Calendar.current
        let today = Dates.localDate(now, cal)
        var out: [WorkoutLog] = []
        for date in Dates.weekDates(now, cal) {
            let key = Dates.localDate(date, cal)
            guard key < today, let day = plan.first(where: { $0.day == Dates.weekday(date, cal) }), day.type != .rest else { continue }
            out.append(WorkoutLog(date: key, dayName: day.name, dayIndex: day.day, done: true))
        }
        return out
    }
}
