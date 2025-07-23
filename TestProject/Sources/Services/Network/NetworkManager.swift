import Foundation
import Combine
import Network

// MARK: - Network Manager Protocol

public protocol NetworkManagerProtocol: AnyObject, Sendable {
    func perform<T: Codable>(_ request: APIRequest) async throws -> T
    func perform<T: Codable>(_ request: APIRequest, expecting: T.Type) async throws -> T
    func performVoid(_ request: APIRequest) async throws
    func downloadFile(from url: URL) async throws -> Data
    func uploadFile(_ data: Data, to url: URL, mimeType: String) async throws -> UploadResponse
}

// MARK: - Network Manager Actor

@globalActor
public actor NetworkActor {
    public static let shared = NetworkActor()
    private init() {}
}

// MARK: - Network Manager Implementation

@NetworkActor
public final class NetworkManager: NetworkManagerProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = NetworkManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var isConnected: Bool = true
    @Published public private(set) var connectionType: NWInterface.InterfaceType = .wifi
    @Published public private(set) var activeRequests: Set<String> = []
    @Published public private(set) var requestStats: NetworkStats = NetworkStats()
    
    // MARK: - Private Properties
    
    private let session: URLSession
    private let cache: URLCache
    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private let requestQueue: DispatchQueue
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private var interceptors: [NetworkInterceptor] = []
    private var retryConfiguration: RetryConfiguration
    private let throttleManager: RequestThrottleManager
    private let metricsCollector: NetworkMetricsCollector
    
    // MARK: - Configuration
    
    public struct Configuration {
        let baseURL: URL
        let timeout: TimeInterval
        let maxRetries: Int
        let retryDelay: TimeInterval
        let cachePolicy: URLRequest.CachePolicy
        let allowsCellularAccess: Bool
        
        public init(baseURL: URL = URL(string: "https://api.example.com")!,
                    timeout: TimeInterval = 30.0,
                    maxRetries: Int = 3,
                    retryDelay: TimeInterval = 1.0,
                    cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                    allowsCellularAccess: Bool = true) {
            self.baseURL = baseURL
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.retryDelay = retryDelay
            self.cachePolicy = cachePolicy
            self.allowsCellularAccess = allowsCellularAccess
        }
    }
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.timeoutIntervalForResource = configuration.timeout * 2
        config.allowsCellularAccess = configuration.allowsCellularAccess
        config.waitsForConnectivity = true
        config.requestCachePolicy = configuration.cachePolicy
        
        // Configure cache
        self.cache = URLCache(memoryCapacity: 20 * 1024 * 1024, // 20MB memory
                              diskCapacity: 100 * 1024 * 1024,   // 100MB disk
                              diskPath: "network_cache")
        config.urlCache = cache
        
        self.session = URLSession(configuration: config)
        
        // Configure JSON handling
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        configureDateHandling()
        
        // Configure networking monitoring
        self.monitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
        self.requestQueue = DispatchQueue(label: "NetworkRequests", qos: .userInitiated)
        
        // Configure retry and throttling
        self.retryConfiguration = RetryConfiguration(
            maxRetries: configuration.maxRetries,
            baseDelay: configuration.retryDelay
        )
        self.throttleManager = RequestThrottleManager()
        self.metricsCollector = NetworkMetricsCollector()
        
        setupNetworkMonitoring()
        setupDefaultInterceptors()
    }
    
    // MARK: - Setup
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @NetworkActor in
                await self?.handleNetworkPathUpdate(path)
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    private func setupDefaultInterceptors() {
        // Add default interceptors
        addInterceptor(AuthenticationInterceptor())
        addInterceptor(RetryInterceptor(configuration: retryConfiguration))
        addInterceptor(CachingInterceptor())
        addInterceptor(MetricsInterceptor(collector: metricsCollector))
        addInterceptor(ThrottleInterceptor(manager: throttleManager))
    }
    
    private func configureDateHandling() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
    }
    
    // MARK: - NetworkManagerProtocol Implementation
    
    public func perform<T: Codable>(_ request: APIRequest) async throws -> T {
        return try await perform(request, expecting: T.self)
    }
    
    public func perform<T: Codable>(_ request: APIRequest, expecting type: T.Type) async throws -> T {
        let requestId = UUID().uuidString
        
        await MainActor.run {
            activeRequests.insert(requestId)
        }
        
        defer {
            Task {
                await MainActor.run {
                    activeRequests.remove(requestId)
                }
            }
        }
        
        do {
            // Check network connectivity
            guard isConnected else {
                throw NetworkError.noConnection
            }
            
            // Build URLRequest
            let urlRequest = try buildURLRequest(for: request)
            
            // Apply interceptors (pre-request)
            var modifiedRequest = urlRequest
            for interceptor in interceptors {
                modifiedRequest = try await interceptor.intercept(request: modifiedRequest, phase: .preRequest)
            }
            
            // Perform request with retry logic
            let (data, response) = try await performRequestWithRetry(modifiedRequest, requestId: requestId)
            
            // Apply interceptors (post-request)
            for interceptor in interceptors {
                try await interceptor.intercept(response: response, data: data, phase: .postRequest)
            }
            
            // Parse response
            let result: T = try parseResponse(data: data, response: response, requestId: requestId)
            
            // Update metrics
            await updateSuccessMetrics(for: request.endpoint)
            
            return result
            
        } catch {
            await updateErrorMetrics(for: request.endpoint, error: error)
            throw error
        }
    }
    
    public func performVoid(_ request: APIRequest) async throws {
        let _: EmptyResponse = try await perform(request)
    }
    
    public func downloadFile(from url: URL) async throws -> Data {
        let requestId = UUID().uuidString
        
        await MainActor.run {
            activeRequests.insert(requestId)
        }
        
        defer {
            Task {
                await MainActor.run {
                    activeRequests.remove(requestId)
                }
            }
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            return data
        } catch {
            throw NetworkError.downloadFailed(error)
        }
    }
    
    public func uploadFile(_ data: Data, to url: URL, mimeType: String) async throws -> UploadResponse {
        let requestId = UUID().uuidString
        
        await MainActor.run {
            activeRequests.insert(requestId)
        }
        
        defer {
            Task {
                await MainActor.run {
                    activeRequests.remove(requestId)
                }
            }
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (responseData, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let uploadResponse: UploadResponse = try decoder.decode(UploadResponse.self, from: responseData)
            return uploadResponse
            
        } catch {
            throw NetworkError.uploadFailed(error)
        }
    }
    
    // MARK: - Public Methods
    
    public func addInterceptor(_ interceptor: NetworkInterceptor) {
        interceptors.append(interceptor)
    }
    
    public func removeInterceptor(_ interceptor: NetworkInterceptor) {
        interceptors.removeAll { $0.id == interceptor.id }
    }
    
    public func clearCache() async {
        cache.removeAllCachedResponses()
        await metricsCollector.reset()
    }
    
    public func getNetworkStats() async -> NetworkStats {
        return requestStats
    }
    
    // MARK: - Private Methods
    
    private func buildURLRequest(for apiRequest: APIRequest) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent(apiRequest.endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = apiRequest.method.rawValue
        request.cachePolicy = configuration.cachePolicy
        request.timeoutInterval = configuration.timeout
        
        // Add headers
        for (key, value) in apiRequest.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("NetworkManager/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add body for POST/PUT requests
        if let body = apiRequest.body {
            request.httpBody = try encoder.encode(body)
        }
        
        // Add query parameters
        if !apiRequest.queryParameters.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.queryItems = apiRequest.queryParameters.map { 
                URLQueryItem(name: $0.key, value: $0.value) 
            }
            request.url = components?.url
        }
        
        return request
    }
    
    private func performRequestWithRetry(_ request: URLRequest, requestId: String) async throws -> (Data, URLResponse) {
        var lastError: Error?
        
        for attempt in 0..<configuration.maxRetries {
            do {
                let result = try await session.data(for: request)
                
                // Check if response is successful
                if let httpResponse = result.1 as? HTTPURLResponse {
                    if 200...299 ~= httpResponse.statusCode {
                        return result
                    } else if 400...499 ~= httpResponse.statusCode {
                        // Client errors shouldn't be retried
                        throw NetworkError.clientError(httpResponse.statusCode)
                    } else {
                        throw NetworkError.serverError(httpResponse.statusCode)
                    }
                } else {
                    throw NetworkError.invalidResponse
                }
                
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if case NetworkError.clientError = error {
                    throw error
                }
                
                if case NetworkError.noConnection = error {
                    throw error
                }
                
                // Wait before retrying (exponential backoff)
                if attempt < configuration.maxRetries - 1 {
                    let delay = configuration.retryDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.maxRetriesExceeded
    }
    
    private func parseResponse<T: Codable>(data: Data, response: URLResponse, requestId: String) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            // Try to parse error response
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw NetworkError.apiError(errorResponse)
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        // Handle empty responses
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) async {
        await MainActor.run {
            isConnected = path.status == .satisfied
            
            if let interface = path.availableInterfaces.first {
                connectionType = interface.type
            }
        }
        
        // Notify about connectivity change
        NotificationCenter.default.post(
            name: .networkConnectivityChanged,
            object: nil,
            userInfo: ["isConnected": path.status == .satisfied]
        )
    }
    
    private func updateSuccessMetrics(for endpoint: String) async {
        await MainActor.run {
            requestStats.incrementSuccess(for: endpoint)
        }
    }
    
    private func updateErrorMetrics(for endpoint: String, error: Error) async {
        await MainActor.run {
            requestStats.incrementError(for: endpoint, error: error)
        }
    }
}

// MARK: - Network Error

public enum NetworkError: LocalizedError, Equatable {
    case noConnection
    case invalidURL
    case invalidResponse
    case decodingFailed(Error)
    case encodingFailed(Error)
    case clientError(Int)
    case serverError(Int)
    case unauthorized
    case forbidden
    case notFound
    case timeout
    case maxRetriesExceeded
    case downloadFailed(Error)
    case uploadFailed(Error)
    case apiError(APIErrorResponse)
    
    public var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .clientError(let code):
            return "Client error with code: \(code)"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .timeout:
            return "Request timed out"
        case .maxRetriesExceeded:
            return "Maximum retries exceeded"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .apiError(let errorResponse):
            return errorResponse.message
        }
    }
    
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.noConnection, .noConnection),
             (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.timeout, .timeout),
             (.maxRetriesExceeded, .maxRetriesExceeded):
            return true
        case (.clientError(let lhsCode), .clientError(let rhsCode)),
             (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode
        case (.apiError(let lhsError), .apiError(let rhsError)):
            return lhsError.code == rhsError.code
        default:
            return false
        }
    }
}

