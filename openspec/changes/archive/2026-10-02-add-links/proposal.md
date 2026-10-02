# Proposal

## Why

Notes and lists often hold web addresses, but today they are plain text: to visit one, the user has to select it, copy it, and paste it into a browser. Making web addresses clickable, with a preview of the page before leaving Notely, makes notes useful as a place to keep links.

## What Changes

- Web addresses typed or pasted into note text, list titles, and list items show as links: in the system link color and underlined. Links are found from the text as the user types; nothing new is saved.
- Cmd+click on a link opens it in the default web browser. A plain click still places the caret and edits, as today.
- While the user holds Cmd with the pointer on a link, the pointer becomes a pointing hand and, after a short pause, a preview card shows next to the link: the page's title, site name, and image or icon, as macOS shows link previews in Messages and Notes. The card closes when Cmd is released, the pointer leaves the link, or the link is opened.
- A page is fetched only when its preview is asked for, and each preview is kept for the rest of the session. Without a network connection, the card shows the address alone.
- Link formatting from pasted rich text is still dropped. Only addresses written in the text itself show as links.

## Capabilities

### New Capabilities

- `links`: Finding web addresses in note and list text, showing them as links, opening them with Cmd+click, and showing a page preview while Cmd is held over a link.

### Modified Capabilities

- `sticky-note`: "Editable note text" allows web addresses to show as links, and its "No other formatting" scenario now covers pasted links whose text is not a web address.
- `checklists`: "List title" allows web addresses in list text to show in the link color instead of white or black.

## Impact

- `Sources/Notely/main.swift`: `NoteTextView` gains link display, Cmd+click, and hover handling; list rows get the same through `ListField.styled`, `ListTextField`, and a custom field editor for list windows (`AppDelegate` becomes the source of field editors for note windows); new shared link detection and preview code.
- New system framework: LinkPresentation (macOS 10.15+, within the macOS 13 minimum). No third-party dependencies.
- Network: Notely makes outgoing requests to the linked site when the user asks for a preview. The app is not sandboxed, so no entitlement is needed.
- No change to saved data: links are found from the text each time it shows.
