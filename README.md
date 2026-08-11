# Liby — a macOS study/break widget

A study timer for macOS built to the Claude Design handoff (`Study Timer Widget.dc.html`):
set how long you study, how long you break, and how many rounds. It chimes and
posts a notification at every changeover, tracks how much you've studied today,
and keeps a day streak.

```
Round 2 of 3   ◍ 24:18  STUDY   ●●○     [ Pause ] [ Skip ] [ ↺ ]
```

## The one behaviour worth knowing

**Phases don't roll on by themselves.** When study hits zero the timer stops,
chimes, and the widget flips to a full-bleed card — *FOCUS COMPLETE / Break /
Start break* — and waits for you. Same on the way back out of a break. This is
deliberate in the design, and it's why the takeover states exist.

One consequence: only one alert can be scheduled at a time. Everything past the
current phase depends on when you press Start, so the next notification is
scheduled at that moment rather than up front.

## How it's put together, and why

A widget on macOS **cannot run a timer, play a sound, or wake itself up.**
Widgets are snapshots the system redraws when it feels like it; they get no
background execution. So the work is split:

| Piece | What it does |
| --- | --- |
| **StudyTimer** (the app) | Owns the session, plays the chime, asks for notification permission. Lives in the menu bar with a live countdown. |
| **StudyTimerWidgetExtension** | Draws the session and offers buttons. Holds no state of its own. |
| **App Group container** | The shared box both of them read and write. |

The state stores an end *date*, not a remaining count. Nothing ticks. Every
reader compares `phaseEnd` against the clock, so a widget redrawn after your Mac
slept for three hours still shows the right thing — `resolved(at:)` brings the
stored state up to now.

The widget's digits tick via `Text(timerInterval:)`, which WidgetKit animates
itself. The ring can't do that — it only moves when a new entry renders — so a
running phase emits one timeline entry a minute plus one at the exact end.

## What's in the widget family

Everything from the design, at the sizes macOS offers:

- **Small** — the timer face. The whole widget is the start/pause button.
- **Small (Study Today)** — a second widget: time studied today and your streak.
- **Medium** — ring, round dots, plan, stats, and Start / Skip / Reset. Flips to
  the green *Break* / blue *Back to focus* / dark *All rounds done* takeovers.
- **Large** — adds the session timeline: study and break blocks filling left to
  right as you work through them.
- **Menu bar popover** — presets (45/15, 25/5, 50/10, 90/20), steppers for study,
  break and rounds, the chime toggle with a Test button, and today's totals.

Light and dark are both handled — the design's two palettes live in
`Shared/Palette.swift`, picked by `\.colorScheme`.

## A note on names

The app shows as **Liby** everywhere you see it: the menu bar, the window title,
the widget gallery, and as the sender on notifications.

Internally the targets, the folders, the `.xcodeproj` and the bundle identifier
are still `StudyTimer` / `com.newwidgets.studytimer`. That is deliberate — the
bundle identifier is what the App Group container and the notification
authorisation are keyed to, so renaming it would orphan a working setup and mean
re-provisioning. None of it is visible to anyone using the app.

## The icon

`Branding/make_icon.py` draws the mark and writes every size the asset catalog
needs. The wordmark is deliberately left off: an app icon is seen at 16-128px,
where lettering turns to mush, and the name is always shown beside it anyway.

```
python3 Branding/make_icon.py                    # redraw from the script
python3 Branding/make_icon.py path/to/1024.png   # or drop in a supplied image
```

Either way it lands on the standard macOS plate — 824/1024 with a 185 corner
radius — and refreshes `StudyTimer/Assets.xcassets/AppIcon.appiconset`.

## Setup

Requires **macOS 14 (Sonoma) or later** and **Xcode 15 or later**. Sonoma is the
floor because the widget's buttons use interactive widgets (`Button(intent:)`).

1. **Open** `StudyTimer.xcodeproj`.
2. **Set your team.** Project → target **StudyTimer** → *Signing & Capabilities*
   → pick your team. Repeat for **StudyTimerWidgetExtension**. A free Apple ID
   works.
3. **Confirm the App Group.** Both targets carry an *App Groups* entitlement for
   `group.newwidgets.studytimer`. Xcode may want the refresh arrow clicked once
   so it registers with your team. To use a different identifier, change it in
   `Shared/AppGroup.swift` and both `.entitlements` files.
4. **Run** (⌘R) and allow notifications.
5. **Add the widgets.** Right-click the desktop → *Edit Widgets*, search for
   **Liby**, drag out the size you want.

The popover shows an orange warning if the App Group isn't wired up — that's the
one misconfiguration that leaves the widget silently ignoring your session.

## Where things live

```
Shared/                       # compiled into both targets
  StudySession.swift          # the phase machine, stats, and every label
  SessionStore.swift          # load / save / mutate the one shared session
  AlertScheduler.swift        # the notification for the running phase
  Palette.swift               # the design's light and dark colours
  SessionViews.swift          # ring, round dots, timeline bar
  AppGroup.swift              # the shared-container identifier, in one place
StudyTimer/                   # the app
  StudyTimerApp.swift         # window + menu bar chip
  SessionPanel.swift          # the popover (design 1d)
  SessionModel.swift          # 1 Hz tick for the live UI, plays the chime
StudyTimerWidget/             # the widget extension
  StudyTimerWidget.swift      # timeline, small/medium/large, takeovers
  StatsWidget.swift           # the "Study Today" small widget
  WidgetIntents.swift         # Start / Skip / Reset
```

Things you might want to change:

- **Sounds:** `SessionModel.chime(afterStudy:)` — any name from
  `/System/Library/Sounds`. The prototype synthesised a rising pair of notes into
  a break and a falling pair out of one; system sounds are the nearest match.
- **Alert wording:** `AlertScheduler.body(for:)`.
- **Presets:** `StudySettings.presets`.
- **Auto-advance instead of waiting:** call `toggle` from `finishPhase()` — but
  the takeover cards become unreachable, so drop them too.

## Two deviations from the prototype, and why

- **The notification has no title line**, only a body sentence. That's what the
  design's banner shows, and it's what macOS renders for a body-only alert.
- **The menu bar ring renders monochrome.** macOS templates menu bar items, so
  the phase colour is lost there. This matches system convention and is the only
  place the design's colour doesn't survive.

## If the project file gives you trouble

The Xcode project was written by hand rather than generated. It builds and runs —
verified on macOS 27 beta with Xcode 27 — but if a future edit corrupts it, the
sources are the real deliverable and can be rehosted in a fresh project:

1. Xcode → *New Project* → **macOS / App**, named `StudyTimer`, SwiftUI.
2. *File → New → Target* → **Widget Extension**, named `StudyTimerWidget`.
   Uncheck *Include Live Activity* and *Include Configuration App Intent*.
3. Delete the stubs and drag in `Shared/`, `StudyTimer/`, `StudyTimerWidget/`.
4. Everything under `Shared/` needs membership in **both** targets
   (File Inspector → *Target Membership*).
5. Add *App Groups* to both targets with the same group ID.
