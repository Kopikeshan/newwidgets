import AppIntents
import WidgetKit

/// The widget's buttons. They run in the extension, mutate the one shared
/// session, and reschedule the alert — the same path the app's buttons take.

struct ToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Start or Pause"
    static var description = IntentDescription("Starts the queued phase, or pauses and resumes the running one.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let now = Date()
        SessionStore.shared.mutate(at: now) { $0.toggle(at: now) }
        return .result()
    }
}

struct SkipPhaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Phase"
    static var description = IntentDescription("Ends the current phase early and queues the next one.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let now = Date()
        SessionStore.shared.mutate(at: now) { $0.skip(at: now) }
        return .result()
    }
}

struct ResetSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Session"
    static var description = IntentDescription("Clears the session and cancels its alert.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let now = Date()
        SessionStore.shared.mutate(at: now) { $0.reset(at: now) }
        AlertScheduler.cancel()
        return .result()
    }
}
