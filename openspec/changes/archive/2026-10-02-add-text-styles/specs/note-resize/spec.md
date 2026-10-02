# Spec Delta

## MODIFIED Requirements

### Requirement: Size limits
A note window MUST NOT become smaller than 160 points wide or 120 points high, so that every bottom bar button fits. This limit MUST hold during every resize, from every edge and corner, and MUST apply to list windows too. A note window MUST NOT become larger than the visible area of the screen it is on. At every allowed size, the "−" and trash buttons MUST show fully inside the window, whatever the length of the note text, list title, or list items. A note saved smaller than the minimum size MUST open at the minimum size.

#### Scenario: Shrink below minimum
- **WHEN** the user drags a note window's corner inward past 160 by 120 points
- **THEN** the window stops at 160 points wide and 120 points high

#### Scenario: Drag an edge past the minimum width
- **WHEN** the user drags the left or right edge of a note window inward past 160 points wide
- **THEN** the window stops at 160 points wide
- **AND** the "−" and trash buttons show fully inside the window

#### Scenario: Controls stay visible at minimum size
- **WHEN** a note window is at its minimum size
- **THEN** its drag area shows the "−" and trash buttons
- **AND** its bottom bar shows all its buttons
- **AND** its note area shows at least one line of text

#### Scenario: Long list item at minimum width
- **WHEN** a list window has an item whose text is wider than the window and the user shrinks the window to 160 points wide
- **THEN** the "−" and trash buttons show fully inside the window
- **AND** the item's text wraps within the window's width

#### Scenario: Saved size below new minimum
- **WHEN** the app launches with a note saved at 60 by 100 points
- **THEN** that note's window opens at 160 by 120 points

#### Scenario: Note saved at the old minimum
- **WHEN** the app launches with a note saved at 110 by 150 points by an earlier version
- **THEN** that note's window opens at 160 by 150 points
