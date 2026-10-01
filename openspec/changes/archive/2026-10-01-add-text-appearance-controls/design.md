# Design

## Context

See proposal.md for the motivation. Specs: `text-appearance` (new), plus deltas to `sticky-note` ("Note typeface") and `checklists` ("List title", "List items").

Current state in `Sources/Notely/main.swift`:

- `noteFont` (line ~283) is a global SwiftUI `Font.custom("American Typewriter", size: 15, relativeTo: .body)`. `NoteView` uses it for the `TextEditor` and its placeholder, and `MenuRow` uses it for menu rows.
- `ListField.font(bold:)` (line ~429) is a static `NSFont` for list titles, items, and placeholders, with a system-font fallback. `makeNSView` sets the font once, and `styled(_:bold:done:)` builds attributed strings with it.
- `NoteView` and `ListView` lay `NoteStrip` (top bar) and an empty `BottomBar` over their content as overlays, with padding that keeps content clear of both bars. Overlays avoid a problem where AppKit layers the `NSScrollView` above earlier views and steals their clicks. Both bars sit on `EndEditingView`, which ends editing and drags the window.
- `StripButton` is an `NSViewRepresentable` wrapping a borderless `NSButton` that accepts the first mouse click. Its size comes from `StripButton.referenceSize`.
- `NoteStore` is an `ObservableObject` saved to `UserDefaults` that `AppDelegate` passes into each window's root view.
- The minimum note window size is 110 by 120 points (`minimumNoteSize`), enforced in `windowWillResize`. `bottomBarHeight` is 80% of `barHeight`. The target is macOS 13, so `onKeyPress` and newer SwiftUI popover and menu behavior are not available.

## Goals / Non-Goals

**Goals:**
- Use one source of truth for the font and size, and have every window redraw when it changes.
- Make the bar's buttons behave like the strip's buttons: first-click activation and no click stealing by the scroll view.
- Make changing the size a live operation, with no window reopen and no re-layout bugs in list rows.

**Non-Goals:**
- Changing the bar heights or the minimum window size, unless the check in Risks fails (see the fallback there).
- Supporting Dynamic Type or accessibility text sizes. macOS has no Dynamic Type, so `relativeTo:` is dropped.

## Decisions

### 1. A `TextAppearance` object, owned by `AppDelegate`

Add `final class TextAppearance: ObservableObject` with:

- `@Published var family: FontFamily`, where `enum FontFamily: String { case typewriter, system }`
- `@Published var size: Int`, clamped to `10...20`

Each property saves to its own `UserDefaults` key (`textFontFamily`, `textFontSize`) in `didSet`. `init` reads both keys. It treats a missing or unknown family as `.typewriter`, a missing size as 15, and clamps an out-of-range size.

The object also offers the font builders, so every caller resolves fonts the same way:

- `swiftUIFont(size:)` returns `.custom("American Typewriter", size:)` or `.system(size:)`.
- `nsFont(bold:)` returns `NSFont(name: "AmericanTypewriter"/"AmericanTypewriter-Bold", size:)`, falling back to `.systemFont(ofSize:weight:)`.

`AppDelegate` creates one instance and passes it to `MenuView` and `WindowContent`, in the same way it passes `store`. Views hold it as an `@ObservedObject`.

- *Alternative: store the setting in `NoteStore`.* Rejected because `NoteStore` is about note data, and its `notes` key must stay readable by older builds. Separate keys keep rollback trivial.
- *Alternative: `@AppStorage` in each view.* Rejected because each view would decode and clamp on its own, and `ListField` (AppKit) would still need the value passed in. One object gives one clamp and one fallback rule.
- *Alternative: a singleton.* Rejected to match the existing pattern of passing dependencies explicitly.

### 2. Buttons go into the existing `BottomBar`

`BottomBar` takes the `TextAppearance` and becomes a `ZStack`, like `NoteStrip`: `EndEditingView(drags: true)` underneath, then an `HStack` with `Spacer(minLength: 0)` and the two buttons, with 12 points of trailing padding. Clicks on the buttons reach the buttons; clicks elsewhere on the bar still end editing and drag the window.

No layout changes: `NoteView` and `ListView` already overlay the bar and pad their content above it.

- *Alternative: a separate bar view overlaid next to `BottomBar`.* Rejected because the windows already have exactly one bottom bar, and two overlapping views would fight over clicks and the fill.

