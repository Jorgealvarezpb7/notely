# Proposal

## Why

Notely's menu offers "+ New List", but the row is a disabled placeholder. Users who keep to-do or shopping lists in a plain note must type their own markers and cannot tick items off. A real checklist, with a title, items, and a circle to check each item, makes Notely useful for the most common kind of sticky note.

## What Changes

- "+ New List" in the menu's chooser becomes active. It creates a new list and opens its window next to the menu, at the default note size, with keyboard focus in the list's title.
- A list window has the same drag strip, "−" (close), and trash (delete) buttons as a note window, and the same resizing, frame persistence, layering, and open/closed behavior.
- A list window shows a title row at the top, with the placeholder "Untitled list", and the list's items below it.
- Each item shows an Apple-style circle and its text. Clicking the circle checks the item: the circle fills (white in dark mode, dark gray in light mode), the text is struck through, and the item moves to the top of the checked items at the bottom of the list. Unchecking moves it back to the end of the unchecked items.
- An empty "New item" row always follows the unchecked items. Typing into it creates an item.
- Keyboard editing: Return adds an item, Backspace in an empty item removes it, Up and Down move between rows, Cmd+Return checks or unchecks the focused item, and Esc ends editing. An item left empty is removed when it loses focus.
- The menu lists lists with notes, newest first. A list's row shows its title, or "Untitled list", and a checklist icon.
- Lists are saved with notes on every change and restored at launch.

Out of scope: converting a note into a list or back, reordering items by dragging, nested items, due dates, a "clear checked items" action, sharing, and per-item delete buttons.

## Capabilities

### New Capabilities
- `checklists`: The list window and its shared window behavior, the title, items, checking and unchecking with the circle, the order of checked items, keyboard editing, and saving lists.

### Modified Capabilities
- `notes-menu`: "Note list" rows include lists, with their own title rule and icon. "New chooser" changes, because "+ New List" is no longer a placeholder. A new requirement, "Create a list from the menu", places a new list the same way as a new note.

## Impact

- Code: `Sources/Notely/main.swift` only. `Note` gains optional `kind`, `title`, and `items` fields. A new `ListView` uses an AppKit `NSTextField` wrapper for the title and each item, so Return, Backspace, and the arrow keys can be handled on macOS 13. `MenuView` enables "+ New List" and shows list rows. `AppDelegate` opens a `ListView` for list notes. The Edit menu gains a "Check Item" (Cmd+Return) item. The overlay-scroller helper finds the window's scroll view directly, so list windows get the same scroll bar behavior as notes.
- Storage: lists live in the existing `notes` key. A note saved without `kind` is a plain note, so existing data loads unchanged. Each list also writes a plain-text copy of itself into `text`, so an older build shows a list's content as a readable note.
- Rollback: an older build opens each list as a note showing that plain-text copy. Editing it there turns it into a note, and its items are lost as a list.
- Dependencies: none added. AppKit and SwiftUI only. Target stays macOS 13.
