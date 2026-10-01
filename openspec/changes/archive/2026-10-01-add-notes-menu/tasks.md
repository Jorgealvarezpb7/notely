# Tasks

The project has no test target, so each task is verified with a command and a manual check on the host Mac. Build and run with `just run` on macOS; the recipes do not run in the dkc Linux container. Before starting, back up the current notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. Store: open state and empty list

- [x] 1.1 In `Sources/Notely/main.swift`, add `isOpen: Bool?` to `Note` and `setOpen(_:for:)` to `NoteStore` (design.md Decision 1); verify `swift build -c release` succeeds and, after `just run` on the backed-up data, every existing note opens (multiple-notes scenario "Notes saved by an earlier version")
- [x] 1.2 Make a decoded empty `notes` list stay empty, keeping the one-empty-note fallback only for a missing key and for undecodable data (design.md Decision 1); verify `swift build -c release` succeeds (behavior is checked in 4.3, once trash no longer quits)

## 2. Menu window

- [x] 2.1 Give `fit` and `restoredFrame` a `minimum` size parameter that defaults to `minimumNoteSize`, and add `minimumMenuSize` (200 by 200) and the default menu frame (design.md Decision 3); verify the build succeeds and that sticky-note scenario "Saved position partly off-screen" still passes for a note
- [x] 2.2 Add `MenuWindowDelegate` and `openMenuWindow()` (style mask, visible traffic lights, `.fullScreenPrimary`, `minSize`, frame restore from `menuFrame`, saving on move and resize except in full screen), and open the menu at launch before notes (design.md Decisions 2, 3, and 7); verify notes-menu scenarios "Launch shows the menu", "First launch menu frame", "Relaunch keeps menu frame", and "Shrink the menu"
- [x] 2.3 Verify the traffic lights: notes-menu scenarios "Click red", "Click yellow", "Click green", "Hold green", and "Note windows have no traffic lights", and app-controls scenarios "Cmd+Q in the menu" and "Quit soon after typing" through the red button
- [x] 2.4 Update `applicationShouldHandleReopen` to deminiaturize and front the menu as well as the notes (design.md Decision 7); verify app-controls scenarios "Click Dock icon with notes hidden" and "Click Dock icon with menu minimized"

## 3. Menu content

- [x] 3.1 Add `noteTitle(_:)` and `MenuView`'s list (a "+ New" row, then rows newest first, in `noteFont`, scrolling when long) as the menu's content (design.md Decision 4); verify notes-menu scenarios "Rows for open and closed notes" (after 4.2, recheck it), "Row title from text", "Empty note title", and "Title follows typing"
- [x] 3.2 Add `openNote(_:)` and wire it to note rows (design.md Decision 5); verify notes-menu scenario "Click the row of an open note"
- [x] 3.3 Add the chooser with the "<--" back control, "+ New Note", and a disabled "+ New List" (design.md Decision 4); verify notes-menu scenarios "Open the chooser", "Back from the chooser", and "New List is a placeholder"
- [x] 3.4 Add `newNoteFrame(menu:screen:)` and `addNoteFromMenu()`, wire them to "+ New Note", and return the menu to the list afterwards (design.md Decision 6); verify notes-menu scenarios "Click '+ New Note'", "Menu at the right screen edge", "No room on either side", and "Newest first", note-resize scenario "Create a note from the menu", and sticky-note scenario "New note"

## 4. Note strip: "−" closes, trash deletes

- [x] 4.1 Replace `onAdd`/`onRemove` in `NoteView` with `onClose`/`onDelete`, and show "minus" ("Close Note") and then "trash" ("Delete Note") in the strip; delete `addNote(after:)` (design.md Decision 5); verify `grep -n 'symbolName: "plus"\|addNote(after' Sources/Notely/main.swift` prints nothing, and verify multiple-notes scenarios "Drag area buttons" and "Click a panel button" and note-resize scenario "Controls stay visible at minimum size"
- [x] 4.2 Extract `detachWindow(_:)` and add `closeNote(_:)` wired to "−" (design.md Decision 5); verify multiple-notes scenarios "Click '−'", "Close the only open note", "Click '−' while another app is frontmost", "Closed note stays closed after relaunch", and "Relaunch with one closed note", and notes-menu scenario "Open a closed note", and sticky-note scenario "Reopened note"
- [x] 4.3 Change `removeNote(_:)` to use `detachWindow(_:)` and stop terminating, wired to trash (design.md Decision 5); verify multiple-notes scenarios "Click trash with two notes open", "Removed note stays removed", and "Click trash while another app is frontmost", and notes-menu scenarios "Delete the last note" and "Launch with no notes"

## 5. Integration

- [x] 5.1 Run `defaults delete com.alvarezjorge.Notely` and launch; verify notes-menu scenario "First launch" and sticky-note scenarios "First launch" and "First launch position", then restore the backup with `defaults import com.alvarezjorge.Notely ~/notely-backup.plist`
- [x] 5.2 Run `openspec validate add-notes-menu --strict`, then walk every scenario in the five delta specs on the final build from `just run`; verify all pass, including multiple-notes "Relaunch with three notes" and app-controls "Quit from Dock" with the menu and two notes open

## 6. Follow-up from review

- [x] 6.1 Add `HoverHighlight` to menu rows and the chooser's back control; verify notes-menu scenario "Hover a row", and that "+ New List" does not change on hover
- [x] 6.2 Add `.fullScreenNone` and `.fullScreenDisallowsTiling` to note windows; verify notes-menu scenario "Tile the menu", and multiple-notes scenarios "Drag area buttons" and "Click a panel button" still pass
