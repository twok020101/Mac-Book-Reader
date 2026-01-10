import Foundation
import PDFKit
import SwiftUI

public class PDFService {
    @MainActor public static let shared = PDFService()
    
    public init() {}
    
    public func document(from url: URL) -> PDFDocument? {
        return PDFDocument(url: url)
    }
    
    public func generateThumbnail(for url: URL, size: CGSize = CGSize(width: 300, height: 400)) -> Data? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }
        
        // Ensure thumbnail generation happens on main thread if needed or appropriate context
        // PDFKit usually handles this, but creating images might depend on AppKit/UIKit
        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        
        #if canImport(AppKit)
        return thumbnail.tiffRepresentation
        #else
        return thumbnail.pngData()
        #endif
    }
}
