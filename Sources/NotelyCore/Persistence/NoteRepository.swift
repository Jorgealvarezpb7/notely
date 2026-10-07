import Foundation

/// Where notes are kept between launches. `NoteStore` loads once at start
/// and saves the whole list after every change.
public protocol NoteRepository {
    /// Every saved note, with damaged data repaired or replaced.
    func load() -> [Note]
    func save(_ notes: [Note])
}

/// Keeps notes as one JSON array in `UserDefaults`, the same timing the
/// single-note version relied on: normal termination flushes
/// `UserDefaults`, so a save on every keystroke and every move is what
/// keeps text and position through a quit.
public struct UserDefaultsNoteRepository: NoteRepository {
    private static let notesKey = "notes"
    private static let legacyTextKey = "noteText"
    private static let legacyOriginKey = "panelOrigin"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [Note] {
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
                return decoded
            }
            let notes = [Note(id: UUID(), text: "", origin: nil, size: nil)]
            save(notes)
            return notes
        }
        // First launch of this version: migrate the single-note keys into
        // one note, then remove them.
        let text = defaults.string(forKey: Self.legacyTextKey) ?? ""
        let origin = defaults.string(forKey: Self.legacyOriginKey)
        let notes = [Note(id: UUID(), text: text, origin: origin, size: nil)]
        defaults.removeObject(forKey: Self.legacyTextKey)
        defaults.removeObject(forKey: Self.legacyOriginKey)
        save(notes)
        return notes
    }

    public func save(_ notes: [Note]) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: Self.notesKey)
    }
}
