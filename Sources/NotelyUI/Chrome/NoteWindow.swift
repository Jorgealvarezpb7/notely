import AppKit
import SwiftUI

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

/// A click target that ends editing, as Esc does, and with `drags` then
/// drags the window. TextEditor consumes mouseDown itself (for text
/// selection), so dragging by the window background alone cannot work
/// once the note fills the window; the bars give an explicit, visible
/// drag target instead.
struct EndEditingView: NSViewRepresentable {
    let drags: Bool

    final class ClickView: NSView {
        var drags = true

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(nil)
            if drags {
                window?.performDrag(with: event)
            }
        }
    }

    func makeNSView(context: Context) -> ClickView {
        ClickView()
    }

    func updateNSView(_ nsView: ClickView, context: Context) {
        nsView.drags = drags
    }
}
