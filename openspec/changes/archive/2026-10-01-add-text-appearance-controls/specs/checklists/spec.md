# Spec Delta

## MODIFIED Requirements

### Requirement: List title
A list window SHALL show a title row above its items. The title MUST show in the bold form of the font of the text appearance setting, at the setting's size: American Typewriter Bold or the bold macOS system font, at 10 to 20 points, with American Typewriter Bold at 15 points when the user has not changed the setting. When the title is empty, the row MUST show the placeholder "Untitled list" in the same font and size. All list text, the title, items, and the "Untitled list" and "New item" placeholders included, MUST show white in dark appearance and black in light appearance, never gray. The user MUST be able to type, select, copy, and paste in the title.

#### Scenario: Name a list
- **WHEN** the font setting is the default and the user types "Groceries" in a list's title row
- **THEN** the title row shows "Groceries" in American Typewriter Bold at 15 points

#### Scenario: Title with the system font
- **WHEN** the font setting is "System" at 18 points
- **THEN** a list's title shows in the bold system font at 18 points

#### Scenario: Empty title
- **WHEN** a list's title is empty
- **THEN** the title row shows the placeholder "Untitled list"

### Requirement: List items
Below the title, a list window SHALL show one row per item. Each row MUST show a circle at its leading edge and the item's text in the font and at the size of the text appearance setting, with American Typewriter at 15 points when the user has not changed the setting. The "New item" placeholder MUST use the same font and size. Long item text MUST wrap onto more lines within the window's width, and rows MUST change height to fit the text when the size changes. An empty row with the placeholder "New item" MUST always follow the unchecked items, before the checked items. Typing in the "New item" row MUST create an item with the typed text, keep keyboard focus in that item, and show a new empty "New item" row below it. When an item loses keyboard focus while its text is empty, that item MUST be removed. When the items are taller than the window, the list MUST scroll vertically, and its scroll bar MUST show only while the user scrolls, as in note areas.

#### Scenario: Add the first item
- **WHEN** a list has no items and the user types "milk" in the "New item" row
- **THEN** the list shows an unchecked item "milk"
- **AND** a new empty "New item" row shows below it

#### Scenario: Items follow the size
- **WHEN** a list window is open and the user sets the text size to 20 points
- **THEN** every item and the "New item" row show at 20 points
- **AND** each row grows to fit its text, and long items wrap within the window's width

#### Scenario: Long item
- **WHEN** an item's text is wider than the window
- **THEN** the item's text wraps onto more lines and the window keeps its size

#### Scenario: Empty item removed
- **WHEN** the user clears an item's text and then clicks another row
- **THEN** that item is removed from the list

#### Scenario: Long list
- **WHEN** a list's items are taller than its window and the user is not scrolling
- **THEN** the list shows no scroll bar
- **AND** scrolling the list shows the scroll bar until scrolling stops
