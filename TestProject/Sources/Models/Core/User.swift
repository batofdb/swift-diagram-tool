import Foundation
import Combine

// MARK: - Core User Types

@dynamicMemberLookup
public struct User: Codable, Identifiable, Hashable, CustomStringConvertible {
    public let id: UUID
    public var name: String
    public var email: String
    public var profile: UserProfile?
    public var posts: [Post] = []
    public var followers: Set<UUID> = []
    public var following: Set<UUID> = []
    public private(set) var createdAt: Date
    public private(set) var updatedAt: Date
    
    // MARK: - Nested Types
    
    public enum Status: String, Codable, CaseIterable {
        case active = "active"
        case inactive = "inactive"
        case suspended = "suspended"
        case deleted = "deleted"
        
        var displayName: String {
            switch self {
            case .active: return "Active"
            case .inactive: return "Inactive"
            case .suspended: return "Suspended"
            case .deleted: return "Deleted"
            }
        }
    }
    
    public struct Statistics: Codable, Equatable {
        public let totalPosts: Int
        public let totalLikes: Int
        public let totalComments: Int
        public let joinedDate: Date
        
        public init(totalPosts: Int, totalLikes: Int, totalComments: Int, joinedDate: Date) {
            self.totalPosts = totalPosts
            self.totalLikes = totalLikes
            self.totalComments = totalComments
            self.joinedDate = joinedDate
        }
    }
    
    // MARK: - Properties
    
    public var status: Status = .active
    public var statistics: Statistics?
    public var preferences: UserPreferences = UserPreferences()
    
    // MARK: - Computed Properties
    
    public var description: String {
        return "User(id: \(id), name: \(name), email: \(email), status: \(status))"
    }
    
    public var isVerified: Bool {
        return profile?.isVerified ?? false
    }
    
    public var fullDisplayName: String {
        if let profile = profile, !profile.displayName.isEmpty {
            return profile.displayName
        }
        return name
    }
    
    // MARK: - Initializers
    
    public init(name: String, email: String, profile: UserProfile? = nil) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.profile = profile
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    public init(id: UUID, name: String, email: String, profile: UserProfile?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.email = email
        self.profile = profile
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Methods
    
    public mutating func updateProfile(_ newProfile: UserProfile) {
        self.profile = newProfile
        self.updatedAt = Date()
    }
    
    public mutating func addPost(_ post: Post) {
        posts.append(post)
        updatedAt = Date()
    }
    
    public mutating func follow(_ userId: UUID) {
        following.insert(userId)
        updatedAt = Date()
    }
    
    public mutating func unfollow(_ userId: UUID) {
        following.remove(userId)
        updatedAt = Date()
    }
    
    public func isFollowing(_ userId: UUID) -> Bool {
        return following.contains(userId)
    }
    
    // MARK: - Dynamic Member Lookup
    
    public subscript<T>(dynamicMember keyPath: KeyPath<UserProfile, T>) -> T? {
        return profile?[keyPath: keyPath]
    }
}

// MARK: - User Extensions

extension User: Comparable {
    public static func < (lhs: User, rhs: User) -> Bool {
        return lhs.name < rhs.name
    }
}

extension User: ObservableObject {}

// MARK: - User Profile

public struct UserProfile: Codable, Equatable, Hashable {
    public let id: UUID
    public var displayName: String
    public var bio: String
    public var avatarURL: URL?
    public var location: String?
    public var website: URL?
    public var birthDate: Date?
    public var isVerified: Bool
    public var isPrivate: Bool
    public var socialLinks: [SocialLink]
    public private(set) var createdAt: Date
    public private(set) var updatedAt: Date
    
    // MARK: - Nested Types
    
    public struct SocialLink: Codable, Equatable, Hashable, Identifiable {
        public let id: UUID
        public let platform: SocialPlatform
        public let url: URL
        public let username: String
        
        public init(platform: SocialPlatform, url: URL, username: String) {
            self.id = UUID()
            self.platform = platform
            self.url = url
            self.username = username
        }
    }
    
    public enum SocialPlatform: String, Codable, CaseIterable {
        case twitter = "twitter"
        case instagram = "instagram"
        case linkedin = "linkedin"
        case github = "github"
        case website = "website"
        
