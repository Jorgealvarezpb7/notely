# Proposal

## Why

All note and list text is fixed at American Typewriter, 15 points. Some users find the typewriter face hard to read for long notes, and 15 points is too large for a small sticky or too small on a large display. A font choice and a text size control let each user pick what reads best, without changing the app's character for those who like it as it is.

## What Changes

- The bottom bar of every note window and every list window, empty until now, gets two icon buttons at its trailing edge: a font button and a text size button. They use the same borderless style as the "−" and trash buttons in the top bar.
- The font button opens a menu with two entries, "American Typewriter" and "System", with a check mark on the current one. Choosing an entry changes the font at once.
- The text size button opens a popover with a slider from 10 to 20 points, in steps of 1, and shows the current size. Text changes size while the user drags.
- The setting is global: one font and one size for the whole app. A change in any window applies to every open note and list window at once.
- The setting persists across quit and relaunch. With no saved setting, the app uses American Typewriter at 15 points, as today.
- Note text, the note placeholder, list titles, list items, and the "Untitled list" and "New item" placeholders all follow the setting. List titles stay bold in either font.
- Menu window rows follow the font choice but keep a fixed size of 15 points.

Out of scope: per-note fonts, fonts other than the two named, keyboard shortcuts for text size (Cmd+Plus, Cmd+Minus), bold or italic for note text, line spacing, and changing the size of menu rows.

## Capabilities

### New Capabilities
- `text-appearance`: The font and size buttons in the bottom bar of note and list windows, the font menu, the text size popover, the global setting and its defaults, persistence, live update of all open windows, menu rows following the font, and the bar staying usable at the minimum window size.

### Modified Capabilities
- `sticky-note`: "Note typeface" no longer fixes American Typewriter at 15 points. Note text and its placeholder use the font and size from the text appearance setting. "Panel stays movable" no longer requires an empty bottom bar: the bar shows the font and size buttons, and dragging it outside them still moves the window.
- `checklists`: "List title" and "List items" no longer fix American Typewriter (Bold) at 15 points. They use the font and size from the text appearance setting; the title stays bold.

## Impact

- Code: `Sources/Notely/main.swift` only. A new `ObservableObject` holds the font choice and size and saves them in `UserDefaults`. `noteFont` and `ListField.font(bold:)` become functions of that setting. The existing `BottomBar` gains the two buttons on top of its drag target. `MenuRow` reads the font choice. New AppKit buttons open an `NSMenu` and an `NSPopover`.
- Storage: two new `UserDefaults` keys, separate from `notes`. Notes data is unchanged, so older builds still read it and ignore the new keys.
- Rollback: an older build ignores the new keys and shows American Typewriter at 15 points.
- Dependencies: none added. AppKit and SwiftUI only. Target stays macOS 13.
