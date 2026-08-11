import Foundation

// MARK: - Phase

enum Phase: String, Codable, Sendable {
    case idle
    case study
    case rest
    case done

    var title: String {
        switch self {
        case .idle: "Ready"
        case .study: "Studying"
        case .rest: "Break"
        case .done: "Finished"
        }
    }

    var symbol: String {
        switch self {
        case .idle: "play.circle"
        case .study: "book.fill"
        case .rest: "cup.and.saucer.fill"
        case .done: "checkmark.seal.fill"
        }
    }

    var isRunning: Bool { self == .study || self == .rest }
}

// MARK: - Settings

struct StudySettings: Codable, Equatable, Sendable {
    var studyMinutes: Int = 25
    var breakMinutes: Int = 5
    var rounds: Int = 4
    var soundEnabled: Bool = true

    /// Minutes are clamped to at least 1 so a zero-length phase can never make
    /// the phase machine spin.
    mutating func clamp() {
        studyMinutes = min(max(studyMinutes, 1), 180)
        breakMinutes = min(max(breakMinutes, 1), 120)
        rounds = min(max(rounds, 1), 20)
    }
}

// MARK: - Session state

/// The whole session as a value. Nothing here ticks — the state records *when*
/// the current phase ends, and every consumer derives the countdown from that.
/// That is what lets the widget stay correct while nothing is running.
struct SessionState: Codable, Equatable, Sendable {
    var settings = StudySettings()
    var phase: Phase = .idle
    var round: Int = 1
    /// Wall-clock instant the current phase ends. Nil when idle, done, or paused.
    var phaseEnd: Date?
    /// Seconds left in the current phase while paused. Nil when not paused.
    var pausedRemaining: TimeInterval?

    var isPaused: Bool { phase.isRunning && pausedRemaining != nil }

    func duration(of phase: Phase) -> TimeInterval {
        switch phase {
        case .study: Double(settings.studyMinutes) * 60
        case .rest: Double(settings.breakMinutes) * 60
        case .idle, .done: 0
        }
    }

    func remaining(at now: Date = Date()) -> TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        guard let phaseEnd else { return 0 }
        return max(0, phaseEnd.timeIntervalSince(now))
    }

    /// 0...1 through the current phase.
    func progress(at now: Date = Date()) -> Double {
        let total = duration(of: phase)
        guard total > 0 else { return phase == .done ? 1 : 0 }
        return min(max(1 - remaining(at: now) / total, 0), 1)
    }

    /// The range a live countdown should be drawn over.
    func countdownRange(at now: Date = Date()) -> ClosedRange<Date> {
        let end = phaseEnd ?? now.addingTimeInterval(remaining(at: now))
        let start = end.addingTimeInterval(-duration(of: phase))
        return start <= end ? start...end : end...end
    }

    // MARK: Commands

    mutating func start(at now: Date = Date()) {
        settings.clamp()
        phase = .study
        round = 1
        phaseEnd = now.addingTimeInterval(duration(of: .study))
        pausedRemaining = nil
    }

    mutating func togglePause(at now: Date = Date()) {
        guard phase.isRunning else {
            start(at: now)
            return
        }
        if let pausedRemaining {
            phaseEnd = now.addingTimeInterval(pausedRemaining)
            self.pausedRemaining = nil
        } else {
            pausedRemaining = remaining(at: now)
            phaseEnd = nil
        }
    }

    mutating func skip(at now: Date = Date()) {
        guard phase.isRunning else { return }
        let wasPaused = isPaused
        advance()
        if phase.isRunning {
            if wasPaused {
                pausedRemaining = duration(of: phase)
                phaseEnd = nil
            } else {
                phaseEnd = now.addingTimeInterval(duration(of: phase))
                pausedRemaining = nil
            }
        } else {
            phaseEnd = nil
            pausedRemaining = nil
        }
    }

    mutating func reset() {
        phase = .idle
        round = 1
        phaseEnd = nil
        pausedRemaining = nil
    }

    /// study -> break -> next study ... -> break of the last round -> done.
    private mutating func advance() {
        switch phase {
        case .study:
            phase = .rest
        case .rest:
            if round >= settings.rounds {
                phase = .done
            } else {
                round += 1
                phase = .study
            }
        case .idle, .done:
            break
        }
    }

    /// Fast-forwards past any phase boundaries that have already gone by.
    ///
    /// Nothing is running most of the time — the Mac sleeps, the app is quit,
    /// the widget is redrawn hours later — so every reader resolves the stored
    /// state against the current clock before using it.
    func resolved(at now: Date = Date()) -> SessionState {
        var state = self
        var steps = 0
        while state.phase.isRunning,
              state.pausedRemaining == nil,
              let end = state.phaseEnd,
              end <= now,
              steps < 500 {
            steps += 1
            state.advance()
            state.phaseEnd = state.phase.isRunning
                ? end.addingTimeInterval(state.duration(of: state.phase))
                : nil
        }
        return state
    }

    // MARK: Boundaries

    struct Boundary: Equatable, Sendable {
        /// When the phase change happens.
        let date: Date
        /// The phase that is ending.
        let from: Phase
        /// The round that phase belonged to.
        let round: Int
        /// The full state from `date` onwards.
        let state: SessionState
    }

    /// Every phase change still ahead of `now`, in order. Used both to schedule
    /// alerts and to build the widget's timeline.
    func upcomingBoundaries(from now: Date = Date(), limit: Int = 40) -> [Boundary] {
        var boundaries: [Boundary] = []
        var state = resolved(at: now)
        guard !state.isPaused else { return [] }

        while state.phase.isRunning, let end = state.phaseEnd, boundaries.count < limit {
            var next = state
            next.advance()
            next.phaseEnd = next.phase.isRunning
                ? end.addingTimeInterval(next.duration(of: next.phase))
                : nil
            boundaries.append(Boundary(date: end, from: state.phase, round: state.round, state: next))
            state = next
        }
        return boundaries
    }

    /// When the whole session finishes, if it is running and unpaused.
    func finishDate(from now: Date = Date()) -> Date? {
        upcomingBoundaries(from: now).last?.date
    }
}

// MARK: - Formatting

enum Clock {
    /// mm:ss, or h:mm:ss past an hour.
    static func string(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}
