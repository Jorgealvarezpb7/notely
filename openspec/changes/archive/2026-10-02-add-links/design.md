# Design

## Context

All code is in `Sources/Notely/main.swift`.

- **Notes:** `NoteTextView` is an `NSTextView` subclass hosted by `NoteEditor` in a `NoteScrollView`. Its text storage holds trait attributes (`notelyBold`, `notelyItalic`, `underlineStyle`) and display attributes that `restyle(_:)` derives from them; `restyle` calls `setAttributes`, which drops any other attribute. Runs are saved from the storage (`StyleTraits.runs`) and copied through a private pasteboard type. The view is created with `NSTextView(frame:)` and never touches `layoutManager`, so on macOS 13+ it runs on TextKit 2 (`textLayoutManager`).
- **Lists:** each title and item is a `ListTextField` (`NSTextField`) shown through `ListField`. While a row is not edited it shows `ListField.styled(...)`; while edited, AppKit's shared field editor (an `NSTextView`) holds the text. `ListField.Coordinator` already uses the field editor's `layoutManager` for caret lines.
- **Windows:** `AppDelegate` is every note and list window's delegate. `openWindow` builds `NoteWindow`s with `.titled`, transparent title bar, `safeAreaRegions = []`.
- The app is not sandboxed, the deployment target is macOS 13, and Info.plist has no App Transport Security keys.

## Goals / Non-Goals

**Goals:**
- One detector, one hover and preview controller, and one click rule, used by notes and lists.
- No change to saved data, undo, copy, or paste.

**Non-Goals:**
- Links with custom text (Markdown or rich-text anchors), editing a link's target, or a "Copy Link" menu.
- Email, phone, or file links.
- Previews in the menu window.
- A preference to turn links off.

## Decisions

### 1. Detection: `NSDataDetector` with a web-only filter

A `LinkDetector` wraps one shared `NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)` and returns `[(NSRange, URL)]` for a string, keeping only results whose URL scheme is `http` or `https` (the detector gives bare domains an `http` scheme and emails a `mailto` scheme, which is dropped). Detection runs on the whole string on every change; notes and rows are small, so no incremental work is needed.

Alternative: a hand-written regular expression. Rejected: `NSDataDetector` already knows top-level domains and trailing punctuation rules, and matches what other macOS apps underline.

### 2. Notes: draw links with rendering attributes, not storage attributes

Links are shown with TextKit 2 rendering attributes on `textLayoutManager`: `.foregroundColor = .linkColor` and `.underlineStyle = single` for each detected range, removed and re-added for the whole document after `load`, `applyAppearance`, `didChangeText`, and paste. Rendering attributes live in the layout manager, so they never reach `textStorage`: `restyle`, `runs`, saving, undo, and the pasteboard code see no change, and the trait-based styling stays the single source of truth.

Code MUST NOT read `NoteTextView.layoutManager`: that switches the view to TextKit 1 for good. If `textLayoutManager` is `nil` (a future fallback), use `layoutManager.addTemporaryAttributes` instead, which has the same storage-free behavior.

Alternative: adding `.link` to the text storage. Rejected: `restyle` would strip it, `StyleTraits.runs` and RTF copy would carry it, and every edit would add attribute changes to undo. It would also make `NSTextView` open links on a plain click.

### 3. Lists: links in `styled` and in a custom field editor

