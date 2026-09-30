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
- **THEN** the note area scrolls vertically and the note window keeps its current size

#### Scenario: Greeting and clock removed
- **WHEN** the app launches
- **THEN** no panel shows greeting text or a clock

## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Editing does not steal app focus
**Reason**: The app is now a regular app. Clicking a note makes the app active, like any native Mac app.
**Migration**: None. Clicking a note still gives its note area keyboard focus; the menu bar now shows the app's menus while the user types.

### Requirement: Floating panel behavior preserved
**Reason**: Note windows now stack normally with other windows and belong to one Space, and the app shows a Dock icon.
**Migration**: Replaced by "Normal window layering" in this capability and "Dock icon" in `app-controls`. Use the Dock icon to bring notes to the front.
