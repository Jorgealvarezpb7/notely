import AppKit
import SwiftUI

/// One note: its text and, once the window has been moved or resized,
/// its saved window position in `NSStringFromPoint` form and its saved
/// window size in `NSStringFromSize` form. `isOpen` is `false` once the
/// user closes the note's window with "−"; `nil` means open. All three are
/// optional, so notes saved by earlier versions still decode, and open.
struct Note: Codable, Identifiable {
    let id: UUID
    var text: String
    var origin: String?
    var size: String?
    var isOpen: Bool?
}

/// Holds every note and keeps `UserDefaults` in sync on every change, the
/// same timing the single-note version relied on: normal termination
/// flushes `UserDefaults`, so a save on every keystroke and every move is
/// what keeps text and position through a quit.
final class NoteStore: ObservableObject {
    private static let notesKey = "notes"
    private static let legacyTextKey = "noteText"
    private static let legacyOriginKey = "panelOrigin"

    @Published private(set) var notes: [Note]

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.notesKey) {
            // An empty list (every note was deleted) stays empty, so the
            // menu shows only "+ New". Undecodable data falls back to one
            // empty note.
            if let decoded = try? JSONDecoder().decode([Note].self, from: data) {
                notes = decoded
            } else {
                notes = [Note(id: UUID(), text: "", origin: nil, size: nil)]
                save()
            }
        } else {
            // First launch of this version: migrate the single-note keys
            // into one note, then remove them.
            let text = defaults.string(forKey: Self.legacyTextKey) ?? ""
            let origin = defaults.string(forKey: Self.legacyOriginKey)
            notes = [Note(id: UUID(), text: text, origin: origin, size: nil)]
            defaults.removeObject(forKey: Self.legacyTextKey)
            defaults.removeObject(forKey: Self.legacyOriginKey)
            save()
        }
    }

    func text(for id: UUID) -> String {
        notes.first(where: { $0.id == id })?.text ?? ""
    }

    func setText(_ text: String, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].text = text
        save()
    }

    func setOrigin(_ origin: String, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].origin = origin
        save()
    }

    func setOpen(_ isOpen: Bool, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isOpen = isOpen
        save()
    }

    func setFrame(origin: String, size: String, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].origin = origin
        notes[index].size = size
        save()
    }

    @discardableResult
    func add(origin: String?, size: String?) -> Note {
        let note = Note(id: UUID(), text: "", origin: origin, size: size)
        notes.append(note)
        save()
        return note
    }

    func remove(_ id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: Self.notesKey)
    }
}

/// A note's window: a titled, resizable window whose title bar is
/// transparent and hidden, so the note keeps its own look while getting
/// native resizing, corners, and shadow.
final class NoteWindow: NSWindow {
    /// Esc sends `cancelOperation(_:)` up the responder chain from a
    /// focused NSTextView. Resign first responder to end editing while
    /// keeping the note text.
    override func cancelOperation(_ sender: Any?) {
        makeFirstResponder(nil)
    }
}

/// Thin header strip that drags the window on mouseDown. TextEditor
/// consumes mouseDown itself (for text selection), so dragging by the
/// window background alone cannot work once the note fills the window;
/// this strip gives an explicit, visible drag target instead.
struct DragHandle: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> NSView {
        DragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// A small borderless button for "−" and trash in the drag strip. It
/// accepts the first click even while the app is not active, so one
/// click works while another app is frontmost.
struct StripButton: NSViewRepresentable {
    final class FirstMouseButton: NSButton {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }

    /// Reuses the standard close button's natural size purely as a sizing
    /// constant; the button itself is never shown. Keeps the strip height
    /// and button hit targets the same as when the window had a close button.
    static let referenceSize = NSWindow.standardWindowButton(.closeButton, for: [.titled, .closable])!.frame.size

    let symbolName: String
    let accessibilityLabel: String
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = FirstMouseButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel)
        button.image?.isTemplate = true
        button.setAccessibilityLabel(accessibilityLabel)
        button.target = context.coordinator
        button.action = #selector(Coordinator.fire)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }
}

