# Study Timer — a macOS study/break widget

A Pomodoro-style timer for macOS: set how long you study, how long you break, and
how many rounds. It chimes and posts a notification at every changeover, and the
widget on your desktop or in Notification Center shows the live countdown with
Start / Pause / Skip / Reset buttons.

```
Round 1  ████████░░░░░░  Studying   12:43   →  break  →  Round 2 …
```

## How it's put together, and why

A widget on macOS **cannot run a timer, play a sound, or wake itself up.** Widgets
are snapshots the system redraws when it feels like it; they get no background
execution. So the work is split in two:

| Piece | What it does |
| --- | --- |
| **StudyTimer** (the app) | Owns the session, plays the chime, asks for notification permission. Lives in the menu bar with a live countdown. |
| **StudyTimerWidgetExtension** (the widget) | Draws the session and offers buttons. Holds no state of its own. |
| **App Group container** | The shared box both of them read and write. |

Two details make it accurate without anything running:

- **The state stores an end *date*, not a remaining count.** Nothing ticks. Any
  reader compares `phaseEnd` with the clock, so a widget redrawn after your Mac
  slept for three hours still shows the right phase. `SessionState.resolved(at:)`
  fast-forwards over every boundary that has already gone by.
- **The alerts are all scheduled up front.** Once a session starts, every
  changeover is known, so `AlertScheduler` posts a local notification for each
  one. They fire even if the widget extension has been torn down.

The widget's countdown uses `Text(timerInterval:)`, which WidgetKit animates
itself — no timeline refresh budget is spent making the digits move. The timeline
only carries one entry per phase change, so the label and colour flip on time.

## Setup

Requires **macOS 14 (Sonoma) or later** and **Xcode 15 or later**. Sonoma is the
floor because the widget's buttons use interactive widgets (`Button(intent:)`),
and because it's the release that let widgets sit on the desktop.

1. **Open** `StudyTimer.xcodeproj`.
2. **Set your team.** Select the project → target **StudyTimer** → *Signing &
   Capabilities* → pick your team under *Signing*. Repeat for the
   **StudyTimerWidgetExtension** target. A free Apple ID works fine.
3. **Confirm the App Group.** Both targets ship with an *App Groups* entitlement
   for `group.newwidgets.studytimer`. Xcode may want you to click the refresh
   arrow next to it once so it registers the group with your team. If you'd
   rather use a different identifier, change it in three places:
   `Shared/AppGroup.swift`, `StudyTimer/StudyTimer.entitlements`, and
   `StudyTimerWidget/StudyTimerWidget.entitlements`.
4. **Run** the StudyTimer scheme (⌘R). Allow notifications when asked — that's
   what makes the alert appear when a phase ends.
5. **Add the widget.** Right-click the desktop → *Edit Widgets* (or click the
   date in the menu bar → *Edit Widgets*), search for **Study Timer**, and drag
   the small or medium size where you want it.

The app window shows an orange warning if the App Group isn't wired up — that's
the one misconfiguration that makes the widget silently ignore your session.

For the widget to keep working, the app needs to have been launched at least
once, and should stay running in the menu bar for the in-app chime. The
notification alerts are scheduled with the system, so they arrive regardless.

## Using it

- **In the app:** set study minutes, break minutes and rounds, then Start.
  Space bar starts and pauses.
- **In the menu bar:** live countdown, plus Start / Skip / Reset.
- **On the widget:** the same three buttons. Presses go through the same code
  path as the app's, so the two never disagree.

Settings are locked while a session runs — stop or reset to change them.

A session is `rounds × (study + break)`, ending after the last break. With the
defaults that's 4 × (25 + 5) = 2 hours, 100 minutes of it studying.

## Where things live

```
Shared/                       # compiled into both targets
  AppGroup.swift              # the shared-container identifier, in one place
  StudySession.swift          # the phase machine — settings, state, transitions
  SessionStore.swift          # load / save / mutate the one shared session
  AlertScheduler.swift        # a notification per upcoming phase change
StudyTimer/                   # the app
  StudyTimerApp.swift         # window + MenuBarExtra
  ContentView.swift           # dial, controls, settings
  SessionModel.swift          # 1 Hz tick for the live UI, plays the chime
StudyTimerWidget/             # the widget extension
  StudyTimerWidget.swift      # timeline provider + small/medium layouts
  WidgetIntents.swift         # the Start / Skip / Reset buttons
  StudyTimerWidgetBundle.swift
```

Things you might want to change:

- **Sounds:** `SessionModel.chime(for:)` — any name from `/System/Library/Sounds`.
- **Alert wording:** `AlertScheduler.message(for:settings:)`.
- **A long break every N rounds:** add the rule to `SessionState.advance()`; the
  widget, the timeline and the alerts all derive from it and will follow.
- **Widget sizes:** `supportedFamilies` in `StudyTimerWidget`.

## If the project file gives you trouble

The Xcode project here was written by hand rather than generated by Xcode, and it
has not been compiled (that needs a Mac). If it doesn't open cleanly, the sources
are the real deliverable and you can rehost them in a fresh project in a few
minutes:

1. Xcode → *New Project* → **macOS / App**, named `StudyTimer`, SwiftUI.
2. *File → New → Target* → **Widget Extension**, named `StudyTimerWidget`.
   Uncheck *Include Live Activity*, uncheck *Include Configuration App Intent*.
3. Delete the stub files Xcode made and drag in `Shared/`, `StudyTimer/` and
   `StudyTimerWidget/` from this repo.
4. Set target membership so everything under `Shared/` belongs to **both** targets
   (File Inspector → *Target Membership*).
5. Add the *App Groups* capability to both targets with the same group ID.
