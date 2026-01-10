import SwiftUI
import SwiftData

public struct BookGridView: View {
    let books: [Book]
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @State private var bookToDelete: Book?
    @State private var showDeleteConfirmation = false
    
    public init(books: [Book], columnVisibility: Binding<NavigationSplitViewVisibility>) {
        self.books = books
        self._columnVisibility = columnVisibility
    }
    
    public var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                ForEach(books) { book in
                    Button {
                        openWindow(value: BookWindowRequest(bookID: book.id))
                    } label: {
                        BookCard(book: book)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            bookToDelete = book
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Book", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .alert("Delete Book?", isPresented: $showDeleteConfirmation, presenting: bookToDelete) { book in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteBook(book)
            }
        } message: { book in
            Text("Are you sure you want to delete \"\(book.title)\"? This will also delete all notes and progress for this book.")
        }
    }
    
    private func deleteBook(_ book: Book) {
        // Delete file from disk
        if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docsURL.appendingPathComponent(book.filePath)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Delete from database (SwiftData will cascade delete notes and progress)
        modelContext.delete(book)
    }
}
