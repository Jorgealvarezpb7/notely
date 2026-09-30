# Proposal

## Why

Notely runs as a hidden accessory app. Its notes float above every window, it has no Dock icon and no app icon, and each note is stuck at 220x150 points. The user wants Notely to behave like a native Mac app: notes that can be resized, that stack with other windows normally, and an app that lives in the Dock with its own icon.

## What Changes

- Every note window can be resized by dragging its edges and corners, within a minimum size and the screen's visible area. Each note's size is saved and restored with its position.
- A new note created with "+" opens at the same size as the note whose "+" was clicked.
- **BREAKING**: Notes become normal windows. They no longer stay above other apps' windows, and they no longer show on every Space.
- **BREAKING**: Notely becomes a regular app. It shows a Dock icon and becomes the active app when the user clicks a note, so the menu bar shows Notely's own menus.
- **BREAKING**: The menu bar status item is removed. Quit stays available from the app menu, the Dock menu, and Cmd+Q.
- Clicking the Dock icon brings all note windows to the front.
- The app gets an icon, built from the supplied 1024x1024 artwork, shown in the Dock, Finder, and the app switcher.
- Saved notes from the previous version open at the old default size, 220x150 points.

## Capabilities

### New Capabilities
- `note-resize`: resizing a note window, its size limits, size persistence, and the size of new notes.

### Modified Capabilities
- `sticky-note`: remove "Editing does not steal app focus"; replace "Floating panel behavior preserved" with normal window layering; the long-text scenario refers to the note window's current size, not a fixed size.
- `app-controls`: remove the "Menu bar item" requirement; add a Dock icon and an app icon; "Quitting keeps note text" names the app menu and Dock menu as quit paths in place of the menu bar item.
- `multiple-notes`: "Create a note from a panel" no longer requires another app to stay active; "Removing the last note quits the app" no longer mentions the menu bar item.

## Impact

- `Sources/Notely/main.swift`: `NSPanel` replaced with a titled, resizable `NSWindow` with a hidden title bar; regular activation policy; normal window level; status item removed; `Note` gains an optional saved size; fixed-size constants replaced with per-note sizes.
- `Packaging/Info.plist`: `LSUIElement` removed; `CFBundleIconFile` added.
- `justfile`: `build` generates `AppIcon.icns` with `sips` and `iconutil` and copies it into `Contents/Resources`.
- `notely-icon-1024 (1).png` moves to `Packaging/AppIcon.png`.
- Saved data in `UserDefaults` stays compatible: the new size field is optional.
