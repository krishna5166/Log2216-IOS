import SwiftUI
import Observation
import UIKit
import Fit2216Core

/// One workout being logged: holds the log, which exercise is open, and saves every change.
@Observable
final class LoggingSession {
    private(set) var log: WorkoutLog
    private(set) var day: TemplateDay
    let history: [WorkoutLog]
    let unit: WeightUnit
    var index: Int
    /// Each lift's earlier sessions (workouts before today), computed once: used to spot a new personal best.
    let lifts: [String: [LiftPoint]]

    @ObservationIgnored private let timer: RestTimer
    @ObservationIgnored private let onSave: (WorkoutLog) -> Void

    init(day: TemplateDay, log: WorkoutLog, history: [WorkoutLog], timer: RestTimer, onSave: @escaping (WorkoutLog) -> Void) {
        self.day = day
        self.log = log
        self.history = history
        self.unit = Units.logUnit(log)
        self.timer = timer
        self.onSave = onSave
        self.index = Logging.firstOpenIndex(day: day, log: log)
        self.lifts = Insights.liftHistory(history.filter { $0.date < log.date })
    }

    var exercise: TemplateExercise { day.exercises[index] }
    var shownName: String { Plan.effectiveName(log, exercise.name) }
    var loggedCount: Int { Logging.setsLogged(log, exercise: exercise.name) }
    var isLast: Bool { index == day.exercises.count - 1 }
    var lastTime: (date: String, sets: [SetLog])? { Logging.lastTime(name: shownName, history: history, before: log.date, unit: unit) }

    /// A set today that beat every earlier session of this lift.
    var personalBest: PersonalBest? { PersonalBests.best(history: lifts[shownName], sets: log.sets[exercise.name] ?? [], unit: unit) }

    /// The sessions before the last one (up to two more), for the "earlier sessions" list.
    var earlier: [(date: String, sets: [SetLog])] {
        Array(Plan.recentSessions(history, name: shownName, before: log.date, unit: unit, count: 3).dropFirst())
    }

    var canFinish: Bool { Logging.canFinish(log) }

    func rows() -> [SetLog] { Logging.rows(log, exercise: exercise) }

    func hint(for i: Int) -> SetLog? {
        Logging.suggestion(exercise: exercise, shownName: shownName, index: i, log: log, history: history, unit: unit)
    }

    func set(_ i: Int, weight: String? = nil, reps: String? = nil) {
        let before = log
        log = Logging.setting(log, exercise: exercise.name, index: i, weight: weight, reps: reps)
        onSave(log)
        if Logging.shouldStartRest(before: before, after: log, exercise: exercise, index: i, day: day) {
            timer.start(seconds: Plan.restSeconds(exercise))
            Haptics.light()
        }
    }

    /// Today only: the plan is untouched and the swap lives on this workout's log.
    func swapToday(to name: String) {
        log = Logging.swapped(log, original: exercise.name, to: name)
        onSave(log)
    }

    /// For good: renames the exercise in the plan day and moves today's sets with it. Returns the changed day so the plan can be saved, or nil if the name is empty or already used.
    func swapAlways(to name: String) -> TemplateDay? {
        let old = exercise.name
        guard let renamed = Logging.renamingExercise(day, from: old, to: name) else { return nil }
        day = renamed
        log = Logging.movingSets(log, from: old, to: renamed.exercises[index].name)
        onSave(log)
        return renamed
    }

    var readyToIncrease: Bool { Plan.readyToIncrease(exercise, lastTime?.sets) }
    var isSwapped: Bool { shownName != exercise.name }
    var isCopiedTemplate: Bool { log.template != nil }

    func skipWorkout() {
        log = Logging.skipped(log)
        onSave(log)
        timer.stop()
    }

    /// Marks the workout done. A workout with nothing logged is left as it is.
    func finish() {
        guard Logging.canFinish(log) else { timer.stop(); return }
        log = Logging.finished(log)
        onSave(log)
        timer.stop()
        Haptics.success()
    }

    func exerciseProgress(_ e: TemplateExercise) -> Int { Logging.setsLogged(log, exercise: e.name) }
}
