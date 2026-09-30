# Proposal

## Why

The note area uses the system font, which makes notes look like any other text field. On the user's Mac, the note area's vertical scroll bar also stays visible all the time, which takes width from a small window and adds clutter. The user wants notes in the American Typewriter typeface, and a scroll bar that shows only while they scroll.

## What Changes

- Note text and the "Type a note…" placeholder use American Typewriter, a font that ships with macOS, at 15 points, two points larger than the system body text.
- The note area's scroll bar uses the overlay style whatever the macOS "Show scroll bars" setting is. It is hidden while the note is idle, appears while the user scrolls, and fades out after scrolling stops.
- The app keeps the overlay style when the user changes the "Show scroll bars" setting, or connects or disconnects a mouse, while the app runs.
- Long text still scrolls with the trackpad, the mouse wheel, and caret movement.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `sticky-note`: add a requirement for the note typeface (note text and placeholder), and a requirement that the note area's scroll bar shows only while the user scrolls, independent of the system scroll bar setting.

## Impact

- `Sources/Notely/main.swift`: `NoteView` sets the American Typewriter font on the `TextEditor` and the placeholder `Text`, and may adjust the placeholder padding so it lines up with the caret. New AppKit code finds the `NSScrollView` behind each note's `TextEditor`, sets overlay scroller style, and sets it again when the system posts `NSScroller.preferredScrollerStyleDidChangeNotification`.
- No change to saved data, packaging, or the `justfile`. No new dependencies or bundled fonts.
- The app overrides the user's "Always" scroll bar setting in the note area only. This goes against the macOS default and is a deliberate choice.
