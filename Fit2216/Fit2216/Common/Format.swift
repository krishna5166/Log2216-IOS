import SwiftUI
import Fit2216Core

enum Format {
    /// A kilogram value shown in the person's unit, e.g. "176.4 lb".
    static func weight(kg: Double, unit: WeightUnit) -> String {
        "\(Units.tidy(Units.fromKg(kg, to: unit))) \(unit.rawValue)"
    }

    static func date(_ s: String) -> String {
        guard let d = Dates.parse(s) else { return s }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    static func daysAgo(_ days: Int?) -> String {
        switch days {
        case nil: return "never"
        case 0: return "today"
        case 1: return "yesterday"
        default: return "\(days ?? 0) days ago"
        }
    }
}

extension View {
    /// A rounded card background used across the screens.
    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}
