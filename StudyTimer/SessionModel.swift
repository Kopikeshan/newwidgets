import AppKit
import Combine
import Foundation
import SwiftUI

/// The app's live view of the session: ticks once a second so the popover and
/// the menu bar stay current, and chimes when a phase turns over.
@MainActor
final class SessionModel: ObservableObject {
    @Published private(set) var state: SessionState
    @Published private(set) var now: Date = .init()

    private var ticker: AnyCancellable?
    private var lastPhase: Phase
    private var lastAwaiting: Awaiting?

    init() {
        let initial = SessionStore.shared.current()
        state = initial
        lastPhase = initial.phase
        lastAwaiting = initial.awaiting

        ticker = Timer.publish(every: 1, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.tick(at: date) }
    }

    // MARK: Derived

    var remaining: TimeInterval { state.remaining(at: now) }
    var ringFraction: Double { state.ringFraction(at: now) }
    var timeText: String { state.timeText(at: now) }
    var todayText: String { state.todayText(at: now) }

    // MARK: Commands

    func toggle() { apply { $0.toggle(at: self.now) } }
    func skip() { apply { $0.skip(at: self.now) } }

    func reset() {
        apply { $0.reset(at: self.now) }
        AlertScheduler.cancel()
    }

    func apply(_ preset: StudySettings.Preset) {
        apply { $0.apply(preset, at: self.now) }
    }

    func bumpStudy(_ delta: Int) { bump { $0.studyMinutes += delta } }
    func bumpBreak(_ delta: Int) { bump { $0.breakMinutes += delta } }
    func bumpRounds(_ delta: Int) { bump { $0.rounds += delta } }

    func setSoundEnabled(_ enabled: Bool) {
        bump { $0.soundEnabled = enabled }
    }

    /// The "Test" affordance beside the chime toggle.
    func testChime() { chime(afterStudy: true) }

    private func bump(_ change: (inout StudySettings) -> Void) {
        var settings = state.settings
        change(&settings)
        settings.clamp()
        guard settings != state.settings else { return }
        apply { $0.settings = settings }
    }

    private func apply(_ change: @escaping (inout SessionState) -> Void) {
        let instant = Date()
        now = instant
        state = SessionStore.shared.mutate(at: instant, change)
        lastPhase = state.phase
        lastAwaiting = state.awaiting
    }

    // MARK: Ticking

    private func tick(at date: Date) {
        now = date
        // Picks up both our own clock crossing a phase end and any change the
        // widget's buttons made behind our back.
        let fresh = SessionStore.shared.current(at: date)
        guard fresh != state else { return }

        let turnedOver = fresh.phase != lastPhase || fresh.awaiting != lastAwaiting
        let endedStudy = lastAwaiting == nil && (fresh.awaiting == .rest || (fresh.phase == .done && lastPhase == .study))

        state = fresh
        lastPhase = fresh.phase
        lastAwaiting = fresh.awaiting

        if turnedOver {
            SessionStore.shared.save(fresh)
            SessionStore.shared.reloadWidgets()
            if fresh.settings.soundEnabled { chime(afterStudy: endedStudy) }
        }
    }

    /// The prototype plays a rising pair of notes when study gives way to a
    /// break and a falling pair on the way back. System sounds are the nearest
    /// equivalent: bright going into a break, duller coming out of one.
    private func chime(afterStudy: Bool) {
        let name: NSSound.Name = afterStudy ? "Glass" : "Bottle"
        NSSound(named: name)?.play()
    }
}
