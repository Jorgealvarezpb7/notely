# Tasks

The project has no test target, so each task is verified with a build and a manual check on the host Mac. Build and run with `just run` on macOS; the recipes do not run in the dkc Linux container. For the checks, use a list with about 30 items in a window of the default size.

## 1. Clip list content

- [x] 1.1 In `AppDelegate.applyOverlayScroller(to:)` in `Sources/Notely/main.swift`, set `clipsToBounds = true` on the found `NSScrollView` and its `contentView`, inside `if #available(macOS 14, *)`, with a comment explaining why (design.md Decision 1); verify `swift build -c release` succeeds
- [x] 1.2 In `AppDelegate.openWindow`, set `hostingView.safeAreaRegions = []` inside `if #available(macOS 13.3, *)` (design.md Decision 2); with `just run`, scroll a long list down to the end and back to the top and verify checklists scenarios "Scroll a long list down" and "Scroll a long list back up": no row, circle, or placeholder shows over the drag area or the bottom bar
- [x] 1.2a Remove the temporary `NotelyScroll` diagnostic logs from `applyOverlayScroller`; verify `grep -n NotelyScroll Sources/Notely/main.swift` finds nothing
- [x] 1.3 In a scrolled long list, click "−", then reopen the list and click trash and "Cancel"; verify checklists scenario "Buttons over a scrolled list" and that the font and text size buttons in the bottom bar also work
- [x] 1.4 In a scrolled long list, type in an item, check and uncheck an item, and drag the text size slider from 10 to 20; verify the content stays clipped throughout (design.md Risks). If clipping is lost, re-apply it with a KVO observation like the one for `scrollerStyle`
- [x] 1.5 Verify the existing checklists scenario "Long list" and sticky-note scenarios "Long note above the bottom bar" and "Scroll a long note" still pass, and run `openspec validate fix-list-scroll-clipping` with no errors
