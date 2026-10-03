# Tasks

The project has no test target, so each task is checked with a build and a manual check on the host Mac.
- Build and run with `just run` on macOS. The recipes do not run in the Linux container.
- Before starting, back up the notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. Data model

- [x] 1.1 Add `tint: String?` to `Note`, the functions `tintString(_:)` and `tintColor(_:)`, and `NoteStore.setTint(_:for:)` (design.md Decision 1).
  - Verify `swift build -c release` succeeds.
  - Verify that the notes saved in the backup open unchanged (note-tint scenario "Notes from an earlier version").
- [x] 1.2 Add the `TintPreset` list with the seven name and hex pairs (design.md Decision 2).
  - Verify `swift build -c release` succeeds.

## 2. Tint layer

- [x] 2.1 Add `tintStrength = 0.2`. Replace `.background(.ultraThinMaterial)` in `NoteView` and `ListView` with the material plus the optional tint layer (design.md Decision 3).
  - Temporarily set a tint through `defaults write`, or by hard-coding it in a debug launch.
  - Verify note-tint scenarios "Background shows through a tint", "Black tint is not opaque", "Text color unchanged by a tint", and "Bars over a tint".
  - Verify both appearances, note windows and list windows.
  - Verify that a note with no tint matches the backup build pixel for pixel in a side-by-side screenshot.
- [x] 2.2 Tune `tintStrength` over a light desktop and over a dark desktop, using all seven presets.
  - Keep one value where every preset shows visibly and the desktop still shows through.
  - Record the final value in design.md Decision 3, if it changes.

## 3. Minimum size

- [x] 3.1 Change `minimumNoteSize` to 190 by 120 (design.md Decision 6).
  - Verify note-resize scenarios "Shrink below minimum", "Drag an edge past the minimum width", "Saved size below new minimum", and "Note saved at the old minimum".
  - Verify the same scenarios in a list window.

## 4. Tint button and menu

- [x] 4.1 Add the `tintColor` parameter to `StripButton`: `circle.fill` tinted when set, `circle` when nil (design.md Decision 4).
  - Pass `store` and `id` into `BottomBar` from `NoteView` and `ListView`.
  - Add the button last in the trailing group.
  - Verify note-tint scenarios "Button in a note window", "Button in a list window", "Button with no tint", and "No tint button in the menu window".
  - Verify sticky-note scenario "Bottom bar controls" and text-appearance scenarios "Smallest window, largest text" and "Smallest list window", at 190 points wide.
- [x] 4.2 Add `TintControls` with `showMenu(from:)`: "Default", the presets with circle images, "Other Colors…", and the check mark rule. Wire it to the tint button (design.md Decision 5).
  - Verify note-tint scenarios "Choose a preset color", "Back to default", "Dismiss the menu", "Button shows the tint", and "Click while another app is active".
  - Verify that dragging the bottom bar beside the button still moves the window.
- [x] 4.3 Verify per-note independence and persistence with presets.
  - Verify note-tint scenarios "Tint one of two notes", "Tint a list", "Content unchanged", "Relaunch keeps the tint", and "Reopen a closed note".

## 5. Custom color

- [x] 5.1 Add "Other Colors…" to `TintControls`: `showsAlpha = false`, start color, `setTarget` and `setAction`, and `panelChanged(_:)` saving through `tintString`. Also add the `panelOwner` cleanup in `deinit` (design.md Decision 5).
  - Verify note-tint scenarios "Pick any color", "No opacity control", "Panel changes one note", "Panel follows the last note", and "Custom color shows no check mark".
  - Verify that closing the color panel keeps the tint.
  - Verify that a color picked with the eyedropper from a translucent area is saved at full opacity: open the saved data with `defaults read com.alvarezjorge.Notely notes` and check that the tint is a `#RRGGBB` value.
- [x] 5.2 Close the color panel when its note's window closes: observe `NSWindow.willCloseNotification` for the owning window, and release and order out the panel (design.md Decision 5).
  - Verify note-tint scenarios "Close the note that owns the panel", "Delete the note that owns the panel", and "Close another note".
  - Reopen the closed note from the menu, choose "Other Colors…" again, and check that the panel changes that note.
- [x] 5.3 Close the color panel when the trash button is clicked, before the confirmation sheet shows (design.md Decision 5).
  - Verify note-tint scenario "Trash closes the panel", from the note that owns the panel and from another note.
  - Click "Cancel", then choose "Other Colors…" again, and check that the panel opens and changes the note.
  - Verify note-tint scenario "Unreadable saved tint" by writing `"tint":"oops"` into one note of the saved JSON. That note opens with no tint.

## 6. Integration

- [x] 6.1 Verify that the existing specs still pass for the touched areas:
  - sticky-note "End editing": clicking the bottom bar ends editing, including next to the tint button.
  - text-appearance: font menu and size popover.
  - text-styles: Bold, Italic, and Underline buttons.
  - The logo, which still hides at minimum width only when it would touch "−".
  - Run `openspec validate add-note-tint --strict` and confirm it reports no errors.
