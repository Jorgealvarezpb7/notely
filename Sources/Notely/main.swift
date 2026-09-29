import AppKit
import SwiftUI

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

/// The standard red close button, used on its own because the borderless
/// panel has no title bar to provide one. Clicking it quits the app.
struct CloseButton: NSViewRepresentable {
    /// Natural size of the close button on this macOS version.
    static let size = makeButton().frame.size

    static func makeButton() -> NSButton {
        NSWindow.standardWindowButton(.closeButton, for: [.titled, .closable])!
    }

    func makeNSView(context: Context) -> NSButton {
        let button = Self.makeButton()
        button.target = NSApp
        button.action = #selector(NSApplication.terminate(_:))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}
}

struct NoteView: View {
    @AppStorage("noteText") private var noteText: String = ""

    var body: some View {
        VStack(spacing: 4) {
            // The close button sits on top of the drag handle, so clicks
            // on it never start a panel drag.
            ZStack(alignment: .leading) {
                DragHandle()
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 32, height: 4)
                    )
                CloseButton()
                    .frame(width: CloseButton.size.width,
                           height: CloseButton.size.height)
            }
            .frame(height: max(16, CloseButton.size.height))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $noteText)
                    .scrollContentBackground(.hidden)
                    .font(.body)

                if noteText.isEmpty {
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
/// active. AppKit still checks it for Cmd key equivalents while the panel
/// is key, so it gives the note working edit shortcuts and Cmd+Q.
func makeMainMenu() -> NSMenu {
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Quit Notely",
                    action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q")

    // Actions with no target go to the first responder: the note's text view.
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

/// Where to open the panel from a saved `NSStringFromPoint` origin: the
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

    return NSPoint(x: min(max(frame.minX, screen.minX), screen.maxX - frame.width),
                   y: min(max(frame.minY, screen.minY), screen.maxY - frame.height))
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let panelOriginKey = "panelOrigin"

    var panel: NotePanel!
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

        let size = NSSize(width: 220, height: 150)
        panel = NotePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: NoteView())
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        // The drag handle performs dragging explicitly; disable
        // background-drag so it doesn't fight the text editor's own
        // mouse handling elsewhere in the panel.
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let saved = UserDefaults.standard.string(forKey: Self.panelOriginKey)
        if let origin = restoredOrigin(saved: saved, size: size,
                                       screens: NSScreen.screens.map(\.visibleFrame)) {
            panel.setFrameOrigin(origin)
        } else if let frame = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 20,
                                         y: frame.maxY - size.height - 20))
        }
        // Set after positioning, so launch never saves an origin the user
        // did not choose.
        panel.delegate = self
        panel.orderFrontRegardless()
    }

    /// Save on every move, not at quit, so a crash or `kill` keeps the
    /// last position too.
    func windowDidMove(_ notification: Notification) {
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin),
                                  forKey: Self.panelOriginKey)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
