# Tasks

The project has no test target and the behavior is UI-level, so each task is verified with `swift build` and a manual check against the named spec scenario (`just run` to launch).

## 1. Key-capable panel

- [ ] 1.1 Add `NotePanel: NSPanel` subclass in `Sources/FloatingWidget/main.swift` with `canBecomeKey` returning `true`, and use it in `AppDelegate` instead of `NSPanel`; verify `swift build -c release` succeeds and the panel still appears top-right on launch
- [ ] 1.2 Set `isMovableByWindowBackground = false` on the panel; verify with `swift build -c release` and confirm the panel still floats above other windows and shows on all Spaces (scenario "Switch Space")

## 2. Editable note view

- [ ] 2.1 Replace `WidgetView` with `NoteView`: a `TextEditor` bound to `@AppStorage("noteText")`, hidden scroll background, existing material background and 220x150 frame; remove greeting and clock; verify scenarios "Type into the note", "Long text", and "Greeting and clock removed"
- [ ] 2.2 Add placeholder `Text` overlay shown only when the note is empty, with hit testing disabled; verify scenario "First launch" (clear with `defaults delete FloatingWidget noteText` before launch)
- [ ] 2.3 Check that clicking the note while another app is frontmost gives the note keystrokes and keeps the other app active; verify scenario "Click note while another app is frontmost". If the caret or first click fails, replace `TextEditor` with an `NSTextView` wrapper per design.md Risks
- [ ] 2.4 Check Cmd+A/C/V/X/Z in the note; verify scenario "Standard editing shortcuts"

## 3. End editing with Esc

- [ ] 3.1 Override `cancelOperation(_:)` in `NotePanel` to call `makeFirstResponder(nil)`; verify scenario "Press Esc while editing" (caret disappears, text unchanged). If Esc does not reach the panel, use the `NSTextView` fallback from design.md

## 4. Drag area

- [ ] 4.1 Add a drag handle header strip (about 16 pt, grip indicator) above the `TextEditor`, backed by an `NSViewRepresentable` whose view calls `window?.performDrag(with:)` on `mouseDown`; verify scenarios "Drag the drag area" and "Drag inside text"

## 5. Persistence and integration

- [ ] 5.1 Type text, quit the app normally within one second, relaunch; verify scenarios "Relaunch keeps text" and "Save without explicit action"
- [ ] 5.2 Run `openspec validate add-note-editing --strict` and walk every scenario in `specs/sticky-note/spec.md` once more on the final build; verify all pass
