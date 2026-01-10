import Foundation
import SwiftData

@Model
public final class Note {
    @Attribute(.unique) public var id: UUID
    public var book: Book?
    public var content: String
    public var pageReference: String?   // Page number or chapter
    public var selectedText: String?    // Text that was highlighted
    public var pageIndex: Int = 0       // Store raw page index
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(id: UUID = UUID(), content: String, pageReference: String? = nil, selectedText: String? = nil, pageIndex: Int = 0, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.content = content
        self.pageReference = pageReference
        self.selectedText = selectedText
        self.pageIndex = pageIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