/// Typeface for note text and its placeholder, at the macOS body text
/// size. One value for both keeps the placeholder in step with the text.
let noteFont = Font.custom("American Typewriter", size: 15, relativeTo: .body)

struct NoteView: View {
    @ObservedObject var store: NoteStore
    let id: UUID
    var onClose: () -> Void
    var onDelete: () -> Void

    private var text: Binding<String> {
        Binding(
            get: { store.text(for: id) },
            set: { store.setText($0, for: id) }
        )
    }

    var body: some View {
        VStack(spacing: 4) {
            // The buttons sit on top of the drag handle, so clicks on
            // them never start a window drag.
            ZStack {
                DragHandle()
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 32, height: 4)
                    )
                HStack(spacing: 4) {
                    Spacer()
                    StripButton(symbolName: "minus", accessibilityLabel: "Close Note", action: onClose)
                        .frame(width: StripButton.referenceSize.width,
                               height: StripButton.referenceSize.height)
                    StripButton(symbolName: "trash", accessibilityLabel: "Delete Note", action: onDelete)
                        .frame(width: StripButton.referenceSize.width,
                               height: StripButton.referenceSize.height)
                }
            }
            .frame(height: max(16, StripButton.referenceSize.height))

            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .scrollContentBackground(.hidden)
                    .font(noteFont)

                if text.wrappedValue.isEmpty {
                    Text("Type a note…")
                        .font(noteFont)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        // Fill the transparent title bar too, so the drag strip sits at
        // the top edge of the window as before.
        .ignoresSafeArea()
    }
}

/// A menu row's title: the first line of `text` that is not empty after
/// trimming whitespace, or "Untitled note" when there is none.
func noteTitle(_ text: String) -> String {
    text.split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .first { !$0.isEmpty } ?? "Untitled note"
}

/// Lightens a menu button while the pointer is over it. Disabled buttons
/// do not react.
struct HoverHighlight: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(Color.primary.opacity(isEnabled && isHovering ? 0.08 : 0))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

/// One full-width row of the menu window, with a divider below it.
struct MenuRow: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                Text(title)
                    .font(noteFont)
                    .foregroundStyle(isEnabled ? HierarchicalShapeStyle.primary : .tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(HoverHighlight())
            Divider()
        }
    }
}

