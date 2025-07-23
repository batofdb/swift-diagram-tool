import Foundation
import Combine

// MARK: - Comment Model

public struct Comment: Codable, Identifiable, Hashable {
    public let id: UUID
    public var content: String
    public let postId: UUID
    public let authorId: UUID
    public let parentId: UUID? // For nested comments/replies
    public var reactions: [Reaction]
    public var mentions: Set<UUID> // User IDs mentioned in the comment
    public private(set) var status: Status
    public private(set) var metadata: Metadata
    public private(set) var createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var editHistory: [EditRecord]
    
    // MARK: - Nested Types
    
    public enum Status: String, Codable, CaseIterable {
        case visible = "visible"
        case hidden = "hidden"
        case flagged = "flagged"
        case deleted = "deleted"
        case spam = "spam"
        
        public var displayName: String {
            switch self {
            case .visible: return "Visible"
            case .hidden: return "Hidden"
            case .flagged: return "Flagged"
            case .deleted: return "Deleted"
            case .spam: return "Spam"
            }
        }
        
        public var isVisible: Bool {
            return self == .visible
        }
    }
    
    public struct Reaction: Codable, Identifiable, Hashable {
        public let id: UUID
        public let userId: UUID
        public let type: ReactionType
        public let createdAt: Date
        
        public enum ReactionType: String, Codable, CaseIterable {
            case like = "like"
            case love = "love"
            case laugh = "laugh"
            case sad = "sad"
            case angry = "angry"
            case wow = "wow"
            
            public var emoji: String {
                switch self {
                case .like: return "👍"
                case .love: return "❤️"
                case .laugh: return "😂"
                case .sad: return "😢"
                case .angry: return "😠"
                case .wow: return "😮"
                }
            }
            
            public var displayName: String {
                switch self {
                case .like: return "Like"
                case .love: return "Love"
                case .laugh: return "Laugh"
                case .sad: return "Sad"
                case .angry: return "Angry"
                case .wow: return "Wow"
                }
            }
        }
        
        public init(userId: UUID, type: ReactionType) {
            self.id = UUID()
            self.userId = userId
            self.type = type
            self.createdAt = Date()
        }
    }
    
    public struct Metadata: Codable, Equatable, Hashable {
        public let ipAddress: String?
        public let userAgent: String?
        public let source: Source
        public var isEdited: Bool
        public var isPinned: Bool
        public var isFeatured: Bool
        public var moderatorNotes: String?
        
        public enum Source: String, Codable, CaseIterable {
            case web = "web"
            case mobile = "mobile"
            case api = "api"
            case import = "import"
            
            public var displayName: String {
                switch self {
                case .web: return "Web"
                case .mobile: return "Mobile"
                case .api: return "API"
                case .import: return "Import"
                }
            }
        }
        
        public init(source: Source = .web, ipAddress: String? = nil, userAgent: String? = nil) {
            self.ipAddress = ipAddress
            self.userAgent = userAgent
            self.source = source
            self.isEdited = false
            self.isPinned = false
            self.isFeatured = false
            self.moderatorNotes = nil
        }
    }
    
    public struct EditRecord: Codable, Equatable, Hashable, Identifiable {
        public let id: UUID
        public let previousContent: String
        public let newContent: String
        public let reason: String?
        public let editedAt: Date
        public let editorId: UUID
        
        public init(previousContent: String, newContent: String, reason: String? = nil, editorId: UUID) {
            self.id = UUID()
            self.previousContent = previousContent
            self.newContent = newContent
            self.reason = reason
            self.editedAt = Date()
            self.editorId = editorId
        }
    }
    
    // MARK: - Computed Properties
    
    public var isReply: Bool {
        return parentId != nil
    }
    
