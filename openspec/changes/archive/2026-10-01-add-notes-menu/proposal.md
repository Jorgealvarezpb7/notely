# Proposal

## Why

Notely has no overview of its notes. Every note is a floating window, every note opens at launch, and a note can only be created from the "+" on another note. A user with many notes cannot see them in one place, cannot put a note away without deleting it, and has no single, obvious place to start a new note. A menu window that lists all notes fixes this, and it gives a home for other kinds of content (lists) later.

## What Changes

- Add a menu window. It shows the standard traffic lights, a "+ New" row, and one row for every saved note. The menu opens at every launch.
- The menu's red traffic light quits the app. The yellow light minimizes the menu. The green light gives the native zoom and full-screen options.
- "+ New" shows a chooser in the menu window with a "<--" back control, a "+ New Note" row, and a "+ New List" row. "+ New List" is a disabled placeholder for a later change.
- "+ New Note" opens a new, empty note window next to the menu, at the default note size, with keyboard focus in the note.
- Clicking a note's row in the menu opens that note's window, or brings it to the front when it is already open.
- **BREAKING (controls)**: remove the "+" button from every note window. Notes are created only from the menu.
- **BREAKING (controls)**: the "−" button on a note now closes the note window and keeps the note. The note stays listed in the menu and can be opened again.
- Add a trash button to every note window. It deletes the note at once, with no confirmation, which is what "−" did before.
- **BREAKING (behavior)**: deleting the last note no longer quits the app. The menu stays open and lists no notes.
- Launch restores the menu and only the notes that were open at quit. Closed notes stay closed until the user opens them from the menu.
- Note windows keep showing no traffic lights.

Out of scope: the "+ New List" behavior and any list data type, deleting notes from the menu, Cmd+N or other menu bar items for new notes, search, sorting options, renaming notes, and changing the "<--" control into anything other than the chooser's back control.

## Capabilities

### New Capabilities
- `notes-menu`: The menu window, its traffic lights, the note list and row titles, opening a note from its row, the "+ New" chooser with the "+ New List" placeholder, creating a note next to the menu, and the menu's own frame persistence.

### Modified Capabilities
- `multiple-notes`: "+" is removed from note windows ("Create a note from a panel" is removed). "−" closes a note instead of deleting it (new requirement). A trash button deletes a note ("Remove a note from its panel" changes). "Removing the last note quits the app" is removed. "Panel buttons do not move the panel" lists "−" and trash. "All notes restored on launch" restores only the notes that were open.
- `note-resize`: "New note size" uses the default size for notes created from the menu. The minimum-size scenario in "Size limits" lists "−" and trash.
- `sticky-note`: the "New note" scenario of "Scroll bar shows only while scrolling" creates the note from the menu instead of "+".
- `app-controls`: Cmd+Q also quits while the menu window has keyboard focus. The menu's red traffic light is a quit path that keeps note text. Clicking the Dock icon also brings back the menu, including when it is minimized.

## Impact

- Code: `Sources/Notely/main.swift` only. New menu window with SwiftUI content (list view and chooser view). `NoteView` drag strip changes from "−" and "+" to "−" and trash. `AppDelegate` gains close-note, open-note, and menu-anchored add-note paths; `removeNote` no longer terminates. `NoteStore` gains an open/closed state per note and keeps an empty list empty.
- Storage: `Note` gains an optional `isOpen` field. Notes saved by earlier versions have no value and load as open, so the upgrade shows the same windows as before plus the menu. The menu frame is saved under a new `menuFrame` `UserDefaults` key.
- Rollback: an older build ignores `isOpen` and opens every note, including closed ones. An older build that loads an empty list creates one empty note. No data is lost.
- Dependencies: none added. AppKit and SwiftUI only. Target stays macOS 13.
