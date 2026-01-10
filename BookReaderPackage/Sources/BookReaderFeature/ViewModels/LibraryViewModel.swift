import Foundation
import SwiftData
import SwiftUI

import PDFKit
import UniformTypeIdentifiers // Added for UTType

@MainActor
public class LibraryViewModel: ObservableObject {
    @Published public var searchText = ""
    @Published public var selectedCollection: Collection?
    @Published public var isImporting = false
    @Published public var duplicateAlert = false
    @Published public var duplicateBookTitles: [String] = []
    
    public init() {}
    
    public func importBooks(urls: [URL], context: ModelContext) {
        Task { @MainActor in
            var duplicates: [String] = []
            var imported = 0
            
            // Fetch existing books to check for duplicates
            let descriptor = FetchDescriptor<Book>()
            let existingBooks = (try? context.fetch(descriptor)) ?? []
            let existingPaths = Set(existingBooks.map { $0.filePath })
            
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access: \(url)")
                    continue
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let fileName = url.lastPathComponent
                
                // Check for duplicate by file path
                if existingPaths.contains(fileName) { // filePath is just the fileName
                    // Extract title from existing book
                    if let existingBook = existingBooks.first(where: { $0.filePath == fileName }) {
                        duplicates.append(existingBook.title)
                    }
                    continue
                }
                
                do {
                    guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { continue }
                    let destURL = docsURL.appendingPathComponent(fileName)
                    
                    // Copy file if not already there
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try? FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: url, to: destURL)
                    
                    let fileType: BookFileType = url.pathExtension.lowercased() == "pdf" ? .pdf : .epub
                    let relativePath = fileName
                    
                    var title = fileName
                    var author: String? = nil
                    var coverData: Data? = nil
                    
                    if fileType == .epub {
                        if let doc = EPUBParserService.shared.parse(url: destURL) {
                            title = doc.title ?? fileName
                            author = doc.author
                            coverData = EPUBParserService.shared.cover(from: doc)
                        }
                    } else {
                        if let pdf = PDFService.shared.document(from: destURL) {
                            if let attrs = pdf.documentAttributes {
                                title = (attrs[PDFDocumentAttribute.titleAttribute] as? String) ?? fileName
                                author = attrs[PDFDocumentAttribute.authorAttribute] as? String
                            }
                            coverData = PDFService.shared.generateThumbnail(for: destURL)
                        }
                    }
                    
                    let newBook = Book(title: title, author: author, coverImageData: coverData, filePath: relativePath, fileType: fileType)
                    
                    context.insert(newBook)
                    imported += 1
                } catch {
                    print("Error importing book: \(error)")
                }
            }
            
            // Show alert if duplicates were found
            if !duplicates.isEmpty {
                duplicateBookTitles = duplicates
                duplicateAlert = true
            }
            
            print("Imported \(imported) books, skipped \(duplicates.count) duplicates")
        }
    }
}
