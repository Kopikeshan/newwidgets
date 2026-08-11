import Foundation

/// The one place the App Group identifier is written down.
///
/// The app and the widget extension can only see the same session if they are
/// both entitled to this group. If you change it, change it in three places:
/// here, `StudyTimer/StudyTimer.entitlements`, and
/// `StudyTimerWidget/StudyTimerWidget.entitlements`.
enum AppGroup {
    static let identifier = "group.newwidgets.studytimer"

    /// True when the process really has access to the shared container.
    /// `UserDefaults(suiteName:)` hands back an object even when the
    /// entitlement is missing, so ask the file system instead.
    static var isShared: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    /// Shared defaults, falling back to standard defaults so the app still
    /// works on its own if the group is misconfigured (the widget just won't
    /// follow along until it is fixed).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
