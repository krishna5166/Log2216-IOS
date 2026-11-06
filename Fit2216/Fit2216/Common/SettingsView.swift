import SwiftUI

struct SettingsView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(AppModel.self) private var model
    let onDone: () -> Void

    private var email: String {
        if case .signedIn(_, let email) = auth.state { return email ?? "" }
        return ""
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if !model.profile.name.isEmpty { LabeledContent("Name", value: model.profile.name) }
                    LabeledContent("Email", value: email)
                    LabeledContent("Gym weights", value: model.profile.gymUnit.rawValue)
                    LabeledContent("Body weight", value: model.profile.bodyUnit.rawValue)
                }
                Section {
                    Button("Sign out", role: .destructive) { auth.signOut(); onDone() }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: onDone) } }
        }
    }
}
