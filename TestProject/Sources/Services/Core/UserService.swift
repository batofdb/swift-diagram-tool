import Foundation
import Combine

// MARK: - User Service Protocol

@MainActor
public protocol UserServiceProtocol {
    func getCurrentUser() async throws -> User?
    func getUser(id: UUID) async throws -> User?
    func updateUser(_ user: User) async throws -> User
    func deleteUser(id: UUID) async throws
    func searchUsers(query: String) async throws -> [User]
    func followUser(id: UUID) async throws
    func unfollowUser(id: UUID) async throws
    func getFollowers(for userId: UUID) async throws -> [User]
    func getFollowing(for userId: UUID) async throws -> [User]
}

// MARK: - User Service Implementation

@MainActor
public class UserService: UserServiceProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = UserService()
    
    // MARK: - Published Properties
    
    @Published public var currentUser: User?
    @Published public var isAuthenticated: Bool = false
    @Published public var authenticationState: AuthenticationState = .unauthenticated
    @Published public var lastSyncTime: Date?
    
    // MARK: - Private Properties
    
    private let networkManager: NetworkManagerProtocol
    private let cacheManager: CacheManagerProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let notificationCenter: NotificationCenter
    
    private var cancellables = Set<AnyCancellable>()
    private let userCache = NSCache<NSString, UserCacheItem>()
    private let syncQueue = DispatchQueue(label: "com.userservice.sync", qos: .background)
    
    // MARK: - Nested Types
    
    public enum AuthenticationState: Equatable {
        case authenticated(User)
        case unauthenticated
        case loading
        case error(AuthError)
        
        public var isAuthenticated: Bool {
            switch self {
            case .authenticated: return true
            default: return false
            }
        }
    }
    
    public enum AuthError: LocalizedError {
        case invalidCredentials
        case networkError(Error)
        case tokenExpired
        case userNotFound
        case serverError(Int)
        
        public var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return "Invalid username or password"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .tokenExpired:
                return "Your session has expired. Please sign in again."
            case .userNotFound:
                return "User not found"
            case .serverError(let code):
                return "Server error with code: \(code)"
            }
        }
    }
    
    private class UserCacheItem {
        let user: User
        let timestamp: Date
        
        init(user: User) {
            self.user = user
            self.timestamp = Date()
        }
        
        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }
    }
    
    // MARK: - Initialization
    
    public init(networkManager: NetworkManagerProtocol = NetworkManager.shared,
                cacheManager: CacheManagerProtocol = CacheManager.shared,
                analyticsService: AnalyticsServiceProtocol = AnalyticsService.shared,
                notificationCenter: NotificationCenter = .default) {
        self.networkManager = networkManager
        self.cacheManager = cacheManager
        self.analyticsService = analyticsService
        self.notificationCenter = notificationCenter
        
        setupBindings()
        loadCurrentUser()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor authentication state changes
        $authenticationState
            .map { state in
                switch state {
                case .authenticated(let user):
                    return user
                default:
                    return nil
                }
            }
            .assign(to: &$currentUser)
        
        $currentUser
            .map { $0 != nil }
            .assign(to: &$isAuthenticated)
        
        // Setup cache configuration
        userCache.countLimit = 100
        userCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        
        // Listen for memory warnings
        notificationCenter.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.userCache.removeAllObjects()
            }
            .store(in: &cancellables)
    }
    
    private func loadCurrentUser() {
        Task {
            do {
                if let cachedUser = try await loadUserFromCache() {
                    authenticationState = .authenticated(cachedUser)
                } else {
                    authenticationState = .unauthenticated
                }
            } catch {
                authenticationState = .error(.networkError(error))
            }
        }
    }
    
    // MARK: - UserServiceProtocol Implementation
    
    public func getCurrentUser() async throws -> User? {
        switch authenticationState {
        case .authenticated(let user):
            return user
        case .loading:
            // Wait for loading to complete
            return try await withCheckedThrowingContinuation { continuation in
                let cancellable = $authenticationState
                    .filter { state in
                        switch state {
                        case .loading: return false
                        default: return true
                        }
                    }
                    .first()
                    .sink { state in
                        switch state {
                        case .authenticated(let user):
                            continuation.resume(returning: user)
                        case .error(let error):
                            continuation.resume(throwing: error)
                        default:
                            continuation.resume(returning: nil)
                        }
                    }
                
                // Store cancellable to prevent deallocation
                cancellables.insert(cancellable)
            }
        default:
            return nil
        }
    }
    
    public func getUser(id: UUID) async throws -> User? {
        // Check cache first
        if let cacheItem = userCache.object(forKey: id.uuidString as NSString),
           !cacheItem.isExpired {
            return cacheItem.user
        }
        
        // Fetch from network
        do {
            let request = APIRequest.getUser(id: id)
            let user: User = try await networkManager.perform(request)
            
            // Cache the user
            userCache.setObject(UserCacheItem(user: user), forKey: id.uuidString as NSString)
            
            // Store in persistent cache
            await cacheManager.store(user, forKey: "user_\(id.uuidString)")
            
            analyticsService.track(event: "user_fetched", parameters: [
                "user_id": id.uuidString,
                "source": "network"
            ])
            
            return user
        } catch {
            analyticsService.track(event: "user_fetch_failed", parameters: [
                "user_id": id.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func updateUser(_ user: User) async throws -> User {
        do {
            let request = APIRequest.updateUser(user)
            let updatedUser: User = try await networkManager.perform(request)
            
            // Update cache
            userCache.setObject(UserCacheItem(user: updatedUser), forKey: user.id.uuidString as NSString)
            
            // Update persistent cache
            await cacheManager.store(updatedUser, forKey: "user_\(user.id.uuidString)")
            
            // Update current user if it's the same user
            if currentUser?.id == user.id {
                currentUser = updatedUser
                authenticationState = .authenticated(updatedUser)
            }
            
            analyticsService.track(event: "user_updated", parameters: [
                "user_id": user.id.uuidString
            ])
            
            return updatedUser
        } catch {
            analyticsService.track(event: "user_update_failed", parameters: [
                "user_id": user.id.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func deleteUser(id: UUID) async throws {
        do {
            let request = APIRequest.deleteUser(id: id)
            try await networkManager.perform(request)
            
            // Remove from cache
            userCache.removeObject(forKey: id.uuidString as NSString)
            await cacheManager.removeObject(forKey: "user_\(id.uuidString)")
            
            // If deleting current user, log out
            if currentUser?.id == id {
                await logout()
            }
            
            analyticsService.track(event: "user_deleted", parameters: [
                "user_id": id.uuidString
            ])
        } catch {
            analyticsService.track(event: "user_deletion_failed", parameters: [
                "user_id": id.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func searchUsers(query: String) async throws -> [User] {
        guard query.count >= 2 else { return [] }
        
        do {
            let request = APIRequest.searchUsers(query: query)
            let searchResult: SearchResult<User> = try await networkManager.perform(request)
            
            // Cache search results
            for user in searchResult.items {
                userCache.setObject(UserCacheItem(user: user), forKey: user.id.uuidString as NSString)
            }
            
            analyticsService.track(event: "users_searched", parameters: [
                "query": query,
                "results_count": searchResult.items.count
            ])
            
            return searchResult.items
        } catch {
            analyticsService.track(event: "user_search_failed", parameters: [
                "query": query,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func followUser(id: UUID) async throws {
        do {
            let request = APIRequest.followUser(id: id)
            try await networkManager.perform(request)
            
            // Update current user's following list
            if var user = currentUser {
                user.follow(id)
                currentUser = user
                authenticationState = .authenticated(user)
            }
            
            analyticsService.track(event: "user_followed", parameters: [
                "followed_user_id": id.uuidString
            ])
        } catch {
            analyticsService.track(event: "user_follow_failed", parameters: [
                "followed_user_id": id.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func unfollowUser(id: UUID) async throws {
        do {
            let request = APIRequest.unfollowUser(id: id)
            try await networkManager.perform(request)
            
            // Update current user's following list
            if var user = currentUser {
                user.unfollow(id)
                currentUser = user
                authenticationState = .authenticated(user)
            }
            
            analyticsService.track(event: "user_unfollowed", parameters: [
                "unfollowed_user_id": id.uuidString
            ])
        } catch {
            analyticsService.track(event: "user_unfollow_failed", parameters: [
                "unfollowed_user_id": id.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func getFollowers(for userId: UUID) async throws -> [User] {
        do {
            let request = APIRequest.getUserFollowers(userId: userId)
            let response: PaginatedResponse<User> = try await networkManager.perform(request)
            
            // Cache followers
            for user in response.items {
                userCache.setObject(UserCacheItem(user: user), forKey: user.id.uuidString as NSString)
            }
            
            analyticsService.track(event: "followers_fetched", parameters: [
                "user_id": userId.uuidString,
                "count": response.items.count
            ])
            
            return response.items
        } catch {
            analyticsService.track(event: "followers_fetch_failed", parameters: [
                "user_id": userId.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func getFollowing(for userId: UUID) async throws -> [User] {
        do {
            let request = APIRequest.getUserFollowing(userId: userId)
            let response: PaginatedResponse<User> = try await networkManager.perform(request)
            
            // Cache following users
            for user in response.items {
                userCache.setObject(UserCacheItem(user: user), forKey: user.id.uuidString as NSString)
            }
            
            analyticsService.track(event: "following_fetched", parameters: [
                "user_id": userId.uuidString,
                "count": response.items.count
            ])
            
            return response.items
        } catch {
            analyticsService.track(event: "following_fetch_failed", parameters: [
                "user_id": userId.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    // MARK: - Authentication Methods
    
    public func login(email: String, password: String) async throws -> User {
        authenticationState = .loading
        
        do {
            let request = APIRequest.login(email: email, password: password)
            let loginResponse: LoginResponse = try await networkManager.perform(request)
            
            // Store authentication token
            await storeAuthToken(loginResponse.token)
            
            // Cache user
            await cacheManager.store(loginResponse.user, forKey: "current_user")
            
            authenticationState = .authenticated(loginResponse.user)
            
            analyticsService.track(event: "user_logged_in", parameters: [
                "user_id": loginResponse.user.id.uuidString
            ])
            
            return loginResponse.user
        } catch {
            let authError: AuthError
            if let networkError = error as? NetworkError {
                switch networkError {
                case .unauthorized:
                    authError = .invalidCredentials
                case .serverError(let code):
                    authError = .serverError(code)
                default:
                    authError = .networkError(error)
                }
            } else {
                authError = .networkError(error)
            }
            
            authenticationState = .error(authError)
            
            analyticsService.track(event: "login_failed", parameters: [
                "error": error.localizedDescription
            ])
            
            throw authError
        }
    }
    
    public func logout() async {
        do {
            if let _ = currentUser {
                let request = APIRequest.logout
                try await networkManager.perform(request)
            }
        } catch {
            // Log error but continue with logout
            analyticsService.track(event: "logout_api_failed", parameters: [
                "error": error.localizedDescription
            ])
        }
        
        // Clear local state regardless of API call result
        await clearAuthToken()
        await cacheManager.removeObject(forKey: "current_user")
        userCache.removeAllObjects()
        
        currentUser = nil
        authenticationState = .unauthenticated
        
        analyticsService.track(event: "user_logged_out")
    }
    
    // MARK: - Private Helper Methods
    
    private func loadUserFromCache() async throws -> User? {
        return await cacheManager.object(forKey: "current_user", type: User.self)
    }
    
    private func storeAuthToken(_ token: String) async {
        await cacheManager.store(token, forKey: "auth_token")
    }
    
    private func clearAuthToken() async {
        await cacheManager.removeObject(forKey: "auth_token")
    }
}

// MARK: - Supporting Types

public struct LoginResponse: Codable {
    public let user: User
    public let token: String
    public let expiresAt: Date
}

public struct SearchResult<T: Codable>: Codable {
    public let items: [T]
    public let totalCount: Int
    public let hasMore: Bool
}

public struct PaginatedResponse<T: Codable>: Codable {
    public let items: [T]
    public let totalCount: Int
    public let currentPage: Int
    public let totalPages: Int
    public let hasMore: Bool
}

// MARK: - Dependency Injection

public protocol UserServiceContainer {
    var userService: UserServiceProtocol { get }
}

public extension UserServiceContainer {
    var userService: UserServiceProtocol {
        return UserService.shared
    }
}

// MARK: - User Store (SwiftUI)

@MainActor
public class UserStore: ObservableObject {
    public static let shared = UserStore()
    
    @Published public var currentUser: User?
    @Published public var isAuthenticated: Bool = false
    @Published public var authenticationState: UserService.AuthenticationState = .unauthenticated
    
    private let userService: UserServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public init(userService: UserServiceProtocol = UserService.shared) {
        self.userService = userService
        
        if let service = userService as? UserService {
            // Bind to UserService published properties
            service.$currentUser
                .assign(to: \.currentUser, on: self)
                .store(in: &cancellables)
            
            service.$isAuthenticated
                .assign(to: \.isAuthenticated, on: self)
                .store(in: &cancellables)
            
            service.$authenticationState
                .assign(to: \.authenticationState, on: self)
                .store(in: &cancellables)
        }
    }
    
    public func refreshCurrentUser() async {
        do {
            currentUser = try await userService.getCurrentUser()
        } catch {
            print("Failed to refresh current user: \(error)")
        }
    }
}

// MARK: - Mock User Service (for testing)

#if DEBUG
public class MockUserService: UserServiceProtocol {
    public var mockCurrentUser: User?
    public var shouldThrowError: Bool = false
    public var mockUsers: [UUID: User] = [:]
    
    public func getCurrentUser() async throws -> User? {
        if shouldThrowError {
            throw UserService.AuthError.networkError(NSError(domain: "MockError", code: 1))
        }
        return mockCurrentUser
    }
    
    public func getUser(id: UUID) async throws -> User? {
        if shouldThrowError {
            throw UserService.AuthError.userNotFound
        }
        return mockUsers[id]
    }
    
    public func updateUser(_ user: User) async throws -> User {
        if shouldThrowError {
            throw UserService.AuthError.networkError(NSError(domain: "MockError", code: 1))
        }
        mockUsers[user.id] = user
        if mockCurrentUser?.id == user.id {
            mockCurrentUser = user
        }
        return user
    }
    
    public func deleteUser(id: UUID) async throws {
        if shouldThrowError {
            throw UserService.AuthError.networkError(NSError(domain: "MockError", code: 1))
        }
        mockUsers.removeValue(forKey: id)
        if mockCurrentUser?.id == id {
            mockCurrentUser = nil
        }
    }
    
    public func searchUsers(query: String) async throws -> [User] {
        if shouldThrowError {
            throw UserService.AuthError.networkError(NSError(domain: "MockError", code: 1))
        }
        return Array(mockUsers.values.filter { $0.name.contains(query) })
    }
    
    public func followUser(id: UUID) async throws {
        if shouldThrowError {
            throw UserService.AuthError.networkError(NSError(domain: "MockError", code: 1))
        }
        mockCurrentUser?.follow(id)
    }
    
    public func unfollowUser(id: UUID) async throws {
        if shouldThrowError {
            throw UserService.AuthError.networkError(NSError(domain: "MockError", code: 1))
        }
        mockCurrentUser?.unfollow(id)
    }
    
    public func getFollowers(for userId: UUID) async throws -> [User] {
        if shouldThrowError {
            throw UserService.AuthError.networkError(NSError(domain: "MockError", code: 1))
        }
        // Mock implementation
        return []
    }
    
    public func getFollowing(for userId: UUID) async throws -> [User] {
        if shouldThrowError {
            throw UserService.AuthError.networkError(NSError(domain: "MockError", code: 1))
        }
        // Mock implementation
        return []
    }
}
#endif