- **Not editing:** `ListField.styled(...)` adds `.foregroundColor = .linkColor` and `.underlineStyle` to detected ranges, after the strikethrough for checked items. This is the attributed value the field shows, and `sizeThatFits` already measures with it (color and underline do not change size).
- **Editing:** `AppDelegate.windowWillReturnFieldEditor(_:to:)` returns, for a `ListTextField` client, one `LinkFieldEditor` per window (a TextKit 1 `NSTextView` subclass with `isFieldEditor = true`, plain text, and undo, like AppKit's own), and `nil` for anything else so AppKit uses its default. `LinkFieldEditor` shows links with the same rendering-attribute code as `NoteTextView` (shared in a small `LinkDisplay` helper used by both), refreshed in `didChangeText` and when editing begins.

Alternative: one `NSTextView` per row instead of `NSTextField`. Rejected: it rewrites the list's keyboard handling, which works today.

### 4. Finding the link under the pointer

Each link host answers `link(at point: NSPoint) -> (URL, NSRect)?` in its own coordinates:

- `NoteTextView` and `LinkFieldEditor`: `characterIndexForInsertion(at:)` gives the nearest index; the link whose range contains that index, or the index before it, counts only if the point lies inside the link's bounding rect from `firstRect(forCharacterRange:actualRange:)` converted from screen to view coordinates. This works on TextKit 1 and 2 and avoids reading `layoutManager`.
- `ListTextField` while not editing: lay out its attributed value in a throwaway TextKit 1 stack (`NSTextStorage`, `NSLayoutManager`, `NSTextContainer` with the width of `cell.titleRect(forBounds: bounds)` and the cell's line fragment padding) and hit-test there. While editing, the field editor answers instead.

A protocol `LinkHost` with this one method lets the controller in Decision 5 treat all three the same.

### 5. One controller for Cmd, pointer, and preview

`LinkHoverController` (one shared instance, started by `AppDelegate` at launch) installs a local event monitor for `.flagsChanged`, `.mouseMoved`, `.scrollWheel`, `.keyDown`, and `.leftMouseDown`, and observes `NSApplication.didResignActiveNotification`. Note windows set `acceptsMouseMovedEvents = true`.

- On `.flagsChanged` and `.mouseMoved`: if Cmd is held, hit-test the window's content view at the event location, walk up to the first `LinkHost`, and ask it for a link. A local monitor receives events only while Notely is active, which matches the spec.
- Over a link with Cmd: set `NSCursor.pointingHand`. Text views reset the cursor to the I-beam in their own `mouseMoved`, which runs after the monitor, so the hosts override `mouseMoved`/`cursorUpdate` to call `super` and then let the controller re-apply the pointing hand while it is active.
- Start a 0.5 s timer when the pointer reaches a new link with Cmd held. When it fires, show the preview (Decision 6). Leaving the link, releasing Cmd, scrolling, typing, any click, or the app resigning active cancels the timer and closes the card.

Alternative: tracking areas on every host. Rejected: Cmd changes arrive as `flagsChanged` at the first responder, not the view under the pointer, so a central monitor is needed anyway.

### 6. Preview: LinkPresentation in an `NSPopover`

- `LinkPreviewStore` caches `LPLinkMetadata` by URL for the session and keeps at most one `LPMetadataProvider` per URL in flight (`timeout = 10`). A provider is created only when a preview is about to show.
- The card is an `NSPopover` (`behavior = .applicationDefined`, so the controller alone closes it, and `animates = false`) whose content view controller hosts an `LPLinkView`: built with `LPLinkView(url:)` while loading, which shows the address, and given the metadata when it arrives. On failure it stays on the address. Width 300 pt. A page with an image gets a standard height: 157 pt for the image (the 1.91:1 shape of page preview images) plus 64 pt for title and site. Otherwise the height comes from the link view, 80 pt at least while loading. The link view is pinned with Auto Layout inside a container of that size, and the controller sets the open popover's `contentSize` on every height change: an open `NSPopover` keeps the size it opened with, so a card that opened at the loading height stayed a thin strip once the image arrived.
- The popover is shown `relativeTo:` the link's rect in the host view, `preferredEdge: .maxY` in the host's coordinates, so AppKit places it next to the link and flips it when there is no room.
- An `NSPopover` does not become key, so keyboard focus stays in the note or row.

### 7. Opening

On `mouseDown` with Cmd held, each host asks itself for a link at the click point; if there is one, the controller closes the card, `NSWorkspace.shared.open(url)` runs, and the host returns without calling `super`, so no caret move, selection, editing start, or drag happens. Otherwise it calls `super`. `acceptsFirstMouse` already returns `true` for `NoteTextView`; `ListTextField` gets the same override so Cmd+click works while Notely is not active.

## Risks / Trade-offs

- [Reading `layoutManager` on `NoteTextView` would silently switch it to TextKit 1 and could change text layout] → Decision 2 forbids it; review the diff for `layoutManager` uses on the note view.
- [Rendering attributes are dropped by TextKit 2 when the text in their range changes] → Links are recomputed for the whole text after every change (Decision 2).
- [Hit-testing a non-editing `NSTextField` with a separate layout can be off by the cell's insets] → Use `titleRect(forBounds:)` and the cell's padding; verify with long, wrapped items on the Mac and adjust the offset if clicks miss.
- [`http://` pages may fail to load under App Transport Security] → The card then shows the address alone, which the spec allows. Do not add ATS exceptions.
- [Preview requests reveal to the linked site that the user looked at the link] → Requests happen only on an explicit Cmd-hover, never in the background.
- [`LPLinkView` sizes itself asynchronously after metadata arrives] → Use a fixed standard height for cards with an image (Decision 6); the popover follows `preferredContentSize` when it changes.
- [No automated tests] → Verify on the Mac with `just run`.
