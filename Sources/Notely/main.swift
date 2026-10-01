import AppKit
import SwiftUI

/// One checklist item. A list's `items` are kept in display order: the
/// unchecked items, then the checked items, most recently checked first.
struct ListItem: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    var done: Bool
}

/// One note: its text and, once the window has been moved or resized,
/// its saved window position in `NSStringFromPoint` form and its saved
/// window size in `NSStringFromSize` form. `isOpen` is `false` once the
/// user closes the note's window with "−"; `nil` means open. All three are
/// optional, so notes saved by earlier versions still decode, and open.
///
/// A list is a note whose `kind` is "list", with a `title` and `items`.
/// `kind` is a string, not an enum, so a kind added by a later version
/// still decodes (as a note) instead of failing the whole saved list.
struct Note: Codable, Identifiable {
    let id: UUID
    var text: String
    var origin: String?
    var size: String?
    var isOpen: Bool?
    var kind: String?
    var title: String?
    var items: [ListItem]?

    static let listKind = "list"

    var isList: Bool { kind == Self.listKind }
}

/// A list as plain text, written into `text` so a build without lists
/// shows the list's content as a readable note.
func plainText(ofList note: Note) -> String {
    ([note.title ?? ""] + (note.items ?? []).map { ($0.done ? "[x] " : "[ ] ") + $0.text })
        .joined(separator: "\n")
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

    func note(_ id: UUID) -> Note? {
        notes.first(where: { $0.id == id })
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

    @discardableResult
    func addList(origin: String?, size: String?) -> Note {
        var note = Note(id: UUID(), text: "", origin: origin, size: size)
        note.kind = Note.listKind
        note.title = ""
        note.items = []
        notes.append(note)
        save()
        return note
    }

    func remove(_ id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    /// Applies one change to a list, refreshes its plain-text copy, and
    /// saves.
    private func updateList(_ id: UUID, _ change: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        change(&notes[index])
        notes[index].text = plainText(ofList: notes[index])
        save()
    }

    func setTitle(_ title: String, for id: UUID) {
        updateList(id) { $0.title = title }
    }

    /// Adds an unchecked item at the end of the unchecked items.
    @discardableResult
    func appendItem(_ text: String, for id: UUID) -> UUID {
        let item = ListItem(id: UUID(), text: text, done: false)
        updateList(id) { note in
            var items = note.items ?? []
            items.insert(item, at: items.firstIndex(where: \.done) ?? items.count)
            note.items = items
        }
        return item.id
    }

    /// Adds an empty unchecked item directly after the unchecked item
    /// `itemID`.
    @discardableResult
    func insertItem(after itemID: UUID, for id: UUID) -> UUID {
        let item = ListItem(id: UUID(), text: "", done: false)
        updateList(id) { note in
            var items = note.items ?? []
            let index = items.firstIndex(where: { $0.id == itemID }).map { $0 + 1 } ?? items.count
            items.insert(item, at: index)
            note.items = items
        }
        return item.id
    }

    func setItemText(_ text: String, item itemID: UUID, for id: UUID) {
        updateList(id) { note in
            guard let index = note.items?.firstIndex(where: { $0.id == itemID }) else { return }
            note.items?[index].text = text
        }
    }

    func removeItem(_ itemID: UUID, for id: UUID) {
        guard note(id)?.items?.contains(where: { $0.id == itemID }) == true else { return }
        updateList(id) { note in note.items?.removeAll { $0.id == itemID } }
    }

    /// Checks or unchecks an item and moves it to index "number of
    /// unchecked items": for a newly checked item that is the top of the
    /// checked items, for a newly unchecked one the end of the unchecked
    /// items.
    func toggleItem(_ itemID: UUID, for id: UUID) {
        updateList(id) { note in
            var items = note.items ?? []
            guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
            var item = items.remove(at: index)
            item.done.toggle()
            items.insert(item, at: items.filter { !$0.done }.count)
            note.items = items
        }
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

/// Height of the top and bottom bars: the buttons plus a margin around
/// them.
let barHeight = max(16, StripButton.referenceSize.height) + 12

/// Gap between a bar and the note or list content.
let barGap: CGFloat = 4

/// Shade of both bars: `primary` is black in light appearance and white
/// in dark appearance, so the bars show darker or lighter than the note.
let barFill = Color.primary.opacity(0.08)

/// The top bar shared by note and list windows: drags the window and
/// ends editing, with "−" (close) and trash (delete) at the trailing edge.
struct NoteStrip: View {
    var onClose: () -> Void
    var onDelete: () -> Void

    var body: some View {
        // The buttons sit on top of the click target, so clicks on them
        // never start a window drag.
        ZStack {
            EndEditingView(drags: true)
            // The wide gap keeps trash away from "−", so a close is not
            // mistaken for a delete.
            HStack(spacing: 16) {
                Spacer(minLength: 0)
                StripButton(symbolName: "minus", accessibilityLabel: "Close Note", action: onClose)
                    .frame(width: StripButton.referenceSize.width,
                           height: StripButton.referenceSize.height)
                StripButton(symbolName: "trash", accessibilityLabel: "Delete Note", action: onDelete)
                    .frame(width: StripButton.referenceSize.width,
                           height: StripButton.referenceSize.height)
            }
            .padding(.trailing, 12)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: barHeight)
        .background(barFill)
    }
}

/// Height of the bottom bar: 20% lower than the top bar, which needs
/// room for the buttons.
let bottomBarHeight = (barHeight * 0.8).rounded()

/// The bottom bar of note and list windows: drags the window and ends
/// editing. Empty for now; later controls go here.
struct BottomBar: View {
    var body: some View {
        EndEditingView(drags: true)
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: bottomBarHeight)
            .background(barFill)
    }
}

/// A note window's content: the list editor for lists, the text editor
/// for everything else.
struct WindowContent: View {
    @ObservedObject var store: NoteStore
    let id: UUID
    var onClose: () -> Void
    var onDelete: () -> Void

    var body: some View {
        if store.note(id)?.isList == true {
            ListView(store: store, id: id, onClose: onClose, onDelete: onDelete)
        } else {
            NoteView(store: store, id: id, onClose: onClose, onDelete: onDelete)
        }
    }
}

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
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .font(noteFont)

            if text.wrappedValue.isEmpty {
                Text("Type a note…")
                    .font(noteFont)
                    .foregroundStyle(Color(nsColor: .textColor))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.top, barHeight + barGap)
        .padding(.bottom, bottomBarHeight + barGap)
        // The bars are overlays outside the padding, so their fill runs
        // from edge to edge, as in list windows.
        .overlay(alignment: .top) {
            NoteStrip(onClose: onClose, onDelete: onDelete)
        }
        .overlay(alignment: .bottom) {
            BottomBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        // Fill the transparent title bar too, so the top bar sits at the
        // top edge of the window.
        .ignoresSafeArea()
    }
}

/// Where keyboard focus can go in a list window, in display order: the
/// title, the items, and the "New item" row between unchecked and checked
/// items.
enum FocusTarget: Equatable {
    case title
    case item(UUID)
    case newItem
}

/// A list window's pending focus move. The `ListField` whose target
/// matches takes keyboard focus on the next run loop turn, once SwiftUI
/// has created its view, and clears the request.
final class ListFocus: ObservableObject {
    @Published var request: FocusTarget?
}

/// Keys a `ListField` hands to its list instead of editing its own text.
enum ListCommand {
    case returnKey, deleteEmpty, up, down, toggle
}

/// The `NSTextField` behind every editable list row. It answers "Check
/// Item" (Cmd+Return) only while it is an item: AppKit enables a menu item
/// only when some responder responds to its action.
final class ListTextField: NSTextField {
    var isTitle = false
    var onToggle: (() -> Void)?

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(toggleChecklistItem(_:)) { return onToggle != nil }
        return super.responds(to: aSelector)
    }

    @objc func toggleChecklistItem(_ sender: Any?) {
        onToggle?()
    }
}

/// One editable, wrapping list row: the title, an item, or "New item".
/// AppKit rather than a SwiftUI `TextField`, because Return, Backspace and
/// the arrow keys must be intercepted, and `onKeyPress` needs macOS 14.
struct ListField: NSViewRepresentable {
    let text: String
    let placeholder: String
    var bold = false
    var done = false
    var isTitle = false
    var canToggle = false
    let target: FocusTarget
    @ObservedObject var focus: ListFocus
    var onChange: (String) -> Void
    var onEndEditing: () -> Void = {}
    var onCommand: (ListCommand) -> Bool = { _ in false }

    static func font(bold: Bool) -> NSFont {
        NSFont(name: bold ? "AmericanTypewriter-Bold" : "AmericanTypewriter", size: 15)
            ?? .systemFont(ofSize: 15, weight: bold ? .bold : .regular)
    }

    /// All list text, placeholders included, is white in dark appearance
    /// and black in light appearance; checked items are struck through.
    static func styled(_ text: String, bold: Bool, done: Bool) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(bold: bold),
            .foregroundColor: NSColor.textColor,
        ]
        if done {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        return NSAttributedString(string: text, attributes: attributes)
    }

    func makeNSView(context: Context) -> ListTextField {
        let field = ListTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.font = Self.font(bold: bold)
        field.textColor = .textColor
        field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .font: Self.font(bold: bold),
            .foregroundColor: NSColor.textColor,
        ])
        field.delegate = context.coordinator
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: ListTextField, context: Context) {
        context.coordinator.parent = self
        field.isTitle = isTitle
        if canToggle {
            let onCommand = self.onCommand
            field.onToggle = { _ = onCommand(.toggle) }
        } else {
            field.onToggle = nil
        }

        if let editor = field.currentEditor() as? NSTextView {
            // While editing, the store already holds the typed text; only
            // an outside change (the "New item" row turning into an item)
            // replaces it. Never touch text an input method is composing.
            if !editor.hasMarkedText(), editor.string != text {
                editor.string = text
            }
        } else {
            field.attributedStringValue = Self.styled(text, bold: bold, done: done)
        }

        if focus.request == target {
            let listFocus = self.focus
            let wanted = self.target
            DispatchQueue.main.async { [weak field] in
                guard let field, let window = field.window, listFocus.request == wanted else { return }
                listFocus.request = nil
                window.makeFirstResponder(field)
                let end = (field.stringValue as NSString).length
                field.currentEditor()?.selectedRange = NSRange(location: end, length: 0)
            }
        }
    }

    /// Height of the wrapped text at the proposed width, so long items
    /// grow downward instead of being cut off.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ListTextField, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0,
              let cell = nsView.cell?.copy() as? NSCell else { return nil }
        // Without this the field's intrinsic width is its text on one
        // line, which can push the window's content wider than the window.
        nsView.preferredMaxLayoutWidth = width
        cell.attributedStringValue = Self.styled(text.isEmpty ? " " : text, bold: bold, done: done)
        let size = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: width,
                                                   height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ListField

        init(_ parent: ListField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            // Wait for an input method to commit (Option-e, then e)
            // before saving, so the "New item" row never turns into an
            // item halfway through a composed character.
            if let editor = notification.userInfo?["NSFieldEditor"] as? NSTextView,
               editor.hasMarkedText() { return }
            parent.onChange(field.stringValue)
        }

        /// Ending an edit puts the field editor's plain text back into
        /// the field, dropping the checked style; restyle it at once.
        func controlTextDidEndEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField {
                field.attributedStringValue = ListField.styled(field.stringValue, bold: parent.bold,
                                                               done: parent.done)
            }
            parent.onEndEditing()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                // Cmd+Return normally arrives through the "Check Item"
                // menu item; this covers it reaching the field editor.
                if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                    return parent.onCommand(.toggle)
                }
                return parent.onCommand(.returnKey)
            case #selector(NSResponder.deleteBackward(_:)):
                return textView.string.isEmpty && parent.onCommand(.deleteEmpty)
            case #selector(NSResponder.moveUp(_:)):
                return caretLine(in: textView).isFirst && parent.onCommand(.up)
            case #selector(NSResponder.moveDown(_:)):
                return caretLine(in: textView).isLast && parent.onCommand(.down)
            case #selector(NSResponder.cancelOperation(_:)):
                control.window?.makeFirstResponder(nil)
                return true
            default:
                return false
            }
        }

        /// Whether the caret is on the first and/or last wrapped line of
        /// the field, so Up and Down move inside a long item before they
        /// move to the next row.
        private func caretLine(in textView: NSTextView) -> (isFirst: Bool, isLast: Bool) {
            let length = (textView.string as NSString).length
            guard length > 0, let layoutManager = textView.layoutManager else { return (true, true) }
            func lineY(_ characterIndex: Int) -> CGFloat {
                let glyph = layoutManager.glyphIndexForCharacter(at: characterIndex)
                return layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
            }
            let caret = min(textView.selectedRange().location, length - 1)
            let y = lineY(caret)
            return (y <= lineY(0), y >= lineY(length - 1))
        }
    }
}

