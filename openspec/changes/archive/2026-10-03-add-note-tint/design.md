# Design

## Context

See proposal.md for the motivation. Specs: `note-tint` (new), plus deltas to `sticky-note` ("Panel stays movable"), `text-appearance` ("Font and size buttons in the bottom bar", "Buttons usable at minimum window size"), and `note-resize` ("Size limits").

Current state in `Sources/Notely/main.swift`:

**Window background**
- Note and list windows are `NoteWindow`s with `isOpaque = false` and `backgroundColor = .clear`.
- All of the translucency comes from SwiftUI `.background(.ultraThinMaterial)` on the root of `NoteView` (line ~834) and `ListView` (line ~2028). There is no `NSVisualEffectView`.

**Colors that follow the appearance**
- Text uses `NSColor.textColor`.
- The bars use `barFill = Color.primary.opacity(0.08)`.
- The logo, check circles, and button tints use dynamic colors, so all of them follow the window's effective appearance.

**Bottom bar**
- `BottomBar` holds `StyleButtons` (notes only) at the leading edge.
- It holds the font and text size `StripButton`s at the trailing edge, in an `HStack(spacing: 16)`.
- The font menu and size popover come from `AppearanceControls`, an `NSObject` kept as `@StateObject` so the popover outlives view updates.

**Data and sizes**
- `Note` is `Codable` with only optional fields beyond `id` and `text`.
- `NoteStore` saves the whole array to `UserDefaults` on every `set…` call.
- `minimumNoteSize` is 160 by 120. `windowWillResize`, `fit`, and `restoredFrame` enforce it for notes and lists alike.
- The note bottom bar at 160 uses about 150 points: 12 + 3×14 + 2×12 + 16 + 14 + 16 + 14 + 12. A sixth button does not fit.

## Goals / Non-Goals

**Goals:**
- Add exactly one view layer for the tint. Leave the material, window flags, and every foreground color untouched.
- Use one tint strength constant, so "never opaque" holds by construction rather than per color.
- Keep the saved data readable by older builds.

**Non-Goals:**
- Readability guarantees for any particular color. The user picked option B in exploration: the appearance is never changed for a tint.
- Tint for the menu window, or showing the tint in menu rows.
- Changing the bar heights, spacing, or any existing button.
- User-adjustable tint strength.

## Decisions

### 1. Store the tint as an optional sRGB hex string on `Note`

Add `var tint: String?` holding `"#RRGGBB"`, written in sRGB. nil means no tint. Add `NoteStore.setTint(_ tint: String?, for id: UUID)` in the style of `setOrigin`.

Add two free functions next to `savedSize`:
- `tintString(_ color: NSColor) -> String`: convert to `.sRGB`, drop alpha, round components to 0…255.
- `tintColor(_ string: String?) -> NSColor?`: parse `#RRGGBB`; nil on any other shape.

Callers treat a nil parse as no tint, which covers the "unreadable saved tint" scenario.

- *Alternative: store `[Double]` RGBA components.* Rejected. A hex string reads clearly in the saved JSON, it cannot carry alpha (which the spec forbids anyway), and it compares equal to presets exactly.
- *Alternative: archive `NSColor` with `NSKeyedArchiver`.* Rejected. The result is opaque binary in the JSON, and catalog colors like `systemBlue` resolve differently by appearance, so a stored tint would drift.

### 2. Preset colors are fixed sRGB values, not system colors

The seven presets are constants in a `TintPreset` list of name and hex pairs:
- Yellow `#FFD60A`
- Orange `#FF9F0A`
- Pink `#FF375F`
- Purple `#BF5AF2`
- Blue `#0A84FF`
- Green `#30D158`
- Gray `#8E8E93`

These are the macOS dark-appearance system colors, saved as fixed values. A menu entry shows the check mark when its hex equals the note's `tint` string.

- *Alternative: `NSColor.systemYellow` and the other system colors.* Rejected. They change between light and dark, so the stored hex would not match the preset after an appearance switch, and the check mark would vanish.

### 3. The tint is a second background layer over the material

In `NoteView` and `ListView`, replace `.background(.ultraThinMaterial)` with a background that stacks:
1. `Rectangle().fill(.ultraThinMaterial)`, unchanged in effect.
2. `Color(nsColor: tint).opacity(tintStrength)`, only when the note has a tint.

`let tintStrength = 0.2` is a top-level constant next to `barFill`. The bars stay overlays above this background, so their `barFill` shades over the tint as the spec requires. Text, logo, and buttons are untouched.

Both views read the tint with `store.note(id)?.tint`. Both already observe `store`, so a change redraws at once.

- *Alternative: set `NSWindow.backgroundColor` to the tint with alpha.* Rejected. With `isOpaque = false`, AppKit draws that color under the SwiftUI material, where the blur mostly hides it. It also brings back the risk of an opaque window if alpha is ever lost.
- *Alternative: `NSVisualEffectView` with a layer tint, or `.material` with a `.blendMode`.* Rejected. Both change how the native material renders, and the user asked to keep it as it is.
- *Alternative: flip `window.appearance` by tint luminance.* Rejected by the user in exploration (option A) because it changes the material's look.

### 4. Tint button: a `StripButton` with a colored symbol

