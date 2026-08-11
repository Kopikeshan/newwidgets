import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: SessionModel

    var body: some View {
        VStack(spacing: 20) {
            header
            dial
            controls
            Divider()
            settings
            if !AppGroup.isShared { groupWarning }
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 520)
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 4) {
            Label(model.state.phase.title, systemImage: model.state.phase.symbol)
                .font(.title3.weight(.semibold))
            Text(model.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 14)
            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: model.progress)

            VStack(spacing: 6) {
                Text(model.state.phase.isRunning ? Clock.string(model.remaining) : "—")
                    .font(.system(size: 46, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if model.state.isPaused {
                    Text("Paused").font(.caption).foregroundStyle(.secondary)
                } else if let finish = model.finishText {
                    Text("done by \(finish)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 200, height: 200)
        .padding(.vertical, 4)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: model.startOrPause) {
                Label(primaryLabel, systemImage: primarySymbol)
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: model.skip) {
                Image(systemName: "forward.end.fill")
            }
            .controlSize(.large)
            .disabled(!model.state.phase.isRunning)
            .help("Skip to the next phase")

            Button(action: model.reset) {
                Image(systemName: "arrow.counterclockwise")
            }
            .controlSize(.large)
            .disabled(model.state.phase == .idle)
            .help("Reset the session")
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepper("Study", value: model.state.settings.studyMinutes, unit: "min") { delta in
                model.update { $0.studyMinutes += delta }
            }
            stepper("Break", value: model.state.settings.breakMinutes, unit: "min") { delta in
                model.update { $0.breakMinutes += delta }
            }
            stepper("Rounds", value: model.state.settings.rounds, unit: "×") { delta in
                model.update { $0.rounds += delta }
            }

            Toggle("Play a sound at each change", isOn: Binding(
                get: { model.state.settings.soundEnabled },
                set: { on in model.update { $0.soundEnabled = on } }
            ))

            Text(totalText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(model.state.phase.isRunning)
        .opacity(model.state.phase.isRunning ? 0.5 : 1)
    }

    private func stepper(
        _ title: String,
        value: Int,
        unit: String,
        change: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value) \(unit)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper(title, value: Binding(
                get: { value },
                set: { change($0 - value) }
            ))
            .labelsHidden()
        }
    }

    private var groupWarning: some View {
        Label(
            "The widget can't see this session yet — turn on the App Groups capability for both targets (see README).",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Derived

    private var tint: Color {
        switch model.state.phase {
        case .study: .blue
        case .rest: .green
        case .done: .purple
        case .idle: .gray
        }
    }

    private var primaryLabel: String {
        switch model.state.phase {
        case .idle, .done: "Start"
        default: model.state.isPaused ? "Resume" : "Pause"
        }
    }

    private var primarySymbol: String {
        switch model.state.phase {
        case .idle, .done: "play.fill"
        default: model.state.isPaused ? "play.fill" : "pause.fill"
        }
    }

    private var totalText: String {
        let settings = model.state.settings
        let total = settings.rounds * (settings.studyMinutes + settings.breakMinutes)
        let study = settings.rounds * settings.studyMinutes
        return "\(study) min of study across \(total) min total."
    }
}

#Preview {
    ContentView().environmentObject(SessionModel())
}
