import Foundation
import UserNotifications

/// Schedules the alert for the phase that is running.
///
/// Only ever one: because a finished phase waits to be started rather than
/// rolling on, nothing past the current phase has a known time yet. The next
/// alert is scheduled when you press Start.
enum AlertScheduler {
    private static let identifier = "study.phase-end"

    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func reschedule(for state: SessionState, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard state.isCounting, let end = state.phaseEnd else { return }
        let delay = end.timeIntervalSince(now)
        guard delay > 0.5 else { return }

        let content = UNMutableNotificationContent()
        // The design's banner shows the app name and a single sentence, with no
        // separate title line — which is what an empty title renders as.
        content.body = body(for: state)
        content.sound = state.settings.soundEnabled ? .default : nil

        center.add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        ))
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// What the phase now running will say when it ends.
    private static func body(for state: SessionState) -> String {
        let settings = state.settings
        switch state.phase {
        case .study where state.round >= settings.rounds:
            return "All \(settings.rounds) rounds done. Nice work."
        case .study:
            let left = settings.rounds - state.round
            let rounds = left == 1 ? "1 round left" : "\(left) rounds left"
            return "\(settings.studyMinutes) min of study done. \(settings.breakMinutes) min break — \(rounds)."
        case .rest:
            let next = min(state.round + 1, settings.rounds)
            return "Break over. Round \(next) of \(settings.rounds) — \(settings.studyMinutes) min of study."
        case .idle, .done:
            return "Phase finished."
        }
    }
}
