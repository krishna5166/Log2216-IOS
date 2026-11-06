import SwiftUI
import Observation
import UIKit
import Fit2216Core

/// One workout being logged: holds the log, which exercise is open, and saves every change.
@Observable
final class LoggingSession {
    private(set) var log: WorkoutLog
    let day: TemplateDay
    let history: [WorkoutLog]
    let unit: WeightUnit
    var index: Int

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
    }

    var exercise: TemplateExercise { day.exercises[index] }
    var shownName: String { Plan.effectiveName(log, exercise.name) }
    var loggedCount: Int { Logging.setsLogged(log, exercise: exercise.name) }
    var isLast: Bool { index == day.exercises.count - 1 }
    var lastTime: (date: String, sets: [SetLog])? { Logging.lastTime(name: shownName, history: history, before: log.date, unit: unit) }

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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func finish() {
        log = Logging.finished(log)
        onSave(log)
        timer.stop()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func exerciseProgress(_ e: TemplateExercise) -> Int { Logging.setsLogged(log, exercise: e.name) }
}
