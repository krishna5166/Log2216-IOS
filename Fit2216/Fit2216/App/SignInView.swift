import SwiftUI

struct SignInView: View {
    @Environment(AuthModel.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var info: String?

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 84, height: 84)
                .background(Theme.lime, in: RoundedRectangle(cornerRadius: 22))
                .padding(.bottom, 6)
            Text("Fit2216").font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Your workouts, weight and food.").font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 18)

            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            if let message {
                Text(message).font(.footnote).foregroundStyle(Theme.pink).multilineTextAlignment(.center)
            }
            if let info {
                Text(info).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            let ready = !(busy || email.isEmpty || password.isEmpty)
            Button {
                Task { await signIn() }
            } label: {
                Group { if busy { ProgressView().tint(.black) } else { Text("Sign in") } }
                    .limeCapsule(enabled: ready)
            }
            .buttonStyle(.plain)
            .disabled(!ready)
            .padding(.top, 6)
            Button("Forgot password?") { Task { await reset() } }
                .font(.footnote)
                .disabled(busy)
            Spacer(minLength: 0)
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
