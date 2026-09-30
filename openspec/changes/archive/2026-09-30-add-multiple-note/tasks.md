# Tasks

The project has no test target, so each task is verified with a command and a manual check on the host Mac. Build and run with `just run` on macOS; the recipes do not run in the dkc Linux container. Before starting, back up the current note with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. Note store and migration

- [x] 1.1 In `Sources/Notely/main.swift`, add the `Note` struct and `NoteStore` (load, save on every change, `text(for:)`/`setText(_:for:)`, `setOrigin(_:for:)`, `add(origin:)`, `remove(_:)`) per design.md Decision 1; verify `swift build -c release` succeeds
- [x] 1.2 Add the launch load rules from design.md Decision 3 (decode `notes`; empty or undecodable list gives one empty note; missing key migrates `noteText` and `panelOrigin` and then removes them); verify `swift build -c release` succeeds

## 2. One panel per note

- [x] 2.1 Change `NoteView` to take the store, a note id, `onAdd`, and `onRemove`, and bind the `TextEditor` and placeholder to that note's text in the store instead of `@AppStorage` (design.md Decision 2); verify `grep -n AppStorage Sources/Notely/main.swift` prints nothing and the build succeeds
- [x] 2.2 Replace `AppDelegate.panel` with `panels: [UUID: NotePanel]`, move panel setup into `makePanel(for:)`, open one panel per stored note at launch, and make `windowDidMove(_:)` save the origin of the moved panel's note (design.md Decisions 2 and 3); verify with `just run` that the existing note opens with its old text at its old position (spec "Upgrade from single note"), and that `defaults read com.alvarezjorge.Notely` shows `notes` and no longer shows `noteText` or `panelOrigin`
- [ ] 2.3 Quit and relaunch with `defaults delete com.alvarezjorge.Notely` run first; verify sticky-note scenarios "First launch" and "First launch position", then restore the backup with `defaults import com.alvarezjorge.Notely ~/notely-backup.plist`

## 3. "+" and "−" buttons, close button removed

- [x] 3.0 Delete `CloseButton` and its usage in `NoteView` (design.md Decision 4); verify `grep -n CloseButton Sources/Notely/main.swift` prints nothing and the build succeeds
- [x] 3.1 Add `StripButton` (borderless `NSButton` subclass with `acceptsFirstMouse` returning `true`, SF Symbols `plus` and `minus`, accessibility labels, sized from `StripButton.referenceSize`) and place "−" then "+" at the trailing edge of the drag strip over `DragHandle` (design.md Decision 4); verify multiple-notes scenarios "Drag area buttons" and "Click a panel button", and that dragging a part of the strip that is not a button still moves the panel
- [ ] 3.2 Extract `clamp(_:into:)` from `restoredOrigin` and make `restoredOrigin` call it (design.md Decision 5, step 2); verify sticky-note scenario "Saved position partly off-screen" still passes by editing the `origin` of a note in `defaults` to a partly off-screen point and relaunching
- [ ] 3.3 Implement `addNote(after:)` per design.md Decision 5 and wire it to "+"; verify multiple-notes scenarios "Click '+'", "Click '+' near a screen edge", and "Click '+' while another app is frontmost" (if the new note does not get keystrokes, apply the fallback in design.md Risk 1)
- [ ] 3.4 Implement `removeNote(_:)` per design.md Decision 6 and wire it to "−"; verify multiple-notes scenarios "Click '−' with two notes open", "Removed note stays removed", "Click '−' while another app is frontmost", "Click '−' on the only note", and "Launch after removing the last note"

## 4. Integration

- [ ] 4.1 With three notes open at different positions and with different text, verify multiple-notes scenarios "Type in one of two notes", "Move one of two notes", and "Relaunch with three notes", and sticky-note scenario "Switch Space" for all three panels
- [ ] 4.2 Verify app-controls scenarios "Cmd+Q while editing" from a second note and "Quit soon after typing" through the menu bar item and Cmd+Q with two notes open
- [ ] 4.3 Run `openspec validate add-multiple-note --strict`, then walk every scenario in the three delta specs on the final build from `just run`; verify all pass, including "Standard editing shortcuts" and "Press Esc while editing" in a note created with "+"
