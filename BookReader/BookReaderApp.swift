import SwiftUI
import SwiftData
import BookReaderFeature

@main
struct BookReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Book.self, Collection.self, Note.self, ReadingProgress.self])
        }
        
        // Window group for books - allows opening multiple books
        WindowGroup(for: BookWindowRequest.self) { $request in
            if let request = request {
                BookReaderWindow(request: request)
                    .modelContainer(for: [Book.self, Collection.self, Note.self, ReadingProgress.self])
            }
        }
    }
}

// Helper view to load and display book in window
struct BookReaderWindow: View {
    let request: BookWindowRequest
    @Query private var allBooks: [Book]
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var book: Book? {
        allBooks.first { $0.id == request.bookID }
    }
    
    var body: some View {
        if let book = book {
            ReaderView(
                book: book,
                columnVisibility: $columnVisibility,
                initialChapterIndex: request.chapterIndex,
                initialPageIndex: request.pageIndex
            )
        } else {
            Text("Book not found")
        }
    }
}
