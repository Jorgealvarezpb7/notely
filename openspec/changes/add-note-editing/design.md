# Design

## Context

All code is in `Sources/FloatingWidget/main.swift`. `AppDelegate` creates an `NSPanel` with style mask `[.borderless, .nonactivatingPanel]`, level `.floating`, `isMovableByWindowBackground = true`, and hosts a SwiftUI `WidgetView` with fixed 220x150 size. The app uses activation policy `.accessory` (no Dock icon). There is no state and no persistence. Target is macOS 13, so SwiftUI APIs newer than macOS 13 are not available without availability checks.

See proposal.md for motivation and specs/sticky-note/spec.md for required behavior.

## Goals / Non-Goals

**Goals:**
- Keystrokes reach the SwiftUI text area inside a borderless, non-activating panel.
- Keep the single-file structure; the change stays small.

**Non-Goals:**
- A reusable note model or store for multiple notes later. Design for one note only.
- Saving panel position. The panel keeps its current top-right start position.

## Decisions

### 1. `NSPanel` subclass that can become key
A borderless `NSWindow`/`NSPanel` returns `false` from `canBecomeKey`, so the text view never gets keyboard events. Add a `NotePanel: NSPanel` subclass with `override var canBecomeKey: Bool { true }`. Keep `canBecomeMain` as `false`.

Keep `.nonactivatingPanel`: the panel becomes key without activating the app, which satisfies "Editing does not steal app focus".

Alternative: use a titled window with a hidden title bar. Rejected: it changes the look, and the title bar still activates the app on click.

### 2. SwiftUI `TextEditor` for the note area
Use `TextEditor(text:)` bound to the note text, with `.scrollContentBackground(.hidden)` so the existing `.ultraThinMaterial` background shows through (available on macOS 13). Placeholder: an overlaid `Text` shown only when the text is empty, with `allowsHitTesting(false)`.

Alternative: wrap `NSTextView` in `NSViewRepresentable`. Rejected for now: more code, and `TextEditor` already gives undo, copy, paste, and scrolling. Revisit only if Esc handling (Decision 4) fails with `TextEditor`.

### 3. Persistence with `@AppStorage`
Store the text in `UserDefaults.standard` under key `noteText` through `@AppStorage("noteText")`. `UserDefaults` writes are cached in memory and flushed by the system, and it flushes on normal termination. This covers "Save without explicit action" with no custom debounce.

Alternative: JSON file in Application Support. Rejected: only needed for many notes or export, which are out of scope.

Note: the binary is run from `.build/release` without a bundle identifier, so the defaults domain is the executable name (`FloatingWidget`). This is acceptable; it becomes the bundle ID later if the app is packaged.

### 4. Esc ends editing
Esc on a focused `NSTextView` sends `cancelOperation(_:)` up the responder chain. Override `cancelOperation(_:)` in `NotePanel` to call `makeFirstResponder(nil)`. This removes the caret and keeps the text.

Alternative: SwiftUI `@FocusState` with `.onKeyPress(.escape)`. Rejected: `onKeyPress` needs macOS 14.

### 5. Drag area
Set `isMovableByWindowBackground = false` on the panel, and add a thin header strip (about 16 pt high, with a small grip indicator) above the text area. The strip is an `NSViewRepresentable` whose `NSView` overrides `mouseDown(with:)` to call `window?.performDrag(with: event)`. Dragging in the text area then selects text only.

Alternative: keep `isMovableByWindowBackground = true` and rely on padding around the text. Rejected: with a background-movable window, clicks on non-text SwiftUI areas are unpredictable, and the drag target is not visible to the user.

## Risks / Trade-offs

- [`TextEditor` inside a non-activating panel may not show the caret or accept first click] → Verify manually during implementation. If it fails, switch to the `NSTextView` wrapper from Decision 2.
- [`cancelOperation` may be handled by `TextEditor` before reaching the panel] → Verify manually. Fallback: `NSViewRepresentable` `NSTextView` subclass that handles Esc itself.
- [Force-quit (`kill -9`) can lose the last unflushed keystrokes] → Accepted. The spec requires persistence only for normal quit.
- [Removing the clock is user-visible] → Intended; recorded as BREAKING in the proposal.

## Migration Plan

No data to migrate. Rollback: revert the change to `main.swift`. The stored `noteText` key is ignored by the old version.
