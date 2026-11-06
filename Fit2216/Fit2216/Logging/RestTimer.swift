import SwiftUI
import Observation
import UserNotifications
import UIKit

/// The rest countdown between sets. It is a deadline, not a counter, so it keeps the right time when the app is in the background,
/// and a local notification tells you when it ends.
@Observable
final class RestTimer {
    private(set) var deadline: Date?

    private static let notificationID = "fit2216.rest"

    func start(seconds: Int) {
        deadline = Date().addingTimeInterval(Double(seconds))
        schedule(after: seconds)
    }

    func add(_ seconds: Int) {
        guard let current = deadline else { return }
        let next = current.addingTimeInterval(Double(seconds))
        if next.timeIntervalSinceNow <= 1 { stop(); return }
        deadline = next
        schedule(after: Int(next.timeIntervalSinceNow.rounded()))
    }

    func stop() {
        deadline = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func schedule(after seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        let content = UNMutableNotificationContent()
        content.title = "Rest is over"
        content.body = "Time for your next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
