# Proposal

## Why

A link's preview shows only while the user holds Cmd over it, so most users never see one. The user wants every link to show a preview at all times, as WhatsApp does: a card above the text with the page's image, title, description, site, and icon.

## What Changes

- Every paragraph of a note, and every list title and list item, that contains a web address shows a preview card above its text for its first web address.
- The card follows WhatsApp's layout: the page image on top, a bold title, a gray description of up to 4 lines, and a footer with a link glyph, the site's domain, and the site's icon in the corner. A page without an image gets a compact card with no image area.
- No card shows while the page information loads; the card appears when it arrives. A page that cannot be reached, or has no title, shows no card.
- A plain click on a card opens its link in the browser.
- Notely requests a page as soon as a web address has stayed unchanged for about a second, rather than only when a preview is about to show.
- Page information is kept on disk, so a relaunch shows cards without requesting pages again. A failed request is not kept; Notely tries it again on the next launch.
- **BREAKING**: The Cmd+hover preview card is removed. Cmd+click and the pointing hand while Cmd is held over a link stay.
- Cards are display only: they never change a note's saved text or styles, undo, the caret, or what Copy puts on the pasteboard.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `links`: removes "Link preview while Cmd is held" and adds always-visible preview cards above paragraphs and list rows, their content and layout, when pages are requested, the on-disk cache, and opening a link from its card.

## Impact

- `Sources/Notely/main.swift`:
  - The note text view (`NoteTextView`, `NoteEditor`) gets display-only space above paragraphs with links, and card views in that space.
  - List rows (`ListView.rowView`) and the list title show a card above their text.
  - `LinkHoverController` loses its popover and timer. `LinkPreviewStore` and `LinkPreviewViewController` are replaced by a page-information fetcher, a disk cache, and a card view.
  - The `LinkPresentation` framework is no longer used.
- Network: Notely contacts a linked site when its address is typed or opened, not only on Cmd+hover.
- Disk: page information, images, and icons are stored under the user's Caches folder.
- No change to the saved note format.
