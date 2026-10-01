# Tasks

The project has no test target, so each task is verified with a command and a manual check on the host Mac. Build and run with `just run` on macOS; the recipes do not run in the dkc Linux container. Before starting, back up the current notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. Data model

- [x] 1.1 In `Sources/Notely/main.swift`, add `kind`, `title`, and `items` to `Note`, add `ListItem`, and add the `NoteStore` list operations, the order-keeping `toggleItem`, and the plain-text `text` copy (design.md Decision 1); verify `swift build -c release` succeeds, and after `just run` on the backed-up data, every note opens as a note with its text unchanged (checklists scenario "Notes stay notes")

## 2. Shared window and menu entry

- [x] 2.1 Extract `NoteStrip` from `NoteView`, add `WindowContent` choosing `NoteView` or a placeholder `ListView` by `kind`, and use it in `openWindow(for:)` (design.md Decision 2); verify notes still show "−" and trash and that multiple-notes scenarios "Click '−'" and "Click trash with two notes open" still pass
- [x] 2.2 Replace `addNoteFromMenu()` with `addFromMenu(list:)`, enable "+ New List", add `listTitle(_:)` and the trailing `checklist` symbol on list rows (design.md Decisions 2 and 9); verify notes-menu scenarios "Open the chooser", "Back from the chooser", "Click '+ New List'" (except title focus, checked in 3.2), "List row", and "Notes and lists mixed", and that "Click '+ New Note'" still passes
- [x] 2.3 Verify checklists scenarios "Close and reopen a list", "Delete a list", "Relaunch with an open list" (frame only; content in 7.1), and "List window controls"

## 3. Editable fields and focus

- [X] 3.1 Add `ListField` (`NSTextField` wrapper with wrapping, American Typewriter, placeholder, `sizeThatFits`, and the delegate that reports changes, end of editing, and commands) (design.md Decision 3); verify the build succeeds
- [X] 3.2 Add `ListFocus` and the title row in `ListView`, saving on every change, and focus the title when a list is created (design.md Decisions 4 and 2); verify checklists scenarios "Name a list" and "Empty title", notes-menu scenario "Click '+ New List'" title focus, and that the menu row title follows typing

## 4. Items and the "New item" row

- [X] 4.1 Add the single `rows` `ForEach` with item rows (circle placeholder and `ListField`) and the "New item" row that turns into an item on first input (design.md Decision 5); verify checklists scenarios "Add the first item" and "Long item"
- [X] 4.2 Remove an item that is empty when it loses focus; verify checklists scenario "Empty item removed"
- [X] 4.3 Replace the overlay-scroller lookup with `firstScrollView` (design.md Decision 8); verify checklists scenario "Long list", and sticky-note scenarios "Idle long note", "Scroll a long note", and "New note" still pass for notes

## 5. Checking items

- [X] 5.1 Add `CheckCircle` with the dynamic fill color, wire it to `toggleItem` inside `withAnimation`, and show checked text struck through in the secondary color (design.md Decision 6); verify checklists scenarios "Check an item", "Most recently checked first", "Uncheck an item", and "Circle in light and dark appearance" (switch appearance in System Settings while the app runs), and that items slide to their new place

## 6. Keyboard

- [X] 6.1 Handle Return, Backspace in an empty item, Up, and Down through `ListCommand`s and focus requests (design.md Decisions 3 and 4); verify checklists scenarios "Return in the title", "Return in an item", "Backspace in an empty item", and "Arrow keys between rows", and that Return in a checked item moves focus to the "New item" row
- [X] 6.2 Handle `cancelOperation:` in the field delegate; verify checklists scenario "Esc in a list", and that Cmd+A, Cmd+C, Cmd+V, Cmd+X, and Cmd+Z work in the title and in an item
- [X] 6.3 Add the "Check Item" (Cmd+Return) Edit menu item and `toggleChecklistItem(_:)` with menu validation on `ListTextField` (design.md Decision 7); verify checklists scenario "Check from the keyboard", and that "Check Item" is disabled while a note, the title, or the "New item" row has focus (if it is always disabled, apply the fallback in design.md Risks)

## 7. Integration

- [X] 7.1 With two notes and two lists open, checked and unchecked items, and moved windows, quit with Cmd+Q within one second of typing in a list item and relaunch; verify checklists scenarios "Relaunch with an open list" and "Quit soon after typing in a list", and that `defaults read com.alvarezjorge.Notely notes` shows the plain-text copy in each list's `text`
- [X] 7.2 Type Option-e then e in the "New item" row; verify the item reads "é" (design.md Risks, marked text)
- [X] 7.3 Run `openspec validate add-checklists --strict`, then walk every scenario in both delta specs on the final build from `just run`; verify all pass

## 8. Follow-up from review

- [X] 8.1 Show all list text and every placeholder ("Untitled list", "New item", "Type a note…") in `NSColor.textColor`, with checked items struck through but not gray; verify checklists scenarios "Check an item" and "Empty title", and sticky-note scenario "Placeholder color", in both light and dark appearance
- [X] 8.2 Widen the gap between "−" and trash to 16 points; verify multiple-notes scenario "Drag area buttons" and note-resize scenario "Controls stay visible at minimum size"
- [X] 8.3 Add `confirmDelete(_:)` with a sheet whose default button is "Cancel", wired to trash in notes and lists; verify multiple-notes scenarios "Click trash with two notes open", "Cancel a delete", "Removed note stays removed", and "Click trash while another app is frontmost", checklists scenario "Delete a list", and notes-menu scenario "Delete the last note"
