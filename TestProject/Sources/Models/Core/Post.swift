import Foundation
import UIKit

// MARK: - Post Model

public struct Post: Codable, Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var content: String
    public var excerpt: String?
    public var authorId: UUID
    public var categoryId: UUID?
    public var tags: Set<Tag>
    public var attachments: [Attachment]
    public var metadata: Metadata
    public private(set) var status: Status
    public private(set) var statistics: Statistics
    public private(set) var createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var publishedAt: Date?
    
    // MARK: - Nested Types
    
    public enum Status: String, Codable, CaseIterable, Comparable {
        case draft = "draft"
        case reviewing = "reviewing"
        case published = "published"
        case archived = "archived"
        case deleted = "deleted"
        
        public static func < (lhs: Status, rhs: Status) -> Bool {
            let order: [Status] = [.draft, .reviewing, .published, .archived, .deleted]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
        
        public var canEdit: Bool {
            switch self {
            case .draft, .reviewing: return true
            case .published, .archived, .deleted: return false
            }
        }
        
        public var displayName: String {
            switch self {
            case .draft: return "Draft"
            case .reviewing: return "Under Review"
            case .published: return "Published"
            case .archived: return "Archived"
            case .deleted: return "Deleted"
            }
        }
    }
    
    public struct Statistics: Codable, Equatable, Hashable {
        public private(set) var viewCount: Int
        public private(set) var likeCount: Int
        public private(set) var commentCount: Int
        public private(set) var shareCount: Int
        public private(set) var readingTime: TimeInterval
        public private(set) var lastViewedAt: Date?
        
        public init(viewCount: Int = 0, likeCount: Int = 0, commentCount: Int = 0, 
                   shareCount: Int = 0, readingTime: TimeInterval = 0) {
            self.viewCount = viewCount
            self.likeCount = likeCount
            self.commentCount = commentCount
            self.shareCount = shareCount
            self.readingTime = readingTime
            self.lastViewedAt = nil
        }
        
        public mutating func incrementViews() {
            viewCount += 1
            lastViewedAt = Date()
        }
        
        public mutating func incrementLikes() {
            likeCount += 1
        }
        
        public mutating func incrementComments() {
            commentCount += 1
        }
        
        public mutating func incrementShares() {
            shareCount += 1
        }
        
        public var engagementRate: Double {
            guard viewCount > 0 else { return 0 }
            let totalEngagements = likeCount + commentCount + shareCount
            return Double(totalEngagements) / Double(viewCount)
        }
    }
    
    public struct Metadata: Codable, Equatable, Hashable {
        public var seoTitle: String?
        public var seoDescription: String?
        public var seoKeywords: [String]
        public var featuredImage: URL?
        public var allowComments: Bool
        public var allowLikes: Bool
        public var allowSharing: Bool
        public var isSponsored: Bool
        public var contentWarnings: [ContentWarning]
        public var customFields: [String: String]
        
        public enum ContentWarning: String, Codable, CaseIterable {
            case mature = "mature"
            case violence = "violence"
            case sensitive = "sensitive"
            case spoiler = "spoiler"
            
            public var displayName: String {
                switch self {
                case .mature: return "Mature Content"
                case .violence: return "Violence"
                case .sensitive: return "Sensitive Content"
                case .spoiler: return "Spoiler Alert"
                }
            }
        }
        
        public init(allowComments: Bool = true, allowLikes: Bool = true, allowSharing: Bool = true) {
            self.seoTitle = nil
            self.seoDescription = nil
            self.seoKeywords = []
            self.featuredImage = nil
            self.allowComments = allowComments
            self.allowLikes = allowLikes
            self.allowSharing = allowSharing
            self.isSponsored = false
            self.contentWarnings = []
            self.customFields = [:]
        }
    }
    
    public struct Attachment: Codable, Identifiable, Hashable {
        public let id: UUID
        public let fileName: String
        public let mimeType: String
        public let fileSize: Int64
        public let url: URL
        public let thumbnailURL: URL?
        public let uploadedAt: Date
        public let metadata: AttachmentMetadata?
        
        public enum AttachmentType: String, Codable {
            case image = "image"
            case video = "video"
            case audio = "audio"
            case document = "document"
            case archive = "archive"
            case other = "other"
            
            public static func from(mimeType: String) -> AttachmentType {
                if mimeType.hasPrefix("image/") { return .image }
                if mimeType.hasPrefix("video/") { return .video }
                if mimeType.hasPrefix("audio/") { return .audio }
                if mimeType.contains("pdf") || mimeType.contains("document") { return .document }
                if mimeType.contains("zip") || mimeType.contains("archive") { return .archive }
                return .other
            }
        }
        
        public struct AttachmentMetadata: Codable, Hashable {
            public let width: Int?
            public let height: Int?
            public let duration: TimeInterval?
            public let bitrate: Int?
            public let colorProfile: String?
            public let altText: String?
            public let caption: String?
        }
        
        public var type: AttachmentType {
            return AttachmentType.from(mimeType: mimeType)
        }
        
        public var formattedFileSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: fileSize)
        }
        
        public init(fileName: String, mimeType: String, fileSize: Int64, url: URL, 
                   thumbnailURL: URL? = nil, metadata: AttachmentMetadata? = nil) {
            self.id = UUID()
            self.fileName = fileName
            self.mimeType = mimeType
            self.fileSize = fileSize
            self.url = url
            self.thumbnailURL = thumbnailURL
            self.uploadedAt = Date()
            self.metadata = metadata
        }
    }
    
    // MARK: - Computed Properties
    
    public var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    public var estimatedReadingTime: TimeInterval {
        let averageWordsPerMinute: Double = 200
        return TimeInterval(Double(wordCount) / averageWordsPerMinute * 60)
    }
    
    public var isPublished: Bool {
        return status == .published && publishedAt != nil
    }
    
    public var hasAttachments: Bool {
        return !attachments.isEmpty
    }
    
    public var imageAttachments: [Attachment] {
        return attachments.filter { $0.type == .image }
    }
    
    public var videoAttachments: [Attachment] {
        return attachments.filter { $0.type == .video }
    }
    
    // MARK: - Initializers
    
    public init(title: String, content: String, authorId: UUID, categoryId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.excerpt = nil
        self.authorId = authorId
        self.categoryId = categoryId
        self.tags = []
        self.attachments = []
        self.metadata = Metadata()
        self.status = .draft
        self.statistics = Statistics()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.publishedAt = nil
    }
    
    // MARK: - Methods
    
    public mutating func publish() throws {
        guard status == .draft || status == .reviewing else {
            throw PostError.invalidStatusTransition
        }
        
        guard !title.isEmpty && !content.isEmpty else {
            throw PostError.incompleteContent
        }
        
        status = .published
        publishedAt = Date()
        updatedAt = Date()
        
        if excerpt == nil {
            generateExcerpt()
        }
        
        statistics.readingTime = estimatedReadingTime
    }
    
    public mutating func archive() {
        guard status == .published else { return }
        status = .archived
        updatedAt = Date()
    }
    
    public mutating func addTag(_ tag: Tag) {
        tags.insert(tag)
        updatedAt = Date()
    }
    
    public mutating func removeTag(_ tag: Tag) {
        tags.remove(tag)
        updatedAt = Date()
    }
    
    public mutating func addAttachment(_ attachment: Attachment) {
        attachments.append(attachment)
        updatedAt = Date()
    }
    
    public mutating func removeAttachment(withId id: UUID) {
        attachments.removeAll { $0.id == id }
        updatedAt = Date()
    }
    
    private mutating func generateExcerpt() {
        let maxLength = 160
        let plainContent = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        if plainContent.count <= maxLength {
            excerpt = plainContent
        } else {
            let trimmed = String(plainContent.prefix(maxLength))
            if let lastSpace = trimmed.lastIndex(of: " ") {
                excerpt = String(trimmed[..<lastSpace]) + "..."
            } else {
                excerpt = trimmed + "..."
            }
        }
    }
    
    public mutating func updateStatistics(with newStats: Statistics) {
        statistics = newStats
        updatedAt = Date()
    }
}

