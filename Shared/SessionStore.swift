import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Reads and writes the single shared session. Both the app and the widget
/// extension go through here, so a button pressed on the widget and a button
/// pressed in the app are the same operation.
struct SessionStore {
    static let shared = SessionStore()

    private let key = "study.session.v1"

    func load() -> SessionState {
        guard let data = AppGroup.defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(SessionState.self, from: data) else {
            return SessionState()
        }
        return state
    }

    /// The stored state fast-forwarded to now.
    func current(at now: Date = Date()) -> SessionState {
        load().resolved(at: now)
    }

    func save(_ state: SessionState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    /// Applies a change, reschedules the alerts that follow from it, and asks
    /// the widget to redraw. Every mutation should go through this.
    @discardableResult
    func mutate(at now: Date = Date(), _ change: (inout SessionState) -> Void) -> SessionState {
        var state = current(at: now)
        change(&state)
        save(state)
        AlertScheduler.reschedule(for: state, now: now)
        reloadWidgets()
        return state
    }

    func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
