import Foundation

/// A finished workout the server refused (400, 409 or 413). Kept on the phone and shown, instead of being dropped silently,
/// until the owner retries or discards it. Holds the server's short error text only; never the token.
public struct FeedbackFailure: Codable, Equatable, Sendable {
    public var session: FeedbackSession
    public var status: Int
    public var message: String
    public var at: String

    public init(session: FeedbackSession, status: Int, message: String, at: String) {
        self.session = session; self.status = status; self.message = String(message.prefix(160)); self.at = at
    }

    /// Statuses that will not succeed by sending the same body again.
    public static func isRefusal(_ status: Int) -> Bool { [400, 409, 413].contains(status) }

    /// The server's `{"error": ..., "detail": ...}` as one short line; a plain fallback when the body is not that shape.
    public static func message(status: Int, body: Data) -> String {
        let j = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let parts = [j?["error"] as? String, j?["detail"] as? String].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.isEmpty ? "The server refused this workout (HTTP \(status))" : parts.joined(separator: ": ")
    }

    /// Adds or replaces the failure for the same session (one entry per workout), newest last, at most `limit`.
    public static func recording(_ f: FeedbackFailure, in list: [FeedbackFailure], limit: Int = 30) -> [FeedbackFailure] {
        Array((list.filter { $0.session.sessionId != f.session.sessionId } + [f]).suffix(limit))
    }

    /// What to send again on Retry: the workout rebuilt from its current log when it still exists (so a corrected log is used),
    /// else the original body. A 409 means the server already holds a different version of this session: retrying cannot help.
    public static func retryBody(_ f: FeedbackFailure, rebuilt: FeedbackSession?) -> FeedbackSession? {
        if f.status == 409 { return nil }
        return rebuilt ?? f.session
    }
}