/// Fill of a checked item's circle: white in dark appearance, dark gray
/// in light appearance, where white would not show.
let checkFill = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .darkGray
})

/// The circle at the start of an item: an outline when unchecked, filled
/// when checked. A plain button never takes keyboard focus, so clicking
/// it leaves the item being edited alone.
struct CheckCircle: View {
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if done {
                    Circle().fill(checkFill)
                } else {
                    Circle().strokeBorder(Color.secondary, lineWidth: 1.5)
                }
            }
            .frame(width: 18, height: 18)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(done ? "Uncheck Item" : "Check Item")
    }
}

/// One row below a list's title, in display order.
enum ListRow: Identifiable {
    case item(ListItem)
    case newItem

    var id: String {
        switch self {
        case .item(let item): return item.id.uuidString
        case .newItem: return "new-item"
        }
    }

    var target: FocusTarget {
        switch self {
        case .item(let item): return .item(item.id)
        case .newItem: return .newItem
        }
    }
}

/// A list window's content: the shared strip, the title, the items, and
/// the "New item" row between unchecked and checked items.
struct ListView: View {
    @ObservedObject var store: NoteStore
    let id: UUID
    var onClose: () -> Void
    var onDelete: () -> Void
    @StateObject private var focus = ListFocus()

    private var items: [ListItem] { store.note(id)?.items ?? [] }

