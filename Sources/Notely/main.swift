import NotelyCore
import NotelyLinks
import NotelyUI

// Composition root: builds the shared state once and hands it to the app.
// Top-level code runs on the main thread, where the app must run.
MainActor.assumeIsolated {
    NotelyApp.run(
        store: NoteStore(repository: UserDefaultsNoteRepository(defaults: .standard)),
        appearance: TextAppearance(),
        linkPages: LinkPageStore()
    )
}
