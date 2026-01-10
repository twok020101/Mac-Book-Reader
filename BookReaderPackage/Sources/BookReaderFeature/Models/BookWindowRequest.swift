import Foundation

/// Represents a request to open a book with optional navigation
public struct BookWindowRequest: Codable, Hashable {
    public let bookID: UUID
    public let chapterIndex: Int?
    public let pageIndex: Int
    
    public init(bookID: UUID, chapterIndex: Int? = nil, pageIndex: Int = 0) {
        self.bookID = bookID
        self.chapterIndex = chapterIndex
        self.pageIndex = pageIndex
    }
}
