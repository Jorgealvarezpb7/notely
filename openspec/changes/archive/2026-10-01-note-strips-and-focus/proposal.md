# Proposal

## Why

After typing, the caret stays visible in a note or list. The only way to end editing is Esc, and clicking the drag area does not end it. The drag area is also hard to see: it shows only a small gray grip, so the user cannot tell where the top bar ends. At small window sizes, the "−" and trash buttons can disappear: the 160-point minimum width is not enforced, and windows shrink to about 27 points wide. Future controls, such as font and size, also need a place to go.

## What Changes

- Clicking the top bar or the bottom bar of a note or list window ends editing, as Esc does. The text is kept.
- In a list window, clicking the empty space below the rows ends editing.
- The top bar loses its small gray grip. It gets a shaded fill from edge to edge: darker than the note in light appearance, lighter in dark appearance.
- A new bottom bar, 20% lower than the top bar and with the same shade, shows at the bottom of every note and list window. It moves the window when dragged and is empty for now, so later changes can add controls to it.
- The minimum window size becomes 110 by 120 points: half the width of a new note, and 20 points higher than before. The minimum is enforced during every resize.
- At every allowed size, the "−" and trash buttons stay visible, also when a list item or a note line is long.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `sticky-note`: "End editing" adds a click on either bar. "Panel stays movable" describes the shaded top bar with no grip, and the new bottom bar.
- `checklists`: a new requirement covers ending editing by clicking empty space below the rows.
- `note-resize`: "Size limits" changes the minimum to 110 by 120 points, and requires that the buttons stay visible with long content at the minimum size.

## Impact

- `Sources/Notely/main.swift`:
  - `DragHandle` and `NoteStrip`: the grip is removed, the fill is added, and a click ends editing.
  - New bottom bar view.
  - `NoteView` and `ListView` layout: bars go edge to edge, and only the content keeps its padding.
  - `ListView`: a click on empty space ends editing.
  - `minimumNoteSize` changes.
- Saved notes smaller than 110 by 120 points open at the minimum size. The existing `fit` and `restoredFrame` code handles this through `minimumNoteSize`.
- No new dependencies.
