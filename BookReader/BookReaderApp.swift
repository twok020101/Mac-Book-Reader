import SwiftUI
import SwiftData
import BookReaderFeature

@main
struct BookReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Book.self,
            ReadingProgress.self,
            Note.self,
            Collection.self
        ])
    }
}
