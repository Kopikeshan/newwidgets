import AppKit
import SwiftUI

@main
struct StudyTimerApp: App {
    static let mainWindow = "study-timer-main"

    @StateObject private var model = SessionModel()

    init() {
        AlertScheduler.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup("Liby", id: Self.mainWindow) {
            SessionPanel()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)

        // The menu bar is the app's real home: a live countdown you can glance
        // at, and the popover where the session gets set up.
        MenuBarExtra {
            SessionPanel()
                .environmentObject(model)
        } label: {
            MenuBarChip()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Design 1d's menu bar chip — a small depleting ring beside the countdown.
private struct MenuBarChip: View {
    @EnvironmentObject private var model: SessionModel

    var body: some View {
        if model.state.phase == .idle || model.state.phase == .done {
            Image(systemName: model.state.phase == .done ? "checkmark.circle" : "timer")
        } else {
            HStack(spacing: 5) {
                TimerRing(
                    fraction: model.ringFraction,
                    tint: .primary,
                    track: .primary.opacity(0.35),
                    lineWidth: 2.2,
                    inset: 1.6
                )
                .frame(width: 13, height: 13)

                Text(model.timeText)
                    .font(.system(size: 11.5, weight: .medium))
                    .monospacedDigit()
            }
        }
    }
}
