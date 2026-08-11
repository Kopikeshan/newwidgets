import Foundation

// MARK: - Phase

enum Phase: String, Codable, Sendable {
    case idle
    case study
    case rest
    case done

    var isRunning: Bool { self == .study || self == .rest }
}

/// A phase has finished and the next one is queued, waiting to be started.
///
/// This is the design's central behaviour: the timer never rolls straight from
/// study into a break. It stops, chimes, shows a takeover, and waits for you.
enum Awaiting: String, Codable, Sendable {
    case rest
    case study
}

// MARK: - Settings

struct StudySettings: Codable, Equatable, Sendable {
    var studyMinutes: Int = 45
    var breakMinutes: Int = 15
    var rounds: Int = 3
    var soundEnabled: Bool = true

    /// Ranges and steps come straight from the prototype's steppers.
    static let studyRange = 5...120
    static let breakRange = 5...60
    static let roundsRange = 1...8
    static let minuteStep = 5

    mutating func clamp() {
        studyMinutes = min(max(studyMinutes, StudySettings.studyRange.lowerBound), StudySettings.studyRange.upperBound)
        breakMinutes = min(max(breakMinutes, StudySettings.breakRange.lowerBound), StudySettings.breakRange.upperBound)
        rounds = min(max(rounds, StudySettings.roundsRange.lowerBound), StudySettings.roundsRange.upperBound)
    }

    /// The last break is never served — a session ends on a study phase.
    var totalMinutes: Int { studyMinutes * rounds + breakMinutes * (rounds - 1) }

    struct Preset: Identifiable, Sendable {
        var id: String { title }
        let title: String
        let study: Int
        let rest: Int
        let rounds: Int
    }

    static let presets: [Preset] = [
        Preset(title: "45 / 15", study: 45, rest: 15, rounds: 3),
        Preset(title: "25 / 5", study: 25, rest: 5, rounds: 4),
        Preset(title: "50 / 10", study: 50, rest: 10, rounds: 3),
        Preset(title: "90 / 20", study: 90, rest: 20, rounds: 2)
    ]

    func matches(_ preset: Preset) -> Bool {
        studyMinutes == preset.study && breakMinutes == preset.rest && rounds == preset.rounds
    }
}

// MARK: - Stats

struct Stats: Codable, Equatable, Sendable {
    /// The day `studiedSeconds` belongs to; anything older is cleared.
    var dayStart: Date?
    var studiedSeconds: TimeInterval = 0
    var streak: Int = 0
    var lastStudyDay: Date?

    mutating func rollOver(to now: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard dayStart != today else { return }
        dayStart = today
        studiedSeconds = 0

        // A streak survives one night. Two nights without study and it's gone.
        if let last = lastStudyDay,
           let gap = calendar.dateComponents([.day], from: last, to: today).day,
           gap > 1 {
            streak = 0
        }
    }

    mutating func noteStudy(on instant: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: instant)
        guard lastStudyDay != day else { return }
        if let last = lastStudyDay,
           let gap = calendar.dateComponents([.day], from: last, to: day).day,
           gap == 1 {
            streak += 1
        } else {
            streak = 1
        }
        lastStudyDay = day
    }
}

// MARK: - Session state

/// The whole session as a value.
///
/// Nothing here ticks. A running phase records the instant it ends, and every
/// reader derives the countdown from the clock — which is what keeps the widget
/// right after the Mac has been asleep.
struct SessionState: Codable, Equatable, Sendable {
    var settings = StudySettings()
    var phase: Phase = .idle
    var round: Int = 1
    /// Set only while a phase is genuinely counting down.
    var phaseEnd: Date?
    /// Seconds left in the phase, set only while paused.
    var pausedRemaining: TimeInterval?
    /// Set when a phase has finished and the next is queued.
    var awaiting: Awaiting?
    var stats = Stats()
    /// When the current stretch of study time started accruing, if it is.
    var accrualStart: Date?

    // MARK: Derived

