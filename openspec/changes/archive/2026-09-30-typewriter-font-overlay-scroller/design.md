# Design

## Context

All app code is in `Sources/Notely/main.swift`. `NoteView` shows the note as a SwiftUI `TextEditor` with `.font(.body)`, with a placeholder `Text("Type a note…")` on top of it when the note is empty. The placeholder's `.padding(.top, 8)` and `.padding(.leading, 5)` were tuned by eye to line up with the text view's first line in the system font.

On macOS, `TextEditor` is an `NSTextView` inside an `NSScrollView`. SwiftUI does not expose the scroll view's scroller style. The deployment target is macOS 13. The code already reaches into the hosting view's AppKit hierarchy once: `AppDelegate.addNote` uses the private `NSView.firstTextView` search on the next run loop turn to focus a new note.

The user's Mac shows a permanent scroll bar today: the "Show scroll bars" setting is "Always", or it is "Automatically" with a mouse connected. In both cases AppKit gives every scroll view the legacy scroller style.

## Goals / Non-Goals

**Goals:**
- Meet the two requirements in `specs/sticky-note/spec.md`, and keep all existing `sticky-note` scenarios passing (editing shortcuts, Esc, long text scrolls).
- Keep the AppKit reach-in small, in one place, and applied to every note window however it was opened.

**Non-Goals:**
- A font or size setting, or a menu to change them.
- Changing the scroll bar anywhere other than the note area. Notely has no other scroll views.
- Bundling a font file. American Typewriter ships with every macOS version the app supports.

## Decisions

### Font through `Font.custom` with a shared constant
Define one font value, `Font.custom("American Typewriter", size: 15, relativeTo: .body)`, and use it for both the `TextEditor` and the placeholder `Text`. 15 points is two points above the macOS body text size (13), chosen by the user after seeing the typeface; American Typewriter reads small at 13. `relativeTo: .body` keeps the size tied to the body text style if the system ever scales it.

One constant for both views keeps the placeholder and the typed text from drifting apart.

Alternative: set `NSTextView.font` through the AppKit reach-in. Rejected, because SwiftUI's `.font` modifier already reaches the underlying text view, and setting the font in two layers risks SwiftUI overwriting the AppKit value on update.

### Placeholder padding tuned by eye after the font change
American Typewriter has different ascender and line height values from the system font, so the placeholder's first line may no longer sit where the caret appears. Check it and adjust `.padding(.top, …)` and `.padding(.leading, …)` until the caret shows at the start of the placeholder text (spec scenario "Placeholder lines up with the caret"). The leading value comes from the text container's line fragment padding and should stay at 5.

### Overlay scroller set on the `NSScrollView` from `AppDelegate.openWindow`
After `openWindow` sets the hosting view as the window's content view, schedule `DispatchQueue.main.async` to find the note's text view with `firstTextView` and take its `enclosingScrollView`. On that scroll view, set `scrollerStyle = .overlay` and `autohidesScrollers = true`. Put this in one helper that takes a window, for example `applyOverlayScroller(to:)`.

`openWindow` runs for every note, both at launch and from "+", so one call site covers every window. The next run loop turn is when SwiftUI has built the text view, the same timing `addNote` already depends on.

Overlay style also gives the text the full width of the note area, because an overlay scroller takes no layout space (spec scenario "Idle long note").

Alternatives:
- `.scrollIndicators(.hidden)`: rejected. It follows the system setting, so it changes nothing on a Mac set to "Always" or with a mouse connected. That is the user's case.
- `.scrollIndicators(.never)` or `hasVerticalScroller = false`: rejected. They hide the scroll bar even while scrolling. The user wants it to show while they scroll.
- An `NSViewRepresentable` probe view inside `NoteView` that finds the scroll view in `viewDidMoveToWindow`: works, but adds a second reach-in pattern. The `openWindow` path reuses the existing `firstTextView` pattern.
- Replacing `TextEditor` with an `NSTextView` wrapper that owns its scroll view: full control, but it rewrites text binding, undo, and focus handling that work today. That is too much for a visual change.

### Apply again when the system scroller style changes
AppKit posts `NSScroller.preferredScrollerStyleDidChangeNotification` when the user changes "Show scroll bars" or connects or disconnects a mouse. Every `NSScrollView` observes it and resets its own `scrollerStyle` to the system preference. `AppDelegate` observes the same notification and, on the next run loop turn, applies the overlay style again to every window in `windows`.

The async hop matters: observers run in no fixed order, so applying synchronously could run before the scroll view's own reset and be overwritten.

## Risks / Trade-offs

- [SwiftUI resets `scrollerStyle` when it updates the `TextEditor`, for example on every keystroke] → Check by typing in a long note on a Mac set to "Always". If the scroll bar comes back, observe the scroll view's `scrollerStyle` with KVO and set `.overlay` again whenever it changes.
- [On a slow first layout, the text view does not exist yet on the next run loop turn] → Same risk `addNote` already takes. If the helper finds no scroll view, it tries once more on the following turn.
- [The app overrides the user's "Always" scroll bar setting] → Deliberate, see proposal.md. Limited to the note area.
- [American Typewriter is wider than the system font, so fewer words fit on a line, most visibly at the 160-point minimum width] → Accepted. `note-resize` scenario "Controls stay visible at minimum size" still needs one visible line of text; check it at minimum size.
- [The private `firstTextView` search depends on SwiftUI's view hierarchy, which can change between macOS versions] → If the search fails, the note falls back to the system scroller style. Nothing breaks.

## Migration Plan

No data or packaging changes. Saved notes open unchanged in the new font. To roll back, revert the commit.
