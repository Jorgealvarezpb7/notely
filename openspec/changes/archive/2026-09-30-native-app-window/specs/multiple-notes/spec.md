# Spec Delta

## MODIFIED Requirements

### Requirement: Create a note from a panel
Every panel's drag area SHALL show a "+" button. Clicking "+" MUST open one new, empty note panel that shows the placeholder text. The new panel MUST open 24 points to the left of and 24 points below the panel whose "+" was clicked. When that position is not fully inside the visible area of the clicked panel's screen, the new panel MUST move the shortest distance to be fully inside it. The new note's text area MUST receive keyboard focus.

#### Scenario: Click "+"
- **WHEN** the user clicks "+" on a panel
- **THEN** a new panel opens 24 points to the left of and 24 points below that panel
- **AND** the new panel's note area is empty, shows placeholder text, and receives keystrokes

#### Scenario: Click "+" near a screen edge
- **WHEN** the user clicks "+" on a panel that touches the left or bottom edge of its screen's visible area
- **THEN** the new panel opens fully inside that screen's visible area

#### Scenario: Click "+" while another app is frontmost
- **WHEN** another application is frontmost and the user clicks "+" once
- **THEN** a new panel opens on that click
- **AND** the new panel's note area receives keystrokes

### Requirement: Removing the last note quits the app
When the user removes the only open note, the app SHALL quit. The next launch MUST show one empty note at the default position.

#### Scenario: Click "−" on the only note
- **WHEN** one note is open and the user clicks "−" on it
- **THEN** the app quits
- **AND** the note window and the Dock icon disappear

#### Scenario: Launch after removing the last note
- **WHEN** the app quit because the user removed the last note, and the user launches it again
- **THEN** one empty note opens 20 points from the top and right edges of the main screen's visible area
