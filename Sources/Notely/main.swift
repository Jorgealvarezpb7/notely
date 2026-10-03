import AppKit
import LinkPresentation
import SwiftUI

/// One checklist item. A list's `items` are kept in display order: the
/// unchecked items, then the checked items, most recently checked first.
struct ListItem: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    var done: Bool
}

/// One styled range of a note's text. `location` and `length` count
/// UTF-16 code units, as `NSString` and `NSRange` do. A trait that is
/// `nil` is off.
struct StyleRun: Codable, Equatable {
    var location: Int
    var length: Int
    var bold: Bool?
    var italic: Bool?
    var underline: Bool?

    /// The run trimmed to a text of `textLength` UTF-16 code units, or
    /// `nil` when nothing of it is left inside the text.
    func clamped(toLength textLength: Int) -> StyleRun? {
        let start = max(location, 0)
        let end = min(location + length, textLength)
        guard end > start else { return nil }
        var run = self
        run.location = start
        run.length = end - start
        return run
    }
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
///
/// `styles` holds a note's bold, italic, and underlined ranges. `text`
/// stays plain, so a build without styles still shows the note's text.
///
/// `tint` is the note's color as sRGB "#RRGGBB", or nil for no tint.
struct Note: Codable, Identifiable {
    let id: UUID
    var text: String
    var origin: String?
    var size: String?
    var isOpen: Bool?
    var kind: String?
    var title: String?
    var items: [ListItem]?
    var styles: [StyleRun]?
    var tint: String?

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
            if var decoded = try? JSONDecoder().decode([Note].self, from: data) {
                // Runs outside a note's text, from damaged data, are
                // trimmed or dropped rather than failing the decode.
                for index in decoded.indices {
                    guard let styles = decoded[index].styles else { continue }
                    let length = decoded[index].text.utf16.count
                    decoded[index].styles = styles.compactMap { $0.clamped(toLength: length) }
                }
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

    /// Saves a note's text and its style runs together. Empty runs are
    /// saved as no styles.
    func setText(_ text: String, styles: [StyleRun], for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].text = text
        notes[index].styles = styles.isEmpty ? nil : styles
        save()
    }

    func setOrigin(_ origin: String, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].origin = origin
        save()
    }

    /// `nil` removes the tint.
    func setTint(_ tint: String?, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }),
              notes[index].tint != tint else { return }
        notes[index].tint = tint
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

/// The two fonts the user can choose for note and list text.
enum FontFamily: String {
    case typewriter, system

    /// Title of the font's entry in the font menu.
    var menuTitle: String {
        switch self {
        case .typewriter: return "American Typewriter"
        case .system: return "System"
        }
    }
}

/// The one font and text size for every note and list. Each change is
/// saved to `UserDefaults` at once, under keys apart from `notes`, so a
/// build without this setting still reads notes and ignores it.
final class TextAppearance: ObservableObject {
    static let sizeRange = 10...20
    /// Menu rows follow the font choice but always keep this size.
    static let menuSize: CGFloat = 15
    private static let familyKey = "textFontFamily"
    private static let sizeKey = "textFontSize"

    @Published var family: FontFamily {
        didSet { UserDefaults.standard.set(family.rawValue, forKey: Self.familyKey) }
    }

    /// Callers keep this within `sizeRange`; the slider cannot leave it.
    @Published var size: Int {
        didSet { UserDefaults.standard.set(size, forKey: Self.sizeKey) }
    }

    /// No saved setting means American Typewriter at 15 points. An
    /// unknown font falls back to American Typewriter, and a size outside
    /// `sizeRange` to the nearest limit.
    init() {
        let defaults = UserDefaults.standard
        family = defaults.string(forKey: Self.familyKey).flatMap(FontFamily.init(rawValue:)) ?? .typewriter
        let saved = defaults.object(forKey: Self.sizeKey) as? Int ?? 15
        size = min(max(saved, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
    }

    /// The chosen font at `size`, for SwiftUI text.
    func swiftUIFont(size: CGFloat) -> Font {
        switch family {
        case .typewriter: return .custom("American Typewriter", size: size)
        case .system: return .system(size: size)
        }
    }

    /// The chosen font at the chosen size, for AppKit text. Falls back to
    /// the system font if American Typewriter is missing.
    func nsFont(bold: Bool) -> NSFont {
        let size = CGFloat(self.size)
        if family == .typewriter,
           let font = NSFont(name: bold ? "AmericanTypewriter-Bold" : "AmericanTypewriter", size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    /// Display attributes for note text with these traits: the chosen
    /// font, bold when asked, and for italic the font's italic face, or a
    /// slant when the font has none (American Typewriter).
    func noteAttributes(bold: Bool, italic: Bool) -> [NSAttributedString.Key: Any] {
        var font = nsFont(bold: bold)
        var obliqueness: CGFloat = 0
        if italic {
            let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.italic))
            if let italicFont = NSFont(descriptor: descriptor, size: font.pointSize),
               italicFont.familyName == font.familyName,
               italicFont.fontDescriptor.symbolicTraits.contains(.italic) {
                font = italicFont
            } else {
                obliqueness = 0.2
            }
        }
        return [.font: font, .obliqueness: obliqueness, .foregroundColor: NSColor.textColor]
    }
}

/// The styles a note's text can carry, in bottom bar order.
enum TextStyle: CaseIterable {
    case bold, italic, underline

    var symbolName: String {
        switch self {
        case .bold: return "bold"
        case .italic: return "italic"
        case .underline: return "underline"
        }
    }

    var title: String {
        switch self {
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .underline: return "Underline"
        }
    }
}

extension NSAttributedString.Key {
    /// Bold and italic are kept as traits, apart from the font, so a
    /// change of the font setting keeps them. Underline uses the standard
    /// `underlineStyle`.
    static let notelyBold = NSAttributedString.Key("NotelyBold")
    static let notelyItalic = NSAttributedString.Key("NotelyItalic")
}

extension StyleRun {
    init(location: Int, length: Int, traits: Set<TextStyle>) {
        self.init(location: location, length: length,
                  bold: traits.contains(.bold) ? true : nil,
                  italic: traits.contains(.italic) ? true : nil,
                  underline: traits.contains(.underline) ? true : nil)
    }

    var traits: Set<TextStyle> {
        var traits = Set<TextStyle>()
        if bold == true { traits.insert(.bold) }
        if italic == true { traits.insert(.italic) }
        if underline == true { traits.insert(.underline) }
        return traits
    }
}

/// Text and style runs, as `Note` saves them; also the private pasteboard
/// type for copying styled text between notes.
struct StyledText: Codable {
    var text: String
    var styles: [StyleRun]
}

/// Converts between attributed text and style runs.
enum StyleTraits {
    static func traits(in attributes: [NSAttributedString.Key: Any]) -> Set<TextStyle> {
        var traits = Set<TextStyle>()
        if attributes[.notelyBold] as? Bool == true { traits.insert(.bold) }
        if attributes[.notelyItalic] as? Bool == true { traits.insert(.italic) }
        if let underline = attributes[.underlineStyle] as? Int, underline != 0 { traits.insert(.underline) }
        return traits
    }

    /// The trait attributes alone, without display attributes.
    static func attributes(for traits: Set<TextStyle>) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        if traits.contains(.bold) { attributes[.notelyBold] = true }
        if traits.contains(.italic) { attributes[.notelyItalic] = true }
        if traits.contains(.underline) { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        return attributes
    }

    /// Runs of `text` with at least one trait, adjacent equal runs merged.
    static func runs(of text: NSAttributedString) -> [StyleRun] {
        var runs: [StyleRun] = []
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, range, _ in
            let traits = Self.traits(in: attributes)
            guard !traits.isEmpty else { return }
            if let last = runs.last, last.location + last.length == range.location, last.traits == traits {
                runs[runs.count - 1].length += range.length
            } else {
                runs.append(StyleRun(location: range.location, length: range.length, traits: traits))
            }
        }
        return runs
    }

    /// `text` with the trait attributes of `runs`; runs are clamped to it.
    static func attributed(_ text: String, runs: [StyleRun]) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: text)
        for run in runs {
            guard let run = run.clamped(toLength: result.length) else { continue }
            result.addAttributes(attributes(for: run.traits),
                                 range: NSRange(location: run.location, length: run.length))
        }
        return result
    }

    /// Rich text from another source reduced to bold, italic, and
    /// underline. Bold and italic come from the font's traits; a slant
    /// counts as italic.
    static func sanitized(_ rich: NSAttributedString) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: rich.string)
        rich.enumerateAttributes(in: NSRange(location: 0, length: rich.length)) { attributes, range, _ in
            var traits = Self.traits(in: attributes)
            if let font = attributes[.font] as? NSFont {
                let symbolic = font.fontDescriptor.symbolicTraits
                if symbolic.contains(.bold) { traits.insert(.bold) }
                if symbolic.contains(.italic) { traits.insert(.italic) }
            }
            if let slant = attributes[.obliqueness] as? NSNumber, slant.doubleValue > 0 {
                traits.insert(.italic)
            }
            result.addAttributes(Self.attributes(for: traits), range: range)
        }
        return result
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

