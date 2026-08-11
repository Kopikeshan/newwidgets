import AppIntents
import WidgetKit

/// The widget's buttons. These run in the extension, mutate the shared session,
/// and re-post the alerts — the same code path the app's buttons use, so the
/// two stay in step.

struct StartPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Start or Pause"
    static var description = IntentDescription("Starts the session, or pauses and resumes it.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        SessionStore.shared.mutate { $0.togglePause() }
        return .result()
    }
}

struct SkipPhaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Phase"
    static var description = IntentDescription("Jumps straight to the next study or break phase.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        SessionStore.shared.mutate { $0.skip() }
        return .result()
    }
}

struct ResetSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Session"
    static var description = IntentDescription("Clears the session and cancels its alerts.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        SessionStore.shared.mutate { $0.reset() }
        AlertScheduler.cancelAll()
        return .result()
    }
}
