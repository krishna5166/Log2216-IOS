import Foundation

/// The one notice shown at the top of the app, chosen from everything that can be wrong at once.
public struct StatusNotice: Equatable, Sendable {
    public enum Kind: Sendable { case problem, offline, syncing }
    public enum Action: Sendable { case retry, dismiss, none }
    public var kind: Kind
    public var message: String
    public var action: Action
}

public enum Status {
    /// Priority: data could not be loaded, then a change was refused, then working offline, then changes still sending.
    /// Only one notice at a time, so the screen never stacks competing messages; what is waiting to sync is folded into the offline line.
    public static func notice(loadFailed: String?, offline: String?, writeProblem: String?, unsent: Int, slowSync: Bool) -> StatusNotice? {
        let waiting = unsent == 1 ? "1 change is waiting to sync." : "\(unsent) changes are waiting to sync."
        if let loadFailed { return StatusNotice(kind: .problem, message: loadFailed, action: .retry) }
        if let writeProblem {
            let extra = unsent > 0 ? " " + waiting : ""
            return StatusNotice(kind: .problem, message: "A change could not be saved to the cloud: \(writeProblem)." + extra, action: .dismiss)
        }
        if let offline { return StatusNotice(kind: .offline, message: offline + (unsent > 0 ? " " + waiting : ""), action: .retry) }
        if slowSync && unsent > 0 {
            return StatusNotice(kind: .syncing, message: unsent == 1 ? "1 change saved on this phone, syncing…" : "\(unsent) changes saved on this phone, syncing…", action: .none)
        }
        return nil
    }
}