    public var wordCount: Int {
        return content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
    
    public var reactionCounts: [Reaction.ReactionType: Int] {
        var counts: [Reaction.ReactionType: Int] = [:]
        for reaction in reactions {
            counts[reaction.type, default: 0] += 1
        }
        return counts
    }
    
    public var totalReactions: Int {
        return reactions.count
    }
    
    public var hasBeenEdited: Bool {
        return !editHistory.isEmpty
    }
    
    public var lastEditedAt: Date? {
        return editHistory.last?.editedAt
    }
    
    // MARK: - Initializers
    
    public init(content: String, postId: UUID, authorId: UUID, parentId: UUID? = nil) {
        self.id = UUID()
        self.content = content
        self.postId = postId
        self.authorId = authorId
        self.parentId = parentId
        self.reactions = []
        self.mentions = []
        self.status = .visible
        self.metadata = Metadata()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.editHistory = []
    }
    
    // MARK: - Methods
    
    public mutating func addReaction(_ reaction: Reaction) {
        // Remove existing reaction from the same user if it exists
        reactions.removeAll { $0.userId == reaction.userId }
        reactions.append(reaction)
        updatedAt = Date()
    }
    
    public mutating func removeReaction(userId: UUID) {
        reactions.removeAll { $0.userId == userId }
        updatedAt = Date()
    }
    
    public mutating func edit(newContent: String, editorId: UUID, reason: String? = nil) {
        guard newContent != content else { return }
        
        let editRecord = EditRecord(
            previousContent: content,
            newContent: newContent,
            reason: reason,
            editorId: editorId
        )
        
        editHistory.append(editRecord)
        content = newContent
        metadata.isEdited = true
        updatedAt = Date()
    }
    
    public mutating func hide() {
        status = .hidden
        updatedAt = Date()
    }
    
    public mutating func show() {
        status = .visible
        updatedAt = Date()
    }
    
    public mutating func flag() {
        status = .flagged
        updatedAt = Date()
    }
    
    public mutating func markAsSpam() {
        status = .spam
        updatedAt = Date()
    }
    
    public mutating func delete() {
        status = .deleted
        content = "[Deleted]"
        updatedAt = Date()
    }
    
    public mutating func pin() {
        metadata.isPinned = true
        updatedAt = Date()
    }
    
    public mutating func unpin() {
        metadata.isPinned = false
        updatedAt = Date()
    }
    
    public mutating func addMention(_ userId: UUID) {
        mentions.insert(userId)
        updatedAt = Date()
    }
    
    public mutating func removeMention(_ userId: UUID) {
        mentions.remove(userId)
        updatedAt = Date()
    }
    
    public func getReaction(from userId: UUID) -> Reaction? {
        return reactions.first { $0.userId == userId }
    }
    
    public func hasReaction(from userId: UUID, type: Reaction.ReactionType? = nil) -> Bool {
        if let type = type {
            return reactions.contains { $0.userId == userId && $0.type == type }
        } else {
            return reactions.contains { $0.userId == userId }
        }
    }
}

// MARK: - Comment Extensions

extension Comment: CustomStringConvertible {
    public var description: String {
        let truncatedContent = content.count > 50 
            ? String(content.prefix(50)) + "..." 
            : content
        return "Comment(id: \(id), content: \"\(truncatedContent)\", author: \(authorId))"
    }
}

extension Comment: Comparable {
    public static func < (lhs: Comment, rhs: Comment) -> Bool {
        // Pin status takes precedence
        if lhs.metadata.isPinned != rhs.metadata.isPinned {
            return lhs.metadata.isPinned && !rhs.metadata.isPinned
        }
        
        // Then sort by creation date (newest first)
        return lhs.createdAt > rhs.createdAt
    }
}

// MARK: - Comment Thread Helper

public struct CommentThread {
    public let parentComment: Comment
    public let replies: [Comment]
    public let totalReplies: Int
    public let maxDepth: Int
    
    public init(parentComment: Comment, replies: [Comment] = [], maxDepth: Int = 3) {
        self.parentComment = parentComment
        self.replies = replies.sorted()
        self.totalReplies = replies.count
        self.maxDepth = maxDepth
    }
    
    public var flattenedComments: [Comment] {
        var result = [parentComment]
        result.append(contentsOf: replies)
        return result
    }
    
    public var visibleReplies: [Comment] {
        return replies.filter { $0.status.isVisible }
    }
    
    public var hasMoreReplies: Bool {
        return totalReplies > replies.count
    }
}

// MARK: - Comment Repository Protocol

public protocol CommentRepository {
    func fetchComments(for postId: UUID) async throws -> [Comment]
    func fetchReplies(for commentId: UUID) async throws -> [Comment]
    func createComment(_ comment: Comment) async throws -> Comment
    func updateComment(_ comment: Comment) async throws -> Comment
    func deleteComment(_ commentId: UUID) async throws
    func addReaction(_ reaction: Comment.Reaction, to commentId: UUID) async throws
    func removeReaction(userId: UUID, from commentId: UUID) async throws
}

// MARK: - Comment Events

public enum CommentEvent {
    case created(Comment)
    case updated(Comment)
    case deleted(UUID)
    case reactionAdded(Comment.Reaction, to: UUID)
    case reactionRemoved(userId: UUID, from: UUID)
    case statusChanged(UUID, Comment.Status)
}

// MARK: - Comment Validation

public struct CommentValidator {
    public static func validate(_ comment: Comment) throws {
        guard !comment.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyContent
        }
        
        guard comment.content.count <= 5000 else {
            throw ValidationError.contentTooLong
        }
        
        guard comment.wordCount <= 500 else {
            throw ValidationError.tooManyWords
        }
    }
    
    public enum ValidationError: LocalizedError {
        case emptyContent
        case contentTooLong
        case tooManyWords
        
        public var errorDescription: String? {
            switch self {
            case .emptyContent:
                return "Comment content cannot be empty"
            case .contentTooLong:
                return "Comment content exceeds maximum length of 5000 characters"
            case .tooManyWords:
                return "Comment exceeds maximum word count of 500 words"
            }
        }
    }
}