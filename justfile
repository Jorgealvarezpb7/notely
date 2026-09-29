set dotenv-load
set positional-arguments

app := "Notely.app"
bundle_id := "com.alvarezjorge.Notely"

# List Tasks
default:
    just --list

# Runs the Development-Kit Container
dkc:
    docker pull ghcr.io/leoborai/dkc:latest
    docker run -it --rm \
        -v $(pwd):/app \
        -w /app \
        ghcr.io/leoborai/dkc:latest

# Stops early outside macOS: the dkc container has no AppKit or codesign
_macos:
    @[ "$(uname)" = Darwin ] || { echo "error: run this recipe on the macOS host, not in the dkc container" >&2; exit 1; }

# Builds and ad-hoc signs .build/Notely.app without launching it
build: _macos
    swift build -c release
    rm -rf {{app}}
    mkdir -p {{app}}/Contents/MacOS
    cp .build/release/Notely {{app}}/Contents/MacOS/Notely
    cp Packaging/Info.plist {{app}}/Contents/Info.plist
    codesign --force --sign - {{app}}
    codesign --verify {{app}}

# Replaces ~/Applications/Notely.app, quitting a running Notely first
install: build
    #!/usr/bin/env bash
    set -euo pipefail
    # Quit through Apple Events so Notely terminates normally and saves.
    if pgrep -x Notely >/dev/null; then
        osascript -e 'tell application id "{{bundle_id}}" to quit'
    fi
    # Wait for the old process to exit, or `open` would bring it forward
    # instead of starting the new build.
    for _ in $(seq 1 100); do
        pgrep -x Notely >/dev/null || break
        sleep 0.1
    done
    if pgrep -x Notely >/dev/null; then
        echo "error: Notely did not quit within 10 seconds" >&2
        exit 1
    fi
    mkdir -p ~/Applications
    rm -rf ~/Applications/Notely.app
    ditto {{app}} ~/Applications/Notely.app

# Installs and opens Notely
run: install
    open ~/Applications/Notely.app
