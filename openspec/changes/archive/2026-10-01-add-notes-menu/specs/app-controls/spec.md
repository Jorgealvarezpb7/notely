# Spec Delta

## MODIFIED Requirements

### Requirement: Quit from keyboard
While any note panel or the menu window has keyboard focus, Cmd+Q SHALL quit the app. When a window of another application has keyboard focus, Cmd+Q MUST NOT quit the app.

#### Scenario: Cmd+Q while editing
- **WHEN** a note area has keyboard focus and the user presses Cmd+Q
- **THEN** the app quits

#### Scenario: Cmd+Q in the menu
- **WHEN** the menu window is the key window and the user presses Cmd+Q
- **THEN** the app quits

#### Scenario: Cmd+Q in another app
- **WHEN** the user clicks a window of another application and then presses Cmd+Q
- **THEN** the note app keeps running

### Requirement: Quitting keeps note text
Every quit path in this capability and the menu window's red button SHALL keep the full text of every note, open or closed, including the last keystroke. Quitting MUST also keep which notes are open and which are closed.

#### Scenario: Quit soon after typing
- **WHEN** the user types text in a note and, within one second of the last keystroke, quits through the app menu, the Dock icon's menu, Cmd+Q, or the menu window's red button
- **THEN** the next launch shows the full text of every note, including the last keystroke

### Requirement: Dock icon
While the app runs, the Dock SHALL show the app's icon. While the app is active, the menu bar MUST show the app's menus, and the app menu MUST contain a Quit item that quits the app. The Dock icon's menu MUST contain a Quit item that quits the app. Clicking the Dock icon MUST bring the menu window and every open note window to the front, and MUST restore the menu window when it is minimized.

#### Scenario: Dock icon at launch
- **WHEN** the app launches
- **THEN** the Dock shows the app's icon

#### Scenario: Quit from app menu
- **WHEN** the app is active and the user chooses Quit from the app menu
- **THEN** the app quits

#### Scenario: Quit from Dock
- **WHEN** the user opens the Dock icon's menu and chooses Quit
- **THEN** the app quits
- **AND** every note window, the menu window, and the Dock icon disappear

#### Scenario: Click Dock icon with notes hidden
- **WHEN** the menu window and every note window are behind windows of other applications and the user clicks the Dock icon
- **THEN** the menu window and every open note window come in front of the other applications' windows

#### Scenario: Click Dock icon with menu minimized
- **WHEN** the menu window is minimized and the user clicks the Dock icon
- **THEN** the menu window is restored from the Dock and shows in front
