# Design

## Context

All link code lives in `Sources/Notely/main.swift` under `// MARK: Links`:

- `LinkDetector` finds http and https links with `NSDataDetector`. A bare domain is given `http://`.
- `NSTextView.showLinks()` draws links with TextKit 2 rendering attributes, falling back to TextKit 1 temporary attributes. The text storage holds exactly the saved text and styles; nothing display-only may enter it.
- `LinkHoverController` handles the Cmd pointer and the Cmd+hover popover. `LinkPreviewStore` caches `LPLinkMetadata` in memory for the session. `LinkPreviewViewController` wraps `LPLinkView`.
- Notes use `NoteTextView` (an `NSTextView`) inside `NoteScrollView`. The view used to be created with `init(frame:)`, which in practice gave a TextKit 1 view (no `textLayoutManager`, no `textContentStorage`).
- Lists are SwiftUI: `ListView` stacks `ListField` rows (an `NSTextField`, `ListTextField`) in a `VStack` inside a `ScrollView`. `rowView(_:)` lays out the check circle and the field in an `HStack`.
- The app is not sandboxed. `Packaging/Info.plist` has no App Transport Security keys, so `URLSession` refuses plain `http://` loads.
- There is no test target. Behavior is checked by running the app (`just run`, macOS only).

## Goals / Non-Goals

**Goals:**
- A card above each paragraph with a link, laid out with real text-layout space, so the caret, selection, hit testing, and scrolling stay correct.
- One page fetch per address, shared by every note and row, with results kept on disk.

**Non-Goals:**
- Expiring or refreshing stored page information. Once stored, an entry is used until macOS clears the Caches folder.
- Video or animated previews, or site-specific layouts.
- Cards in the TextKit 1 fallback. A note that has fallen back to TextKit 1 shows links without cards.
- Size limits or eviction for the disk cache.

## Decisions

### 1. Space above a paragraph: a display-only paragraph style from the content storage delegate

`NoteTextView` becomes the delegate of its `NSTextContentStorage`. In `textContentStorage(_:textParagraphWith:)`, a paragraph whose first link has stored page information is returned as an `NSTextParagraph` copy whose paragraph style adds `paragraphSpacingBefore` equal to the card's height plus a gap. All other paragraphs return `nil`, so the default is used.

This delegate shapes only what TextKit lays out; the text storage is not touched. Layout, caret movement, hit testing, and selection all see the extra space, so the caret never stops inside it.

Alternatives considered:
- **`NSTextAttachment` in the storage**: changes the saved text, undo, and copy. Rejected.
- **A custom `NSTextLayoutFragment` with a taller frame**: the line fragments still sit at the top, so drawing and hit testing would have to be offset by hand. The paragraph-style route moves the lines for real.
- **Cards stacked below all the text**: rejected by the user; cards go above their link.

The text view is created with `NoteTextView(usingTextLayoutManager: true)`, so it is on TextKit 2 from the start. `init(frame:)` produced a TextKit 1 view, where none of this runs.

The first paragraph needed no special case: TextKit 2 honors `paragraphSpacingBefore` on it too, as task 2.1 confirmed.

### 2. Card views live in the text view and follow layout

Each card is a `LinkCardHost` (see Decision 5) added as a subview of `NoteTextView`. For each paragraph with a card, the text view looks up its layout fragment (`textLayoutFragment(for:)`) and places the card above the paragraph's first line:

- **Vertical position:** the fragment's top plus its first line's top, minus the gap and the card height. This works whether TextKit puts the paragraph spacing inside the fragment or above it.
- **Horizontal position:** at the line's left edge, as wide as the lines.
- **Reuse:** card views are reused in text order. Extra ones are removed when a paragraph loses its link.

**When cards are placed:**
- In an override of `layout()`, after `super.layout()`. That way cards follow the text view's own on-screen layout, the one that is drawn.
- After text changes, load, and font changes.

Placing cards from a separate `ensureLayout` pass right after a change left them where that pass said, while the drawn text stayed where the on-screen layout had put it. The two did not agree again until a later event, which the user saw as a 10-second "break" after a resize.

