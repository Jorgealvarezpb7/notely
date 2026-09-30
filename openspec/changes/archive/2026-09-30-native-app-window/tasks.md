# Tasks

The project has no test target. Each task is verified with a command and a manual check on the host Mac. Build and run with `just run` on macOS; the recipes do not run in the dkc Linux container. Before starting, commit the pending `add-multiple-note` archive and spec edits, and back up notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. App icon

- [x] 1.1 Move `notely-icon-1024 (1).png` to `Packaging/AppIcon.png` with `git mv` or `mv`; verify `ls Packaging` shows `AppIcon.png` and the repo root no longer has the old file
- [x] 1.2 In the `justfile` `build` recipe, before `codesign`, create `{{app}}/Contents/Resources`, build an `AppIcon.iconset` in a temporary directory with `sips -z` at 16, 32, 128, 256, and 512 (each at @1x and @2x), and run `iconutil -c icns` into `{{app}}/Contents/Resources/AppIcon.icns` (design.md "Icon built at `just build`"); verify `just build` succeeds, `codesign --verify Notely.app` passes, and the `.icns` file exists
- [x] 1.3 Add `CFBundleIconFile` = `AppIcon` to `Packaging/Info.plist`, and add `touch ~/Applications/Notely.app` at the end of `install`; verify `plutil -lint Packaging/Info.plist` passes and, after `just install`, app-controls scenario "Icon in Finder" passes

## 2. Regular app

- [x] 2.1 Remove `LSUIElement` from `Packaging/Info.plist` and change `app.setActivationPolicy(.accessory)` to `.regular` in `Sources/Notely/main.swift` (update its comment); verify with `just run` that app-controls scenario "Dock icon at launch" passes and the Dock shows the Notely icon
- [x] 2.2 Delete the status item (the `statusItem` property and its setup in `applicationDidFinishLaunching`), and update the `makeMainMenu()` doc comment, because the menu is now visible; verify `grep -n statusItem Sources/Notely/main.swift` prints nothing, the menu bar has no Notely item, and app-controls scenarios "Quit from app menu", "Quit from Dock", "Cmd+Q while editing", and "Cmd+Q in another app" pass
- [x] 2.3 Add `applicationShouldHandleReopen(_:hasVisibleWindows:)`, which orders every note window front and returns `true`; verify app-controls scenario "Click Dock icon with notes hidden"

## 3. Native note window

- [x] 3.1 Replace `NotePanel: NSPanel` with `NoteWindow: NSWindow`. Keep the `cancelOperation(_:)` override and drop the `canBecomeKey`/`canBecomeMain` overrides. In `openPanel`, use style mask `[.titled, .resizable, .fullSizeContentView]`, `titlebarAppearsTransparent = true`, `titleVisibility = .hidden`, hide the three standard window buttons, remove `.floating` level and `collectionBehavior`, and set `NSHostingView.sizingOptions = []` (design.md "Titled `NSWindow`..." and "Regular app activation"); verify `grep -n "NSPanel\|nonactivatingPanel\|floating\|canJoinAllSpaces" Sources/Notely/main.swift` prints nothing and the build succeeds
- [x] 3.2 In `NoteView`, replace `.frame(width: 220, height: 150)` and the rounded-rectangle background with `.frame(maxWidth: .infinity, maxHeight: .infinity)` and an `.ultraThinMaterial` background that ignores safe areas (design.md "Look inside the window"); verify with `just run` that the note shows the translucent material with system rounded corners, no traffic lights, and no title
- [x] 3.3 In `addNote`, replace `panel.makeKey()` with `makeKeyAndOrderFront(nil)`; verify multiple-notes scenarios "Click '+'", "Click '+' while another app is frontmost", and "Click a panel button"
- [x] 3.4 Verify sticky-note scenarios "Click another app's window", "Click a note window behind another app", "Switch Space", "Press Esc while editing", "Drag the drag area", and "Drag inside text", and multiple-notes scenarios "Click '−' while another app is frontmost" and "Click '−' on the only note" (if "+" or "−" fails to click inside the title bar area, apply the fallback in design.md Risks)

## 4. Resize and size persistence

- [x] 4.1 Add `var size: String?` to `Note`, a `size` parameter to `NoteStore.add`, and `setFrame(origin:size:for:)` (or `setSize`) to `NoteStore`, plus an explicit `{w, h}` parser like the origin parser in `restoredOrigin` (design.md "Persistence"); verify the build succeeds and, with `just run` on the backed-up data, old notes open with their text and positions (note-resize scenario "Note saved by an earlier version")
- [x] 4.2 Replace `AppDelegate.panelSize` with a `defaultSize` (220x150) and an effective-size helper (saved size or default, fitted to the target screen's visible frame, floored at 160x100). Use it in `openPanel`, `restoredOrigin`, and `defaultOrigin`. Make `addNote` use the source window's `frame.size` and pass it to `store.add` (design.md "Per-note size through placement helpers"); verify `grep -n panelSize Sources/Notely/main.swift` prints nothing, and note-resize scenario "Click '+' on a resized note" and multiple-notes scenario "Click '+' near a screen edge" pass
- [x] 4.3 Set `minSize` to 160x100 and implement `windowWillResize(_:to:)` to cap the size at the current screen's visible frame (design.md "Size limits"); verify note-resize scenarios "Shrink below minimum", "Controls stay visible at minimum size", "Drag the bottom-right corner", and "Drag an edge", and that dragging a corner cannot make the window larger than the screen's visible area
- [x] 4.4 Implement `windowDidResize(_:)` to save the origin and size of the resized window's note; verify note-resize scenarios "Relaunch keeps size" (including a resize from the left edge) and "Resize one of two notes", and check that `defaults read com.alvarezjorge.Notely notes` includes a `size` value
- [x] 4.5 Edit one note's saved `size` in `defaults` to a value larger than the screen and relaunch; verify note-resize scenario "Saved size larger than screen", then restore the backup with `defaults import com.alvarezjorge.Notely ~/notely-backup.plist`

## 5. Integration

- [x] 5.1 Update the `## Purpose` lines of `openspec/specs/sticky-note/spec.md` (drop "always-on-top") and `openspec/specs/app-controls/spec.md` (drop "no Dock icon" and "menu bar item"); verify `openspec validate --specs --strict` passes
- [x] 5.2 Run `openspec validate native-app-window --strict`, then walk every scenario in the four delta specs on the final `just run` build with three notes of different sizes open; verify all pass, including app-controls scenario "Quit soon after typing" through the app menu, the Dock menu, and Cmd+Q, and app-controls scenario "Icon in application switcher"
