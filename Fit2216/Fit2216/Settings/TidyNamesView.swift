import SwiftUI
import Fit2216Core

/// Finds one exercise logged under several spellings and, on confirmation, rewrites those workouts to one name.
struct TidyNamesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @State private var confirm = false
    @State private var result: String?

    var body: some View {
        let groups = ExerciseNames.drift(plan: model.plan, logs: model.logs)
        let preview = ExerciseNames.rename(logs: model.logs, groups: groups)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if groups.isEmpty {
                    ContentUnavailableView("Names match", systemImage: "checkmark.circle", description: Text(result ?? "Every exercise is logged under one name."))
                } else {
                    Text("These exercises are logged under more than one name, so their history is split. Tidying rewrites those workouts to the name shown in green.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(groups, id: \.target) { g in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(g.target).font(.title3.weight(.semibold)).foregroundStyle(Theme.lime)
                            ForEach(g.names, id: \.name) { n in
                                HStack {
                                    Text(n.name).foregroundStyle(n.name == g.target ? Color.primary : Color.secondary)
                                    Spacer()
                                    Text("\(n.count) workouts").font(.footnote).foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                        .card()
                    }
                    Text("\(preview.changed.count) workouts will change" + (preview.skipped > 0 ? "; \(preview.skipped) use both spellings and are left alone." : "."))
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Tip: make a backup first (Settings, Backup).").font(.footnote).foregroundStyle(.secondary)
                    Button { confirm = true } label: { Text("Tidy names").limeCapsule(height: 54, enabled: !preview.changed.isEmpty) }
                        .buttonStyle(.plain)
                        .disabled(preview.changed.isEmpty)
                }
            }
            .padding(16)
        }
        .navigationTitle("Exercise names")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Rewrite \(preview.changed.count) workouts?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Tidy names") {
                preview.changed.forEach { model.save($0) }
                result = "Done: \(preview.changed.count) workouts updated."
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This changes your saved workouts. Make a backup first if you haven't.") }
    }
}
