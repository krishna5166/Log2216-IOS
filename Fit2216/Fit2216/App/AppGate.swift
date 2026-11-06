import SwiftUI

/// Shows sign-in until there is a session, then the app. Loads the person's data when they sign in and clears it when they sign out.
struct AppGate: View {
    @Environment(AuthModel.self) private var auth
    @Environment(AppModel.self) private var model

    var body: some View {
        switch auth.state {
        case .loading:
            ProgressView()
        case .signedOut:
            SignInView()
                .onAppear { model.reset() }
        case .signedIn(let uid, _):
            RootView()
                .task(id: uid) { await model.load(uid: uid) }
                .overlay { LoadingOverlay() }
                .safeAreaInset(edge: .top) { ErrorBanner(uid: uid) }
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
        if case .failed(let message) = model.phase {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                Text(message).font(.footnote).lineLimit(2)
                Spacer()
                Button("Retry") { Task { await model.load(uid: uid) } }.font(.footnote.bold())
            }
            .padding(10)
            .background(.regularMaterial)
        }
    }
}
