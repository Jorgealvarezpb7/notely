# Spec Delta

## MODIFIED Requirements

### Requirement: Panel stays movable
The user SHALL be able to move the panel by dragging a visible area that is not the text. Every note window MUST show a drag area across its top edge and a bottom bar across its bottom edge. Both MUST span the full width of the window. The bottom bar MUST be 20% lower than the drag area. Both MUST show a shaded fill that sets them apart from the note area: darker than the note area in light appearance and lighter in dark appearance. The drag area MUST NOT show a grip mark. The drag area MUST show only its shaded fill, the "−" and trash buttons, and the Notely logo. The bottom bar of a note window MUST show only the Bold, Italic, and Underline buttons at its leading edge, and the font button and the text size button at its trailing edge. Dragging the drag area, or the bottom bar outside its buttons, MUST move the panel. The note area MUST end above the bottom bar, so no note text shows under it. Dragging inside the text MUST select text and MUST NOT move the panel.

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
- **THEN** its drag area shows only its shaded fill, the "−" and trash buttons, and the Notely logo

#### Scenario: Long note above the bottom bar
- **WHEN** a note's text is longer than its visible note area
- **THEN** the last visible line of text ends above the bottom bar

## ADDED Requirements

### Requirement: Logo in the drag area
The drag area of every note window and every list window SHALL show the Notely logo: an "N" between two pairs of quote marks, as drawn in `Packaging/notely-logo.svg`. The logo MUST be centered horizontally in the window and vertically in the drag area, and MUST keep the artwork's proportions. The logo MUST be shorter than the drag area, with space above and below it. The logo MUST show in a translucent black in light appearance and a translucent white in dark appearance, so it matches the drag area's shaded fill, and MUST show less strongly than the "−" and trash buttons. The logo MUST change color at once when the system appearance changes. The logo MUST NOT be a control: a click on it MUST end editing, and dragging from it MUST move the window, as on any other part of the drag area. When the window is too narrow for the logo to show at the center without touching the "−" button, the drag area MUST NOT show the logo. The menu window MUST NOT show the logo.

#### Scenario: Logo in a note window
- **WHEN** a note window is open at its default size
- **THEN** its drag area shows the Notely logo at the horizontal center of the window

#### Scenario: Logo in a list window
- **WHEN** a list window is open at its default size
- **THEN** its drag area shows the Notely logo at the horizontal center of the window

#### Scenario: Logo in light appearance
- **WHEN** the system appearance is light
- **THEN** the logo shows in a translucent black, lighter than the "−" and trash buttons

#### Scenario: Logo in dark appearance
- **WHEN** the system appearance is dark
- **THEN** the logo shows in a translucent white, dimmer than the "−" and trash buttons

#### Scenario: Appearance changes
- **WHEN** a note window is open and the user switches the system appearance from light to dark
- **THEN** the logo changes from translucent black to translucent white without reopening the window

#### Scenario: Drag from the logo
- **WHEN** the user drags the window starting on the logo
- **THEN** the window moves with the pointer

#### Scenario: Click the logo while editing
- **WHEN** the note area has keyboard focus and the user clicks the logo
- **THEN** editing ends and the note text is kept

#### Scenario: Narrow window
- **WHEN** the user resizes a note window to its minimum width
- **THEN** the drag area shows no logo
- **AND** the "−" and trash buttons show and work as before

#### Scenario: Menu window
- **WHEN** the menu window is open
- **THEN** it shows no Notely logo
