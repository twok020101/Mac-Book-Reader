import SwiftUI
import SwiftData

public struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    
    @StateObject private var viewModel = LibraryViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedTab = 0
    
    public init() {}
    
    var filteredBooks: [Book] {
        books.filter { book in
            let matchesSearch = viewModel.searchText.isEmpty || book.title.localizedCaseInsensitiveContains(viewModel.searchText)
            let matchesCollection = viewModel.selectedCollection == nil || book.collection == viewModel.selectedCollection
            return matchesSearch && matchesCollection
        }
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Books Tab
            NavigationStack {
                BookGridView(books: filteredBooks, columnVisibility: $columnVisibility)
                    .searchable(text: $viewModel.searchText, prompt: "Search books...")
                    .toolbar {
                        Button(action: { viewModel.isImporting = true }) {
                            Label("Import", systemImage: "plus")
                        }
                    }
                    .sheet(isPresented: $viewModel.isImporting) {
                        ImportBookView(isPresented: $viewModel.isImporting) { urls in
                            viewModel.importBooks(urls: urls, context: modelContext)
                        }
                    }
            }
            .tabItem {
                Label("Books", systemImage: "books.vertical")
            }
            .tag(0)
            
            // Notes Tab
            NavigationStack {
                NotesView()
            }
            .tabItem {
                Label("Notes", systemImage: "note.text")
            }
            .tag(1)
        }
    }
}
