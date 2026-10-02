# Tasks

The project has no test target and builds only on macOS (AppKit). Every task is verified with `swift build` on a Mac plus the stated check in the running app (`swift run Notely`).

## 1. Style data model

- [x] 1.1 Add `StyleRun` (UTF-16 `location`, `length`, optional `bold`/`italic`/`underline`) and optional `styles: [StyleRun]?` to `Note`, with a doc comment on compatibility like the other optional fields; verify `swift build` passes and an app launch with existing saved notes shows every note's text unchanged
- [x] 1.2 Add `NoteStore.setText(_:styles:for:)` that saves text and runs in one `save()`, and a load-time clamp that trims runs to the text length and drops runs outside it; verify by writing a note JSON with an out-of-range run via `defaults write`, launching, and seeing the note open with its text and no crash

## 2. Rich note editor (no styles yet)

- [x] 2.1 Add `NoteTextView: NSTextView` and `NoteEditor: NSViewRepresentable` (scroll view + text view, rich text on, font panel and graphics off, undo on, transparent background, `.textColor`), and replace `TextEditor` in `NoteView`; verify typing, Cmd+A/C/V/X/Z, and long-text scrolling work in a note
- [x] 2.2 Match `TextEditor` insets and substitutions (`lineFragmentPadding`, `textContainerInset`, smart quotes/dashes as before); verify by comparing a note's text position and typed quotes before and after the swap with the same note
- [x] 2.3 Draw the "Type a note…" placeholder in `NoteTextView.draw(_:)` at the first glyph position, in the note font and `.textColor`, and remove the SwiftUI placeholder overlay; verify the caret sits at the placeholder's start at 10, 15, and 20 points in both fonts
- [x] 2.4 Override `cancelOperation(_:)` to end editing and `acceptsFirstMouse` to return `true`; verify Esc removes the caret and keeps text, and one click in a note of an inactive app places the caret
- [x] 2.5 Wire `textDidChange` to `NoteStore.setText(_:styles:for:)` and apply font and size from `TextAppearance` in `updateNSView`; verify text survives quit within one second of the last keystroke, and font/size changes apply at once to open notes
- [x] 2.6 Regression pass on the editor swap: run every scenario of the sticky-note spec (end editing from bars, drag while editing, overlay scroller with "Always" setting, scroll with caret, focus on "+ New Note", reopened note) and of the text-appearance spec; verify each scenario passes

## 3. Style rendering and toggling

- [x] 3.1 Add `.notelyBold` / `.notelyItalic` keys, `TextStyle`, and `renderAttributes(bold:italic:appearance:)` with real italic face when the font has it, else `.obliqueness = 0.2`; add `restyle(range:)` and restyle on family/size change only; verify with a note restored from runs: bold, italic, and bold italic show correctly in American Typewriter (slanted) and System (italic face)
- [x] 3.2 Load runs into the text storage when the editor is created, and build runs from the storage on every save; verify a bold word stays bold and in place after typing text before it, quitting, and relaunching
- [x] 3.3 Implement `toggle(_:)` for selections (all-have-trait removes, else applies) through `shouldChangeText`/`didChangeText`, and for an empty selection via typing traits that reset when the caret moves; verify every scenario of "Toggle a style on selected text" and "Toggle a style for new typing", and that Cmd+Z undoes a toggle
- [x] 3.4 Verify font and size switches keep styles: a note with bold, italic, and underlined words keeps all three after choosing "System", then 18 points, then "American Typewriter"

## 4. Bottom bar buttons and button state

- [x] 4.1 Add `NoteEditorState` (active styles, weak text view) per note window; update it from selection changes, toggles, and focus changes; verify with a breakpoint or log that the set follows caret moves and empties on Esc
- [x] 4.2 Add optional `isOn` to `StripButton`: when set, keep the borderless look, tint the symbol `.secondaryLabelColor` while off and `.labelColor` while on, no background or hover effect, and set `refusesFirstResponder`; verify the font and size buttons look unchanged, and an on style button shows a white symbol in dark appearance and a black one in light appearance
- [x] 4.3 Give `BottomBar` an optional editor state and show `bold`, `italic`, `underline` buttons at the leading edge only when it is set; pass it from `NoteView`, `nil` from `ListView`; verify note windows show B/I/U, list windows and the menu do not, and clicking B keeps focus and selection
- [x] 4.4 Verify the "Style button state" scenarios: caret in bold text lights B only, a partly underlined selection leaves U off, Esc turns all off

## 5. Shortcuts and Format menu

- [x] 5.1 Add a "Format" menu to `makeMainMenu()` with target-less Bold (Cmd+B), Italic (Cmd+I), Underline (Cmd+U) items calling the `NoteTextView` toggle selectors, and `validateMenuItem` setting check marks; verify shortcuts toggle styles in notes, do nothing in a focused list item, and the items are disabled with no note focused

## 6. Paste and copy

- [x] 6.1 Override `writeSelection(to:types:)` to add a private styled-text type (text + runs) next to RTF and plain text; verify copying an italic word in American Typewriter and pasting it into another note keeps it italic
- [x] 6.2 Override `readSelection(from:type:)` to read the private type, else RTF/HTML mapped to traits only, else plain text with typing traits, through `shouldChangeText`/`didChangeText`; verify pasting a red, large, bold link from Safari gives bold text in the note font, size, and color with no link, and Cmd+Z undoes the paste

## 7. Minimum window width

- [x] 7.1 Change `minimumNoteSize` to 160 x 120 and update its doc comment; set bar spacing so all five buttons fit; verify a note and a list at minimum size at 20 points show every bar button without overlap and one full line of text, and a note saved at 110 x 150 opens at 160 x 150

## 8. Integration check

- [x] 8.1 Run every scenario of `specs/text-styles/spec.md` and the `text-appearance`, `sticky-note`, and `note-resize` deltas in the running app, in light and dark appearance; verify each passes and `openspec validate add-text-styles --strict` succeeds
