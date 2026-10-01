import AppKit
import SwiftUI

/// One note: its text and, once the window has been moved or resized,
/// its saved window position in `NSStringFromPoint` form and its saved
/// window size in `NSStringFromSize` form. Both are optional, so notes
/// saved by earlier versions still decode.
struct Note: Codable, Identifiable {
    let id: UUID
    var text: String
    var origin: String?
    var size: String?
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
            // An empty or undecodable list (the last note was removed, or
            // the data is bad) falls back to one empty note.
            let decoded = (try? JSONDecoder().decode([Note].self, from: data)) ?? []
            if decoded.isEmpty {
                notes = [Note(id: UUID(), text: "", origin: nil, size: nil)]
                save()
            } else {
                notes = decoded
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

/// A small borderless button for "+" and "−" in the drag strip. It
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
    var onAdd: () -> Void
    var onRemove: () -> Void

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
                    StripButton(symbolName: "minus", accessibilityLabel: "Remove Note", action: onRemove)
                        .frame(width: StripButton.referenceSize.width,
                               height: StripButton.referenceSize.height)
                    StripButton(symbolName: "plus", accessibilityLabel: "New Note", action: onAdd)
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

/// `size` capped at `screen`'s size and floored at the minimum note size.
func fit(_ size: NSSize, into screen: NSRect) -> NSSize {
    NSSize(width: max(min(size.width, screen.width), minimumNoteSize.width),
           height: max(min(size.height, screen.height), minimumNoteSize.height))
}

/// Where to open a window from a saved `NSStringFromPoint` origin: the
/// saved frame, shrunk to fit and then moved the shortest distance to sit
/// fully inside the screen it overlaps most. Returns `nil` when nothing
/// usable is saved or the saved frame is on no screen, so the caller uses
/// the default position.
func restoredFrame(saved: String?, size: NSSize, screens: [NSRect]) -> NSRect? {
    guard let pair = parsePair(saved) else { return nil }

    let frame = NSRect(origin: NSPoint(x: pair.0, y: pair.1), size: size)
    func overlap(_ screen: NSRect) -> CGFloat {
        let common = screen.intersection(frame)
        return common.isNull ? 0 : common.width * common.height
    }
    guard let screen = screens.max(by: { overlap($0) < overlap($1) }),
          overlap(screen) > 0 else { return nil }

    let fitted = fit(size, into: screen)
    let origin = clamp(NSRect(origin: frame.origin, size: fitted), into: screen)
    return NSRect(origin: origin, size: fitted)
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
    /// One scroller-style observation per note window, keyed by window.
    var scrollerObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        for note in store.notes {
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

    /// Clicking the Dock icon brings every note window to the front.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        for window in windows.values {
            window.orderFront(nil)
        }
        return true
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

        let hostingView = NSHostingView(rootView: NoteView(
            store: store,
            id: note.id,
            onAdd: { [weak self] in self?.addNote(after: note.id) },
            onRemove: { [weak self] in self?.removeNote(note.id) }
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

    /// Opens a new, empty note at the source window's size, 24 points to
    /// the left of and below it, clamped fully inside that window's
    /// screen, and gives it keyboard focus.
    private func addNote(after id: UUID) {
        guard let sourceWindow = windows[id] else { return }
        let size = sourceWindow.frame.size
        let screen = sourceWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let proposedOrigin = NSPoint(x: sourceWindow.frame.origin.x - 24,
                                     y: sourceWindow.frame.origin.y - 24)
        let origin = clamp(NSRect(origin: proposedOrigin, size: size), into: screen)

        let note = store.add(origin: NSStringFromPoint(origin), size: NSStringFromSize(size))
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

    /// Removes a note and its window at once. Removing the last note
    /// quits the app, so the next launch starts from one empty note.
    private func removeNote(_ id: UUID) {
        guard let window = windows[id] else { return }
        // Closing the window would otherwise report a move to the origin
        // it closes at; drop the delegate first so nothing is saved for
        // a note that no longer exists.
        window.delegate = nil
        store.remove(id)
        windows.removeValue(forKey: id)
        scrollerObservations.removeValue(forKey: ObjectIdentifier(window))
        window.close()
        if windows.isEmpty {
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)   // Dock icon and visible app menus
let delegate = AppDelegate()
app.delegate = delegate
app.run()
