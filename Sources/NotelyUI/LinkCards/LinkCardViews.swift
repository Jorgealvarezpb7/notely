import AppKit
import NotelyLinks
import SwiftUI

/// Sizes of a card's parts. `height(for:width:)` is the height the card
/// draws at, so the text can leave exactly that much room for it.
enum LinkCardLayout {
    static let cornerRadius: CGFloat = 8
    static let padding: CGFloat = 10
    static let textTop: CGFloat = 8
    static let textSpacing: CGFloat = 2
    static let footerHeight: CGFloat = 32
    static let iconSize: CGFloat = 18
    /// Space between a card and the text under it.
    static let gap: CGFloat = 6
    static let titleLines = 2
    static let descriptionLines = 4
    static let titleFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let descriptionFont = NSFont.systemFont(ofSize: 13)

    static func imageHeight(width: CGFloat) -> CGFloat {
        (width / 1.91).rounded()
    }

    private static var textHeights: [String: CGFloat] = [:]

    /// Height of `text` wrapped at `width`, `maxLines` lines at most.
    /// Measured once per text, font, and width.
    static func textHeight(_ text: String, font: NSFont, width: CGFloat, maxLines: Int) -> CGFloat {
        guard width > 0 else { return 0 }
        let key = "\(text)\u{0}\(font.fontName)\u{0}\(font.pointSize)\u{0}\(width)\u{0}\(maxLines)"
        if let height = textHeights[key] { return height }
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font])
        let height = min(ceil(rect.height), lineHeight * CGFloat(maxLines))
        if textHeights.count > 1000 { textHeights.removeAll() }
        textHeights[key] = height
        return height
    }

    static func titleHeight(_ page: LinkPage, width: CGFloat) -> CGFloat {
        textHeight(page.title, font: titleFont, width: width - 2 * padding, maxLines: titleLines)
    }

    static func descriptionHeight(_ page: LinkPage, width: CGFloat) -> CGFloat {
        guard let description = page.description else { return 0 }
        return textHeight(description, font: descriptionFont, width: width - 2 * padding, maxLines: descriptionLines)
    }

    /// Heights already measured, by page text, image, and width: text
    /// views and cards ask for the same height several times per layout.
    private static var heights: [String: CGFloat] = [:]

    static func height(for page: LinkPage, width: CGFloat) -> CGFloat {
        let key = "\(page.title)\u{0}\(page.description ?? "")\u{0}\(page.image != nil)\u{0}\(width)"
        if let height = heights[key] { return height }
        var height = textTop + titleHeight(page, width: width) + footerHeight
        if page.image != nil { height += imageHeight(width: width) }
        if page.description != nil { height += textSpacing + descriptionHeight(page, width: width) }
        if heights.count > 500 { heights.removeAll() }
        heights[key] = height
        return height
    }
}

/// A link's card: the page image, the title in bold, the description in
/// gray, and a footer with a link glyph, the domain, and the site icon.
/// A page without an image gets the same card without the image area.
struct LinkCard: View {
    let page: LinkPage
    let url: URL

    private var domain: String {
        let host = url.host ?? url.absoluteString
        return host.lowercased().hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            VStack(alignment: .leading, spacing: 0) {
                if let image = page.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: LinkCardLayout.imageHeight(width: width))
                        .clipped()
                }
                Text(page.title)
                    .font(Font(LinkCardLayout.titleFont as CTFont))
                    .foregroundColor(.primary)
                    .lineLimit(LinkCardLayout.titleLines)
                    .frame(width: width - 2 * LinkCardLayout.padding,
                           height: LinkCardLayout.titleHeight(page, width: width), alignment: .topLeading)
                    .padding(.top, LinkCardLayout.textTop)
                    .padding(.horizontal, LinkCardLayout.padding)
                if let description = page.description {
                    Text(description)
                        .font(Font(LinkCardLayout.descriptionFont as CTFont))
                        .foregroundColor(.secondary)
                        .lineLimit(LinkCardLayout.descriptionLines)
                        .truncationMode(.tail)
                        .frame(width: width - 2 * LinkCardLayout.padding,
                               height: LinkCardLayout.descriptionHeight(page, width: width), alignment: .topLeading)
                        .padding(.top, LinkCardLayout.textSpacing)
                        .padding(.horizontal, LinkCardLayout.padding)
                }
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .medium))
                    Text(domain)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 6)
                    if let icon = page.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: LinkCardLayout.iconSize, height: LinkCardLayout.iconSize)
                            .clipShape(Circle())
                    }
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, LinkCardLayout.padding)
                .frame(width: width, height: LinkCardLayout.footerHeight)
            }
            .frame(width: width, height: proxy.size.height, alignment: .top)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: LinkCardLayout.cornerRadius, style: .continuous))
        }
    }
}

/// Shows a `LinkCard` in AppKit, in note text views and list rows. Takes
/// every click inside it: a click opens the link, also while Notely is not
/// the active app, and never reaches the text under it.
final class LinkCardHost: NSView {
    private(set) var url: URL
    private let hosting: NSHostingView<LinkCard>

    init(url: URL, page: LinkPage) {
        self.url = url
        hosting = NSHostingView(rootView: LinkCard(page: page, url: url))
        super.init(frame: .zero)
        hosting.sizingOptions = []
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        addSubview(hosting)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Shows `page`. Keeps the card as it is when it already shows that
    /// page, so a new frame only resizes it.
    func show(url: URL, page: LinkPage) {
        let current = hosting.rootView.page
        guard url != self.url || page.title != current.title || page.description != current.description
                || page.image !== current.image || page.icon !== current.icon else { return }
        self.url = url
        hosting.rootView = LinkCard(page: page, url: url)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        LinkHoverController.shared.reset()
        NSWorkspace.shared.open(url)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }
}

/// A list row's card in SwiftUI, as tall as the card at the row's width.
struct LinkCardRow: NSViewRepresentable {
    let url: URL
    let page: LinkPage

    func makeNSView(context: Context) -> LinkCardHost {
        LinkCardHost(url: url, page: page)
    }

    func updateNSView(_ host: LinkCardHost, context: Context) {
        host.show(url: url, page: page)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LinkCardHost, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: LinkCardLayout.height(for: page, width: width))
    }
}

/// `content` with the card of the first web address in `text` above it,
/// once that page has arrived. Asks for the page a second after `text`
/// last changed its first web address, and when the row appears.
struct LinkCardAbove<Content: View>: View {
    let text: String
    let indent: CGFloat
    let content: Content
    @ObservedObject private var pages: LinkPageStore

    init(text: String, pages: LinkPageStore, indent: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.text = text
        _pages = ObservedObject(wrappedValue: pages)
        self.indent = indent
        self.content = content()
    }

    var body: some View {
        let url = LinkDetector.links(in: text).first?.url
        VStack(alignment: .leading, spacing: LinkCardLayout.gap) {
            if let url, let page = pages.page(for: url) {
                LinkCardRow(url: url, page: page)
                    .padding(.leading, indent)
            }
            content
        }
        .task(id: url) {
            guard let url else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            pages.request(url)
        }
    }
}
