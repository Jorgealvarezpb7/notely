# Tasks

Build checkpoints marked "(host)" need the macOS host: the `dkc` container has no Swift. "(linux)" means `docker run --rm -v "$PWD:/app" -w /app swift:6.0 swift test` from the repo root on the host.

## 1. Platform and file split

- [x] 1.1 Raise the minimum macOS to 14: `.macOS(.v14)` in `Package.swift` and `LSMinimumSystemVersion` 14.0 in `Packaging/Info.plist`. Verify both files say 14 and nothing else in the repo names 13.0 as a minimum (`grep -rn "13\.0\|v13"`).
- [x] 1.2 Split `Sources/Notely/main.swift` into files grouped by area (Model, Store, Appearance, Styling, Chrome, Links, LinkCards, Editor, Lists, Menu, Geometry, App) inside the same `Notely` target, moving code without editing it. Leave only the 5 lines of app startup in `main.swift`. Mark `private extension NSView` helpers `fileprivate`/`internal` only where a split needs it. Verify that `git diff --stat` shows code only moving and that the line totals match. (host) `swift build` succeeds.

## 2. NotelyCore module

- [x] 2.1 Add the `NotelyCore` target in `Package.swift`, plus the `#if os(macOS)` guard around the macOS-only targets (design decision 7). Move `Note`, `ListItem`, `StyleRun`, `plainText(ofList:)`, `listTitle`, `noteTitle`, the frame functions and size constants, `parsePair`, and `savedSize` into it, making them `public` only where `Notely` uses them. Verify that Core imports only Foundation and (host) `swift build` succeeds.
- [x] 2.2 Split tint handling: hex parsing and formatting to and from RGB components go in Core, and the `NSColor` conversion and `tintPresets` stay in the app. Verify (host) `swift build` and that a preset tint still round-trips to the same `#RRGGBB` string.
- [x] 2.3 Move `PageHead` into Core (`Links/PageHead.swift`). Verify (host) `swift build`.
- [x] 2.4 Add the `NotelyCoreTests` target and the `just test` recipe (`swift test`). Write tests for: `StyleRun.clamped`, `plainText(ofList:)`, `parsePair` with both `{10, 20}` and `{10.0, 20.0}`, `fit`/`clamp`/`restoredFrame`/`newNoteFrame` (minimum size, larger than screen, offscreen), hex tint parsing (valid, short, non-hex), `noteTitle`/`listTitle`, and `PageHead.parse` (title, `og:` tags, entities, relative icon URLs, stopping at `</head>`). Verify (host) `just test` passes and (linux) passes.

## 3. NoteStore and repository

- [x] 3.1 Add the `NoteRepository` protocol and `UserDefaultsNoteRepository(defaults:)` in Core, moving today's load logic unchanged: the `notes` key, clamping of damaged style runs, falling back to one empty note on undecodable data, keeping an empty list empty, and migrating `noteText`/`panelOrigin`. Add an in-memory repository for tests. Verify with tests using `UserDefaults(suiteName:)` for each load branch.
- [x] 3.2 Add a fixture test: a JSON blob in today's saved format (a plain note, a styled note, a tinted note, an open list with checked and unchecked items, a closed note, and a note with an unknown `kind`) decodes, and re-encoding keeps the same keys and values. Verify (host) `just test` and (linux) pass.
- [x] 3.3 Move `NoteStore` into Core as `@Observable public final class` with `init(repository:)`, keeping every mutation method, the list ordering rules, and save-after-every-change. Verify with tests for `add`, `addList`, `remove`, `setText` (empty styles saved as nil), `setTint` (no save when unchanged), `appendItem`/`insertItem` positions, `toggleItem` ordering in both directions, `removeItem`, and the `text` plain copy refreshing on every list change, each asserting what the in-memory repository received.
- [x] 3.4 Update the app to `NoteStore(repository: UserDefaultsNoteRepository(defaults: .standard))`, and replace `@ObservedObject var store` with `let store: NoteStore` (or `@Bindable` where a binding is needed) in every view. Verify (host) `swift build` and the manual checks: typing in a note updates the menu title live, checking an item moves it, tint changes show at once, and quit and relaunch keeps every change.

## 4. NotelyLinks module

- [x] 4.1 Add the `NotelyLinks` target that depends on Core. Move `LinkDetector`, `DetectedLink`, `LinkPage`, `StoredLinkPage`, `LinkPageFetcher`, `LinkPageStore`, and `LinkCardLayout` into it, if `LinkCardLayout` has no view code; otherwise it stays in the app. Make `LinkPageStore.init` public and take the cache folder as a parameter, defaulting to the current `Caches/com.alvarezjorge.Notely/LinkPages`. Verify that Links does not import SwiftUI and (host) `swift build`.
- [x] 4.2 Remove `LinkPageStore.shared`: the startup code creates one instance and passes it through the `NoteEditor` and `ListField` representables to `NoteTextView`, `ListTextField`, and `LinkFieldEditor`, and to `LinkCardAbove` through a SwiftUI environment value. Verify that `grep -rn "LinkPageStore.shared" Sources` is empty and (host) manually: a pasted link shows its card, and cards load from cache on relaunch with no network.

## 5. NotelyUI module and thin AppDelegate

- [x] 5.1 Add the `NotelyUI` target that depends on Core and Links, and move all remaining view, window, menu, appearance, and styling code into it. `AppDelegate` gets a `public init(store:appearance:linkPages:)`. Convert `TextAppearance` to `@Observable` and update its observers. Leave `Sources/Notely/main.swift` as the composition root only. Verify (host) `swift build`, and that changing the font and size in the appearance popover updates open notes, lists, and the menu.
- [x] 5.2 Extract `MenuWindowController` (menu window, its frame saving under `menuFrame`, and the full-screen guard, absorbing `MenuWindowDelegate`). Verify (host) that the menu window reopens at its saved frame and that its red button quits.
- [x] 5.3 Extract `NoteWindowController` (the window map, `openWindow`, frame saving and resize limits, field editors, overlay scrollers, and the open, close, and delete-confirm flows), leaving `AppDelegate` with launch, reopen, main menu, and scroller-style observation. Verify that `AppDelegate` is under 120 lines and (host) manually: new note and new list from the menu, "−" closes and the menu reopens, trash asks and deletes, windows reopen at their saved frames, and the 190 by 120 minimum size holds.
- [x] 5.4 Review the public API: every `public` symbol in Core and Links is used by another module. Verify with a grep listing public symbols and their cross-module uses, and remove `public` from any unused one.

## 6. Integration check

- [x] 6.1 (host) `just test` passes, and (linux) Core tests pass.
- [x] 6.2 (host) `just run` with the existing saved data from the previous build: every note, list, style, tint, window frame, font setting, and link card is as before. Go through the specs (`openspec/specs/*`) for sticky-note, multiple-notes, checklists, text-styles, text-appearance, note-tint, note-resize, links, notes-menu, and app-controls, and confirm no behavior changed.
