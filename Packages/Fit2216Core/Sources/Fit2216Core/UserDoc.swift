import Foundation

public enum UnitSystem: String, Decodable, Equatable, Sendable { case metric, imperial }

/// The parts of the web app's profile the iPhone app reads. Everything is optional and unknown fields are ignored.
public struct Profile: Decodable, Equatable, Sendable {
    public var name: String
    public var units: UnitSystem?
    public var gymUnitSetting: WeightUnit?
    public var bodyUnitSetting: WeightUnit?
    public var heightCm: Double?
    public var targetWeightKg: Double?
    public var targetDate: String?
    public var goal: Goal?
    public var proteinMin: Double?
    public var proteinMax: Double?

    public init(name: String = "", units: UnitSystem? = nil, gymUnit: WeightUnit? = nil, bodyUnit: WeightUnit? = nil, heightCm: Double? = nil,
                targetWeightKg: Double? = nil, targetDate: String? = nil, goal: Goal? = nil, proteinMin: Double? = nil, proteinMax: Double? = nil) {
        self.name = name; self.units = units; self.gymUnitSetting = gymUnit; self.bodyUnitSetting = bodyUnit; self.heightCm = heightCm
        self.targetWeightKg = targetWeightKg; self.targetDate = targetDate; self.goal = goal; self.proteinMin = proteinMin; self.proteinMax = proteinMax
    }

    private enum Keys: String, CodingKey { case name, units, gymUnit, bodyUnit, heightCm, targetWeightKg, targetDate, goal, proteinMin, proteinMax }
    public init(from decoder: Decoder) throws {
        let c = try? decoder.container(keyedBy: Keys.self)
        name = c?.lenientString(.name) ?? ""
        units = (try? c?.decodeIfPresent(UnitSystem.self, forKey: .units)) ?? nil
        gymUnitSetting = (try? c?.decodeIfPresent(WeightUnit.self, forKey: .gymUnit)) ?? nil
        bodyUnitSetting = (try? c?.decodeIfPresent(WeightUnit.self, forKey: .bodyUnit)) ?? nil
        heightCm = (try? c?.decodeIfPresent(Double.self, forKey: .heightCm)) ?? nil
        targetWeightKg = (try? c?.decodeIfPresent(Double.self, forKey: .targetWeightKg)) ?? nil
        targetDate = c?.lenientString(.targetDate)
        goal = (try? c?.decodeIfPresent(Goal.self, forKey: .goal)) ?? nil
        proteinMin = (try? c?.decodeIfPresent(Double.self, forKey: .proteinMin)) ?? nil
        proteinMax = (try? c?.decodeIfPresent(Double.self, forKey: .proteinMax)) ?? nil
    }

    /// Unit for set weights, volume and lifts. Older profiles only had `units`, which drove both.
    public var gymUnit: WeightUnit { gymUnitSetting ?? (units == .imperial ? .lb : .kg) }
    /// Unit for the body-weight log and chart.
    public var bodyUnit: WeightUnit { bodyUnitSetting ?? (units == .imperial ? .lb : .kg) }
}

/// `users/{uid}`: the plan, exercise library and profile. Bad data is repaired while reading, never thrown on.
public struct UserDoc: Decodable, Equatable, Sendable {
    public var plan: [TemplateDay]
    public var library: [String]
    public var profile: Profile

    public init(plan: [TemplateDay] = [], library: [String] = [], profile: Profile = Profile()) { self.plan = plan; self.library = library; self.profile = profile }

    private enum Keys: String, CodingKey { case plan, library, profile }
    public init(from decoder: Decoder) throws {
        let c = try? decoder.container(keyedBy: Keys.self)
        plan = (try? c?.decodeIfPresent(LossyArray<TemplateDay>.self, forKey: .plan))??.elements ?? []
        library = (try? c?.decodeIfPresent([String].self, forKey: .library)) ?? []
        profile = (try? c?.decodeIfPresent(Profile.self, forKey: .profile)) ?? Profile()
    }
}

public enum FirestoreDecoding {
    /// Converts a Firestore document (already a dictionary of plain values) into a model. Returns nil when it cannot be turned into JSON.
    public static func decode<T: Decodable>(_ type: T.Type, from object: [String: Any]) -> T? {
        guard JSONSerialization.isValidJSONObject(object), let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
