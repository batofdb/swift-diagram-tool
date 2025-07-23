import Foundation
import Combine
import CoreData

// MARK: - Post Service Protocol

public protocol PostServiceProtocol: AnyObject {
    associatedtype PostType: Identifiable & Codable
    associatedtype CommentType: Identifiable & Codable
    
    func fetchPost<T: PostIdentifiable>(_ identifier: T) async throws -> PostType?
    func createPost<T: PostCreatable>(_ post: T) async throws -> PostType
    func updatePost<T: PostUpdatable>(_ post: T) async throws -> PostType
    func deletePost<T: PostIdentifiable>(_ identifier: T) async throws
    func searchPosts<T: SearchQuery>(query: T) async throws -> [PostType]
    func likePost<T: PostIdentifiable>(_ identifier: T) async throws
    func unlikePost<T: PostIdentifiable>(_ identifier: T) async throws
    func addComment<T: CommentCreatable>(_ comment: T, to postId: UUID) async throws -> CommentType
}

// MARK: - Generic Protocols

public protocol PostIdentifiable {
    var postId: UUID { get }
}

public protocol PostCreatable {
    var title: String { get }
    var content: String { get }
    var authorId: UUID { get }
}

public protocol PostUpdatable: PostIdentifiable {
    var updatedTitle: String? { get }
    var updatedContent: String? { get }
}

public protocol CommentCreatable {
    var content: String { get }
    var authorId: UUID { get }
    var parentId: UUID? { get }
}

public protocol SearchQuery {
    var query: String { get }
    var filters: [SearchFilter] { get }
    var sortBy: SortOption { get }
    var limit: Int { get }
}

// MARK: - Post Service Actor

@globalActor
public actor PostServiceActor {
    public static let shared = PostServiceActor()
    private init() {}
}

// MARK: - Post Service Implementation

@PostServiceActor
public final class PostService: PostServiceProtocol, ObservableObject {
    public typealias PostType = Post
    public typealias CommentType = Comment
    
    // MARK: - Singleton
    
    public static let shared = PostService()
    
    // MARK: - Published Properties
    
    @Published public private(set) var homeFeedPosts: [Post] = []
    @Published public private(set) var trendingPosts: [Post] = []
    @Published public private(set) var bookmarkedPosts: [Post] = []
    @Published public private(set) var draftPosts: [Post] = []
    @Published public private(set) var isLoadingMore: Bool = false
    @Published public private(set) var lastError: PostError?
    
    // MARK: - Dependencies
    
    private let networkManager: NetworkManagerProtocol
    private let cacheManager: CacheManagerProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let userService: UserServiceProtocol
    private let imageProcessor: ImageProcessorProtocol
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let postCache: PostCache<Post>
    private let commentCache: CommentCache<Comment>
    private let feedManager: FeedManager
    private let syncManager: SyncManager<Post>
    
    private var currentPage = 0
    private let pageSize = 20
    private var hasMorePosts = true
    
    // MARK: - Initialization
    
