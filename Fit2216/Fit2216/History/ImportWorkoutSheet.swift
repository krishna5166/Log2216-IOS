import SwiftUI
import UIKit
import Fit2216Core

/// Paste a workout someone shared (from Past sessions, Share workout) and do it today.
struct ImportWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var problem: String?
    let start: (TemplateDay) -> Void

    private var parsed: TemplateDay? { WorkoutCopy.parse(text) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ask for a workout with Share workout (Past sessions), then paste it here.").font(.subheadline).foregroundStyle(.secondary)
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    Button("Paste from clipboard") { text = UIPasteboard.general.string ?? "" }
                        .font(.subheadline.weight(.semibold))

                    if let day = parsed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day.name).font(.title3.weight(.semibold))
                            ForEach(day.exercises, id: \.name) { e in
                                HStack { Text(e.name); Spacer(); Text("\(e.sets) × \(e.reps)").foregroundStyle(.secondary) }.font(.subheadline)
                            }
                        }
                        .card()
                        Button {
                            switch model.startCopy(of: day, logged: nil) {
                            case .ready(let d): dismiss(); start(d)
                            case .blocked(let why): problem = why
                            }
                        } label: { Text("Do this today").limeCapsule(height: 54) }
                        .buttonStyle(.plain)
                    } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("That doesn't look like a shared workout.").font(.footnote).foregroundStyle(Theme.pink)
                    }
                    if let problem { Text(problem).font(.footnote).foregroundStyle(Theme.pink) }
                }
                .padding(16)
            }
            .navigationTitle("Import workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
    }
}