/// A small borderless button for "−" and trash in the drag strip, and for
/// the bottom bar's buttons. It accepts the first click even while the
/// app is not active, so one click works while another app is frontmost.
/// The action gets the button, to anchor a menu or popover on it.
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
    /// `nil` for a plain button. Set for an on/off button (the style
    /// buttons): no background in any state; the symbol shows in the
    /// label color (white in dark appearance) while on and gray while
    /// off. The button never takes keyboard focus, so the note keeps its
    /// selection.
    var isOn: Bool? = nil
    /// Set for a color swatch (the tint button): the symbol shows in this
    /// color instead of the bar's icon color.
    var color: NSColor? = nil
    let action: (NSButton) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = FirstMouseButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        if isOn != nil {
            button.refusesFirstResponder = true
        }
        button.setAccessibilityLabel(accessibilityLabel)
        button.target = context.coordinator
        button.action = #selector(Coordinator.fire(_:))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.action = action
        // The tint button switches between "circle" and "circle.fill".
        if context.coordinator.symbolName != symbolName {
            context.coordinator.symbolName = symbolName
            nsView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel)
            nsView.image?.isTemplate = true
        }
        if let isOn {
            nsView.contentTintColor = isOn ? .labelColor : .secondaryLabelColor
        } else {
            nsView.contentTintColor = color
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        var action: (NSButton) -> Void
        var symbolName: String?
        init(action: @escaping (NSButton) -> Void) { self.action = action }
        @objc func fire(_ sender: NSButton) { action(sender) }
    }
}

/// Height of the top and bottom bars: the buttons plus a margin around
/// them.
let barHeight = max(16, StripButton.referenceSize.height) + 12

/// Gap between a bar and the note or list content.
let barGap: CGFloat = 4

/// Shade of both bars: `primary` is black in light appearance and white
/// in dark appearance, so the bars show darker or lighter than the note.
let barFill = Color.primary.opacity(0.08)

/// Strength of a note's tint over the material: one value for every
/// color, low enough that the desktop always shows through.
let tintStrength = 0.2

/// The background of note and list windows: the translucent material,
/// with the note's tint, if any, as a faint wash over it.
struct NoteBackground: View {
    let tint: String?

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            if let color = tintColor(tint) {
                Color(nsColor: color).opacity(tintStrength)
            }
        }
    }
}

/// Fill of the logo in the top bar, a stronger tint of `barFill`'s color:
/// black in light appearance and white in dark appearance, quieter than
/// the bar's buttons. White gets more alpha because it looks weaker on
/// the dark material.
let logoFill = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor.white.withAlphaComponent(0.30)
        : NSColor.black.withAlphaComponent(0.25)
})