### 3. AppKit buttons for the menu and the popover

Generalize `StripButton` so it can hand its `NSButton` to the action, for example `action: (NSButton) -> Void`. Then use it for both buttons:

- **Font (`textformat`):** build an `NSMenu` with two items, "American Typewriter" and "System". Set `state = .on` on the current one. Each item's action sets `appearance.family`. Show it with `menu.popUp(positioning: currentItem, at: .zero, in: button)`. AppKit keeps it on screen and handles Esc and outside clicks.
- **Size (`textformat.size`):** an `NSPopover` with `behavior = .transient` and `contentViewController = NSHostingController(rootView: SizePopover(appearance:))`. Show it with `show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)`, so it opens above the bar.
  - `SizePopover` holds a SwiftUI `Slider(value: Binding<Double>, in: 10...20, step: 1)`, bound through `appearance.size`, and a `Text("\(size) pt")`.
  - Writes happen on every slider tick, so text changes live. A `UserDefaults` write per tick is cheap.

Keep a reference to the open popover in the button's coordinator, so a second click closes it rather than stacking another.

- *Alternative: SwiftUI `Menu` and `.popover`.* Rejected for three reasons:
  - SwiftUI `Menu` on macOS 13 draws its own bordered button.
  - `.popover` anchored inside an `NSHostingView` with `sizingOptions = []` has been unreliable.
  - Neither accepts the first mouse click in an inactive window. The spec requires the first click to work.

### 4. Fonts flow into views as values

- **`NoteView`:** takes `appearance` and uses `appearance.swiftUIFont(size: appearance.size)` for both the `TextEditor` and the placeholder. The global `noteFont` constant is removed.
- **`MenuRow`:** gets the font from `MenuView` as `appearance.swiftUIFont(size: 15)`, so the menu follows the family and keeps its fixed size.
- **`ListField`:** gets a `font: NSFont` property in place of the static `font(bold:)`, and `styled(...)` takes the font as a parameter. `ListView` computes `appearance.nsFont(bold: true)` for the title and `appearance.nsFont(bold: false)` for items. `updateNSView` reapplies the font when `field.font != font`:
  - the field's `font`
  - the placeholder attributed string
  - the attributed value, while not editing
  - the field editor's `typingAttributes` and text storage, while editing
  - then `invalidateIntrinsicContentSize()`, so wrapped rows get a new height

Today `makeNSView` sets the font only once, so without this step list rows would keep their old size.

### 5. Placeholder alignment

The note placeholder uses fixed offsets (`.padding(.top, 8)`, `.padding(.leading, 5)`) that match the `NSTextView` container inset and line fragment padding. These do not depend on the font, so they stay. Task 3.3 checks alignment at sizes 10 and 20 in both fonts. If alignment drifts, derive the top offset from the font's ascender.

## Risks / Trade-offs

- **Minimum size with the largest text** → [Risk] At 110 by 120 points:
  - top bar (`barHeight`, about 28) plus gap 4
  - bottom bar (`bottomBarHeight`, about 22) plus gap 4
  - leaves about 62 points for text, which is room for two 20 point lines

  The width needs two buttons, 16 points apart, plus 12 points of trailing padding: about 60 of 110 points. → Mitigation: task 3.4 checks this case. If it fails, ask the user before changing `minimumNoteSize`, because that changes `note-resize`.
- **List row heights not updating on size change** → [Risk] `NSTextField` wrapping height is cached. → Mitigation: invalidate the intrinsic size in `updateNSView` (Decision 4). Task 4.2 verifies with long wrapped items while dragging the slider.
- **Editing during a font change** → [Risk] Changing the font while a field editor is active can lose the caret position or the undo history. → Mitigation: update the field editor's text storage attributes in place instead of resetting its string. Task 4.3 verifies the caret stays put.
- **Global setting surprises** → [Trade-off] Changing the size in one window resizes text in all windows. This was accepted in exploration as the simpler model.
- **Menu rows wider in the system font** → [Trade-off] Titles may truncate at different points. Truncation is already handled with `.tail`.

## Migration Plan

- The setting is additive: two new `UserDefaults` keys. Existing data, including `notes`, is unchanged.
- **Rollback:** an older build ignores the new keys and shows American Typewriter at 15 points. No cleanup is needed.
