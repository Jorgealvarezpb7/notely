# Proposal

## Why

Notes are plain text. Users cannot mark a word as important or set off a heading inside a note. Bold, italic, and underline cover most of what people want from a sticky note, and the bottom bar already has room for formatting controls next to the font and size buttons.

## What Changes

- Note text supports per-range **bold**, *italic*, and underline. The user selects text and toggles a style. With no selection, the toggle sets the style for the next typed text.
- The bottom bar of note windows shows three new icon buttons at its leading edge: Bold, Italic, Underline. The font and text size buttons stay at the trailing edge. A button shows as active when its style applies at the caret or to the whole selection.
- Cmd+B, Cmd+I, and Cmd+U toggle the styles. A new "Format" menu in the menu bar lists them.
- Italic uses the font's real italic face when it has one. American Typewriter has no italic face, so italic text in that font shows with a synthetic slant.
- Styles are kept as traits, not as font names, so changing the global font or size keeps every styled range.
- Pasted rich text keeps only bold, italic, and underline. Other attributes (font, size, color, links) are dropped, and the pasted text uses the note's font and size.
- Styles persist with the note. The note's plain `text` stays saved as before, so builds without this change still open every note and show its text without styles.
- **BREAKING (layout)**: the minimum note window width grows from 110 to 160 points, so five buttons fit in the bottom bar. List windows share this limit. Windows saved narrower open at 160 points.
- List windows do not change: no style buttons, no styled items.

## Capabilities

### New Capabilities
- `text-styles`: per-range bold, italic, and underline in note text: toggling from buttons and shortcuts, button state, italic fallback, paste handling, and persistence of styles.

### Modified Capabilities
- `text-appearance`: the bottom bar requirement adds the style buttons in note windows; the minimum-size requirement includes them; font and size changes keep styles.
- `sticky-note`: the note area is no longer plain text only; the bottom bar of note windows shows the style buttons as well as the font and size buttons.
- `note-resize`: the minimum window width changes from 110 to 160 points.

## Impact

- `Sources/Notely/main.swift`:
  - `NoteView`: SwiftUI `TextEditor` (plain `String`, macOS 13) is replaced by an `NSTextView` in an `NSViewRepresentable`. Esc, end editing from the bars, placeholder, overlay scroller, and focus on new notes must keep working.
  - `Note` / `NoteStore`: new optional field for style runs, plus a setter that saves text and runs together.
  - `BottomBar`: leading B/I/U buttons for note windows only; needs to know the focused text view of its window.
  - `makeMainMenu`: new "Format" menu.
  - `minimumNoteSize`: width 110 to 160.
- Saved data: new optional key inside each note's JSON. Older builds ignore it. No migration.
- No new dependencies.
