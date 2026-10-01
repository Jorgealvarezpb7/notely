# checklists Specification

## Purpose

Lets the user keep checklists: a window with a title and items that the user can check off with a circle, with checked items kept, crossed out, at the bottom.

## Requirements

### Requirement: List windows behave like note windows
Every list SHALL have its own window that behaves like a note window. Its drag area MUST show the same "−" and trash buttons and no other buttons. "−" MUST close the list window and keep the list, which the menu still lists and opens again from its row. Trash MUST ask for confirmation and delete the list only after the user clicks "Delete", as for notes. A list window MUST follow the same rules as a note window for dragging, resizing, size limits, saved position and size, opening at launch only when it was open at quit, window layering, and showing no red, yellow, or green buttons.

#### Scenario: Close and reopen a list
- **WHEN** the user clicks "−" on a list window and then clicks the list's row in the menu
- **THEN** the list window opens at the position and size it had when closed, with its title and items unchanged

#### Scenario: Delete a list
- **WHEN** the user clicks the trash button on a list window and clicks "Delete"
- **THEN** the list window closes and the menu no longer lists it
- **AND** the list does not return on the next launch

#### Scenario: Relaunch with an open list
- **WHEN** a list window is open, the user moves and resizes it, quits the app, and launches it again
- **THEN** the list window opens at the same position and size, with the same title, items, and checked items

#### Scenario: List window controls
- **WHEN** a list window is open
- **THEN** its drag area shows a "−" button and a trash button, and no other buttons
- **AND** the window shows no red, yellow, or green button

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

### Requirement: Check and uncheck items
Clicking an item's circle SHALL check an unchecked item and uncheck a checked item, without moving keyboard focus into the item. An unchecked item MUST show an empty circle outline. A checked item MUST show a filled circle, white in dark appearance and dark gray in light appearance, and its text MUST show struck through, in the same white or black as unchecked text. Checked items MUST show after the "New item" row, with the most recently checked item first. Unchecking an item MUST move it to the end of the unchecked items. Items MUST animate to their new place. The "New item" row MUST NOT show a circle that can be checked.

#### Scenario: Check an item
- **WHEN** a list has unchecked items "eggs", "milk", and "bread", and the user clicks the circle of "milk"
- **THEN** "milk" shows a filled circle and struck-through text in the same color as unchecked text
- **AND** the list shows "eggs", "bread", the "New item" row, and then "milk"

#### Scenario: Most recently checked first
- **WHEN** the user checks "eggs" and then "bread"
- **THEN** the checked items show "bread" above "eggs"

#### Scenario: Uncheck an item
- **WHEN** the user clicks the filled circle of a checked item
- **THEN** the item shows an empty circle and plain text
- **AND** the item moves to the end of the unchecked items, above the "New item" row

#### Scenario: Circle in light and dark appearance
- **WHEN** the system appearance is dark and an item is checked
- **THEN** its circle is filled white
- **AND** when the system appearance is light, the same circle is filled dark gray

### Requirement: Keyboard editing in lists
A list window SHALL support these keys. In the title, Return MUST move keyboard focus to the first item, or to the "New item" row when the list has no items. In an unchecked item, Return MUST insert a new empty unchecked item directly below and give it keyboard focus. In a checked item, Return MUST move keyboard focus to the "New item" row. In an empty item, Backspace MUST remove the item and put the caret at the end of the row above. Up MUST move keyboard focus to the row above when the caret is on the first line of its row, and Down MUST move keyboard focus to the row below when the caret is on the last line of its row. Cmd+Return MUST check or uncheck the item that has keyboard focus. Esc MUST end editing and keep the text, as in notes. Cmd+A, Cmd+C, Cmd+V, Cmd+X, and Cmd+Z MUST work in the title and every item.

#### Scenario: Return in the title
- **WHEN** the title has keyboard focus and the user presses Return
- **THEN** keyboard focus moves to the first item

#### Scenario: Return in an item
- **WHEN** the unchecked item "eggs" has keyboard focus and the user presses Return
- **THEN** a new empty item shows directly below "eggs" with keyboard focus

#### Scenario: Backspace in an empty item
- **WHEN** an empty item below "eggs" has keyboard focus and the user presses Backspace
- **THEN** the empty item is removed
- **AND** the caret shows at the end of "eggs"

#### Scenario: Arrow keys between rows
- **WHEN** the caret is in the first item and the user presses Up
- **THEN** keyboard focus moves to the title
- **AND** pressing Down moves keyboard focus back to the first item

#### Scenario: Check from the keyboard
- **WHEN** an unchecked item has keyboard focus and the user presses Cmd+Return
- **THEN** the item is checked and moves to the top of the checked items

#### Scenario: Esc in a list
- **WHEN** an item has keyboard focus and the user presses Esc
- **THEN** no row has keyboard focus and the item's text is unchanged

### Requirement: List persistence
A list's title, items, item text, and checked state SHALL be saved on every change, without an explicit save action, and MUST be restored on the next launch. Every quit path MUST keep the last change. Notes saved by earlier versions MUST still open as notes.

#### Scenario: Quit soon after typing in a list
- **WHEN** the user types in a list item and quits the app with Cmd+Q within one second of the last keystroke
- **THEN** the next launch shows that item's full text, including the last keystroke

#### Scenario: Notes stay notes
- **WHEN** the app launches with notes saved by a version without lists
- **THEN** every one of those notes opens as a note with its text unchanged

### Requirement: End editing by clicking empty list space
In a list window, clicking empty space below the last row SHALL end editing, as Esc does. Ending editing MUST remove keyboard focus from the title and every item, and MUST keep their text. An item left empty when editing ends MUST be removed, as when it loses keyboard focus in any other way. Clicking the drag area or the bottom bar of a list window MUST end editing the same way as in note windows.

#### Scenario: Click below the rows
- **WHEN** an item has keyboard focus and the user clicks empty space below the last row
- **THEN** no row has keyboard focus and no caret shows
- **AND** the item's text is unchanged

#### Scenario: Click below the rows with an empty item
- **WHEN** an empty item has keyboard focus and the user clicks empty space below the last row
- **THEN** that empty item is removed from the list

#### Scenario: Click the drag area in a list
- **WHEN** the title has keyboard focus and the user clicks the list window's drag area, outside the "−" and trash buttons
- **THEN** no row has keyboard focus
- **AND** the title is unchanged