    /// One array for one `ForEach`, so an item keeps its identity when it
    /// moves between the unchecked and checked groups and slides there.
    private var rows: [ListRow] {
        let unchecked: [ListRow] = items.filter { !$0.done }.map(ListRow.item)
        let checked: [ListRow] = items.filter(\.done).map(ListRow.item)
        return unchecked + [.newItem] + checked
    }

    private var order: [FocusTarget] {
        [.title] + rows.map(\.target)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ListField(text: store.note(id)?.title ?? "",
                              placeholder: "Untitled list",
                              isTitle: true,
                              target: .title,
                              focus: focus,
                              onChange: { store.setTitle($0, for: id) },
                              onCommand: { handle($0, at: .title) })
                        .padding(.bottom, 2)

                    ForEach(rows) { row in
                        rowView(row)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                // Reaches down to the bottom of the visible area, so a
                // click on the empty space below the rows ends editing.
                .frame(minHeight: proxy.size.height, alignment: .top)
                .background(EndEditingView(drags: false))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, barHeight + barGap)
        .padding(.bottom, bottomBarHeight + barGap)
        // The bars are overlays, not rows of a stack: AppKit orders the
        // scroll view's NSScrollView above views declared before it, and
        // it reaches up under the transparent title bar, where it took
        // the clicks meant for "−" and trash.
        .overlay(alignment: .top) {
            NoteStrip(onClose: onClose, onDelete: onDelete)
        }
        .overlay(alignment: .bottom) {
            BottomBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        // Fill the transparent title bar too, as in note windows.
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func rowView(_ row: ListRow) -> some View {
        HStack(alignment: .top, spacing: 6) {
            switch row {
            case .item(let item):
                CheckCircle(done: item.done) { toggle(item.id) }
                ListField(text: item.text,
                          placeholder: "",
                          done: item.done,
                          canToggle: true,
                          target: .item(item.id),
                          focus: focus,
                          onChange: { store.setItemText($0, item: item.id, for: id) },
                          onEndEditing: { removeIfEmpty(item.id) },
                          onCommand: { handle($0, at: .item(item.id)) })
                    .padding(.top, 3)
            case .newItem:
                // No circle: "New item" cannot be checked.
                Color.clear.frame(width: 24, height: 24)
                ListField(text: "",
                          placeholder: "New item",
                          target: .newItem,
                          focus: focus,
                          onChange: { text in
                              guard !text.isEmpty else { return }
                              focus.request = .item(store.appendItem(text, for: id))
                          },
                          onCommand: { handle($0, at: .newItem) })
                    .padding(.top, 3)
            }
        }
    }

    private func toggle(_ itemID: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.toggleItem(itemID, for: id)
        }
    }

    /// An item left empty when it loses keyboard focus is removed.
    private func removeIfEmpty(_ itemID: UUID) {
        guard items.first(where: { $0.id == itemID })?.text.isEmpty == true else { return }
        store.removeItem(itemID, for: id)
    }

    /// Handles a key a field passed up; returns false to let the field
    /// edit as usual.
    private func handle(_ command: ListCommand, at target: FocusTarget) -> Bool {
        let targets = order
        guard let index = targets.firstIndex(of: target) else { return false }
        switch command {
        case .returnKey:
            switch target {
            case .title:
                let firstItem = items.first.map { FocusTarget.item($0.id) }
                focus.request = firstItem ?? .newItem
            case .item(let itemID):
                if items.first(where: { $0.id == itemID })?.done == true {
                    focus.request = .newItem
                } else {
                    focus.request = .item(store.insertItem(after: itemID, for: id))
                }
            case .newItem:
                break
            }
            return true
        case .deleteEmpty:
            guard case .item(let itemID) = target, index > 0 else { return false }
            store.removeItem(itemID, for: id)
            focus.request = targets[index - 1]
            return true
        case .up:
            guard index > 0 else { return false }
            focus.request = targets[index - 1]
            return true
        case .down:
            guard index + 1 < targets.count else { return false }
            focus.request = targets[index + 1]
            return true
        case .toggle:
            guard case .item(let itemID) = target else { return false }
            toggle(itemID)
            return true
        }
    }
}

/// A list's menu row title: its title after trimming whitespace, or
/// "Untitled list" when that is empty.
func listTitle(_ title: String?) -> String {
    let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Untitled list" : trimmed
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
    /// SF Symbol shown at the trailing edge, such as a list's icon.
    var trailingSymbol: String? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(noteFont)
                        .foregroundStyle(isEnabled ? HierarchicalShapeStyle.primary : .tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let trailingSymbol {
                        Image(systemName: trailingSymbol)
                            .foregroundStyle(.secondary)
                    }
                }
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
    var onNewList: () -> Void
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
                    MenuRow(title: "+ New List") {
                        onNewList()
                        showingChooser = false
                    }
                } else {
                    MenuRow(title: "+ New") { showingChooser = true }
                    // `add` appends, so reversed store order is newest first.
                    ForEach(Array(store.notes.reversed())) { note in
                        MenuRow(title: note.isList ? listTitle(note.title) : noteTitle(note.text),
                                trailingSymbol: note.isList ? "checklist" : nil) {
                            onOpen(note.id)
                        }
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
    editMenu.addItem(.separator())
    // Enabled only while a list item is edited (see `ListTextField`).
    editMenu.addItem(withTitle: "Check Item",
                     action: #selector(ListTextField.toggleChecklistItem(_:)),
                     keyEquivalent: "\r")

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
/// `screen`. Shared by `restoredFrame` (relaunch) and `newNoteFrame` (a
/// new note or list placed next to the menu), so both use the same rule.
func clamp(_ frame: NSRect, into screen: NSRect) -> NSPoint {
    NSPoint(x: min(max(frame.minX, screen.minX), screen.maxX - frame.width),
           y: min(max(frame.minY, screen.minY), screen.maxY - frame.height))
}

/// Smallest size a note window can have: half the width of a new note,
/// which still fits the top bar's buttons, and room for the bottom bar
/// and one line of text.
let minimumNoteSize = NSSize(width: 110, height: 120)

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
    /// Depth-first search for the first view of type `T` in this view's
    /// hierarchy that matches `match`.
    func firstDescendant<T: NSView>(_ type: T.Type, where match: (T) -> Bool = { _ in true }) -> T? {
        if let view = self as? T, match(view) { return view }
        for subview in subviews {
            if let found = subview.firstDescendant(type, where: match) { return found }
        }
        return nil
    }

    /// The first `NSTextView`, used to focus a freshly created note's
    /// text editor.
    var firstTextView: NSTextView? {
        firstDescendant(NSTextView.self)
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

    /// Gives the window's scroll view (a note's text editor, or a list's
    /// rows) overlay scrollers, which show only while the user scrolls,
    /// whatever the system scroll bar setting. SwiftUI builds the scroll
    /// view on a later run loop turn; when it is not there yet, try once
    /// more on the next turn.
    private func applyOverlayScroller(to window: NSWindow, retry: Bool = true) {
        guard let scrollView = window.contentView?.firstDescendant(NSScrollView.self) else {
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
            onNewNote: { [weak self] in self?.addFromMenu(list: false) },
            onNewList: { [weak self] in self?.addFromMenu(list: true) }
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

        let hostingView = NSHostingView(rootView: WindowContent(
            store: store,
            id: note.id,
            onClose: { [weak self] in self?.closeNote(note.id) },
            onDelete: { [weak self] in self?.confirmDelete(note.id) }
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

    /// A note window never grows larger than its screen's visible area,
    /// nor shrinks below `minimumNoteSize`. Not `sender.minSize`: AppKit
    /// ties it to `contentMinSize`, which the SwiftUI hosting view can
    /// lower to its own fitting size, so it does not hold on its own.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let minimum = minimumNoteSize
        guard let screen = sender.screen?.visibleFrame else {
            return NSSize(width: max(frameSize.width, minimum.width),
                          height: max(frameSize.height, minimum.height))
        }
        return NSSize(width: max(min(frameSize.width, screen.width), minimum.width),
                      height: max(min(frameSize.height, screen.height), minimum.height))
    }

    /// Opens a new, empty note or list next to the menu window (see
    /// `newNoteFrame`), and gives keyboard focus to the note's text or the
    /// list's title.
    private func addFromMenu(list: Bool) {
        guard let menuWindow else { return }
        let screen = menuWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let frame = newNoteFrame(menu: menuWindow.frame, screen: screen)

        let origin = NSStringFromPoint(frame.origin)
        let size = NSStringFromSize(frame.size)
        let note = list ? store.addList(origin: origin, size: size) : store.add(origin: origin, size: size)
        let window = openWindow(for: note)

        window.makeKeyAndOrderFront(nil)
        // The editors exist only after SwiftUI builds the hosting view's
        // hierarchy, which happens on the next run loop turn.
        DispatchQueue.main.async {
            let editor: NSView? = list
                ? window.contentView?.firstDescendant(ListTextField.self, where: \.isTitle)
                : window.contentView?.firstTextView
            if let editor {
                window.makeFirstResponder(editor)
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

    /// Asks before deleting, in a sheet on the note's window. "Cancel" is
    /// the default button, so Return and Esc never delete; only a click on
    /// "Delete" does.
    private func confirmDelete(_ id: UUID) {
        guard let window = windows[id], window.attachedSheet == nil,
              let note = store.note(id) else { return }
        let name = note.isList ? listTitle(note.title) : noteTitle(note.text)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete “\(name)”?"
        alert.informativeText = "This \(note.isList ? "list" : "note") will be deleted. You can't undo this."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete").hasDestructiveAction = true
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertSecondButtonReturn {
                self?.removeNote(id)
            }
        }
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
