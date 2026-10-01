# Spec Delta

## MODIFIED Requirements

### Requirement: Panel buttons do not move the panel
Clicking "−" or the trash button MUST NOT start a panel drag. Dragging a part of the drag area that is not a button MUST still move the panel. The drag area MUST show no buttons other than "−" and the trash button. The trash button MUST sit at least 16 points from the "−" button, so the user does not click one for the other.

#### Scenario: Click a panel button
- **WHEN** the user presses and drags from the "−" or trash button
- **THEN** the panel does not move

#### Scenario: Drag area buttons
- **WHEN** a note panel is open
- **THEN** its drag area shows a "−" button and a trash button, and no other buttons
- **AND** the gap between the two buttons is at least 16 points

### Requirement: Delete a note from its panel
Every panel's drag area SHALL show a trash button. Clicking the trash button MUST show a confirmation sheet on that panel that names the note and offers "Cancel" and "Delete". "Cancel" MUST be the default button, so Return and Esc cancel. Only clicking "Delete" MUST close that panel and delete the note. Cancelling MUST keep the note and its panel unchanged. After a delete, the menu MUST stop listing that note at once, other notes MUST stay open and unchanged, and the deleted note MUST NOT return on the next launch.

#### Scenario: Click trash with two notes open
- **WHEN** two notes are open, the user clicks the trash button on the first panel, and clicks "Delete"
- **THEN** the first panel closes and the menu no longer lists the first note
- **AND** the second panel stays open with its text unchanged

#### Scenario: Cancel a delete
- **WHEN** the user clicks the trash button on a note and then clicks "Cancel", or presses Return or Esc
- **THEN** the sheet closes, and the note stays open with its text unchanged

#### Scenario: Removed note stays removed
- **WHEN** the user deletes a note with the trash button and "Delete", quits the app, and launches it again
- **THEN** the removed note does not open and the menu does not list it

#### Scenario: Click trash while another app is frontmost
- **WHEN** another application is frontmost and the user clicks the trash button once
- **THEN** the confirmation sheet shows on that click
