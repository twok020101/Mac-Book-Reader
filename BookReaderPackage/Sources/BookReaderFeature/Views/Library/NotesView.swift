import SwiftUI
import SwiftData

public struct NotesView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]
    @State private var searchText = ""
    @State private var selectedBook: Book?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    
    public init() {}
    
    var filteredNotes: [Note] {
        allNotes.filter { note in
            let matchesSearch = searchText.isEmpty ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                (note.selectedText?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (note.chapterTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesBook = selectedBook == nil || note.book == selectedBook
            
            return matchesSearch && matchesBook
        }
    }
    
    var groupedNotes: [(Book, [Note])] {
        var groups: [Book: [Note]] = [:]
        
        for note in filteredNotes {
            if let book = note.book {
                groups[book, default: []].append(note)
            }
        }
        
        return groups.sorted { $0.key.title < $1.key.title }
            .map { ($0.key, $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }
    
    public var body: some View {
        Group {
            if filteredNotes.isEmpty {
                ContentUnavailableView {
                    Label("No Notes", systemImage: "note.text")
                } description: {
                    Text(searchText.isEmpty ? "Start taking notes while reading" : "No notes match your search")
                }
            } else {
                List {
                    ForEach(groupedNotes, id: \.0.id) { book, notes in
                        Section {
                            ForEach(notes) { note in
                                NotesListRow(note: note, book: book, openWindow: openWindow)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteNote(note)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            BookSectionHeader(book: book, noteCount: notes.count)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .searchable(text: $searchText, prompt: "Search notes...")
        .navigationTitle("Notes")
        .toolbar {
            if !allNotes.isEmpty {
                Menu {
                    Button(action: { selectedBook = nil }) {
                        Label("All Books", systemImage: selectedBook == nil ? "checkmark" : "")
                    }
                    
                    Divider()
                    
                    ForEach(Array(Set(allNotes.compactMap { $0.book })).sorted(by: { $0.title < $1.title }), id: \.id) { book in
                        Button(action: { selectedBook = book }) {
                            Label(book.title, systemImage: selectedBook == book ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
    
    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
    }
}

// MARK: - Book Section Header

struct BookSectionHeader: View {
    let book: Book
    let noteCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.headline)
                
                if let author = book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text("^[\(noteCount) note](inflect: true)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Notes List Row

struct NotesListRow: View {
    let note: Note
    let book: Book
    let openWindow: OpenWindowAction
    
    var body: some View {
        Button {
            // Open book in new window with navigation to note location
            let request = BookWindowRequest(
                bookID: book.id,
                chapterIndex: note.chapterIndex,
                pageIndex: note.pageIndex
            )
            openWindow(value: request)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Selected text quote (if available)
                if let selectedText = note.selectedText, !selectedText.isEmpty {
                    Text(selectedText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(2)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(6)
                }
                
                // User's note
                Text(note.content)
                    .font(.body)
                    .lineLimit(3)
                
                // Metadata
                HStack {
                    Label(note.displayLocation, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    Text(note.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
