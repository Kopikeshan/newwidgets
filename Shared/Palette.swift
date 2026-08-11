import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The colours from the design, one set per appearance.
///
/// Resolved from `\.colorScheme` rather than dynamic `NSColor`, so a view's
/// palette is explicit and behaves the same in the app, the widget, and previews.
struct Palette {
    let study: Color
    let rest: Color
    /// The unfilled part of the countdown ring.
    let track: Color
    /// Filled segment backgrounds in the session timeline.
    let studyTrack: Color
    let restTrack: Color
    /// Chrome for the controls.
    let primaryButton: Color
    let primaryButtonHover: Color
    let secondaryButton: Color
    let accentText: Color

    static let dark = Palette(
        study: Color(hex: 0x0A84FF),
        rest: Color(hex: 0x30D158),
        track: Color.white.opacity(0.10),
        studyTrack: Color(hex: 0x0A84FF).opacity(0.30),
        restTrack: Color(hex: 0x30D158).opacity(0.28),
        primaryButton: Color(hex: 0x0A84FF),
        primaryButtonHover: Color(hex: 0x3D9EFF),
        secondaryButton: Color.white.opacity(0.11),
        accentText: Color(hex: 0x6FB8FF)
    )

    static let light = Palette(
        study: Color(hex: 0x007AFF),
        rest: Color(hex: 0x28C840),
        track: Color.black.opacity(0.09),
        studyTrack: Color(hex: 0x007AFF).opacity(0.22),
        restTrack: Color(hex: 0x28C840).opacity(0.22),
        primaryButton: Color(hex: 0x007AFF),
        primaryButtonHover: Color(hex: 0x3D9EFF),
        secondaryButton: Color.black.opacity(0.06),
        accentText: Color(hex: 0x0A6EDB)
    )

    static func of(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }

    /// The ring/segment colour for whichever phase is on screen.
    func tint(breakish: Bool) -> Color { breakish ? rest : study }
}

/// Full-bleed backgrounds for the phase-end takeovers (design 1b / 1e).
/// These are the same in both appearances — they are saturated cards, not chrome.
enum Takeover {
    static let breakNext = Color(hex: 0x248A3D)
    static let breakNextLabel = Color(hex: 0x1A6B32)
    static let studyNext = Color(hex: 0x0A6EDB)
    static let studyNextLabel = Color(hex: 0x0A4E9B)
    static let done = Color(hex: 0x1C1C1E)
    static let doneMark = Color(hex: 0x30D158)
    static let doneGlyph = Color(hex: 0x0F2E17)
}
