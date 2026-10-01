# Spec Delta

## MODIFIED Requirements

### Requirement: Note typeface
Every note area SHALL show its note text in the American Typewriter typeface, at 15 points. The placeholder text of an empty note area MUST use the same typeface and size, and MUST start at the position where the first typed character appears. The placeholder MUST use the same color as note text: white in dark appearance and black in light appearance.

#### Scenario: Typed text uses American Typewriter
- **WHEN** the user types text in a note area
- **THEN** the text shows in American Typewriter at 15 points

#### Scenario: Placeholder uses American Typewriter
- **WHEN** a note area is empty
- **THEN** the placeholder text shows in American Typewriter at the same size as note text

#### Scenario: Placeholder lines up with the caret
- **WHEN** a note area is empty and has keyboard focus
- **THEN** the caret shows at the start of the placeholder text's first line

#### Scenario: Placeholder color
- **WHEN** a note area is empty
- **THEN** the placeholder shows white in dark appearance and black in light appearance

#### Scenario: Saved text after upgrade
- **WHEN** the app launches with notes saved by a version that used the system font
- **THEN** every note shows its saved text unchanged, in American Typewriter
