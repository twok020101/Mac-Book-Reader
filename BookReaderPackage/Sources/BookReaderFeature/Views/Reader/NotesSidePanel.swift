import SwiftUI
import SwiftData
import EPUBKit

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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Notes")
                .font(.headline)
                .padding()
            
            Divider()
            
            // Notes List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(book.notes.sorted(by: { $0.createdAt > $1.createdAt }), id: \.id) { note in
                        NoteCard(note: note, viewModel: viewModel)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Add Note Section
            VStack(spacing: 12) {
                // Show selected text if available
                if !viewModel.selectedText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Text:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(viewModel.selectedText)
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                            .italic()
                    }
                }
                
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
        
        // Get current chapter info
        let currentChapter: EPUBTableOfContents? = {
            if let toc = viewModel.epubDocument?.tableOfContents.subTable,
               toc.indices.contains(viewModel.currentChapterIndex) {
                return toc[viewModel.currentChapterIndex]
            }
            return nil
        }()
        
        let note = Note(
            content: trimmed,
            pageReference: "Page \(viewModel.currentSubPage + 1)",
            selectedText: viewModel.selectedText.isEmpty ? nil : viewModel.selectedText,
            pageIndex: viewModel.currentSubPage,
            chapterTitle: currentChapter?.label ?? viewModel.currentChapterTitle,
            chapterIndex: viewModel.currentChapterIndex
        )
        
        note.book = book
        book.notes.append(note)
        modelContext.insert(note)
        
        newNoteContent = ""
        viewModel.clearSelection()
    }
    
    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        if let index = book.notes.firstIndex(of: note) {
            book.notes.remove(at: index)
        }
    }
}

// MARK: - Note Card Component

struct NoteCard: View {
    let note: Note
    @ObservedObject var viewModel: ReaderViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected text quote (if available)
            if let selectedText = note.selectedText, !selectedText.isEmpty {
                Text(selectedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
            }
            
            // User's note
            Text(note.content)
                .font(.body)
            
            // Location and timestamp
            HStack {
                Button(action: {
                    jumpToNote(note)
                }) {
                    Label(note.displayLocation, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(note.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func jumpToNote(_ note: Note) {
        // Jump to the chapter and page where note was created
        if let chapterIndex = note.chapterIndex {
            viewModel.currentChapterIndex = chapterIndex
        }
        viewModel.currentSubPage = note.pageIndex
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