// MARK: - Post Extensions

extension Post: CustomStringConvertible {
    public var description: String {
        return "Post(id: \(id), title: \"\(title)\", status: \(status), author: \(authorId))"
    }
}

extension Post {
    public enum PostError: LocalizedError {
        case invalidStatusTransition
        case incompleteContent
        case attachmentTooLarge
        case unsupportedMimeType
        
        public var errorDescription: String? {
            switch self {
            case .invalidStatusTransition:
                return "Cannot perform this status transition"
            case .incompleteContent:
                return "Post must have title and content to be published"
            case .attachmentTooLarge:
                return "Attachment file size exceeds the maximum allowed"
            case .unsupportedMimeType:
                return "This file type is not supported"
            }
        }
    }
}

// MARK: - Tag Model

public struct Tag: Codable, Identifiable, Hashable, CustomStringConvertible {
    public let id: UUID
    public let name: String
    public let slug: String
    public let color: String?
    public let description: String?
    public private(set) var usageCount: Int
    public private(set) var createdAt: Date
    
    public var description: String {
        return "Tag(name: \"\(name)\", slug: \"\(slug)\", usage: \(usageCount))"
    }
    
    public init(name: String, color: String? = nil, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        self.color = color
        self.description = description
        self.usageCount = 0
        self.createdAt = Date()
    }
    
    public mutating func incrementUsage() {
        usageCount += 1
    }
    
    public mutating func decrementUsage() {
        usageCount = max(0, usageCount - 1)
    }
}

// MARK: - Category Model

public struct Category: Codable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let slug: String
    public let description: String?
    public let parentId: UUID?
    public let color: String?
    public let icon: String?
    public private(set) var postCount: Int
    public private(set) var createdAt: Date
    
    // MARK: - Nested Types
    
    public struct CategoryHierarchy {
        public let category: Category
        public let children: [CategoryHierarchy]
        public let level: Int
        
        public init(category: Category, children: [CategoryHierarchy] = [], level: Int = 0) {
            self.category = category
            self.children = children
            self.level = level
        }
        
        public var allDescendants: [Category] {
            var result: [Category] = []
            for child in children {
                result.append(child.category)
                result.append(contentsOf: child.allDescendants)
            }
            return result
        }
    }
    
    // MARK: - Computed Properties
    
    public var isRootCategory: Bool {
        return parentId == nil
    }
    
    public var hasChildren: Bool {
        // This would typically be determined by checking if any categories have this ID as parentId
        // For now, we'll assume it's false since we don't have access to the full category tree
        return false
    }
    
    // MARK: - Initializer
    
    public init(name: String, description: String? = nil, parentId: UUID? = nil, 
               color: String? = nil, icon: String? = nil) {
        self.id = UUID()
        self.name = name
        self.slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        self.description = description
        self.parentId = parentId
        self.color = color
        self.icon = icon
        self.postCount = 0
        self.createdAt = Date()
    }
    
    // MARK: - Methods
    
    public mutating func incrementPostCount() {
        postCount += 1
    }
    
    public mutating func decrementPostCount() {
        postCount = max(0, postCount - 1)
    }
}

extension Category: CustomStringConvertible {
    public var description: String {
        return "Category(name: \"\(name)\", slug: \"\(slug)\", posts: \(postCount))"
    }
}