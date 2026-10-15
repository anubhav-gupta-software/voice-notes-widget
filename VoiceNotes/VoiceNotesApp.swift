import SwiftUI

@main
struct VoiceNotesApp: App {
    @State private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
