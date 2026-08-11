import AppKit
import Combine
import Foundation
import SwiftUI

/// The app's view of the session: it ticks once a second so the window and the
/// menu bar can show a live countdown, and it chimes when a phase turns over
/// while the app is running.
@MainActor
final class SessionModel: ObservableObject {
    @Published private(set) var state: SessionState
    @Published private(set) var now: Date = .init()

    private var ticker: AnyCancellable?
    private var lastSeenPhase: Phase
    private var lastSeenRound: Int

    init() {
        let initial = SessionStore.shared.current()
        state = initial
        lastSeenPhase = initial.phase
        lastSeenRound = initial.round

        ticker = Timer.publish(every: 1, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.tick(at: date) }
    }

    // MARK: Derived

    var remaining: TimeInterval { state.remaining(at: now) }
    var progress: Double { state.progress(at: now) }

    /// What the menu bar shows: a countdown while running, an icon otherwise.
    var menuBarTitle: String {
        switch state.phase {
        case .idle: "Study"
        case .study: "📖 \(Clock.string(remaining))"
        case .rest: "☕️ \(Clock.string(remaining))"
        case .done: "✅"
        }
    }

    var summary: String {
        switch state.phase {
        case .idle:
            "\(state.settings.rounds) × \(state.settings.studyMinutes) min study / \(state.settings.breakMinutes) min break"
        case .study, .rest:
            "Round \(state.round) of \(state.settings.rounds)"
        case .done:
            "\(state.settings.rounds) rounds finished"
        }
    }

    /// When the last break ends, so you can see when you'll be free.
    var finishText: String? {
        guard let finish = state.finishDate(from: now) else { return nil }
        return finish.formatted(date: .omitted, time: .shortened)
    }

    // MARK: Commands

    func startOrPause() { apply { $0.togglePause(at: self.now) } }
    func skip() { apply { $0.skip(at: self.now) } }

    func reset() {
        apply { $0.reset() }
        AlertScheduler.cancelAll()
    }

    func update(_ change: (inout StudySettings) -> Void) {
        var settings = state.settings
        change(&settings)
        settings.clamp()
        guard settings != state.settings else { return }
        apply { $0.settings = settings }
    }

    private func apply(_ change: @escaping (inout SessionState) -> Void) {
        let now = Date()
        self.now = now
        state = SessionStore.shared.mutate(at: now, change)
        lastSeenPhase = state.phase
        lastSeenRound = state.round
    }

    // MARK: Ticking

    private func tick(at date: Date) {
        now = date
        // Pick up changes made from the widget's buttons as well as our own
        // clock running past a phase boundary.
        let fresh = SessionStore.shared.current(at: date)
        guard fresh != state else { return }

        let phaseTurnedOver = fresh.phase != lastSeenPhase || fresh.round != lastSeenRound
        state = fresh
        lastSeenPhase = fresh.phase
        lastSeenRound = fresh.round

        if phaseTurnedOver {
            SessionStore.shared.save(fresh)
            SessionStore.shared.reloadWidgets()
            if fresh.settings.soundEnabled { chime(for: fresh.phase) }
        }
    }

    /// The notification carries its own sound; this is the in-app cue on top of
    /// it, which is audible even when notifications are muted in Focus.
    private func chime(for phase: Phase) {
        let name: NSSound.Name = switch phase {
        case .rest: "Glass"
        case .study: "Ping"
        case .done: "Hero"
        case .idle: "Pop"
        }
        NSSound(named: name)?.play()
    }
}
