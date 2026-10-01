# Design

## Context

All code is in `Sources/Notely/main.swift`. The parts this change touches:

- `NoteStore` holds `[Note]` (`id`, `text`, `origin`, `size`) as JSON under `notes` and saves on every change. When the decoded list is empty, it creates one empty note. That is how "Removing the last note quits the app" leads to one empty note on the next launch.
- `AppDelegate.openWindow(for:)` builds a `NoteWindow` (`[.titled, .resizable, .fullSizeContentView]`) with a transparent title bar and hides the close, minimize, and zoom buttons (`main.swift:430`). `AppDelegate` is the delegate for every note window. It finds the note by looking up the window in `windows: [UUID: NoteWindow]`.
- `NoteView`'s drag strip shows two `StripButton`s, "minus" (`onRemove`) and "plus" (`onAdd`).
- `addNote(after:)` places a new note 24 points left of and below the source note, at the source note's size. `removeNote(_:)` drops the delegate, deletes the note, closes the window, and terminates when no window is left.
- The pure helpers `clamp`, `fit`, `parsePair`, `savedSize`, and `restoredFrame` handle every frame rule.

There is no test target. The target is macOS 13 with an AppKit lifecycle. See proposal.md for motivation and the five delta specs for required behavior.

## Goals / Non-Goals

**Goals:**
- Reuse the existing frame helpers for the menu frame and the new-note frame, so every window uses one set of on-screen rules.
- Keep note windows exactly as they are, apart from their two strip buttons.
- Keep saved data readable in both directions, from older builds to this one and back.

**Non-Goals:**
- Keeping the chooser open across launches. The menu always opens on the note list.
- Keyboard navigation of menu rows (arrow keys, Return). Rows are mouse-only in this change.
- Keeping the z-order between the menu and notes across launches.

## Decisions

### 1. `isOpen: Bool?` on `Note`, and an empty list stays empty
Add `var isOpen: Bool?` to `Note`. `nil` means open, so notes saved by earlier versions decode and open as before. The "Notes saved by an earlier version" scenario relies on this. `NoteStore` gains `setOpen(_:for:)`, which saves like every other setter.

The empty-list fallback changes. A decoded empty list now stays empty, which the "Launch with no notes" scenario requires. Only a missing `notes` key still creates one note, through the existing legacy migration. That migration gives one empty note on a true first launch. An undecodable list also gives one empty note, as today, so bad data never leaves the user with nothing.

Alternative: store open note ids in a separate key. Rejected because two keys can disagree after a crash between writes, which is the same reason one list was chosen in the earlier multiple-notes design.

### 2. Menu window is a plain `NSWindow` with its own delegate
Build the menu window in `openMenuWindow()` with the style mask `[.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]`, a transparent title bar, a hidden title, and the standard buttons left visible. Set `collectionBehavior` to include `.fullScreenPrimary`, so green offers full screen and holding green shows the tiling options. Set `minSize` to 200 by 200. Its content is an `NSHostingView` of `MenuView`, with `sizingOptions = []` as for notes. SwiftUI content respects the title-bar safe area, so rows start below the traffic lights.

A small `MenuWindowDelegate` class owns the menu's delegate methods:
- `windowShouldClose(_:)` calls `NSApp.terminate(nil)` and returns `false`. That makes red quit, which reuses the one quit path that Cmd+Q and the Quit menu items already use.
- `windowDidMove` and `windowDidResize` save the frame, except while the window is in full screen, so that relaunch restores the windowed frame.

Alternative: make `AppDelegate` the menu's delegate too, and branch on `window === menuWindow`. Rejected because every note delegate method would need that branch, and a missed one would write a menu frame into a note.

Alternative: `applicationShouldTerminateAfterLastWindowClosed` returning `true`, with red closing the window normally. Rejected because the menu would never be the "last window" while notes are open, so red would close the menu and leave the app running with no menu.

### 3. Menu frame saved under `menuFrame`, using existing helpers
Save `NSStringFromRect(frame)` under a new `UserDefaults` key `menuFrame`. At launch, split it into origin and size, then call `restoredFrame(saved:size:screens:)` with `fit` against `minimumMenuSize`. When that returns `nil`, use the default frame from `notes-menu`: 260 by 360 points, 20 points from the top and left of `NSScreen.main.visibleFrame`.

`restoredFrame` and `fit` currently floor sizes at `minimumNoteSize`. Give `fit` a `minimum` parameter that defaults to `minimumNoteSize`, and pass that parameter through `restoredFrame`. Note call sites stay unchanged.

Alternative: `setFrameAutosaveName`. Rejected because AppKit's autosave does not promise the frame is fully inside a visible area, which the spec requires. It would also be a second persistence mechanism next to the `notes` key.

### 4. `MenuView`: list and chooser in one SwiftUI view
`MenuView(store:onOpen:onNewNote:)` holds `@State var showingChooser = false`.

