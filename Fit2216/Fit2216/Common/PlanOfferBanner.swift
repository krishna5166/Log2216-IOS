import SwiftUI
import Fit2216Core

/// One line at the top: the feedback loop has new numbers for the plan. Yes puts them in, No leaves the plan alone; tap the line to see what would change.
struct PlanOfferBanner: View {
    @Environment(AppModel.self) private var model
    @State private var showDetails = false

    var body: some View {
        if let offer = model.planOffer {
            VStack(alignment: .leading, spacing: 10) {
                Button { showDetails = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Theme.lime)
                        Text(PlanOffer.line(proposal: offer.proposal, changedCount: offer.changed.count))
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows what would change")
                HStack(spacing: 10) {
                    Button("No") { model.declinePlanOffer() }
                        .buttonStyle(.bordered)
                    Button("Yes, update my numbers") { model.acceptPlanOffer() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.lime)
                        .foregroundStyle(.black)
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .background(.regularMaterial)
            .sheet(isPresented: $showDetails) { PlanOfferDetails(offer: offer) }
        }
    }
}

private struct PlanOfferDetails: View {
    let offer: (proposal: PlanProposal, changed: [String])
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if offer.proposal.changes.isEmpty {
                    Section("Exercises with new numbers") { ForEach(offer.changed, id: \.self) { Text($0) } }
                } else {
                    Section("What would change") {
                        ForEach(Array(offer.proposal.changes.enumerated()), id: \.offset) { _, c in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.exercise).font(.body.weight(.semibold))
                                Text("\(c.field): \(c.from) → \(c.to)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section { Text("Nothing changes unless you tap Yes. These numbers come from your own logged workouts.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("New numbers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
