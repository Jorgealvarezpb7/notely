import Foundation
import NotelyCore
import Testing

/// A store over an in-memory repository holding one list with `items`.
private func storeWithList(_ items: [ListItem]) -> (NoteStore, InMemoryNoteRepository, UUID) {
    let id = UUID()
    let list = Note(id: id, text: "", kind: Note.listKind, title: "", items: items)
    let repository = InMemoryNoteRepository([list])
    return (NoteStore(repository: repository), repository, id)
}

private func item(_ text: String, done: Bool = false) -> ListItem {
    ListItem(id: UUID(), text: text, done: done)
}

struct NoteStoreTests {
    @Test func loadsFromRepository() {
        let note = Note(id: UUID(), text: "Saved")
        let store = NoteStore(repository: InMemoryNoteRepository([note]))
        #expect(store.notes.map(\.id) == [note.id])
    }

    @Test func addSavesAnEmptyNote() {
        let repository = InMemoryNoteRepository()
        let store = NoteStore(repository: repository)
        let note = store.add(origin: "{1, 2}", size: "{220, 150}")
        #expect(store.notes.map(\.id) == [note.id])
        #expect(note.text == "")
        #expect(note.origin == "{1, 2}")
        #expect(note.size == "{220, 150}")
        #expect(!note.isList)
        #expect(repository.stored.map(\.id) == [note.id])
    }

    @Test func addListSavesAnEmptyList() {
        let repository = InMemoryNoteRepository()
        let store = NoteStore(repository: repository)
        let list = store.addList(origin: nil, size: nil)
        #expect(list.isList)
        #expect(list.title == "")
        #expect(list.items == [])
        #expect(repository.stored.first?.isList == true)
    }

    @Test func removeSaves() {
        let note = Note(id: UUID(), text: "Gone")
        let repository = InMemoryNoteRepository([note])
        let store = NoteStore(repository: repository)
        store.remove(note.id)
        #expect(store.notes.isEmpty)
        #expect(repository.stored.isEmpty)
    }

    @Test func setTextSavesEmptyStylesAsNone() {
        let note = Note(id: UUID(), text: "")
        let repository = InMemoryNoteRepository([note])
        let store = NoteStore(repository: repository)

        store.setText("Hello", styles: [], for: note.id)
        #expect(repository.stored.first?.text == "Hello")
        #expect(repository.stored.first?.styles == nil)

        let bold = StyleRun(location: 0, length: 5, bold: true)
        store.setText("Hello", styles: [bold], for: note.id)
        #expect(repository.stored.first?.styles == [bold])
    }

    @Test func setTintSavesOnlyChanges() {
        let note = Note(id: UUID(), text: "")
        let repository = InMemoryNoteRepository([note])
        let store = NoteStore(repository: repository)

        store.setTint("#FFD60A", for: note.id)
        store.setTint("#FFD60A", for: note.id)
        #expect(repository.saves.count == 1)
        store.setTint(nil, for: note.id)
        #expect(repository.saves.count == 2)
        #expect(repository.stored.first?.tint == nil)
    }

    @Test func setFrameAndOpenSave() {
        let note = Note(id: UUID(), text: "")
        let repository = InMemoryNoteRepository([note])
        let store = NoteStore(repository: repository)
        store.setFrame(origin: "{5, 6}", size: "{300, 200}", for: note.id)
        store.setOpen(false, for: note.id)
        #expect(repository.stored.first?.origin == "{5, 6}")
        #expect(repository.stored.first?.size == "{300, 200}")
        #expect(repository.stored.first?.isOpen == false)
    }

    @Test func appendedItemGoesAfterUncheckedItems() {
        let a = item("A"), b = item("B", done: true)
        let (store, _, id) = storeWithList([a, b])
        store.appendItem("C", for: id)
        #expect(store.note(id)?.items?.map(\.text) == ["A", "C", "B"])
    }

    @Test func insertedItemGoesAfterItsItem() {
        let a = item("A"), b = item("B")
        let (store, _, id) = storeWithList([a, b])
        let new = store.insertItem(after: a.id, for: id)
        #expect(store.note(id)?.items?.map(\.id) == [a.id, new, b.id])
        #expect(store.note(id)?.items?[1].text == "")
    }

    @Test func checkedItemMovesToTopOfCheckedItems() {
        let a = item("A"), b = item("B"), c = item("C", done: true)
        let (store, _, id) = storeWithList([a, b, c])
        store.toggleItem(a.id, for: id)
        #expect(store.note(id)?.items?.map(\.text) == ["B", "A", "C"])
        #expect(store.note(id)?.items?[1].done == true)
    }

    @Test func uncheckedItemMovesToEndOfUncheckedItems() {
        let a = item("A"), b = item("B", done: true), c = item("C", done: true)
        let (store, _, id) = storeWithList([a, b, c])
        store.toggleItem(c.id, for: id)
        #expect(store.note(id)?.items?.map(\.text) == ["A", "C", "B"])
        #expect(store.note(id)?.items?[1].done == false)
    }

    @Test func removeItemSavesOnlyKnownItems() {
        let a = item("A")
        let (store, repository, id) = storeWithList([a])
        store.removeItem(UUID(), for: id)
        #expect(repository.saves.isEmpty)
        store.removeItem(a.id, for: id)
        #expect(store.note(id)?.items == [])
        #expect(repository.saves.count == 1)
    }

    @Test func everyListChangeRefreshesPlainText() {
        let (store, repository, id) = storeWithList([])
        store.setTitle("Groceries", for: id)
        let milk = store.appendItem("Milk", for: id)
        store.appendItem("Egs", for: id)
        store.toggleItem(milk, for: id)
        if let eggs = store.note(id)?.items?.first(where: { $0.text == "Egs" }) {
            store.setItemText("Eggs", item: eggs.id, for: id)
        }
        #expect(store.note(id)?.text == "Groceries\n[ ] Eggs\n[x] Milk")
        #expect(repository.stored.first?.text == "Groceries\n[ ] Eggs\n[x] Milk")
    }
}
