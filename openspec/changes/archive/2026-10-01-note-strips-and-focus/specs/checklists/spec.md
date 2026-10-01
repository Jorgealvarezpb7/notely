# Spec Delta

## ADDED Requirements

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
