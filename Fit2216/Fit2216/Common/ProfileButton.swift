import SwiftUI

/// The profile icon, top right, that opens Settings (a placeholder for now).
private struct ProfileButton: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "person.crop.circle") }
                        .accessibilityLabel("Profile and settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    ContentUnavailableView("Settings", systemImage: "gearshape", description: Text("Units, backup, spreadsheet and sign-out go here."))
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSettings = false } } }
                }
            }
    }
}

extension View {
    func profileButton() -> some View { modifier(ProfileButton()) }
}

struct ComingSoonView: View {
    let title: String
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text("Comes after logging works."))
            .navigationTitle(title)
    }
}
