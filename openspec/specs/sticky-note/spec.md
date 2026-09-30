# sticky-note Specification

## Purpose

Provides note windows that the user can type into, and that keep their text and position between app launches.

## Requirements

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
- **THEN** the note area scrolls vertically and the note window keeps its current size

#### Scenario: Greeting and clock removed
- **WHEN** the app launches
- **THEN** no panel shows greeting text or a clock

### Requirement: End editing
The user SHALL be able to end editing from the keyboard. Ending editing MUST remove keyboard focus from the note area and MUST keep the note text.

#### Scenario: Press Esc while editing
- **WHEN** the note area has keyboard focus and the user presses Esc
- **THEN** the note area loses keyboard focus and shows no caret
- **AND** the note text is unchanged

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

### Requirement: Panel stays movable
The user SHALL be able to move the panel by dragging a visible drag area that is not the text. Dragging inside the text MUST select text and MUST NOT move the panel.

#### Scenario: Drag the drag area
- **WHEN** the user drags the panel's drag area
- **THEN** the panel moves with the pointer

#### Scenario: Drag inside text
- **WHEN** the user drags across text in the note area
- **THEN** the text is selected and the panel does not move

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

### Requirement: Normal window layering
Every note window SHALL stack with other applications' windows as a normal window: it MUST NOT stay above other applications' windows. A note window MUST show only on the Space where it is open. Clicking a note window MUST bring it to the front and make the app the active application.

#### Scenario: Click another app's window
- **WHEN** a note window overlaps a window of another application and the user clicks that other window
- **THEN** the other window comes in front of the note window

#### Scenario: Click a note window behind another app
- **WHEN** a note window is partly behind a window of another application and the user clicks the visible part of the note window
- **THEN** the note window comes to the front
- **AND** the menu bar shows the app's menus

#### Scenario: Switch Space
- **WHEN** a note window is open on one Space and the user switches to another Space
- **THEN** that note window is not visible on the other Space
