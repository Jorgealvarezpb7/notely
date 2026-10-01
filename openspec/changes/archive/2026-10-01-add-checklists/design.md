# Design

## Context

All code is in `Sources/Notely/main.swift`. Relevant current state:

- `Note` has `id`, `text`, `origin`, `size`, and `isOpen`. `NoteStore` saves the whole `[Note]` as JSON under `notes` on every change. A decode failure of the list falls back to one empty note and overwrites the saved data on the next save.
- `openWindow(for:)` builds a `NoteWindow` whose content is `NoteView`. `NoteView` draws the drag strip (`DragHandle`, then `StripButton` "minus" and "trash") above a `TextEditor`.
- `MenuView` shows `MenuRow`s. "+ New List" is a disabled placeholder. `addNoteFromMenu()` places the window with `newNoteFrame(menu:screen:)` and focuses `firstTextView`.
- `applyOverlayScroller(to:)` finds the scroll view through `firstTextView?.enclosingScrollView`.
- `NoteWindow.cancelOperation` resigns first responder, so Esc ends editing.
- The target is macOS 13. SwiftUI's `onKeyPress` (macOS 14) is not available, and there is no test target.

See proposal.md for motivation, and the `checklists` and `notes-menu` delta specs for required behavior.

## Goals / Non-Goals

**Goals:**
- Lists reuse every window path that notes use: open, close, delete, frame saving, and restore at launch. Lists add no second window type.
- Saved data stays readable both ways. Old notes stay notes, and an older build shows a list's content as text.
- Keep macOS 13 as the target.

**Non-Goals:**
- Keeping strikethrough while a checked item is being edited. See Risks.
- Undo across item operations (check, add, remove). Undo works only inside one field's text, as AppKit gives it.
- Rich text in items.

## Decisions

### 1. Lists are `Note`s with a `kind`
Add these fields to `Note`:
- `var kind: String?`: `"list"` for lists. `nil` or any other value is a note.
- `var title: String?`
- `var items: [ListItem]?`

`struct ListItem: Codable, Identifiable { let id: UUID; var text: String; var done: Bool }`.

`kind` is a `String`, not an enum. If a future build adds a third kind, an enum would fail to decode the whole list, and `NoteStore` would replace every note with one empty note. A string keeps unknown kinds loading as notes.

**Array order is display order:** the unchecked items first, then the checked items with the most recently checked first. Every store operation keeps this order, so no `checkedAt` timestamp is needed, and the view draws the array as it is.

`NoteStore` gains these list operations. Each one saves, like the existing setters:
- `addList(origin:size:)`
- `setTitle(_:for:)`
- `appendItem(_:for:) -> UUID`, which inserts at the end of the unchecked items
- `insertItem(after:for:) -> UUID`
- `setItemText(_:item:for:)`
- `removeItem(_:for:)`
- `toggleItem(_:for:)`

`toggleItem` removes the item, flips `done`, and inserts it at index `uncheckedCount`. For a newly checked item, that index is the top of the checked items. For a newly unchecked item, it is the end of the unchecked items. One rule covers both cases.

**Rollback copy:** after each list operation, the store writes `text = title + "\n" + items.map { (done ? "[x] " : "[ ] ") + text }`. The app itself never reads `text` for a list. The copy exists only so an older build shows the list's content.

Alternative: a separate `lists` key with its own type. Rejected because opening, closing, deleting, frame saving, and menu ordering would all need a second code path, and "newest first across notes and lists" would need a merged ordering.

### 2. One window path, content chosen by kind
Pull the drag strip out of `NoteView` into `NoteStrip(onClose:onDelete:)`. `NoteView` and the new `ListView` both use it. `ListView` places the strip as an `.overlay` above its `ScrollView`, not as the first row of a stack. When the strip came first, the scroll view's `NSScrollView` sat above it in AppKit's view order and reached under the transparent title bar, so it took the clicks meant for "−" and trash.

`openWindow(for:)` builds the hosting view from `WindowContent(store:id:onClose:onDelete:)`. That view shows `ListView` when the note's `kind == "list"` and `NoteView` otherwise. Window setup, the delegate, frame saving, `closeNote`, `removeNote`, and `openNote` stay unchanged. This gives the "List windows behave like note windows" requirement for free.

`addNoteFromMenu()` becomes `addFromMenu(list: Bool)`. It uses the same `newNoteFrame` call and calls either `store.add` or `store.addList`. For focus, a note keeps the `firstTextView` focus, and a list requests focus on its title (Decision 4).

### 3. `ListField`: an `NSTextField` wrapper for every editable row
`ListField: NSViewRepresentable` makes a `ListTextField: NSTextField` that is borderless, has no background or focus ring, wraps, and has unlimited lines (`cell.wraps = true`, `usesSingleLineMode = false`, `lineBreakMode = .byWordWrapping`, `maximumNumberOfLines = 0`). It uses `NSFont(name: "AmericanTypewriter", size: 15)`, or `"AmericanTypewriter-Bold"` for the title, and shows a placeholder string.

`sizeThatFits(_:nsView:context:)` (macOS 13) returns `cell.cellSize(forBounds:)` at the proposed width, so wrapped items grow in height inside SwiftUI's layout.

