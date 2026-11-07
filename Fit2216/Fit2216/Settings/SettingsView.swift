import SwiftUI
import UniformTypeIdentifiers
import Fit2216Core

struct SettingsView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(AppModel.self) private var model
    @AppStorage("smartNotes") private var smartNotes = false
    @AppStorage("haptics") private var haptics = true
    @State private var sending = false
    @AppStorage("autoAdvance") private var autoAdvance = true
    let onDone: () -> Void

    @State private var backupURL: URL?
    @State private var csvURL: URL?
    @State private var pendingBackup: BackupFile?
    @State private var pendingCSV: CsvImport?
    @State private var showBackupImporter = false
    @State private var showCSVImporter = false
    @State private var busy = false
    @State private var message: String?

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
                    NavigationLink("Body and targets") { AboutMeView() }
                    NavigationLink("Weigh-ins") { WeightHistoryView() }
                }

                Section("Units") {
                    Picker("Gym weights", selection: Binding(get: { model.profile.gymUnit }, set: { setUnit(gym: $0) })) {
                        Text("kg").tag(WeightUnit.kg); Text("lb").tag(WeightUnit.lb)
                    }
                    Picker("Body weight", selection: Binding(get: { model.profile.bodyUnit }, set: { setUnit(body: $0) })) {
                        Text("kg").tag(WeightUnit.kg); Text("lb").tag(WeightUnit.lb)
                    }
                }

                Section("While logging") {
                    Toggle("Haptics", isOn: $haptics)
                    Toggle("Next exercise after the last set", isOn: $autoAdvance)
                }

                Section {
                    Toggle("AI meal calculation", isOn: $smartNotes)
                } header: {
                    Text("Macros")
                } footer: {
                    Text("When on, the food text you type is sent through your own server to Google to estimate calories. Off by default.")
                }

                Section {
                    Button(busy ? "Preparing…" : "Prepare backup (.json)") { Task { await prepareBackup() } }.disabled(busy)
                    if let backupURL { ShareLink("Share backup", item: backupURL) }
                    Button("Restore from backup (.json)") { showBackupImporter = true }.disabled(sending)
                    if sending {
                        HStack(spacing: 8) { ProgressView(); Text("Sending to the cloud. Offline, this finishes when you reconnect.").font(.footnote).foregroundStyle(.secondary) }
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Restore puts a backup into this account: its plan, profile and library replace yours; its workouts and weigh-ins are added or replace the same dates. Nothing else is deleted. Make a backup first.")
                }

                Section {
                    Button("Prepare spreadsheet (.csv)") { Task { await prepareCSV() } }.disabled(busy)
                    if let csvURL { ShareLink("Share spreadsheet", item: csvURL) }
                    Button("Import spreadsheet (.csv)") { showCSVImporter = true }.disabled(sending)
                } header: {
                    Text("Spreadsheet")
                } footer: {
                    Text("Every set and weigh-in, one per row, for reading and editing in a spreadsheet. It is not a full backup: swaps and copied workouts are not in it (use Backup for those). Importing replaces the same dates and deletes nothing; a day keeps its swaps.")
                }

                Section {
                    NavigationLink("Check exercise names") { TidyNamesView() }
                    NavigationLink("Diagnostics") { DiagnosticsView() }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Finds one exercise saved under different spellings, so its history and trends stay together.")
                }

                Section {
                    Button("Sign out", role: .destructive) { auth.signOut(); onDone() }
                } footer: {
                    Text("Fit2216 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: onDone) } }
            .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [.json]) { result in readFile(result) { text in
                do { pendingBackup = try Backup.parse(text) } catch { message = "Import failed. \(error)" }
            } }
            .fileImporter(isPresented: $showCSVImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in readFile(result) { text in
                do { pendingCSV = try Csv.parse(text) } catch { message = "Import failed. \(error)" }
            } }
            .confirmationDialog("Restore this backup?", isPresented: Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } }), titleVisibility: .visible) {
                Button("Restore", role: .destructive) { restoreBackup() }
                Button("Cancel", role: .cancel) { pendingBackup = nil }
            } message: {
                Text("Your plan, profile and library are replaced by the backup's. Its \(pendingBackup?.logs.count ?? 0) workouts and \(pendingBackup?.weights.count ?? 0) weigh-ins are added or replace the same dates. Nothing else is deleted.")
            }
            .confirmationDialog("Import this spreadsheet?", isPresented: Binding(get: { pendingCSV != nil }, set: { if !$0 { pendingCSV = nil } }), titleVisibility: .visible) {
                Button("Import") { importCSV() }
                Button("Cancel", role: .cancel) { pendingCSV = nil }
            } message: {
                Text("Add \(pendingCSV?.logs.count ?? 0) workouts and \(pendingCSV?.weights.count ?? 0) weigh-ins. A workout or weigh-in on the same date is replaced; nothing else changes.")
            }
            .alert("Fit2216", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
    }

    // MARK: actions

    private func setUnit(gym: WeightUnit? = nil, body: WeightUnit? = nil) {
        var keys = Set<String>()
        if gym != nil { keys.insert("profile.gymUnit") }
        if body != nil { keys.insert("profile.bodyUnit") }
        model.updateProfile(keys: keys) { p in
            if let gym { p.gymUnitSetting = gym }
            if let body { p.bodyUnitSetting = body }
        }
    }

    private func readFile(_ result: Result<URL, Error>, then use: (String) -> Void) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), data.count < 20 * 1024 * 1024, let text = String(data: data, encoding: .utf8) else {
            message = "Could not read that file."
            return
        }
        use(text)
    }

    private func prepareBackup() async {
        guard let uid = model.uid else { return }
        busy = true
        defer { busy = false }
        do {
            guard let text = try await model.firestore.exportBackup(uid: uid) else { message = "Could not prepare the backup."; return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("fit2216-backup-\(Dates.localDate(Date())).json")
            try text.write(to: url, atomically: true, encoding: .utf8)
            backupURL = url
        } catch { message = "Could not prepare the backup. Try again." }
    }

    private func prepareCSV() async {
        guard let uid = model.uid else { return }
        busy = true
        defer { busy = false }
        do {
            async let logs = model.firestore.loadAllLogs(uid: uid)
            async let weights = model.firestore.loadAllWeights(uid: uid)
            let text = Csv.export(logs: try await logs, weights: try await weights)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("fit2216-\(Dates.localDate(Date())).csv")
            try text.write(to: url, atomically: true, encoding: .utf8)
            csvURL = url
        } catch { message = "Could not prepare the spreadsheet. Try again." }
    }

    private func restoreBackup() {
        guard let backup = pendingBackup, let uid = model.uid else { return }
        pendingBackup = nil
        sending = true
        model.firestore.restore(uid: uid, backup: backup) { report in finish(report, what: "Backup restore") }
        Task { await model.reload() } // shows what this phone now holds, including changes still waiting to be sent
    }

    private func importCSV() {
        guard let data = pendingCSV, let uid = model.uid else { return }
        pendingCSV = nil
        sending = true
        // A spreadsheet has no swaps or copied-workout details, so a day that already has them keeps them.
        let existing = Dictionary(model.logs.map { (Logging.documentID($0), $0) }, uniquingKeysWith: { first, _ in first })
        let logs = data.logs.map { log -> WorkoutLog in
            guard let old = existing[Logging.documentID(log)] else { return log }
            var merged = log
            if merged.template == nil { merged.template = old.template }
            if merged.swaps == nil { merged.swaps = old.swaps }
            return merged
        }
        model.firestore.importRows(uid: uid, logs: logs, weights: data.weights) { report in finish(report, what: "Spreadsheet import") }
        Task { await model.reload() }
    }

    /// Runs when the cloud has answered for every batch (offline, when the connection returns), so the message is the real result.
    private func finish(_ report: FirestoreService.WriteReport, what: String) {
        sending = false
        if report.failed == 0 {
            message = "\(what) finished: \(report.succeeded) items saved."
        } else {
            message = "\(what): \(report.succeeded) of \(report.attempted) items saved, \(report.failed) failed (\(report.firstError ?? "unknown reason")). Nothing was deleted. It is safe to run it again: the same days are replaced."
        }
        Task { await model.reload() }
    }
}
