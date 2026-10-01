# Tasks

The project has no test target. Each task is verified with a command and a manual check on the host Mac. Build and run with `just run` on macOS; the recipes do not run in the dkc Linux container. Scroll bar checks need a note with text longer than its visible area, and need the macOS "Show scroll bars" setting (System Settings > Appearance) set as each task says.

## 1. Note typeface

- [x] 1.1 In `Sources/Notely/main.swift`, add one shared font value, `Font.custom("American Typewriter", size: 15, relativeTo: .body)`, and use it in `NoteView` for the `TextEditor` (in place of `.font(.body)`) and for the placeholder `Text` (design.md "Font through `Font.custom` with a shared constant"); verify `swift build` succeeds and, with `just run`, sticky-note scenarios "Typed text uses American Typewriter", "Placeholder uses American Typewriter", and "Saved text after upgrade" pass
- [x] 1.2 Adjust the placeholder's `.padding(.top, …)` (and `.padding(.leading, …)` only if needed) until the caret in an empty, focused note shows at the start of the placeholder text (design.md "Placeholder padding tuned by eye after the font change"); verify sticky-note scenario "Placeholder lines up with the caret", and that note-resize scenario "Controls stay visible at minimum size" still passes at 160x100 points

## 2. Overlay scroll bar

- [x] 2.1 Add a helper on `AppDelegate`, for example `applyOverlayScroller(to:)`, that finds the window's text view with `firstTextView`, takes its `enclosingScrollView`, and sets `scrollerStyle = .overlay` and `autohidesScrollers = true`. If no text view is found, try once more on the next run loop turn. Call it with `DispatchQueue.main.async` at the end of `openWindow` (design.md "Overlay scroller set on the `NSScrollView` from `AppDelegate.openWindow`"); verify with "Show scroll bars" set to "Always" that sticky-note scenarios "Idle long note", "Scroll a long note", "System setting is 'Always'", and "New note" pass
- [x] 2.2 In `applicationDidFinishLaunching`, observe `NSScroller.preferredScrollerStyleDidChangeNotification` and, on the next run loop turn, call the helper for every window in `windows` (design.md "Apply again when the system scroller style changes"); verify sticky-note scenario "Setting changes while the app runs" by switching "Show scroll bars" between "Always", "When scrolling", and "Automatically" with two notes open, and, if a mouse is available, by connecting and disconnecting it (scenario "Mouse connected")
- [x] 2.3 With "Show scroll bars" set to "Always", type several lines at the end of a long note and scroll it again; verify the scroll bar stays hidden while idle. If it comes back after typing, add the KVO fallback from design.md Risks (observe the scroll view's `scrollerStyle` and set `.overlay` again), then repeat this check. The scroll bar stayed visible on idle notes with the one-time set alone, so the KVO fallback is in place
- [x] 2.4 Verify sticky-note scenarios "Scroll with the caret" and "Long text", and that Esc and Cmd+A, Cmd+C, Cmd+V, Cmd+X, and Cmd+Z still work in a note with the overlay scroller

## 3. Integration

- [x] 3.1 Run `openspec validate typewriter-font-overlay-scroller --strict`, then on the final `just run` build with three notes open (one long, one empty, one created with "+"), walk every scenario in `specs/sticky-note/spec.md` with "Show scroll bars" set to "Always" and again with "When scrolling"; verify all pass
