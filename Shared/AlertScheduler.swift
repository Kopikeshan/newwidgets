import Foundation
import UserNotifications

/// Schedules a local notification for every phase change still ahead.
///
/// This is what actually alerts you. Because the whole session is deterministic
/// once it starts, all of the alerts can be posted up front — they still fire
/// while the app is in the background, and they survive the widget extension
/// being torn down between button presses.
enum AlertScheduler {
    private static let prefix = "study.boundary."

    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func reschedule(for state: SessionState, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)

            // Local notifications cap out at 64 pending; a session is far
            // smaller than that, but stay well clear anyway.
            for (index, boundary) in state.upcomingBoundaries(from: now).prefix(32).enumerated() {
                let delay = boundary.date.timeIntervalSince(now)
                guard delay > 0.5 else { continue }

                let content = UNMutableNotificationContent()
                let text = message(for: boundary, settings: state.settings)
                content.title = text.title
                content.body = text.body
                content.sound = state.settings.soundEnabled ? .default : nil

                let request = UNNotificationRequest(
                    identifier: "\(prefix)\(index)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                )
                center.add(request)
            }
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }
    }

    private static func message(
        for boundary: SessionState.Boundary,
        settings: StudySettings
    ) -> (title: String, body: String) {
        switch (boundary.from, boundary.state.phase) {
        case (.study, _):
            return (
                "Break time",
                "Round \(boundary.round) of \(settings.rounds) done. Take \(settings.breakMinutes) min."
            )
        case (.rest, .study):
            return (
                "Back to it",
                "Round \(boundary.state.round) of \(settings.rounds) — \(settings.studyMinutes) min of study."
            )
        case (.rest, _):
            let total = settings.rounds * settings.studyMinutes
            return (
                "Session complete",
                "\(settings.rounds) rounds done — \(total) minutes of study. Nice."
            )
        default:
            return ("Study timer", "Phase finished.")
        }
    }
}
