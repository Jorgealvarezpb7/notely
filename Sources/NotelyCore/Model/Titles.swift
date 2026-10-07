import Foundation

/// A list's menu row title: its title after trimming whitespace, or
/// "Untitled list" when that is empty.
public func listTitle(_ title: String?) -> String {
    let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Untitled list" : trimmed
}

/// A menu row's title: the first line of `text` that is not empty after
/// trimming whitespace, or "Untitled note" when there is none.
public func noteTitle(_ text: String) -> String {
    text.split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .first { !$0.isEmpty } ?? "Untitled note"
}
