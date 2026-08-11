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
        WindowGroup("Study Timer", id: Self.mainWindow) {
            ContentView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)

        // Keeps a live countdown in the menu bar, and keeps the app running so
        // the chime still plays when the window is closed.
        MenuBarExtra(model.menuBarTitle, systemImage: model.state.phase.symbol) {
            MenuBarContent().environmentObject(model)
        }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject private var model: SessionModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.summary)

        Divider()

        Button(model.state.isPaused || !model.state.phase.isRunning ? "Start" : "Pause") {
            model.startOrPause()
        }
        Button("Skip phase") { model.skip() }
            .disabled(!model.state.phase.isRunning)
        Button("Reset") { model.reset() }
            .disabled(model.state.phase == .idle)

        Divider()

        Button("Open Study Timer") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: StudyTimerApp.mainWindow)
        }
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
