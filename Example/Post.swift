import Foundation

public class Post: Identifiable, Timestampable {
    public let id: UUID
    public var title: String
    public var content: String
    public var tags: [Tag] = []
    public weak var author: User?
    public var comments: [Comment] = []
    public let createdAt: Date
    public var updatedAt: Date
    public private(set) var status: PostStatus
    
    public init(title: String, content: String, author: User? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.author = author
        self.createdAt = Date()
        self.updatedAt = Date()
        self.status = .draft
    }
    
    public func publish() {
        self.status = .published
        self.updatedAt = Date()
    }
    
    public func addComment(_ comment: Comment) {
        comments.append(comment)
        comment.post = self
    }
    
    public func addTag(_ tag: Tag) {
        tags.append(tag)
    }
}

public enum PostStatus: String {
    case draft
    case published
    case archived
}