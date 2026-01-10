import Foundation
import SwiftData
import SwiftUI

import PDFKit

@MainActor
public class LibraryViewModel: ObservableObject {
    @Published public var searchText = ""
    @Published public var selectedCollection: Collection?
    @Published public var isImporting = false
    
    public init() {}
    
    public func importBooks(urls: [URL], context: ModelContext) {
        Task { @MainActor in
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let fileName = url.lastPathComponent
                guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
                let destURL = docsURL.appendingPathComponent(fileName)
                
                do {
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
                    // context is main context, so safe
                } catch {
                    print("Error importing book: \(error)")
                }
            }
        }
    }
}
