# Design

## Context

See proposal.md for motivation. Current state of `Sources/Notely/main.swift`:

- **Model and store (l.8-252)**: `Note`, `ListItem`, `StyleRun`, `plainText(ofList:)`. `NoteStore` is an `ObservableObject` that holds the mutation rules (list ordering, style clamping, legacy migration) and writes the whole `[Note]` JSON to `UserDefaults` on every change.
- **Preferences**: `TextAppearance` (`ObservableObject`, `UserDefaults`, `NSFont` and SwiftUI `Font`). `MenuWindowDelegate` saves `menuFrame` directly to `UserDefaults`.
- **Links**: `LinkDetector` uses `NSDataDetector`. `PageHead` is a regex parser. `LinkPageFetcher` uses `URLSession`. `LinkPageStore.shared` is a singleton cache in `Caches/com.alvarezjorge.Notely/LinkPages`, read directly by `NoteTextView` and `LinkCardAbove`. `LinkHoverController.shared` is an app-wide event monitor read by `NoteTextView`, `ListTextField`, and `LinkFieldEditor`.
- **Geometry (l.3134-3252)**: frame clamp, fit, and restore functions and size constants, all pure. Tint parsing mixes pure hex parsing with `NSColor`.
- **App (l.3308-3673)**: `AppDelegate` owns the store, the note windows, the menu window, overlay scroller fixes, field editors, and open, close, and delete flows.
- `NoteStore` and `TextAppearance` are already injected through initializers from `AppDelegate`. Views reach the store through `@ObservedObject var store`.

Constraints:

- A Linux spike in `swift:6.0` showed that Combine is missing, Observation is present, `NSDataDetector` is missing, and `NSRect`, `NSStringFrom*`, `NSRegularExpression`, `UserDefaults`, and `JSONEncoder` all work. Linux formats whole numbers as `{10.0, 20.0}`; macOS writes `{10, 20}`.
- The `dkc` container has no Swift toolchain. Building and running the app needs the macOS host. The Linux check of `NotelyCore` needs Docker `swift:6.0` on the host.
- The Command Line Tools ship neither XCTest nor a `Testing` module that `swift test` can find, so tests on the Mac need full Xcode (`xcode-select -s /Applications/Xcode.app/Contents/Developer`). Tests use Swift Testing, which both Xcode and the Linux `swift:6.0` image provide.
- No spec states a minimum macOS version. Every spec requirement must keep holding.

## Goals / Non-Goals

**Goals:**

- Compile-time-enforced, one-way dependencies: `Notely` depends on `NotelyUI`, `NotelyUI` on `NotelyLinks` and `NotelyCore`, and `NotelyLinks` on `NotelyCore`.
- `NotelyCore` builds and passes its tests on both macOS and Linux.
- Every note and list mutation goes through `NoteStore`, which is the single hook point for a later sync engine.
- Saved data stays byte-compatible in key names and JSON shape.

**Non-Goals:**

- No change stream, no `source` field on `ListItem`, and no new storage backend. Those belong to the GitHub change.
- Local view state classes (`NoteEditorState`, `AppearanceControls`, `TintControls`, `ListFocus`) keep using `ObservableObject` with `@StateObject`. Converting them gains nothing.
- No UI tests. The UI is checked by hand against the specs.
- No CI setup.

## Decisions

### 1. SwiftPM targets in one package (modular monolith)

```
Notely (exe) --> NotelyUI --> NotelyLinks --> NotelyCore
                     |                            ^
                     +----------------------------+
NotelyCoreTests -------------------------------> NotelyCore
```

Alternatives: separate packages, which add version management with no benefit for a single app. Folders inside one target, which give no enforced boundaries. TCA or VIPER, which add a framework and ceremony that is out of proportion for about 4k lines.

### 2. `NoteStore` becomes `@Observable` in `NotelyCore`; minimum macOS 14

`NoteStore` holds `private(set) var notes: [Note]`, keeps every current mutation method and rule, and calls `repository.save(notes)` after each change, the same timing as today. Views take `let store: NoteStore` instead of `@ObservedObject`. SwiftUI tracks reads of `notes`, which has the same granularity as `@Published` today.

Alternative: keep macOS 13, put a pure `NoteCollection` struct in Core, and wrap it in an `ObservableObject` in the UI. That works, but it leaves two layers to keep in sync, and a future sync engine would depend on the UI module. The user chose macOS 14.

`TextAppearance` also moves to `@Observable` but stays in `NotelyUI`, because it depends on `NSFont` and SwiftUI `Font`. Converting it keeps one observation system for injected shared state.

### 3. `NoteRepository` protocol

```swift
public protocol NoteRepository {
    func load() -> [Note]   // includes legacy migration and clamping of damaged style runs
    func save(_ notes: [Note])
}
```

`UserDefaultsNoteRepository(defaults:)` moves today's `init` logic over unchanged: the `notes` key, fallback to one empty note on undecodable data, and migration of `noteText` and `panelOrigin`. Tests use an in-memory repository and a `UserDefaults(suiteName:)` instance. Style-run clamping stays in the load path, the same place as today.

Alternative: put the store's storage behind a file in Application Support now. Rejected because it changes data. That move is left to the GitHub change, behind this protocol.

### 4. What goes where

