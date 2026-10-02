# Design

## Context

The drag area is `NoteStrip` in `Sources/Notely/main.swift`. It is a `ZStack` of `EndEditingView(drags: true)` (an NSView that ends editing and calls `performDrag`) and a trailing `HStack` with the "−" and trash `StripButton`s. Both note windows (`NoteView`) and list windows (`ListView`) use it as a top overlay, so one change to `NoteStrip` covers both window types. The menu window does not use `NoteStrip`.

Measurements that shape the layout:

- `barHeight` = `max(16, StripButton.referenceSize.height) + 12`, about 28 pt.
- The trailing cluster takes `12` (padding) + button width + `16` (gap) + button width from the right edge. With the standard 14 pt button width that is about 56 pt.
- `minimumNoteSize.width` is 110 pt, so at minimum width the center is at 55 pt and the "−" button starts at about 54 pt.
- `barFill` is `Color.primary.opacity(0.08)` over `.ultraThinMaterial`.

The artwork `Packaging/notely-logo.svg` has a `viewBox` of `0 0 837 465` (about 1.8:1). Its single `path` uses only absolute `M` commands followed by implicit straight-line point lists and `Z`, with `fill-rule="evenodd"`. It has no curves and no other commands. The package targets macOS 13, and `Packaging/` is not copied into the app bundle.

## Goals / Non-Goals

**Goals:**
- One logo view, drawn by SwiftUI, used by both window types through `NoteStrip`.
- No new resources, build steps, or dependencies.

**Non-Goals:**
- A general SVG renderer. The parser handles only the commands this file uses.
- Making the logo clickable or adding a tooltip or accessibility element for it.
- Changing the app icon or the menu window.

## Decisions

### 1. Draw the logo as a SwiftUI `Shape` built from the SVG path data

Copy the path's `d` string into `main.swift` as a constant. A `NotelyLogo: Shape` parses it once (a `static let` of points per subpath, in viewBox units). `path(in:)` scales the subpaths uniformly by `rect.width / 837` and offsets them to the rect's origin. The view fills the shape with `FillStyle(eoFill: true)` to match `fill-rule="evenodd"`, and gets a fixed frame whose width is its height times 837 / 465, so the proportions are kept.

The parser splits on whitespace. `M` starts a subpath, each `x,y` token adds a point (the first one is the move, the rest are lines), and `Z` closes the subpath. Any other token is ignored. SVG and SwiftUI both use a top-left origin with y pointing down, so no flip is needed.

Alternatives considered:
- `NSImage` from SVG data: native SVG support in `NSImage` is not reliable on macOS 13, and it would need the file in the bundle (a `justfile` change).
- Converting the SVG to a PDF or an asset catalog: this adds a build step and resource handling to a SwiftPM executable that has none today.
- Pre-converting the points into a Swift array literal: this works, but it is much longer than the `d` string and harder to update when the artwork changes. Parsing the existing string keeps the source next to its origin.

### 2. Size: 12 pt tall, about 22 pt wide, centered

Make the logo 12 pt tall in the 28 pt bar. That leaves about 8 pt above and below, similar to the margin around the buttons. The width follows the aspect ratio (about 21.6 pt). Place it as a centered layer of the `ZStack`, between `EndEditingView` and the buttons, so its position does not depend on the button cluster.

### 3. Color: one dynamic `NSColor`, the same pattern as `checkFill`

```swift
let logoFill = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor.white.withAlphaComponent(0.30)
        : NSColor.black.withAlphaComponent(0.25)
})
```

`barFill` uses black in light appearance and white in dark appearance, so a stronger tint of the same color reads as an embossed mark on the bar. Template button images draw in a label color near full opacity, so the logo stays clearly quieter than the controls. Dark appearance gets a slightly higher alpha because white on a dark material looks weaker at the same alpha. A dynamic `NSColor` updates at once when the appearance changes.

Alternative considered: `Color.primary.opacity(...)`, as `barFill` uses. This is a single alpha for both appearances, and the user asked for a separate color for each. `.tertiary` is close too, but it is tied to the system's label alphas and cannot be tuned.

### 4. Click-through

Apply `.allowsHitTesting(false)` to the logo. Clicks and drags fall through to `EndEditingView`, which already ends editing and drags the window. This keeps the spec's "not a control" behavior with no new event code.

### 5. Hide the logo in narrow windows

Read the bar's width with a `GeometryReader` around the logo layer only, and show the logo when

```
width >= 2 * (trailingCluster + gap) + logoWidth
```

where `trailingCluster = 12 + 2 * StripButton.referenceSize.width + 16` and `gap = 8`. With the standard button size this is about 150 pt. Derive the threshold from the same constants the `HStack` uses, so it stays right if the buttons change.

Alternatives considered:
- Centering the logo in the space left of the buttons. This puts it off-center, which is what the logo is meant to avoid.
- Shrinking the logo as the window narrows. At about 110 pt it would be too small to read.
- `ViewThatFits`. It measures the logo's own size, not the overlap with a sibling layer, so it cannot express this rule.

## Risks / Trade-offs

- [The 0.25 / 0.30 alphas may look too strong or too weak on the real material over different desktops] → Keep both values in one place (`logoFill`) and tune them during the manual check in tasks.md.
- [A future SVG export may use relative commands or curves that the small parser ignores] → Document in a comment that the parser handles only absolute `M`, point lists, and `Z`. A new artwork file means checking that comment.
- [`StripButton.referenceSize` differs between macOS versions] → The threshold is computed from it, not hard-coded.
- [No automated tests: the project has no test target] → Verify on the Mac with `just run`, in both appearances, at the default size and at minimum width.
