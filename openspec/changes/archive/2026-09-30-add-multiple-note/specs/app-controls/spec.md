# Spec Delta

## MODIFIED Requirements

### Requirement: Quit from keyboard
While any note panel has keyboard focus, Cmd+Q SHALL quit the app. When a window of another application has keyboard focus, Cmd+Q MUST NOT quit the app.

#### Scenario: Cmd+Q while editing
- **WHEN** a note area has keyboard focus and the user presses Cmd+Q
- **THEN** the app quits

#### Scenario: Cmd+Q in another app
- **WHEN** the user clicks a window of another application and then presses Cmd+Q
- **THEN** the note app keeps running

### Requirement: Quitting keeps note text
Every quit path in this capability SHALL keep the full text of every open note, including the last keystroke.

#### Scenario: Quit soon after typing
- **WHEN** the user types text in a note and, within one second of the last keystroke, quits through the menu bar item or Cmd+Q
- **THEN** the next launch shows the full text of every note, including the last keystroke

## REMOVED Requirements

### Requirement: Panel close button
**Reason**: The user decided the panel close button added no value once "+" and "−" exist for creating and removing individual notes. Quitting the app now happens only through the menu bar item's Quit item and Cmd+Q.
**Migration**: Use the menu bar item's Quit item or Cmd+Q to quit the app. The panel's drag area keeps only the "+" and "−" buttons from the `multiple-notes` capability; it shows no close, minimize, or zoom button.
