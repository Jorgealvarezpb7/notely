import Foundation
@testable import NotelyCore
import Testing

struct StyleRunTests {
    @Test func runInsideTextIsKept() {
        let run = StyleRun(location: 2, length: 3, bold: true)
        #expect(run.clamped(toLength: 10) == run)
    }

    @Test func runPastTheEndIsTrimmed() {
        let run = StyleRun(location: 8, length: 5, italic: true)
        #expect(run.clamped(toLength: 10) == StyleRun(location: 8, length: 2, italic: true))
    }

    @Test func runBeforeTheStartIsTrimmed() {
        let run = StyleRun(location: -2, length: 5, underline: true)
        #expect(run.clamped(toLength: 10) == StyleRun(location: 0, length: 3, underline: true))
    }

    @Test func runOutsideTextIsDropped() {
        #expect(StyleRun(location: 12, length: 3, bold: true).clamped(toLength: 10) == nil)
        #expect(StyleRun(location: 3, length: 0, bold: true).clamped(toLength: 10) == nil)
    }
}

struct PlainTextTests {
    @Test func listBecomesTitleAndCheckboxLines() {
        var note = Note(id: UUID(), text: "")
        note.kind = Note.listKind
        note.title = "Groceries"
        note.items = [ListItem(id: UUID(), text: "Milk", done: false),
                      ListItem(id: UUID(), text: "Eggs", done: true)]
        #expect(plainText(ofList: note) == "Groceries\n[ ] Milk\n[x] Eggs")
    }

    @Test func emptyListIsEmptyText() {
        #expect(plainText(ofList: Note(id: UUID(), text: "")) == "")
    }
}

struct TitleTests {
    @Test func noteTitleIsFirstNonEmptyLine() {
        #expect(noteTitle("\n   \n  Hello  \nWorld") == "Hello")
    }

    @Test func noteWithoutTextIsUntitled() {
        #expect(noteTitle("") == "Untitled note")
        #expect(noteTitle("  \n\t\n") == "Untitled note")
    }

    @Test func listTitleIsTrimmed() {
        #expect(listTitle("  Groceries \n") == "Groceries")
    }

    @Test func listWithoutTitleIsUntitled() {
        #expect(listTitle(nil) == "Untitled list")
        #expect(listTitle("   ") == "Untitled list")
    }
}

struct TintTests {
    @Test func parsesSavedTint() {
        #expect(TintRGB(hex: "#FFD60A") == TintRGB(red: 255, green: 214, blue: 10))
        #expect(TintRGB(hex: "#ffd60a") == TintRGB(red: 255, green: 214, blue: 10))
    }

    @Test func rejectsUnusableTint() {
        #expect(TintRGB(hex: nil) == nil)
        #expect(TintRGB(hex: "#FFF") == nil)
        #expect(TintRGB(hex: "FFD60A0") == nil)
        #expect(TintRGB(hex: "#GGGGGG") == nil)
    }

    @Test func savesUppercaseHex() {
        #expect(TintRGB(red: 255, green: 214, blue: 10).hex == "#FFD60A")
        #expect(TintRGB(red: 0, green: 0, blue: 0).hex == "#000000")
    }

    /// The tint menu's presets, as `tintPresets` in the app lists them.
    @Test(arguments: ["#FFD60A", "#FF9F0A", "#FF375F", "#BF5AF2", "#0A84FF", "#30D158", "#8E8E93"])
    func presetRoundTrips(_ preset: String) {
        #expect(TintRGB(hex: preset)?.hex == preset)
    }
}
