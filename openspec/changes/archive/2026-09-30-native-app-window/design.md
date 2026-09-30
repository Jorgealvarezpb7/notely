# Design

## Context

All app code is in `Sources/Notely/main.swift`. Today each note is a borderless `NotePanel` (`NSPanel` with `.nonactivatingPanel`) at `.floating` level on all Spaces. The app runs with `.accessory` policy and `LSUIElement`. A hidden main menu gives Cmd key equivalents, and a status item gives Quit. The size 220x150 is hardcoded in two places: `NoteView`'s `.frame(width:height:)` and `AppDelegate.panelSize`. `clamp`, `restoredOrigin`, and `addNote` all take that constant.

`Note` is `Codable` and is stored as a JSON array in `UserDefaults` under `notes`. It has `id`, `text`, and an optional `origin` in `NSStringFromPoint` form.

The build is a `justfile` that assembles `Notely.app` by hand (no Xcode project) and ad-hoc signs it. The icon artwork is `notely-icon-1024 (1).png` at the repo root: 1024x1024 RGBA with transparent corners, already on Apple's macOS icon grid.

## Goals / Non-Goals

**Goals:**
- Native resize with system cursors and edge and corner hit areas. No custom resize code.
- Keep the current note look: the drag strip with "+" and "−", translucent material, and no visible title or traffic lights.
- Keep saved notes compatible in both directions: upgrading and downgrading.

**Non-Goals:**
- Window menu, Cmd+W, Cmd+M, full screen, or window tabbing.
- A Dock menu with note titles or "New Note".
- An asset catalog, an Xcode project, or a `.icon` (Icon Composer) file.

## Decisions

### Titled `NSWindow` with a hidden title bar, not a borderless resizable window
Style mask: `[.titled, .resizable, .fullSizeContentView]`. Set `titlebarAppearsTransparent = true` and `titleVisibility = .hidden`. Hide the close, miniaturize, and zoom buttons with `standardWindowButton(_:)?.isHidden = true`. Leave out `.closable` and `.miniaturizable`, so Cmd+W and Cmd+M do nothing, and "−" stays the only way to remove a note.

Rationale: a titled window gets native resize tracking, native rounded corners, and a native shadow. Alternative: a borderless window with `.resizable`. Rejected, because edge hit-testing on a clear, rounded borderless window is unreliable and would need a custom grip.

`NotePanel` becomes `NoteWindow: NSWindow`. It keeps the `cancelOperation(_:)` override (Esc ends editing). It drops the `canBecomeKey` and `canBecomeMain` overrides, because a titled window already allows both. Set `isReleasedWhenClosed = false`: an `NSWindow` made in code releases itself on `close()` by default, which would over-release a window the `windows` dictionary still owns. Using `NSWindow` instead of `NSPanel` also avoids `hidesOnDeactivate`, which defaults to true for panels and would hide every note whenever another app became active.

### Look inside the window
`NoteView` drops `.frame(width: 220, height: 150)` and the `RoundedRectangle(cornerRadius: 22)` background clip. Instead it uses `.frame(maxWidth: .infinity, maxHeight: .infinity)` and a `.ultraThinMaterial` background that ignores safe areas. The window keeps `isOpaque = false` and `backgroundColor = .clear`, so the material shows through, and the system window mask gives the rounded corners. Set `NSHostingView.sizingOptions = []` (macOS 13+), so SwiftUI's size never pins the window. The window alone owns its size.

The drag strip stays at the top, in the transparent title bar area. `DragHandle` still calls `performDrag(with:)`. The title bar region can drag the window too, and that is harmless. The "+" and "−" buttons keep `acceptsFirstMouse`, so one click works while another app is active.

### Size limits
- Minimum: `window.minSize = 160x100` (a frame size, like the saved size). At that size the strip plus one text line still fit inside the 12-point padding.
- Maximum: `windowWillResize(_:to:)` limits the proposed size to the visible frame of the window's current screen. This is dynamic because screens differ. `contentMaxSize` is a fixed value, so it cannot follow the window between screens.