// MARK: - API Request

public struct APIRequest {
    let endpoint: String
    let method: HTTPMethod
    let headers: [String: String]
    let queryParameters: [String: String]
    let body: AnyEncodable?
    
    public enum HTTPMethod: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
        case PATCH = "PATCH"
    }
    
    public init(endpoint: String, 
                method: HTTPMethod = .GET,
                headers: [String: String] = [:],
                queryParameters: [String: String] = [:],
                body: AnyEncodable? = nil) {
        self.endpoint = endpoint
        self.method = method
        self.headers = headers
        self.queryParameters = queryParameters
        self.body = body
    }
    
    // MARK: - Convenience Methods
    
    public static func getUser(id: UUID) -> APIRequest {
        return APIRequest(endpoint: "users/\(id.uuidString)")
    }
    
    public static func updateUser(_ user: User) -> APIRequest {
        return APIRequest(
            endpoint: "users/\(user.id.uuidString)",
            method: .PUT,
            body: AnyEncodable(user)
        )
    }
    
    public static func deleteUser(id: UUID) -> APIRequest {
        return APIRequest(
            endpoint: "users/\(id.uuidString)",
            method: .DELETE
        )
    }
    
    public static func searchUsers(query: String) -> APIRequest {
        return APIRequest(
            endpoint: "users/search",
            queryParameters: ["q": query]
        )
    }
    
    public static func followUser(id: UUID) -> APIRequest {
        return APIRequest(
            endpoint: "users/\(id.uuidString)/follow",
            method: .POST
        )
    }
    
    public static func unfollowUser(id: UUID) -> APIRequest {
        return APIRequest(
            endpoint: "users/\(id.uuidString)/follow",
            method: .DELETE
        )
    }
    
    public static func getUserFollowers(userId: UUID) -> APIRequest {
        return APIRequest(endpoint: "users/\(userId.uuidString)/followers")
    }
    
    public static func getUserFollowing(userId: UUID) -> APIRequest {
        return APIRequest(endpoint: "users/\(userId.uuidString)/following")
    }
    
    public static func login(email: String, password: String) -> APIRequest {
        let credentials = ["email": email, "password": password]
        return APIRequest(
            endpoint: "auth/login",
            method: .POST,
            body: AnyEncodable(credentials)
        )
    }
    
    public static let logout = APIRequest(endpoint: "auth/logout", method: .POST)
    
    // Post endpoints
    public static func getPost(id: UUID) -> APIRequest {
        return APIRequest(endpoint: "posts/\(id.uuidString)")
    }
    
    public static func createPost(_ post: Post) -> APIRequest {
        return APIRequest(
            endpoint: "posts",
            method: .POST,
            body: AnyEncodable(post)
        )
    }
    
    public static func updatePost(_ post: Post) -> APIRequest {
        return APIRequest(
            endpoint: "posts/\(post.id.uuidString)",
            method: .PUT,
            body: AnyEncodable(post)
        )
    }
    
    public static func deletePost(id: UUID) -> APIRequest {
        return APIRequest(
            endpoint: "posts/\(id.uuidString)",
            method: .DELETE
        )
    }
    
    public static func searchPosts(_ searchRequest: PostSearchRequest) -> APIRequest {
        return APIRequest(
            endpoint: "posts/search",
            method: .POST,
            body: AnyEncodable(searchRequest)
        )
    }
    
    public static func likePost(id: UUID) -> APIRequest {
        return APIRequest(
            endpoint: "posts/\(id.uuidString)/like",
            method: .POST
        )
    }
    
    public static func unlikePost(id: UUID) -> APIRequest {
        return APIRequest(
            endpoint: "posts/\(id.uuidString)/like",
            method: .DELETE
        )
    }
    
    public static func createComment(_ comment: Comment) -> APIRequest {
        return APIRequest(
            endpoint: "comments",
            method: .POST,
            body: AnyEncodable(comment)
        )
    }
}

