import AppKit
import NotelyLinks
import SwiftUI

// MARK: Links

/// Link color: a stronger blue (#1D4ED8) than the system link color in light
/// appearance, where the system blue reads poorly on light and tinted
/// notes; the system link color in dark appearance.
let noteLinkColor = NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? .linkColor
        : NSColor(srgbRed: 0x1D / 255, green: 0x4E / 255, blue: 0xD8 / 255, alpha: 1)
}

/// Link color and underline, as list rows and text views show links.
let linkDisplayAttributes: [NSAttributedString.Key: Any] = [
    .foregroundColor: noteLinkColor,
    .underlineStyle: NSUnderlineStyle.single.rawValue,
]

extension NSTextView {
    /// Shows every web address in the text as a link and returns them.
    /// The link look lives in the layout manager (rendering attributes on
    /// TextKit 2, temporary attributes on TextKit 1), never in the text
    /// storage, so saved text and styles, undo, and copy do not change.
    /// Never reads `layoutManager` on a TextKit 2 view: that would switch
    /// the view to TextKit 1 for good.
    func showLinks() -> [DetectedLink] {
        let links = LinkDetector.links(in: string)
        if let textLayoutManager {
            let document = textLayoutManager.documentRange
            textLayoutManager.removeRenderingAttribute(.foregroundColor, for: document)
            textLayoutManager.removeRenderingAttribute(.underlineStyle, for: document)
            for link in links {
                guard let start = textLayoutManager.location(document.location, offsetBy: link.range.location),
                      let end = textLayoutManager.location(start, offsetBy: link.range.length),
                      let range = NSTextRange(location: start, end: end) else { continue }
                for (key, value) in linkDisplayAttributes {
                    textLayoutManager.addRenderingAttribute(key, value: value, for: range)
                }
            }
        } else if let layoutManager {
            let full = NSRange(location: 0, length: (string as NSString).length)
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: full)
            for link in links {
                layoutManager.addTemporaryAttributes(linkDisplayAttributes, forCharacterRange: link.range)
            }
        }
        needsDisplay = true
        return links
    }

    /// The link of `links` under `point` (view coordinates), with the rect
    /// of the line piece under the point. Uses only text input APIs, which
    /// work on TextKit 1 and 2.
    func link(in links: [DetectedLink], at point: NSPoint) -> (url: URL, rect: NSRect)? {
        guard !links.isEmpty, let window else { return nil }
        let index = characterIndexForInsertion(at: point)
        for link in links where NSLocationInRange(index, link.range)
            || (index > 0 && NSLocationInRange(index - 1, link.range)) {
            // A link can wrap over several lines; check each line's piece.
            var location = link.range.location
            let end = NSMaxRange(link.range)
            while location < end {
                var actual = NSRange(location: NSNotFound, length: 0)
                let screenRect = firstRect(forCharacterRange: NSRange(location: location, length: end - location),
                                           actualRange: &actual)
                guard actual.location != NSNotFound, actual.length > 0 else { break }
                let rect = convert(window.convertFromScreen(screenRect), from: nil)
                if rect.contains(point) { return (link.url, rect) }
                location = NSMaxRange(actual)
            }
        }
        return nil
    }
}

/// A view that shows links: note text views, the list field editor, and
/// list rows that are not being edited.
protocol LinkHost: NSView {
    /// The link under `point`, in this view's coordinates, and its rect.
    func link(at point: NSPoint) -> (url: URL, rect: NSRect)?
}

extension LinkHost {
    /// Opens the link under a Cmd+click and returns true; returns false
    /// for any other click, which the view then handles as usual.
    func openLink(for event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              let link = link(at: convert(event.locationInWindow, from: nil)) else { return false }
        LinkHoverController.shared.reset()
        NSWorkspace.shared.open(link.url)
        return true
    }
}

/// Watches Cmd and the pointer while Notely is active. With Cmd held over
/// a link, shows the pointing hand. Scrolling, typing, clicking, releasing
/// Cmd, leaving the link, or switching apps puts the text pointer back.
final class LinkHoverController {
    static let shared = LinkHoverController()

    private var monitor: Any?
    private weak var host: NSView?
    private var url: URL?
    private var rect: NSRect = .zero

    /// True while Cmd is held over a link; hosts keep the pointing hand.
    var isActive: Bool { url != nil && host != nil }

    func start() {
        guard monitor == nil else { return }
        // A local monitor sees events only while Notely is active.
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .mouseMoved, .scrollWheel, .keyDown, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.reset()
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged, .mouseMoved:
            update(commandHeld: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command))
        default:
            reset()
        }
    }

    /// The link host under the pointer, if any, and the link there.
    private func hostAndLink() -> (host: LinkHost, link: (url: URL, rect: NSRect)?)? {
        let screenPoint = NSEvent.mouseLocation
        let number = NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: 0)
        guard let window = NSApp.window(withWindowNumber: number),
              let content = window.contentView else { return nil }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        var view = content.hitTest(content.superview?.convert(windowPoint, from: nil) ?? windowPoint)
        while let current = view {
            if let host = current as? LinkHost {
                return (host, host.link(at: host.convert(windowPoint, from: nil)))
            }
            view = current.superview
        }
        return nil
    }

    private func update(commandHeld: Bool) {
        let found = commandHeld ? hostAndLink() : nil
        guard let found, let link = found.link else {
            let wasActive = isActive
            reset()
            // Cmd released or the pointer left the link without moving
            // onto other text: put the text pointer back at once.
            if wasActive {
                (hostAndLink() != nil ? NSCursor.iBeam : NSCursor.arrow).set()
            }
            return
        }
        if host === found.host, url == link.url, rect == link.rect {
            applyCursor()
            return
        }
        reset()
        host = found.host
        url = link.url
        rect = link.rect
        applyCursor()
    }

    /// Text views set the I-beam in their own handling of the same event,
    /// which runs after this monitor; set the hand again after it.
    private func applyCursor() {
        NSCursor.pointingHand.set()
        DispatchQueue.main.async { [weak self] in
            if self?.isActive == true { NSCursor.pointingHand.set() }
        }
    }

    /// Forgets the link.
    func reset() {
        host = nil
        url = nil
    }
}
