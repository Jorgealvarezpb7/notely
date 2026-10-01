# Design

## Context

All code is in `Sources/Notely/main.swift` and targets macOS 13.

- `NoteStrip` (a `DragHandle` with a grip overlay, plus the "−" and trash `StripButton`s) sits inside each view's `.padding(12)`. A fill on it would show as an inset box, not as a bar along the window edge.
- `NoteView` puts the strip in a `VStack` above the `TextEditor`.
- `ListView` puts the strip in an `.overlay(alignment: .top)` and pads its `ScrollView` down by the strip height. The reason: AppKit stacks the `NSScrollView` above the views declared before it, and the scroll view reaches up under the transparent title bar, where it took the clicks meant for "−" and trash.
- `DragHandle.DragView.mouseDown` only calls `window?.performDrag(with:)`. Focus stays in the text, so the caret stays visible.
- Esc already ends editing: `NoteWindow.cancelOperation` and `ListField`'s `cancelOperation` both call `makeFirstResponder(nil)`. List fields remove an empty item through their end-editing callback, so any `makeFirstResponder(nil)` already does that.
- `minimumNoteSize` (160x100) feeds `window.minSize`, `fit`, and `restoredFrame`. A screenshot on the user's Mac shows a note window about 27pt wide, so `minSize` is not enforced during a live resize. The delegate's `windowWillResize` returns a size capped only at the screen, and AppKit uses that return value as final (see Decision 6).

## Goals / Non-Goals

**Goals:**
- Use one view for both bars, so later controls in the bottom bar can reuse the same shape and behavior.
- Use the same focus-ending path as Esc, so empty-item removal and text saving work as they already do.

**Non-Goals:**
- No controls in the bottom bar yet. Font and size controls are a later change.
- The menu window does not change.
- Text notes have no "click empty space" behavior: their editor fills the area between the bars.

## Decisions

1. **One `EndEditingView` NSView, with a `drags` flag.** `mouseDown` first calls `window?.makeFirstResponder(nil)`. Then, when `drags` is true, it calls `performDrag(with:)`. The bars use `drags: true`. The empty list space uses `drags: false`, so a click there does not move the window and it behaves like the background of a text area. `DragHandle` is replaced by this view.
   - Alternative: SwiftUI `.onTapGesture` with `NSApp.keyWindow`. Rejected: it fights `performDrag` for the same mouseDown, and the key window can be a different window on the first click.

2. **Bars are overlays at the window edges in both `NoteView` and `ListView`.** The content (editor or scroll view) gets `.padding(.horizontal, 12)` and vertical padding equal to the bar height plus a small gap. The top bar and bottom bar are `.overlay(alignment: .top)` and `.overlay(alignment: .bottom)` outside that padding, so their fill runs edge to edge. Using overlays in both views keeps one layout and avoids the `NSScrollView` click problem described above. `TextEditor` is also backed by an `NSScrollView`.
   - Alternative: an outer `VStack` of bar, content, and bar. Rejected: in `ListView` this brings back the click-stealing problem.

3. **Bar look.**
   - Height: the top bar is about 28pt, the current strip height plus its old top padding, so "−" and trash stay where they were. The bottom bar is 80% of that, because it holds no buttons and the user found it too tall at full height.
   - Fill: `Color.primary.opacity(0.08)` on top of the existing `.ultraThinMaterial`. `primary` is black in light appearance and white in dark appearance, which gives darker and lighter bars with no appearance check.
   - The grip `RoundedRectangle` is removed.
   - The window has a titled style, so AppKit rounds its corners and clips the content. The bottom bar fill follows the corner radius with no extra clip shape.
   - Exact opacity and height can be tuned on a real Mac.

4. **Empty list space.** In `ListView`, a `GeometryReader` reads the scroll view's visible height. The rows' `VStack` gets `.frame(minHeight: visibleHeight, alignment: .top)` and an `EndEditingView(drags: false)` background. The background fills the space below the last row. Clicks on rows still reach the fields and circles above it. `containerRelativeFrame` would be simpler but needs macOS 14.

5. **Buttons stay visible at minimum width.** `hostingView.sizingOptions = []` lets SwiftUI content grow wider than the window. When that happens, the content is centered and clipped, which pushes the trailing "−" and trash out of view. Likely causes, to check in this order:
   - A `ListField` NSTextField reports its one-line natural width as its ideal width, so a long item or title is wider than the window.
   - The `HStack` in the bar has no limit on its width.

   Fix: give the bar and the content `.frame(maxWidth: .infinity)` inside the window width. Make sure each `ListField` wraps: low horizontal compression resistance and a `preferredMaxLayoutWidth` that follows its width. Check at 110pt wide with a long title and a long item.

6. **Minimum 110x120, enforced in the delegate.** `minimumNoteSize` becomes 110x120. 110 is half the width of a new note (220), and the user marked it as the smallest width wanted. `windowWillResize` now also floors the size at the `minimumNoteSize` constant, so live resizing respects it. It does not read `sender.minSize`: AppKit ties that value to `contentMinSize`, which the SwiftUI hosting view can lower to its fitting size. A first attempt that used `sender.minSize` still let windows shrink below the minimum on the user's Mac. `fit` and `restoredFrame` already use `minimumNoteSize`, so saved notes below the minimum open at the minimum size with no migration code.
   - Alternative: rely on `window.minSize` alone. Rejected: the screenshot shows that it does not hold while the delegate returns a smaller size.

## Risks / Trade-offs

- [The title bar area handles double-click (zoom) before the SwiftUI view] → The current strip sits in the same place and already gets clicks. Check that double-clicking the top bar does nothing unwanted.
- [A `makeFirstResponder(nil)` on every bar click also happens when the user only wants to drag] → This is intended by the spec ("ends editing also when the user then drags").
- [A `GeometryReader` around the `ScrollView` changes the view hierarchy that `applyOverlayScroller` searches] → It finds the first `NSScrollView`, and no new scroll view is added. Check that the scroll bar still shows only while scrolling.
- [The 0.08 opacity may be too faint on some wallpapers behind `.ultraThinMaterial`] → Tune it on a real Mac. Only the visual tone changes, not the spec.
- [This machine cannot build or run the macOS app] → All visual checks happen on the user's Mac.

## Migration Plan

No data changes. Saved sizes below 120pt high grow when the window opens. Rollback: revert the commit.
