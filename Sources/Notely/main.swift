import AppKit
import SwiftUI

/// One note: its text and, once the panel has been moved at least once,
/// its saved panel position in `NSStringFromPoint` form.
struct Note: Codable, Identifiable {
    let id: UUID
    var text: String
    var origin: String?
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
                notes = [Note(id: UUID(), text: "", origin: nil)]
                save()
            } else {
                notes = decoded
            }
        } else {
            // First launch of this version: migrate the single-note keys
            // into one note, then remove them.
            let text = defaults.string(forKey: Self.legacyTextKey) ?? ""
            let origin = defaults.string(forKey: Self.legacyOriginKey)
            notes = [Note(id: UUID(), text: text, origin: origin)]
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

    @discardableResult
    func add(origin: String?) -> Note {
        let note = Note(id: UUID(), text: "", origin: origin)
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

/// NSPanel subclass that can accept keyboard focus while staying a
/// non-activating panel: the app never becomes active, but the panel's
/// text view can become first responder and receive keystrokes.
final class NotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc sends `cancelOperation(_:)` up the responder chain from a
    /// focused NSTextView. Resign first responder to end editing while
    /// keeping the note text.
    override func cancelOperation(_ sender: Any?) {
        makeFirstResponder(nil)
    }
}

/// Thin header strip that drags the panel on mouseDown. TextEditor
/// consumes mouseDown itself (for text selection), so dragging by the
/// window background alone cannot work once the note fills the panel;
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
    /// and button hit targets the same as when the panel had a close button.
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
            // them never start a panel drag.
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
                    .font(.body)

                if text.wrappedValue.isEmpty {
                    Text("Type a note…")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(12)
        .frame(width: 220, height: 150)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

/// Main menu that the menu bar never shows, because the app never becomes
/// active. AppKit still checks it for Cmd key equivalents while a panel
/// is key, so it gives every note working edit shortcuts and Cmd+Q.
func makeMainMenu() -> NSMenu {
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Quit Notely",
                    action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q")

    // Actions with no target go to the first responder: the key panel's
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
/// `screen`. Shared by `restoredOrigin` (relaunch) and `addNote` (a new
/// note placed near its source panel), so both use the same rule.
func clamp(_ frame: NSRect, into screen: NSRect) -> NSPoint {
    NSPoint(x: min(max(frame.minX, screen.minX), screen.maxX - frame.width),
           y: min(max(frame.minY, screen.minY), screen.maxY - frame.height))
}

/// Where to open a panel from a saved `NSStringFromPoint` origin: the
/// saved frame moved the shortest distance to fit fully inside the screen
/// it overlaps most. Returns `nil` when nothing usable is saved or the
/// saved frame is on no screen, so the caller uses the default position.
func restoredOrigin(saved: String?, size: NSSize, screens: [NSRect]) -> NSPoint? {
    // NSPointFromString returns .zero for unparsable text, which is also a
    // valid origin, so parse the "{x, y}" form explicitly.
    guard let saved else { return nil }
    let numbers = saved
        .trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
        .split(separator: ",")
        .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard numbers.count == 2 else { return nil }

    let frame = NSRect(origin: NSPoint(x: numbers[0], y: numbers[1]), size: size)
    func overlap(_ screen: NSRect) -> CGFloat {
        let common = screen.intersection(frame)
        return common.isNull ? 0 : common.width * common.height
    }
    guard let screen = screens.max(by: { overlap($0) < overlap($1) }),
          overlap(screen) > 0 else { return nil }

    return clamp(frame, into: screen)
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
    private static let panelSize = NSSize(width: 220, height: 150)

    let store = NoteStore()
    var panels: [UUID: NotePanel] = [:]
    /// Held strongly: a released status item disappears from the menu bar.
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "note.text",
                            accessibilityDescription: "Notely")
        image?.isTemplate = true
        statusItem.button?.image = image
        let statusMenu = NSMenu()
        statusMenu.addItem(withTitle: "Quit Notely",
                           action: #selector(NSApplication.terminate(_:)),
                           keyEquivalent: "q")
        statusItem.menu = statusMenu

        for note in store.notes {
            openPanel(for: note)
        }
    }

    private func defaultOrigin(size: NSSize) -> NSPoint {
        guard let frame = NSScreen.main?.visibleFrame else { return .zero }
        return NSPoint(x: frame.maxX - size.width - 20,
                       y: frame.maxY - size.height - 20)
    }

    @discardableResult
    private func openPanel(for note: Note) -> NotePanel {
        let size = Self.panelSize
        let panel = NotePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: NoteView(
            store: store,
            id: note.id,
            onAdd: { [weak self] in self?.addNote(after: note.id) },
            onRemove: { [weak self] in self?.removeNote(note.id) }
        ))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        // The drag handle performs dragging explicitly; disable
        // background-drag so it doesn't fight the text editor's own
        // mouse handling elsewhere in the panel.
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        if let origin = restoredOrigin(saved: note.origin, size: size,
                                       screens: NSScreen.screens.map(\.visibleFrame)) {
            panel.setFrameOrigin(origin)
        } else {
            panel.setFrameOrigin(defaultOrigin(size: size))
        }
        // Set after positioning, so opening a panel never saves an origin
        // the user did not choose.
        panel.delegate = self
        panels[note.id] = panel
        panel.orderFrontRegardless()
        return panel
    }

    /// Save on every move, not at quit, so a crash or `kill` keeps the
    /// last position too.
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = panels.first(where: { $0.value === window })?.key else { return }
        store.setOrigin(NSStringFromPoint(window.frame.origin), for: id)
    }

    /// Opens a new, empty note 24 points to the left of and below the
    /// source panel, clamped fully inside that panel's screen, and gives
    /// it keyboard focus without activating the app.
    private func addNote(after id: UUID) {
        guard let sourcePanel = panels[id] else { return }
        let size = Self.panelSize
        let screen = sourcePanel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let proposedOrigin = NSPoint(x: sourcePanel.frame.origin.x - 24,
                                     y: sourcePanel.frame.origin.y - 24)
        let origin = clamp(NSRect(origin: proposedOrigin, size: size), into: screen)

        let note = store.add(origin: NSStringFromPoint(origin))
        let panel = openPanel(for: note)

        panel.makeKey()
        // The text view exists only after SwiftUI builds the hosting
        // view's hierarchy, which happens on the next run loop turn.
        DispatchQueue.main.async {
            if let textView = panel.contentView?.firstTextView {
                panel.makeFirstResponder(textView)
            }
        }
    }

    /// Removes a note and its panel at once. Removing the last note
    /// quits the app, so the next launch starts from one empty note.
    private func removeNote(_ id: UUID) {
        guard let panel = panels[id] else { return }
        // Closing the panel would otherwise report a move to the origin
        // it closes at; drop the delegate first so nothing is saved for
        // a note that no longer exists.
        panel.delegate = nil
        store.remove(id)
        panels.removeValue(forKey: id)
        panel.close()
        if panels.isEmpty {
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
