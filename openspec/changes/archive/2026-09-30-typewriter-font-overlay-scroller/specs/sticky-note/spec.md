# Spec Delta

## ADDED Requirements

### Requirement: Note typeface
Every note area SHALL show its note text in the American Typewriter typeface, at 15 points. The placeholder text of an empty note area MUST use the same typeface and size, and MUST start at the position where the first typed character appears.

#### Scenario: Typed text uses American Typewriter
- **WHEN** the user types text in a note area
- **THEN** the text shows in American Typewriter at 15 points

#### Scenario: Placeholder uses American Typewriter
- **WHEN** a note area is empty
- **THEN** the placeholder text shows in American Typewriter at the same size as note text

#### Scenario: Placeholder lines up with the caret
- **WHEN** a note area is empty and has keyboard focus
- **THEN** the caret shows at the start of the placeholder text's first line

#### Scenario: Saved text after upgrade
- **WHEN** the app launches with notes saved by a version that used the system font
- **THEN** every note shows its saved text unchanged, in American Typewriter

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
- **WHEN** the user creates a note with "+" and types text longer than its visible note area
- **THEN** that note area shows no scroll bar until the user scrolls it

#### Scenario: Scroll with the caret
- **WHEN** a note's text is longer than its visible note area and the user moves the caret below the visible area with the arrow keys
- **THEN** the note area scrolls to keep the caret visible
