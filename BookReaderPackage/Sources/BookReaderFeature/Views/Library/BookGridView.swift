import SwiftUI

public struct BookGridView: View {
    let books: [Book]
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    public init(books: [Book], columnVisibility: Binding<NavigationSplitViewVisibility>) {
        self.books = books
        self._columnVisibility = columnVisibility
    }
    
    public var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                ForEach(books) { book in
                    NavigationLink(destination: ReaderView(book: book, columnVisibility: $columnVisibility)) {
                        BookCard(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}
