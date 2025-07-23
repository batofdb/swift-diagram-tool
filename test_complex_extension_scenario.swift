import Foundation
import UIKit

// Base class
class UserManager {
    var users: [String] = []
    
    func addUser(_ name: String) {
        users.append(name)
    }
}

// Extension 1 - adds properties and methods
extension UserManager {
    var userCount: Int {
        return users.count
    }
    
    func removeUser(_ name: String) {
        users.removeAll { $0 == name }
    }
}

// Extension 2 - adds protocol conformance
extension UserManager: CustomStringConvertible {
    var description: String {
        return "UserManager with \(userCount) users"
    }
}

// Extension 3 - adds nested types
extension UserManager {
    enum SortOrder {
        case ascending
        case descending
    }
    
    func sortedUsers(order: SortOrder) -> [String] {
        switch order {
        case .ascending:
            return users.sorted()
        case .descending:
            return users.sorted().reversed()
        }
    }
}

// Extension 4 - adds generic constraints
extension UserManager where Self: AnyObject {
    func performAsyncOperation() async {
        // Async operation
    }
}

// Cases that should be handled gracefully:

// 1. Extension for unknown type (should create phantom node)
extension UnknownClass {
    func unknownMethod() {
        print("Unknown")
    }
}

// 2. Multiple extensions with protocol conformances
extension UserManager: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(users)
    }
    
    static func == (lhs: UserManager, rhs: UserManager) -> Bool {
        return lhs.users == rhs.users
    }
}

// 3. Extension with where clause
extension Array where Element == String {
    func userNames() -> [String] {
        return self
    }
}

// 4. Complex nested scenarios
class DataStore {
    var data: [String: Any] = [:]
}

extension DataStore {
    subscript(key: String) -> Any? {
        get { return data[key] }
        set { data[key] = newValue }
    }
}

extension DataStore {
    func store<T>(_ value: T, forKey key: String) {
        data[key] = value
    }
    
    func retrieve<T>(_ type: T.Type, forKey key: String) -> T? {
        return data[key] as? T
    }
}