# Proposal

## Why

The app has no Dock icon, no menu bar item, and no main menu, so the user cannot quit it except with Ctrl+C in the terminal or `kill`. Without a main menu, the standard editing shortcuts (Cmd+A/C/V/X/Z) also fail in the note, which breaks an existing `sticky-note` requirement. The panel also returns to the top-right corner on every launch, so the user must move it again each time.

## What Changes

- Add a menu bar status item with a menu that contains "Quit FloatingWidget".
- Add one native macOS close button (the red traffic-light button) to the panel's drag strip. Clicking it quits the app. The panel shows no minimize or zoom button.
- Add a hidden main menu with a Quit item (Cmd+Q) and an Edit menu (Undo, Redo, Cut, Copy, Paste, Select All). The menu bar never shows it, because the app never becomes active. It gives the note working editing shortcuts, and Cmd+Q quits the app while the note has keyboard focus.
- Save the panel position when the user moves the panel, and restore it on launch. If the saved position is not on any connected screen, use the current top-right default. If the panel is only partly on a screen, move it fully onto that screen.
- Quitting through any of these controls keeps the note text (no change to how the text is saved).

Out of scope: hiding and showing the panel, multiple notes, launch at login, packaging as an `.app` bundle, and resizing the panel.

## Capabilities

### New Capabilities
- `app-controls`: How the user quits the app: the menu bar status item, the panel's close button, and Cmd+Q.

### Modified Capabilities
- `sticky-note`: Add a requirement that the panel position persists across relaunch, with a fallback when the saved position is off-screen.

The editing shortcuts fix needs no spec change. It makes the app meet the existing "Standard editing shortcuts" scenario of the "Editable note text" requirement.

## Impact

- Code: `Sources/FloatingWidget/main.swift` only. `AppDelegate` gets the status item, the main menu, and position save and restore. `NoteView`'s drag strip gets the close button.
- Storage: new `UserDefaults` key for the panel origin, next to the existing `noteText` key.
- UI: a new icon in the menu bar while the app runs. This reverses the "no menu bar item" non-goal of the archived `add-note-editing` change.
- Dependencies: none added. AppKit and SwiftUI only. Target stays macOS 13.
