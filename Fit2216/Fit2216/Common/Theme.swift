import SwiftUI

/// The look of the app: black, rounded dark cards, big coloured numbers (like Apple's Fitness app).
enum Theme {
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.10)
    static let pink = Color(red: 0.98, green: 0.10, blue: 0.35)
    static let cyan = Color(red: 0.35, green: 0.85, blue: 0.95)
    static let purple = Color(red: 0.62, green: 0.55, blue: 0.95)
}

/// A big rounded number with its small bold unit beside it, e.g. "588/500 CAL".
struct BigValue: View {
    let value: String
    var unit: String = ""
    let color: Color
    var size: CGFloat = 34

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: size, weight: .medium, design: .rounded))
                .monospacedDigit()
            if !unit.isEmpty {
                Text(unit.uppercased()).font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// A progress ring that fills clockwise from the top.
struct Ring: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    var line: CGFloat = 18

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: line)
            if progress > 0 {
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.6), value: progress)
    }
}

extension View {
    /// The big lime call-to-action button look (use inside a plain-style Button label).
    func limeCapsule(height: CGFloat = 58, enabled: Bool = true) -> some View {
        self.font(.title3.bold())
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(.black)
            .background(Theme.lime, in: Capsule())
            .opacity(enabled ? 1 : 0.35)
    }
}

/// A titled card: the building block of every screen.
struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty { Text(title).font(.title3.weight(.semibold)) }
            content
        }
        .card()
    }
}
