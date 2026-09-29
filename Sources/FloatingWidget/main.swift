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

struct NoteView: View {
    @AppStorage("noteText") private var noteText: String = ""

    var body: some View {
        VStack(spacing: 4) {
            DragHandle()
                .frame(height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 32, height: 4)
                )

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

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NotePanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        if let frame = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 20,
                                         y: frame.maxY - size.height - 20))
        }
        panel.orderFrontRegardless()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
