import Foundation
import SwiftData

@Model
public final class Collection {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var icon: String?            // SF Symbol name
    @Relationship public var books: [Book]
    public var createdAt: Date
    
    public init(id: UUID = UUID(), name: String, icon: String? = "folder", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.books = []
        self.createdAt = createdAt
    }
}
