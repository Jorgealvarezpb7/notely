# Tasks

The project has no test target, so each task is verified with a command and a manual check on the host Mac. The recipes do not run in the dkc Linux container.

## 1. Rename to Notely

- [ ] 1.1 Run `git mv Sources/FloatingWidget Sources/Notely`, and rename the package and the executable target in `Package.swift` to `Notely` with path `Sources/Notely` (design.md Decision 1); verify `swift build -c release` succeeds and `.build/release/Notely` exists
- [ ] 1.2 In `Sources/Notely/main.swift`, change both "Quit FloatingWidget" menu items to "Quit Notely" and the status item image's accessibility description to "Notely"; verify `grep -rn FloatingWidget Sources Package.swift` prints nothing and `swift build -c release` succeeds

## 2. Bundle build

- [ ] 2.1 Add `Packaging/Info.plist` with the keys listed in design.md Decision 2; verify `plutil -lint Packaging/Info.plist` reports OK
- [ ] 2.2 Replace the `build` recipe in `justfile` with the three steps in design.md Decision 2 (build only, assemble `.build/Notely.app`, sign per Decision 3 and run `codesign --verify`), with the `uname` guard at the start; verify `just build` does not launch the app, `plutil -p .build/Notely.app/Contents/Info.plist` shows the bundle ID and `LSUIElement` true, and `codesign -dv .build/Notely.app` shows `Identifier=com.alvarezjorge.Notely` and `Signature=adhoc`
- [ ] 2.3 Run `just build` inside `just dkc`; verify it stops at once with the guard's "run on the macOS host" message

## 3. Install and run recipes

- [ ] 3.1 Add the `install` recipe per design.md Decision 4 (quit only if running, wait up to 10 seconds, `mkdir -p ~/Applications`, replace with `ditto`); with Notely not running and no `~/Applications` folder (rename it first if it exists), run `just install`; verify Notely does not launch and `~/Applications/Notely.app` exists. Allow the Automation prompt if macOS shows it
- [ ] 3.2 Replace the `run` recipe so it depends on `install` and then runs `open ~/Applications/Notely.app`; quit FloatingWidget, run `just run` twice in a row; verify only one Notely process runs after each (`pgrep -x Notely | wc -l` prints 1), `stat -f %m ~/Applications/Notely.app/Contents/MacOS/Notely` prints a newer time after the second run, and app-controls scenario "Menu bar item at launch" passes with "Quit Notely" in the menu

## 4. Integration

- [ ] 4.1 On Notely's first launch, verify sticky-note scenario "First launch" (empty note with placeholder) and "First launch position" (default top-right position)
- [ ] 4.2 Run `openspec validate package-notely-app --strict`, then walk every scenario in the main `openspec/specs/app-controls/spec.md` and `openspec/specs/sticky-note/spec.md` on the final installed build; verify all pass, including "Standard editing shortcuts", "Relaunch keeps position", and "Quitting keeps note text"
