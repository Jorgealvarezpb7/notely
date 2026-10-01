# Spec Delta

## MODIFIED Requirements

### Requirement: Size limits
A note window MUST NOT become smaller than 160 points wide or 100 points high. A note window MUST NOT become larger than the visible area of the screen it is on.

#### Scenario: Shrink below minimum
- **WHEN** the user drags a note window's corner inward past 160 by 100 points
- **THEN** the window stops at 160 points wide and 100 points high

#### Scenario: Controls stay visible at minimum size
- **WHEN** a note window is at its minimum size
- **THEN** its drag area shows the "−" and trash buttons
- **AND** its note area shows at least one line of text

## ADDED Requirements

### Requirement: Default size for new notes
A note created from the menu or at first launch SHALL open at 220 by 150 points. When 220 by 150 points does not fit inside the visible area of the screen where the window opens, the window MUST shrink to fit that visible area.

#### Scenario: Create a note from the menu
- **WHEN** a note window is 300 by 200 points and the user clicks "+ New Note" in the menu
- **THEN** the new note window opens at 220 by 150 points

## REMOVED Requirements

### Requirement: New note size
**Reason**: Notes are no longer created from another note's "+", so there is no source note whose size to copy.
**Migration**: Notes created from the menu open at 220 by 150 points ("Default size for new notes"). Resize them by dragging an edge or corner.
