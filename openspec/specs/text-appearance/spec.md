# text-appearance Specification

## Purpose

Lets the user choose the font and the text size of note and list text from a bottom bar in note and list windows, as one global setting that persists between app launches.

## Requirements

### Requirement: Font and size buttons in the bottom bar
The bottom bar of every note window and every list window SHALL show two icon buttons at its trailing edge: a font button and a text size button, in that order, followed by the tint button as defined by the note-tint capability. In note windows, the bottom bar MUST also show the Bold, Italic, and Underline buttons at its leading edge; list windows MUST NOT show them. The buttons MUST use the same borderless icon style and size as the "−" and trash buttons in the drag area. Each button MUST work on the first click, also while another application is active. Clicking a button MUST open its control and MUST NOT move the window. Clicks on the buttons MUST reach the buttons, also when the note or list content is taller than the window. The menu window MUST NOT show these buttons.

#### Scenario: Buttons in a note window
- **WHEN** a note window is open
- **THEN** its bottom bar shows a font button, a text size button, and a tint button at the trailing edge
- **AND** the Bold, Italic, and Underline buttons at the leading edge

#### Scenario: Buttons in a list window
- **WHEN** a list window is open and its items are taller than the window
- **THEN** its bottom bar shows the font button, the text size button, and the tint button, and no style buttons
- **AND** clicking the font button or the text size button opens its control, not a list row

#### Scenario: No buttons in the menu
- **WHEN** the menu window is open
- **THEN** it shows no font button and no text size button

#### Scenario: Click while another app is active
- **WHEN** another application is active and the user clicks the font button of a note window
- **THEN** the font menu opens with that one click

### Requirement: Font menu
Clicking the font button SHALL open a menu at the button with two entries: "American Typewriter" and "System". The entry for the current font MUST show a check mark, and the other entry MUST NOT. Choosing an entry MUST make it the current font and close the menu. Choosing the current entry MUST change nothing. Pressing Esc or clicking outside the menu MUST close it without a change.

#### Scenario: Switch to the system font
- **WHEN** the current font is American Typewriter and the user chooses "System" from the font menu
- **THEN** note and list text show in the macOS system font
- **AND** the next time the font menu opens, "System" shows the check mark

#### Scenario: Dismiss the font menu
- **WHEN** the font menu is open and the user presses Esc
- **THEN** the menu closes and the font is unchanged

### Requirement: Text size popover
Clicking the text size button SHALL open a popover attached to the button. The popover MUST show a slider from 10 to 20 points in steps of 1, set to the current size, and MUST show the current size as a number of points. Moving the slider MUST change the text size while the user drags, and the shown number MUST follow. Clicking outside the popover or pressing Esc MUST close it and keep the size last set.

#### Scenario: Make text smaller
- **WHEN** the size is 15 points and the user drags the slider to 12
- **THEN** note and list text show at 12 points while the slider is at 12
- **AND** the popover shows "12 pt"

#### Scenario: Limits
- **WHEN** the user drags the slider fully to either end
- **THEN** the size stops at 10 points at the lower end and at 20 points at the upper end

#### Scenario: Close the popover
- **WHEN** the user set the size to 18 and then clicks outside the popover
- **THEN** the popover closes and the text stays at 18 points

### Requirement: Global text appearance setting
The app SHALL keep one font choice and one text size for all notes and lists. A change made from any window MUST apply at once to every open note window and every open list window, and to every note or list opened later. Changing the font or the size MUST NOT change any note's text, list title, list items, checked state, window position, or window size.

#### Scenario: Change applies to every window
- **WHEN** a note window and a list window are open and the user chooses "System" in the note window's font menu
- **THEN** the note text and the list's title and items both show in the system font

#### Scenario: Closed note opens with the setting
- **WHEN** the user sets the size to 18 and then opens a closed note from the menu
- **THEN** that note's text shows at 18 points

#### Scenario: Content unchanged
- **WHEN** the user changes the font or the size
- **THEN** every note keeps its text and every list keeps its title, items, and checked items

### Requirement: Text appearance persists
The font choice and the text size SHALL persist across app quit and relaunch without an explicit save action. With no saved setting, the font MUST be American Typewriter and the size MUST be 15 points. A saved size outside 10 to 20 points MUST be brought to the nearest of those limits, and an unknown saved font MUST be treated as American Typewriter. Notes and lists saved by earlier versions MUST open unchanged, using the setting.

#### Scenario: Relaunch keeps the setting
- **WHEN** the user chooses "System" and size 12, quits the app, and launches it again
- **THEN** every note and list shows its text in the system font at 12 points

#### Scenario: First launch of this version
- **WHEN** the app launches with notes saved by a version without the bottom bar
- **THEN** every note and list shows in American Typewriter at 15 points
- **AND** the font menu shows the check mark on "American Typewriter"

### Requirement: Menu rows follow the font
Rows in the menu window, "+ New", note rows, list rows, "+ New Note", and "+ New List" included, SHALL show in the current font choice. Menu rows MUST stay at 15 points whatever the text size setting is.

#### Scenario: Menu font follows the choice
- **WHEN** the user chooses "System" in the font menu
- **THEN** the menu window's rows show in the system font

#### Scenario: Menu size stays fixed
- **WHEN** the user sets the text size to 20 points
- **THEN** note text shows at 20 points
- **AND** the menu window's rows stay at 15 points

### Requirement: Buttons usable at minimum window size
At the minimum note window size, a note window SHALL show the Bold, Italic, Underline, font, text size, and tint buttons and the drag area's "−" and trash buttons fully inside the window, without overlap, and at least one full line of text at the largest text size. A list window at the minimum size MUST show the font, text size, and tint buttons, "−", and trash fully inside the window, and at least one full line of text at the largest text size.

#### Scenario: Smallest window, largest text
- **WHEN** a note window is at its minimum size and the text size is 20 points
- **THEN** the window shows Bold, Italic, Underline, the font button, the text size button, the tint button, "−", and trash, none of them overlapping
- **AND** at least one full line of note text shows

#### Scenario: Smallest list window
- **WHEN** a list window is at its minimum size and the text size is 20 points
- **THEN** the window shows the font button, the text size button, the tint button, "−", and trash
- **AND** at least one full line of list text shows
