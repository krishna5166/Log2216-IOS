import SwiftUI
import Fit2216Core

/// The feedback loop on the phone: finished workouts go to the server, and when it has new numbers for the plan the owner is asked
/// (Yes / No). Nothing in the plan changes without Yes.
extension AppModel {
    private func versionKey(_ name: String) -> String { "fit2216.feedback.\(name).\(uid ?? "")" }
    private var acceptedVersion: Int {
        get { UserDefaults.standard.integer(forKey: versionKey("accepted")) }
        set { UserDefaults.standard.set(newValue, forKey: versionKey("accepted")) }
    }
    private var declinedVersion: Int {
        get { UserDefaults.standard.integer(forKey: versionKey("declined")) }
        set { UserDefaults.standard.set(newValue, forKey: versionKey("declined")) }
    }

    /// The proposal to show now, with the exercises it would change, or nil.
    var planOffer: (proposal: PlanProposal, changed: [String])? {
        guard let p = planProposal,
              PlanOffer.shouldShow(proposal: p, plan: plan, acceptedVersion: acceptedVersion, declinedVersion: declinedVersion, workoutOpen: workoutOpen)
        else { return nil }
        return (p, p.applied(to: plan).changed)
    }

    /// Called by `save` for every saved workout. Gives a workout that was just finished today a session id (once) and returns true when it
    /// should be sent. A workout that already has an id, or was finished earlier, is never sent again: sent sessions are final.
    func prepareFeedback(_ log: inout WorkoutLog) -> Bool {
        let id = Logging.documentID(log)
        let stored = logs.first { Logging.documentID($0) == id } ?? archive.first { Logging.documentID($0) == id }
        if log.sessionId == nil, let known = stored?.sessionId { log.sessionId = known }
        // Today's or yesterday's date: a workout that runs past midnight keeps the date it started on.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now).map { Dates.localDate($0) } ?? ""
        guard log.sessionId == nil, stored?.done != true, log.done == true, log.skipped != true, [Dates.localDate(now), yesterday].contains(log.date) else { return false }
        log.sessionId = UUID().uuidString
        return true
    }

    /// Queues a finished workout for the server and tries to send everything waiting.
    func queueFeedback(_ log: WorkoutLog) {
        guard let uid, let session = FeedbackSession.make(from: log, plan: plan) else { return }
        var box = FeedbackOutbox.load(uid)
        if !box.contains(where: { $0.sessionId == session.sessionId }) { box.append(session) }
        FeedbackOutbox.save(box, uid: uid)
        Task { @MainActor in await flushFeedback() }
    }

    /// Sends waiting workouts one at a time (oldest first), then asks for new plan numbers. Safe to call often.
    func flushFeedback() async {
        guard let uid, !flushingFeedback else { return }
        flushingFeedback = true
        defer { flushingFeedback = false }
        let client = FeedbackClient()
        var left: [FeedbackSession] = []
        var anySent = false
        var failed = FeedbackOutbox.loadFailed(uid)
        for session in FeedbackOutbox.load(uid) {
            switch await client.post(session) {
            case .sent: anySent = true
            case .refused(let status, let message):
                failed = FeedbackFailure.recording(FeedbackFailure(session: session, status: status, message: message, at: ISO8601DateFormatter().string(from: Date())), in: failed)
            case .retry: left.append(session)
            }
        }
        guard self.uid == uid else { return } // signed out meanwhile
        FeedbackOutbox.save(left, uid: uid)
        FeedbackOutbox.saveFailed(failed, uid: uid)
        feedbackFailures = failed
        if anySent { await refreshProposal() }
    }

    /// Asks the server whether it has newer plan numbers than the ones already accepted.
    func refreshProposal() async {
        guard let uid else { return }
        let found = await FeedbackClient().plan(since: acceptedVersion)
        guard self.uid == uid else { return }
        if found?.planVersion != planProposal?.planVersion || planProposalBasis == nil { planProposalBasis = plan }
        planProposal = found
    }

    /// Yes: the proposed numbers go into the plan and are saved like any plan edit.
    func acceptPlanOffer() {
        guard !workoutOpen, let p = planProposal else { return }
        savePlan(p.applied(to: plan, basis: planProposalBasis).plan)   // exercises edited since the proposal was shown keep the edit
        acceptedVersion = p.planVersion
        planProposal = nil; planProposalBasis = nil
    }

    /// No: the plan stays as it is, and this version is not offered again (a newer one will be).
    func declinePlanOffer() {
        guard let p = planProposal else { return }
        declinedVersion = p.planVersion
        planProposal = nil; planProposalBasis = nil
    }

    /// Retry the refused workouts: each is rebuilt from its current log (so a corrected log is what is sent); a 409 cannot be fixed by
    /// sending again and stays until discarded.
    func retryFeedbackFailures() {
        guard let uid else { return }
        var keep: [FeedbackFailure] = []
        var box = FeedbackOutbox.load(uid)
        for f in FeedbackOutbox.loadFailed(uid) {
            let log = (logs + archive).first { $0.sessionId == f.session.sessionId }
            guard let body = FeedbackFailure.retryBody(f, rebuilt: log.flatMap { FeedbackSession.make(from: $0, plan: plan) }) else { keep.append(f); continue }
            if !box.contains(where: { $0.sessionId == body.sessionId }) { box.append(body) }
        }
        FeedbackOutbox.save(box, uid: uid)
        FeedbackOutbox.saveFailed(keep, uid: uid)
        feedbackFailures = keep
        Task { @MainActor in await flushFeedback() }
    }

    /// Discard the refused workouts: they stay in the workout history, only the feedback loop does not use them.
    func discardFeedbackFailures() {
        guard let uid else { return }
        FeedbackOutbox.saveFailed([], uid: uid)
        feedbackFailures = []
    }
}
