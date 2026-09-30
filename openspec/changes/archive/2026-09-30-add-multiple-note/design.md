# Design

## Context

All code is in `Sources/Notely/main.swift`. `AppDelegate` creates one `NotePanel` (`[.borderless, .nonactivatingPanel]`, `canBecomeKey` is `true`), holds it in a single `panel` property, and is its `NSWindowDelegate`. `NoteView` binds its `TextEditor` to `@AppStorage("noteText")`. The drag strip is a `ZStack` of `DragHandle` and `CloseButton` (the standard close button wrapped in `NSViewRepresentable`, target `NSApp`, action `terminate(_:)`). `windowDidMove(_:)` saves `NSStringFromPoint(panel.frame.origin)` under `panelOrigin`. At launch, `restoredOrigin(saved:size:screens:)` turns that string into an origin, or returns `nil` so the caller uses the top-right default. The hidden main menu and the status item do not reference the panel. There is no test target. Target is macOS 13, AppKit lifecycle.

After first building this change, the user tried it and asked to remove the panel close button entirely: it always quit the whole app rather than closing one note, which added no value once "+" and "−" exist. Quitting is now only the menu bar item's Quit item and Cmd+Q. The decisions and code below reflect that; `CloseButton` is deleted rather than kept unused.

See proposal.md for motivation and the three delta specs for required behavior.

## Goals / Non-Goals

**Goals:**
- Keep one quit code path (`NSApp.terminate(_:)`) for Cmd+Q, the menu bar item, and removal of the last note.
- Keep every panel identical to today's panel: size, material, corner radius, level, collection behavior, non-activating focus.
- Keep the single-file structure and the pure `restoredOrigin` function.

**Non-Goals:**
- Spreading out notes that open at the same default position (for example, several notes whose saved screen is gone). They stack exactly, which the specs allow.
- Keeping z-order between notes across launches. Panels open in list order.
- Undo for a removed note.

## Decisions

### 1. One JSON list of notes in `UserDefaults`
Model a note as `struct Note: Codable, Identifiable { let id: UUID; var text: String; var origin: String? }`. `origin` keeps the `NSStringFromPoint` format so `restoredOrigin` works unchanged. Store the whole list as JSON `Data` under a new key `notes`.

A `NoteStore: ObservableObject` owns `@Published var notes: [Note]`, loads at launch, and writes the list to `UserDefaults` on every change. This keeps today's timing: `@AppStorage` also writes on every keystroke, and normal termination flushes `UserDefaults`, which is what the "Save without explicit action" and "Quit soon after typing" scenarios rely on. Encoding a few short notes per keystroke is cheap.

Alternative A: one key per note (`note.<uuid>.text`, `note.<uuid>.origin`) plus a list of ids. Rejected: removal must delete several keys, and a crash between writes leaves orphans. Alternative B: a JSON file in Application Support. Rejected: adds file I/O and error paths for no gain at this size.

### 2. One panel per note, owned by `AppDelegate`
Replace `var panel: NotePanel!` with `var panels: [UUID: NotePanel]`. Move the current panel setup into `makePanel(for note: Note) -> NotePanel`, which builds the panel, sets its content to `NoteView(store:id:onAdd:onRemove:)`, positions it, sets the delegate last (as today, so positioning never writes an origin), and calls `orderFrontRegardless()`.

`windowDidMove(_:)` finds the note id by the moved window (`notification.object`) and writes the new origin into the store.

`NoteView` takes the store and a note id instead of `@AppStorage`, and binds the `TextEditor` to a `Binding` that reads and writes that note's text in the store. The placeholder check reads the same text.

### 3. Launch and migration
At launch, `NoteStore` loads:
1. `notes` key present: decode it. If the list is empty (the last note was removed), use one new empty note with `origin` `nil`.
2. `notes` key absent: build one note from `noteText` (default `""`) and `panelOrigin` (may be `nil`), save it under `notes`, then remove `noteText` and `panelOrigin`.
3. `notes` present but not decodable: treat as case 1 with an empty list. Leave the bad data in place until the next write replaces it.

Then `AppDelegate` calls `makePanel(for:)` for each note. Each origin comes from `restoredOrigin` with the note's saved string, or the existing top-right default when it returns `nil`.

Alternative: keep reading `noteText` and `panelOrigin` for the first note forever. Rejected: two storage formats for one concept, and removing the first note would need special cases.

