# Spec Delta

## MODIFIED Requirements

### Requirement: Editable note text
Every note panel SHALL show one note area in place of the previous greeting and clock. The user MUST be able to type, delete, select, copy, and paste text in each note area. Note text MAY carry bold, italic, and underline styles as defined by the text-styles capability; it MUST NOT carry any other formatting.

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
- **WHEN** the user pastes text with colors and links into a note area
- **THEN** the note shows the text with no colors and no links

### Requirement: Panel stays movable
The user SHALL be able to move the panel by dragging a visible area that is not the text. Every note window MUST show a drag area across its top edge and a bottom bar across its bottom edge. Both MUST span the full width of the window. The bottom bar MUST be 20% lower than the drag area. Both MUST show a shaded fill that sets them apart from the note area: darker than the note area in light appearance and lighter in dark appearance. The drag area MUST NOT show a grip mark. The bottom bar of a note window MUST show only the Bold, Italic, and Underline buttons at its leading edge, and the font button and the text size button at its trailing edge. Dragging the drag area, or the bottom bar outside its buttons, MUST move the panel. The note area MUST end above the bottom bar, so no note text shows under it. Dragging inside the text MUST select text and MUST NOT move the panel.

#### Scenario: Drag the drag area
- **WHEN** the user drags the panel's drag area
- **THEN** the panel moves with the pointer

#### Scenario: Drag the bottom bar
- **WHEN** the user drags the panel's bottom bar outside its buttons
- **THEN** the panel moves with the pointer

#### Scenario: Bottom bar controls
- **WHEN** a note window is open
- **THEN** its bottom bar shows the Bold, Italic, and Underline buttons at the leading edge, the font button and the text size button at the trailing edge, and no other controls

#### Scenario: Drag inside text
- **WHEN** the user drags across text in the note area
- **THEN** the text is selected and the panel does not move

#### Scenario: Bars in light appearance
- **WHEN** the system appearance is light
- **THEN** the drag area and the bottom bar show darker than the note area, from the left edge to the right edge of the window

#### Scenario: Bars in dark appearance
- **WHEN** the system appearance is dark
- **THEN** the drag area and the bottom bar show lighter than the note area, from the left edge to the right edge of the window

#### Scenario: No grip mark
- **WHEN** a note window is open
- **THEN** its drag area shows only the "−" and trash buttons and its shaded fill

#### Scenario: Long note above the bottom bar
- **WHEN** a note's text is longer than its visible note area
- **THEN** the last visible line of text ends above the bottom bar