/// Outline of the Notely logo: the `d` attribute of
/// `Packaging/notely-logo.svg`, whose viewBox is 837 by 465 and whose fill
/// rule is even-odd.
let notelyLogoPathData = "M 209,4 203,14 202,25 201,26 201,52 202,53 203,65 206,72 209,76 216,79 242,79 243,80 250,80 251,81 251,376 249,378 221,378 220,379 214,379 210,381 205,387 203,393 203,398 202,399 202,431 203,432 204,442 208,450 211,453 216,455 388,455 391,454 397,447 400,437 400,431 401,430 401,401 400,400 400,395 398,389 394,382 388,379 382,379 381,378 336,378 334,375 335,373 335,368 334,367 334,197 335,196 335,167 337,164 340,167 354,188 377,227 383,235 512,450 520,458 532,463 538,463 539,464 561,464 562,463 571,462 580,458 586,452 589,445 589,88 590,87 590,81 591,80 621,79 626,77 629,74 632,68 633,60 634,59 634,49 635,48 635,27 634,26 633,16 629,7 625,3 622,2 601,2 600,1 486,1 485,2 475,1 474,2 460,2 457,3 453,7 450,13 448,20 447,42 448,43 448,60 449,61 450,68 453,74 456,77 461,79 489,79 490,80 503,80 504,81 504,92 505,93 505,116 504,117 504,123 505,124 504,125 505,126 504,128 505,129 504,130 505,131 505,142 504,143 504,146 505,147 505,155 504,156 505,159 504,160 505,202 504,204 505,206 504,207 504,211 505,212 505,222 504,223 504,271 503,272 499,268 357,29 351,21 343,7 340,4 335,2 327,2 326,1 236,1 235,2 213,2 Z M 801,0 800,1 795,1 786,5 777,13 773,20 771,27 771,41 772,42 772,50 773,51 774,65 775,66 777,85 779,92 782,119 783,120 783,125 784,126 784,131 786,138 786,144 789,151 793,155 800,158 809,158 815,155 819,151 821,146 822,136 823,135 823,129 824,128 824,122 825,121 825,115 827,108 827,102 828,101 828,94 829,93 831,75 832,74 832,68 833,67 834,55 835,54 837,31 836,30 835,22 832,16 825,8 813,1 Z M 714,0 713,1 708,1 699,5 691,12 687,18 684,26 684,44 685,45 685,51 686,52 686,58 687,59 688,72 690,79 690,85 691,86 691,92 692,93 693,106 694,107 695,119 697,126 697,133 698,134 699,145 701,150 707,156 711,158 721,158 726,156 732,150 734,145 737,119 738,118 738,112 739,111 739,105 740,104 741,92 742,91 743,79 744,78 744,72 745,71 747,53 748,52 749,35 750,34 749,33 749,25 744,14 736,6 725,1 Z M 117,0 116,1 107,2 97,8 91,15 87,24 86,40 87,41 88,56 89,57 90,71 92,78 92,84 93,85 93,91 94,92 94,98 95,99 95,105 96,106 96,113 97,114 97,121 98,122 99,137 100,138 101,147 103,151 108,156 112,158 123,158 129,155 132,152 135,146 136,135 137,134 137,127 139,120 139,114 140,113 141,101 142,100 144,82 145,81 145,75 146,74 146,69 147,68 147,63 149,56 149,50 150,49 150,43 151,42 151,28 146,15 137,6 126,1 Z M 29,0 28,1 23,1 16,4 9,9 3,17 0,25 0,45 1,46 3,69 4,70 4,76 6,83 6,90 7,91 7,97 9,104 9,110 10,111 10,117 11,118 12,131 13,132 13,138 14,139 15,147 17,151 22,156 27,158 37,158 43,155 46,152 49,145 52,119 53,118 53,112 54,111 54,104 56,97 57,83 58,82 59,70 61,63 61,56 62,55 62,49 63,48 64,29 60,17 50,6 39,1 Z"

/// The Notely logo, drawn from `notelyLogoPathData` and scaled to fit the
/// proposed rect with its proportions kept. The parser handles only what
/// that file uses: absolute `M`, then `x,y` points joined by straight
/// lines, then `Z`. An export with relative commands or curves needs a
/// new parser.
struct NotelyLogo: Shape {
    static let viewBox = CGSize(width: 837, height: 465)

    /// Each subpath's points, in viewBox units. SVG and SwiftUI both put
    /// the origin at the top left with y pointing down, so no flip.
    static let subpaths: [[CGPoint]] = {
        var subpaths: [[CGPoint]] = []
        var current: [CGPoint] = []
        for token in notelyLogoPathData.split(whereSeparator: \.isWhitespace) {
            switch token {
            case "M":
                current = []
            case "Z":
                if !current.isEmpty { subpaths.append(current) }
                current = []
            default:
                let pair = token.split(separator: ",").compactMap { Double($0) }
                if pair.count == 2 {
                    current.append(CGPoint(x: pair[0], y: pair[1]))
                }
            }
        }
        return subpaths
    }()

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.viewBox.width, rect.height / Self.viewBox.height)
        var path = Path()
        for points in Self.subpaths {
            path.addLines(points.map { CGPoint(x: rect.minX + $0.x * scale,
                                               y: rect.minY + $0.y * scale) })
            path.closeSubpath()
        }
        return path
    }
}

/// The top bar shared by note and list windows: drags the window and
/// ends editing, with the Notely logo at its center and "−" (close) and
/// trash (delete) at the trailing edge.
struct NoteStrip: View {
    var onClose: () -> Void
    var onDelete: () -> Void

    /// Logo size: shorter than the bar, with its artwork's proportions.
    static let logoHeight: CGFloat = 12
    static let logoWidth = logoHeight * NotelyLogo.viewBox.width / NotelyLogo.viewBox.height

    /// Narrowest bar that shows the logo at its center with 8 points to
    /// spare before "−": the buttons take their trailing padding, two
    /// button widths, and the gap between them.
    static let logoMinimumWidth: CGFloat = {
        let buttons = 12 + 2 * StripButton.referenceSize.width + 16
        return 2 * (buttons + 8) + logoWidth
    }()

