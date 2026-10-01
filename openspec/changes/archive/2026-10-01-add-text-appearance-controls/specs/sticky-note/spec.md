# Spec Delta

## MODIFIED Requirements

### Requirement: Note typeface
Every note area SHALL show its note text in the font and at the size of the text appearance setting: American Typewriter or the macOS system font, at 10 to 20 points, with American Typewriter at 15 points when the user has not changed the setting. The placeholder text of an empty note area MUST use the same typeface and size as note text, and MUST start at the position where the first typed character appears, at every font and size. The placeholder MUST use the same color as note text: white in dark appearance and black in light appearance.

#### Scenario: Typed text uses the chosen font
- **WHEN** the font setting is "System" at 12 points and the user types text in a note area
- **THEN** the text shows in the system font at 12 points

#### Scenario: Typed text uses American Typewriter
- **WHEN** the user has never changed the text appearance setting and types text in a note area
- **THEN** the text shows in American Typewriter at 15 points

#### Scenario: Placeholder uses American Typewriter
- **WHEN** the user has never changed the text appearance setting and a note area is empty
- **THEN** the placeholder text shows in American Typewriter at the same size as note text

#### Scenario: Placeholder uses the note font
- **WHEN** the font setting is "System" at 12 points and a note area is empty
- **THEN** the placeholder text shows in the system font at 12 points

#### Scenario: Placeholder lines up with the caret
- **WHEN** a note area is empty and has keyboard focus, at any font and size
- **THEN** the caret shows at the start of the placeholder text's first line

#### Scenario: Placeholder color
- **WHEN** a note area is empty
- **THEN** the placeholder shows white in dark appearance and black in light appearance

#### Scenario: Saved text after upgrade
- **WHEN** the app launches with notes saved by an earlier version
- **THEN** every note shows its saved text unchanged, in the font and size of the text appearance setting

### Requirement: Panel stays movable
The user SHALL be able to move the panel by dragging a visible area that is not the text. Every note window MUST show a drag area across its top edge and a bottom bar across its bottom edge. Both MUST span the full width of the window. The bottom bar MUST be 20% lower than the drag area. Both MUST show a shaded fill that sets them apart from the note area: darker than the note area in light appearance and lighter in dark appearance. The drag area MUST NOT show a grip mark. The bottom bar MUST show only the font button and the text size button, at its trailing edge. Dragging the drag area, or the bottom bar outside its buttons, MUST move the panel. The note area MUST end above the bottom bar, so no note text shows under it. Dragging inside the text MUST select text and MUST NOT move the panel.

#### Scenario: Drag the drag area
- **WHEN** the user drags the panel's drag area
- **THEN** the panel moves with the pointer

#### Scenario: Drag the bottom bar
- **WHEN** the user drags the panel's bottom bar outside its buttons
- **THEN** the panel moves with the pointer

#### Scenario: Bottom bar controls
- **WHEN** a note window is open
- **THEN** its bottom bar shows the font button and the text size button at the trailing edge, and no other controls

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