### Persistence: separate optional `size` field
`Note` gains `var size: String?` in `NSStringFromSize` form. Synthesized `Codable` decodes a missing optional key as `nil`, so notes saved by the previous version load with `size == nil` and open at 220x150. `JSONDecoder` ignores unknown keys, so a downgrade still loads, and it drops the sizes on its next save.

Alternative: replace `origin` with one `frame` string. Rejected. It needs a migration branch, and it breaks downgrade.

Parse `size` explicitly, like `restoredOrigin` parses `origin`. `NSSizeFromString` returns `.zero` for bad input, and `.zero` would be clamped up to the minimum size silently.

Saving: `windowDidResize` saves both origin and size, because a resize from the left or bottom edge moves the origin without always posting `windowDidMove`. `windowDidMove` still saves the origin. Saving on every live-resize step is acceptable, because each keystroke already writes the same data.

### Per-note size through placement helpers
Replace `AppDelegate.panelSize` with a `defaultSize` constant (220x150) and a helper that gives the effective size for a note: saved size or default, then fitted to the target screen's visible frame (each side capped at that screen's size and floored at the minimum). `openPanel` builds the window with that size. `restoredOrigin` and `clamp` already take a size parameter, so they receive it unchanged. `addNote` uses `sourceWindow.frame.size` and passes it into `store.add`, which gains a `size` parameter, so the new note's size is saved from the start.

`frame.size` is the frame size, not the content size. With `.fullSizeContentView` the two are equal, so the saved size and the min/max values all use the same measure.

### Regular app activation
Use `setActivationPolicy(.regular)` and remove `LSUIElement` from `Info.plist`. Keep the existing `makeMainMenu()`; it is now visible. The app menu keeps "Quit Notely" (Cmd+Q). The Edit menu keeps its items. Remove the status item and its menu.

Window level `.normal`. `collectionBehavior` goes back to the default (drop `.canJoinAllSpaces` and `.stationary`).

In `addNote`, replace `panel.makeKey()` with `makeKeyAndOrderFront(nil)`. Clicking "+" on a background window activates the app anyway. The first-responder dispatch stays as it is.

Implement `applicationShouldHandleReopen(_:hasVisibleWindows:)`: order every note window front and return `true`. The default Dock-click activation already raises the app's windows. The explicit handler also covers the case where the windows are ordered out.

### Icon built at `just build`
Move the artwork to `Packaging/AppIcon.png`. In `build`, generate `AppIcon.iconset` in a temporary directory with `sips -z` at 16, 32, 128, 256, and 512 (each at @1x and @2x). Then run `iconutil -c icns` into `Notely.app/Contents/Resources/AppIcon.icns`. Add `CFBundleIconFile = AppIcon` to `Info.plist`. Generate the icon before `codesign`, so the seal covers `Resources`. The `.icns` file is not committed; the PNG is the source.

## Risks / Trade-offs

- [Launch Services and the Dock cache the old generic icon, or the old `LSUIElement` state, for the installed path] → `install` runs `touch` on the copied bundle. Tasks include checking the Dock and Finder after `just run`. If the cache persists, run `lsregister -f ~/Applications/Notely.app` once by hand.
- [The transparent title bar region (~28pt) could take clicks meant for "+" and "−"] → With `.fullSizeContentView`, content views in the title bar area still receive mouse events. Verify by hand. If a button fails, move the strip below the title bar inset.
- [The corner radius changes from 22pt to the system radius] → Accepted by the user.
- [The material background looks different in an inactive window (the system dims it)] → Accepted. This is native behavior.
- [Notes no longer float, so a user who relied on always-on-top loses it] → Accepted by the user. The Dock icon brings the notes back.

## Migration Plan

No data migration step. Old saved data loads with `size == nil`. To roll back, install the previous build: notes keep their text and positions, and sizes are dropped.