The coordinator is the field's `NSTextFieldDelegate`:
- `controlTextDidChange` calls `onChange(text)`, which saves on every keystroke.
- `controlTextDidEndEditing` calls `onEndEditing`. The parent uses it to remove an item that is empty when it loses focus.
- `control(_:textView:doCommandBy:)` maps these selectors to `ListCommand`s and returns `true` when the parent handles them:
  - `insertNewline:` becomes `.return`.
  - `deleteBackward:` becomes `.deleteEmpty`, but only when the field is empty.
  - `moveUp:` becomes `.up`, but only when the caret's line fragment is the first.
  - `moveDown:` becomes `.down`, but only when the caret's line fragment is the last.
  - `cancelOperation:` ends editing with `window.makeFirstResponder(nil)`.

  Line fragments come from the field editor's `layoutManager`. When the caret is not on the first or last line, the delegate returns `false`, so AppKit moves the caret inside the field.

Alternative: raise the target to macOS 14 and use SwiftUI `TextField` with `onKeyPress` and `@FocusState`. Rejected because the user did not ask for a target change. The `NSViewRepresentable` pattern is also already in use (`DragHandle`, `StripButton`).

### 4. Focus requests through a per-window `ListFocus`
`ListView` owns `@StateObject var focus = ListFocus()`, which holds `request: FocusTarget?`. `FocusTarget` is `.title`, `.item(UUID)`, or `.newItem`, plus a caret position: at the end, or keep the current one.

Each `ListField` knows its own target. In `updateNSView`, when `focus.request` matches its target, the field calls `window.makeFirstResponder(field)` on the next run-loop turn, puts the caret at the end, and clears the request. The next run-loop turn is needed because a newly inserted row's view exists only after SwiftUI lays it out.

How each key maps to a request:

| Key | Result |
|---|---|
| Return in title | first item, or `.newItem` |
| Return in an unchecked item | `insertItem(after:)`, then focus that item |
| Return in a checked item | `.newItem` |
| Backspace in an empty item | `removeItem`, then focus the item above, or the title |
| Up | the row above |
| Down | the row below |

Row order for Up and Down is the display order: title, unchecked items, "New item", checked items.

### 5. "New item" row
`ListView` builds one `rows` array: the unchecked items, then a `.newItem` marker, then the checked items. It draws that array with a single `ForEach`, keyed by item id, with a fixed id for the marker. Using a single `ForEach` matters: an item that moves between the unchecked and checked groups keeps its identity, so it slides to its new place instead of fading out in one section and in in another.

The "New item" row is a `ListField` with the placeholder "New item" and no circle. On its first non-empty change, it calls `appendItem(text)`, clears its own string, and requests focus on the new item with the caret at the end.

Toggling runs inside `withAnimation(.easeInOut(duration: 0.2))`.

### 6. Check circle
`CheckCircle(done:action:)` is a plain SwiftUI `Button`:
- **Unchecked:** an 18-point `Circle().strokeBorder(.secondary, lineWidth: 1.5)`.
- **Checked:** the same circle filled with `checkFill`, a dynamic `NSColor(name:dynamicProvider:)` that returns `.white` for `.darkAqua` and `.darkGray` for `.aqua`.

The hit target is 24 by 24 points. A plain button does not take first responder, so clicking it leaves the focused field alone.

A checked item's field shows `attributedStringValue` with `.strikethroughStyle` and `secondaryLabelColor`.

### 7. Cmd+Return through the Edit menu
Add "Check Item" with key equivalent Return and `.command` to the Edit menu. Its action is `toggleChecklistItem:` and it has no target. While a field is edited, the field editor is the first responder and its `nextResponder` is the `NSTextField`. `ListTextField` implements `toggleChecklistItem(_:)`, which sends `.toggle`, and implements `validateMenuItem` so the item is enabled only for item fields. In notes, the title row, and the "New item" row, no responder handles the action, so AppKit disables the menu item automatically.

Alternative: a local `NSEvent` key monitor. Rejected because it is global state that must be filtered per window. The menu item can also be discovered in the menu bar.

### 8. Overlay scroller finds a scroll view directly
Replace the lookup `firstTextView?.enclosingScrollView` with a depth-first `firstScrollView` search on the content view. In a note window, that finds the `TextEditor`'s `NSScrollView`. In a list window, it finds the `NSScrollView` behind SwiftUI's `ScrollView`. The retry on the next run-loop turn and the `scrollerStyle` observation stay as they are.

### 9. Menu rows for lists
`MenuRow` gains an optional `trailingSymbol`. List rows pass `"checklist"`. A list row's title comes from `listTitle(_:)`: the title after trimming whitespace, or "Untitled list". "+ New List" calls `onNewList`, and the `.disabled(true)` is removed.

## Risks / Trade-offs

- [The responder chain may not reach the `NSTextField` for Cmd+Return] If the field editor's `nextResponder` is not the field on some macOS version, "Check Item" stays disabled. → Verify in tasks. The fallback is to handle `insertNewline:` with the Command modifier inside `doCommandBy` by reading `NSApp.currentEvent?.modifierFlags`.
- [Strikethrough is lost while a checked item is edited] The field editor draws its own text, not the field's attributed string. → Accept: the strike comes back when editing ends. This is noted as a non-goal.
- [Focus jump when the "New item" row becomes an item] Moving first responder after the first keystroke could drop marked text from an input method, such as an accented letter started with Option-e. → Accept for now. Test with Option-e then e. If it breaks, delay the switch until marked text is committed (`hasMarkedText()`).
- [Wrapped `NSTextField` height in SwiftUI] `sizeThatFits` must get a definite width, or the field stays one line. → `ListView` gives rows `.frame(maxWidth: .infinity)` inside a fixed-width scroll content. Verify with the "Long item" scenario.
- [Rollback loses list structure] An older build shows the text copy, and editing it there turns the list into a plain note. → This is documented in the proposal. There is no data loss until the user edits the list in the older build.

## Migration Plan

No step runs at upgrade time. The new fields are optional. Saved notes decode with `kind == nil` and open as notes. For rollback, see the last item in Risks.
