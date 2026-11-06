import SwiftUI
import Fit2216Core

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    @State private var showSoon = false

    var body: some View {
        let now = model.now
        let session = Summary.today(plan: model.plan, logs: model.logs, now)
        let streak = Summary.streak(plan: model.plan, logs: model.logs, now)

        ScrollView {
            VStack(spacing: 20) {
                RingsPlaceholder()
                if let session {
                    SessionCard(session: session, streak: streak)
                } else {
                    ContentUnavailableView("No plan yet", systemImage: "calendar", description: Text("Add a plan in the Workout tab."))
                }
            }
            .padding()
        }
        .navigationTitle("Summary")
        .safeAreaInset(edge: .bottom) {
            StartBar(session: session) { showSoon = true }
        }
        .alert("Logging comes next", isPresented: $showSoon) { Button("OK", role: .cancel) {} }
    }
}

/// Stand-in for Apple's activity rings, which come from Apple Health in a later step.
private struct RingsPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ring(0.8, color: .red, size: 120)
                ring(0.6, color: .green, size: 90)
                ring(0.4, color: .cyan, size: 60)
            }
            Text("Activity rings (from Apple Health) will appear here.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func ring(_ progress: Double, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 12)
            Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

private struct SessionCard: View {
    let session: TodaySession
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.isToday ? "Today" : "Next up").font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
                    Text(session.day.name).font(.title2.bold())
                }
                Spacer()
                Label("\(streak)", systemImage: "flame.fill").foregroundStyle(.orange).font(.headline)
                    .accessibilityLabel("Workout streak \(streak)")
            }

            if !session.muscles.isEmpty {
                Text(session.muscles.map(\.label).joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
            }

            switch session.state {
            case .rest:
                Text("Rest day. Recovery is part of the plan.").font(.subheadline)
            case .skipped:
                Text("Skipped today.").font(.subheadline)
            default:
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(session.loggedSets), total: Double(max(session.plannedSets, 1)))
                    Text("\(session.loggedSets) of \(session.plannedSets) sets" + (session.state == .finished ? " · finished" : "")).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// The Start button, pinned above the tab bar so it never scrolls away.
private struct StartBar: View {
    let session: TodaySession?
    let action: () -> Void

    private var title: String {
        switch session?.state {
        case .inProgress: return "Continue"
        case .finished: return "Review"
        case .rest: return "Rest day"
        case .skipped: return "Skipped"
        default: return "Start"
        }
    }

    var body: some View {
        Button(action: action) { Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6) }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(session == nil || session?.state == .rest || session?.state == .skipped)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
    }
}

#Preview {
    NavigationStack { SummaryView() }.environment(AppModel())
}
