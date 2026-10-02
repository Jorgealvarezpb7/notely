# Tasks

The project has no test target, so each task is verified with a build and a manual check on the host Mac. Build and run with `just run` on macOS; the recipes do not run in the dkc Linux container. Before starting, back up the notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. Detection and display in notes

- [x] 1.1 Add `LinkDetector` (shared `NSDataDetector`, http/https only) (design.md Decision 1); verify `swift build -c release` succeeds
- [x] 1.2 Add the `LinkDisplay` helper that applies link color and underline as TextKit 2 rendering attributes (temporary attributes as fallback), and call it from `NoteTextView` after `load`, `applyAppearance`, `didChangeText`, and paste (design.md Decision 2); verify links scenarios "Type an address in a note", "Not a web address", "Address edited into plain text", and "Styles kept", and confirm with `grep -n "layoutManager" Sources/Notely/main.swift` that `NoteTextView` never reads `layoutManager`
- [x] 1.3 Verify saved data and editing are unchanged: links scenarios "Links are not saved" and "Pasted link with other text", sticky-note scenario "No other formatting", text-styles scenarios "Paste from a web page" and "Copy between notes", and that Cmd+Z after typing an address undoes only the typing

## 2. Detection and display in lists

- [x] 2.1 Add link color and underline to `ListField.styled` for detected ranges, after the strikethrough (design.md Decision 3); verify links scenario "Address without a scheme", checklists scenario "Address in a title", and that a checked item's link shows struck through in the link color
- [x] 2.2 Add `LinkFieldEditor` and `AppDelegate.windowWillReturnFieldEditor(_:to:)` returning it for `ListTextField` clients only (design.md Decision 3); verify that links show while a row is edited, and that Return, Backspace on an empty row, Up and Down, Esc, Cmd+Return, and typing with an input method (Option-e, e) still work in list rows

## 3. Cmd+click

- [x] 3.1 Add the `LinkHost` protocol and `link(at:)` for `NoteTextView` and `LinkFieldEditor` (design.md Decision 4), and Cmd+click handling in their `mouseDown` (design.md Decision 7); verify links scenarios "Open a link from a note", "Plain click edits", and "Address without a scheme opens", and that Cmd+click outside a link behaves as before
- [x] 3.2 Add `link(at:)` for a non-editing `ListTextField` with a throwaway TextKit 1 layout, Cmd+click in its `mouseDown`, and `acceptsFirstMouse` (design.md Decisions 4 and 7); verify links scenario "Open a link from a list item that is not being edited" with short and long wrapped items, and Cmd+click from another active app

## 4. Pointer and preview

- [x] 4.1 Add `LinkHoverController` with the local event monitor, `acceptsMouseMovedEvents` on note windows, and the pointing-hand cursor re-applied by the hosts (design.md Decision 5); verify links scenarios "Hold Cmd over a link" and "Release Cmd" (pointer) in a note, a list row being edited, and a list row not being edited
- [x] 4.2 Add `LinkPreviewStore` and the `NSPopover` with `LPLinkView` (design.md Decision 6), shown after 0.5 s by the controller; verify links scenarios "Preview a link", "Move away", "Release Cmd" (card), "Open from the preview state", "Plain hover", and "Typing is not affected", and that scrolling and switching apps close the card
- [x] 4.3 Verify the network behavior: links scenario "Preview again" (no second request, checked by turning Wi-Fi off after the first preview), "No network" with Wi-Fi off for a link never previewed, and that typing addresses without Cmd shows no card and makes no request

## 5. Integration

- [x] 5.1 Verify the existing specs still pass for the touched areas: sticky-note "Standard editing shortcuts" and "End editing" scenarios, text-styles bold/italic/underline toggles and persistence, checklists "Keyboard editing in lists" scenarios, and the top bar and bottom bar buttons; run `openspec validate add-links --strict` with no errors
