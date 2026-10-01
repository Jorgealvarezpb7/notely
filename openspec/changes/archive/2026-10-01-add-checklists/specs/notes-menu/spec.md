# Spec Delta

## MODIFIED Requirements

### Requirement: Note list
The menu window SHALL show a "+ New" row first, followed by one row for every saved note and list, whether its window is open or closed. Rows MUST be ordered newest first, with notes and lists mixed. A note row's title MUST be the first line of the note's text that is not empty after trimming spaces, or "Untitled note" when the note has no such line. A list row's title MUST be the list's title after trimming spaces, or "Untitled list" when that is empty, and a list row MUST show a checklist icon at its trailing edge. A row's title MUST update while the user types in that note or list title. When the list is longer than the menu window, the menu MUST scroll vertically. While the pointer is over an enabled row or the chooser's "<--" control, that control MUST show a lighter background; disabled rows MUST NOT change.

#### Scenario: Rows for open and closed notes
- **WHEN** one note window is open and one note is closed
- **THEN** the menu shows "+ New" and then one row for each of the two notes

#### Scenario: Newest first
- **WHEN** the user creates note A and then note B
- **THEN** note B's row is above note A's row

#### Scenario: Row title from text
- **WHEN** a note's text is "\n  Groceries\nmilk"
- **THEN** that note's row shows "Groceries"

#### Scenario: Empty note title
- **WHEN** a note's text is empty or only spaces and line breaks
- **THEN** that note's row shows "Untitled note"

#### Scenario: Hover a row
- **WHEN** the pointer moves over a note row
- **THEN** that row shows a lighter background
- **AND** the background returns to normal when the pointer leaves the row

#### Scenario: Title follows typing
- **WHEN** the user changes the first line of an open note
- **THEN** that note's row shows the new first line without the user doing anything else

#### Scenario: List row
- **WHEN** a list's title is "Groceries"
- **THEN** its row shows "Groceries" and a checklist icon at the trailing edge
- **AND** when the title is empty, the row shows "Untitled list"

#### Scenario: Notes and lists mixed
- **WHEN** the user creates note A, then list B, then note C
- **THEN** the rows show C, B, and A, in that order

### Requirement: App keeps running with no notes
Deleting the last note SHALL NOT quit the app. The menu window MUST stay open and show only "+ New". The next launch MUST open the menu window with no note windows and no note rows.

#### Scenario: Delete the last note
- **WHEN** one note exists and the user clicks its trash button and then "Delete"
- **THEN** the note window closes and the app keeps running
- **AND** the menu shows only "+ New"

#### Scenario: Launch with no notes
- **WHEN** the user deleted every note, quits the app, and launches it again
- **THEN** the menu window opens and shows only "+ New"
- **AND** no note window opens

## ADDED Requirements

### Requirement: New chooser with lists
Clicking "+ New" SHALL replace the note list in the menu window with a chooser. The chooser MUST show a "<--" back control at its top-right, a "+ New Note" row, and a "+ New List" row, both enabled. Clicking "<--" MUST show the note list again without creating anything.

#### Scenario: Open the chooser
- **WHEN** the user clicks "+ New" in the menu
- **THEN** the menu window shows "<--", "+ New Note", and "+ New List"
- **AND** "+ New List" looks enabled and reacts to hover

#### Scenario: Back from the chooser
- **WHEN** the chooser shows and the user clicks "<--"
- **THEN** the menu window shows the note list
- **AND** nothing is created

### Requirement: Create a list from the menu
Clicking "+ New List" SHALL create one new list with an empty title and no items, and open its window at the same frame a new note would get: 220 by 150 points, placed next to the menu window by the rules of "Create a note from the menu". The new list's title MUST receive keyboard focus. The menu window MUST then show the note list with the new list's row first.

#### Scenario: Click "+ New List"
- **WHEN** the menu has room on its right and the user clicks "+ New List"
- **THEN** a new 220 by 150 point list window opens 12 points to the right of the menu, top edges aligned
- **AND** its title row shows "Untitled list" and receives keystrokes
- **AND** the menu shows the note list with "Untitled list" as the first row

## REMOVED Requirements

### Requirement: New chooser
**Reason**: "+ New List" is no longer a disabled placeholder, so the chooser requirement and its placeholder scenario no longer hold.
**Migration**: See "New chooser with lists" in this capability, and "Create a list from the menu".
