import AppKit
import NotelyCore
import SwiftUI

/// Owns the menu window. Red quits the app, and the windowed frame is
/// saved on every move and resize under `menuFrame`.
final class MenuWindowController: NSObject, NSWindowDelegate {
    static let frameKey = "menuFrame"

    private let store: NoteStore
    private let appearance: TextAppearance
    private let onOpen: (UUID) -> Void
    private let onNewNote: () -> Void
    private let onNewList: () -> Void

    private(set) var window: NSWindow?

    /// True from the start of entering full screen to the end of leaving
    /// it, so the full-screen frame is never saved.
    private var inFullScreen = false

    init(store: NoteStore, appearance: TextAppearance,
         onOpen: @escaping (UUID) -> Void,
         onNewNote: @escaping () -> Void,
         onNewList: @escaping () -> Void) {
        self.store = store
        self.appearance = appearance
        self.onOpen = onOpen
        self.onNewNote = onNewNote
        self.onNewList = onNewList
        super.init()
    }

    /// Opens the menu window at its saved frame, or at the default frame
    /// 20 points from the top and left edges of the main screen's visible
    /// area. The standard window buttons stay visible.
    func open() {
        let saved = UserDefaults.standard.string(forKey: Self.frameKey)
            .map(NSRectFromString)
        let frame: NSRect
        // `NSRectFromString` returns .zero for unparsable text.
        if let saved, saved.width > 0, saved.height > 0,
           let restored = restoredFrame(saved, screens: NSScreen.screens.map(\.visibleFrame),
                                        minimum: minimumMenuSize) {
            frame = restored
        } else {
            let screen = NSScreen.main?.visibleFrame ?? NSRect(origin: .zero, size: defaultMenuSize)
            let fitted = fit(defaultMenuSize, into: screen, minimum: minimumMenuSize)
            frame = NSRect(x: screen.minX + 20,
                           y: screen.maxY - fitted.height - 20,
                           width: fitted.width, height: fitted.height)
        }

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        // Named for the Dock tile and the Window list; the title bar
        // itself shows no title.
        window.title = "Notely"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.minSize = minimumMenuSize

        let hostingView = NSHostingView(rootView: MenuView(
            store: store,
            appearance: appearance,
            onOpen: onOpen,
            onNewNote: onNewNote,
            onNewList: onNewList
        ))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setFrame(frame, display: false)

        // Set after positioning, as for notes, so opening never saves a
        // frame the user did not choose.
        window.delegate = self
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    /// Restores the menu when minimized and brings it to the front.
    func bringToFront() {
        guard let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.orderFront(nil)
    }

    /// Red quits through the same path as Cmd+Q and the Quit menu items.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil)
        return false
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        inFullScreen = true
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        inFullScreen = false
        saveFrame(notification)
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame(notification)
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame(notification)
    }

    private func saveFrame(_ notification: Notification) {
        guard !inFullScreen, let window = notification.object as? NSWindow else { return }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Self.frameKey)
    }
}
