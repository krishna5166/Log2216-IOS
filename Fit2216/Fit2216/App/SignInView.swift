import SwiftUI

struct SignInView: View {
    @Environment(AuthModel.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var info: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Fit2216").font(.largeTitle.bold())
            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
            if let message {
                Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            if let info {
                Text(info).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button {
                Task { await signIn() }
            } label: {
                if busy { ProgressView() } else { Text("Sign in").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(busy || email.isEmpty || password.isEmpty)
            Button("Forgot password?") { Task { await reset() } }
                .font(.footnote)
                .disabled(busy)
        }
        .padding(24)
    }

    private func reset() async {
        let address = email.trimmingCharacters(in: .whitespaces)
        guard !address.isEmpty else { message = "Type your email above first."; info = nil; return }
        busy = true
        message = nil
        do {
            try await auth.sendPasswordReset(email: address)
            info = "If that email has an account, a reset link is on its way."
        } catch {
            message = error.localizedDescription
        }
        busy = false
    }

    private func signIn() async {
        busy = true
        info = nil
        message = nil
        do {
            try await auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            message = error.localizedDescription
        }
        busy = false
    }
}
