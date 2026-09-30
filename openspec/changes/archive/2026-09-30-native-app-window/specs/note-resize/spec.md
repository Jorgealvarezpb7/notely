# Spec Delta

## Purpose

Lets the user change the size of each note window, and keeps each note's size between app launches.

## ADDED Requirements

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
A note window MUST NOT become smaller than 160 points wide or 100 points high. A note window MUST NOT become larger than the visible area of the screen it is on.

#### Scenario: Shrink below minimum
- **WHEN** the user drags a note window's corner inward past 160 by 100 points
- **THEN** the window stops at 160 points wide and 100 points high

#### Scenario: Controls stay visible at minimum size
- **WHEN** a note window is at its minimum size
- **THEN** its drag area shows the "+" and "−" buttons
- **AND** its note area shows at least one line of text

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

### Requirement: New note size
A note created with "+" SHALL open at the same size as the note window whose "+" was clicked. A note created at first launch, or after the last note was removed, MUST open at 220 by 150 points.

#### Scenario: Click "+" on a resized note
- **WHEN** a note window is 300 by 200 points and the user clicks its "+"
- **THEN** the new note window opens at 300 by 200 points
