import Foundation

/// Combines the recent workouts the app keeps fresh with the all-time archive, so records are judged against the whole history.
public enum LogHistory {
    /// Every workout once: the archive's copy, replaced by the recent one when both have the same document. Newest first.
    public static func merged(recent: [WorkoutLog], archive: [WorkoutLog]) -> [WorkoutLog] {
        guard !archive.isEmpty else { return recent }
        var byID: [String: WorkoutLog] = [:]
        for log in archive { byID[Logging.documentID(log)] = log }
        for log in recent { byID[Logging.documentID(log)] = log }
        return byID.values.sorted { $0.date == $1.date ? Logging.documentID($0) > Logging.documentID($1) : $0.date > $1.date }
    }
}
