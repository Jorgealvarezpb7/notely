# Spec Delta

## MODIFIED Requirements

### Requirement: Editable note text
Every note panel SHALL show one note area in place of the previous greeting and clock. The user MUST be able to type, delete, select, copy, and paste text in each note area. Note text MAY carry bold, italic, and underline styles as defined by the text-styles capability; it MUST NOT carry any other formatting. Web addresses in note text show as links as defined by the links capability; that display is not formatting the note carries.

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

#### Scenario: No other formatting
- **WHEN** the user pastes text with colors and links whose visible text is not a web address into a note area
- **THEN** the note shows the text with no colors and no links