    var isPaused: Bool { phase.isRunning && awaiting == nil && pausedRemaining != nil }
    var isAwaiting: Bool { awaiting != nil }
    var isCounting: Bool { phase.isRunning && awaiting == nil && pausedRemaining == nil && phaseEnd != nil }

    /// True when the screen should be showing break colours — either a break is
    /// running, or a break just ended and study is queued next.
    var isBreakish: Bool { phase == .rest || awaiting == .study }

    func duration(of phase: Phase) -> TimeInterval {
        switch phase {
        case .study: Double(settings.studyMinutes) * 60
        case .rest: Double(settings.breakMinutes) * 60
        case .idle, .done: 0
        }
    }

    /// The length of the phase the ring is currently drawn against.
    var ringTotal: TimeInterval {
        isBreakish ? Double(settings.breakMinutes) * 60 : Double(settings.studyMinutes) * 60
    }

    func remaining(at now: Date) -> TimeInterval {
        switch phase {
        case .idle:
            return Double(settings.studyMinutes) * 60
        case .done:
            return 0
        case .study, .rest:
            if awaiting != nil { return 0 }
            if let pausedRemaining { return pausedRemaining }
            guard let phaseEnd else { return 0 }
            return max(0, phaseEnd.timeIntervalSince(now))
        }
    }

    /// 1 when the phase has just begun, 0 when it is spent. The ring depletes.
    func ringFraction(at now: Date) -> Double {
        guard ringTotal > 0 else { return 0 }
        return min(max(remaining(at: now) / ringTotal, 0), 1)
    }

    /// The range a live countdown is drawn over, for `Text(timerInterval:)`.
    func countdownRange(at now: Date) -> ClosedRange<Date> {
        let end = phaseEnd ?? now
        let start = end.addingTimeInterval(-duration(of: phase))
        return start <= end ? start...end : end...end
    }

    /// Study time banked today, including the stretch currently running.
    func studiedToday(at now: Date) -> TimeInterval {
        var total = stats.studiedSeconds
        if let accrualStart {
            let cap = min(now, phaseEnd ?? now)
            total += max(0, cap.timeIntervalSince(accrualStart))
        }
        return total
    }

    // MARK: Commands

    mutating func toggle(at now: Date) {
        stats.rollOver(to: now)

        // A queued phase is waiting: this press starts it.
        if let awaiting {
            commitStudy(upTo: now)
            phase = awaiting == .rest ? .rest : .study
            phaseEnd = now.addingTimeInterval(duration(of: phase))
            pausedRemaining = nil
            self.awaiting = nil
            if phase == .study { accrualStart = now }
            return
        }

        switch phase {
        case .done:
            reset(at: now)
        case .idle:
            settings.clamp()
            phase = .study
            round = 1
            phaseEnd = now.addingTimeInterval(duration(of: .study))
            pausedRemaining = nil
            accrualStart = now
        case .study, .rest:
            if let pausedRemaining {
                phaseEnd = now.addingTimeInterval(pausedRemaining)
                self.pausedRemaining = nil
                if phase == .study { accrualStart = now }
            } else {
                pausedRemaining = remaining(at: now)
                commitStudy(upTo: now)
                phaseEnd = nil
            }
        }
    }

    /// Ends the current phase early. Like reaching zero, it queues the next
    /// phase rather than starting it.
    mutating func skip(at now: Date) {
        guard phase.isRunning, awaiting == nil else { return }
        stats.rollOver(to: now)
        commitStudy(upTo: now)
        finishPhase()
    }

    mutating func reset(at now: Date) {
        stats.rollOver(to: now)
        commitStudy(upTo: now)
        phase = .idle
        round = 1
        phaseEnd = nil
        pausedRemaining = nil
        awaiting = nil
    }

    mutating func apply(_ preset: StudySettings.Preset, at now: Date) {
        settings.studyMinutes = preset.study
        settings.breakMinutes = preset.rest
        settings.rounds = preset.rounds
        settings.clamp()
        reset(at: now)
    }

