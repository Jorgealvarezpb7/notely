# Spec Delta

## Purpose

Gives the user visible, standard ways to quit the floating note app, which has no Dock icon: a menu bar item, a close button on the panel, and Cmd+Q.

## ADDED Requirements

### Requirement: Menu bar item
While the app runs, the app SHALL show one item in the menu bar. The item's menu MUST contain a Quit item that quits the app. The app MUST still show no Dock icon.

#### Scenario: Menu bar item at launch
- **WHEN** the app launches
- **THEN** the menu bar shows the app's item
- **AND** the Dock shows no icon for the app

#### Scenario: Quit from menu bar
- **WHEN** the user opens the menu bar item's menu and chooses Quit
- **THEN** the app quits
- **AND** the panel and the menu bar item disappear

### Requirement: Panel close button
The panel SHALL show one native macOS close button in its drag area. Clicking the close button MUST quit the app. The panel MUST NOT show a minimize button or a zoom button.

#### Scenario: Only a close button
- **WHEN** the app launches
- **THEN** the drag area shows a close button
- **AND** the panel shows no minimize button and no zoom button

#### Scenario: Click close button
- **WHEN** the user clicks the close button
- **THEN** the app quits

#### Scenario: Click close button while another app is frontmost
- **WHEN** another application is frontmost and the user clicks the close button once
- **THEN** the app quits on that click

#### Scenario: Drag area outside the close button still moves the panel
- **WHEN** the user drags a part of the drag area that is not the close button
- **THEN** the panel moves with the pointer

### Requirement: Quit from keyboard
While the panel has keyboard focus, Cmd+Q SHALL quit the app. When a window of another application has keyboard focus, Cmd+Q MUST NOT quit the app.

#### Scenario: Cmd+Q while editing
- **WHEN** the note area has keyboard focus and the user presses Cmd+Q
- **THEN** the app quits

#### Scenario: Cmd+Q in another app
- **WHEN** the user clicks a window of another application and then presses Cmd+Q
- **THEN** the note app keeps running

### Requirement: Quitting keeps note text
Every quit path in this capability SHALL keep the full note text, including the last keystroke.

#### Scenario: Quit soon after typing
- **WHEN** the user types text and, within one second of the last keystroke, quits through the menu bar item, the close button, or Cmd+Q
- **THEN** the next launch shows the full text including the last keystroke