    var body: some View {
        // The buttons sit on top of the click target, so clicks on them
        // never start a window drag.
        ZStack {
            EndEditingView(drags: true)
            // Decoration only: clicks and drags fall through to the click
            // target below. Hidden when it would touch "−".
            GeometryReader { proxy in
                if proxy.size.width >= Self.logoMinimumWidth {
                    NotelyLogo()
                        .fill(logoFill, style: FillStyle(eoFill: true))
                        .frame(width: Self.logoWidth, height: Self.logoHeight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            // The wide gap keeps trash away from "−", so a close is not
            // mistaken for a delete.
            HStack(spacing: 16) {
                Spacer(minLength: 0)
                StripButton(symbolName: "minus", accessibilityLabel: "Close Note", action: { _ in onClose() })
                    .frame(width: StripButton.referenceSize.width,
                           height: StripButton.referenceSize.height)
                StripButton(symbolName: "trash", accessibilityLabel: "Delete Note", action: { _ in onDelete() })
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
/// editing, with the font button, the text size button, and the tint
/// button at the trailing edge. Note windows pass their editor state and
/// also get the style buttons at the leading edge.
struct BottomBar: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var appearance: TextAppearance
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
    @ObservedObject var appearance: TextAppearance

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

/// A note window's content: the list editor for lists, the text editor
/// for everything else.
struct WindowContent: View {
    @ObservedObject var store: NoteStore
    let appearance: TextAppearance
    let id: UUID
    var onClose: () -> Void
    var onDelete: () -> Void

    var body: some View {
        if store.note(id)?.isList == true {
            ListView(store: store, appearance: appearance, id: id, onClose: onClose, onDelete: onDelete)
        } else {
            NoteView(store: store, appearance: appearance, id: id, onClose: onClose, onDelete: onDelete)
        }
    }
}

struct NoteView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var appearance: TextAppearance
    let id: UUID
    var onClose: () -> Void
    var onDelete: () -> Void
    @StateObject private var editorState = NoteEditorState()

    var body: some View {
        NoteEditor(store: store, appearance: appearance, family: appearance.family,
                   size: appearance.size, id: id, state: editorState)
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
            BottomBar(store: store, appearance: appearance, id: id, editorState: editorState)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoteBackground(tint: store.note(id)?.tint))
        // Fill the transparent title bar too, so the top bar sits at the
        // top edge of the window.
        .ignoresSafeArea()
    }
}

/// A note window's editor as the bottom bar sees it: the styles that
/// apply at the caret or to the whole selection (none while the note
/// does not have keyboard focus), and the text view to toggle them in.
final class NoteEditorState: ObservableObject {
    @Published var active: Set<TextStyle> = []
    weak var textView: NoteTextView?
}

/// The Bold, Italic, and Underline buttons of a note's bottom bar.
struct StyleButtons: View {
    @ObservedObject var state: NoteEditorState

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TextStyle.allCases, id: \.self) { style in
                StripButton(symbolName: style.symbolName, accessibilityLabel: style.title,
                            isOn: state.active.contains(style)) { _ in
                    state.textView?.toggle(style)
                }
                .frame(width: StripButton.referenceSize.width,
                       height: StripButton.referenceSize.height)
            }
        }
    }
}

// MARK: Links

/// A web address found in text, and where.
struct DetectedLink {
    let range: NSRange
    let url: URL
}

/// Finds web addresses in text. Only http and https links count: the
/// detector gives a bare domain such as "apple.com" an http scheme, and an
/// email address a mailto scheme, which is dropped.
enum LinkDetector {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func links(in text: String) -> [DetectedLink] {
        guard let detector, !text.isEmpty else { return [] }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return detector.matches(in: text, range: range).compactMap { match in
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else { return nil }
            return DetectedLink(range: match.range, url: url)
        }
    }
}

/// Link color and underline, as list rows and text views show links.
let linkDisplayAttributes: [NSAttributedString.Key: Any] = [
    .foregroundColor: NSColor.linkColor,
    .underlineStyle: NSUnderlineStyle.single.rawValue,
]

extension NSTextView {
    /// Shows every web address in the text as a link and returns them.
    /// The link look lives in the layout manager (rendering attributes on
    /// TextKit 2, temporary attributes on TextKit 1), never in the text
    /// storage, so saved text and styles, undo, and copy do not change.
    /// Never reads `layoutManager` on a TextKit 2 view: that would switch
    /// the view to TextKit 1 for good.
    func showLinks() -> [DetectedLink] {
        let links = LinkDetector.links(in: string)
        if let textLayoutManager {
            let document = textLayoutManager.documentRange
            textLayoutManager.removeRenderingAttribute(.foregroundColor, for: document)
            textLayoutManager.removeRenderingAttribute(.underlineStyle, for: document)
            for link in links {
                guard let start = textLayoutManager.location(document.location, offsetBy: link.range.location),
                      let end = textLayoutManager.location(start, offsetBy: link.range.length),
                      let range = NSTextRange(location: start, end: end) else { continue }
                for (key, value) in linkDisplayAttributes {
                    textLayoutManager.addRenderingAttribute(key, value: value, for: range)
                }
            }
        } else if let layoutManager {
            let full = NSRange(location: 0, length: (string as NSString).length)
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: full)
            for link in links {
                layoutManager.addTemporaryAttributes(linkDisplayAttributes, forCharacterRange: link.range)
            }
        }
        needsDisplay = true
        return links
    }

    /// The link of `links` under `point` (view coordinates), with the rect
    /// of the line piece under the point. Uses only text input APIs, which
    /// work on TextKit 1 and 2.
    func link(in links: [DetectedLink], at point: NSPoint) -> (url: URL, rect: NSRect)? {
        guard !links.isEmpty, let window else { return nil }
        let index = characterIndexForInsertion(at: point)
        for link in links where NSLocationInRange(index, link.range)
            || (index > 0 && NSLocationInRange(index - 1, link.range)) {
            // A link can wrap over several lines; check each line's piece.
            var location = link.range.location
            let end = NSMaxRange(link.range)
            while location < end {
                var actual = NSRange(location: NSNotFound, length: 0)
                let screenRect = firstRect(forCharacterRange: NSRange(location: location, length: end - location),
                                           actualRange: &actual)
                guard actual.location != NSNotFound, actual.length > 0 else { break }
                let rect = convert(window.convertFromScreen(screenRect), from: nil)
                if rect.contains(point) { return (link.url, rect) }
                location = NSMaxRange(actual)
            }
        }
        return nil
    }
}

/// A view that shows links: note text views, the list field editor, and
/// list rows that are not being edited.
protocol LinkHost: NSView {
    /// The link under `point`, in this view's coordinates, and its rect.
    func link(at point: NSPoint) -> (url: URL, rect: NSRect)?
}

extension LinkHost {
    /// Opens the link under a Cmd+click and returns true; returns false
    /// for any other click, which the view then handles as usual.
    func openLink(for event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              let link = link(at: convert(event.locationInWindow, from: nil)) else { return false }
        LinkHoverController.shared.reset()
        NSWorkspace.shared.open(link.url)
        return true
    }
}

/// Watches Cmd and the pointer while Notely is active. With Cmd held over
/// a link, shows the pointing hand and, after half a second, the link's
/// preview card. Scrolling, typing, clicking, releasing Cmd, leaving the
/// link, or switching apps closes the card.
final class LinkHoverController {
    static let shared = LinkHoverController()

    private var monitor: Any?
    private weak var host: NSView?
    private var url: URL?
    private var rect: NSRect = .zero
    private var timer: Timer?
    private var popover: NSPopover?

    /// True while Cmd is held over a link; hosts keep the pointing hand.
    var isActive: Bool { url != nil && host != nil }

    func start() {
        guard monitor == nil else { return }
        // A local monitor sees events only while Notely is active.
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .mouseMoved, .scrollWheel, .keyDown, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.reset()
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged, .mouseMoved:
            update(commandHeld: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command))
        default:
            reset()
        }
    }

    /// The link host under the pointer, if any, and the link there.
    private func hostAndLink() -> (host: LinkHost, link: (url: URL, rect: NSRect)?)? {
        let screenPoint = NSEvent.mouseLocation
        let number = NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: 0)
        guard let window = NSApp.window(withWindowNumber: number),
              let content = window.contentView else { return nil }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        var view = content.hitTest(content.superview?.convert(windowPoint, from: nil) ?? windowPoint)
        while let current = view {
            if let host = current as? LinkHost {
                return (host, host.link(at: host.convert(windowPoint, from: nil)))
            }
            view = current.superview
        }
        return nil
    }

    private func update(commandHeld: Bool) {
        let found = commandHeld ? hostAndLink() : nil
        guard let found, let link = found.link else {
            let wasActive = isActive
            reset()
            // Cmd released or the pointer left the link without moving
            // onto other text: put the text pointer back at once.
            if wasActive {
                (hostAndLink() != nil ? NSCursor.iBeam : NSCursor.arrow).set()
            }
            return
        }
        if host === found.host, url == link.url, rect == link.rect {
            applyCursor()
            return
        }
        reset()
        host = found.host
        url = link.url
        rect = link.rect
        applyCursor()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.showPreview()
        }
    }

    /// Text views set the I-beam in their own handling of the same event,
    /// which runs after this monitor; set the hand again after it.
    private func applyCursor() {
        NSCursor.pointingHand.set()
        DispatchQueue.main.async { [weak self] in
            if self?.isActive == true { NSCursor.pointingHand.set() }
        }
    }

    private func showPreview() {
        guard let host, let url, host.window != nil else { return }
        let controller = LinkPreviewViewController(url: url)
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.contentViewController = controller
        controller.onResize = { [weak popover] size in
            popover?.contentSize = size
        }
        // A popover never becomes key, so keyboard focus stays put.
        popover.show(relativeTo: rect, of: host, preferredEdge: .maxY)
        self.popover = popover
        LinkPreviewStore.shared.metadata(for: url) { [weak controller] metadata in
            controller?.show(metadata)
        }
    }

    /// Closes the card and forgets the link.
    func reset() {
        timer?.invalidate()
        timer = nil
        popover?.close()
        popover = nil
        host = nil
        url = nil
    }
}

