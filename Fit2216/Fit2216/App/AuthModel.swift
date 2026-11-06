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

    func signOut() {
        try? Auth.auth().signOut()
    }
}
