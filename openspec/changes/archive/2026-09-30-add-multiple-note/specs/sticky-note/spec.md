# Spec Delta

## MODIFIED Requirements

### Requirement: Editable note text
Every note panel SHALL show one plain-text note area in place of the previous greeting and clock. The user MUST be able to type, delete, select, copy, and paste text in each note area.

#### Scenario: Type into the note
- **WHEN** the user clicks inside a note area and types characters
- **THEN** the typed characters appear in that note area at the caret position

#### Scenario: Standard editing shortcuts
- **WHEN** a note area has keyboard focus and the user presses Cmd+A, Cmd+C, Cmd+V, Cmd+X, or Cmd+Z
- **THEN** that note area performs select all, copy, paste, cut, or undo on its note text

#### Scenario: Long text
- **WHEN** a note's text is longer than the visible note area
- **THEN** the note area scrolls vertically and the panel size does not change

#### Scenario: Greeting and clock removed
- **WHEN** the app launches
- **THEN** no panel shows greeting text or a clock

### Requirement: Note persistence
The text of every note SHALL persist across app quit and relaunch. Changes MUST be saved without an explicit save action.

#### Scenario: Relaunch keeps text
- **WHEN** the user types text in a note, quits the app, and launches it again
- **THEN** that note shows the same text

#### Scenario: First launch
- **WHEN** the app launches with no saved note
- **THEN** one note opens, and its note area is empty and shows placeholder text that invites the user to type

#### Scenario: Save without explicit action
- **WHEN** the user types text in any note and the app is quit normally within one second of the last keystroke
- **THEN** the next launch shows that note's full text including the last keystroke

### Requirement: Floating panel behavior preserved
Every note panel SHALL keep the existing floating behavior: it stays above normal windows, shows on all Spaces, and the app shows no Dock icon.

#### Scenario: Switch Space
- **WHEN** the user switches to another Space
- **THEN** every note panel is visible on that Space with the same text

### Requirement: Panel position persists
Every panel SHALL open at the position where the user last left it. When a note has no saved position, or its saved position is not on any connected screen, its panel MUST open 20 points from the top and right edges of the main screen's visible area. Every panel MUST always open fully inside one screen's visible area.

#### Scenario: Relaunch keeps position
- **WHEN** the user drags a panel to a new position, quits the app, and launches it again
- **THEN** that panel opens at the same position

#### Scenario: First launch position
- **WHEN** the app launches with no saved note
- **THEN** the one panel opens 20 points from the top and right edges of the main screen's visible area

#### Scenario: Saved screen disconnected
- **WHEN** a note's saved position is on a screen that is no longer connected, and the app launches
- **THEN** that panel opens 20 points from the top and right edges of the main screen's visible area

#### Scenario: Saved position partly off-screen
- **WHEN** a note's saved position puts part of its panel outside the visible area of the screen it overlaps, and the app launches
- **THEN** that panel opens fully inside that screen's visible area, moved the shortest distance from the saved position
