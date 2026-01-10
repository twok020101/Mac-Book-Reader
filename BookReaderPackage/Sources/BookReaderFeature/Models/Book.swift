import Foundation
import SwiftData

@Model
public final class Book {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var author: String?
    public var coverImageData: Data?
    public var filePath: String        // Relative path in app sandbox
    public var fileType: BookFileType  // .epub or .pdf
    public var dateAdded: Date
    public var lastOpened: Date?
    
    @Relationship(deleteRule: .cascade) public var progress: ReadingProgress?
    @Relationship(deleteRule: .cascade) public var notes: [Note]
    @Relationship public var collection: Collection?
    public var tags: [String] = []
    
    public init(id: UUID = UUID(), title: String, author: String? = nil, coverImageData: Data? = nil, filePath: String, fileType: BookFileType, dateAdded: Date = Date(), tags: [String] = []) {
        self.id = id
        self.title = title
        self.author = author
        self.coverImageData = coverImageData
        self.filePath = filePath
        self.fileType = fileType
        self.dateAdded = dateAdded
        self.tags = tags
        self.notes = []
    }
}

public enum BookFileType: String, Codable {
    case epub, pdf
}
