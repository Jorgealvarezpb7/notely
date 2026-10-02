# Design

## Context

- The app targets macOS 13 (`Package.swift`). `NoteView` edits note text with SwiftUI `TextEditor` bound to a plain `String`. On macOS 13, `TextEditor` cannot show or edit attributed text, so per-range styles need an AppKit `NSTextView`.
- List windows already wrap AppKit (`ListField` / `ListTextField`), so the `NSViewRepresentable` pattern exists in the code base.
- Note behavior that depends on the editor being an `NSTextView` inside an `NSScrollView`:
  - `NoteWindow.cancelOperation` ends editing on Esc.
  - `EndEditingView` ends editing on a click in either bar.
  - `AppDelegate.applyOverlayScroller` finds the first `NSScrollView` in the window.
  - `addFromMenu` focuses `contentView?.firstTextView` for a new note.
- `Note.text` is saved as JSON in `UserDefaults` on every change. `Note` already has optional fields so older and newer builds can read each other's data.
- Font family and size are global (`TextAppearance`). Styles must survive a family switch, so they cannot be stored as font names.
- `minimumNoteSize` (110 x 120) is shared by note and list windows and enforced in `windowWillResize` and at open.
- Requirements: see `specs/text-styles/spec.md` and the deltas for `text-appearance`, `sticky-note`, and `note-resize`.

## Goals / Non-Goals

**Goals:**
- One source of truth for styles: three traits per character (bold, italic, underline), independent of font.
- Keep every existing note behavior (Esc, bar clicks, placeholder alignment, overlay scroller, first-mouse, focus on new note) after the editor swap.
- Saved data stays readable by builds without this change.

**Non-Goals:**
- Styles in list windows.
- Any other formatting: colors, links, headings, lists in notes, the system Font panel.
- Styles in the menu window's note rows. Rows keep showing plain text.

## Decisions

### D1. Replace `TextEditor` with an `NSTextView` subclass in an `NSViewRepresentable`
New `NoteTextView` (subclass of `NSTextView`), hosted by `NoteEditor: NSViewRepresentable`, which returns an `NSScrollView` with the text view as document view.

Settings: `isRichText = true`, `importsGraphics = false`, `usesFontPanel = false`, `allowsUndo = true`, `drawsBackground = false`, `textColor = .textColor`, smart quotes and dashes as the current `TextEditor` has them (default off for `NSTextView`, verify against current behavior).

The scroll view is an ordinary `NSScrollView`, so `applyOverlayScroller` and `firstTextView` keep working without change.

*Alternatives:* `TextEditor` with `AttributedString` needs macOS 26. Rejected because it would raise the deployment target. Markdown markers in plain text (`**bold**`) look wrong in a note that shows formatted text. Rejected.

### D2. Styles as custom trait attributes; fonts derived when rendering
The text storage carries three attributes per range:
- `.notelyBold: Bool`, `.notelyItalic: Bool` (custom `NSAttributedString.Key`).
- `.underlineStyle` (standard, `.single`).

A pure function `renderAttributes(bold:italic:appearance:) -> [Key: Any]` gives the font, `.obliqueness`, and foreground color. `NoteTextView.restyle()` walks the storage and sets those display attributes from the traits. It runs:
- after every trait change,
- after paste,
- when `TextAppearance.family` or `.size` changes (`updateNSView` compares to the last rendered family/size and restyles only on change).

`typingAttributes` is computed the same way from the typing traits.

Font selection:
- Bold: `AmericanTypewriter-Bold` for typewriter; `NSFont.systemFont(ofSize:weight: .bold)` for system. This matches `TextAppearance.nsFont(bold:)`, which is reused.
- Italic: ask `NSFontDescriptor.withSymbolicTraits(.italic)` of the chosen font. If the resulting font does not report the italic trait, keep the upright font and set `.obliqueness = 0.2`. This covers American Typewriter without naming it, and gives the system font its real italic face.