/// Page previews for the session: fetched only when a card is about to
/// show, at most one request per address at a time, and kept until quit.
/// A failed request is not kept, so a later preview tries again.
final class LinkPreviewStore {
    static let shared = LinkPreviewStore()

    private var cache: [URL: LPLinkMetadata] = [:]
    private var providers: [URL: LPMetadataProvider] = [:]
    private var waiting: [URL: [(LPLinkMetadata) -> Void]] = [:]

    func metadata(for url: URL, completion: @escaping (LPLinkMetadata) -> Void) {
        if let metadata = cache[url] {
            completion(metadata)
            return
        }
        waiting[url, default: []].append(completion)
        guard providers[url] == nil else { return }
        let provider = LPMetadataProvider()
        provider.timeout = 10
        providers[url] = provider
        provider.startFetchingMetadata(for: url) { metadata, _ in
            DispatchQueue.main.async {
                self.providers[url] = nil
                let callbacks = self.waiting.removeValue(forKey: url) ?? []
                guard let metadata else { return }
                self.cache[url] = metadata
                callbacks.forEach { $0(metadata) }
            }
        }
    }
}

/// The preview card's content: the system link preview, showing the
/// address until the page's title, site, and image arrive.
final class LinkPreviewViewController: NSViewController {
    static let width: CGFloat = 300
    /// Height of the caption under a preview image: title and site.
    static let captionHeight: CGFloat = 64

    private let linkView: LPLinkView
    private var heightConstraint: NSLayoutConstraint?
    /// Called with the new size whenever the card changes height. An open
    /// popover keeps the size it opened with, so its owner resizes it.
    var onResize: ((NSSize) -> Void)?

    init(url: URL) {
        linkView = LPLinkView(url: url)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// The link view fills a container of fixed size, so it lays out for
    /// the card's height rather than its own guess.
    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: Self.width, height: 80))
        linkView.translatesAutoresizingMaskIntoConstraints = false
        for orientation in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            linkView.setContentHuggingPriority(.defaultLow, for: orientation)
            linkView.setContentCompressionResistancePriority(.defaultLow, for: orientation)
        }
        container.addSubview(linkView)
        let height = container.heightAnchor.constraint(equalToConstant: 80)
        NSLayoutConstraint.activate([
            linkView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            linkView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            linkView.topAnchor.constraint(equalTo: container.topAnchor),
            linkView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: Self.width),
            height,
        ])
        heightConstraint = height
        view = container
        resize()
    }

    func show(_ metadata: LPLinkMetadata) {
        linkView.metadata = metadata
        resize(hasImage: metadata.imageProvider != nil || metadata.videoProvider != nil)
    }

    /// Fixed width. A page with an image gets a standard height: the image
    /// at the 1.91:1 shape of page preview images, plus the caption.
    /// Without an image, the link view's own height, 80 points at least.
    private func resize(hasImage: Bool = false) {
        let height: CGFloat
        if hasImage {
            height = (Self.width / 1.91).rounded() + Self.captionHeight
        } else {
            let natural = linkView.intrinsicContentSize.height
            height = natural != NSView.noIntrinsicMetric ? max(natural, 80) : 80
        }
        let size = NSSize(width: Self.width, height: height)
        heightConstraint?.constant = height
        preferredContentSize = size
        onResize?(size)
    }
}

/// A note's text view. Text carries bold and italic as trait attributes
/// and underline as `underlineStyle`; `restyle` derives the font, slant,
/// and color from the traits and the text appearance setting, so a font
/// or size change keeps every style. AppKit rather than `TextEditor`,
/// which shows no attributed text before macOS 26.
final class NoteTextView: NSTextView, LinkHost {
    static let styledTextType = NSPasteboard.PasteboardType("com.alvarezjorge.Notely.styled-text")

    var textAppearance: TextAppearance?
    var placeholder = "Type a note…"
    /// Called whenever the active styles may have changed.
    var onStylesChange: ((Set<TextStyle>) -> Void)?
    private var renderedFamily: FontFamily?
    private var renderedSize: Int?
    /// The web addresses shown as links, found again after every change.
    private var links: [DetectedLink] = []

    // MARK: Styles

    func displayAttributes(for traits: Set<TextStyle>) -> [NSAttributedString.Key: Any] {
        var attributes = textAppearance?.noteAttributes(bold: traits.contains(.bold),
                                                        italic: traits.contains(.italic))
            ?? [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.textColor]
        attributes.merge(StyleTraits.attributes(for: traits)) { _, new in new }
        return attributes
    }

    /// Sets the display attributes of `range` from its traits, dropping
    /// every other attribute. Registers no undo.
    func restyle(_ range: NSRange) {
        guard let storage = textStorage, range.length > 0 else { return }
        var pieces: [(NSRange, Set<TextStyle>)] = []
        storage.enumerateAttributes(in: range) { attributes, piece, _ in
            pieces.append((piece, StyleTraits.traits(in: attributes)))
        }
        storage.beginEditing()
        for (piece, traits) in pieces {
            storage.setAttributes(displayAttributes(for: traits), range: piece)
        }
        storage.endEditing()
    }

    private var fullRange: NSRange {
        NSRange(location: 0, length: textStorage?.length ?? 0)
    }

    /// Shows `text` with the styles of `runs`, with no undo history.
    func load(text: String, runs: [StyleRun]) {
        textStorage?.setAttributedString(StyleTraits.attributed(text, runs: runs))
        renderedFamily = textAppearance?.family
        renderedSize = textAppearance?.size
        restyle(fullRange)
        typingAttributes = displayAttributes(for: [])
        links = showLinks()
    }

    /// Restyles every character after a font or size change, keeping the
    /// styles for new typing.
    func applyAppearance() {
        guard let appearance = textAppearance,
              appearance.family != renderedFamily || appearance.size != renderedSize else { return }
        renderedFamily = appearance.family
        renderedSize = appearance.size
        let typing = StyleTraits.traits(in: typingAttributes)
        restyle(fullRange)
        typingAttributes = displayAttributes(for: typing)
        links = showLinks()
        needsDisplay = true
    }

