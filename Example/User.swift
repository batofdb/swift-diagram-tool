import Foundation

public protocol Identifiable {
    var id: UUID { get }
}

public protocol Timestampable {
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

public class User: Identifiable, Timestampable {
    public let id: UUID
    public var name: String
    public var email: String
    private var passwordHash: String
    public let createdAt: Date
    public var updatedAt: Date
    
    public var profile: UserProfile?
    public var posts: [Post] = []
    
    public init(name: String, email: String, password: String) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.passwordHash = password // In real app, this would be hashed
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    public func updatePassword(_ newPassword: String) {
        self.passwordHash = newPassword
        self.updatedAt = Date()
    }
    
    public func addPost(_ post: Post) {
        posts.append(post)
        post.author = self
    }
}