import Foundation
import FirebaseAuth
import Fit2216Core

/// Asks your Vercel server (the "brain") to turn food text into calories and macros. The server checks who is asking and holds the AI keys.
struct AIClient {
    enum Failure: LocalizedError {
        case notConfigured, notSignedIn, offline, tooSlow, empty
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "the server address is not set yet (AppConfig.swift)"
            case .notSignedIn: return "you are not signed in"
            case .offline: return "no connection to the server"
            case .tooSlow: return "it took too long"
            case .empty: return "the server could not read any food in that text"
            case .server(let m): return m
            }
        }
    }

    private struct Reply: Decodable {
        var meals: LossyArray<Meal>?
    }

    func meals(for text: String) async throws -> [Meal] {
        guard let base = AppConfig.apiBaseURL else { throw Failure.notConfigured }
        guard let user = Auth.auth().currentUser else { throw Failure.notSignedIn }
        let token = try await user.getIDToken()

        var request = URLRequest(url: base.appendingPathComponent("api/ai"))
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["task": "macros", "data": ["text": text.trimmingCharacters(in: .whitespacesAndNewlines)]])

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw Failure.tooSlow
        } catch is URLError {
            throw Failure.offline
        }

        guard let http = response as? HTTPURLResponse else { throw Failure.offline }
        guard http.statusCode == 200 else {
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            switch http.statusCode {
            case 404: throw Failure.server("the server was not found (/api/ai returned 404)")
            case 401, 403: throw Failure.server("the server could not verify you")
            default: throw Failure.server((body?["error"] as? String) ?? "server error \(http.statusCode)")
            }
        }
        let meals = (try? JSONDecoder().decode(Reply.self, from: data))?.meals?.elements ?? []
        let clean = meals
            .filter { [$0.kcal, $0.protein, $0.carbs, $0.fat].allSatisfy { $0.isFinite && $0 >= 0 } }
            .prefix(30)
            .map { Meal(name: String($0.name.trimmingCharacters(in: .whitespaces).prefix(40)), kcal: $0.kcal, protein: $0.protein, carbs: $0.carbs, fat: $0.fat) }
        if clean.isEmpty { throw Failure.empty }
        return Array(clean)
    }
}

/// Foods already worked out are answered from the phone, so the same text never costs a second request. Kept per account,
/// limited to the 200 most recently used estimates, and cleared when that account signs out (food text is personal).
enum FoodMemory {
    static let limit = 200
    static let maxTextLength = 500

    private static var defaults: UserDefaults { .standard }
    private static func prefix(_ uid: String) -> String { "foodMemory.\(uid)." }
    private static func key(_ uid: String, _ text: String) -> String { prefix(uid) + Food.normalize(text) }
    private static func indexKey(_ uid: String) -> String { "foodMemoryIndex.\(uid)" }

    /// The keys in use, oldest first. Entries saved before the index existed are adopted once, so they too can be limited and cleared.
    private static func order(_ uid: String) -> [String] {
        if let saved = defaults.stringArray(forKey: indexKey(uid)) { return saved }
        let legacy = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix(uid)) }.sorted()
        defaults.set(legacy, forKey: indexKey(uid))
        return legacy
    }

    private static func touch(_ uid: String, _ k: String) {
        let result = Lru.touch(order(uid), key: k, limit: limit)
        result.evicted.forEach { defaults.removeObject(forKey: $0) }
        defaults.set(result.order, forKey: indexKey(uid))
    }

    static func lookup(uid: String, text: String) -> [Meal]? {
        let k = key(uid, text)
        guard let data = defaults.data(forKey: k), let meals = try? JSONDecoder().decode([Meal].self, from: data) else { return nil }
        touch(uid, k) // used just now, so it is the last to go
        return meals
    }

    static func store(uid: String, text: String, meals: [Meal]) {
        guard Food.normalize(text).count <= maxTextLength, let data = try? JSONEncoder().encode(meals) else { return }
        let k = key(uid, text)
        defaults.set(data, forKey: k)
        touch(uid, k)
    }

    /// Removes everything remembered for this account (called on sign-out).
    static func clear(uid: String) {
        order(uid).forEach { defaults.removeObject(forKey: $0) }
        defaults.removeObject(forKey: indexKey(uid))
    }
}
