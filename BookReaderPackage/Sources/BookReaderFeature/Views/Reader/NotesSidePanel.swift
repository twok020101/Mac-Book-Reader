import SwiftUI
import SwiftData

public struct NotesSidePanel: View {
    @Bindable var book: Book
    @ObservedObject var viewModel: ReaderViewModel
    @State private var newNoteContent: String = ""
    @Environment(\.modelContext) private var modelContext
    
    public init(book: Book, viewModel: ReaderViewModel) {
        self.book = book
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text("Notes")
                .font(.headline)
                .padding()
            
            List {
                ForEach(book.notes.sorted(by: { $0.createdAt < $1.createdAt }), id: \.id) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.content)
                            .font(.body)
                        
                        Button("Jump to Page \(note.pageIndex + 1)") {
                            viewModel.currentSubPage = note.pageIndex
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteNotes)
            }
            
            Divider()
            
            VStack(spacing: 8) {
                TextEditor(text: $newNoteContent)
                    .frame(height: 80)
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                
                Button("Add Note") {
                    addNote()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .frame(width: 300)
        .background(.regularMaterial)
    }
    
    private func addNote() {
        let trimmed = newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Use current page index and create a reference string
        let pIndex = viewModel.currentSubPage
        let note = Note(content: trimmed, pageReference: "Page \(pIndex + 1)", pageIndex: pIndex)
        note.book = book
        book.notes.append(note)
        modelContext.insert(note)
        
        newNoteContent = ""
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        let notes = book.notes
        let sortedNotes = notes.sorted(by: { $0.createdAt < $1.createdAt })
        
        for index in offsets {
            let noteToDelete = sortedNotes[index]
            modelContext.delete(noteToDelete)
            if let indexInBook = book.notes.firstIndex(of: noteToDelete) {
                book.notes.remove(at: indexInBook)
            }
        }
    }
}
