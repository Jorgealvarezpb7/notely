# Tasks

The project has no test target, so each task is verified with a command and a manual check on the host Mac. Build and run with `just run` on macOS; the recipes do not run in the dkc Linux container. Before starting, back up the current notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. Setting object

- [x] 1.1 In `Sources/Notely/main.swift`, add `FontFamily` and `TextAppearance` (published `family` and `size`, `UserDefaults` keys `textFontFamily` and `textFontSize`, clamp to 10...20, fallbacks, `swiftUIFont(size:)`, `nsFont(bold:)`) (design.md Decision 1); verify `swift build -c release` succeeds
- [x] 1.2 Create one `TextAppearance` in `AppDelegate` and pass it to `MenuView` and `WindowContent` (then on to `NoteView` and `ListView`); verify the build succeeds and the app launches with notes unchanged
- [x] 1.3 Verify the persistence fallbacks: run `defaults write com.alvarezjorge.Notely textFontSize -int 42` and `defaults write com.alvarezjorge.Notely textFontFamily bogus`, launch, and check that text shows in American Typewriter at 20 points; then `defaults delete` both keys and check American Typewriter at 15 (text-appearance scenario "First launch of this version")

## 2. Fonts follow the setting

- [x] 2.1 Replace the global `noteFont` with `appearance.swiftUIFont(size: appearance.size)` in `NoteView` for the text and its placeholder (design.md Decision 4); verify, by temporarily changing the defaults with `defaults write`, that sticky-note scenarios "Typed text uses the chosen font", "Typed text uses American Typewriter", "Placeholder uses American Typewriter", and "Placeholder uses the note font" pass
- [x] 2.2 Make `MenuRow` use `appearance.swiftUIFont(size: 15)` passed from `MenuView`; verify with `defaults write ... textFontFamily system` and `textFontSize 20` that the menu rows use the system font at 15 points (text-appearance scenarios "Menu font follows the choice" and "Menu size stays fixed")
- [x] 2.3 Replace static `ListField.font(bold:)` with a `font: NSFont` property, pass the font into `styled(...)`, and compute bold and regular fonts in `ListView` from `appearance.nsFont(bold:)`; verify with the defaults set to the system font at 18 points that checklists scenarios "Name a list" (default) and "Title with the system font" pass, and that placeholders use the same font

## 3. Bottom bar

- [x] 3.1 Let `StripButton` pass its `NSButton` to the action, and put the `textformat` and `textformat.size` buttons, labeled "Font" and "Text Size" for accessibility, into the existing `BottomBar` on top of its `EndEditingView` (design.md Decisions 2 and 3); verify text-appearance scenarios "Buttons in a note window", "Buttons in a list window" (with a list taller than its window), and "No buttons in the menu", sticky-note scenarios "Drag the bottom bar" and "Bottom bar controls", and that "−" and trash still work
- [x] 3.2 Add the font `NSMenu` with a check mark on the current family (design.md Decision 3); verify text-appearance scenarios "Switch to the system font", "Dismiss the font menu", and "Click while another app is active"
- [x] 3.3 Add the size `NSPopover` with `SizePopover` (slider 10...20, step 1, "N pt" label), closing it on a second click of its button (design.md Decision 3); verify text-appearance scenarios "Make text smaller", "Limits", and "Close the popover", and sticky-note scenario "Placeholder lines up with the caret" at 10 and 20 points in both fonts (design.md Decision 5)
- [x] 3.4 Resize a note window and a list window to the minimum size with text size 20 in American Typewriter; verify text-appearance scenario "Smallest window, largest text". If it fails, ask the user before changing `minimumNoteSize` (design.md Risks)

## 4. Live update

- [x] 4.1 Verify that the note text in `NoteView` redraws while the slider is dragged and when the font changes, with two note windows and one list window open (text-appearance scenarios "Change applies to every window" and "Content unchanged")
- [x] 4.2 In `ListField.updateNSView`, reapply the font to the field, the placeholder, and the attributed value when it differs, and invalidate the intrinsic size (design.md Decision 4); verify checklists scenario "Items follow the size" by dragging the slider from 10 to 20 with long wrapped items, checked items included
- [x] 4.3 While editing a list item, change the font and the size; verify that the caret stays in place, typing continues in the new font, and Cmd+Z still undoes the last typing
- [x] 4.4 Verify text-appearance scenario "Closed note opens with the setting" by closing a note, changing the size, and reopening the note from the menu

## 5. Integration checks

- [x] 5.1 Choose "System" and size 12, quit with Cmd+Q, and relaunch; verify text-appearance scenario "Relaunch keeps the setting" and sticky-note scenario "Saved text after upgrade" on the backed-up notes
- [x] 5.2 Run `openspec validate add-text-appearance-controls --strict` and verify it passes
