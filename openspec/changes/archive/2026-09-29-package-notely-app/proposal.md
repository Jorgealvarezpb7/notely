# Proposal

## Why

The app runs only as a bare binary started from a terminal with `just run`. It has no app bundle, so it cannot be opened like other apps, from Finder, Spotlight, or Launchpad. For personal daily use, the note must be an installed app. The app is also renamed to Notely, because it is now a sticky note, not a generic widget. A bundle is also what a later change needs to add launch at login.

## What Changes

- **BREAKING** (user-visible): rename the app from FloatingWidget to Notely. This covers the Swift package, the executable target, the source directory, the binary, and the "Quit" menu items.
- **BREAKING** (user-visible): Notely stores its data under its bundle ID, not under the `FloatingWidget` defaults domain. The note text and panel position that FloatingWidget saved are not carried over, so Notely starts with an empty note at the default position. The old data stays unused in the `FloatingWidget` domain.
- Package the app as `Notely.app` with bundle ID `com.alvarezjorge.Notely`, version 0.1.0, and `LSUIElement` set, so it shows no Dock icon from the first moment of launch.
- Sign the bundle with an ad-hoc signature (`codesign -s -`). No certificate, no Developer ID, no notarization.
- Rework the `just` recipes: `build` assembles and signs the bundle without launching it, `install` replaces `~/Applications/Notely.app` (quitting a running Notely first), and `run` installs and opens it. There is one copy of the app. This also fixes the current `build` recipe, which launches the app through `swift run`.

Out of scope: launch at login, carrying data over from FloatingWidget, an app icon, certificate signing, notarization, a DMG or other distribution, and a separate development copy of the app.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
<!-- None -->

No spec-level behavior changes, so this change sets `skip_specs: true`. The specs never name the app, and the existing requirements (including "no Dock icon" in `sticky-note` and `app-controls`) stay true for the bundled app. Packaging (bundle layout, signing, `just` recipes, install location) is build tooling and is described in design.md and tasks.md.

## Impact

- Code: `Sources/FloatingWidget/main.swift` moves to `Sources/Notely/main.swift`. Only menu titles and one accessibility description change in it.
- Build: `Package.swift` renames the package and the target. `justfile` gets new `build`, `install`, and `run` recipes. A new `Info.plist` template is added to the repository. The recipes need macOS tools (`codesign`, `plutil`, `osascript`), so they run on the host Mac, not in the dkc Linux container.
- Storage: the defaults domain changes from `FloatingWidget` to `com.alvarezjorge.Notely`.
- Dependencies: none added. Target stays macOS 13.
