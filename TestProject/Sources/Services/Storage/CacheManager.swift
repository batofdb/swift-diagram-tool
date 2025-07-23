import Foundation
import Combine

// MARK: - Cache Manager Protocol

public protocol CacheManagerProtocol: AnyObject, Sendable {
    func store<T: Codable>(_ item: T, forKey key: String) async
    func object<T: Codable>(forKey key: String, type: T.Type) async -> T?
    func removeObject(forKey key: String) async
    func removeAll() async
    func exists(forKey key: String) async -> Bool
    func size() async -> Int64
}

// MARK: - Generic Cache Protocol

public protocol GenericCache: AnyObject, Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable
    
    func get(id: Key) async -> Value?
    func set(_ value: Value, for key: Key) async
    func remove(id: Key) async
    func removeAll() async
    func contains(id: Key) async -> Bool
}

// MARK: - Cache Manager Actor

@globalActor
public actor CacheActor {
    public static let shared = CacheActor()
    private init() {}
}

// MARK: - Cache Manager Implementation

@CacheActor
public final class CacheManager: CacheManagerProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = CacheManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var memoryUsage: Int64 = 0
    @Published public private(set) var diskUsage: Int64 = 0
    @Published public private(set) var hitRate: Double = 0.0
    @Published public private(set) var lastCleanupTime: Date = Date()
    
    // MARK: - Private Properties
    
    private let memoryCache: NSCache<NSString, CacheItem>
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let serialQueue: DispatchQueue
    
    private var cacheMetrics: CacheMetrics
    private let cleanupInterval: TimeInterval = 3600 // 1 hour
    private var cleanupTimer: Timer?
    
    // MARK: - Configuration
    
    public struct Configuration {
        let memoryLimit: Int // bytes
        let diskLimit: Int64 // bytes
        let defaultExpiration: TimeInterval // seconds
        let compressionEnabled: Bool
        
        public init(memoryLimit: Int = 50 * 1024 * 1024, // 50MB
                    diskLimit: Int64 = 500 * 1024 * 1024, // 500MB
                    defaultExpiration: TimeInterval = 3600, // 1 hour
                    compressionEnabled: Bool = true) {
            self.memoryLimit = memoryLimit
            self.diskLimit = diskLimit
            self.defaultExpiration = defaultExpiration
            self.compressionEnabled = compressionEnabled
        }
    }
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        
        // Setup memory cache
        self.memoryCache = NSCache<NSString, CacheItem>()
        memoryCache.totalCostLimit = configuration.memoryLimit
        memoryCache.countLimit = 1000
        
        // Setup file manager and directories
        self.fileManager = FileManager.default
        
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cacheDir.appendingPathComponent("AppCache")
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Setup serialization
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        configureDateHandling()
        
        // Setup metrics and cleanup
        self.cacheMetrics = CacheMetrics()
        self.serialQueue = DispatchQueue(label: "CacheManager.serial", qos: .utility)
        
        setupCleanupTimer()
        calculateInitialUsage()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func configureDateHandling() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performPeriodicCleanup()
            }
        }
    }
    
    private func calculateInitialUsage() {
        Task {
            let diskSize = await calculateDiskUsage()
            await MainActor.run {
                diskUsage = diskSize
                memoryUsage = Int64(memoryCache.totalCostLimit)
            }
        }
    }
    
    // MARK: - CacheManagerProtocol Implementation
    
    public func store<T: Codable>(_ item: T, forKey key: String) async {
        await store(item, forKey: key, expiration: configuration.defaultExpiration)
    }
    
    public func store<T: Codable>(_ item: T, forKey key: String, expiration: TimeInterval) async {
        do {
            let data = try encoder.encode(item)
            let compressedData = configuration.compressionEnabled ? compress(data) : data
            
            let cacheItem = CacheItem(
                data: compressedData,
                expiration: Date().addingTimeInterval(expiration),
                size: Int64(compressedData.count),
                isCompressed: configuration.compressionEnabled
            )
            
            // Store in memory cache
            let nsKey = key as NSString
            memoryCache.setObject(cacheItem, forKey: nsKey, cost: compressedData.count)
            
            // Store on disk asynchronously
            await storeToDisk(cacheItem, forKey: key)
            
            // Update metrics
            cacheMetrics.recordWrite(key: key, size: cacheItem.size)
            await updateMemoryUsage()
            
        } catch {
            print("Cache storage failed for key \(key): \(error)")
        }
    }
    
    public func object<T: Codable>(forKey key: String, type: T.Type) async -> T? {
        let nsKey = key as NSString
        
        // Check memory cache first
        if let cacheItem = memoryCache.object(forKey: nsKey) {
            if cacheItem.isValid {
                cacheMetrics.recordHit(key: key, location: .memory)
                return decodeItem(cacheItem, as: type)
            } else {
                // Remove expired item
                memoryCache.removeObject(forKey: nsKey)
            }
        }
        
        // Check disk cache
        if let cacheItem = await loadFromDisk(forKey: key) {
            if cacheItem.isValid {
                // Move back to memory cache
                memoryCache.setObject(cacheItem, forKey: nsKey, cost: Int(cacheItem.size))
                cacheMetrics.recordHit(key: key, location: .disk)
                return decodeItem(cacheItem, as: type)
            } else {
                // Remove expired file
                await removeFromDisk(forKey: key)
            }
        }
        
        // Cache miss
        cacheMetrics.recordMiss(key: key)
        return nil
    }
    
    public func removeObject(forKey key: String) async {
        let nsKey = key as NSString
        memoryCache.removeObject(forKey: nsKey)
        await removeFromDisk(forKey: key)
        cacheMetrics.recordRemoval(key: key)
    }
    
    public func removeAll() async {
        memoryCache.removeAllObjects()
        await removeAllFromDisk()
        cacheMetrics.reset()
        await updateUsageMetrics()
    }
    
    public func exists(forKey key: String) async -> Bool {
        let nsKey = key as NSString
        
        // Check memory first
        if let cacheItem = memoryCache.object(forKey: nsKey) {
            return cacheItem.isValid
        }
        
        // Check disk
        return await fileExists(forKey: key)
    }
    
    public func size() async -> Int64 {
        return diskUsage + memoryUsage
    }
    
    // MARK: - Public Methods
    
    public func getCacheMetrics() async -> CacheMetrics {
        await updateHitRate()
        return cacheMetrics
    }
    
    public func clearExpired() async {
        await performCleanup()
    }
    
    public func compactCache() async {
        await performCleanup()
        await defragmentDisk()
    }
    
    // MARK: - Private Methods
    
    private func storeToDisk(_ item: CacheItem, forKey key: String) async {
        return await withCheckedContinuation { continuation in
            serialQueue.async {
                do {
                    let fileURL = self.cacheDirectory.appendingPathComponent(key.hash.description)
                    try item.data.write(to: fileURL)
                    
                    // Store metadata
                    let metadataURL = fileURL.appendingPathExtension("meta")
                    let metadata = CacheMetadata(
                        expiration: item.expiration,
                        size: item.size,
                        isCompressed: item.isCompressed,
                        createdAt: Date()
                    )
                    let metadataData = try self.encoder.encode(metadata)
                    try metadataData.write(to: metadataURL)
                    
                    continuation.resume()
                } catch {
                    print("Failed to write to disk for key \(key): \(error)")
                    continuation.resume()
                }
            }
        }
    }
    
    private func loadFromDisk(forKey key: String) async -> CacheItem? {
        return await withCheckedContinuation { continuation in
            serialQueue.async {
                do {
                    let fileURL = self.cacheDirectory.appendingPathComponent(key.hash.description)
                    let metadataURL = fileURL.appendingPathExtension("meta")
                    
                    guard self.fileManager.fileExists(atPath: fileURL.path),
                          self.fileManager.fileExists(atPath: metadataURL.path) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let data = try Data(contentsOf: fileURL)
                    let metadataData = try Data(contentsOf: metadataURL)
                    let metadata = try self.decoder.decode(CacheMetadata.self, from: metadataData)
                    
                    let cacheItem = CacheItem(
                        data: data,
                        expiration: metadata.expiration,
                        size: metadata.size,
                        isCompressed: metadata.isCompressed
                    )
                    
                    continuation.resume(returning: cacheItem)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func removeFromDisk(forKey key: String) async {
        await withCheckedContinuation { continuation in
            serialQueue.async {
                let fileURL = self.cacheDirectory.appendingPathComponent(key.hash.description)
                let metadataURL = fileURL.appendingPathExtension("meta")
                
                try? self.fileManager.removeItem(at: fileURL)
                try? self.fileManager.removeItem(at: metadataURL)
                
                continuation.resume()
            }
        }
    }
    
    private func removeAllFromDisk() async {
        await withCheckedContinuation { continuation in
            serialQueue.async {
                do {
                    let contents = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, 
                                                                           includingPropertiesForKeys: nil)
                    for url in contents {
                        try self.fileManager.removeItem(at: url)
                    }
                } catch {
                    print("Failed to clear disk cache: \(error)")
                }
                continuation.resume()
            }
        }
    }
    
    private func fileExists(forKey key: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            serialQueue.async {
                let fileURL = self.cacheDirectory.appendingPathComponent(key.hash.description)
                let exists = self.fileManager.fileExists(atPath: fileURL.path)
                continuation.resume(returning: exists)
            }
        }
    }
    
    private func decodeItem<T: Codable>(_ item: CacheItem, as type: T.Type) -> T? {
        do {
            let data = item.isCompressed ? decompress(item.data) : item.data
            return try decoder.decode(type, from: data)
        } catch {
            print("Failed to decode cache item: \(error)")
            return nil
        }
    }
    
    private func compress(_ data: Data) -> Data {
        // Simple compression (in real app, use proper compression library)
        return data
    }
    
    private func decompress(_ data: Data) -> Data {
        // Simple decompression (in real app, use proper compression library)
        return data
    }
    
    private func calculateDiskUsage() async -> Int64 {
        return await withCheckedContinuation { continuation in
            serialQueue.async {
                var totalSize: Int64 = 0
                
                do {
                    let contents = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, 
                                                                           includingPropertiesForKeys: [.fileSizeKey])
                    for url in contents {
                        let attributes = try self.fileManager.attributesOfItem(atPath: url.path)
                        if let size = attributes[.size] as? Int64 {
                            totalSize += size
                        }
                    }
                } catch {
                    print("Failed to calculate disk usage: \(error)")
                }
                
                continuation.resume(returning: totalSize)
            }
        }
    }
    
    private func performCleanup() async {
        // Remove expired items from memory cache
        // Note: NSCache doesn't provide enumeration, so we rely on access-time cleanup
        
        // Clean up disk cache
        await cleanupExpiredDiskItems()
        
        // Update usage metrics
        await updateUsageMetrics()
        
        await MainActor.run {
            lastCleanupTime = Date()
        }
    }
    
    private func cleanupExpiredDiskItems() async {
        await withCheckedContinuation { continuation in
            serialQueue.async {
                do {
                    let contents = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, 
                                                                           includingPropertiesForKeys: nil)
                    
                    for url in contents where url.pathExtension == "meta" {
                        let metadataData = try Data(contentsOf: url)
                        let metadata = try self.decoder.decode(CacheMetadata.self, from: metadataData)
                        
                        if metadata.expiration < Date() {
                            // Remove expired item and its data file
                            try self.fileManager.removeItem(at: url)
                            let dataURL = url.deletingPathExtension()
                            try? self.fileManager.removeItem(at: dataURL)
                        }
                    }
                } catch {
                    print("Failed to cleanup expired items: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
    
    private func performPeriodicCleanup() async {
        await performCleanup()
        
        // Additional periodic maintenance
        if diskUsage > configuration.diskLimit {
            await evictLeastRecentlyUsed()
        }
    }
    
    private func evictLeastRecentlyUsed() async {
        // Implement LRU eviction based on file access times
        await withCheckedContinuation { continuation in
            serialQueue.async {
                // Implementation would sort files by access time and remove oldest
                // until under disk limit
                continuation.resume()
            }
        }
    }
    
    private func defragmentDisk() async {
        // Compact disk storage by removing fragmentation
        // Implementation would reorganize files for better performance
    }
    
    private func updateUsageMetrics() async {
        let newDiskUsage = await calculateDiskUsage()
        await MainActor.run {
            diskUsage = newDiskUsage
        }
    }
    
    private func updateMemoryUsage() async {
        // Estimate memory usage (NSCache doesn't provide exact usage)
        let estimated = Int64(memoryCache.totalCostLimit / 10) // Rough estimate
        await MainActor.run {
            memoryUsage = estimated
        }
    }
    
    private func updateHitRate() async {
        let metrics = cacheMetrics
        let total = metrics.hits + metrics.misses
        let rate = total > 0 ? Double(metrics.hits) / Double(total) : 0.0
        
        await MainActor.run {
            hitRate = rate
        }
    }
}

// MARK: - Cache Item

private class CacheItem: NSObject {
    let data: Data
    let expiration: Date
    let size: Int64
    let isCompressed: Bool
    
    init(data: Data, expiration: Date, size: Int64, isCompressed: Bool) {
        self.data = data
        self.expiration = expiration
        self.size = size
        self.isCompressed = isCompressed
        super.init()
    }
    
    var isValid: Bool {
        return Date() < expiration
    }
    
    var isExpired: Bool {
        return !isValid
    }
}

// MARK: - Cache Metadata

private struct CacheMetadata: Codable {
    let expiration: Date
    let size: Int64
    let isCompressed: Bool
    let createdAt: Date
}

// MARK: - Cache Metrics

public struct CacheMetrics {
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    private(set) var writes: Int = 0
    private(set) var removals: Int = 0
    private(set) var totalDataSize: Int64 = 0
    
    private var hitsByKey: [String: Int] = [:]
    private var missByKey: [String: Int] = [:]
    private var hitsByLocation: [CacheLocation: Int] = [:]
    
    public enum CacheLocation {
        case memory
        case disk
    }
    
    public var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0.0
    }
    
    public var missRate: Double {
        return 1.0 - hitRate
    }
    
    mutating func recordHit(key: String, location: CacheLocation) {
        hits += 1
        hitsByKey[key, default: 0] += 1
        hitsByLocation[location, default: 0] += 1
    }
    
    mutating func recordMiss(key: String) {
        misses += 1
        missByKey[key, default: 0] += 1
    }
    
    mutating func recordWrite(key: String, size: Int64) {
        writes += 1
        totalDataSize += size
    }
    
    mutating func recordRemoval(key: String) {
        removals += 1
    }
    
    mutating func reset() {
        hits = 0
        misses = 0
        writes = 0
        removals = 0
        totalDataSize = 0
        hitsByKey.removeAll()
        missByKey.removeAll()
        hitsByLocation.removeAll()
    }
    
    public func getHitCount(for key: String) -> Int {
        return hitsByKey[key, default: 0]
    }
    
    public func getMissCount(for key: String) -> Int {
        return missByKey[key, default: 0]
    }
    
    public func getHitCount(for location: CacheLocation) -> Int {
        return hitsByLocation[location, default: 0]
    }
}

// MARK: - Generic Cache Implementations

public final class PostCache<T: Post>: GenericCache {
    public typealias Key = UUID
    public typealias Value = T
    
    private let cacheManager: CacheManagerProtocol
    private let keyPrefix: String
    
    public init(cacheManager: CacheManagerProtocol = CacheManager.shared, maxSize: Int = 500) {
        self.cacheManager = cacheManager
        self.keyPrefix = "post_cache_"
    }
    
    public func get(id: UUID) async -> T? {
        let key = keyPrefix + id.uuidString
        return await cacheManager.object(forKey: key, type: T.self)
    }
    
    public func set(_ value: T, for key: UUID) async {
        let cacheKey = keyPrefix + key.uuidString
        await cacheManager.store(value, forKey: cacheKey)
    }
    
    public func remove(id: UUID) async {
        let key = keyPrefix + id.uuidString
        await cacheManager.removeObject(forKey: key)
    }
    
    public func removeAll() async {
        // Would need a more sophisticated implementation to remove only posts
        // For now, this is a placeholder
    }
    
    public func contains(id: UUID) async -> Bool {
        let key = keyPrefix + id.uuidString
        return await cacheManager.exists(forKey: key)
    }
}

public final class CommentCache<T: Comment>: GenericCache {
    public typealias Key = UUID
    public typealias Value = T
    
    private let cacheManager: CacheManagerProtocol
    private let keyPrefix: String
    
    public init(cacheManager: CacheManagerProtocol = CacheManager.shared, maxSize: Int = 1000) {
        self.cacheManager = cacheManager
        self.keyPrefix = "comment_cache_"
    }
    
    public func get(id: UUID) async -> T? {
        let key = keyPrefix + id.uuidString
        return await cacheManager.object(forKey: key, type: T.self)
    }
    
    public func set(_ value: T, for key: UUID) async {
        let cacheKey = keyPrefix + key.uuidString
        await cacheManager.store(value, forKey: cacheKey)
    }
    
    public func remove(id: UUID) async {
        let key = keyPrefix + id.uuidString
        await cacheManager.removeObject(forKey: key)
    }
    
    public func removeAll() async {
        // Would need a more sophisticated implementation to remove only comments
        // For now, this is a placeholder
    }
    
    public func contains(id: UUID) async -> Bool {
        let key = keyPrefix + id.uuidString
        return await cacheManager.exists(forKey: key)
    }
}

// MARK: - String Hash Extension

private extension String {
    var hash: Int {
        return self.hashValue
    }
}