# note-resize Specification

## Purpose

Lets the user change the size of each note window, and keeps each note's size between app launches.

## Requirements

### Requirement: Resize a note window
The user SHALL be able to resize every note window by dragging any of its edges or corners. While the user resizes a window, the pointer MUST show the standard resize cursor, and the note area MUST fill the new size. Resizing one note window MUST NOT change the size, position, or text of another note.

#### Scenario: Drag the bottom-right corner
- **WHEN** the user drags the bottom-right corner of a note window outward
- **THEN** the window grows with the pointer
- **AND** the note area fills the larger window

#### Scenario: Drag an edge
- **WHEN** the user drags the left edge of a note window
- **THEN** only the window's width changes

#### Scenario: Resize one of two notes
- **WHEN** two notes are open and the user resizes the first window
- **THEN** the second window keeps its size, position, and text

### Requirement: Size limits
A note window MUST NOT become smaller than 110 points wide or 120 points high, which is half the width of a new note. This limit MUST hold during every resize, from every edge and corner. A note window MUST NOT become larger than the visible area of the screen it is on. At every allowed size, the "−" and trash buttons MUST show fully inside the window, whatever the length of the note text, list title, or list items. A note saved smaller than the minimum size MUST open at the minimum size.

#### Scenario: Shrink below minimum
- **WHEN** the user drags a note window's corner inward past 110 by 120 points
- **THEN** the window stops at 110 points wide and 120 points high

#### Scenario: Drag an edge past the minimum width
- **WHEN** the user drags the left or right edge of a note window inward past 110 points wide
- **THEN** the window stops at 110 points wide
- **AND** the "−" and trash buttons show fully inside the window

#### Scenario: Controls stay visible at minimum size
- **WHEN** a note window is at its minimum size
- **THEN** its drag area shows the "−" and trash buttons
- **AND** its bottom bar shows
- **AND** its note area shows at least one line of text

#### Scenario: Long list item at minimum width
- **WHEN** a list window has an item whose text is wider than the window and the user shrinks the window to 110 points wide
- **THEN** the "−" and trash buttons show fully inside the window
- **AND** the item's text wraps within the window's width

#### Scenario: Saved size below new minimum
- **WHEN** the app launches with a note saved at 60 by 100 points
- **THEN** that note's window opens at 110 by 120 points

### Requirement: Note size persists
Every note window SHALL open at the size it had when the app last quit. A note with no saved size MUST open at 220 by 150 points. When a note's saved size does not fit inside the visible area of the screen where the window opens, the window MUST shrink to fit that visible area.

#### Scenario: Relaunch keeps size
- **WHEN** the user resizes a note window, quits the app, and launches it again
- **THEN** that window opens at the same size and position as before

#### Scenario: Note saved by an earlier version
- **WHEN** the app launches with a note saved by a version without resizing
- **THEN** that note's window opens at 220 by 150 points at its saved position

#### Scenario: Saved size larger than screen
- **WHEN** a note's saved size is larger than the visible area of the screen where its window opens
- **THEN** the window opens fully inside that visible area, no larger than it

### Requirement: Default size for new notes
A note created from the menu or at first launch SHALL open at 220 by 150 points. When 220 by 150 points does not fit inside the visible area of the screen where the window opens, the window MUST shrink to fit that visible area.

#### Scenario: Create a note from the menu
- **WHEN** a note window is 300 by 200 points and the user clicks "+ New Note" in the menu
- **THEN** the new note window opens at 220 by 150 points
