# Spec Delta

## Purpose

Lets the user keep web addresses in notes and lists as links: shown as links, opened in the browser with Cmd+click, and previewed while Cmd is held over them.

## ADDED Requirements

### Requirement: Web addresses show as links
Every web address in note text, in a list's title, or in a list item SHALL show as a link: in the system link color and underlined, in the font, size, and styles the text has otherwise. A web address is text that starts with "http://" or "https://", or a domain name with a known top-level domain, such as "apple.com" or "www.apple.com/mac", with an optional path. Email addresses, phone numbers, and other kinds of addresses MUST NOT show as links. Links MUST update as the user types, pastes, cuts, undoes, or redoes, without moving the caret or the selection. Links MUST NOT change the saved text or styles, the undo history, or the text that Copy puts on the pasteboard. Link formatting in pasted rich text MUST NOT make text a link; only text that is itself a web address shows as a link. A checked list item MUST show its links struck through, in the link color.

#### Scenario: Type an address in a note
- **WHEN** the user types "see https://apple.com/mac today" in a note
- **THEN** "https://apple.com/mac" shows in the link color and underlined, and the other words show as before

#### Scenario: Address without a scheme
- **WHEN** a list item's text is "buy at store.example.com"
- **THEN** "store.example.com" shows as a link

#### Scenario: Not a web address
- **WHEN** a note contains "mail me at ana@example.com"
- **THEN** no part of the text shows as a link

#### Scenario: Address edited into plain text
- **WHEN** a note shows "https://apple.com" as a link and the user deletes "https://apple.co", leaving "m"
- **THEN** no part of the text shows as a link

#### Scenario: Styles kept
- **WHEN** a note's web address is bold and the font setting changes to the system font at 18 points
- **THEN** the address shows bold, in the system font at 18 points, in the link color and underlined

#### Scenario: Pasted link with other text
- **WHEN** the user pastes a link from a web page whose visible text is "Read more"
- **THEN** "Read more" shows as plain note text, not as a link

#### Scenario: Links are not saved
- **WHEN** a note shows a link and the app is quit and launched again
- **THEN** the note's saved text is the same characters with the same styles, and the address shows as a link again

### Requirement: Cmd+click opens a link
Clicking a link while holding Cmd SHALL open its address in the default web browser. An address without "http://" or "https://" MUST open with "http://" added. The click MUST NOT place the caret, select text, start editing a list row, or move the window. A click on a link without Cmd MUST behave as a click on any other text: it places the caret and edits. Cmd+click outside a link MUST behave as it does today. Cmd+click MUST work in notes and list rows whether or not they are being edited, and on the first click while Notely is not the active app.

#### Scenario: Open a link from a note
- **WHEN** the user holds Cmd and clicks "https://apple.com" in a note
- **THEN** the default browser opens https://apple.com
- **AND** the note's caret and selection do not change

#### Scenario: Open a link from a list item that is not being edited
- **WHEN** no list row has keyboard focus and the user holds Cmd and clicks a link in an item
- **THEN** the default browser opens the link
- **AND** the item does not start editing

#### Scenario: Plain click edits
- **WHEN** the user clicks a link in a note without holding Cmd
- **THEN** the caret moves to the clicked position in the link and no browser opens

#### Scenario: Address without a scheme opens
- **WHEN** the user Cmd+clicks "store.example.com"
- **THEN** the browser opens http://store.example.com

### Requirement: Pointer over a link
While Notely is the active app and the user holds Cmd with the pointer over a link, the pointer SHALL show as a pointing hand. Releasing Cmd or moving the pointer off the link MUST bring back the pointer that shows over text.

#### Scenario: Hold Cmd over a link
- **WHEN** the pointer rests on a link and the user presses Cmd
- **THEN** the pointer changes to a pointing hand

#### Scenario: Release Cmd
- **WHEN** the pointer shows a pointing hand over a link and the user releases Cmd
- **THEN** the pointer changes back to the text pointer

### Requirement: Link preview while Cmd is held
While Notely is the active app, the user holds Cmd, and the pointer rests on a link for half a second, Notely SHALL show a preview card next to the link. The card MUST show the linked page's title and site, and its image or icon when the page has one, in the standard macOS link preview style. Until the page information arrives, the card MUST show the address. When the page cannot be reached within 10 seconds, or the network is off, the card MUST show the address alone and no error message. The card MUST close when the user releases Cmd, moves the pointer off the link, opens the link, scrolls, types, or switches to another app. The card MUST NOT take keyboard focus. Notely MUST request a page only when its preview is about to show, never while the user only types or reads, and MUST reuse a page's preview for the rest of the session without requesting it again. Without Cmd held, resting the pointer on a link MUST NOT show a card.

#### Scenario: Preview a link
- **WHEN** the user holds Cmd and rests the pointer on "https://apple.com" in a note for half a second
- **THEN** a card shows next to the link with the page's title, "apple.com", and the page's image or icon

#### Scenario: Move away
- **WHEN** a preview card shows and the user moves the pointer off the link
- **THEN** the card closes

#### Scenario: Release Cmd
- **WHEN** a preview card shows and the user releases Cmd
- **THEN** the card closes

#### Scenario: Open from the preview state
- **WHEN** a preview card shows and the user clicks the link
- **THEN** the card closes and the browser opens the link

#### Scenario: No network
- **WHEN** the Mac has no network connection and the user holds Cmd over a link for half a second
- **THEN** a card shows the address alone

#### Scenario: Plain hover
- **WHEN** the user rests the pointer on a link for several seconds without holding Cmd
- **THEN** no card shows

#### Scenario: Preview again
- **WHEN** the user has previewed a link and later holds Cmd over the same address in any note or list
- **THEN** the card shows the same title and image at once, without requesting the page again

#### Scenario: Typing is not affected
- **WHEN** a note area has keyboard focus and a preview card shows
- **THEN** keystrokes still go to the note area, and typing closes the card
