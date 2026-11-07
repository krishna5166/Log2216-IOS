import SwiftUI
import Observation
import FirebaseAuth

/// Who is signed in. Firebase keeps the session on the phone, so you stay signed in between launches.
@Observable
final class AuthModel {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(uid: String, email: String?)
    }

    var state: State = .loading
    @ObservationIgnored private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user { self?.state = .signedIn(uid: user.uid, email: user.email) } else { self?.state = .signedOut }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    /// Sends a password-reset email. Firebase answers the same way whether or not the address has an account.
    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func signOut() {
        // Food text typed on this phone belongs to this account: forget it when they leave.
        if case .signedIn(let uid, _) = state { FoodMemory.clear(uid: uid) }
        try? Auth.auth().signOut()
    }
}
