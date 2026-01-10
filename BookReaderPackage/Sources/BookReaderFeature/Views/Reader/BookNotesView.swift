import SwiftUI
import SwiftData

struct BookNotesView: View {
    let book: Book
    @ObservedObject var viewModel: ReaderViewModel
    @State private var searchText = ""
    @Environment(\.modelContext) private var modelContext
    
    var filteredNotes: [Note] {
        book.notes.filter { note in
            searchText.isEmpty ||
            note.content.localizedCaseInsensitiveContains(searchText) ||
            (note.selectedText?.localizedCaseInsensitiveContains(searchText) ?? false)
        }.sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    var body: some View {
        Group {
            if filteredNotes.isEmpty {
                ContentUnavailableView {
                    Label("No Notes", systemImage: "note.text")
                } description: {
                    Text(searchText.isEmpty ? "Start taking notes while reading" : "No notes match your search")
                }
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        BookNoteRow(note: note, viewModel: viewModel)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search notes...")
        .navigationTitle("\(book.title) - Notes")
    }
    
    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        if let index = book.notes.firstIndex(of: note) {
            book.notes.remove(at: index)
        }
    }
}

// MARK: - Book Note Row

struct BookNoteRow: View {
    let note: Note
    @ObservedObject var viewModel: ReaderViewModel
    
    var body: some View {
        Button(action: {
            // Navigate to location
            if let chapterIndex = note.chapterIndex {
                viewModel.currentChapterIndex = chapterIndex
            }
            viewModel.currentSubPage = note.pageIndex
            
            // Close the notes list sheet
            viewModel.showNotesListSheet = false
        }) {
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
