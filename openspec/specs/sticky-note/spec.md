# sticky-note Specification

## Purpose

Provides a single always-on-top floating note that the user can type into, and that keeps its text between app launches.

## Requirements

### Requirement: Editable note text
The floating widget SHALL show one plain-text note area in place of the previous greeting and clock. The user MUST be able to type, delete, select, copy, and paste text in the note area.

#### Scenario: Type into the note
- **WHEN** the user clicks inside the note area and types characters
- **THEN** the typed characters appear in the note area at the caret position

#### Scenario: Standard editing shortcuts
- **WHEN** the note area has keyboard focus and the user presses Cmd+A, Cmd+C, Cmd+V, Cmd+X, or Cmd+Z
- **THEN** the note area performs select all, copy, paste, cut, or undo on the note text

#### Scenario: Long text
- **WHEN** the note text is longer than the visible note area
- **THEN** the note area scrolls vertically and the panel size does not change

#### Scenario: Greeting and clock removed
- **WHEN** the app launches
- **THEN** the widget shows no greeting text and no clock

### Requirement: Editing does not steal app focus
Clicking the note area SHALL give it keyboard focus without making the app the active application. The previously frontmost application MUST stay frontmost.

#### Scenario: Click note while another app is frontmost
- **WHEN** another application is frontmost and the user clicks inside the note area
- **THEN** the note area receives keystrokes
- **AND** the other application stays the active application in the menu bar

### Requirement: End editing
The user SHALL be able to end editing from the keyboard. Ending editing MUST remove keyboard focus from the note area and MUST keep the note text.

#### Scenario: Press Esc while editing
- **WHEN** the note area has keyboard focus and the user presses Esc
- **THEN** the note area loses keyboard focus and shows no caret
- **AND** the note text is unchanged

### Requirement: Note persistence
The note text SHALL persist across app quit and relaunch. Changes MUST be saved without an explicit save action.

#### Scenario: Relaunch keeps text
- **WHEN** the user types text, quits the app, and launches it again
- **THEN** the note area shows the same text

#### Scenario: First launch
- **WHEN** the app launches with no saved note
- **THEN** the note area is empty and shows placeholder text that invites the user to type

#### Scenario: Save without explicit action
- **WHEN** the user types text and the app is quit normally within one second of the last keystroke
- **THEN** the next launch shows the full text including the last keystroke

### Requirement: Panel stays movable
The user SHALL be able to move the panel by dragging a visible drag area that is not the text. Dragging inside the text MUST select text and MUST NOT move the panel.

#### Scenario: Drag the drag area
- **WHEN** the user drags the panel's drag area
- **THEN** the panel moves with the pointer

#### Scenario: Drag inside text
- **WHEN** the user drags across text in the note area
- **THEN** the text is selected and the panel does not move

### Requirement: Floating panel behavior preserved
The note panel SHALL keep the existing floating behavior: it stays above normal windows, shows on all Spaces, and the app shows no Dock icon.

#### Scenario: Switch Space
- **WHEN** the user switches to another Space
- **THEN** the note panel is visible on that Space with the same text

### Requirement: Panel position persists
The panel SHALL open at the position where the user last left it. When there is no saved position, or the saved position is not on any connected screen, the panel MUST open 20 points from the top and right edges of the main screen's visible area. The panel MUST always open fully inside one screen's visible area.

#### Scenario: Relaunch keeps position
- **WHEN** the user drags the panel to a new position, quits the app, and launches it again
- **THEN** the panel opens at the same position

#### Scenario: First launch position
- **WHEN** the app launches with no saved position
- **THEN** the panel opens 20 points from the top and right edges of the main screen's visible area

#### Scenario: Saved screen disconnected
- **WHEN** the saved position is on a screen that is no longer connected, and the app launches
- **THEN** the panel opens 20 points from the top and right edges of the main screen's visible area

#### Scenario: Saved position partly off-screen
- **WHEN** the saved position puts part of the panel outside the visible area of the screen it overlaps, and the app launches
- **THEN** the panel opens fully inside that screen's visible area, moved the shortest distance from the saved position
