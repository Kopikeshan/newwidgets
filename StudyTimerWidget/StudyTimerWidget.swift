import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct SessionEntry: TimelineEntry {
    let date: Date
    let state: SessionState
}

struct SessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry {
        var state = SessionState()
        state.toggle(at: Date())
        return SessionEntry(date: Date(), state: state)
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        let now = Date()
        completion(SessionEntry(date: now, state: SessionStore.shared.current(at: now)))
    }

    /// The digits tick on their own via `Text(timerInterval:)`. The ring can't —
    /// it only moves when a new entry is rendered — so a running phase gets an
    /// entry a minute, plus one at the exact moment it ends.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        let now = Date()
        let state = SessionStore.shared.current(at: now)
        var entries = [SessionEntry(date: now, state: state)]

        if state.isCounting, let end = state.phaseEnd {
            let step: TimeInterval = 60
            var tick = now.addingTimeInterval(step)
            while tick < end, entries.count < 120 {
                entries.append(SessionEntry(date: tick, state: state))
                tick.addTimeInterval(step)
            }
            entries.append(SessionEntry(date: end, state: state.resolved(at: end)))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget

struct StudyTimerWidget: Widget {
    let kind = "StudyTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SessionProvider()) { entry in
            StudyTimerWidgetView(entry: entry)
        }
        .configurationDisplayName("Focus Timer")
        .description("Your study and break rounds, with the countdown and controls.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct StudyTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: SessionEntry

    private var state: SessionState { entry.state }
    private var palette: Palette { .of(scheme) }
    private var tint: Color { palette.tint(breakish: state.isBreakish) }

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        if let takeover = TakeoverKind(state: state), family != .systemSmall {
            TakeoverCard(kind: takeover, state: state)
        } else {
            switch family {
            case .systemLarge: large
            case .systemMedium: medium
            default: small
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if let takeover = TakeoverKind(state: state), family != .systemSmall {
            takeover.background
        } else {
            Color.clear
        }
    }

    // MARK: 1a — small

    private var small: some View {
        Button(intent: ToggleIntent()) {
            VStack(spacing: 9) {
                ZStack {
                    TimerRing(
                        fraction: state.ringFraction(at: entry.date),
                        tint: tint,
                        track: palette.track,
                        lineWidth: 7,
                        inset: 6
                    )
                    countdown(size: 27, tracking: -0.6)
                }
                .frame(width: 104, height: 104)

                HStack(spacing: 7) {
                    PhaseCaption(text: state.phaseLabel)
                    RoundDots(
                        total: state.settings.rounds,
                        isFilled: state.roundDotFilled,
                        tint: tint,
                        size: 6,
                        spacing: 4
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: 1b — medium

    private var medium: some View {
        HStack(spacing: 18) {
            VStack(spacing: 6) {
                ZStack {
                    TimerRing(
                        fraction: state.ringFraction(at: entry.date),
                        tint: tint,
                        track: palette.track,
                        lineWidth: 7,
                        inset: 6
                    )
                    VStack(spacing: 6) {
                        countdown(size: 29, tracking: -0.8)
                        PhaseCaption(text: state.phaseLabel, size: 8.5, opacity: 0.42)
                    }
                }
                .frame(width: 110, height: 110)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(state.roundText)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 8)
                    RoundDots(
                        total: state.settings.rounds,
                        isFilled: state.roundDotFilled,
                        tint: tint,
                        size: 7
                    )
                }
                Text(state.planText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.primary.opacity(0.45))
                    .padding(.top, 4)

                Spacer(minLength: 6)
                statsRow(valueSize: 13)
                Spacer(minLength: 6)

                HStack(spacing: 7) {
                    Button(intent: ToggleIntent()) {
                        ControlLabel(title: state.mainLabel, fill: palette.primaryButton, textColor: .white)
                    }
                    .buttonStyle(.plain)

                    Button(intent: SkipPhaseIntent()) {
                        ControlLabel(title: "Skip", fill: palette.secondaryButton, textColor: .primary.opacity(0.85))
                            .frame(width: 66)
                    }
                    .buttonStyle(.plain)

                    Button(intent: ResetSessionIntent()) {
                        ControlLabel(symbol: "arrow.counterclockwise", fill: palette.secondaryButton)
                            .frame(width: 30)
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 30)
            }
            .frame(height: 110)
        }
    }

    // MARK: 1c — large

    private var large: some View {
        VStack(spacing: 9) {
            HStack {
                Text("Focus")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                RoundDots(
                    total: state.settings.rounds,
                    isFilled: state.roundDotFilled,
                    tint: tint,
                    size: 7
                )
            }

            ZStack {
                TimerRing(
                    fraction: state.ringFraction(at: entry.date),
                    tint: tint,
                    track: palette.track,
                    lineWidth: 8,
                    inset: 7
                )
                VStack(spacing: 6) {
                    PhaseCaption(text: state.phaseLabel, size: 9, opacity: 0.42)
                    countdown(size: 42, tracking: -1.6)
                    Text(state.roundText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.primary.opacity(0.45))
                        .fixedSize()
                }
            }
            .frame(width: 138, height: 138)

            VStack(spacing: 7) {
                TimelineBar(segments: timelineSegments, palette: palette)
                HStack {
                    Text(state.planText)
                    Spacer()
                    Text("\(state.totalText) total")
                }
                .font(.system(size: 9.5))
                .foregroundStyle(.primary.opacity(0.35))
            }

            statsRow(valueSize: 16, divided: true)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button(intent: ToggleIntent()) {
                    ControlLabel(title: state.mainLabel, fill: palette.primaryButton, textColor: .white, fontSize: 13, radius: 9)
                }
                .buttonStyle(.plain)

                Button(intent: SkipPhaseIntent()) {
                    ControlLabel(title: "Skip", fill: palette.secondaryButton, textColor: .primary.opacity(0.85), fontSize: 13, radius: 9)
                        .frame(width: 78)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 36)
        }
    }

    // MARK: Pieces

    /// Ticks by itself while counting; static the rest of the time.
    @ViewBuilder
    private func countdown(size: CGFloat, tracking: CGFloat) -> some View {
        Group {
            if state.isCounting {
                Text(
                    timerInterval: state.countdownRange(at: entry.date),
                    countsDown: true,
                    showsHours: false
                )
                .multilineTextAlignment(.center)
            } else {
                Text(state.timeText(at: entry.date))
            }
        }
        .font(.system(size: size, weight: .semibold))
        .tracking(tracking)
        .monospacedDigit()
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }

    private func statsRow(valueSize: CGFloat, divided: Bool = false) -> some View {
        HStack(spacing: 16) {
            StatBlock(
                value: state.todayText(at: entry.date),
                caption: divided ? "STUDIED TODAY" : "TODAY",
                valueSize: valueSize
            )
            .frame(maxWidth: divided ? .infinity : nil, alignment: .leading)

            if divided {
                Rectangle()
                    .fill(.primary.opacity(0.09))
                    .frame(width: 0.5)
            }

            StatBlock(value: state.streakText, caption: "DAY STREAK", valueSize: valueSize)
                .frame(maxWidth: divided ? .infinity : nil, alignment: .leading)

            if !divided { Spacer(minLength: 0) }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .top) { hairline }
        .overlay(alignment: .bottom) { hairline }
    }

    private var hairline: some View {
        Rectangle()
            .fill(.primary.opacity(0.09))
            .frame(height: 0.5)
    }

    private var timelineSegments: [TimelineBar.Segment] {
        state.timelineSegments.enumerated().map { index, segment in
            TimelineBar.Segment(
                isStudy: segment.isStudy,
                minutes: segment.minutes,
                isFilled: state.segmentFilled(index)
            )
        }
    }
}

// MARK: - Control label

/// The pill used for every widget button, so they stay identical across sizes.
struct ControlLabel: View {
    var title: String?
    var symbol: String?
    let fill: Color
    var textColor: Color = .primary.opacity(0.85)
    var fontSize: CGFloat = 12
    var radius: CGFloat = 8

    init(title: String, fill: Color, textColor: Color = .primary.opacity(0.85), fontSize: CGFloat = 12, radius: CGFloat = 8) {
        self.title = title
        self.fill = fill
        self.textColor = textColor
        self.fontSize = fontSize
        self.radius = radius
    }

    init(symbol: String, fill: Color, radius: CGFloat = 8) {
        self.symbol = symbol
        self.fill = fill
        self.radius = radius
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            if let title {
                Text(title)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Phase-end takeovers (1b / 1e)

enum TakeoverKind {
    case breakNext
    case studyNext
    case done

    init?(state: SessionState) {
        switch state.awaiting {
        case .rest: self = .breakNext
        case .study: self = .studyNext
        case .none: if state.phase == .done { self = .done } else { return nil }
        }
    }

    var background: Color {
        switch self {
        case .breakNext: Takeover.breakNext
        case .studyNext: Takeover.studyNext
        case .done: Takeover.done
        }
    }
}

struct TakeoverCard: View {
    let kind: TakeoverKind
    let state: SessionState

    var body: some View {
        switch kind {
        case .breakNext:
            phaseEnd(
                caption: "FOCUS COMPLETE",
                headline: "Break",
                action: "Start break",
                actionColor: Takeover.breakNextLabel
            )
        case .studyNext:
            phaseEnd(
                caption: "BREAK OVER",
                headline: state.roundText,
                action: "Start focus",
                actionColor: Takeover.studyNextLabel
            )
        case .done:
            done
        }
    }

    private func phaseEnd(
        caption: String,
        headline: String,
        action: String,
        actionColor: Color
    ) -> some View {
        VStack(spacing: 3) {
            Text(caption)
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.7))
            Text(headline)
                .font(.system(size: 40, weight: .semibold))
                .tracking(-1.4)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(state.nextText)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.bottom, 11)

            Button(intent: ToggleIntent()) {
                Text(action)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(actionColor)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var done: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(Takeover.doneMark)
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Takeover.doneGlyph)
            }
            .frame(width: 34, height: 34)
            .padding(.bottom, 6)

            Text("All \(state.settings.rounds) rounds done")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(state.todayText(at: Date())) studied today")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 12)

            Button(intent: ResetSessionIntent()) {
                Text("New session")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
