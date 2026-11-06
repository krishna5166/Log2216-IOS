import SwiftUI

/// Shows sign-in until there is a session, then the app. Loads the person's data when they sign in and clears it when they sign out.
struct AppGate: View {
    @Environment(AuthModel.self) private var auth
    @Environment(AppModel.self) private var model
    @Environment(RestTimer.self) private var rest
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        switch auth.state {
        case .loading:
            ProgressView()
        case .signedOut:
            SignInView()
                .onAppear { model.reset(); rest.stop() }
        case .signedIn(let uid, _):
            RootView()
                .task(id: uid) { await model.load(uid: uid) }
                .task { await midnightTicks() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.dayChanged(); Task { await model.refreshIfNeeded() } }
                }
                .overlay { LoadingOverlay() }
                .safeAreaInset(edge: .top) { ErrorBanner(uid: uid) }
        }
    }

    /// Wakes just after local midnight so a foreground app moves on to the new day.
    private func midnightTicks() async {
        while !Task.isCancelled {
            let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0, second: 5), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
            try? await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow)))
            if !Task.isCancelled { model.dayChanged() }
        }
    }
}

private struct LoadingOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.phase == .loading && model.plan.isEmpty {
            ProgressView("Loading your plan…")
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct ErrorBanner: View {
    @Environment(AppModel.self) private var model
    let uid: String

    var body: some View {
        switch model.phase {
        case .failed(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                Text(message).font(.footnote).lineLimit(2)
                Spacer()
                Button("Retry") { Task { await model.load(uid: uid) } }.font(.footnote.bold())
            }
            .padding(10)
            .background(.regularMaterial)
        case .stale(let message):
            HStack(spacing: 8) {
                Image(systemName: "icloud.slash").foregroundStyle(.secondary)
                Text(message).font(.footnote).lineLimit(2)
                Spacer()
                Button("Retry") { Task { await model.load(uid: uid) } }.font(.footnote.bold())
            }
            .padding(8)
            .background(.regularMaterial)
        default:
            if let problem = model.writeProblem {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    Text("A change could not be saved to the cloud: \(problem)").font(.footnote).lineLimit(3)
                    Spacer()
                    Button("OK") { model.dismissWriteProblem() }.font(.footnote.bold())
                }
                .padding(8)
                .background(.regularMaterial)
            } else if model.slowSync && model.unsent > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.secondary)
                    Text(model.unsent == 1 ? "1 change saved on this phone, syncing…" : "\(model.unsent) changes saved on this phone, syncing…").font(.footnote)
                    Spacer()
                }
                .padding(8)
                .background(.regularMaterial)
            }
        }
    }
}
