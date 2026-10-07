# Proposal

## Why

All of Notely lives in one 3,678-line `Sources/Notely/main.swift` with no tests. Domain rules, persistence, networking, and AppKit views sit side by side, so nothing can be unit-tested and every feature touches the same file. A planned GitHub integration (list issues from repositories in lists, and close an issue when its item is checked) needs clean seams to attach to: one path for every note change, storage behind an interface, and feature modules that do not depend on the UI. Splitting the code now, while it is still small, is cheaper than after that integration lands.

## What Changes

- Split the single executable target into SwiftPM modules with one-way dependencies:
  - `NotelyCore` (Foundation only, builds and tests on Linux): the note model, every note and list mutation rule, the note store, a `NoteRepository` protocol with the `UserDefaults` implementation and legacy migration, window frame math, saved-value parsing, and the link page head parser.
  - `NotelyLinks` (macOS): link detection, link page fetching, and the link page cache.
  - `NotelyUI` (AppKit + SwiftUI): windows, editor, lists, menu, chrome, link hover and cards, text appearance.
  - `Notely` (executable): the composition root that builds and wires every dependency.
- Turn `NoteStore` from an `ObservableObject` into an `@Observable` class in `NotelyCore` that loads and saves through an injected `NoteRepository`.
- Replace the `LinkPageStore.shared` singleton with an instance that the composition root creates and injects.
- Move window management out of `AppDelegate` into dedicated controllers.
- Add a `NotelyCoreTests` test target and a `just test` recipe. The tests include a fixture of notes saved in today's format, to prove saved data still loads.
- **BREAKING**: raise the minimum macOS version from 13 (Ventura) to 14 (Sonoma) in `Package.swift` and `Packaging/Info.plist`. `@Observable` needs macOS 14.
- No user-visible behavior changes. Saved notes, lists, styles, tints, window frames, text appearance, and the link page cache stay in the same keys and formats.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is a structural refactor: no spec requirement changes, so the change sets `skip_specs: true`. The macOS 14 minimum version is a platform constraint that no current spec states.

## Impact

- **Code**: `Sources/Notely/main.swift` is replaced by files under `Sources/NotelyCore`, `Sources/NotelyLinks`, `Sources/NotelyUI`, and `Sources/Notely`. Tests are added under `Tests/NotelyCoreTests`.
- **Build**: `Package.swift` gains three library targets and one test target. `justfile` gains a `test` recipe. `just build` and `just install` keep producing the same `Notely.app`.
- **Platform**: Notely no longer runs on macOS 13.
- **Data**: no migration. The `UserDefaults` keys (`notes`, `textFontFamily`, `textFontSize`, `menuFrame`, and the legacy `noteText` and `panelOrigin`) and the link page cache folder stay the same.
- **Future work**: a `NotelyGitHub` module can sit beside `NotelyLinks`, depend only on `NotelyCore`, and observe the store. That work is out of scope here.
