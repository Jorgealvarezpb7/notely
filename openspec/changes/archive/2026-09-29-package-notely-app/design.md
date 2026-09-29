# Design

## Context

All app code is in `Sources/FloatingWidget/main.swift`. `Package.swift` declares one executable target, `FloatingWidget`, for macOS 13. There is no app bundle and no `Info.plist`, so `Bundle.main.bundleIdentifier` is `nil` and `UserDefaults.standard` uses the domain `FloatingWidget` (`~/Library/Preferences/FloatingWidget.plist`). The app hides its Dock icon at runtime with `app.setActivationPolicy(.accessory)`.

The `justfile` `build` recipe runs `swift run -c release`, which builds and also launches the app. `run` depends on `build`, then launches `.build/release/FloatingWidget` a second time after the first instance quits.

The development container (`just dkc`) is Linux. It has no Swift toolchain, and it has no AppKit, `codesign`, `plutil`, or `osascript`, so bundle recipes must run on the host Mac.

See proposal.md for motivation. This change has no spec deltas (`skip_specs: true`); the existing main specs must stay true for the bundled app.

## Goals / Non-Goals

**Goals:**
- One copy of the app, at `~/Applications/Notely.app`. Every `just run` replaces it.
- Recipes that are safe to run again and again: with or without a running Notely, and with or without an existing `~/Applications`.
- No new dependencies or build systems. SwiftPM stays the only build system, and the app code stays in one file.

**Non-Goals:**
- A universal (arm64 + x86_64) binary. The bundle holds the host architecture only.
- Hardened runtime, App Sandbox, or an update mechanism.
- Reading any data from the old `FloatingWidget` domain.

## Decisions

### 1. Full rename to Notely
`git mv Sources/FloatingWidget Sources/Notely`. In `Package.swift`, rename the package and the executable target to `Notely`, with path `Sources/Notely`. The binary becomes `.build/release/Notely`. In `main.swift`, the two "Quit FloatingWidget" menu items become "Quit Notely", and the status item image's accessibility description becomes "Notely".

Alternative: change only the bundle's display name and keep the target name. Rejected: the executable inside the bundle would keep the old name for good, and the rename touches only six references now.

### 2. Bundle assembled by the `justfile` from an `Info.plist` template
Add `Packaging/Info.plist` to the repository with these keys: `CFBundleIdentifier` = `com.alvarezjorge.Notely`, `CFBundleName` and `CFBundleDisplayName` = `Notely`, `CFBundleExecutable` = `Notely`, `CFBundlePackageType` = `APPL`, `CFBundleInfoDictionaryVersion` = `6.0`, `CFBundleShortVersionString` = `0.1.0`, `CFBundleVersion` = `1`, `LSMinimumSystemVersion` = `13.0`, `LSUIElement` = `true`.

`just build`:
1. `swift build -c release` (builds only, does not launch).
2. Recreate `.build/Notely.app/Contents/MacOS/`, copy `.build/release/Notely` into it, and copy `Packaging/Info.plist` to `Contents/Info.plist`.
3. Sign (Decision 3).

Each recipe starts with a guard that stops with a clear message when `uname` is not `Darwin`, so a run in the dkc container fails early.

Keep `app.setActivationPolicy(.accessory)` in `main.swift`. `LSUIElement` hides the Dock icon from the first moment of launch. The runtime call keeps the bare binary Dock-less if someone runs it directly while debugging.

Alternatives: an Xcode project (rejected: a second build system and `project.pbxproj` churn for a one-file app); a bundler package such as swift-bundler (rejected: a new dependency for about 15 lines of shell); embedding `Info.plist` into the binary with the `-sectcreate` linker flag (rejected: it needs `unsafeFlags`, and the app still would not be a bundle that Finder, Spotlight, and Launchpad can open).

### 3. Ad-hoc signature over the whole bundle
After the bundle is assembled: `codesign --force --sign - .build/Notely.app`. This seals `Info.plist` into the signature, which the linker's own ad-hoc signature on the bare binary does not do. The recipe then runs `codesign --verify .build/Notely.app` and fails if it does not pass. There is no certificate, no Developer ID, and no notarization. An app built locally never gets a quarantine attribute, so Gatekeeper does not block it.

Alternative: a self-signed code-signing certificate, which keeps the code identity stable across builds. Deferred by the user's choice. A later launch-at-login change may need it.

### 4. `install` and `run` recipes keep one copy
`just install` (depends on `build`):
1. Quit a running Notely only if it runs: `osascript -e 'if application id "com.alvarezjorge.Notely" is running then tell application id "com.alvarezjorge.Notely" to quit'`. The `is running` guard keeps AppleScript from launching Notely just to quit it. `quit` goes through `NSApp.terminate(_:)`, so it is a normal quit and saves data like every other quit path.
2. Wait until `pgrep -x Notely` finds no process, for at most 10 seconds, then fail with a message. Without the wait, `open` in `run` would bring the old instance forward instead of starting the new build.
3. `mkdir -p ~/Applications`, `rm -rf ~/Applications/Notely.app`, and `ditto .build/Notely.app ~/Applications/Notely.app`.

`just run` depends on `install` and then runs `open ~/Applications/Notely.app`.

Alternative: a separate development copy in `.build/Notely.app` next to the installed one. Rejected in exploration: both copies would share one bundle ID and one defaults domain.

## Risks / Trade-offs

- [The first `osascript` quit may show an Automation permission prompt ("Terminal wants to control Notely")] → Allow it once. If it is denied, the recipe's wait step times out with a message. The fix is System Settings > Privacy & Security > Automation.
- [An old FloatingWidget instance still running when Notely launches shows a second panel] → Quit FloatingWidget before the first `just run`. After the rename, `.build/release/FloatingWidget` is stale and can be deleted.
- [The FloatingWidget note text and position are lost from the user's view] → Accepted by the user. The data stays in `~/Library/Preferences/FloatingWidget.plist` and is not deleted.

## Migration Plan

1. Quit FloatingWidget.
2. Run `just run`. Notely opens with an empty note at the default position.
3. Optionally delete `.build/release/FloatingWidget`.

Rollback: quit Notely and delete `~/Applications/Notely.app`. Then revert the change and run the old `just run`. The old binary reads the untouched `FloatingWidget` domain.