Add a `tintColor: NSColor?` parameter to `StripButton`:
- With a tint, the button shows `circle.fill` with `contentTintColor = tint`, at full strength.
- With no tint, it shows `circle` with the same tint as the other bar icons.

`updateNSView` already refreshes `contentTintColor` for the style buttons, so a tint change updates the icon live.

The button goes last in `BottomBar`'s trailing `HStack(spacing: 16)`. `BottomBar` gets the `store` and the note `id`, so both note and list windows can pass them in.

### 5. `TintControls`: the menu and the shared color panel

Add `final class TintControls: NSObject, ObservableObject`, a `@StateObject` in `BottomBar` beside `AppearanceControls`. It holds `store` and `id`.

**`showMenu(from: NSButton)`** builds an `NSMenu`:
- "Default".
- A separator.
- The seven presets. Each `NSMenuItem.image` is a 12 pt filled circle drawn with `NSImage(size:flipped:drawingHandler:)`.
- A separator.
- "Other Colors…".

The menu pops up at the button, in the same way `showFontMenu` does. The check mark goes on the entry whose value equals `note.tint`, or on "Default" when the tint is nil.

**"Other Colors…"**:
1. Set `NSColorPanel.shared.showsAlpha = false`.
2. Set the panel's color to the current tint, or white.
3. Call `setTarget(self)` and `setAction(#selector(panelChanged(_:)))`.
4. Call `orderFront`.

**`panelChanged(_:)`** reads `NSColorPanel.shared.color`, converts it with `tintString`, which drops alpha, and calls `store.setTint`.

`NSColorPanel` is a single shared panel, and a new `setTarget` replaces the old one. So the window that last chose "Other Colors…" owns the panel, and other windows stop receiving changes. This gives the "panel follows the last note" scenario with no extra bookkeeping.

When the window that owns the panel closes, the panel closes too, as the spec requires. "−" and delete both end in `window.close()`, which posts `NSWindow.willCloseNotification`. So "Other Colors…" also starts observing that notification for the button's window. When it fires and this `TintControls` still owns the panel, it:
1. calls `setTarget(nil)` and `setAction(nil)`,
2. calls `orderOut(nil)` on the panel,
3. clears `panelOwner`.

When another note owns the panel, the handler does nothing, so closing an unrelated note leaves the panel open.

The panel floats above every window of the app, sheets included, so it would cover a delete confirmation. `confirmDelete` calls `TintControls.closePanel()` before showing the sheet. That static method releases and orders out the panel, whichever note owns it. The owner's close observer then finds `panelOwner` nil and does nothing.
- *Alternative: lower the panel's level, or show the delete confirmation as a separate alert window.* Rejected. Both change how standard macOS UI behaves, and the user wants no color panel during a delete.

`NSColorPanel` has no public getter for its target. So `TintControls` keeps `static var panelOwner: ObjectIdentifier?`, set when it takes the panel.
- It is an identifier, not a `weak var`: Swift reads a weak reference as nil inside `deinit`, so an ownership check in `deinit` would always fail.
- `deinit` runs the same release as the close handler, without `orderOut`. This covers a `TintControls` that goes away without its window closing.
- A deleted note is also covered by the existing `firstIndex` guard: `setTint` on a removed id does nothing.

- *Alternative: `NSColorWell` with `.minimal` style.* Rejected during exploration. It has no "Default" entry and it does not look like the other bar icons.

### 6. Minimum size goes from 160 to 190, shared by notes and lists

Change `minimumNoteSize` to `NSSize(width: 190, height: 120)`. `windowWillResize`, `fit`, `restoredFrame`, and `window.minSize` already read it, so saved frames narrower than 190 widen on open with no new code.

The new layout at 190: 12 + 42 + 24 + 16 + (3×14 + 2×16) + 12 = 180, which leaves 10 points of slack, the same slack the bar has today. Check the logo's hide threshold (line ~621). It counts only the top bar's "−" and trash, so it does not change.

Lists share the constant. The note-resize spec already requires the same limit for both kinds of window.

## Risks / Trade-offs

- **[Risk]** Some colors read poorly. Yellow in light appearance, or navy in dark appearance, can lower text contrast. → **Mitigation:** none by design. The fixed strength of 0.2 keeps the tint faint. The user accepted this trade-off.
- **[Risk]** Saving on every `NSColorPanel` change re-encodes all notes many times a second while the user drags. → **Mitigation:** `NoteStore` already saves on every keystroke, and the comment at line ~71 records that this is cheap. Debounce only if profiling shows lag.
- **[Risk]** The 0.2 strength looks too weak over a dark desktop, or too strong over a light one. → **Mitigation:** strength is one constant. Tune it during the visual check in tasks. The spec fixes only "same strength for all colors, never opaque".
- **[Risk]** A `StripButton` with `contentTintColor` set to a light tint, such as yellow, can be hard to see against the bar in light appearance. → **Mitigation:** acceptable. The circle is a color swatch, not text. It shows exactly the color the user chose.
- **[Trade-off]** Notes saved between 160 and 190 points wide grow by up to 30 points on first launch of this version.

## Migration Plan

- No data migration. `tint` is optional, so earlier saves decode with nil. Earlier builds ignore the unknown key when they decode, but rewriting the notes from an earlier build drops it. Rolling back therefore loses tints, and nothing else.
- Window sizes widen on their own through the existing minimum-size checks.
