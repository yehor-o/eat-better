import AVFoundation
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
    /// Rings inside the app when a timer ends, with or without notification permission.
    private var alarms: [Int: Task<Void, Never>] = [:]
    private var player: AVAudioPlayer?

    init(recipeID: String) {
        self.recipeID = recipeID
    }

    func start(step: Int, minutes: Int, title: String, body: String) {
        let end = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        endsAt[step] = end
        alarms[step]?.cancel()
        alarms[step] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled, let self, self.endsAt[step] == end else { return }
            self.ring()
        }
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
        alarms[step]?.cancel()
        alarms[step] = nil
        player?.stop()
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

    /// Three short beeps, loud enough for a kitchen, also with the ring switch on silent.
    private func ring() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(data: Self.beeps)
        player?.numberOfLoops = 2
        player?.play()
    }

    /// A tiny WAV made in code: 3 × (0.25 s of 880 Hz + 0.15 s of silence).
    private static let beeps: Data = {
        let rate = 22_050
        var samples: [Int16] = []
        for _ in 0..<3 {
            for i in 0..<(rate / 4) {
                let fade = min(1, Double(rate / 4 - i) / 400) // no click at the end
                samples.append(Int16(sin(2 * .pi * 880 * Double(i) / Double(rate)) * 20_000 * fade))
            }
            samples += Array(repeating: 0, count: rate * 15 / 100)
        }
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + bytes))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(rate)); append(UInt32(rate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(bytes))
        samples.forEach { append($0) }
        return data
    }()
}

/// Shows timer notifications with sound while the app is open too.
final class TimerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TimerNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // The app rings by itself while open (CookingTimers.ring), so no second sound here.
        [.banner, .list]
    }
}

extension TimeInterval {
    /// "4:05"
    var clockText: String {
        let total = Int(self.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
