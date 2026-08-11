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
        state.start(at: Date())
        return SessionEntry(date: Date(), state: state)
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        let now = Date()
        completion(SessionEntry(date: now, state: SessionStore.shared.current(at: now)))
    }

    /// The countdown itself is drawn by `Text(timerInterval:)`, which ticks
    /// without any help from us. All the timeline has to do is hand WidgetKit
    /// an entry at each phase change so the label and colour flip on time.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        let now = Date()
        let state = SessionStore.shared.current(at: now)

        var entries = [SessionEntry(date: now, state: state)]
        for boundary in state.upcomingBoundaries(from: now, limit: 24) {
            entries.append(SessionEntry(date: boundary.date, state: boundary.state))
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Study Timer")
        .description("Your study and break rounds, with the countdown and controls.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct StudyTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SessionEntry

    private var state: SessionState { entry.state }

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            phaseLabel
            countdown
                .font(.system(size: 32, weight: .medium, design: .rounded))
            Spacer(minLength: 0)
            HStack {
                roundDots
                Spacer()
                Button(intent: StartPauseIntent()) {
                    Image(systemName: primarySymbol)
                }
                .buttonStyle(.plain)
                .foregroundStyle(tint)
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                phaseLabel
                countdown
                    .font(.system(size: 40, weight: .medium, design: .rounded))
                roundDots
                Spacer(minLength: 0)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                controlButton(symbol: primarySymbol, intent: StartPauseIntent(), prominent: true)
                controlButton(symbol: "forward.end.fill", intent: SkipPhaseIntent())
                controlButton(symbol: "arrow.counterclockwise", intent: ResetSessionIntent())
            }
        }
    }

    // MARK: Pieces

    private var phaseLabel: some View {
        Label(state.phase.title, systemImage: state.phase.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
    }

    @ViewBuilder
    private var countdown: some View {
        if state.phase.isRunning {
            if state.isPaused {
                Text(Clock.string(state.remaining(at: entry.date)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                // Self-updating: WidgetKit redraws this every second on its own.
                Text(
                    timerInterval: state.countdownRange(at: entry.date),
                    countsDown: true,
                    showsHours: false
                )
                .monospacedDigit()
            }
        } else {
            Text(state.phase == .done ? "Done" : "Ready")
                .foregroundStyle(.secondary)
        }
    }

    private var roundDots: some View {
        HStack(spacing: 4) {
            ForEach(1...max(state.settings.rounds, 1), id: \.self) { round in
                Circle()
                    .fill(round < state.round || state.phase == .done ? tint : Color.secondary.opacity(0.3))
                    .overlay {
                        if round == state.round, state.phase.isRunning {
                            Circle().stroke(tint, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func controlButton(
        symbol: String,
        intent: some AppIntent,
        prominent: Bool = false
    ) -> some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 16 : 12, weight: .semibold))
                .frame(width: prominent ? 34 : 26, height: prominent ? 34 : 26)
                .background(prominent ? tint.opacity(0.2) : Color.secondary.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? tint : .secondary)
    }

    // MARK: Derived

    private var tint: Color {
        switch state.phase {
        case .study: .blue
        case .rest: .green
        case .done: .purple
        case .idle: .gray
        }
    }

    private var primarySymbol: String {
        state.phase.isRunning && !state.isPaused ? "pause.fill" : "play.fill"
    }

    private var subtitle: String {
        switch state.phase {
        case .idle:
            "\(state.settings.rounds) × \(state.settings.studyMinutes)/\(state.settings.breakMinutes) min"
        case .study, .rest:
            "Round \(state.round) of \(state.settings.rounds)"
        case .done:
            "\(state.settings.rounds) rounds finished"
        }
    }
}

// MARK: - Previews

private func previewEntry(running: Bool) -> SessionEntry {
    var state = SessionState()
    if running { state.start(at: Date()) }
    return SessionEntry(date: Date(), state: state)
}

#Preview(as: .systemMedium) {
    StudyTimerWidget()
} timeline: {
    previewEntry(running: false)
    previewEntry(running: true)
}
