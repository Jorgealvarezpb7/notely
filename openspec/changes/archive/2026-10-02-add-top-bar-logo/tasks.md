# Tasks

The project has no test target, so each task is verified with a build and a manual check on the host Mac. Build and run with `just run` on macOS; the recipes do not run in the dkc Linux container.

## 1. Logo shape

- [x] 1.1 In `Sources/Notely/main.swift`, add the SVG `d` string as a constant and a `NotelyLogo: Shape` that parses it once into subpaths (absolute `M`, `x,y` point lists, `Z`) and scales them uniformly into the rect (design.md Decision 1), with a comment saying which commands the parser supports; verify `swift build -c release` succeeds
- [x] 1.2 Add `logoFill`, a dynamic `NSColor` with black at 0.25 alpha in light appearance and white at 0.30 alpha in dark appearance, next to `barFill` (design.md Decision 3); verify the build succeeds

## 2. Logo in the drag area

- [x] 2.1 In `NoteStrip`, add the logo as a centered `ZStack` layer between `EndEditingView` and the buttons: 12 pt tall and 12 × 837 / 465 pt wide, filled with `logoFill` using `FillStyle(eoFill: true)`, with `.allowsHitTesting(false)` (design.md Decisions 2 and 4); verify with `just run` that note and list windows show the logo centered, with the same outline as `Packaging/notely-logo.svg` (sticky-note scenarios "Logo in a note window" and "Logo in a list window") and that the menu window shows no logo (scenario "Menu window")
- [x] 2.2 Hide the logo when the bar is narrower than `2 * (12 + 2 * StripButton.referenceSize.width + 16 + 8) + logoWidth` (design.md Decision 5); verify by resizing a note window to its minimum width that the logo hides before it touches "−", and that "−" and trash still work (scenario "Narrow window")
- [x] 2.3 Verify the click-through behavior: drag a note window starting on the logo, and click the logo while typing in a note and in a list title (scenarios "Drag from the logo" and "Click the logo while editing", and checklists scenario "Click the drag area in a list")
- [x] 2.4 Verify the colors: check the logo in light and dark appearance, then switch the appearance in System Settings with a note open (scenarios "Logo in light appearance", "Logo in dark appearance", and "Appearance changes"). If the logo looks too strong or too weak next to the buttons, adjust only the alphas in `logoFill` and record the final values in design.md Decision 3
- [x] 2.5 Verify that the existing sticky-note scenarios "No grip mark", "Drag the drag area", "Bars in light appearance", and "Bars in dark appearance" still pass, and run `openspec validate add-top-bar-logo` with no errors

## 3. Artwork

- [x] 3.1 Commit `Packaging/notely-logo.svg` with the change as the source artwork; verify `git status` shows no untracked files under `Packaging/`
