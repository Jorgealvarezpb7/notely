# Spec Delta

## MODIFIED Requirements

### Requirement: List items
Below the title, a list window SHALL show one row per item. Each row MUST show a circle at its leading edge and the item's text in the font and at the size of the text appearance setting, with American Typewriter at 15 points when the user has not changed the setting. The "New item" placeholder MUST use the same font and size. Long item text MUST wrap onto more lines within the window's width, and rows MUST change height to fit the text when the size changes. An empty row with the placeholder "New item" MUST always follow the unchecked items, before the checked items. Typing in the "New item" row MUST create an item with the typed text, keep keyboard focus in that item, and show a new empty "New item" row below it. When an item loses keyboard focus while its text is empty, that item MUST be removed. When the items are taller than the window, the list MUST scroll vertically, and its scroll bar MUST show only while the user scrolls, as in note areas. The title and the rows MUST show only between the drag area and the bottom bar: while the list scrolls, no list text, circle, or placeholder MUST show over or under either bar, and the drag area's and the bottom bar's buttons MUST stay visible and clickable.

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

#### Scenario: Scroll a long list down
- **WHEN** a list's items are taller than its window and the user scrolls to the end of the list
- **THEN** the rows that scroll up past the top of the list area are hidden where the list area begins, below the drag area
- **AND** the drag area shows only its fill, its logo, and the "−" and trash buttons

#### Scenario: Scroll a long list back up
- **WHEN** the user scrolls a long list back to the top
- **THEN** the rows that scroll down past the bottom of the list area are hidden where the list area ends, above the bottom bar
- **AND** the title shows below the drag area, as before scrolling

#### Scenario: Buttons over a scrolled list
- **WHEN** a long list is scrolled so rows sit right below the drag area, and the user clicks "−"
- **THEN** the list window closes, as when the list is not scrolled
