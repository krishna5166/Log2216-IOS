import Foundation

/// Settings that belong to this deployment, not to the code.
enum AppConfig {
    /// The address of your Vercel server (the one that serves `/api/ai`), for example "https://fit2216.vercel.app".
    /// Leave it empty and the AI features say so instead of failing quietly.
    static let apiBaseURLString = ""

    static var apiBaseURL: URL? {
        let trimmed = apiBaseURLString.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : URL(string: trimmed)
    }
}
