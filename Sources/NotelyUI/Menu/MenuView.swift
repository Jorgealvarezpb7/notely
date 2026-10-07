import AppKit
import NotelyCore
import SwiftUI

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
    let font: Font
    /// SF Symbol shown at the trailing edge, such as a list's icon.
    var trailingSymbol: String? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(font)
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
    let store: NoteStore
    let appearance: TextAppearance
    var onOpen: (UUID) -> Void
    var onNewNote: () -> Void
    var onNewList: () -> Void
    @State private var showingChooser = false

    var body: some View {
        // Rows follow the font choice at a fixed size.
        let font = appearance.swiftUIFont(size: TextAppearance.menuSize)
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
                    MenuRow(title: "+ New Note", font: font) {
                        onNewNote()
                        showingChooser = false
                    }
                    MenuRow(title: "+ New List", font: font) {
                        onNewList()
                        showingChooser = false
                    }
                } else {
                    MenuRow(title: "+ New", font: font) { showingChooser = true }
                    // `add` appends, so reversed store order is newest first.
                    ForEach(Array(store.notes.reversed())) { note in
                        MenuRow(title: note.isList ? listTitle(note.title) : noteTitle(note.text),
                                font: font,
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
