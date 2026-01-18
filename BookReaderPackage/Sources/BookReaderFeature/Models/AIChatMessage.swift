import Foundation
import SwiftData

@Model
public final class AIChatMessage {
    @Attribute(.unique) public var id: UUID
    public var book: Book?
    public var role: MessageRole
    public var content: String
    public var createdAt: Date
    
    public enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
    
    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
