protocol CacheProtocol {
    associatedtype Key: Hashable
    associatedtype Value: Codable
    
    var capacity: Int { get }
    
    func store(_ value: Value, for key: Key)
    func retrieve(for key: Key) -> Value?
    func remove(for key: Key)
    
    subscript(key: Key) -> Value? { get set }
}

protocol NetworkProtocol {
    associatedtype Request
    associatedtype Response: Codable
    
    func send(_ request: Request) async throws -> Response
}

class MemoryCache<K: Hashable, V: Codable>: CacheProtocol {
    typealias Key = K
    typealias Value = V
    
    private var storage: [K: V] = [:]
    
    var capacity: Int = 100
    
    func store(_ value: V, for key: K) {
        storage[key] = value
    }
    
    func retrieve(for key: K) -> V? {
        return storage[key]
    }
    
    func remove(for key: K) {
        storage.removeValue(forKey: key)
    }
    
    subscript(key: K) -> V? {
        get { return storage[key] }
        set { storage[key] = newValue }
    }
}

struct URLRequest: Codable {
    let url: String
    let method: String
}

struct APIResponse: Codable {
    let status: Int
    let data: String
}

class HTTPClient: NetworkProtocol {
    typealias Request = URLRequest
    typealias Response = APIResponse
    
    func send(_ request: URLRequest) async throws -> APIResponse {
        // Implementation
        return APIResponse(status: 200, data: "test")
    }
}