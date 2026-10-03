# Spec Delta

## MODIFIED Requirements

### Requirement: Font and size buttons in the bottom bar
The bottom bar of every note window and every list window SHALL show two icon buttons at its trailing edge: a font button and a text size button, in that order, followed by the tint button as defined by the note-tint capability. In note windows, the bottom bar MUST also show the Bold, Italic, and Underline buttons at its leading edge; list windows MUST NOT show them. The buttons MUST use the same borderless icon style and size as the "−" and trash buttons in the drag area. Each button MUST work on the first click, also while another application is active. Clicking a button MUST open its control and MUST NOT move the window. Clicks on the buttons MUST reach the buttons, also when the note or list content is taller than the window. The menu window MUST NOT show these buttons.

#### Scenario: Buttons in a note window
- **WHEN** a note window is open
- **THEN** its bottom bar shows a font button, a text size button, and a tint button at the trailing edge
- **AND** the Bold, Italic, and Underline buttons at the leading edge

#### Scenario: Buttons in a list window
- **WHEN** a list window is open and its items are taller than the window
- **THEN** its bottom bar shows the font button, the text size button, and the tint button, and no style buttons
- **AND** clicking the font button or the text size button opens its control, not a list row

#### Scenario: No buttons in the menu
- **WHEN** the menu window is open
- **THEN** it shows no font button and no text size button

#### Scenario: Click while another app is active
- **WHEN** another application is active and the user clicks the font button of a note window
- **THEN** the font menu opens with that one click

### Requirement: Buttons usable at minimum window size
At the minimum note window size, a note window SHALL show the Bold, Italic, Underline, font, text size, and tint buttons and the drag area's "−" and trash buttons fully inside the window, without overlap, and at least one full line of text at the largest text size. A list window at the minimum size MUST show the font, text size, and tint buttons, "−", and trash fully inside the window, and at least one full line of text at the largest text size.

#### Scenario: Smallest window, largest text
- **WHEN** a note window is at its minimum size and the text size is 20 points
- **THEN** the window shows Bold, Italic, Underline, the font button, the text size button, the tint button, "−", and trash, none of them overlapping
- **AND** at least one full line of note text shows

#### Scenario: Smallest list window
- **WHEN** a list window is at its minimum size and the text size is 20 points
- **THEN** the window shows the font button, the text size button, the tint button, "−", and trash
- **AND** at least one full line of list text shows