*Alternative:* `NSFontManager.convert(_:toHaveTrait:)` with fonts stored in the storage. Rejected: a family switch must then remap every font by name, and the conversion fails silently for American Typewriter italic.

### D3. Persist styles as runs next to plain text
New optional field on `Note`:

```swift
struct StyleRun: Codable, Equatable {
    var location: Int   // UTF-16 offset, as NSString / NSRange
    var length: Int
    var bold: Bool?
    var italic: Bool?
    var underline: Bool?
}
var styles: [StyleRun]?
```

- Only runs with at least one trait are saved. `nil` or empty means no styles.
- `NoteStore.setText(_:styles:for:)` saves text and runs in one `save()`, called from `textDidChange` (which also fires for trait-only changes, see D5).
- On load, runs are clamped to the text length; a run fully outside the text is dropped. This protects against bad data without failing the decode.
- Older builds decode `Note` without `styles` and ignore it. If an older build edits and saves, it re-encodes notes without the field, so styles are lost but never misplaced. This is acceptable.

*Alternative:* RTF `Data`. Rejected: RTF stores font names and sizes, which conflict with the global font setting, and makes the plain-text fallback a second copy anyway.

### D4. Per-window editor state shared between text view and bottom bar
`NoteEditorState: ObservableObject` per note window:
- `@Published var active: Set<TextStyle>` (`.bold`, `.italic`, `.underline`), empty while the text view is not first responder.
- `weak var textView: NoteTextView?`.

`NoteView` creates it as `@StateObject` and passes it to `NoteEditor` and `BottomBar`. The text view updates `active` in `textViewDidChangeSelection`, after each toggle, and in `becomeFirstResponder` / `resignFirstResponder`.

`BottomBar` gets an optional `editorState`; when present (note windows only) it shows `[B] [I] [U]` at the leading edge. List windows pass `nil`, so their bar does not change.

Button state is shown by symbol color only, with no background in any state and no hover effect: style buttons are borderless `NSButton`s like the other bar buttons, with `contentTintColor = .secondaryLabelColor` (gray) while off and `.labelColor` (white in dark appearance, black in light) while on. `StripButton` gains an optional `isOn: Bool?`; `nil` keeps today's plain borderless button for "−", trash, font, and size. Symbols: `bold`, `italic`, `underline`.
*Alternatives:* AppKit's recessed bezel with its on-state fill, and accent-tinted symbol on hover. Both tried and rejected by the user: the backgrounds looked wrong next to the plain bar buttons. `NSSegmentedControl` in `.selectAny` mode, as in TextEdit's format bar. Rejected: it draws a bordered control and is wider than three separate icons at the 160-point minimum.
*Alternatives:* accent-colored symbol tint. Rejected: macOS does not use tint for on/off formatting state. `NSSegmentedControl` in `.selectAny` mode, as in TextEdit's format bar. Rejected: it draws a bordered control, unlike the other bar buttons, and is wider than three separate icons at the 160-point minimum.

### D5. Toggling: one code path for buttons, shortcuts, and menu
`NoteTextView` exposes `@objc toggleNoteBold(_:)`, `toggleNoteItalic(_:)`, `toggleNoteUnderline(_:)`, all calling `toggle(_ style: TextStyle)`:
- Selection non-empty: if every character in the selection has the trait, remove it; else set it. The change goes through `shouldChangeText(in:replacementString: nil)` → edit `textStorage` → `restyle` range → `didChangeText()`. This registers undo and fires `textDidChange`, so the store saves.
- Selection empty: flip the trait in `typingTraits` and recompute `typingAttributes`. AppKit resets `typingAttributes` from the text before the caret when the selection moves, which gives the "caret moves" behavior; `typingTraits` is re-read from those attributes in `textViewDidChangeSelection`.

Buttons call `editorState.textView?.toggle(...)`. Style `StripButton`s set `refusesFirstResponder = true`, so a click keeps the text view's focus and selection. They sit above `EndEditingView` in the `ZStack`, so bar clicks outside them still end editing.

