import Foundation
import Observation
import UserNotifications

/// Step timers of cooking mode. Each one also schedules a local notification with sound, so it
/// is heard when the phone is locked (D-023: the only notifications the app sends; no network).
@MainActor
@Observable
final class CookingTimers {
    /// Step index → when its timer ends.
    private(set) var endsAt: [Int: Date] = [:]
    private let recipeID: String
    private let center = UNUserNotificationCenter.current()

    init(recipeID: String) {
        self.recipeID = recipeID
    }

    func start(step: Int, minutes: Int, title: String, body: String) {
        let end = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        endsAt[step] = end
        let id = identifier(step)
        Task {
            // Asked once, on the first timer; without permission the timer still counts on screen.
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(end.timeIntervalSinceNow, 1), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    func stop(step: Int) {
        endsAt[step] = nil
        center.removePendingNotificationRequests(withIdentifiers: [identifier(step)])
        center.removeDeliveredNotifications(withIdentifiers: [identifier(step)])
    }

    func stopAll() {
        for step in Array(endsAt.keys) { stop(step: step) }
    }

    func remaining(step: Int, at now: Date) -> TimeInterval? {
        endsAt[step].map { max($0.timeIntervalSince(now), 0) }
    }

    private func identifier(_ step: Int) -> String { "cook-\(recipeID)-\(step)" }
}

/// Shows timer notifications with sound while the app is open too.
final class TimerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TimerNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

extension TimeInterval {
    /// "4:05"
    var clockText: String {
        let total = Int(self.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
