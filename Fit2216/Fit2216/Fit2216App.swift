import SwiftUI
import FirebaseCore

@main
struct Fit2216App: App {
    @State private var auth: AuthModel
    @State private var model: AppModel

    init() {
        // Firebase must be configured before anything touches Auth or Firestore, so the models are built after it.
        FirebaseApp.configure()
        _auth = State(initialValue: AuthModel())
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            AppGate()
                .environment(auth)
                .environment(model)
        }
    }
}
