# Proposal

## Why

When a list is taller than its window and the user scrolls it, the title and item rows draw over the drag area at the top of the window. The text covers the bar, the logo, and the "−" and trash buttons. Note windows do not have this problem, and the checklists spec already expects a list to scroll inside the window.

## What Changes

- Clip a list's scrolling content to the area between the drag area and the bottom bar, so no title or item text shows over either bar while the list scrolls.
- State this in the checklists spec, the same way sticky-note already requires note text to end above the bottom bar.
- No change to scrolling itself: overlay scroll bar, keyboard focus moves, and scrolling with the trackpad, mouse wheel, and caret stay as they are.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `checklists`: The "List items" requirement gains the rule that list content shows only between the drag area and the bottom bar, with scenarios for scrolling up and down in a long list.

## Impact

- `Sources/Notely/main.swift`: `AppDelegate.applyOverlayScroller(to:)`, which already finds each window's `NSScrollView`, also makes the scroll view clip its content. No change to `ListView`'s layout.
- No change to saved data, settings, or dependencies.
