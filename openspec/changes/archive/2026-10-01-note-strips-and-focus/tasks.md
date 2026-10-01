# Tasks

The project has no test target. Verify each task with `swift build -c release` and a manual check on the host Mac. Build and run with `just run` on macOS, because the recipes do not run in the Linux container. Before you start, back up the current notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. End editing from the bars

- [x] 1.1 In `Sources/Notely/main.swift`, replace `DragHandle` with `EndEditingView(drags:)`. Its `mouseDown` calls `window?.makeFirstResponder(nil)` and then `performDrag(with:)` when `drags` is true (design.md Decision 1). Verify these sticky-note scenarios: "Click the drag area while editing", "Drag the window while editing", "Click the note area again", and "Drag the drag area". Verify that a click on "−" or trash still closes or deletes the note and does not start a drag.

## 2. Edge-to-edge bars

- [x] 2.1 Turn `NoteStrip` into a top bar of about 28pt:
  - Remove the grip `RoundedRectangle`.
  - Add the `Color.primary.opacity(0.08)` fill.
  - Keep "−" and trash 12pt from the trailing edge.
  - Add a bottom bar with the same shade, 80% of the top bar's height, with no buttons and `EndEditingView(drags: true)` behind it.

  See design.md Decision 3. Verify that the build succeeds.
- [x] 2.2 Lay out `NoteView` with both bars as edge overlays (`.overlay(alignment: .top)` and `.overlay(alignment: .bottom)`). Pad the `TextEditor` 12pt horizontally and by the bar height vertically (design.md Decision 2). Verify these sticky-note scenarios: "Drag the bottom bar", "Click the bottom bar while editing", "Bars in light appearance", "Bars in dark appearance" (switch appearance in System Settings while the app runs), "No grip mark", and "Long note above the bottom bar". Check that the bottom bar follows the rounded window corners, and that "Idle long note" and "Scroll a long note" still pass.
- [x] 2.3 Apply the same layout to `ListView`: keep the top overlay, add the bottom overlay, and pad the `ScrollView` by both bar heights. Verify that the list window shows both bars and that "−" and trash still get clicks. Verify that checklists scenarios "List window controls" and "Long list" still pass.

## 3. Empty list space ends editing

- [x] 3.1 In `ListView`, wrap the `ScrollView` in a `GeometryReader`. Give the rows' `VStack` `.frame(minHeight: visibleHeight, alignment: .top)` and an `EndEditingView(drags: false)` background (design.md Decision 4). Verify these checklists scenarios: "Click below the rows", "Click below the rows with an empty item", and "Click the drag area in a list". Verify that clicks on rows and circles still work ("Check an item", "Add the first item").

## 4. Size limits

- [x] 4.1 Change `minimumNoteSize` to 110x120 and update its comment. Make `windowWillResize` floor the size at the `minimumNoteSize` constant (design.md Decision 6). Verify these note-resize scenarios: "Shrink below minimum", "Drag an edge past the minimum width", and "Controls stay visible at minimum size". Verify "Saved size below new minimum": edit a saved size to `{60, 100}` with `defaults`, relaunch, and confirm the window opens at 110 by 120.
- [x] 4.2 Reproduce the lost buttons. In a list window, add a title and an item longer than the window, then shrink the window to 110pt wide. Write down which view overflows. Fix it as design.md Decision 5 describes: limit the width of the bar and content, and make `ListField` wrap within its width. Verify the note-resize scenario "Long list item at minimum width". Verify the same check with a long title and with a text note that has a long word.

## 5. Integration

- [x] 5.1 Run through these scenarios on the backed-up data, in both appearances:
  - The full `note-resize` spec.
  - The "End editing" and "Panel stays movable" requirements from the `sticky-note` spec.
  - The `checklists` requirement "List windows behave like note windows".

  Verify that every note and list opens with its text unchanged. Verify that the menu window looks the same as before.
