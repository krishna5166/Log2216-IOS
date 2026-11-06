import Foundation
import FirebaseFirestore
import Fit2216Core

/// Everything the app writes to Firestore beyond a workout, in the same shapes the web app uses. Writes are queued by the SDK while offline.
extension FirestoreService {
    private var db: Firestore { Firestore.firestore() }
    private func user(_ uid: String) -> DocumentReference { db.collection("users").document(uid) }

    private func object<T: Encodable>(_ value: T) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    private func objects<T: Encodable>(_ values: [T]) -> [Any] { values.compactMap { object($0) } }

    // MARK: weights, workouts

    func saveWeight(uid: String, entry: WeightEntry) {
        user(uid).collection("weights").document(entry.date).setData(["date": entry.date, "kg": entry.kg])
    }

    func deleteWeight(uid: String, date: String) {
        user(uid).collection("weights").document(date).delete()
    }

    func deleteLog(uid: String, log: WorkoutLog) {
        user(uid).collection("logs").document(Logging.documentID(log)).delete()
    }

    // MARK: plan and profile

    func savePlan(uid: String, plan: [TemplateDay], library: [String]) {
        user(uid).setData(["plan": objects(plan), "library": library], merge: true)
    }

    func updateProfile(uid: String, fields: [String: Any?]) {
        var mapped: [String: Any] = [:]
        for (key, value) in fields { mapped[key] = value ?? FieldValue.delete() }
        user(uid).updateData(mapped)
    }

    // MARK: food

    func loadFoodDay(uid: String, date: String) async throws -> FoodDay {
        let snapshot = try await user(uid).collection("foodDays").document(date).getDocument()
        guard let data = snapshot.data() else { return FoodDay() }
        return FirestoreDecoding.decode(FoodDay.self, from: data) ?? FoodDay()
    }

    func saveFoodDay(uid: String, date: String, day: FoodDay) {
        guard let data = object(day) else { return }
        user(uid).collection("foodDays").document(date).setData(data)
    }

    /// Completion % for each day from `from` on, newest data only (for the 7-day chart).
    func loadFoodPercents(uid: String, from: String) async throws -> [String: Int] {
        let snapshot = try await user(uid).collection("foodDays")
            .whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: from)
            .getDocuments()
        var out: [String: Int] = [:]
        for doc in snapshot.documents {
            if let pct = FirestoreDecoding.decode(FoodDay.self, from: doc.data())?.pct { out[doc.documentID] = pct }
        }
        return out
    }

    // MARK: backup and restore

    func exportBackup(uid: String) async throws -> String? {
        let user = try await self.user(uid).getDocument().data() ?? [:]
        let logs = try await self.user(uid).collection("logs").getDocuments().documents.map { $0.data() }
        let weights = try await self.user(uid).collection("weights").getDocuments().documents.map { $0.data() }
        return Backup.export(user: user, logs: logs, weights: weights, exportedAt: ISO8601DateFormatter().string(from: Date()))
    }

    /// Puts a validated backup into the account: its plan, profile and library replace yours; its workouts and weigh-ins are added or replace the same dates. Nothing else is deleted.
    func restore(uid: String, backup: BackupFile) {
        var fields: [String: Any] = ["plan": objects(backup.plan), "library": backup.library, "profile": backup.profile]
        if let templates = backup.templates { fields["templates"] = templates }
        user(uid).setData(fields, mergeFields: Array(fields.keys))
        for log in backup.logs { if let data = object(log) { user(uid).collection("logs").document(Logging.documentID(log)).setData(data) } }
        for w in backup.weights { saveWeight(uid: uid, entry: w) }
    }

    /// Adds workouts and weigh-ins from a spreadsheet; the same date replaces, nothing else is touched.
    func importRows(uid: String, logs: [WorkoutLog], weights: [WeightEntry]) {
        for log in logs { if let data = object(log) { user(uid).collection("logs").document(Logging.documentID(log)).setData(data) } }
        for w in weights { saveWeight(uid: uid, entry: w) }
    }

    func loadAllLogs(uid: String) async throws -> [WorkoutLog] {
        let snapshot = try await user(uid).collection("logs").order(by: "date", descending: true).getDocuments()
        return snapshot.documents.compactMap { FirestoreDecoding.decode(WorkoutLog.self, from: $0.data()) }
    }

    func loadAllWeights(uid: String) async throws -> [WeightEntry] {
        let snapshot = try await user(uid).collection("weights").order(by: "date", descending: true).getDocuments()
        return snapshot.documents.compactMap { FirestoreDecoding.decode(WeightEntry.self, from: $0.data()) }
    }
}