**Changing the space for a card.** The space is only re-read when TextKit asks the delegate for a paragraph again. To make it ask, `relayoutCards()`:
1. computes each card paragraph's height at the current width;
2. compares it with the height last laid out (`cardRooms`, cleared after every text edit, because paragraphs move);
3. marks only the changed paragraphs edited (`edited(.editedAttributes, …, changeInLength: 0)`), inside `textContentStorage.performEditingTransaction`;
4. sets `needsLayout`, so the cards are placed after the text view's own layout.

This runs when page information arrives (`LinkPageStore.didLoad`) and when the width changes (coalesced to one run per run-loop turn from `setFrameSize`). Marking a range edited without changing it registers no undo and leaves the saved text alone.

**Card width** is computed from the text view's `bounds`, not `textContainer.size`. A resize sets `bounds` at once, but the text container follows only on the next layout. Reading the container gave cards the old width and stored that as "unchanged", so cards stayed narrow.

### 3. Card height is computed for a width, not measured after layout

`LinkCardLayout` exposes `static func height(for: LinkPage, width: CGFloat) -> CGFloat`. It adds up the parts:

- the image height, `width / 1.91`, only when there is an image;
- padding;
- the title height and the description height (at most 4 lines), each measured with `NSAttributedString.boundingRect` at the inner width;
- the footer height.

The content storage delegate, the note card frame, the list card frame, and the SwiftUI card's own section heights all use these functions, so the space in the text and the drawn card always match.

Text measurements and card heights are cached by text, font, and width, because one layout pass asks for the same height several times. The cache is cleared when it grows past a few hundred entries.

### 4. Card look

- **Background:** a rounded rectangle, radius 8, filled with `labelColor` at about 6% opacity, so it works on every note tint and in dark mode.
- **Image:** clipped to the card's top corners, aspect-fill at 1.91:1.
- **Title:** system font, 13 pt semibold, `labelColor`, at most 2 lines.
- **Description:** system font, 13 pt, `secondaryLabelColor`, at most 4 lines, truncated with "…".
- **Footer:** SF Symbol `link`, then the domain (the host without "www."), in `secondaryLabelColor`. The site icon is 18 pt, round, at the trailing edge.
- **Fonts:** the card uses the system font at fixed sizes, independent of the note's font setting, as WhatsApp's card is independent of the message text.
- **Pointer:** in notes, `LinkCardHost` sets the pointing hand with a cursor rect. It returns `true` from `acceptsFirstMouse`, and its `mouseDown` opens the URL with `NSWorkspace` without calling `super`, so the text view never sees the click. Lists use the same `LinkCardHost` (wrapped in an `NSViewRepresentable`), so a first click also works while Notely is inactive, which a SwiftUI tap gesture does not do.

### 5. One SwiftUI card, two hosts

The card is one SwiftUI view, `LinkCard`, so notes and lists look the same.

- **`LinkCardHost`:** a plain `NSView` that holds an `NSHostingView<LinkCard>` (with `sizingOptions = []`, so the frame is ours) and takes every click inside it through `hitTest`. It replaces the hosting view's root only when the page or address changes, so a resize just resizes it.
- **Notes:** the text view places `LinkCardHost` views (Decision 2).
- **Lists:** `LinkCardAbove` wraps the item's row, or the title field, in a `VStack`. When the first link has stored page information, it shows `LinkCardRow` above the row: an `NSViewRepresentable` around `LinkCardHost`, whose `sizeThatFits` returns the height from `LinkCardLayout`. Items indent it to the text column (circle width 24 plus spacing 6); the title does not. `LinkCardAbove` observes `LinkPageStore`, so rows update when information arrives.

Alternative: a hand-drawn AppKit card for notes plus a SwiftUI card for lists. Rejected, because two implementations of the same look would drift apart.

### 6. Page information: our own fetch, not LinkPresentation

`LPLinkMetadata` exposes no description, so `LPMetadataProvider` is replaced. `LinkPageStore` (an `ObservableObject` singleton) works like this:

