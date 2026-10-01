# Spec Delta

## ADDED Requirements

### Requirement: Close a note from its panel
Every panel's drag area SHALL show a "−" button. Clicking "−" MUST close that note's window and MUST keep the note's text, position, and size. The note MUST stay listed in the menu and MUST open again from its row. Other notes MUST stay open and unchanged. A closed note MUST NOT open at the next launch until the user opens it from the menu.

#### Scenario: Click "−"
- **WHEN** two notes are open and the user clicks "−" on the first panel
- **THEN** the first panel closes
- **AND** the menu still lists the first note
- **AND** the second panel stays open with its text unchanged

#### Scenario: Closed note stays closed after relaunch
- **WHEN** the user clicks "−" on a note, quits the app, and launches it again
- **THEN** that note's window does not open
- **AND** the menu lists that note, and clicking its row opens it with its text unchanged

#### Scenario: Close the only open note
- **WHEN** one note window is open and the user clicks "−" on it
- **THEN** the note window closes and the app keeps running with the menu open

#### Scenario: Click "−" while another app is frontmost
- **WHEN** another application is frontmost and the user clicks "−" once
- **THEN** the panel closes on that click

### Requirement: Delete a note from its panel
Every panel's drag area SHALL show a trash button. Clicking the trash button MUST close that panel and delete that note's text at once, with no confirmation. The menu MUST stop listing that note at once. Other notes MUST stay open and unchanged. A removed note MUST NOT return on the next launch.

#### Scenario: Click trash with two notes open
- **WHEN** two notes are open and the user clicks the trash button on the first panel
- **THEN** the first panel closes and the menu no longer lists the first note
- **AND** the second panel stays open with its text unchanged

#### Scenario: Removed note stays removed
- **WHEN** the user clicks the trash button on a note, quits the app, and launches it again
- **THEN** the removed note does not open and the menu does not list it

#### Scenario: Click trash while another app is frontmost
- **WHEN** another application is frontmost and the user clicks the trash button once
- **THEN** the panel closes on that click

## MODIFIED Requirements

### Requirement: Panel buttons do not move the panel
Clicking "−" or the trash button MUST NOT start a panel drag. Dragging a part of the drag area that is not a button MUST still move the panel. The drag area MUST show no buttons other than "−" and the trash button.

#### Scenario: Click a panel button
- **WHEN** the user presses and drags from the "−" or trash button
- **THEN** the panel does not move

#### Scenario: Drag area buttons
- **WHEN** a note panel is open
- **THEN** its drag area shows a "−" button and a trash button, and no other buttons

### Requirement: All notes restored on launch
On launch, the app SHALL open one panel for every note whose window was open when the app last quit, each with its saved text and its saved position. Notes whose window was closed MUST NOT open a panel. Notes saved by a version without closing MUST open a panel.

#### Scenario: Relaunch with three notes
- **WHEN** three notes with different text are open at different positions, the user quits the app, and launches it again
- **THEN** three panels open, each with the same text at the same position as before

#### Scenario: Relaunch with one closed note
- **WHEN** two notes are open, the user closes one with "−", quits the app, and launches it again
- **THEN** only the other note's panel opens
- **AND** the menu lists both notes

#### Scenario: Notes saved by an earlier version
- **WHEN** the app launches with notes saved by a version without the menu
- **THEN** every one of those notes opens a panel with its text and position

## REMOVED Requirements

### Requirement: Remove a note from its panel
**Reason**: The "−" button now closes a note and keeps it. Deleting a note moves to a new trash button.
**Migration**: Click the trash button to delete a note ("Delete a note from its panel"). Click "−" to close a note and keep it ("Close a note from its panel").

### Requirement: Create a note from a panel
**Reason**: Notes are now created from the menu window's "+ New" chooser. A "+" on every note duplicated that and gave new notes no single, predictable place.
**Migration**: Use "+ New", then "+ New Note", in the menu window (`notes-menu` capability, "Create a note from the menu").

### Requirement: Removing the last note quits the app
**Reason**: The menu window stays open with no notes, so the app has a visible window and a way to create a note. Quitting would hide that.
**Migration**: Quit with the menu window's red button, the app menu, the Dock icon's menu, or Cmd+Q. With no notes, the app keeps running and the menu shows only "+ New" (`notes-menu` capability, "App keeps running with no notes").
