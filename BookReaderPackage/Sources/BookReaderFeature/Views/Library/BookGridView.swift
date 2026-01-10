import SwiftUI

public struct BookGridView: View {
    let books: [Book]
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Environment(\.openWindow) private var openWindow
    
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
                }
            }
            .padding()
        }
    }
}