### 4. "+" and "−" as AppKit buttons in the drag strip, close button removed
Delete `CloseButton` and its `.closeButton` usage; the panel's `styleMask` stays `[.borderless, .nonactivatingPanel]`, so it never had a title bar or system buttons of its own. Add one `NSViewRepresentable` `StripButton(symbolName:accessibilityLabel:action:)` that makes a borderless `NSButton` with an SF Symbol image (`plus`, `minus`) and an accessibility label ("New Note", "Remove Note"). It uses an `NSButton` subclass that returns `true` from `acceptsFirstMouse(for:)`, so one click works while another app is frontmost (the "Click '+'/'−' while another app is frontmost" scenarios). Place "−" and then "+" at the trailing edge of the strip, on top of `DragHandle`, so clicks on them never reach `DragView.mouseDown`. The grip stays centered. `StripButton.referenceSize` reads the standard close button's natural size (`NSWindow.standardWindowButton(.closeButton, for:)`, never shown) purely as a sizing constant, so the strip height and button hit targets stay what they were with the close button.

The buttons call closures that `AppDelegate` passes in: `onAdd` and `onRemove`, both with the note id.

Alternative: SwiftUI `Button`. Rejected: in a non-activating panel, whether the first click reaches a SwiftUI button is not documented; `acceptsFirstMouse` on a plain `NSButton` is the same mechanism this design already needed when the close button carried that scenario.

### 5. Placing and focusing a new note
`addNote(after id:)`:
1. Compute the frame at the source origin + (−24, −24).
2. Clamp it inside the `visibleFrame` of the source panel's screen (`panel.screen`, falling back to `NSScreen.main`), shifting x and y only. Extract this clamp from `restoredOrigin` into `clamp(_ frame: NSRect, into screen: NSRect) -> NSPoint` and have `restoredOrigin` call it, so both paths use the same rule.
3. Append a note with that origin to the store and call `makePanel(for:)`.
4. Give it focus without activating the app: `panel.makeKey()`, then on the next run loop turn (after SwiftUI builds the `TextEditor`) find the first `NSTextView` in the panel's view hierarchy and call `panel.makeFirstResponder(_:)` on it.

Alternative for step 4: SwiftUI `@FocusState` set in `onAppear`. Rejected as the primary path: it depends on the hosting view already being in a key window when `onAppear` runs. It is the fallback for Risk 1.

### 6. Removing a note
`removeNote(_ id:)`: remove the note from the store (which saves), set the panel's delegate to `nil` so closing does not write an origin, `close()` the panel, and drop it from `panels`. If `panels` is now empty, call `NSApp.terminate(nil)`. The saved list is then empty, and Decision 3 case 1 gives one empty note at the default position on the next launch.

The removal is immediate, as the proposal states. The "−" button is at the opposite end of the strip from the close button to lower the chance of a wrong click.

## Risks / Trade-offs

- [Risk 1: the new note does not receive keystrokes, because the `NSTextView` is not in the hierarchy yet or `makeKey()` does not take effect for a non-activating panel] → Verify the "Click '+'" scenario manually with another app frontmost. If it fails, try the `@FocusState` fallback from Decision 5.
- [Risk 2: `acceptsFirstMouse` on the button is not enough, and the first click only makes the panel key] → Verify the "while another app is frontmost" scenarios manually. If it fails, also return `true` from `acceptsFirstMouse` in a container view around the buttons.
- [With the close button gone, a user who does not open the menu bar item has no on-panel way to quit] → Accepted, per the user's explicit request. Cmd+Q and the menu bar item's Quit item remain.
- ["−" deletes text with no confirmation and no undo] → Accepted, per the user's choice. Mitigated by button placement (Decision 6). A confirmation or undo is a possible follow-up.
- [Every keystroke re-encodes and writes the whole list] → Accepted for a handful of short notes. Revisit only if typing lags with many long notes.
- [Several notes can open at the exact same default position and hide each other] → Accepted, listed as a non-goal. Only happens when saved screens are gone.
- [Removing a note while a different panel is key changes nothing about focus, but removing the key panel leaves no key window] → Accepted. Cmd+Q then goes to the frontmost other app, which matches the "Cmd+Q in another app" boundary.

## Migration Plan

1. First launch of the new build runs Decision 3 case 2: the existing note text and position move to `notes`, and `noteText` and `panelOrigin` are removed. Verify with `defaults read com.alvarezjorge.Notely` before and after.
2. Rollback: install the previous build. It finds no `noteText` or `panelOrigin` and opens one empty note at the default position. The `notes` key is left alone, so reinstalling the new build restores all notes. To bring the text back into the old build by hand, copy it from `defaults read com.alvarezjorge.Notely notes`.
