import Foundation

/// What an exercise is done with. Progression is tracked per exercise and equipment, so a barbell bench and a dumbbell bench never share numbers.
/// The raw values are the IDs of the planned feedback-loop API contract (`docs/API_CONTRACT.md` in `log2216-api`, still a draft).
public enum Equipment: String, Codable, CaseIterable, Sendable {
    case barbell, dumbbell, smith, machine, cable, kettlebell, bodyweight, band, other

    public var label: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .smith: "Smith machine"
        case .machine: "Machine"
        case .cable: "Cable"
        case .kettlebell: "Kettlebell"
        case .bodyweight: "Bodyweight"
        case .band: "Band"
        case .other: "Other"
        }
    }

    /// A guess from the exercise name, used until equipment is chosen. Nil when the name says nothing; it never guesses wrong on purpose.
    public static func guess(from name: String) -> Equipment? {
        // Spelled out here, not through ExerciseNames.key: that maps old names to current ones and would drop the equipment word.
        let words = ExerciseNames.tidy(name).lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }
        let n = " " + String(words).split(separator: " ").joined(separator: " ") + " "
        let rules: [(Equipment, [String])] = [
            (.smith, [" smith "]),
            (.kettlebell, [" kettlebell "]),
            (.dumbbell, [" dumbbell ", " dumbell ", " db "]),
            (.barbell, [" barbell ", " ez bar ", " t bar "]),
            (.cable, [" cable "]),
            (.machine, [" machine ", " pec deck ", " leg press ", " leg extension ", " leg extensions ", " hack squat ", " hack squats "]),
            (.band, [" band "]),
            (.bodyweight, [" push up ", " push ups ", " pull up ", " pull ups ", " chin up ", " chin ups ", " dip ", " dips ", " plank ", " sit up ", " sit ups "]),
        ]
        for (equipment, words) in rules where words.contains(where: n.contains) { return equipment }
        return nil
    }
}
