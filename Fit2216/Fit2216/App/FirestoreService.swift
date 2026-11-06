import Foundation
import FirebaseFirestore
import Fit2216Core

/// Reads the same documents the web app writes: `users/{uid}` and `users/{uid}/logs/*`. The Firestore SDK keeps its own offline copy.
struct FirestoreService {
    func loadUserDoc(uid: String) async throws -> UserDoc {
        let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
        guard let data = snapshot.data() else { return UserDoc() }
        return FirestoreDecoding.decode(UserDoc.self, from: data) ?? UserDoc()
    }

    func loadLogs(uid: String, limit: Int = 120) async throws -> [WorkoutLog] {
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid).collection("logs")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { FirestoreDecoding.decode(WorkoutLog.self, from: $0.data()) }
    }

    func loadWeights(uid: String, limit: Int = 120) async throws -> [WeightEntry] {
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid).collection("weights")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { FirestoreDecoding.decode(WeightEntry.self, from: $0.data()) }
    }
}
