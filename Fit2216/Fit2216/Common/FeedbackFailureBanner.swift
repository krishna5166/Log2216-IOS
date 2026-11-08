import SwiftUI
import Fit2216Core

/// Shown when the server refused one or more finished workouts for the feedback loop. They are kept (not dropped) until Retry or Discard.
/// The workouts themselves are always safe in the history; this only concerns the plan suggestions.
struct FeedbackFailureBanner: View {
    @Environment(AppModel.self) private var model
    @State private var showDetails = false

    var body: some View {
        let failures = model.feedbackFailures
        if !failures.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button { showDetails = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text(failures.count == 1 ? "One workout wasn't used for suggestions" : "\(failures.count) workouts weren't used for suggestions")
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows why")
                HStack(spacing: 10) {
                    Button("Discard") { model.discardFeedbackFailures() }.buttonStyle(.bordered)
                    Button("Retry") { model.retryFeedbackFailures() }.buttonStyle(.borderedProminent)
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .background(.regularMaterial)
            .sheet(isPresented: $showDetails) {
                NavigationStack {
                    List {
                        ForEach(failures, id: \.session.sessionId) { f in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.session.date).font(.body.weight(.semibold))
                                Text(f.message).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Section { Text("Your workouts are saved either way. Fix the workout if needed, then Retry; or Discard to stop trying.").font(.footnote).foregroundStyle(.secondary) }
                    }
                    .navigationTitle("Not used for suggestions")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}
