# Design

## Context

`ListView` puts a SwiftUI `ScrollView` inside padding of `barHeight + barGap` at the top and `bottomBarHeight + barGap` at the bottom. The drag area (`NoteStrip`) and the bottom bar are overlays on top of that padded view. So by layout the scroll view's frame already ends below the drag area. The rows draw over the bar only if the scroll view does not clip what it shows.

On macOS, the `ScrollView` is an `NSScrollView` whose document view is a SwiftUI hosting view. The title and every row are `ListTextField`s, which are real `NSView`s inside that document view. `NoteView`'s `TextEditor` is one `NSTextView` that draws only inside its own clip view, which is why note windows do not show the bug.

Two causes fit what the user sees:

- **H1: no clipping.** Apps built with the macOS 14 SDK and running on macOS 14 or later get `NSView.clipsToBounds == false` by default. AppKit then lets subviews of the scroll view, the `ListTextField`s, draw outside the scroll view's frame, over the bar.
- **H2: title bar insets.** The windows use `.fullSizeContentView` with a transparent title bar. An `NSScrollView` with `automaticallyAdjustsContentInsets == true` can add a top inset for the title bar and let content scroll under it.

The build in this repo uses the current SDK, and the bug shows only with real `NSView` rows, so H1 is the most likely cause. H2 is the fallback.

`AppDelegate.applyOverlayScroller(to:)` already finds each note and list window's `NSScrollView` (with a retry on the next run loop turn) and keeps its scroller style. It is the one place where the app changes the scroll view in AppKit.

## Goals / Non-Goals

**Goals:**
- List content never draws over or under the drag area or the bottom bar (see specs/checklists/spec.md).
- One small change, in the place that already changes the scroll view.

**Non-Goals:**
- Replacing the SwiftUI `ScrollView` or the `ListTextField` rows.
- Changing the bars' translucent fill. With clipping, nothing scrolls under the bars, so they can stay translucent.
- A fade or shadow at the clipped edges.

## Decisions

### 1. Turn clipping on for the scroll view and its clip view

In `applyOverlayScroller(to:)`, after finding the scroll view, set `clipsToBounds = true` on `scrollView` and on `scrollView.contentView` (the `NSClipView`). Guard it with `if #available(macOS 14, *)`. Before macOS 14, views clip by default, so there is nothing to change there.

This also runs for note windows. Their scroll view already clips, so the change has no visible effect there, and one code path stays simpler than a list-only branch.

Alternatives considered:
- SwiftUI `.clipped()` on the `ScrollView`. It clips SwiftUI drawing but does not reliably clip the `NSView`s of `NSViewRepresentable` rows, which is the content that leaks.
- Making the bars opaque. The text would draw behind an opaque bar instead of over it only if the bar is ordered above the scroll view in AppKit, which the existing comment in `ListView` says is not guaranteed. It also changes the bars' look in every window.
- Moving the bars out of the overlay and into a `VStack` with the scroll view. `ListView`'s comment explains this was tried and the `NSScrollView` took clicks meant for "−" and trash.

### 2. Give note and list windows no title bar safe area (H2, confirmed)

Decision 1 alone did not fix the bug. A diagnostic log on the Mac showed the list's `HostingScrollView` frame ending 32 pt below the window top (below the drag area), clipping on, but a top content inset of 32 pt, equal to the hosting view's `safeAreaInsets.top` and the title bar height. Setting `contentInsets` to zero in `applyOverlayScroller` did not hold: SwiftUI set it back to 32. The note's own `NoteScrollView` had insets of 0 and no bug.

So SwiftUI treats the list's `ScrollView` as reaching under the transparent title bar and lets its rows draw into that region, above the scroll view's own frame, where clipping to the frame cannot stop them.

Set `hostingView.safeAreaRegions = []` (macOS 13.3+) on the hosting view of every note and list window in `openWindow`. These windows draw their own bars and already lay out with `.ignoresSafeArea()`, so the safe area has no use there. The menu window keeps its safe area for its standard window buttons.

Alternative considered: zeroing `automaticallyAdjustsContentInsets` and `contentInsets` on the scroll view. Tried; SwiftUI overwrote the inset.

## Risks / Trade-offs

- [SwiftUI or AppKit sets `clipsToBounds` back to `false` on a later update] → The existing KVO pattern for `scrollerStyle` shows how to re-apply it. Check by typing, checking items, and changing the text size in a scrolled long list; add an observation only if clipping is lost.
- [The `firstDescendant(NSScrollView.self)` search finds a different scroll view if the list's hierarchy changes] → Same risk the overlay scroller already takes; the field editor of a `ListTextField` is not an `NSScrollView`, so today the search finds the list's scroll view.
- [Spec scenario "Scroll a long list down" mentions the logo from `add-top-bar-logo`] → Archive `add-top-bar-logo` first.
- [No automated tests] → Verify on the Mac with `just run`.