        public var displayName: String {
            switch self {
            case .twitter: return "Twitter"
            case .instagram: return "Instagram"
            case .linkedin: return "LinkedIn"
            case .github: return "GitHub"
            case .website: return "Website"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    public var age: Int? {
        guard let birthDate = birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }
    
    public var hasCompletedProfile: Bool {
        return !displayName.isEmpty && !bio.isEmpty && avatarURL != nil
    }
    
    // MARK: - Initializers
    
    public init(displayName: String = "", bio: String = "", avatarURL: URL? = nil, location: String? = nil) {
        self.id = UUID()
        self.displayName = displayName
        self.bio = bio
        self.avatarURL = avatarURL
        self.location = location
        self.website = nil
        self.birthDate = nil
        self.isVerified = false
        self.isPrivate = false
        self.socialLinks = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Methods
    
    public mutating func updateBio(_ newBio: String) {
        self.bio = newBio
        self.updatedAt = Date()
    }
    
    public mutating func addSocialLink(_ link: SocialLink) {
        socialLinks.append(link)
        updatedAt = Date()
    }
    
    public mutating func removeSocialLink(withId id: UUID) {
        socialLinks.removeAll { $0.id == id }
        updatedAt = Date()
    }
    
    public func getSocialLink(for platform: SocialPlatform) -> SocialLink? {
        return socialLinks.first { $0.platform == platform }
    }
}

// MARK: - User Preferences

@propertyWrapper
public struct Clamped<Value: Comparable> {
    private var value: Value
    private let range: ClosedRange<Value>
    
    public var wrappedValue: Value {
        get { value }
        set { value = min(max(range.lowerBound, newValue), range.upperBound) }
    }
    
    public init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.value = min(max(range.lowerBound, wrappedValue), range.upperBound)
    }
}

public struct UserPreferences: Codable, Equatable {
    public var theme: Theme
    public var language: Language
    public var notificationSettings: NotificationSettings
    @Clamped(0...100) public var volume: Int
    public var privacySettings: PrivacySettings
    
    // MARK: - Nested Types
    
    public enum Theme: String, Codable, CaseIterable {
        case light = "light"
        case dark = "dark"
        case auto = "auto"
    }
    
    public enum Language: String, Codable, CaseIterable {
        case english = "en"
        case spanish = "es"
        case french = "fr"
        case german = "de"
        case japanese = "ja"
        case chinese = "zh"
    }
    
    public struct NotificationSettings: Codable, Equatable {
        public var pushNotifications: Bool
        public var emailNotifications: Bool
        public var smsNotifications: Bool
        public var marketingEmails: Bool
        
        public init(pushNotifications: Bool = true, emailNotifications: Bool = true, 
                   smsNotifications: Bool = false, marketingEmails: Bool = false) {
            self.pushNotifications = pushNotifications
            self.emailNotifications = emailNotifications
            self.smsNotifications = smsNotifications
            self.marketingEmails = marketingEmails
        }
    }
    
    public struct PrivacySettings: Codable, Equatable {
        public var profileVisibility: ProfileVisibility
        public var showEmail: Bool
        public var showLocation: Bool
        public var allowDirectMessages: Bool
        public var allowTagging: Bool
        
        public enum ProfileVisibility: String, Codable, CaseIterable {
            case `public` = "public"
            case friends = "friends"
            case `private` = "private"
        }
        
        public init(profileVisibility: ProfileVisibility = .public, showEmail: Bool = false,
                   showLocation: Bool = false, allowDirectMessages: Bool = true, allowTagging: Bool = true) {
            self.profileVisibility = profileVisibility
            self.showEmail = showEmail
            self.showLocation = showLocation
            self.allowDirectMessages = allowDirectMessages
            self.allowTagging = allowTagging
        }
    }
    
    // MARK: - Initializer
    
    public init(theme: Theme = .auto, language: Language = .english, volume: Int = 50) {
        self.theme = theme
        self.language = language
        self.notificationSettings = NotificationSettings()
        self.volume = volume
        self.privacySettings = PrivacySettings()
    }
}