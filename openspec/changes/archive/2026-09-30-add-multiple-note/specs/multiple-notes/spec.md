# Spec Delta

## Purpose

Lets the user keep several separate notes on screen, each in its own floating panel, and create and remove notes from buttons on the panels.

## ADDED Requirements

### Requirement: Independent note panels
Each note SHALL have its own panel, its own text, and its own position. Typing in one note MUST NOT change the text of another note. Moving one panel MUST NOT move another panel.

#### Scenario: Type in one of two notes
- **WHEN** two notes are open and the user types text in the first note
- **THEN** the text appears only in the first note
- **AND** the second note's text is unchanged

#### Scenario: Move one of two notes
- **WHEN** two notes are open and the user drags the first panel's drag area
- **THEN** only the first panel moves

### Requirement: Create a note from a panel
Every panel's drag area SHALL show a "+" button. Clicking "+" MUST open one new, empty note panel that shows the placeholder text. The new panel MUST open 24 points to the left of and 24 points below the panel whose "+" was clicked. When that position is not fully inside the visible area of the clicked panel's screen, the new panel MUST move the shortest distance to be fully inside it. The new note's text area MUST receive keyboard focus, and the previously frontmost application MUST stay the active application.

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
- **AND** the other application stays the active application in the menu bar

### Requirement: Remove a note from its panel
Every panel's drag area SHALL show a "−" button. Clicking "−" MUST close that panel and delete that note's text at once, with no confirmation. Other notes MUST stay open and unchanged. A removed note MUST NOT return on the next launch.

#### Scenario: Click "−" with two notes open
- **WHEN** two notes are open and the user clicks "−" on the first panel
- **THEN** the first panel closes
- **AND** the second panel stays open with its text unchanged

#### Scenario: Removed note stays removed
- **WHEN** the user clicks "−" on a note, quits the app, and launches it again
- **THEN** the removed note does not open

#### Scenario: Click "−" while another app is frontmost
- **WHEN** another application is frontmost and the user clicks "−" once
- **THEN** the panel closes on that click

### Requirement: Removing the last note quits the app
When the user removes the only open note, the app SHALL quit. The next launch MUST show one empty note at the default position.

#### Scenario: Click "−" on the only note
- **WHEN** one note is open and the user clicks "−" on it
- **THEN** the app quits
- **AND** the panel and the menu bar item disappear

#### Scenario: Launch after removing the last note
- **WHEN** the app quit because the user removed the last note, and the user launches it again
- **THEN** one empty note opens 20 points from the top and right edges of the main screen's visible area

### Requirement: Panel buttons do not move the panel
Clicking "+" or "−" MUST NOT start a panel drag. Dragging a part of the drag area that is not a button MUST still move the panel. The drag area MUST show no buttons other than "+" and "−".

#### Scenario: Click a panel button
- **WHEN** the user presses and drags from the "+" or "−" button
- **THEN** the panel does not move

#### Scenario: Drag area buttons
- **WHEN** a note panel is open
- **THEN** its drag area shows a "+" button and a "−" button, and no other buttons

### Requirement: All notes restored on launch
On launch, the app SHALL open one panel for every note that was open when the app last quit, each with its saved text and its saved position.

#### Scenario: Relaunch with three notes
- **WHEN** three notes with different text are open at different positions, the user quits the app, and launches it again
- **THEN** three panels open, each with the same text at the same position as before

### Requirement: Existing note kept on upgrade
The first launch of a version with multiple notes SHALL open the note that the single-note version saved, with its text and its position.

#### Scenario: Upgrade from single note
- **WHEN** the single-note version saved note text and a panel position, and the user launches the multiple-note version for the first time
- **THEN** one panel opens with the same text at the same position
