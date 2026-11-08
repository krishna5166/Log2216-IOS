import Foundation
import FirebaseAuth
import Fit2216Core

/// Talks to the feedback-loop routes on your Vercel server (`/api/sessions`, `/api/plan`). Every failure is quiet: the loop is a bonus,
/// and a finished workout is already safe in Firestore. Wire format: `docs/API_CONTRACT.md` in the `log2216-api` repository.
struct FeedbackClient {
    enum Outcome: Equatable { case sent, refused(status: Int, message: String), retry }

    private func request(_ path: String, method: String, body: Data? = nil) async -> (Int, Data)? {
        guard let base = AppConfig.apiBaseURL, let user = Auth.auth().currentUser, let token = try? await user.getIDToken() else { return nil }
        guard let url = URL(string: base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path) else { return nil }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 20
        r.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        if let body { r.httpBody = body; r.setValue("application/json", forHTTPHeaderField: "content-type") }
        guard let (data, response) = try? await URLSession.shared.data(for: r), let http = response as? HTTPURLResponse else { return nil }
        return (http.statusCode, data)
    }

    /// Sends one finished workout. 200/201 mean stored (a repeat of the same session id is harmless); 400, 409 and 413 will never succeed
    /// as they are, so they come back as `refused` with the server's short reason (kept and shown, not dropped); anything else (offline,
    /// server not updated yet, 5xx) is tried again later.
    func post(_ session: FeedbackSession) async -> Outcome {
        guard let body = try? JSONEncoder().encode(session), let (status, data) = await request("api/sessions", method: "POST", body: body) else { return .retry }
        if status == 200 || status == 201 { return .sent }
        if FeedbackFailure.isRefusal(status) { return .refused(status: status, message: FeedbackFailure.message(status: status, body: data)) }
        return .retry
    }

    /// The server's proposed plan numbers when it has a version newer than `since`; nil for "nothing new", "none yet" and any failure.
    func plan(since: Int) async -> PlanProposal? {
        guard let (status, data) = await request("api/plan?since=\(max(0, since))", method: "GET"), status == 200 else { return nil }
        return try? JSONDecoder().decode(PlanProposal.self, from: data)
    }
}

/// Finished workouts that the server has not confirmed yet, kept on this phone per account so a lost connection loses nothing.
enum FeedbackOutbox {
    private static func key(_ uid: String) -> String { "fit2216.feedback.outbox.\(uid)" }
    private static let limit = 30

    static func load(_ uid: String) -> [FeedbackSession] {
        guard let data = UserDefaults.standard.data(forKey: key(uid)) else { return [] }
        return (try? JSONDecoder().decode([FeedbackSession].self, from: data)) ?? []
    }

    static func save(_ items: [FeedbackSession], uid: String) {
        let kept = Array(items.suffix(limit))
        if kept.isEmpty { UserDefaults.standard.removeObject(forKey: key(uid)) }
        else if let data = try? JSONEncoder().encode(kept) { UserDefaults.standard.set(data, forKey: key(uid)) }
    }

    static func clear(_ uid: String) { UserDefaults.standard.removeObject(forKey: key(uid)); UserDefaults.standard.removeObject(forKey: failedKey(uid)) }

    // Workouts the server refused, kept until the owner retries or discards them.
    private static func failedKey(_ uid: String) -> String { "fit2216.feedback.failed.\(uid)" }
    static func loadFailed(_ uid: String) -> [FeedbackFailure] {
        guard let data = UserDefaults.standard.data(forKey: failedKey(uid)) else { return [] }
        return (try? JSONDecoder().decode([FeedbackFailure].self, from: data)) ?? []
    }
    static func saveFailed(_ items: [FeedbackFailure], uid: String) {
        if items.isEmpty { UserDefaults.standard.removeObject(forKey: failedKey(uid)) }
        else if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: failedKey(uid)) }
    }
}