- **List:** a `ScrollView` with a `VStack` of full-width plain `Button` rows separated by `Divider`s, matching the sketch. The rows are "+ New" and then `store.notes.reversed()`. Store order is creation order, because `add` appends, so reversing it gives newest first with no new field. Each row title comes from a pure `noteTitle(_ text: String) -> String`: the first line that is not empty after trimming whitespace, or "Untitled note". `NoteStore` is an `ObservableObject`, so titles update as the user types.
- **Chooser:** a top row with a trailing `Button` that shows SF Symbol `arrow.left` and has the accessibility label "Back". Under it are "+ New Note" and a `.disabled(true)` "+ New List" row. "+ New Note" calls `onNewNote()` and then sets `showingChooser = false`.

Rows use `noteFont`, so the menu matches the notes' typeface. A `HoverHighlight` modifier gives enabled rows and the back control a `Color.primary.opacity(0.08)` background while hovered. That background is lighter on a dark appearance and slightly darker on a light one, so it works in both.

Alternative: SwiftUI `List`. Rejected because `List` adds selection highlighting and inset styling that the sketch does not show, and plain-button rows are simpler to make full-width hit targets.

### 5. Note strip: "−" closes, trash deletes
In `NoteView`, replace `onAdd` and `onRemove` with `onClose` and `onDelete`. The strip shows `StripButton(symbolName: "minus", accessibilityLabel: "Close Note", action: onClose)` and then `StripButton(symbolName: "trash", accessibilityLabel: "Delete Note", action: onDelete)`. Both keep `acceptsFirstMouse` and `referenceSize`, so the existing first-click and no-drag behavior carries over.

`AppDelegate` gains these functions:
- `detachWindow(_ id:) -> NoteWindow?`: moved out of `removeNote`. It clears the delegate, drops `windows[id]` and the scroller observation, and returns the window.
- `closeNote(_ id:)`: `detachWindow`, then `store.setOpen(false, for: id)`, then `window.close()`.
- `removeNote(_ id:)`: `detachWindow`, then `store.remove(id)`, then `window.close()`. It no longer calls `terminate`.
- `openNote(_ id:)`: when `windows[id]` exists, `makeKeyAndOrderFront`. Otherwise, `store.setOpen(true, for: id)`, `openWindow(for:)`, then `makeKeyAndOrderFront`. The overlay scroller is applied in `openWindow`, so reopened notes keep the scroller behavior.

The delegate must be cleared before `close()`, as today, so a closed note does not save a frame it never chose.

Note windows add `.fullScreenNone` and `.fullScreenDisallowsTiling` to their `collectionBehavior`. Titled, resizable windows can take part in full screen and tiling by default. Without these flags, macOS offers notes as the second tile when the menu is tiled.

### 6. New-note frame next to the menu
Replace `addNote(after:)` with `addNoteFromMenu()`, which uses a pure `newNoteFrame(menu: NSRect, screen: NSRect) -> NSRect`:
1. `size = fit(defaultNoteSize, into: screen)`.
2. Right candidate: `x = menu.maxX + 12` and `y = menu.maxY - size.height`, so the top edges align. Return it when `screen.contains(rect)`.
3. Left candidate: `x = menu.minX - 12 - size.width`, same `y`. Return it when it is inside the screen.
4. Otherwise, return the right candidate with its origin from `clamp(_:into:)`.

The screen is `menuWindow.screen?.visibleFrame`, then `NSScreen.main?.visibleFrame`. Then `store.add(origin:size:)`, `openWindow(for:)`, `makeKeyAndOrderFront`, and focus the text view on the next run-loop turn, as the current `addNote` does.

### 7. Launch order and Dock reopen
`applicationDidFinishLaunching` sets the main menu, opens the menu window, then opens each note where `isOpen != false`. Notes open after the menu, so they stack in front of it on a cluttered screen.

`applicationShouldHandleReopen` deminiaturizes the menu window when `isMiniaturized`, then orders the menu and every note window to the front.

## Risks / Trade-offs

- [Menu in full screen when "+ New Note" is clicked] Note windows have no `.fullScreenAuxiliary`, so the new note opens on the desktop Space. macOS then switches Spaces, and the menu's screen frame is the full-screen frame. → The `clamp` in step 4 still keeps the note on screen. The spec rule "shows only on the Space where it is open" stays intact. Accept and verify manually. Allowing notes over full screen is a later decision.
- [Red quits instead of closing] This differs from most Mac apps, where red closes a window. → The user asked for it explicitly. Cmd+W is not bound, so no other path closes the menu.
- [Rollback with an empty list] An older build turns an empty `notes` list into one empty note. → No data loss. The extra note is empty.
- [Rollback with closed notes] An older build ignores `isOpen` and opens every note. → No data loss. Closed notes become open, which is the earlier behavior.
- [Title updates on every keystroke] Every keystroke republishes `notes`, and the menu rebuilds all rows. → Note counts are small. If typing lags with many notes, extract rows into an `Equatable` subview.

## Migration Plan

No step runs at upgrade time. `isOpen` is optional and decodes as open. `menuFrame` is absent on the first launch, so the menu opens at its default frame. To roll back, install the previous build. See the rollback items in Risks for the effects.
