import UIKit
import Foundation

// Complex inheritance hierarchy for testing focus filtering

// Base classes
class BaseEntity: NSObject {
    var id: String = ""
    var createdAt: Date = Date()
}

class DataEntity: BaseEntity {
    var isValid: Bool = true
    var metadata: [String: Any] = [:]
}

// User hierarchy
class User: DataEntity {
    var username: String = ""
    var email: String = ""
    var profile: UserProfile?
}

class PremiumUser: User {
    var subscriptionLevel: String = ""
    var premiumFeatures: [String] = []
}

class AdminUser: PremiumUser {
    var adminRights: [String] = []
    var lastAdminAction: Date?
}

// Profile hierarchy
class UserProfile: DataEntity {
    var displayName: String = ""
    var avatar: UIImage?
    var settings: ProfileSettings?
}

class ProfileSettings: BaseEntity {
    var theme: String = "default"
    var notifications: Bool = true
    var privacy: PrivacySettings?
}

class PrivacySettings: BaseEntity {
    var isPublic: Bool = false
    var allowMessages: Bool = true
}

// View Controller hierarchy for UIKit testing
class UserViewController: UIViewController {
    var currentUser: User?
    var profileView: UserProfileView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Setup code
    }
}

class UserProfileView: UIView {
    var nameLabel: UILabel?
    var avatarImageView: UIImageView?
    var settingsButton: UIButton?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }
    
    private func setupSubviews() {
        // Setup subviews
    }
}

// Protocol hierarchy for protocol-focused testing
protocol Cacheable {
    associatedtype CacheKey: Hashable
    var cacheKey: CacheKey { get }
    func invalidateCache()
}

protocol NetworkResource: Cacheable {
    associatedtype ResponseType: Codable
    func fetch() async throws -> ResponseType
}

class UserCache: NSObject, Cacheable {
    typealias CacheKey = String
    
    var cacheKey: String { return "user_cache" }
    private var cache: [String: User] = [:]
    
    func invalidateCache() {
        cache.removeAll()
    }
    
    func store(user: User, key: String) {
        cache[key] = user
    }
}

class UserNetworkService: NSObject, NetworkResource {
    typealias CacheKey = String
    typealias ResponseType = User
    
    var cacheKey: String { return "user_network" }
    
    func fetch() async throws -> User {
        // Network implementation
        return User()
    }
    
    func invalidateCache() {
        // Cache invalidation
    }
}

// Additional composition relationships
class UserManager: NSObject {
    private let networkService: UserNetworkService
    private let cache: UserCache
    private let database: UserDatabase
    
    init(networkService: UserNetworkService, cache: UserCache, database: UserDatabase) {
        self.networkService = networkService
        self.cache = cache
        self.database = database
        super.init()
    }
    
    func getUser(id: String) async -> User? {
        // Implementation
        return nil
    }
}

class UserDatabase: NSObject {
    private var users: [String: User] = [:]
    
    func save(_ user: User) {
        users[user.id] = user
    }
    
    func find(id: String) -> User? {
        return users[id]
    }
}