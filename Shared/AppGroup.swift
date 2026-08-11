import Foundation
import Security

/// Resolves the App Group container the app and the widget share.
///
/// macOS wants app group identifiers prefixed with the Team ID
/// (`ABCDE12345.group.newwidgets.studytimer`), where iOS is happy with the bare
/// `group.newwidgets.studytimer`. Rather than hard-code either — the Team ID
/// differs per developer — this reads whatever was actually granted from the
/// running code's own signature.
enum AppGroup {
    /// The part that stays the same whichever prefix is applied. If you change
    /// it, change it in both `.entitlements` files too.
    static let suffix = "group.newwidgets.studytimer"

    /// The identifier this process is genuinely entitled to, falling back to the
    /// bare form so behaviour is still defined when nothing was granted.
    static let identifier: String = {
        entitledGroups().first { $0 == suffix || $0.hasSuffix(".\(suffix)") } ?? suffix
    }()

    /// Whether the shared container really exists for this process. Asking the
    /// file system is the only honest test: `UserDefaults(suiteName:)` hands
    /// back an object either way, and only fails later, at the write.
    static var isShared: Bool { containerURL != nil }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Shared defaults when the group is available, and the process's own
    /// defaults when it isn't — so the app still works standalone instead of
    /// failing every write. The widget can't follow along until the group is
    /// fixed, which is what the warning in the popover is for.
    static var defaults: UserDefaults {
        guard isShared, let shared = UserDefaults(suiteName: identifier) else {
            return .standard
        }
        return shared
    }

    /// The `com.apple.security.application-groups` entitlement as signed.
    private static func entitledGroups() -> [String] {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task,
                  "com.apple.security.application-groups" as CFString,
                  nil
              ) as? [String]
        else { return [] }
        return value
    }

    /// One line describing what resolved, shown in the popover when it didn't.
    static var diagnostic: String {
        if isShared { return "Sharing via \(identifier)" }
        let granted = entitledGroups()
        let listed = granted.isEmpty ? "nothing" : granted.joined(separator: ", ")
        return "No shared container. Signed entitlement grants: \(listed)."
    }
}
