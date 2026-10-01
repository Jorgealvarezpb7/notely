# Spec Delta

## MODIFIED Requirements

### Requirement: End editing
The user SHALL be able to end editing from the keyboard and with the pointer. Pressing Esc, or clicking the window's drag area or bottom bar, MUST end editing. Ending editing MUST remove keyboard focus from the note area and MUST keep the note text. A click on the drag area or bottom bar MUST end editing also when the user then drags the window.

#### Scenario: Press Esc while editing
- **WHEN** the note area has keyboard focus and the user presses Esc
- **THEN** the note area loses keyboard focus and shows no caret
- **AND** the note text is unchanged

#### Scenario: Click the drag area while editing
- **WHEN** the note area has keyboard focus and the user clicks the drag area, outside the "−" and trash buttons
- **THEN** the note area loses keyboard focus and shows no caret
- **AND** the note text is unchanged

#### Scenario: Click the bottom bar while editing
- **WHEN** the note area has keyboard focus and the user clicks the bottom bar
- **THEN** the note area loses keyboard focus and shows no caret
- **AND** the note text is unchanged

#### Scenario: Drag the window while editing
- **WHEN** the note area has keyboard focus and the user drags the drag area
- **THEN** the window moves with the pointer
- **AND** the note area shows no caret after the drag

#### Scenario: Click the note area again
- **WHEN** editing has ended and the user clicks inside the note area
- **THEN** the note area gets keyboard focus and shows the caret at the clicked position

### Requirement: Panel stays movable
The user SHALL be able to move the panel by dragging a visible area that is not the text. Every note window MUST show a drag area across its top edge and a bottom bar across its bottom edge. Both MUST span the full width of the window. The bottom bar MUST be 20% lower than the drag area. Both MUST show a shaded fill that sets them apart from the note area: darker than the note area in light appearance and lighter in dark appearance. The drag area MUST NOT show a grip mark. The bottom bar MUST show no controls. Dragging the drag area or the bottom bar MUST move the panel. The note area MUST end above the bottom bar, so no note text shows under it. Dragging inside the text MUST select text and MUST NOT move the panel.

#### Scenario: Drag the drag area
- **WHEN** the user drags the panel's drag area
- **THEN** the panel moves with the pointer

#### Scenario: Drag the bottom bar
- **WHEN** the user drags the panel's bottom bar
- **THEN** the panel moves with the pointer

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
