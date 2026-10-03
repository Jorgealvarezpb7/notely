# Proposal

## Why

Every note and list window shows the same translucent macOS material, so on a busy screen the user cannot tell notes apart at a glance. A per-note color tint lets the user mark notes by color while the window keeps its translucent, native look.

## What Changes

- The bottom bar of every note window and every list window gets a tint button at its trailing edge, after the text size button. The button shows a filled circle in the note's tint, or a circle outline when the note has no tint.
- Clicking the tint button opens a menu: "Default", a set of color swatches, and "Other Colors…". "Other Colors…" opens the standard macOS color panel, so the user can choose any color. The color panel shows no opacity control.
- The chosen color shows as a faint wash over the window's translucent material, at one fixed strength. The material, its blur, and the desktop showing through stay as they are today. The tint never makes the window opaque.
- Notes and lists keep following the system light or dark appearance. A tint does not change text, bar, logo, or button colors. Whether a chosen color reads well is left to the user.
- Each note and list stores its own tint. Changing one window's tint changes no other window. Tints persist across relaunch. Notes with no tint, including all notes saved by earlier versions, look as they do today.
- The minimum window width grows from 160 to 190 points for note and list windows, so the note bottom bar fits six buttons. Notes saved narrower than 190 points open at 190 points wide.

## Capabilities

### New Capabilities

- `note-tint`: The tint button and its menu, choosing a custom color, how the tint shows over the translucent material, per-note storage and persistence, and the default look when no tint is set.

### Modified Capabilities

- `sticky-note`: "Panel stays movable" lists the tint button among the bottom bar controls of a note window.
- `text-appearance`: "Font and size buttons in the bottom bar" allows the tint button after the text size button; "Buttons usable at minimum window size" includes the tint button.
- `note-resize`: "Size limits" raises the minimum width from 160 to 190 points.

## Impact

- `Sources/Notely/main.swift`:
  - `Note` gains an optional `tint` field.
  - `NoteStore` gains a way to set a note's tint.
  - `BottomBar` gets the tint button, and `AppearanceControls`, or a sibling controller, opens the tint menu and drives `NSColorPanel`.
  - `NoteView` and `ListView` add the tint layer over `.ultraThinMaterial`.
  - `minimumNoteSize` changes to 190 by 120.
- Saved data: Each note gains an optional field. Earlier versions ignore this field, and notes saved by earlier versions decode with no tint.
- No new dependencies. AppKit `NSColorPanel` and `NSMenu` are already available on macOS 13.