// MARK: - Supporting Types

public struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    public init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }
    
    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

public struct EmptyResponse: Codable {
    public init() {}
}

public struct APIErrorResponse: Codable, Equatable {
    public let code: String
    public let message: String
    public let details: [String: String]?
    
    public init(code: String, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

public struct UploadResponse: Codable {
    public let url: URL
    public let filename: String
    public let size: Int64
    public let mimeType: String
    
    public init(url: URL, filename: String, size: Int64, mimeType: String) {
        self.url = url
        self.filename = filename
        self.size = size
        self.mimeType = mimeType
    }
}

// MARK: - Network Stats

public struct NetworkStats {
    private var successCounts: [String: Int] = [:]
    private var errorCounts: [String: Int] = [:]
    private var totalRequests: Int = 0
    private var totalErrors: Int = 0
    
    public var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalRequests - totalErrors) / Double(totalRequests)
    }
    
    public var errorRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalErrors) / Double(totalRequests)
    }
    
    public mutating func incrementSuccess(for endpoint: String) {
        successCounts[endpoint, default: 0] += 1
        totalRequests += 1
    }
    
    public mutating func incrementError(for endpoint: String, error: Error) {
        errorCounts[endpoint, default: 0] += 1
        totalRequests += 1
        totalErrors += 1
    }
    
    public func getSuccessCount(for endpoint: String) -> Int {
        return successCounts[endpoint, default: 0]
    }
    
    public func getErrorCount(for endpoint: String) -> Int {
        return errorCounts[endpoint, default: 0]
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    public static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
}