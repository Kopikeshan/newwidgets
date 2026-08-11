import SwiftUI

/// Design 1d — the menu bar popover, where a session gets set up.
struct SessionPanel: View {
    @EnvironmentObject private var model: SessionModel
    @Environment(\.colorScheme) private var scheme

    private var state: SessionState { model.state }
    private var palette: Palette { .of(scheme) }

    var body: some View {
        VStack(spacing: 14) {
            header
            presets
            steppers
            chimeRow
            primaryButton
            footer
            if !AppGroup.isShared { groupWarning }
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text("Session")
                .font(.system(size: 13.5, weight: .semibold))
            Spacer()
            Text(state.totalText)
                .font(.system(size: 11.5))
                .monospacedDigit()
                .foregroundStyle(.primary.opacity(0.4))
        }
    }

    private var presets: some View {
        HStack(spacing: 6) {
            ForEach(StudySettings.presets) { preset in
                let selected = state.settings.matches(preset)
                Button { model.apply(preset) } label: {
                    Text(preset.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected ? palette.accentText : .primary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selected ? palette.study.opacity(0.22) : .primary.opacity(0.09))
                                .overlay {
                                    if selected {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(palette.study.opacity(0.5), lineWidth: 0.5)
                                    }
                                }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var steppers: some View {
        VStack(spacing: 1) {
            stepperRow(
                title: "Study",
                swatch: .rounded(palette.study),
                value: state.studyStepLabel
            ) { model.bumpStudy($0 * StudySettings.minuteStep) }

            stepperRow(
                title: "Break",
                swatch: .rounded(palette.rest),
                value: state.breakStepLabel
            ) { model.bumpBreak($0 * StudySettings.minuteStep) }

            stepperRow(
                title: "Rounds",
                swatch: .ring,
                value: state.roundsStepLabel
            ) { model.bumpRounds($0) }
        }
        .background(.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private enum Swatch {
        case rounded(Color)
        case ring
    }

    private func stepperRow(
        title: String,
        swatch: Swatch,
        value: String,
        change: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            HStack(spacing: 9) {
                swatchView(swatch)
                Text(title).font(.system(size: 12.5))
            }
            Spacer()
            HStack(spacing: 2) {
                stepButton("−", corners: .leading) { change(-1) }
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 56)
                stepButton("+", corners: .trailing) { change(1) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(.primary.opacity(0.02))
    }

    @ViewBuilder
    private func swatchView(_ swatch: Swatch) -> some View {
        switch swatch {
        case .rounded(let color):
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
        case .ring:
            Circle()
                .strokeBorder(.primary.opacity(0.45), lineWidth: 2)
                .frame(width: 8, height: 8)
        }
    }

    private enum StepCorners { case leading, trailing }

    private func stepButton(_ glyph: String, corners: StepCorners, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 26, height: 24)
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: corners == .leading ? 6 : 0,
                        bottomLeadingRadius: corners == .leading ? 6 : 0,
                        bottomTrailingRadius: corners == .trailing ? 6 : 0,
                        topTrailingRadius: corners == .trailing ? 6 : 0
                    )
                    .fill(.primary.opacity(0.11))
                }
        }
        .buttonStyle(.plain)
    }

    private var chimeRow: some View {
        HStack {
            Text("Chime + notification")
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.55))
            Spacer()
            HStack(spacing: 7) {
                Button("Test") { model.testChime() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.accentText)

                Toggle("", isOn: Binding(
                    get: { state.settings.soundEnabled },
                    set: { model.setSoundEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 2)
    }

    private var primaryButton: some View {
        Button { model.toggle() } label: {
            Text(state.mainLabel)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(palette.primaryButton, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.space, modifiers: [])
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.primary.opacity(0.1))
                .frame(height: 0.5)
            HStack {
                Text("Today \(model.todayText) · \(state.streakText)d streak")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.primary.opacity(0.45))
                Spacer()
                Button("Reset") { model.reset() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.accentText)
            }
            .padding(.top, 12)
        }
    }

    private var groupWarning: some View {
        Label(
            "The widget can't see this session yet — turn on App Groups for both targets (see README).",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SessionPanel().environmentObject(SessionModel())
}
