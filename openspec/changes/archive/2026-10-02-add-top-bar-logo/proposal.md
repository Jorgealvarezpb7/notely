# Proposal

## Why

The drag area at the top of every note and list window shows only a shaded fill and the "−" and trash buttons. Showing the Notely logo at its center gives the windows a small branded detail without adding a control.

## What Changes

- Show the Notely logo (`Packaging/notely-logo.svg`: an "N" between two pairs of quote marks) centered in the drag area of every note window and every list window.
- Color the logo to match the drag area's shaded fill: a translucent black in light appearance and a translucent white in dark appearance. The logo is quieter than the "−" and trash buttons.
- The logo is decoration only. Clicking or dragging on it works like the rest of the drag area: it ends editing and moves the window.
- Hide the logo when the window is too narrow for it to fit between the leading edge and the "−" button, so it never overlaps the buttons.
- Replace the "no grip mark" rule, which said the drag area shows only the buttons and the fill, so it allows the logo. The drag area still shows no grip mark and no other buttons.
- The menu window does not change. It has no drag area.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `sticky-note`: The "Panel stays movable" requirement changes so the drag area may show the logo as well as the buttons and fill. A new requirement covers the logo's position, colors, click-through behavior, and hiding in narrow windows, for note and list windows.

## Impact

- `Sources/Notely/main.swift`: `NoteStrip` gains a centered logo view. A new `Shape` holds the logo's outline, taken from the SVG path, so no SVG loading or bundle resource is needed (macOS 13 is the minimum).
- `Packaging/notely-logo.svg` stays as the source artwork. It is committed but not copied into the app bundle.
- No change to saved data, settings, or dependencies.
