import Foundation
import Fit2216Core

extension AppModel {
    enum CopyResult {
        case ready(TemplateDay)
        case blocked(String)
    }

    /// Starts today's copy of a workout (its targets and swaps, no sets). Never overwrites a workout already logged in today's slot.
    func startCopy(of source: TemplateDay, logged: WorkoutLog?) -> CopyResult {
        let date = Dates.localDate(now)
        let dayIndex = Dates.weekday(now)
        let id = "\(date)_\(dayIndex)"
        if let existing = logs.first(where: { Logging.documentID($0) == id }), Plan.loggedSets(existing) > 0 || existing.skipped == true {
            return .blocked("Today already has a logged workout (\(existing.dayName)). Finish or delete it first, so nothing is overwritten.")
        }
        let copy = WorkoutCopy.copy(source: source, logged: logged, date: date, dayIndex: dayIndex)
        save(copy)
        return .ready(copy.template ?? source)
    }
}
