# Spec Delta

## MODIFIED Requirements

### Requirement: Scroll bar shows only while scrolling
The scroll bar of every note area SHALL be hidden while the user is not scrolling that note area. When the user scrolls a note area whose text is longer than the visible area, that note area MUST show its scroll bar over the text, and MUST hide the scroll bar again after scrolling stops. This behavior MUST NOT depend on the macOS "Show scroll bars" setting or on the connected pointing device, and MUST stay the same when either changes while the app runs. The note area MUST keep scrolling with the trackpad, the mouse wheel, and caret movement.

#### Scenario: Idle long note
- **WHEN** a note's text is longer than its visible note area and the user is not scrolling
- **THEN** the note area shows no scroll bar
- **AND** the note text uses the full width of the note area

#### Scenario: Scroll a long note
- **WHEN** the user scrolls a note area whose text is longer than the visible area
- **THEN** the scroll bar shows over the text while scrolling
- **AND** the scroll bar hides after scrolling stops

#### Scenario: System setting is "Always"
- **WHEN** the macOS "Show scroll bars" setting is "Always" and the app launches with a long note
- **THEN** that note area shows no scroll bar until the user scrolls it

#### Scenario: Mouse connected
- **WHEN** a mouse is connected, the "Show scroll bars" setting is "Automatically based on mouse or trackpad", and the app launches with a long note
- **THEN** that note area shows no scroll bar until the user scrolls it

#### Scenario: Setting changes while the app runs
- **WHEN** the app is running and the user changes the "Show scroll bars" setting, or connects or disconnects a mouse
- **THEN** every open note area still hides its scroll bar until the user scrolls it

#### Scenario: New note
- **WHEN** the user creates a note with "+ New Note" in the menu and types text longer than its visible note area
- **THEN** that note area shows no scroll bar until the user scrolls it

#### Scenario: Reopened note
- **WHEN** the user closes a long note with "−" and opens it again from the menu
- **THEN** that note area shows no scroll bar until the user scrolls it

#### Scenario: Scroll with the caret
- **WHEN** a note's text is longer than its visible note area and the user moves the caret below the visible area with the arrow keys
- **THEN** the note area scrolls to keep the caret visible
