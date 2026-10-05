# Tasks

All code is in `Sources/Notely/main.swift`. Build and run steps need the macOS host. There is no test target, so verification is `swift build` plus checks in the running app (`just run`).

## 1. Page information store

- [x] 1.1 Add a `LinkPage` value type with title, description, an optional image, and an optional icon, plus a head-parsing function that reads the og, twitter, `<title>` and `meta description` tags and the icon links. It resolves relative URLs and decodes entities. Verify: `swift build` succeeds, and a temporary debug call that parses saved HTML of crunchyroll.com and example.com prints the expected title, description, image URL, and icon URL.
- [x] 1.2 Add `LinkPageStore` (`ObservableObject` singleton). It upgrades http to https and makes one `URLSession` GET per address with a 10 s timeout and a 1 MB cap. It downloads the image and the icon, keeps at most 4 requests in flight, shares requests in flight, and remembers failures in memory for the session. Verify: in the running app, a debug request for https://crunchyroll.com publishes a page, and one for an unreachable host publishes nothing and is not retried in the same session.
- [x] 1.3 Add the disk cache under `~/Library/Caches/com.alvarezjorge.Notely/LinkPages/`: `index.json` plus image files named by SHA-256, with images downscaled to at most 600 pt wide. It loads at launch and saves after each success, and never stores failures. Verify: after a fetch, the folder holds the index and the image files; after a relaunch, the page is available without a network request (check with Little Snitch, or with the network off).

## 2. Card above note paragraphs

- [x] 2.1 Spike: make `NoteTextView` the delegate of its `NSTextContentStorage` and return a paragraph with a fixed 100 pt `paragraphSpacingBefore` for paragraphs that contain a link. Verify in the running app that space shows above both the first paragraph and a later one, and that the caret, selection, and up/down arrows skip the space. If the first paragraph gets no space, use the top `textContainerInset` for it, as design Decision 1 describes.
- [x] 2.2 Add `LinkCardLayout.height(for:width:)` and the SwiftUI `LinkCard`: image at 1.91:1, aspect-fill and clipped; bold title of at most 2 lines; gray description of at most 4 lines ending in "…"; footer with the `link` symbol, the domain without "www.", and a round 18 pt icon at the trailing edge; compact layout without an image. Verify: SwiftUI previews or a debug window show the full card, the compact card, and a card with no description, and each drawn height equals `LinkCardLayout.height` at widths 190, 300, and 500.
- [x] 2.3 Replace the fixed spike spacing with each paragraph's first-link card height from `LinkCardLayout`, only when `LinkPageStore` has that link's page. Invalidate the paragraph's layout when a page arrives, when the width changes, and when the font setting changes. Verify: in a note, "see https://crunchyroll.com" gets exactly the card's height of space above it, and "apple.com or crunchyroll.com" gets space for one card.
- [x] 2.4 Add `LinkCardHost` (an `NSHostingView` around `LinkCard`) and place a host per paragraph after layout, at the fragment's top minus the card height and the full text width. Remove hosts whose paragraph lost its link. Verify: cards sit directly above their lines while typing, scrolling, resizing the note, and changing the font, and deleting the address removes the card and pulls the text up.
- [x] 2.5 Make card clicks open the link: `acceptsFirstMouse` returns true, `mouseDown` opens the URL with `NSWorkspace`, and a pointing-hand cursor rect covers the card. Verify: clicking a card opens the browser without moving the caret or selection, also while Notely is inactive, and the pointer is a hand over the card.
- [x] 2.6 Add the 1 s debounced request after text changes, and the immediate request on `load(text:runs:)`. Verify: typing "crunchyroll.com" one character at a time sends one request about 1 s after the last key, and opening a note with links requests its pages at once.
- [x] 2.7 Verify display only: copying text across a card puts only text on the pasteboard, undo/redo never touches cards, and the saved note in `UserDefaults` is unchanged after cards show and after a relaunch.

## 3. Cards in lists

- [x] 3.1 In `ListView.rowView(_:)`, wrap each item in a `VStack` that shows `LinkCard` above the `HStack` for the item's first link once its page is stored, indented to the text column. Do the same for the list title, without the indent. Verify: "buy at store.example.com" shows a card above the item's text, with the check circle still beside the text, and the title shows a card too.
- [x] 3.2 Add the tap-to-open and hover pointing hand on the list card, and the 1 s debounced request on item and title edits. Verify: clicking a list card opens the browser without starting row editing, and a typed address fetches once after typing stops.

## 4. Remove the Cmd+hover preview

- [x] 4.1 Remove the timer, `showPreview()`, and the popover from `LinkHoverController`, and delete `LinkPreviewStore`, `LinkPreviewViewController`, and `import LinkPresentation`. Keep the Cmd pointing hand and Cmd+click. Verify: `swift build` succeeds with no `LinkPresentation` references, holding Cmd over a link shows the hand and no popover, and Cmd+click still opens links.
- [x] 4.2 Update the Purpose of `openspec/specs/links/spec.md` to describe always-visible preview cards instead of a preview while Cmd is held. Verify: `openspec validate link-preview-cards --strict` passes.

## 5. Integration check

- [x] 5.1 End-to-end on the macOS host with `just run`, going through the spec scenarios in `specs/links/spec.md`:
  - a note with two link paragraphs;
  - a list with a link item and a link title;
  - the network turned off with an uncached address (no card, no error);
  - a relaunch (cards show at once);
  - a failed page shown again after a relaunch.
  
  Verify: every scenario behaves as written.
