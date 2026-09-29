# Tasks

The project has no test target and the behavior is UI-level, so each task is verified with `swift build -c release` and a manual check on macOS against the named spec scenario (`just run` to launch). "Another app frontmost" means: click a window of another app (for example Finder), then click the note panel. The defaults domain is `FloatingWidget`.

## 1. Hidden main menu (editing shortcuts and Cmd+Q)

- [x] 1.1 In `Sources/FloatingWidget/main.swift`, set `NSApp.mainMenu` at launch with an app menu ("Quit FloatingWidget", Cmd+Q, `NSApplication.terminate(_:)`) and an Edit menu (Undo, Redo, Cut, Copy, Paste, Select All, target `nil`) per design.md Decision 1; verify `swift build -c release` succeeds and the menu bar still shows the other app's menus while the note is focused
- [x] 1.2 With another app frontmost, click the note and check Cmd+A, Cmd+C, Cmd+V, Cmd+X, Cmd+Z, and Shift+Cmd+Z; verify sticky-note scenario "Standard editing shortcuts". If a shortcut fails, switch all shortcuts to the `performKeyEquivalent(with:)` fallback in design.md Decision 1 and check again
- [x] 1.3 Check Cmd+Q in both directions; verify app-controls scenarios "Cmd+Q while editing" (app quits) and "Cmd+Q in another app" (click a Finder window, press Cmd+Q, note app keeps running)

## 2. Menu bar status item

- [x] 2.1 Add an `NSStatusItem` property on `AppDelegate` with template SF Symbol `note.text` and a menu with one item, "Quit FloatingWidget" (`NSApplication.terminate(_:)`), per design.md Decision 2; verify `swift build -c release` succeeds and scenario "Menu bar item at launch" (icon in menu bar, no Dock icon)
- [x] 2.2 Open the status item menu and choose Quit; verify scenario "Quit from menu bar" (panel and menu bar icon disappear, process exits)

## 3. Native close button

- [x] 3.1 Add a `CloseButton` `NSViewRepresentable` that wraps `NSWindow.standardWindowButton(.closeButton, for: [.titled, .closable])` with target `NSApp` and action `NSApplication.terminate(_:)`, and place it at the leading edge of the drag strip over `DragHandle` with the strip height set per design.md Decision 3; verify `swift build -c release` succeeds and scenario "Only a close button"
- [x] 3.2 Click the close button with the note focused; verify scenario "Click close button"
- [x] 3.3 Click the close button once with another app frontmost (without clicking the panel first); verify scenario "Click close button while another app is frontmost". If the first click only focuses the panel, replace the button with the fallback in design.md Risks (Risk 2) and check again
- [x] 3.4 Drag the strip on both sides of the close button and drag across note text; verify scenario "Drag area outside the close button still moves the panel" and sticky-note scenarios "Drag the drag area" and "Drag inside text"

## 4. Panel position persistence

- [x] 4.1 Add the origin restore function (saved string, panel size, screen visible frames in; origin out) with the three steps in design.md Decision 4, and use it in `applicationDidFinishLaunching` before `orderFrontRegardless()`; verify `swift build -c release` succeeds, then run `defaults delete FloatingWidget panelOrigin` and launch to verify scenario "First launch position"
- [x] 4.2 Make `AppDelegate` the panel's `NSWindowDelegate` after launch positioning and save `NSStringFromPoint(panel.frame.origin)` to `panelOrigin` in `windowDidMove(_:)`; drag the panel, check `defaults read FloatingWidget panelOrigin` shows the new origin, quit, and relaunch to verify scenario "Relaunch keeps position"
- [x] 4.3 Run `defaults write FloatingWidget panelOrigin "{20000, 20000}"` and launch; verify scenario "Saved screen disconnected" (panel at the top-right default)
- [x] 4.4 Write an origin that puts the panel partly past the main screen's left or bottom edge with no screen on that side (for example `"{-100, 200}"` on a single display) and launch; verify scenario "Saved position partly off-screen" (panel fully visible, moved only along the clipped axis)

## 5. Integration

- [x] 5.1 For each quit path (status item menu, close button, Cmd+Q), type text and quit within one second of the last keystroke, then relaunch; verify scenario "Quitting keeps note text" for all three
- [x] 5.2 Run `openspec validate add-app-controls --strict` and walk every scenario in `specs/app-controls/spec.md`, `specs/sticky-note/spec.md`, and the main `openspec/specs/sticky-note/spec.md` once more on the final build; verify all pass, including "Click note while another app is frontmost", "Press Esc while editing", and "Switch Space"