- **Address:** an `http` URL is upgraded to `https` before fetching, because ATS blocks plain http and we do not add an ATS exception.
- **Page:** one `URLSession` GET with the user agent `Notely/0.1 (link preview) facebookexternalhit/1.1`, a 10 s timeout, and the HTML read only until `</head>` or 1 MB. Many sites send browsers a bare app shell with a generic title. Crunchyroll, for one, gave a Safari user agent its home-page title and no `og:` tags. They send the page's real tags only to link-preview crawlers, which they recognize by the `facebookexternalhit` token. The user agent still names Notely. From the `<head>` it reads:
  - `og:title`, falling back to `twitter:title` and then `<title>`;
  - `og:description`, falling back to `twitter:description` and then `meta name=description`;
  - `og:image`, falling back to `twitter:image`;
  - `link rel="apple-touch-icon"` or `rel="icon"`, falling back to `/favicon.ico`.
  
  Relative URLs are resolved against the final response URL. HTML entities are decoded.
- **Images:** the image and the icon are downloaded next. A failed image download yields a compact card; a failed icon download yields no icon.
- **Results:** no title means failure. Each address has one request in flight; callers waiting on the same address share it. A failure is remembered in memory for the session only.
- **Disk cache:** stored in `~/Library/Caches/com.alvarezjorge.Notely/LinkPages/`:
  - `index.json` maps URL → `{title, description, imageFile?, iconFile?}`;
  - image files are named by SHA-256 of their source URL;
  - the index loads at launch and is rewritten after each success;
  - images are downscaled with ImageIO to at most 1200 px on the long side (600 pt at 2x), and icons to 64 px, taking the largest image in multi-size icon files;
  - images are saved as JPEG when opaque and PNG when they have transparency.

Parsing uses regular expressions over the `<head>`. A full HTML parser is not available in the SDK, and adding a package dependency for it is not worth it for meta tags.

### 7. Debounced requests

- **Notes:** after a text change, a 1 s timer, restarted on every change, asks the store for each paragraph's first address. `load(text:runs:)` asks at once.
- **Lists:** `LinkCardAbove` uses `.task(id:)` keyed by the row's first address. It waits 1 s and then asks, and SwiftUI cancels the wait when the address changes. A row that appears waits that same second before asking.

The store skips addresses that are stored, failed this session, or already in flight.

### 8. Remove the hover popover

From `LinkHoverController` we delete:
- the 0.5 s timer;
- `showPreview()`;
- the popover.

The Cmd pointing-hand logic stays. We also delete `LinkPreviewStore`, `LinkPreviewViewController`, and `import LinkPresentation`.

## Risks / Trade-offs

- [A note silently falls back to TextKit 1 (some code reads `layoutManager`)] → Notes on TextKit 1 show no cards. The view is created on TextKit 2 explicitly (Decision 1). Keep the existing rule of never touching `layoutManager` on a note's text view.
- [Rebuilding paragraphs on resize costs time in long notes with many cards] → Only paragraphs whose card height changed are rebuilt, and heights are cached. If it is still slow, rebuild once at the end of a live resize.
- [Sites that stop answering crawler user agents, or block them from non-Facebook addresses] → Those pages fail and show no card, the same as any failure.
- [A stored page that later changes, or was stored wrong] → It is never refreshed (see Non-Goals). Deleting `~/Library/Caches/com.alvarezjorge.Notely/LinkPages` resets it.
- [Text jumps down when a card arrives while the user types above it] → Accepted, as the user chose no placeholder. The caret stays at its place in the text.
- [Regex meta parsing misses odd markup] → No card for that page. That is acceptable, because failure shows nothing.
- [Typing an address contacts the site] → Accepted by the user. The 1 s wait avoids requests for half-typed addresses.
- [Sites that need http only] → No card, because ATS blocks them. Cmd+click and card clicks still open them in the browser.
- [Many links in a long note] → Requests are capped at 4 in flight. The rest queue.

## Migration Plan

No saved-data migration: notes are unchanged. The first launch after the update fetches pages for links in open notes. To roll back, revert the build. The cache folder is ignored by older builds.
