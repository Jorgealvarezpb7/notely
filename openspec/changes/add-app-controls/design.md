# Design

## Context

All code is in `Sources/FloatingWidget/main.swift`. `AppDelegate` creates a `NotePanel` (`NSPanel` subclass, `[.borderless, .nonactivatingPanel]`, `canBecomeKey` is `true`). The panel hosts SwiftUI `NoteView`: a 16 pt `DragHandle` strip above a `TextEditor` bound to `@AppStorage("noteText")`. The app uses activation policy `.accessory`, sets no `NSApp.mainMenu`, and creates no status item. The panel origin is set to the top-right of `NSScreen.main.visibleFrame` with a 20 pt margin on every launch. Target is macOS 13. The app uses the AppKit lifecycle (`NSApplication.shared.run()`), not a SwiftUI `App`.

The app never becomes the active application. Clicking the panel makes the panel the key window, so keyboard events go to this app, but the menu bar keeps showing the other app's menus.

See proposal.md for motivation and specs/app-controls/spec.md and specs/sticky-note/spec.md for required behavior.

## Goals / Non-Goals

**Goals:**
- One quit code path: every control calls `NSApp.terminate(_:)`, so normal termination flushes `UserDefaults` for all of them.
- Keep the borderless panel, its 22 pt rounded material background, and the non-activating focus behavior from the archived `add-note-editing` change.
- Keep the single-file structure.

**Non-Goals:**
- Reacting to screen changes while the app runs. The position check happens only at launch.
- A different position per Space or per display arrangement. There is one saved origin.
- Matching the title-bar hover glyph (the "x" inside the red button) exactly.
- Localized menu titles.

## Decisions

### 1. Hidden main menu for editing shortcuts and Cmd+Q
Set `NSApp.mainMenu` at launch with two menus:
- App menu: "Quit FloatingWidget", key equivalent Cmd+Q, action `NSApplication.terminate(_:)`.
- Edit menu: Undo (`undo:`, Cmd+Z), Redo (`redo:`, Shift+Cmd+Z), Cut (`cut:`), Copy (`copy:`), Paste (`paste:`), Select All (`selectAll:`). Target `nil`, so each action goes to the first responder (the `TextEditor`'s text view).

AppKit routes Cmd key equivalents through the main menu. With no main menu, Cmd+C and the other shortcuts reach nothing, which is the cause of the broken shortcuts. When the panel is key, `NSApplication` checks the key window and then `mainMenu` for key equivalents, even though the app is not active. The menu bar never shows these menus, because the app never becomes active.

Alternative: override `performKeyEquivalent(with:)` in `NotePanel` and map each shortcut to `NSApp.sendAction(_:to:from:)`. Rejected as the primary fix: it re-implements standard menu routing by hand. It stays as the fallback if Risk 1 happens.

### 2. Status item with `NSStatusItem`
Create `NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)` in `AppDelegate` and keep a strong reference, because a released status item disappears. The button image is SF Symbol `note.text` (`NSImage(systemSymbolName:accessibilityDescription:)`, macOS 11+), marked as a template so it follows the menu bar appearance. The menu has one item, "Quit FloatingWidget", with action `NSApplication.terminate(_:)`. Its Cmd+Q key equivalent is display-only while the menu is open. Decision 1 handles Cmd+Q elsewhere.

Alternative: SwiftUI `MenuBarExtra` (macOS 13+). Rejected: it needs the SwiftUI `App` lifecycle, and this app runs its own `NSApplication`.

### 3. Standalone native close button in the drag strip
Get the button with `NSWindow.standardWindowButton(.closeButton, for: [.titled, .closable])` and wrap it in an `NSViewRepresentable` (`CloseButton`). Set its target to `NSApp` and its action to `NSApplication.terminate(_:)`. Place it at the leading edge of the drag strip, over `DragHandle`. The grip indicator stays centered. The strip height is 16 pt or the button height, whichever is larger, so the button is not clipped on macOS versions with a larger button.

The button is a separate view on top of `DragHandle`, so a click on the button goes to the button and does not start a panel drag. Clicks on the rest of the strip still reach `DragView.mouseDown`.

Alternative A: change the panel to `[.titled, .fullSizeContentView, .nonactivatingPanel]` with a transparent, hidden title bar, and hide the minimize and zoom buttons. This gives native title-bar dragging and the hover glyph. Rejected: it changes the corner radius and shadow to the system window look, the title bar (about 28 pt) is taller than the current strip, and it changes the style mask that the previous change verified for non-activating focus.

Alternative B: a custom SwiftUI red circle. Rejected: it is not the native control the user asked for. It is the fallback for Risk 2.

### 4. Explicit panel position save and restore
Save the panel origin in `UserDefaults` under key `panelOrigin` as `NSStringFromPoint(panel.frame.origin)`. `AppDelegate` becomes the panel's `NSWindowDelegate` and saves in `windowDidMove(_:)`. Saving on every move, not at quit, keeps the last position even after a crash or `kill`. Set the delegate after the launch positioning, so launch does not write a value the user never chose.

At launch, compute the origin before `orderFrontRegardless()`:
1. No saved value, or the value does not parse: use the default (top-right of `NSScreen.main.visibleFrame`, 20 pt margin), as today.
2. Build the saved frame from the saved origin and the panel size. Find the screen whose `visibleFrame` has the largest intersection with it. If no screen intersects it, use the default.
3. Otherwise clamp the frame inside that screen's `visibleFrame` by shifting x and y only. This is the shortest move that makes the panel fully visible.

Put steps 1 to 3 in one function that takes the saved string, the panel size, and the screen frames and returns an origin. It has no AppKit side effects, so a test target can call it later.

Alternative: `panel.setFrameAutosaveName(_:)`. Rejected: AppKit does not document what it does for a borderless window when the saved screen is gone or the frame is partly off-screen, and the spec requires exact fallback behavior. The explicit code is about 20 lines.

## Risks / Trade-offs

- [Risk 1: main menu key equivalents do not fire while the app is inactive] → Verify every shortcut manually with another app frontmost. If one fails, use the `performKeyEquivalent(with:)` fallback from Decision 1 for all of them.
- [Risk 2: the standalone close button needs two clicks when another app is frontmost (first click only makes the panel key)] → Verify manually against the scenario "Click close button while another app is frontmost". If it fails, replace it with the custom button from Decision 3, Alternative B, in a view that returns `true` from `acceptsFirstMouse(for:)`.
- [The standalone close button may not show the "x" glyph on hover, because only a title bar tracks hover for its buttons] → Accepted. The red button is still recognizable. Listed as a non-goal.
- [After Esc, the panel stays the key window with no first responder, so Cmd+Q still quits the note app until the user clicks another app's window] → Accepted. The spec defines the Cmd+Q boundary by which window has keyboard focus, and this matches it.
- [Undo depends on the `TextEditor`'s text view having undo enabled] → Verify Cmd+Z and Shift+Cmd+Z manually. If undo does nothing, the text view's `allowsUndo` is off; enabling it needs access to the underlying `NSTextView`, which is a follow-up.
- [A new menu bar icon is always visible while the app runs] → Intended. This reverses the previous change's "no menu bar item" non-goal (see proposal.md, Impact).

## Migration Plan

No data to migrate. The first launch after the change has no `panelOrigin`, so the panel opens at the current default position. Rollback: revert `main.swift`. The old version ignores `panelOrigin`, and the status item goes away with it.