    /// study → break → study … → the last study, then done. No trailing break.
    private mutating func finishPhase() {
        switch phase {
        case .study:
            if round >= settings.rounds {
                phase = .done
                awaiting = nil
            } else {
                awaiting = .rest
            }
        case .rest:
            round += 1
            awaiting = .study
        case .idle, .done:
            break
        }
        phaseEnd = nil
        pausedRemaining = nil
    }

    private mutating func commitStudy(upTo instant: Date) {
        guard let accrualStart else { return }
        let seconds = max(0, instant.timeIntervalSince(accrualStart))
        self.accrualStart = nil
        guard seconds > 0 else { return }
        stats.studiedSeconds += seconds
        stats.noteStudy(on: instant)
    }

    /// Brings the stored state up to the current moment.
    ///
    /// At most one phase can turn over unattended, because a finished phase
    /// waits to be started rather than rolling on by itself.
    func resolved(at now: Date) -> SessionState {
        var state = self
        state.stats.rollOver(to: now)
        if state.awaiting == nil,
           state.phase.isRunning,
           state.pausedRemaining == nil,
           let end = state.phaseEnd,
           end <= now {
            state.commitStudy(upTo: end)
            state.finishPhase()
        }
        return state
    }
}

// MARK: - Copy
//
// Every label the design specifies, in one place, so the app and the widget
// never drift apart on wording.

extension SessionState {
    func timeText(at now: Date) -> String {
        let total = Int(remaining(at: now).rounded(.up))
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    var phaseLabel: String {
        if phase == .done { return "DONE" }
        return isBreakish ? "BREAK" : "STUDY"
    }

    var roundText: String {
        phase == .done ? "Session complete" : "Round \(round) of \(settings.rounds)"
    }

    var planText: String {
        "\(settings.studyMinutes) min study · \(settings.breakMinutes) min break"
    }

    /// The subtitle on a takeover card.
    var nextText: String {
        switch awaiting {
        case .rest:
            let next = min(round + 1, settings.rounds)
            return "\(settings.breakMinutes) min · round \(next) of \(settings.rounds) next"
        case .study, .none:
            return "\(settings.studyMinutes) min of study"
        }
    }

    var mainLabel: String {
        switch awaiting {
        case .rest: return "Start break"
        case .study: return "Start focus"
        case .none: break
        }
        switch phase {
        case .done: return "New session"
        case .idle: return "Start \(settings.studyMinutes) min"
        case .study, .rest: return isPaused ? "Resume" : "Pause"
        }
    }

    var totalText: String { Clock.hoursMinutes(minutes: settings.totalMinutes) }

    func todayText(at now: Date) -> String {
        Clock.hoursMinutes(minutes: Int(studiedToday(at: now)) / 60)
    }

    var streakText: String { String(stats.streak) }

    var studyStepLabel: String { "\(settings.studyMinutes) min" }
    var breakStepLabel: String { "\(settings.breakMinutes) min" }
    var roundsStepLabel: String { "× \(settings.rounds)" }

    // MARK: Round dots and the session timeline

    /// One dot per round; filled up to and including the round in progress.
    func roundDotFilled(_ index: Int) -> Bool {
        phase == .done || index < round
    }

    /// Alternating study/break segments: study, break, study … ending on study.
    var timelineSegments: [(isStudy: Bool, minutes: Int)] {
        (0..<max(settings.rounds * 2 - 1, 1)).map { index in
            index.isMultiple(of: 2)
                ? (true, settings.studyMinutes)
                : (false, settings.breakMinutes)
        }
    }

    /// Index of the segment currently in play.
    var currentSegmentIndex: Int {
        (round - 1) * 2 + (isBreakish ? 1 : 0)
    }

    func segmentFilled(_ index: Int) -> Bool {
        phase == .done || index < currentSegmentIndex
    }
}

// MARK: - Formatting

enum Clock {
    /// "2h 45m" — and "2h 00m" on the hour, as the design spells it.
    static func hoursMinutes(minutes: Int) -> String {
        "\(minutes / 60)h " + (minutes % 60 == 0 ? "00m" : "\(minutes % 60)m")
    }
}
