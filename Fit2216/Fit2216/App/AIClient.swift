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

/// Foods already worked out are answered from the phone, so the same text never costs a second request. Kept per account.
enum FoodMemory {
    private static func key(_ uid: String, _ text: String) -> String { "foodMemory.\(uid).\(Food.normalize(text))" }

    static func lookup(uid: String, text: String) -> [Meal]? {
        guard let data = UserDefaults.standard.data(forKey: key(uid, text)) else { return nil }
        return try? JSONDecoder().decode([Meal].self, from: data)
    }

    static func store(uid: String, text: String, meals: [Meal]) {
        if let data = try? JSONEncoder().encode(meals) { UserDefaults.standard.set(data, forKey: key(uid, text)) }
    }
}