    private init(networkManager: NetworkManagerProtocol = NetworkManager.shared,
                 cacheManager: CacheManagerProtocol = CacheManager.shared,
                 analyticsService: AnalyticsServiceProtocol = AnalyticsService.shared,
                 userService: UserServiceProtocol = UserService.shared,
                 imageProcessor: ImageProcessorProtocol = ImageProcessor.shared) {
        self.networkManager = networkManager
        self.cacheManager = cacheManager
        self.analyticsService = analyticsService
        self.userService = userService
        self.imageProcessor = imageProcessor
        
        self.postCache = PostCache<Post>(maxSize: 500)
        self.commentCache = CommentCache<Comment>(maxSize: 1000)
        self.feedManager = FeedManager(networkManager: networkManager)
        self.syncManager = SyncManager<Post>(networkManager: networkManager, cacheManager: cacheManager)
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor network connectivity
        NotificationCenter.default.publisher(for: .networkConnectivityChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.handleNetworkConnectivityChange()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - PostServiceProtocol Implementation
    
    public func fetchPost<T: PostIdentifiable>(_ identifier: T) async throws -> Post? {
        let postId = identifier.postId
        
        // Check cache first
        if let cachedPost = await postCache.get(id: postId) {
            analyticsService.track(event: "post_fetched_from_cache", parameters: [
                "post_id": postId.uuidString
            ])
            return cachedPost
        }
        
        // Fetch from network
        do {
            let request = APIRequest.getPost(id: postId)
            let post: Post = try await networkManager.perform(request)
            
            // Cache the post
            await postCache.set(post, for: postId)
            await cacheManager.store(post, forKey: "post_\(postId.uuidString)")
            
            analyticsService.track(event: "post_fetched_from_network", parameters: [
                "post_id": postId.uuidString
            ])
            
            return post
        } catch {
            lastError = .networkError(error)
            analyticsService.track(event: "post_fetch_failed", parameters: [
                "post_id": postId.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func createPost<T: PostCreatable>(_ post: T) async throws -> Post {
        do {
            // Process any images first
            var processedAttachments: [Post.Attachment] = []
            
            // Create post object
            let newPost = Post(title: post.title, content: post.content, authorId: post.authorId)
            
            let request = APIRequest.createPost(newPost)
            let createdPost: Post = try await networkManager.perform(request)
            
            // Cache the created post
            await postCache.set(createdPost, for: createdPost.id)
            await cacheManager.store(createdPost, forKey: "post_\(createdPost.id.uuidString)")
            
            // Update local feed
            await MainActor.run {
                homeFeedPosts.insert(createdPost, at: 0)
                if createdPost.status == .draft {
                    draftPosts.insert(createdPost, at: 0)
                }
            }
            
            analyticsService.track(event: "post_created", parameters: [
                "post_id": createdPost.id.uuidString,
                "title_length": post.title.count,
                "content_length": post.content.count
            ])
            
            return createdPost
        } catch {
            lastError = .creationFailed(error)
            analyticsService.track(event: "post_creation_failed", parameters: [
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func updatePost<T: PostUpdatable>(_ post: T) async throws -> Post {
        let postId = post.postId
        
        do {
            guard let existingPost = await postCache.get(id: postId) else {
                throw PostError.postNotFound
            }
            
            var updatedPost = existingPost
            
            if let newTitle = post.updatedTitle {
                updatedPost.title = newTitle
            }
            
            if let newContent = post.updatedContent {
                updatedPost.content = newContent
            }
            
            let request = APIRequest.updatePost(updatedPost)
            let serverPost: Post = try await networkManager.perform(request)
            
            // Update cache
            await postCache.set(serverPost, for: postId)
            await cacheManager.store(serverPost, forKey: "post_\(postId.uuidString)")
            
            // Update local arrays
            await MainActor.run {
                updatePostInArrays(serverPost)
            }
            
            analyticsService.track(event: "post_updated", parameters: [
                "post_id": postId.uuidString
            ])
            
            return serverPost
        } catch {
            lastError = .updateFailed(error)
            analyticsService.track(event: "post_update_failed", parameters: [
                "post_id": postId.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func deletePost<T: PostIdentifiable>(_ identifier: T) async throws {
        let postId = identifier.postId
        
        do {
            let request = APIRequest.deletePost(id: postId)
            try await networkManager.perform(request)
            
            // Remove from cache
            await postCache.remove(id: postId)
            await cacheManager.removeObject(forKey: "post_\(postId.uuidString)")
            
            // Remove from local arrays
            await MainActor.run {
                removePostFromArrays(postId)
            }
            
            analyticsService.track(event: "post_deleted", parameters: [
                "post_id": postId.uuidString
            ])
        } catch {
            lastError = .deletionFailed(error)
            analyticsService.track(event: "post_deletion_failed", parameters: [
                "post_id": postId.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func searchPosts<T: SearchQuery>(query: T) async throws -> [Post] {
        do {
            let searchRequest = PostSearchRequest(
                query: query.query,
                filters: query.filters,
                sortBy: query.sortBy,
                limit: query.limit
            )
            
            let request = APIRequest.searchPosts(searchRequest)
            let searchResult: SearchResult<Post> = try await networkManager.perform(request)
            
            // Cache search results
            for post in searchResult.items {
                await postCache.set(post, for: post.id)
            }
            
            analyticsService.track(event: "posts_searched", parameters: [
                "query": query.query,
                "results_count": searchResult.items.count,
                "filters_count": query.filters.count
            ])
            
            return searchResult.items
        } catch {
            lastError = .searchFailed(error)
            analyticsService.track(event: "post_search_failed", parameters: [
                "query": query.query,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func likePost<T: PostIdentifiable>(_ identifier: T) async throws {
        let postId = identifier.postId
        
        do {
            let request = APIRequest.likePost(id: postId)
            try await networkManager.perform(request)
            
            // Update cached post
            if var post = await postCache.get(id: postId) {
                post.statistics.incrementLikes()
                await postCache.set(post, for: postId)
                
                await MainActor.run {
                    updatePostInArrays(post)
                }
            }
            
            analyticsService.track(event: "post_liked", parameters: [
                "post_id": postId.uuidString
            ])
        } catch {
            lastError = .actionFailed(error)
            analyticsService.track(event: "post_like_failed", parameters: [
                "post_id": postId.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func unlikePost<T: PostIdentifiable>(_ identifier: T) async throws {
        let postId = identifier.postId
        
        do {
            let request = APIRequest.unlikePost(id: postId)
            try await networkManager.perform(request)
            
            // Update cached post
            if var post = await postCache.get(id: postId) {
                post.statistics.likeCount = max(0, post.statistics.likeCount - 1)
                await postCache.set(post, for: postId)
                
                await MainActor.run {
                    updatePostInArrays(post)
                }
            }
            
            analyticsService.track(event: "post_unliked", parameters: [
                "post_id": postId.uuidString
            ])
        } catch {
            lastError = .actionFailed(error)
            analyticsService.track(event: "post_unlike_failed", parameters: [
                "post_id": postId.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    public func addComment<T: CommentCreatable>(_ comment: T, to postId: UUID) async throws -> Comment {
        do {
            let newComment = Comment(
                content: comment.content,
                postId: postId,
                authorId: comment.authorId,
                parentId: comment.parentId
            )
            
            let request = APIRequest.createComment(newComment)
            let createdComment: Comment = try await networkManager.perform(request)
            
            // Cache the comment
            await commentCache.set(createdComment, for: createdComment.id)
            
            // Update post comment count
            if var post = await postCache.get(id: postId) {
                post.statistics.incrementComments()
                await postCache.set(post, for: postId)
                
                await MainActor.run {
                    updatePostInArrays(post)
                }
            }
            
            analyticsService.track(event: "comment_created", parameters: [
                "comment_id": createdComment.id.uuidString,
                "post_id": postId.uuidString,
                "is_reply": comment.parentId != nil
            ])
            
            return createdComment
        } catch {
            lastError = .commentFailed(error)
            analyticsService.track(event: "comment_creation_failed", parameters: [
                "post_id": postId.uuidString,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    // MARK: - Additional Methods
    
    public func loadHomeFeed() async {
        await MainActor.run { isLoadingMore = true }
        defer { Task { await MainActor.run { isLoadingMore = false } } }
        
        do {
            let feedRequest = FeedRequest(
                page: 0,
                limit: pageSize,
                feedType: .home
            )
            
            let posts = try await feedManager.loadFeed(feedRequest)
            
            await MainActor.run {
                homeFeedPosts = posts
                currentPage = 0
                hasMorePosts = posts.count >= pageSize
            }
            
            // Cache posts
            for post in posts {
                await postCache.set(post, for: post.id)
            }
            
        } catch {
            lastError = .feedLoadFailed(error)
        }
    }
    
    public func loadMorePosts() async {
        guard hasMorePosts && !isLoadingMore else { return }
        
        await MainActor.run { isLoadingMore = true }
        defer { Task { await MainActor.run { isLoadingMore = false } } }
        
        do {
            let feedRequest = FeedRequest(
                page: currentPage + 1,
                limit: pageSize,
                feedType: .home
            )
            
            let newPosts = try await feedManager.loadFeed(feedRequest)
            
            await MainActor.run {
                homeFeedPosts.append(contentsOf: newPosts)
                currentPage += 1
                hasMorePosts = newPosts.count >= pageSize
            }
            
            // Cache new posts
            for post in newPosts {
                await postCache.set(post, for: post.id)
            }
            
        } catch {
            lastError = .feedLoadFailed(error)
        }
    }
    
    public func refreshPosts() async {
        currentPage = 0
        hasMorePosts = true
        await loadHomeFeed()
    }
    
    public func search(query: String) async -> [Post] {
        do {
            let searchQuery = BasicSearchQuery(
                query: query,
                filters: [],
                sortBy: .relevance,
                limit: 50
            )
            return try await searchPosts(query: searchQuery)
        } catch {
            return []
        }
    }
    
    public func isPostLiked(_ postId: UUID) async -> Bool {
        // This would typically check against user's liked posts
        return false
    }
    
    public func isPostBookmarked(_ postId: UUID) async -> Bool {
        return bookmarkedPosts.contains { $0.id == postId }
    }
    
    public func addBookmark(_ postId: UUID) async {
        guard let post = await postCache.get(id: postId) else { return }
        
        await MainActor.run {
            if !bookmarkedPosts.contains(where: { $0.id == postId }) {
                bookmarkedPosts.append(post)
            }
        }
    }
    
    public func removeBookmark(_ postId: UUID) async {
        await MainActor.run {
            bookmarkedPosts.removeAll { $0.id == postId }
        }
    }
    
    public func trackPostView(_ postId: UUID) async {
        analyticsService.track(event: "post_view_tracked", parameters: [
            "post_id": postId.uuidString
        ])
        
        // Update view count in cache
        if var post = await postCache.get(id: postId) {
            post.statistics.incrementViews()
            await postCache.set(post, for: postId)
        }
    }
    
    public func reportPost(_ postId: UUID, reason: String) async {
        analyticsService.track(event: "post_reported", parameters: [
            "post_id": postId.uuidString,
            "reason": reason
        ])
    }
    
    public func hidePost(_ postId: UUID) async {
        await MainActor.run {
            removePostFromArrays(postId)
        }
        
        analyticsService.track(event: "post_hidden", parameters: [
            "post_id": postId.uuidString
        ])
    }
    
    // MARK: - Private Helper Methods
    
    @MainActor
    private func updatePostInArrays(_ post: Post) {
        // Update in home feed
        if let index = homeFeedPosts.firstIndex(where: { $0.id == post.id }) {
            homeFeedPosts[index] = post
        }
        
        // Update in trending posts
        if let index = trendingPosts.firstIndex(where: { $0.id == post.id }) {
            trendingPosts[index] = post
        }
        
        // Update in bookmarked posts
        if let index = bookmarkedPosts.firstIndex(where: { $0.id == post.id }) {
            bookmarkedPosts[index] = post
        }
        
        // Update in draft posts
        if let index = draftPosts.firstIndex(where: { $0.id == post.id }) {
            draftPosts[index] = post
        }
    }
    
    @MainActor
    private func removePostFromArrays(_ postId: UUID) {
        homeFeedPosts.removeAll { $0.id == postId }
        trendingPosts.removeAll { $0.id == postId }
        bookmarkedPosts.removeAll { $0.id == postId }
        draftPosts.removeAll { $0.id == postId }
    }
    
    private func handleNetworkConnectivityChange() async {
        // Sync any pending changes when network becomes available
        await syncManager.syncPendingChanges()
    }
}

// MARK: - Supporting Types

public enum PostError: LocalizedError {
    case networkError(Error)
    case postNotFound
    case creationFailed(Error)
    case updateFailed(Error)
    case deletionFailed(Error)
    case searchFailed(Error)
    case actionFailed(Error)
    case commentFailed(Error)
    case feedLoadFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .postNotFound:
            return "Post not found"
        case .creationFailed(let error):
            return "Failed to create post: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update post: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Failed to delete post: \(error.localizedDescription)"
        case .searchFailed(let error):
            return "Search failed: \(error.localizedDescription)"
        case .actionFailed(let error):
            return "Action failed: \(error.localizedDescription)"
        case .commentFailed(let error):
            return "Comment action failed: \(error.localizedDescription)"
        case .feedLoadFailed(let error):
            return "Failed to load feed: \(error.localizedDescription)"
        }
    }
}

public enum SearchFilter: Codable, Equatable {
    case author(UUID)
    case category(UUID)
    case tag(String)
    case dateRange(start: Date, end: Date)
    case status(Post.Status)
    case hasAttachments(Bool)
    case minLikes(Int)
    case minComments(Int)
}

public enum SortOption: String, Codable, CaseIterable {
    case newest = "newest"
    case oldest = "oldest"
    case mostLiked = "most_liked"
    case mostCommented = "most_commented"
    case trending = "trending"
    case relevance = "relevance"
}

// MARK: - Implementation Types

public struct BasicPostIdentifier: PostIdentifiable {
    public let postId: UUID
    
    public init(postId: UUID) {
        self.postId = postId
    }
}

public struct PostCreationRequest: PostCreatable {
    public let title: String
    public let content: String
    public let authorId: UUID
    public let categoryId: UUID?
    public let tags: Set<String>
    public let attachments: [Data]
    
    public init(title: String, content: String, authorId: UUID, 
                categoryId: UUID? = nil, tags: Set<String> = [], attachments: [Data] = []) {
        self.title = title
        self.content = content
        self.authorId = authorId
        self.categoryId = categoryId
        self.tags = tags
        self.attachments = attachments
    }
}

public struct PostUpdateRequest: PostUpdatable {
    public let postId: UUID
    public let updatedTitle: String?
    public let updatedContent: String?
    public let updatedCategoryId: UUID?
    public let updatedTags: Set<String>?
    
    public init(postId: UUID, updatedTitle: String? = nil, updatedContent: String? = nil,
                updatedCategoryId: UUID? = nil, updatedTags: Set<String>? = nil) {
        self.postId = postId
        self.updatedTitle = updatedTitle
        self.updatedContent = updatedContent
        self.updatedCategoryId = updatedCategoryId
        self.updatedTags = updatedTags
    }
}

public struct CommentCreationRequest: CommentCreatable {
    public let content: String
    public let authorId: UUID
    public let parentId: UUID?
    public let mentions: Set<UUID>
    
    public init(content: String, authorId: UUID, parentId: UUID? = nil, mentions: Set<UUID> = []) {
        self.content = content
        self.authorId = authorId
        self.parentId = parentId
        self.mentions = mentions
    }
}

public struct BasicSearchQuery: SearchQuery {
    public let query: String
    public let filters: [SearchFilter]
    public let sortBy: SortOption
    public let limit: Int
    
    public init(query: String, filters: [SearchFilter] = [], sortBy: SortOption = .relevance, limit: Int = 20) {
        self.query = query
        self.filters = filters
        self.sortBy = sortBy
        self.limit = limit
    }
}

public struct PostSearchRequest: Codable {
    public let query: String
    public let filters: [SearchFilter]
    public let sortBy: SortOption
    public let limit: Int
    public let offset: Int
    
    public init(query: String, filters: [SearchFilter], sortBy: SortOption, limit: Int, offset: Int = 0) {
        self.query = query
        self.filters = filters
        self.sortBy = sortBy
        self.limit = limit
        self.offset = offset
    }
}

public struct FeedRequest: Codable {
    public let page: Int
    public let limit: Int
    public let feedType: FeedType
    public let userId: UUID?
    
    public enum FeedType: String, Codable {
        case home = "home"
        case trending = "trending"
        case following = "following"
        case user = "user"
    }
    
    public init(page: Int, limit: Int, feedType: FeedType, userId: UUID? = nil) {
        self.page = page
        self.limit = limit
        self.feedType = feedType
        self.userId = userId
    }
}

// MARK: - PostStore (SwiftUI Integration)

@MainActor
public class PostStore: ObservableObject {
    @Published public var homeFeedPosts: [Post] = []
    @Published public var trendingPosts: [Post] = []
    @Published public var isLoadingMore: Bool = false
    @Published public var lastError: PostError?
    
    private let postService: PostService
    private var cancellables = Set<AnyCancellable>()
    
    public init(postService: PostService = .shared) {
        self.postService = postService
        
        // Bind to PostService published properties
        Task {
            await bindToPostService()
        }
    }
    
    private func bindToPostService() async {
        await postService.$homeFeedPosts
            .receive(on: DispatchQueue.main)
            .assign(to: \.homeFeedPosts, on: self)
            .store(in: &cancellables)
        
        await postService.$isLoadingMore
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoadingMore, on: self)
            .store(in: &cancellables)
        
        await postService.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastError, on: self)
            .store(in: &cancellables)
    }
    
    public func loadHomeFeed() async {
        await postService.loadHomeFeed()
    }
    
    public func loadMorePosts() async {
        await postService.loadMorePosts()
    }
    
    public func refreshPosts() async {
        await postService.refreshPosts()
    }
    
    public func search(query: String) async -> [Post] {
        return await postService.search(query: query)
    }
}