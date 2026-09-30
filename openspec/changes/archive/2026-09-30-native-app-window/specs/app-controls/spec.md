# Spec Delta

## ADDED Requirements

### Requirement: Dock icon
While the app runs, the Dock SHALL show the app's icon. While the app is active, the menu bar MUST show the app's menus, and the app menu MUST contain a Quit item that quits the app. The Dock icon's menu MUST contain a Quit item that quits the app. Clicking the Dock icon MUST bring every note window to the front.

#### Scenario: Dock icon at launch
- **WHEN** the app launches
- **THEN** the Dock shows the app's icon

#### Scenario: Quit from app menu
- **WHEN** the app is active and the user chooses Quit from the app menu
- **THEN** the app quits

#### Scenario: Quit from Dock
- **WHEN** the user opens the Dock icon's menu and chooses Quit
- **THEN** the app quits
- **AND** every note window and the Dock icon disappear

#### Scenario: Click Dock icon with notes hidden
- **WHEN** every note window is behind windows of other applications and the user clicks the Dock icon
- **THEN** every note window comes in front of the other applications' windows

### Requirement: App icon
The app SHALL use the supplied Notely artwork (a pink rounded square with a black quoted "N") as its icon. The icon MUST show in the Dock, in Finder, and in the application switcher, and MUST look sharp at every standard macOS icon size.

#### Scenario: Icon in Finder
- **WHEN** the user opens the folder that contains the installed app in Finder
- **THEN** the app shows the Notely icon, not the generic application icon

#### Scenario: Icon in application switcher
- **WHEN** the app runs and the user presses Cmd+Tab
- **THEN** the application switcher shows the Notely icon

## MODIFIED Requirements

### Requirement: Quitting keeps note text
Every quit path in this capability SHALL keep the full text of every open note, including the last keystroke.

#### Scenario: Quit soon after typing
- **WHEN** the user types text in a note and, within one second of the last keystroke, quits through the app menu, the Dock icon's menu, or Cmd+Q
- **THEN** the next launch shows the full text of every note, including the last keystroke

## REMOVED Requirements

### Requirement: Menu bar item
**Reason**: The app now has a Dock icon and visible app menus, so the separate menu bar item is redundant.
**Migration**: Quit from the app menu, the Dock icon's menu, or Cmd+Q.
