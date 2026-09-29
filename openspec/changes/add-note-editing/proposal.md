# Proposal

## Why

The floating widget only shows static text and a clock. It cannot hold anything the user writes. Turning it into an editable sticky note makes the always-on-top panel useful for quick notes. The notes stay visible across Spaces without switching apps.

## What Changes

- Replace the widget's "Hello from Swift" text and clock with a single editable note text area.
- Let the floating panel accept keyboard focus so the user can type in it, without activating the app or taking focus from the frontmost app.
- Persist the note text so it survives app quit and relaunch.
- Keep the panel draggable through a dedicated drag area, because dragging inside the text area now selects text.
- Let the user end editing (Esc) so the text area gives up keyboard focus.
- **BREAKING** (user-visible): The clock and greeting text are removed from the widget.

Out of scope: multiple notes, a menu bar item, rich text, note sync or export, and resizing the panel.

## Capabilities

### New Capabilities
- `sticky-note`: A single floating note that the user can type into and that keeps its text across relaunches.

### Modified Capabilities
<!-- None: the project has no existing specs. -->

## Impact

- Code: `Sources/FloatingWidget/main.swift`. `WidgetView` is replaced by a note view, and `NSPanel` becomes a subclass that can become key.
- Storage: new `UserDefaults` key for the note text (app's standard defaults domain).
- Dependencies: none added. Uses AppKit and SwiftUI only. Target stays macOS 13.
