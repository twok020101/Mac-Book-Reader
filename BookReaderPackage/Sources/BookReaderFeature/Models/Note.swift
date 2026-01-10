import Foundation
import SwiftData

@Model
public final class Note {
    @Attribute(.unique) public var id: UUID
    public var book: Book?
    public var content: String
    
    // Location context
    public var pageReference: String?   // "Page 45" or "Chapter 3 - Page 12"
    public var pageIndex: Int = 0       // Raw page index within chapter
    public var chapterTitle: String?    // "Chapter 3: The Journey"
    public var chapterIndex: Int?       // For navigation back to chapter
    
    // Text reference
    public var selectedText: String?    // The highlighted text that triggered the note
    
    // Organization
    public var tags: [String] = []      // User-defined tags for categorization
    
    // Metadata
    public var createdAt: Date
    public var updatedAt: Date
    
    // Computed property for display
    public var displayLocation: String {
        if let chapter = chapterTitle, let page = pageReference {
            return "\(chapter) • \(page)"
        }
        return pageReference ?? "Unknown location"
    }
    
    public init(
        id: UUID = UUID(),
        content: String,
        pageReference: String? = nil,
        selectedText: String? = nil,
        pageIndex: Int = 0,
        chapterTitle: String? = nil,
        chapterIndex: Int? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.pageReference = pageReference
        self.selectedText = selectedText
        self.pageIndex = pageIndex
        self.chapterTitle = chapterTitle
        self.chapterIndex = chapterIndex
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