    var runs: [StyleRun] {
        textStorage.map { StyleTraits.runs(of: $0) } ?? []
    }

    /// The styles of the whole selection, or with no selection those for
    /// new typing; none while the text view does not have keyboard focus.
    var activeStyles: Set<TextStyle> {
        guard window?.firstResponder === self, let storage = textStorage else { return [] }
        let ranges = selectedRanges.map(\.rangeValue).filter { $0.length > 0 }
        if ranges.isEmpty {
            return StyleTraits.traits(in: typingAttributes)
        }
        var common = Set(TextStyle.allCases)
        for range in ranges {
            storage.enumerateAttributes(in: range) { attributes, _, stop in
                common.formIntersection(StyleTraits.traits(in: attributes))
                if common.isEmpty { stop.pointee = true }
            }
        }
        return common
    }

    func notifyStyles() {
        onStylesChange?(activeStyles)
    }

    /// Toggles `style` on the selection, or with no selection for new
    /// typing. A selection that has the style everywhere loses it;
    /// otherwise all of it gets it.
    func toggle(_ style: TextStyle) {
        if window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }
        let ranges = selectedRanges.map(\.rangeValue).filter { $0.length > 0 }
        guard let storage = textStorage, !ranges.isEmpty else {
            var traits = StyleTraits.traits(in: typingAttributes)
            traits.formSymmetricDifference([style])
            typingAttributes = displayAttributes(for: traits)
            notifyStyles()
            return
        }
        let remove = activeStyles.contains(style)
        guard shouldChangeText(inRanges: ranges.map { NSValue(range: $0) }, replacementStrings: nil) else { return }
        storage.beginEditing()
        for range in ranges {
            var pieces: [(NSRange, Set<TextStyle>)] = []
            storage.enumerateAttributes(in: range) { attributes, piece, _ in
                pieces.append((piece, StyleTraits.traits(in: attributes)))
            }
            for (piece, traits) in pieces {
                var traits = traits
                if remove { traits.remove(style) } else { traits.insert(style) }
                storage.setAttributes(displayAttributes(for: traits), range: piece)
            }
        }
        storage.endEditing()
        didChangeText()
        notifyStyles()
    }

    @objc func toggleNoteBold(_ sender: Any?) { toggle(.bold) }
    @objc func toggleNoteItalic(_ sender: Any?) { toggle(.italic) }
    @objc func toggleNoteUnderline(_ sender: Any?) { toggle(.underline) }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        let styles: [Selector: TextStyle] = [
            #selector(toggleNoteBold(_:)): .bold,
            #selector(toggleNoteItalic(_:)): .italic,
            #selector(toggleNoteUnderline(_:)): .underline,
        ]
        if let action = item.action, let style = styles[action] {
            (item as? NSMenuItem)?.state = activeStyles.contains(style) ? .on : .off
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    override func didChangeText() {
        // Undo and redo put back attributes rendered for the font
        // setting at that time; render them for the current one.
        if undoManager?.isUndoing == true || undoManager?.isRedoing == true {
            restyle(fullRange)
        }
        super.didChangeText()
        // Typing, paste, cut, undo, and redo all end here.
        links = showLinks()
        needsDisplay = true
    }

    // MARK: Links

    func link(at point: NSPoint) -> (url: URL, rect: NSRect)? {
        link(in: links, at: point)
    }

    /// Cmd+click on a link opens it and leaves the caret alone.
    override func mouseDown(with event: NSEvent) {
        if openLink(for: event) { return }
        super.mouseDown(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        if LinkHoverController.shared.isActive {
            NSCursor.pointingHand.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    // MARK: Pasteboard

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        super.writablePasteboardTypes + [Self.styledTextType]
    }

    /// Adds the selection's text and runs as a private type next to RTF
    /// and plain text, so a slanted italic copies exactly between notes.
    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == Self.styledTextType else { return super.writeSelection(to: pboard, type: type) }
        guard let storage = textStorage else { return false }
        let range = selectedRange()
        guard range.length > 0 else { return false }
        let selection = storage.attributedSubstring(from: range)
        let payload = StyledText(text: selection.string, styles: StyleTraits.runs(of: selection))
        guard let data = try? JSONEncoder().encode(payload) else { return false }
        return pboard.setData(data, forType: type)
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [Self.styledTextType] + super.readablePasteboardTypes
    }

    /// Paste and drop keep only bold, italic, and underline; the text
    /// takes the note's font, size, and color. Plain text takes the
    /// styles for new typing.
    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        let incoming: NSMutableAttributedString
        if let data = pboard.data(forType: Self.styledTextType),
           let payload = try? JSONDecoder().decode(StyledText.self, from: data) {
            incoming = StyleTraits.attributed(payload.text, runs: payload.styles)
        } else if let rich = Self.richText(from: pboard) {
            incoming = StyleTraits.sanitized(rich)
        } else if let plain = pboard.string(forType: .string) {
            let typing = StyleTraits.traits(in: typingAttributes)
            incoming = NSMutableAttributedString(string: plain, attributes: StyleTraits.attributes(for: typing))
        } else {
            return false
        }
        insertStyled(incoming)
        return true
    }

    private static func richText(from pboard: NSPasteboard) -> NSAttributedString? {
        if let data = pboard.data(forType: .rtfd), let text = NSAttributedString(rtfd: data, documentAttributes: nil) {
            return text
        }
        if let data = pboard.data(forType: .rtf), let text = NSAttributedString(rtf: data, documentAttributes: nil) {
            return text
        }
        if let data = pboard.data(forType: .html), let text = NSAttributedString(html: data, documentAttributes: nil) {
            return text
        }
        return nil
    }

    /// Replaces the selection with `text` as one undoable change.
    private func insertStyled(_ text: NSMutableAttributedString) {
        let range = rangeForUserTextChange
        guard range.location != NSNotFound, let storage = textStorage,
              shouldChangeText(in: range, replacementString: text.string) else { return }
        storage.replaceCharacters(in: range, with: text)
        restyle(NSRange(location: range.location, length: text.length))
        didChangeText()
        setSelectedRange(NSRange(location: range.location + text.length, length: 0))
    }

    // MARK: Behavior kept from the note's former text editor

    /// Esc ends editing and keeps the text.
    override func cancelOperation(_ sender: Any?) {
        window?.makeFirstResponder(nil)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        DispatchQueue.main.async { [weak self] in self?.notifyStyles() }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        DispatchQueue.main.async { [weak self] in self?.notifyStyles() }
        return resigned
    }

    /// The placeholder starts where the first typed character appears,
    /// at every font and size, since both use the text container's origin.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty else { return }
        let padding = textContainer?.lineFragmentPadding ?? 0
        let origin = NSPoint(x: textContainerOrigin.x + padding, y: textContainerOrigin.y)
        NSAttributedString(string: placeholder, attributes: displayAttributes(for: [])).draw(at: origin)
    }
}

