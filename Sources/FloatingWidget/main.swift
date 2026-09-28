import AppKit
import SwiftUI

struct WidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Hello from Swift 🐦 (\(ProcessInfo.processInfo.activeProcessorCount) cores)")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(Date(), style: .time)
                .font(.title2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 220, height: 150)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = NSSize(width: 220, height: 150)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: WidgetView())
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
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
