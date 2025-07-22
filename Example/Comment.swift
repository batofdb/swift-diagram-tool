import Foundation

public struct Comment: Identifiable, Timestampable {
    public let id: UUID
    public var content: String
    public var author: User
    public weak var post: Post?
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(content: String, author: User, post: Post? = nil) {
        self.id = UUID()
        self.content = content
        self.author = author
        self.post = post
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}