import AppKit
import NotelyCore
import NotelyLinks

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store: NoteStore
    private let appearance: TextAppearance
    private let notes: NoteWindowController
    private lazy var menu = MenuWindowController(
        store: store,
        appearance: appearance,
        onOpen: { [weak self] id in self?.notes.open(id) },
        onNewNote: { [weak self] in self?.addFromMenu(list: false) },
        onNewList: { [weak self] in self?.addFromMenu(list: true) }
    )

    init(store: NoteStore, appearance: TextAppearance, linkPages: LinkPageStore) {
        self.store = store
        self.appearance = appearance
        notes = NoteWindowController(store: store, appearance: appearance, linkPages: linkPages)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        LinkHoverController.shared.start()

        // Notes open after the menu, so they stack in front of it.
        menu.open()
        notes.openSavedWindows()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredScrollerStyleDidChange(_:)),
            name: NSScroller.preferredScrollerStyleDidChangeNotification,
            object: nil
        )
    }

    /// Every scroll view resets itself to the system scroller style when
    /// the "Show scroll bars" setting or the pointing device changes.
    /// Observers run in no fixed order, so apply overlay again on the next
    /// run loop turn, after that reset.
    @objc private func preferredScrollerStyleDidChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.notes.applyOverlayScrollers()
        }
    }

    /// Clicking the Dock icon restores a minimized menu and brings the menu
    /// and every open note window to the front.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menu.bringToFront()
        notes.orderAllFront()
        return true
    }

    private func addFromMenu(list: Bool) {
        guard let window = menu.window else { return }
        notes.add(list: list, nextTo: window)
    }
}
