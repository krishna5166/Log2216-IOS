import SwiftUI
import Fit2216Core

/// What to look at when something seems wrong: versions, load state, unsent changes, the server. Can be shared as text.
struct DiagnosticsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AuthModel.self) private var auth
    @AppStorage("smartNotes") private var smartNotes = false
    @AppStorage("haptics") private var haptics = true
    @AppStorage("autoAdvance") private var autoAdvance = true
    @State private var serverResult: String?
    @State private var checking = false

    private var email: String {
        if case .signedIn(_, let email) = auth.state { return email ?? "" }
        return "not signed in"
    }

    private var phase: String {
        switch model.phase {
        case .idle: return "idle"
        case .loading: return "loading"
        case .ready: return "ready"
        case .stale(let why): return "showing this phone's copy (\(why))"
        case .failed(let why): return "failed (\(why))"
        }
    }

    private var lines: [(String, String)] {
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        return [
            ("App version", version),
            ("Signed in as", email),
            ("Data", phase),
            ("Workouts / weigh-ins", "\(model.logs.count) / \(model.weights.count)"),
            ("Unsent changes", "\(model.unsent)" + (model.slowSync ? " (waiting a while)" : "")),
            ("Last save problem", model.writeProblem ?? "none"),
            ("Exercise names split", "\(ExerciseNames.drift(plan: model.plan, logs: model.logs).count)"),
            ("AI calculation", smartNotes ? "on" : "off"),
            ("Haptics / auto-advance", "\(haptics ? "on" : "off") / \(autoAdvance ? "on" : "off")"),
            ("Server", AppConfig.apiBaseURL?.absoluteString ?? "not set"),
            ("Server check", serverResult ?? "not run"),
            ("Time zone", TimeZone.current.identifier),
        ]
    }

    private var report: String { lines.map { "\($0.0): \($0.1)" }.joined(separator: "\n") }

    var body: some View {
        List {
            Section {
                ForEach(lines, id: \.0) { LabeledContent($0.0, value: $0.1) }
            }
            Section {
                Button(checking ? "Checking…" : "Check the server") { Task { await checkServer() } }.disabled(checking)
                ShareLink("Share this report", item: report)
            } footer: {
                Text("The server check expects the answer 405 (\"POST only\"): that means the AI server is reachable.")
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func checkServer() async {
        guard let base = AppConfig.apiBaseURL else { serverResult = "address not set"; return }
        checking = true
        defer { checking = false }
        let start = Date()
        do {
            var request = URLRequest(url: base.appendingPathComponent("api/ai"))
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let text = String(decoding: data.prefix(60), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            serverResult = "HTTP \(code) in \(ms) ms \(text.isEmpty ? "" : "(\(text))")"
        } catch {
            serverResult = "failed: \(error.localizedDescription)"
        }
    }
}
