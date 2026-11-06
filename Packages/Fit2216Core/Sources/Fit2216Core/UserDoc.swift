import Foundation

public enum UnitSystem: String, Decodable, Equatable, Sendable { case metric, imperial }
public enum Sex: String, Decodable, Equatable, Sendable { case male, female }
public enum Lifestyle: String, Decodable, Equatable, Sendable { case sitting, standing, physical }
public enum SessionsMode: String, Decodable, Equatable, Sendable { case auto, manual }

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
    public var sex: Sex?
    public var age: Double?
    public var weightKg: Double?
    public var lifestyle: Lifestyle?
    public var sessionsMode: SessionsMode?
    public var sessionsPerWeek: Double?

    public init(name: String = "", units: UnitSystem? = nil, gymUnit: WeightUnit? = nil, bodyUnit: WeightUnit? = nil, heightCm: Double? = nil,
                targetWeightKg: Double? = nil, targetDate: String? = nil, goal: Goal? = nil, proteinMin: Double? = nil, proteinMax: Double? = nil,
                sex: Sex? = nil, age: Double? = nil, weightKg: Double? = nil, lifestyle: Lifestyle? = nil, sessionsMode: SessionsMode? = nil, sessionsPerWeek: Double? = nil) {
        self.name = name; self.units = units; self.gymUnitSetting = gymUnit; self.bodyUnitSetting = bodyUnit; self.heightCm = heightCm
        self.targetWeightKg = targetWeightKg; self.targetDate = targetDate; self.goal = goal; self.proteinMin = proteinMin; self.proteinMax = proteinMax
        self.sex = sex; self.age = age; self.weightKg = weightKg; self.lifestyle = lifestyle; self.sessionsMode = sessionsMode; self.sessionsPerWeek = sessionsPerWeek
    }

    private enum Keys: String, CodingKey { case name, units, gymUnit, bodyUnit, heightCm, targetWeightKg, targetDate, goal, proteinMin, proteinMax, sex, age, weightKg, lifestyle, sessionsMode, sessionsPerWeek }
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
        sex = (try? c?.decodeIfPresent(Sex.self, forKey: .sex)) ?? nil
        age = (try? c?.decodeIfPresent(Double.self, forKey: .age)) ?? nil
        weightKg = (try? c?.decodeIfPresent(Double.self, forKey: .weightKg)) ?? nil
        lifestyle = (try? c?.decodeIfPresent(Lifestyle.self, forKey: .lifestyle)) ?? nil
        sessionsMode = (try? c?.decodeIfPresent(SessionsMode.self, forKey: .sessionsMode)) ?? nil
        sessionsPerWeek = (try? c?.decodeIfPresent(Double.self, forKey: .sessionsPerWeek)) ?? nil
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

extension Profile {
    /// The profile fields to write to Firestore, keyed by their dotted path (`profile.heightCm`) so nothing else in the profile is touched.
    /// A nil value means "remove this field". Pass `targets` to keep the protein range in step with the new body details.
    public func updateFields(targets: Targets?) -> [String: Any?] {
        var out: [String: Any?] = [
            "profile.name": name,
            "profile.units": units?.rawValue,
            "profile.gymUnit": gymUnitSetting?.rawValue,
            "profile.bodyUnit": bodyUnitSetting?.rawValue,
            "profile.heightCm": heightCm,
            "profile.weightKg": weightKg,
            "profile.age": age,
            "profile.sex": sex?.rawValue,
            "profile.goal": goal?.rawValue,
            "profile.lifestyle": lifestyle?.rawValue,
            "profile.sessionsMode": sessionsMode?.rawValue,
            "profile.sessionsPerWeek": sessionsPerWeek,
            "profile.targetWeightKg": targetWeightKg,
            "profile.targetDate": targetDate,
        ]
        if let targets { out["profile.proteinMin"] = targets.proteinMin; out["profile.proteinMax"] = targets.proteinMax }
        return out
    }
}