/// Keeps a note's text view at least as tall as the visible area, so a
/// click below the last line still puts the caret in the note.
final class NoteScrollView: NSScrollView {
    override func tile() {
        super.tile()
        guard let textView = documentView as? NSTextView,
              textView.minSize.height != contentSize.height else { return }
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.sizeToFit()
    }
}

/// Hosts a note's `NoteTextView`. Loads the note's text and styles once;
/// after that the text view owns them and saves every change.
struct NoteEditor: NSViewRepresentable {
    let store: NoteStore
    let appearance: TextAppearance
    /// Passed by value so SwiftUI updates the view when either changes.
    let family: FontFamily
    let size: Int
    let id: UUID
    let state: NoteEditorState

    func makeNSView(context: Context) -> NoteScrollView {
        let scrollView = NoteScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let contentSize = scrollView.contentSize
        let textView = NoteTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: contentSize.width,
                                                       height: .greatestFiniteMagnitude)
        textView.textContainerInset = .zero
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.allowsDocumentBackgroundColorChange = false
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.textAppearance = appearance
        let note = store.note(id)
        textView.load(text: note?.text ?? "", runs: note?.styles ?? [])
        textView.delegate = context.coordinator
        let state = self.state
        textView.onStylesChange = { styles in
            if state.active != styles { state.active = styles }
        }
        state.textView = textView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NoteScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NoteTextView else { return }
        textView.textAppearance = appearance
        textView.applyAppearance()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteEditor

        init(_ parent: NoteEditor) { self.parent = parent }

        /// Saves text and styles together on every change, style-only
        /// changes included.
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NoteTextView else { return }
            parent.store.setText(textView.string, styles: textView.runs, for: parent.id)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            (notification.object as? NoteTextView)?.notifyStyles()
        }
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
final class ListTextField: NSTextField, LinkHost {
    var isTitle = false
    var onToggle: (() -> Void)?

    /// Cmd+click on a link opens it, also while another app is active,
    /// and does not start editing.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if openLink(for: event) { return }
        super.mouseDown(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        if LinkHoverController.shared.isActive {
            NSCursor.pointingHand.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    /// The link under `point` while the row is not being edited, found by
    /// laying out the shown text in a separate TextKit 1 stack the size of
    /// the cell's text area. While the row is edited, the field editor,
    /// which sits on top of the row, answers instead.
    func link(at point: NSPoint) -> (url: URL, rect: NSRect)? {
        guard currentEditor() == nil, let cell else { return nil }
        let text = attributedStringValue
        let links = LinkDetector.links(in: text.string)
        guard !links.isEmpty else { return nil }

        let textRect = cell.titleRect(forBounds: bounds)
        let storage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: textRect.width, height: .greatestFiniteMagnitude))
        // NSTextFieldCell lays out its text with this padding.
        container.lineFragmentPadding = 2
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        // Container coordinates run down from the top of the text area.
        func toContainer(_ point: NSPoint) -> NSPoint {
            NSPoint(x: point.x - textRect.minX,
                    y: isFlipped ? point.y - textRect.minY : textRect.maxY - point.y)
        }
        func toView(_ rect: NSRect) -> NSRect {
            NSRect(x: rect.minX + textRect.minX,
                   y: isFlipped ? rect.minY + textRect.minY : textRect.maxY - rect.maxY,
                   width: rect.width, height: rect.height)
        }

        let containerPoint = toContainer(point)
        var fraction: CGFloat = 0
        let glyph = layoutManager.glyphIndex(for: containerPoint, in: container,
                                             fractionOfDistanceThroughGlyph: &fraction)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard glyphRect.contains(containerPoint) else { return nil }
        let index = layoutManager.characterIndexForGlyph(at: glyph)
        guard let link = links.first(where: { NSLocationInRange(index, $0.range) }) else { return nil }
        // The rect of the link's piece on the line under the pointer.
        var lineRange = NSRange()
        _ = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &lineRange)
        let linkGlyphs = NSIntersectionRange(layoutManager.glyphRange(forCharacterRange: link.range,
                                                                      actualCharacterRange: nil),
                                             lineRange)
        let rect = layoutManager.boundingRect(forGlyphRange: linkGlyphs, in: container)
        return (link.url, toView(rect))
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(toggleChecklistItem(_:)) { return onToggle != nil }
        return super.responds(to: aSelector)
    }

    @objc func toggleChecklistItem(_ sender: Any?) {
        onToggle?()
    }
}

/// The field editor of list rows: AppKit's shared editor for a window,
/// replaced in list windows so rows show links and open them with
/// Cmd+click while they are edited. TextKit 1, like AppKit's own field
/// editor; `ListField` reads its `layoutManager` for caret lines.
final class LinkFieldEditor: NSTextView, LinkHost {
    private var links: [DetectedLink] = []

    func refreshLinks() {
        links = showLinks()
    }

    /// The row's text arrives here when editing starts, and when the list
    /// changes it from outside.
    override var string: String {
        didSet { refreshLinks() }
    }

    override func didChangeText() {
        super.didChangeText()
        refreshLinks()
    }

