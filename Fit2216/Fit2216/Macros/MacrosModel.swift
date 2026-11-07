import SwiftUI
import Observation
import Network
import Fit2216Core

/// Today's food: the entries, the text being written, and turning text into calories through the server.
@Observable
final class MacrosModel {
    enum Status: Equatable {
        case idle
        case parsing
        case failed(String)
    }

    /// An estimate waiting for the person to check it before it becomes a card.
    struct Review: Identifiable {
        let id = UUID()
        let text: String
        var items: [Meal]
        var fromMemory: Bool   // true when it came from this phone (an earlier estimate or a correction), false when the AI just worked it out
    }

    var cards: [FoodCard] = []
    var review: Review?
    var text = ""
    var editing: String?
    var status: Status = .idle
    private(set) var date = ""
    /// False until today's food has been read. Nothing is written before then, so an unread day is never overwritten.
    private(set) var loaded = false
    var loadError: String?

    @ObservationIgnored private var stash = ""
    @ObservationIgnored private let ai = AIClient()
    /// Routes food saves through the app's save tracker (set by the screen), so a refused or waiting save shows the same notice as a workout.
    @ObservationIgnored var track: (((@escaping (Error?) -> Void) -> Void)) -> Void = { write in write { _ in } }
    @ObservationIgnored private let monitor = NWPathMonitor()
    /// What to run again when the connection comes back after a "no connection" or "too slow" failure.
    @ObservationIgnored private var pendingRetry: (() async -> Void)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.connectionBack() }
        }
        monitor.start(queue: DispatchQueue(label: "fit2216.macros.network"))
    }

    deinit { monitor.cancel() }

    private func connectionBack() async {
        guard let retry = pendingRetry, case .failed = status else { return }
        pendingRetry = nil
        await retry()
    }

    var totals: Totals { Food.dayTotals(cards) }

    func load(uid: String, date: String, service: FirestoreService) async {
        self.date = date
        loaded = false
        loadError = nil
        cards = []; text = ""; editing = nil; stash = ""; status = .idle
        do {
            let day = try await service.loadFoodDay(uid: uid, date: date)
            cards = day.cards
            text = day.draft ?? ""
            loaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func persist(uid: String, targets: Targets?, service: FirestoreService) {
        guard loaded else { return }
        // No meals means no day to score: opening the screen must not store a 0% day.
        let pct = cards.isEmpty ? nil : Food.completionPercent(totals, targets: targets)
        let day = FoodDay(cards: cards, draft: text.isEmpty ? nil : text, pct: pct)
        let date = self.date
        track { done in service.saveFoodDay(uid: uid, date: date, day: day, completion: done) }
    }

    /// Saves the unsent text (when the app goes to the background or the screen closes).
    func saveDraft(uid: String, targets: Targets?, service: FirestoreService) {
        persist(uid: uid, targets: targets, service: service)
    }

    func submit(uid: String, targets: Targets?, service: FirestoreService) async {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard loaded, !value.isEmpty, status != .parsing else { return }
        status = .parsing
        pendingRetry = nil
        let items: [Meal]
        var fromMemory = false
        if let known = FoodMemory.lookup(uid: uid, text: value) {
            items = known // worked out before: no request
            fromMemory = true
        } else {
            do {
                items = try await ai.meals(for: value)
                FoodMemory.store(uid: uid, text: value, meals: items)
            } catch {
                status = .failed(error.localizedDescription)
                if let failure = error as? AIClient.Failure {
                    switch failure {
                    case .offline, .tooSlow: pendingRetry = { [weak self] in await self?.submit(uid: uid, targets: targets, service: service) }
                    default: break
                    }
                }
                return
            }
        }
        // Nothing is saved yet: the estimate is shown for the person to check and correct first.
        review = Review(text: value, items: items, fromMemory: fromMemory)
        status = .idle
    }

    /// Saves the (possibly corrected) estimate as a card. A correction is remembered for the same text, so it is not estimated wrongly again.
    func confirmReview(_ reviewed: [Meal], uid: String, targets: Targets?, service: FirestoreService) {
        guard let review else { return }
        let items = Food.cleaned(reviewed)
        guard !items.isEmpty else { return }
        FoodMemory.store(uid: uid, text: review.text, meals: items)
        let id = editing ?? String(UUID().uuidString.prefix(8)).lowercased()
        let card = FoodCard(id: id, text: review.text, items: items)
        if editing != nil { cards = cards.map { $0.id == id ? card : $0 } } else { cards.append(card) }
        editing = nil
        text = stash
        stash = ""
        self.review = nil
        persist(uid: uid, targets: targets, service: service)
    }

    /// Closes the review without saving; the text stays in the box to change or send again.
    func cancelReview() { review = nil }

    func open(_ card: FoodCard) {
        if editing == nil { stash = text } // keep a half-written entry while another one is edited
        editing = card.id
        text = card.text
        status = .idle
    }

    func cancelEdit() {
        editing = nil
        text = stash
        stash = ""
        status = .idle
    }

    func removeEditing(uid: String, targets: Targets?, service: FirestoreService) {
        guard let id = editing else { return }
        cards.removeAll { $0.id == id }
        editing = nil
        text = stash
        stash = ""
        persist(uid: uid, targets: targets, service: service)
    }
}
