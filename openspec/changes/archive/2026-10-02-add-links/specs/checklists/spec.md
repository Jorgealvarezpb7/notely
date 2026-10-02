# Spec Delta

## MODIFIED Requirements

### Requirement: List title
A list window SHALL show a title row above its items. The title MUST show in the bold form of the font of the text appearance setting, at the setting's size: American Typewriter Bold or the bold macOS system font, at 10 to 20 points, with American Typewriter Bold at 15 points when the user has not changed the setting. When the title is empty, the row MUST show the placeholder "Untitled list" in the same font and size. All list text, the title, items, and the "Untitled list" and "New item" placeholders included, MUST show white in dark appearance and black in light appearance, never gray, except web addresses, which show in the link color as defined by the links capability. The user MUST be able to type, select, copy, and paste in the title.

#### Scenario: Name a list
- **WHEN** the font setting is the default and the user types "Groceries" in a list's title row
- **THEN** the title row shows "Groceries" in American Typewriter Bold at 15 points

#### Scenario: Title with the system font
- **WHEN** the font setting is "System" at 18 points
- **THEN** a list's title shows in the bold system font at 18 points

#### Scenario: Empty title
- **WHEN** a list's title is empty
- **THEN** the title row shows the placeholder "Untitled list"

#### Scenario: Address in a title
- **WHEN** a list's title is "Trip: https://example.com/plan"
- **THEN** "Trip:" shows in white or black and "https://example.com/plan" shows as a link