    /// AppKit inserts the editor into a row each time editing starts.
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        DispatchQueue.main.async { [weak self] in self?.refreshLinks() }
    }

    func link(at point: NSPoint) -> (url: URL, rect: NSRect)? {
        link(in: links, at: point)
    }

    override func mouseDown(with event: NSEvent) {
        if openLink(for: event) { return }
        super.mouseDown(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        if LinkHoverController.shared.isActive {
            NSCursor.pointingHand.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }
}

/// One editable, wrapping list row: the title, an item, or "New item".
/// AppKit rather than a SwiftUI `TextField`, because Return, Backspace and
/// the arrow keys must be intercepted, and `onKeyPress` needs macOS 14.
struct ListField: NSViewRepresentable {
    let text: String
    let placeholder: String
    let font: NSFont
    var done = false
    var isTitle = false
    var canToggle = false
    let target: FocusTarget
    @ObservedObject var focus: ListFocus
    var onChange: (String) -> Void
    var onEndEditing: () -> Void = {}
    var onCommand: (ListCommand) -> Bool = { _ in false }

    /// All list text, placeholders included, is white in dark appearance
    /// and black in light appearance, except web addresses, which show as
    /// links; checked items are struck through, links included.
    static func styled(_ text: String, font: NSFont, done: Bool) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
        ]
        if done {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        let result = NSMutableAttributedString(string: text, attributes: attributes)
        for link in LinkDetector.links(in: text) {
            result.addAttributes(linkDisplayAttributes, range: link.range)
        }
        return result
    }

    static func placeholderString(_ placeholder: String, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: placeholder, attributes: [
            .font: font,
            .foregroundColor: NSColor.textColor,
        ])
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
        field.font = font
        field.textColor = .textColor
        field.placeholderAttributedString = Self.placeholderString(placeholder, font: font)
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

        // The text appearance setting changed: restyle in place. The field
        // editor keeps its text, caret, and undo history; only its font
        // changes.
        if field.font != font {
            field.font = font
            field.placeholderAttributedString = Self.placeholderString(placeholder, font: font)
            if let editor = field.currentEditor() as? NSTextView {
                editor.font = font
                editor.typingAttributes[.font] = font
            }
            field.invalidateIntrinsicContentSize()
        }

        if let editor = field.currentEditor() as? NSTextView {
            // While editing, the store already holds the typed text; only
            // an outside change (the "New item" row turning into an item)
            // replaces it. Never touch text an input method is composing.
            if !editor.hasMarkedText(), editor.string != text {
                editor.string = text
            }
        } else {
            field.attributedStringValue = Self.styled(text, font: font, done: done)
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
        cell.attributedStringValue = Self.styled(text.isEmpty ? " " : text, font: font, done: done)
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
                field.attributedStringValue = ListField.styled(field.stringValue, font: parent.font,
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
    @ObservedObject var appearance: TextAppearance
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
                              font: appearance.nsFont(bold: true),
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
            BottomBar(store: store, appearance: appearance, id: id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoteBackground(tint: store.note(id)?.tint))
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
                          font: appearance.nsFont(bold: false),
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
                          font: appearance.nsFont(bold: false),
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
    @ObservedObject var store: NoteStore
    @ObservedObject var appearance: TextAppearance
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

    // Only a note's text view responds to these, so they are disabled
    // unless a note has keyboard focus, and do nothing in lists.
    let formatMenu = NSMenu(title: "Format")
    formatMenu.addItem(withTitle: "Bold", action: #selector(NoteTextView.toggleNoteBold(_:)), keyEquivalent: "b")
    formatMenu.addItem(withTitle: "Italic", action: #selector(NoteTextView.toggleNoteItalic(_:)), keyEquivalent: "i")
    formatMenu.addItem(withTitle: "Underline", action: #selector(NoteTextView.toggleNoteUnderline(_:)), keyEquivalent: "u")

    let appItem = NSMenuItem()
    appItem.submenu = appMenu
    let editItem = NSMenuItem()
    editItem.submenu = editMenu
    let formatItem = NSMenuItem()
    formatItem.submenu = formatMenu

    let mainMenu = NSMenu()
    mainMenu.addItem(appItem)
    mainMenu.addItem(editItem)
    mainMenu.addItem(formatItem)
    return mainMenu
}

/// Moves `frame` the shortest distance (x and y only) to sit fully inside
/// `screen`. Shared by `restoredFrame` (relaunch) and `newNoteFrame` (a
/// new note or list placed next to the menu), so both use the same rule.
func clamp(_ frame: NSRect, into screen: NSRect) -> NSPoint {
    NSPoint(x: min(max(frame.minX, screen.minX), screen.maxX - frame.width),
           y: min(max(frame.minY, screen.minY), screen.maxY - frame.height))
}

/// Smallest size a note or list window can have: wide enough for the
/// six bottom bar buttons of a note, and room for the bottom bar and one
/// line of text.
let minimumNoteSize = NSSize(width: 190, height: 120)

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

/// A tint as saved in `Note.tint`: sRGB "#RRGGBB". Alpha is dropped, so
/// no color can make a note's tint stronger than `tintStrength`.
func tintString(_ color: NSColor) -> String? {
    guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
    let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
    return String(format: "#%02X%02X%02X",
                  channel(rgb.redComponent), channel(rgb.greenComponent), channel(rgb.blueComponent))
}

/// The color of a saved tint, or nil when nothing usable is saved.
func tintColor(_ saved: String?) -> NSColor? {
    guard let saved, saved.count == 7, saved.first == "#",
          saved.dropFirst().allSatisfy(\.isHexDigit),
          let value = UInt32(saved.dropFirst(), radix: 16) else { return nil }
    return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                   green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255,
                   alpha: 1)
}

/// The tint menu's preset colors, in menu order. Fixed values, not system
/// colors: system colors change with the appearance, so a saved preset
/// would stop matching its menu entry.
let tintPresets: [(name: String, tint: String)] = [
    ("Yellow", "#FFD60A"),
    ("Orange", "#FF9F0A"),
    ("Pink", "#FF375F"),
    ("Purple", "#BF5AF2"),
    ("Blue", "#0A84FF"),
    ("Green", "#30D158"),
    ("Gray", "#8E8E93"),
]

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
    let appearance = TextAppearance()
    var windows: [UUID: NoteWindow] = [:]
    var menuWindow: NSWindow?
    /// Window delegates are weak; this keeps the menu's alive.
    let menuDelegate = MenuWindowDelegate()
    /// One scroller-style observation per note window, keyed by window.
    var scrollerObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    /// One list-row field editor per list window, keyed by window.
    var fieldEditors: [ObjectIdentifier: LinkFieldEditor] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        LinkHoverController.shared.start()

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
        // From macOS 14, views do not clip their subviews by default. A
        // list's rows are real NSViews inside the scroll view; keep them
        // inside its frame, clear of the top and bottom bars. (The title
        // bar safe area, the other cause, is turned off in `openWindow`.)
        if #available(macOS 14, *) {
            scrollView.clipsToBounds = true
            scrollView.contentView.clipsToBounds = true
        }

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
            appearance: appearance,
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
            appearance: appearance,
            id: note.id,
            onClose: { [weak self] in self?.closeNote(note.id) },
            onDelete: { [weak self] in self?.confirmDelete(note.id) }
        ))
        // The window alone owns its size; SwiftUI's preferred size must
        // not pin it.
        hostingView.sizingOptions = []
        // The note draws its own bars, so the transparent title bar gives
        // SwiftUI no safe area. Otherwise a list's ScrollView takes the
        // title bar height as a content inset and scrolls its rows up over
        // the drag area.
        if #available(macOS 13.3, *) {
            hostingView.safeAreaRegions = []
        }
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        // The drag handle performs dragging explicitly; disable
        // background-drag so it doesn't fight the text editor's own
        // mouse handling elsewhere in the window.
        window.isMovableByWindowBackground = false
        // The link pointer and preview follow the pointer over text.
        window.acceptsMouseMovedEvents = true
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
        fieldEditors.removeValue(forKey: ObjectIdentifier(window))
        return window
    }

    /// List rows edit in a `LinkFieldEditor`, one per window, so they show
    /// and open links while edited. Every other client gets AppKit's own.
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        guard client is ListTextField else { return nil }
        let key = ObjectIdentifier(sender)
        if let editor = fieldEditors[key] { return editor }
        let editor = LinkFieldEditor(usingTextLayoutManager: false)
        editor.isFieldEditor = true
        // As AppKit's own field editor: plain text, with undo.
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        fieldEditors[key] = editor
        return editor
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
        TintControls.closePanel()
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