| Module | Contents |
|---|---|
| `NotelyCore` | `Note`, `ListItem`, `StyleRun`, `plainText(ofList:)`, `NoteStore`, `NoteRepository`, `UserDefaultsNoteRepository`, frame functions and size constants, `parsePair`, `savedSize`, `TintRGB` (hex tint parsing to RGB components), `listTitle`, `noteTitle`, `PageHead`, `linkPageKey(for:)` |
| `NotelyLinks` | `LinkDetector`, `DetectedLink`, `LinkPage`, `StoredLinkPage`, `LinkPageFetcher`, `LinkPageStore` |
| `NotelyUI` | All views and `NSView` subclasses, `TextAppearance`, `TextStyle` and `StyleTraits`, `NSColor` tint conversion and `tintPresets`, `LinkHoverController`, link card views and `LinkCardLayout`, the menu, `makeMainMenu`, window controllers, `AppDelegate`, `NotelyApp` |
| `Notely` | `main.swift`: builds the repository, `NoteStore`, `TextAppearance`, and `LinkPageStore`, and passes them to `NotelyApp.run`, which runs the app |

`NotelyCore` imports only Foundation and Observation, plus CoreGraphics where it exists: on macOS, `NSRect`'s members (`minX`, `contains`, the `x:y:` initializer) come from the CoreGraphics overlay, which `import Foundation` doesn't bring in. `PageHead` lives in Core because it is portable, and because it is the most valuable parser to test. It needed the link page key normalization, so that moved to Core as `linkPageKey(for:)`, and `LinkPageStore.key(for:)` calls it. `LinkDetector` stays in `NotelyLinks` because `NSDataDetector` doesn't exist on Linux.

`LinkCardLayout` has no view code, but it stays in `NotelyUI`: it holds the cards' drawing sizes, which belong with the card views rather than with fetching and caching.

### 5. Injection instead of singletons, with one exception

The composition root creates `LinkPageStore`. It is passed as an explicit parameter, like `store` and `appearance`: `WindowContent` to `NoteView` to `NoteEditor` to `NoteTextView.linkPages`, and `ListView` to `LinkCardAbove`, which observes it with `@ObservedObject`. Its `didLoad` notification stays as it is.

Alternative: a SwiftUI environment value or `@EnvironmentObject`. Rejected because a missing explicit parameter fails at compile time, while a missing environment object only crashes at runtime. An `@EnvironmentObject` in a representable would also re-run `updateNSView` on every page that arrives.

`LinkHoverController` stays a module-internal shared instance in `NotelyUI`. It wraps a process-wide `NSEvent` monitor and owns no data or I/O, so threading it through every text view would add plumbing without a seam anyone needs. System singletons (`NSColorPanel.shared`, `NSWorkspace.shared`) stay as they are.

### 6. Thin `AppDelegate`

`AppDelegate` keeps the app lifecycle: launch, reopen, the main menu, and the scroller-style observer. Two collaborators take over the rest:

- `NoteWindowController` owns the `[UUID: NoteWindow]` map, opening and closing windows, frame saving and resize limits, field editors, overlay scrollers, and the open, close, and delete-confirm flows.
- `MenuWindowController` owns the menu window and its frame. It absorbs `MenuWindowDelegate`.

The window delegate callbacks move with the windows they serve. If a split would change event order, keep that piece in `AppDelegate` and say so.

### 7. Manifest guards for Linux

`Package.swift` declares `NotelyCore` and `NotelyCoreTests` on every platform. It adds `NotelyLinks`, `NotelyUI`, and `Notely` only inside `#if os(macOS)`. `swift test` builds every target, so this is what lets it run on Linux.

Alternative: wrap each AppKit file in `#if canImport(AppKit)`. That's noisier and easy to forget in a new file.

### 8. Access control

Core and Links types become `public` only where another module uses them. Everything inside `NotelyUI` stays `internal` except `TextAppearance` with its `init()`, and `NotelyApp.run(store:appearance:linkPages:)`, the module's one entry point. `AppDelegate` stays internal: a public class must declare every method that satisfies a public protocol `public`, which would spread across all its delegate methods. `run` keeps the delegate alive with `withExtendedLifetime`, because `NSApplication` holds it weakly.

`run` is `@MainActor`. Top-level code in `main.swift` counts as nonisolated to the compiler, so `main.swift` calls it inside `MainActor.assumeIsolated`; top-level code always runs on the main thread.

Tests use the public API. Symbols that only tests use (`clamp`, `parsePair`, `plainText`, `defaultNoteSize`) are internal, and the tests reach them through `@testable import NotelyCore`.

### 9. Order of work: move first, then cut boundaries

Step 1 splits `main.swift` into files inside the existing target, with no code edits, so the diff is pure moves. Later steps create one module at a time, Core first, and build after each step. This way a build break always points at a single boundary.

## Risks / Trade-offs

- [The `@Observable` conversion changes when SwiftUI redraws, for example a view that read the store through a closure and no longer updates] → Convert in its own step, then run the manual checklist for lists, menu titles, and tints before going on.
- [The app can't be built in the `dkc` container, so the implementing agent can't compile] → Each task group ends with a build checkpoint that the user runs on the macOS host (`just build`, `just test`). The Core Linux check runs with `just test-linux` (Docker `swift:6.0`).
- [`public` spreads, and Core's API grows too wide] → Expose only what another module uses, and review the public symbols in the final task.
- [Saved data could drift during the repository move] → A fixture test decodes a JSON blob in today's format, covering a note, a list, styles, a tint, and legacy keys, and checks that re-encoding keeps the same keys.
- [Linux and macOS format frame strings differently] → Tests parse frame strings and compare numbers, never exact strings. The app keeps writing with the platform `NSStringFrom*`, the same as today.
- [The `NoteTextView` extraction (about 460 lines) touches links, appearance, and the store] → Move it last within the UI step, and change only its dependency injection.
- [Dropping macOS 13] → Accepted by the user.

## Migration Plan

- No data migration: keys, JSON shape, and the cache folder are unchanged.
- Deploy with the usual `just install`.
- Rollback: revert the change. Data written by the new build is readable by the old build, because the format didn't change. A rollback needs macOS 13 support again only if someone actually runs Ventura.
