import AppKit
import NotelyCore
import SwiftUI

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