/// Content of the menu window: the note list, or the "+ New" chooser.
/// The chooser is view state only, so the menu always opens on the list.
struct MenuView: View {
    @ObservedObject var store: NoteStore
    var onOpen: (UUID) -> Void
    var onNewNote: () -> Void
    @State private var showingChooser = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if showingChooser {
                    HStack {
                        Spacer()
                        Button { showingChooser = false } label: {
                            Image(systemName: "arrow.left")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .modifier(HoverHighlight())
                        .accessibilityLabel("Back")
                    }
                    Divider()
                    MenuRow(title: "+ New Note") {
                        onNewNote()
                        showingChooser = false
                    }
                    // Placeholder for a later change.
                    MenuRow(title: "+ New List") {}
                        .disabled(true)
                } else {
                    MenuRow(title: "+ New") { showingChooser = true }
                    // `add` appends, so reversed store order is newest first.
                    ForEach(Array(store.notes.reversed())) { note in
                        MenuRow(title: noteTitle(note.text)) { onOpen(note.id) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

/// Main menu the menu bar shows while the app is active. It gives every
/// note working edit shortcuts and Cmd+Q.
func makeMainMenu() -> NSMenu {
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Quit Notely",
                    action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q")

    // Actions with no target go to the first responder: the key window's
    // note text view.
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
    redo.keyEquivalentModifierMask = [.command, .shift]
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

    let appItem = NSMenuItem()
    appItem.submenu = appMenu
    let editItem = NSMenuItem()
    editItem.submenu = editMenu

    let mainMenu = NSMenu()
    mainMenu.addItem(appItem)
    mainMenu.addItem(editItem)
    return mainMenu
}

/// Moves `frame` the shortest distance (x and y only) to sit fully inside
/// `screen`. Shared by `restoredFrame` (relaunch) and `addNote` (a new
/// note placed near its source window), so both use the same rule.
func clamp(_ frame: NSRect, into screen: NSRect) -> NSPoint {
    NSPoint(x: min(max(frame.minX, screen.minX), screen.maxX - frame.width),
           y: min(max(frame.minY, screen.minY), screen.maxY - frame.height))
}

/// Smallest size a note window can have: room for the drag strip and one
/// line of text.
let minimumNoteSize = NSSize(width: 160, height: 100)

/// Size of a note with no saved size.
let defaultNoteSize = NSSize(width: 220, height: 150)

/// Smallest size of the menu window.
let minimumMenuSize = NSSize(width: 200, height: 200)

/// Size of the menu window with no saved frame.
let defaultMenuSize = NSSize(width: 260, height: 360)

/// Parses the "{a, b}" form written by `NSStringFromPoint` and
/// `NSStringFromSize`. Their `...FromString` counterparts return .zero for
/// unparsable text, which is indistinguishable from a real value.
func parsePair(_ saved: String?) -> (Double, Double)? {
    guard let saved else { return nil }
    let numbers = saved
        .trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
        .split(separator: ",")
        .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard numbers.count == 2 else { return nil }
    return (numbers[0], numbers[1])
}

/// A saved `NSStringFromSize` size, or the default size when nothing
/// usable is saved.
func savedSize(_ saved: String?) -> NSSize {
    guard let pair = parsePair(saved) else { return defaultNoteSize }
    return NSSize(width: pair.0, height: pair.1)
}

/// `size` capped at `screen`'s size and floored at `minimum`.
func fit(_ size: NSSize, into screen: NSRect, minimum: NSSize = minimumNoteSize) -> NSSize {
    NSSize(width: max(min(size.width, screen.width), minimum.width),
           height: max(min(size.height, screen.height), minimum.height))
}

/// Where to open a window from a saved `NSStringFromPoint` origin: the
/// saved frame, shrunk to fit and then moved the shortest distance to sit
/// fully inside the screen it overlaps most. Returns `nil` when nothing
/// usable is saved or the saved frame is on no screen, so the caller uses
/// the default position.
func restoredFrame(saved: String?, size: NSSize, screens: [NSRect]) -> NSRect? {
    guard let pair = parsePair(saved) else { return nil }
    return restoredFrame(NSRect(origin: NSPoint(x: pair.0, y: pair.1), size: size),
                         screens: screens)
}

/// `frame` shrunk to fit (no smaller than `minimum`) and moved the shortest
/// distance to sit fully inside the screen it overlaps most, or `nil` when
/// it is on no screen.
func restoredFrame(_ frame: NSRect, screens: [NSRect], minimum: NSSize = minimumNoteSize) -> NSRect? {
    func overlap(_ screen: NSRect) -> CGFloat {
        let common = screen.intersection(frame)
        return common.isNull ? 0 : common.width * common.height
    }
    guard let screen = screens.max(by: { overlap($0) < overlap($1) }),
          overlap(screen) > 0 else { return nil }

    let fitted = fit(frame.size, into: screen, minimum: minimum)
    let origin = clamp(NSRect(origin: frame.origin, size: fitted), into: screen)
    return NSRect(origin: origin, size: fitted)
}

/// Frame for a note created from the menu: the default note size, top
/// edges aligned, 12 points right of the menu; else 12 points left of it;
/// else the right-hand frame moved the shortest distance into `screen`.
func newNoteFrame(menu: NSRect, screen: NSRect) -> NSRect {
    let size = fit(defaultNoteSize, into: screen)
    let y = menu.maxY - size.height
    let right = NSRect(x: menu.maxX + 12, y: y, width: size.width, height: size.height)
    if screen.contains(right) { return right }
    let left = NSRect(x: menu.minX - 12 - size.width, y: y, width: size.width, height: size.height)
    if screen.contains(left) { return left }
    return NSRect(origin: clamp(right, into: screen), size: size)
}

/// Delegate of the menu window. Red quits the app, and the windowed frame
/// is saved on every move and resize under `menuFrame`.
final class MenuWindowDelegate: NSObject, NSWindowDelegate {
    static let frameKey = "menuFrame"

    /// True from the start of entering full screen to the end of leaving
    /// it, so the full-screen frame is never saved.
    private var inFullScreen = false

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

private extension NSView {
    /// Depth-first search for the first `NSTextView` in this view's
    /// hierarchy, used to focus a freshly created note's text editor.
    var firstTextView: NSTextView? {
        if let textView = self as? NSTextView { return textView }
        for subview in subviews {
            if let found = subview.firstTextView { return found }
        }
        return nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = NoteStore()
    var windows: [UUID: NoteWindow] = [:]
    var menuWindow: NSWindow?
    /// Window delegates are weak; this keeps the menu's alive.
    let menuDelegate = MenuWindowDelegate()
    /// One scroller-style observation per note window, keyed by window.
    var scrollerObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        // Notes open after the menu, so they stack in front of it.
        openMenuWindow()
        for note in store.notes where note.isOpen != false {
            openWindow(for: note)
        }

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
            guard let self else { return }
            for window in self.windows.values {
                self.applyOverlayScroller(to: window)
            }
        }
    }

    /// Gives the note's scroll view overlay scrollers, which show only
    /// while the user scrolls, whatever the system scroll bar setting.
    /// SwiftUI builds the text view on a later run loop turn; when it is
    /// not there yet, try once more on the next turn.
    private func applyOverlayScroller(to window: NSWindow, retry: Bool = true) {
        guard let scrollView = window.contentView?.firstTextView?.enclosingScrollView else {
            if retry {
                DispatchQueue.main.async { [weak self, weak window] in
                    guard let window else { return }
                    self?.applyOverlayScroller(to: window, retry: false)
                }
            }
            return
        }
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true

        // SwiftUI and AppKit set the style back to the system preference
        // after this; set overlay again whenever it changes.
        scrollerObservations[ObjectIdentifier(window)] = scrollView.observe(\.scrollerStyle) { scrollView, _ in
            guard scrollView.scrollerStyle != .overlay else { return }
            scrollView.scrollerStyle = .overlay
        }
    }

    /// Clicking the Dock icon restores a minimized menu and brings the menu
    /// and every open note window to the front.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let menuWindow {
            if menuWindow.isMiniaturized {
                menuWindow.deminiaturize(nil)
            }
            menuWindow.orderFront(nil)
        }
        for window in windows.values {
            window.orderFront(nil)
        }
        return true
    }

    /// Opens the menu window at its saved frame, or at the default frame
    /// 20 points from the top and left edges of the main screen's visible
    /// area. The standard window buttons stay visible.
    private func openMenuWindow() {
        let saved = UserDefaults.standard.string(forKey: MenuWindowDelegate.frameKey)
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
            onOpen: { [weak self] id in self?.openNote(id) },
            onNewNote: { [weak self] in self?.addNoteFromMenu() }
        ))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setFrame(frame, display: false)

        // Set after positioning, as for notes, so opening never saves a
        // frame the user did not choose.
        window.delegate = menuDelegate
        menuWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    @discardableResult
    private func openWindow(for note: Note) -> NoteWindow {
        let size = savedSize(note.size)
        let frame: NSRect
        if let restored = restoredFrame(saved: note.origin, size: size,
                                        screens: NSScreen.screens.map(\.visibleFrame)) {
            frame = restored
        } else {
            // Default position: 20 points from the top and right edges of
            // the main screen's visible area.
            let screen = NSScreen.main?.visibleFrame ?? NSRect(origin: .zero, size: size)
            let fitted = fit(size, into: screen)
            frame = NSRect(x: screen.maxX - fitted.width - 20,
                           y: screen.maxY - fitted.height - 20,
                           width: fitted.width, height: fitted.height)
        }

        let window = NoteWindow(
            contentRect: frame,
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // The dictionary owns the window; without this, `close()` would
        // release it a second time.
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        // Full screen and window tiling are for the menu only; a note is
        // never offered as a tile or moved into a full-screen Space.
        window.collectionBehavior.formUnion([.fullScreenNone, .fullScreenDisallowsTiling])

        let hostingView = NSHostingView(rootView: NoteView(
            store: store,
            id: note.id,
            onClose: { [weak self] in self?.closeNote(note.id) },
            onDelete: { [weak self] in self?.removeNote(note.id) }
        ))
        // The window alone owns its size; SwiftUI's preferred size must
        // not pin it.
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        // The drag handle performs dragging explicitly; disable
        // background-drag so it doesn't fight the text editor's own
        // mouse handling elsewhere in the window.
        window.isMovableByWindowBackground = false
        window.minSize = minimumNoteSize
        // `contentRect` may be adjusted for the title bar; set the frame
        // itself so the saved size is the frame size.
        window.setFrame(frame, display: false)

        // Set after positioning, so opening a window never saves a frame
        // the user did not choose.
        window.delegate = self
        windows[note.id] = window
        window.orderFrontRegardless()
        // The text view exists only after SwiftUI builds the hosting
        // view's hierarchy, on the next run loop turn.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window else { return }
            self?.applyOverlayScroller(to: window)
        }
        return window
    }

    private func noteID(of notification: Notification) -> UUID? {
        guard let window = notification.object as? NSWindow else { return nil }
        return windows.first(where: { $0.value === window })?.key
    }

    /// Save on every move, not at quit, so a crash or `kill` keeps the
    /// last position too.
    func windowDidMove(_ notification: Notification) {
        guard let id = noteID(of: notification), let window = windows[id] else { return }
        store.setOrigin(NSStringFromPoint(window.frame.origin), for: id)
    }

    /// Saves origin and size together: a resize from the left or bottom
    /// edge moves the origin without always posting `windowDidMove`.
    func windowDidResize(_ notification: Notification) {
        guard let id = noteID(of: notification), let window = windows[id] else { return }
        store.setFrame(origin: NSStringFromPoint(window.frame.origin),
                       size: NSStringFromSize(window.frame.size),
                       for: id)
    }

    /// A note window never grows larger than its screen's visible area.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard let screen = sender.screen?.visibleFrame else { return frameSize }
        return NSSize(width: min(frameSize.width, screen.width),
                      height: min(frameSize.height, screen.height))
    }

    /// Opens a new, empty note next to the menu window (see
    /// `newNoteFrame`), and gives it keyboard focus.
    private func addNoteFromMenu() {
        guard let menuWindow else { return }
        let screen = menuWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let frame = newNoteFrame(menu: menuWindow.frame, screen: screen)

        let note = store.add(origin: NSStringFromPoint(frame.origin),
                             size: NSStringFromSize(frame.size))
        let window = openWindow(for: note)

        window.makeKeyAndOrderFront(nil)
        // The text view exists only after SwiftUI builds the hosting
        // view's hierarchy, which happens on the next run loop turn.
        DispatchQueue.main.async {
            if let textView = window.contentView?.firstTextView {
                window.makeFirstResponder(textView)
            }
        }
    }

    /// Shows a note's window in front, opening it at its saved frame when
    /// it is closed. An open window is not moved, and never duplicated.
    private func openNote(_ id: UUID) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard let note = store.notes.first(where: { $0.id == id }) else { return }
        store.setOpen(true, for: id)
        openWindow(for: note).makeKeyAndOrderFront(nil)
    }

    /// Stops tracking a note's window and returns it, ready to close.
    /// Closing the window would otherwise report a move to the origin it
    /// closes at; dropping the delegate first means nothing is saved for
    /// a frame the user did not choose.
    private func detachWindow(_ id: UUID) -> NoteWindow? {
        guard let window = windows.removeValue(forKey: id) else { return nil }
        window.delegate = nil
        scrollerObservations.removeValue(forKey: ObjectIdentifier(window))
        return window
    }

    /// Closes a note's window and keeps the note, listed in the menu.
    private func closeNote(_ id: UUID) {
        guard let window = detachWindow(id) else { return }
        store.setOpen(false, for: id)
        window.close()
    }

    /// Deletes a note and closes its window at once. The app keeps
    /// running with no notes; the menu then shows only "+ New".
    private func removeNote(_ id: UUID) {
        guard let window = detachWindow(id) else { return }
        store.remove(id)
        window.close()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)   // Dock icon and visible app menus
let delegate = AppDelegate()
app.delegate = delegate
app.run()
