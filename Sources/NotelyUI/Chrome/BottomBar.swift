import AppKit
import NotelyCore
import SwiftUI

/// The bottom bar of note and list windows: drags the window and ends
/// editing, with the font button, the text size button, and the tint
/// button at the trailing edge. Note windows pass their editor state and
/// also get the style buttons at the leading edge.
struct BottomBar: View {
    let store: NoteStore
    let appearance: TextAppearance
    let id: UUID
    var editorState: NoteEditorState? = nil
    @StateObject private var controls = AppearanceControls()
    @StateObject private var tintControls = TintControls()

    var body: some View {
        // The buttons sit on top of the click target, as in the top bar.
        ZStack {
            EndEditingView(drags: true)
            // Fits six buttons in the minimum note width.
            HStack(spacing: 0) {
                if let editorState {
                    StyleButtons(state: editorState)
                }
                Spacer(minLength: 16)
                HStack(spacing: 16) {
                    StripButton(symbolName: "textformat", accessibilityLabel: "Font") { button in
                        controls.appearance = appearance
                        controls.showFontMenu(from: button)
                    }
                    .frame(width: StripButton.referenceSize.width,
                           height: StripButton.referenceSize.height)
                    StripButton(symbolName: "textformat.size", accessibilityLabel: "Text Size") { button in
                        controls.appearance = appearance
                        controls.toggleSizePopover(from: button)
                    }
                    .frame(width: StripButton.referenceSize.width,
                           height: StripButton.referenceSize.height)
                    let tint = tintColor(store.note(id)?.tint)
                    StripButton(symbolName: tint == nil ? "circle" : "circle.fill",
                                accessibilityLabel: "Note Color", color: tint) { button in
                        tintControls.store = store
                        tintControls.id = id
                        tintControls.showMenu(from: button)
                    }
                    .frame(width: StripButton.referenceSize.width,
                           height: StripButton.referenceSize.height)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: bottomBarHeight)
        .background(barFill)
    }
}

/// Opens the bottom bar's font menu and text size popover. A class, so
/// the open popover outlives view updates.
final class AppearanceControls: NSObject, ObservableObject, NSPopoverDelegate {
    var appearance: TextAppearance?
    private var popover: NSPopover?
    /// When the size popover last closed. A transient popover closes on
    /// the mouse-down of the click on its own button, before the button's
    /// action runs; that click must not open it again.
    private var popoverClosedAt = Date.distantPast

    func showFontMenu(from button: NSButton) {
        guard let appearance else { return }
        let menu = NSMenu()
        for family in [FontFamily.typewriter, .system] {
            let item = NSMenuItem(title: family.menuTitle, action: #selector(chooseFamily(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = family.rawValue
            item.state = family == appearance.family ? .on : .off
            menu.addItem(item)
        }
        // Below the button; AppKit moves the menu up if it would leave
        // the screen.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func chooseFamily(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let family = FontFamily(rawValue: raw),
              appearance?.family != family else { return }
        appearance?.family = family
    }

    func toggleSizePopover(from button: NSButton) {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let appearance, Date().timeIntervalSince(popoverClosedAt) > 0.3 else { return }
        let controller = NSHostingController(rootView: SizePopover(appearance: appearance))
        controller.sizingOptions = .preferredContentSize
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = controller
        popover.delegate = self
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        self.popover = popover
    }

    func popoverDidClose(_ notification: Notification) {
        popover = nil
        popoverClosedAt = Date()
    }
}

/// Opens the bottom bar's tint menu and sends the shared color panel's
/// changes to one note. A class, so it can be the target of the menu
/// items and the color panel.
final class TintControls: NSObject, ObservableObject {
    var store: NoteStore?
    var id: UUID?
    /// The note's window, from the tint button. The color panel closes
    /// when it closes.
    private weak var window: NSWindow?

    /// The controls the color panel sends its changes to. `NSColorPanel`
    /// is shared, and a new target replaces the old one, so the window
    /// that last chose "Other Colors…" owns it. An identifier, not a weak
    /// reference: a weak reference already reads nil in `deinit`.
    private static var panelOwner: ObjectIdentifier?

    func showMenu(from button: NSButton) {
        guard let store, let id else { return }
        window = button.window
        let current = store.note(id)?.tint
        let menu = NSMenu()
        let none = NSMenuItem(title: "Default", action: #selector(choose(_:)), keyEquivalent: "")
        none.target = self
        none.state = tintColor(current) == nil ? .on : .off
        menu.addItem(none)
        menu.addItem(.separator())
        for preset in tintPresets {
            let item = NSMenuItem(title: preset.name, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.tint
            item.image = tintColor(preset.tint).map(Self.swatch)
            item.state = preset.tint == current ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let other = NSMenuItem(title: "Other Colors…", action: #selector(showColorPanel(_:)), keyEquivalent: "")
        other.target = self
        menu.addItem(other)
        // Below the button, as the font menu.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    /// A filled circle in `color`, for a preset's menu entry.
    private static func swatch(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
    }

    /// "Default" has no represented object, so it removes the tint.
    @objc private func choose(_ sender: NSMenuItem) {
        guard let id else { return }
        store?.setTint(sender.representedObject as? String, for: id)
    }

    @objc private func showColorPanel(_ sender: NSMenuItem) {
        guard let store, let id else { return }
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        // Drop the old target first: setting the color sends the action,
        // which must not reach the previous note.
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.color = tintColor(store.note(id)?.tint) ?? .white
        panel.setTarget(self)
        panel.setAction(#selector(panelChanged(_:)))
        Self.panelOwner = ObjectIdentifier(self)
        // "−" and delete both close the window, so one observer covers
        // both. Observers added with a selector go away with `self`.
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        // A nil object would observe every window, so skip it.
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)),
                                                   name: NSWindow.willCloseNotification, object: window)
        }
        panel.orderFront(nil)
    }

    /// Closes the color panel with the note it changes. When another
    /// note owns the panel, it stays open.
    @objc private func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        guard releasePanel() else { return }
        NSColorPanel.shared.orderOut(nil)
    }

    /// Closes the color panel, whichever note owns it. The panel floats
    /// above every window, so it would cover a delete confirmation sheet.
    static func closePanel() {
        guard panelOwner != nil else { return }
        panelOwner = nil
        NSColorPanel.shared.setTarget(nil)
        NSColorPanel.shared.setAction(nil)
        NSColorPanel.shared.orderOut(nil)
    }

    /// Stops the color panel from sending changes here, if this owns it.
    /// Returns whether it did.
    @discardableResult
    private func releasePanel() -> Bool {
        guard Self.panelOwner == ObjectIdentifier(self) else { return false }
        Self.panelOwner = nil
        NSColorPanel.shared.setTarget(nil)
        NSColorPanel.shared.setAction(nil)
        return true
    }

    /// `tintString` drops alpha, so an eyedropper color from a
    /// translucent area saves at full opacity.
    @objc private func panelChanged(_ sender: NSColorPanel) {
        guard let id, let tint = tintString(sender.color) else { return }
        store?.setTint(tint, for: id)
    }

    /// The panel may not clear a target that goes away.
    deinit {
        releasePanel()
    }
}

/// The text size popover: a slider from 10 to 20 points that changes
/// every note and list while the user drags, and the size in points.
struct SizePopover: View {
    let appearance: TextAppearance

    private var size: Binding<Double> {
        Binding(
            get: { Double(appearance.size) },
            set: { appearance.size = Int($0.rounded()) }
        )
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("A").font(.system(size: 10))
                Slider(value: size,
                       in: Double(TextAppearance.sizeRange.lowerBound)...Double(TextAppearance.sizeRange.upperBound),
                       step: 1)
                    .accessibilityLabel("Text Size")
                Text("A").font(.system(size: 18))
            }
            Text("\(appearance.size) pt")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 220)
    }
}
