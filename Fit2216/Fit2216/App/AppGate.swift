import SwiftUI
import Fit2216Core

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
                .task(id: uid) { await model.load(uid: uid); await model.flushFeedback(); await model.refreshProposal() }
                .task { await midnightTicks() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.dayChanged(); Task { await model.refreshIfNeeded(); await model.flushFeedback(); await model.refreshProposal() } }
                }
                .overlay { LoadingOverlay() }
                .safeAreaInset(edge: .top) { VStack(spacing: 0) { StatusBanner(uid: uid); FeedbackFailureBanner(); PlanOfferBanner() } }
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

/// The one notice at the top of the app (see `Status.notice` in core for the priority): load failed, a change was refused,
/// working offline, or changes still sending. Never more than one at a time.
private struct StatusBanner: View {
    @Environment(AppModel.self) private var model
    let uid: String

    private var notice: StatusNotice? {
        var failed: String?, offline: String?
        switch model.phase {
        case .failed(let message): failed = message
        case .stale(let message): offline = message
        default: break
        }
        return Status.notice(loadFailed: failed, offline: offline, writeProblem: model.writeProblem, unsent: model.unsent, slowSync: model.slowSync)
    }

    private func icon(_ kind: StatusNotice.Kind) -> (name: String, color: Color) {
        switch kind {
        case .problem: return ("exclamationmark.triangle.fill", .yellow)
        case .offline: return ("icloud.slash", .secondary)
        case .syncing: return ("arrow.triangle.2.circlepath", .secondary)
        }
    }

    var body: some View {
        if let notice {
            HStack(spacing: 10) {
                Image(systemName: icon(notice.kind).name).foregroundStyle(icon(notice.kind).color)
                Text(notice.message).font(.footnote).lineLimit(3)
                Spacer(minLength: 8)
                switch notice.action {
                case .retry: Button("Retry") { Task { await model.load(uid: uid) } }.font(.footnote.bold())
                case .dismiss: Button("OK") { model.dismissWriteProblem() }.font(.footnote.bold())
                case .none: EmptyView()
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .accessibilityElement(children: .combine)
        }
    }
}