Format menu: new `Format` menu in `makeMainMenu()` with target-less items using these selectors and key equivalents `b`, `i`, `u`. Only `NoteTextView` implements them, so the items are disabled when no note text view is first responder, and the shortcuts do nothing in lists (`ListTextField`'s field editor does not respond). `NoteTextView.validateMenuItem` sets the check mark from `active`.

### D6. Paste and drop keep only traits
Override `readSelection(from:type:)` in `NoteTextView` (covers paste and drag-and-drop):
1. Prefer a private pasteboard type `com.notely.styled-text` (JSON: text + runs), written by `writeSelection(to:types:)` on copy and cut. This keeps synthetic italic exact when copying between notes, where RTF would only see the upright font.
2. Else read RTF/RTFD/HTML as `NSAttributedString` and map each run: bold/italic from the font's symbolic traits (italic also when `.obliqueness > 0`), underline when `.underlineStyle != 0`. Drop all other attributes.
3. Else plain string, inserted with the current typing traits.

The result is inserted via `shouldChangeText` / `replaceCharacters` / `didChangeText` and restyled, so undo and saving work. Copy still writes standard RTF and plain text too, for other apps.

### D7. Keep existing note behaviors in the new editor
- **Esc**: `NSTextView` handles `cancelOperation:` itself (completion), so it never reaches `NoteWindow`. `NoteTextView.cancelOperation` calls `window?.makeFirstResponder(nil)`.
- **Placeholder**: drawn by `NoteTextView.draw(_:)` when the string is empty, at `textContainerOrigin` plus `lineFragmentPadding`, in the typing font and `.textColor`. It lines up with the caret at every font and size by construction. This replaces the SwiftUI overlay and its padding tweaks (the uncommitted `.padding(.top, 8)` edit in `NoteView` becomes moot).
- **Text insets**: match today's `TextEditor` (`textContainerInset` 0, `lineFragmentPadding` 5) so text does not shift.
- **First mouse**: `NoteTextView.acceptsFirstMouse` returns `true`, as `TextEditor` effectively did.
- **Focus on a new note**: unchanged, `firstTextView` finds `NoteTextView`.

### D8. Minimum width 160
`minimumNoteSize.width` becomes 160 (height stays 120). Lists share it, which keeps one size rule for all windows (checklists spec: same size limits as notes). Existing narrower frames are already raised to the minimum at open by the current clamp. Bar layout: `HStack(spacing: 16)` with B/I/U, `Spacer(minLength: 8)`, then font and size, 12 pt side padding. At 160 points this gives roughly 5 x 14 + 3 x 16 + 8 + 24 = 150 points, inside the limit. The real button width comes from `StripButton.referenceSize`; check it in the running app and tighten spacing inside the B/I/U group to 12 if needed.

## Risks / Trade-offs

- [The `NSTextView` swap breaks a subtle `TextEditor` behavior: insets, smart substitutions, scroll-to-caret, overlay scroller] → Task list has an explicit regression pass over every sticky-note and text-appearance scenario; keep `firstTextView` and `applyOverlayScroller` paths unchanged.
- [UTF-16 offsets in runs drift if text changes outside the editor] → Only the editor writes text for notes; runs are rebuilt from storage on every save, never patched. Load clamps runs.
- [Synthetic italic looks cruder than a real italic face] → Accepted (user choice). Slant is one constant, easy to tune.
- [Full restyle on every font or size change is O(text length) per note] → Notes are short; restyle only on actual family/size change, not on every SwiftUI update.
- [An older build saving notes drops all styles] → Text is never lost. Accepted; noted in proposal.
- [Saving on every keystroke now encodes runs too] → Runs are few and small; same `UserDefaults` timing as today.
- [Raising the minimum width enlarges existing narrow windows of users] → Spec scenario covers it; the existing clamp at open handles it.
- [Gray vs. label color is a subtle on/off cue, especially in light appearance] → Accepted (user choice); check both appearances in task 4.2.

## Migration Plan

- No data migration: `styles` is optional and absent in existing data.
- Rollback: an older build reads all notes. Styles are ignored and dropped on its next save.
