import SwiftUI
import Fit2216Core

/// Body details and goal. These drive the daily calorie and macro targets, which follow your training and latest weight.
struct AboutMeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    @State private var draft = Profile()
    @State private var heightText = ""
    @State private var feetText = ""
    @State private var inchesText = ""
    @State private var weightText = ""
    @State private var ageText = ""
    @State private var targetText = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var loaded = false

    private var imperial: Bool { draft.units == .imperial }

    var body: some View {
        Form {
            Section("You") {
                TextField("Name", text: $draft.name)
                Picker("Sex", selection: Binding(get: { draft.sex }, set: { draft.sex = $0 })) {
                    Text("Not set").tag(Sex?.none)
                    Text("Male").tag(Sex?.some(.male))
                    Text("Female").tag(Sex?.some(.female))
                }
                HStack { Text("Age"); Spacer(); TextField("years", text: $ageText).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80) }
                Picker("Height", selection: Binding(get: { draft.units ?? .metric }, set: { draft.units = $0 })) {
                    Text("Centimetres").tag(UnitSystem.metric)
                    Text("Feet and inches").tag(UnitSystem.imperial)
                }
                if imperial {
                    HStack { Text("Height"); Spacer(); TextField("ft", text: $feetText).keyboardType(.numberPad).frame(width: 50); TextField("in", text: $inchesText).keyboardType(.decimalPad).frame(width: 50) }
                } else {
                    HStack { Text("Height"); Spacer(); TextField("cm", text: $heightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80) }
                }
                HStack { Text("Weight (\(model.profile.bodyUnit.rawValue))"); Spacer(); TextField("latest", text: $weightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80) }
            }
            Section("Goal") {
                Picker("Goal", selection: Binding(get: { draft.goal ?? .maintain }, set: { draft.goal = $0 })) {
                    Text("Lose fat").tag(Goal.lose); Text("Maintain").tag(Goal.maintain); Text("Build muscle").tag(Goal.gain)
                }
                HStack { Text("Target weight (\(model.profile.bodyUnit.rawValue))"); Spacer(); TextField("optional", text: $targetText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90) }
                Toggle("Reach it by a date", isOn: $hasTargetDate)
                if hasTargetDate { DatePicker("Date", selection: $targetDate, in: Date()..., displayedComponents: .date) }
            }
            Section("Activity") {
                Picker("Daily life", selection: Binding(get: { draft.lifestyle ?? .sitting }, set: { draft.lifestyle = $0 })) {
                    Text("Mostly sitting").tag(Lifestyle.sitting); Text("On my feet").tag(Lifestyle.standing); Text("Physical work").tag(Lifestyle.physical)
                }
                Picker("Training sessions", selection: Binding(get: { draft.sessionsMode ?? .auto }, set: { draft.sessionsMode = $0 })) {
                    Text("From my workouts").tag(SessionsMode.auto); Text("I set it").tag(SessionsMode.manual)
                }
                if draft.sessionsMode == .manual {
                    Stepper("\(Int(draft.sessionsPerWeek ?? 3)) a week", value: Binding(get: { draft.sessionsPerWeek ?? 3 }, set: { draft.sessionsPerWeek = $0 }), in: 0...7, step: 1)
                }
            }
            if let t = Nutrition.computeTargets(current(), autoSessions: Nutrition.avgSessions(plan: model.plan, logs: model.logs, model.now)) {
                Section("Daily targets") {
                    LabeledContent("Calories", value: "\(t.kcal) kcal")
                    LabeledContent("Protein", value: "\(t.proteinMin)–\(t.proteinMax) g")
                    LabeledContent("Carbs", value: "\(t.carbs) g")
                    LabeledContent("Fat", value: "\(t.fat) g")
                    Text("Informational estimates, not medical advice. They follow your goal, your training and your latest weight.").font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Section { Text("Fill in sex, age, height and weight to see your daily targets.").font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Body and targets")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Save") { model.saveProfile(current()); dismiss() } } }
        .onAppear(perform: load)
    }

    /// The profile as typed so far.
    private func current() -> Profile {
        var p = draft
        p.age = Double(ageText)
        let bodyUnit = model.profile.bodyUnit
        p.weightKg = Double(weightText.replacingOccurrences(of: ",", with: ".")).map { Units.toKg($0, from: bodyUnit) } ?? model.profile.weightKg
        if imperial {
            let ft = Double(feetText) ?? 0, inch = Double(inchesText.replacingOccurrences(of: ",", with: ".")) ?? 0
            p.heightCm = ft > 0 || inch > 0 ? (ft * 12 + inch) * 2.54 : nil
        } else {
            p.heightCm = Double(heightText.replacingOccurrences(of: ",", with: "."))
        }
        p.targetWeightKg = Double(targetText.replacingOccurrences(of: ",", with: ".")).map { Units.toKg($0, from: bodyUnit) }
        p.targetDate = hasTargetDate ? Dates.localDate(targetDate) : nil
        return p
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let p = model.profile
        draft = p
        ageText = p.age.map { Units.tidy($0) } ?? ""
        let unit = p.bodyUnit
        weightText = p.weightKg.map { Units.tidy(Units.fromKg($0, to: unit)) } ?? ""
        if let h = p.heightCm {
            heightText = Units.tidy(h)
            let totalInches = h / 2.54
            feetText = String(Int(totalInches / 12))
            inchesText = Units.tidy(totalInches.truncatingRemainder(dividingBy: 12))
        }
        targetText = p.targetWeightKg.map { Units.tidy(Units.fromKg($0, to: unit)) } ?? ""
        if let d = p.targetDate, let parsed = Dates.parse(d) { hasTargetDate = true; targetDate = parsed }
    }
}
