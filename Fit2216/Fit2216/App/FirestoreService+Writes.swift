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

    func saveWeight(uid: String, entry: WeightEntry, completion: ((Error?) -> Void)? = nil) {
        user(uid).collection("weights").document(entry.date).setData(["date": entry.date, "kg": entry.kg], completion: completion)
    }

    func deleteWeight(uid: String, date: String, completion: ((Error?) -> Void)? = nil) {
        user(uid).collection("weights").document(date).delete(completion: completion)
    }

    func deleteLog(uid: String, log: WorkoutLog, completion: ((Error?) -> Void)? = nil) {
        user(uid).collection("logs").document(Logging.documentID(log)).delete(completion: completion)
    }

    // MARK: plan and profile

    func savePlan(uid: String, plan: [TemplateDay], library: [String], completion: ((Error?) -> Void)? = nil) {
        user(uid).setData(["plan": objects(plan), "library": library], merge: true, completion: completion)
    }

    /// Changes only the named profile fields (`profile.heightCm` ...); nil removes a field. Creates the document if it does not exist yet.
    func updateProfile(uid: String, fields: [String: Any?], completion: ((Error?) -> Void)? = nil) {
        var nested: [String: Any] = [:]
        for (key, value) in fields where key.hasPrefix("profile.") {
            nested[String(key.dropFirst("profile.".count))] = value ?? FieldValue.delete()
        }
        guard !nested.isEmpty else { completion?(nil); return } // nothing to write is a finished write, not a stuck one
        user(uid).setData(["profile": nested], merge: true, completion: completion)
    }

    // MARK: food

    func loadFoodDay(uid: String, date: String) async throws -> FoodDay {
        let snapshot = try await user(uid).collection("foodDays").document(date).getDocument()
        guard let data = snapshot.data() else { return FoodDay() }
        return FirestoreDecoding.decode(FoodDay.self, from: data) ?? FoodDay()
    }

    func saveFoodDay(uid: String, date: String, day: FoodDay, completion: ((Error?) -> Void)? = nil) {
        guard let data = object(day) else { completion?(SaveEncodingError()); return }
        user(uid).collection("foodDays").document(date).setData(data, completion: completion)
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

    /// What a restore or import achieved, once the cloud has answered for every batch.
    struct WriteReport {
        var attempted = 0
        var failed = 0
        var firstError: String?
        var succeeded: Int { attempted - failed }
    }

    private struct PendingWrite {
        var ref: DocumentReference
        var data: [String: Any]
        var mergeFields: [String]?
    }

    /// Sends the writes in batches of up to 400 (each batch is all-or-nothing) and calls `done` once every batch has been answered:
    /// offline that is when the connection returns. Several batches are not one atomic restore, so a failed batch is counted and reported
    /// and the whole import can be run again safely (the same days are replaced, nothing is deleted).
    private func send(_ writes: [PendingWrite], done: @escaping (WriteReport) -> Void) {
        let chunks = stride(from: 0, to: writes.count, by: 400).map { Array(writes[$0..<min($0 + 400, writes.count)]) }
        guard !chunks.isEmpty else { done(WriteReport()); return }
        var report = WriteReport(attempted: writes.count)
        var remaining = chunks.count
        for chunk in chunks {
            let batch = db.batch()
            for w in chunk {
                if let fields = w.mergeFields { batch.setData(w.data, forDocument: w.ref, mergeFields: fields) } else { batch.setData(w.data, forDocument: w.ref) }
            }
            batch.commit { error in
                DispatchQueue.main.async {
                    if let error { report.failed += chunk.count; report.firstError = report.firstError ?? error.localizedDescription }
                    remaining -= 1
                    if remaining == 0 { done(report) }
                }
            }
        }
    }

    private func logWrites(_ logs: [WorkoutLog], _ uid: String) -> (writes: [PendingWrite], unreadable: Int) {
        var writes: [PendingWrite] = [], bad = 0
        for log in logs {
            if let data = object(log) { writes.append(PendingWrite(ref: user(uid).collection("logs").document(Logging.documentID(log)), data: data, mergeFields: nil)) } else { bad += 1 }
        }
        return (writes, bad)
    }

    private func weightWrites(_ weights: [WeightEntry], _ uid: String) -> [PendingWrite] {
        weights.map { PendingWrite(ref: user(uid).collection("weights").document($0.date), data: ["date": $0.date, "kg": $0.kg], mergeFields: nil) }
    }

    /// Puts a validated backup into the account: its plan, profile and library replace yours; its workouts and weigh-ins are added or replace the same dates. Nothing else is deleted.
    func restore(uid: String, backup: BackupFile, done: @escaping (WriteReport) -> Void) {
        var fields: [String: Any] = ["plan": objects(backup.plan), "library": backup.library, "profile": backup.profile]
        if let templates = backup.templates { fields["templates"] = templates }
        let logs = logWrites(backup.logs, uid)
        var writes = [PendingWrite(ref: user(uid), data: fields, mergeFields: Array(fields.keys))]
        writes += logs.writes
        writes += weightWrites(backup.weights, uid)
        send(writes) { report in
            var r = report
            r.attempted += logs.unreadable
            r.failed += logs.unreadable
            done(r)
        }
    }

    /// Adds workouts and weigh-ins from a spreadsheet; the same date replaces, nothing else is touched.
    func importRows(uid: String, logs: [WorkoutLog], weights: [WeightEntry], done: @escaping (WriteReport) -> Void) {
        let l = logWrites(logs, uid)
        send(l.writes + weightWrites(weights, uid)) { report in
            var r = report
            r.attempted += l.unreadable
            r.failed += l.unreadable
            done(r)
        }
    }

    func loadAllLogs(uid: String) async throws -> [WorkoutLog] {
        let snapshot = try await user(uid).collection("logs").order(by: "date", descending: true).getDocuments()
        return snapshot.documents.compactMap { FirestoreDecoding.decode(WorkoutLog.self, from: $0.data()) }
    }

    func loadAllWeights(uid: String) async throws -> [WeightEntry] {
        let snapshot = try await user(uid).collection("weights").order(by: "date", descending: true).getDocuments()
        return snapshot.documents.compactMap { FirestoreDecoding.decode(WeightEntry.self, from: $0.data()) }
    }

    // MARK: loading

    struct Loaded {
        var doc: UserDoc
        var logs: [WorkoutLog]
        var weights: [WeightEntry]
    }

    /// Plan, profile, recent workouts and weigh-ins. With `.cache` it answers at once from what this phone already holds (and throws if it holds nothing).
    func loadAll(uid: String, source: FirestoreSource) async throws -> Loaded {
        let userSnap = try await user(uid).getDocument(source: source)
        let doc = userSnap.data().flatMap { FirestoreDecoding.decode(UserDoc.self, from: $0) } ?? UserDoc()
        let logSnap = try await user(uid).collection("logs").order(by: "date", descending: true).limit(to: 500).getDocuments(source: source)
        let logs = logSnap.documents.compactMap { FirestoreDecoding.decode(WorkoutLog.self, from: $0.data()) }
        let weightSnap = try? await user(uid).collection("weights").order(by: "date", descending: true).limit(to: 400).getDocuments(source: source)
        let weights = weightSnap?.documents.compactMap { FirestoreDecoding.decode(WeightEntry.self, from: $0.data()) } ?? []
        return Loaded(doc: doc, logs: logs, weights: weights)
    }

    /// One workout straight from the server, so a workout started on another device is not overwritten by an older copy here.
    func loadLog(uid: String, id: String) async throws -> WorkoutLog? {
        let snap = try await user(uid).collection("logs").document(id).getDocument(source: .server)
        return snap.data().flatMap { FirestoreDecoding.decode(WorkoutLog.self, from: $0) }
    }
}
