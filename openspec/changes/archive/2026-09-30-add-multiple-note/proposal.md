# Proposal

## Why

Notely shows exactly one note. A user who wants to keep separate things in view (a to-do list, a phone number, a snippet) must mix them in one small panel. Physical sticky notes solve this with more notes, and Notely should work the same way.

## What Changes

- Each note is its own floating panel with its own text and its own position. All panels keep the current look, size, floating level, all-Spaces behavior, and non-activating focus.
- Add a "+" button to every panel's drag area. Clicking it opens a new, empty note panel near that panel, with keyboard focus in the new note.
- Add a "−" button to every panel's drag area. Clicking it removes that note and its text at once, with no confirmation. Removing the last note quits the app, and the next launch shows one empty note.
- **BREAKING (controls)**: remove the panel's red close button. It added no value once "+" and "−" exist for creating and removing individual notes, and it was confusing because it quit the whole app instead of closing one note. Quitting is now only the menu bar item's Quit item and Cmd+Q. Quitting keeps all notes.
- Save the text and position of every note, and restore all notes on launch. Each note uses the existing position rules (default position, off-screen fallback, clamp inside the screen).
- **BREAKING (storage)**: notes move from the `noteText` and `panelOrigin` `UserDefaults` keys to one list of notes. The first launch after the change migrates the existing note text and position into the first note, so the user loses nothing.

Out of scope: a "New Note" item in the menu bar menu, Cmd+N, a list of notes in the menu, per-note colors, resizing, undo for a removed note, and a limit on the number of notes.

## Capabilities

### New Capabilities
- `multiple-notes`: Creating and removing note panels with the "+" and "−" buttons, what happens when the last note is removed, and restoring all notes on launch.

### Modified Capabilities
- `sticky-note`: The purpose and requirements change from "one note" to "every note". Text persistence and position persistence become per-note. The first-launch scenario describes one empty note.
- `app-controls`: Removes the panel close button entirely (requirement and its scenarios). The remaining quit paths (menu bar item, Cmd+Q) keep the text of all notes, not one note.

## Impact

- Code: `Sources/Notely/main.swift` only. `AppDelegate` changes from one `panel` to a set of panels. `NoteView` binds to one note from a shared store instead of `@AppStorage("noteText")`. The drag area loses the close button and gets "+" and "−" buttons.
- Storage: new `UserDefaults` key with the list of notes (id, text, origin). One-time migration from `noteText` and `panelOrigin`. The old keys are removed after migration.
- Rollback: an older build reads `noteText` and `panelOrigin`, which are gone after migration, so it opens one empty note. Notes stay in the new key and come back when the new build is installed again.
- Dependencies: none added. AppKit and SwiftUI only. Target stays macOS 13.
