import Foundation
import UIKit

// Test comprehensive extension consolidation scenarios

// Scenario 1: Basic extension consolidation
class BasicUser {
    let id: String
    var name: String
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

extension BasicUser {
    var displayName: String {
        return "User: \(name)"
    }
    
    func greet() -> String {
        return "Hello, \(name)!"
    }
}

extension BasicUser {
    static func createDefault() -> BasicUser {
        return BasicUser(id: UUID().uuidString, name: "Default")
    }
}

// Scenario 2: Extension with protocol conformances
class Product {
    let id: String
    let name: String
    let price: Double
    
    init(id: String, name: String, price: Double) {
        self.id = id
        self.name = name
        self.price = price
    }
}

extension Product: Equatable {
    static func == (lhs: Product, rhs: Product) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Product: CustomStringConvertible {
    var description: String {
        return "\(name): $\(price)"
    }
}

extension Product: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Scenario 3: Multiple extensions with same protocol
class Order {
    let id: String
    var items: [Product] = []
    
    init(id: String) {
        self.id = id
    }
}

extension Order: CustomStringConvertible {
    var description: String {
        return "Order \(id) with \(items.count) items"
    }
}

extension Order: Codable {
    enum CodingKeys: String, CodingKey {
        case id, items
    }
}

// Scenario 4: Extension with nested types
class DataManager {
    private var cache: [String: Any] = [:]
}

extension DataManager {
    enum CacheError: Error {
        case keyNotFound
        case invalidType
    }
    
    struct CacheKey {
        let value: String
    }
    
    func store<T>(_ value: T, for key: CacheKey) {
        cache[key.value] = value
    }
    
    func retrieve<T>(_ type: T.Type, for key: CacheKey) throws -> T {
        guard let value = cache[key.value] else {
            throw CacheError.keyNotFound
        }
        guard let typedValue = value as? T else {
            throw CacheError.invalidType
        }
        return typedValue
    }
}

// Scenario 5: Extension with generic constraints
class Container<T> {
    private var items: [T] = []
}

extension Container where T: Equatable {
    func contains(_ item: T) -> Bool {
        return items.contains(item)
    }
    
    func remove(_ item: T) {
        items.removeAll { $0 == item }
    }
}

extension Container where T: Comparable {
    func sorted() -> [T] {
        return items.sorted()
    }
    
    var max: T? {
        return items.max()
    }
}

// Scenario 6: Protocol extension (external type)
extension String {
    var isEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    func trimmed() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Scenario 7: Extensions that add computed properties and methods
struct Point {
    let x: Double
    let y: Double
}

extension Point {
    var magnitude: Double {
        return sqrt(x * x + y * y)
    }
    
    var angle: Double {
        return atan2(y, x)
    }
}

extension Point {
    func distance(to other: Point) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func scaled(by factor: Double) -> Point {
        return Point(x: x * factor, y: y * factor)
    }
}

// Scenario 8: Extension with subscripts and initializers
class Matrix {
    private var data: [[Double]]
    let rows: Int
    let columns: Int
    
    init(rows: Int, columns: Int) {
        self.rows = rows
        self.columns = columns
        self.data = Array(repeating: Array(repeating: 0.0, count: columns), count: rows)
    }
}

extension Matrix {
    subscript(row: Int, column: Int) -> Double {
        get {
            return data[row][column]
        }
        set {
            data[row][column] = newValue
        }
    }
    
    convenience init(identity size: Int) {
        self.init(rows: size, columns: size)
        for i in 0..<size {
            self[i, i] = 1.0
        }
    }
}

// Scenario 9: Extensions for unknown/external types
extension UnknownClass {
    func extensionMethod() -> String {
        return "Extended unknown class"
    }
    
    var extensionProperty: Int {
        return 42
    }
}

// Scenario 10: Complex inheritance with extensions
class BaseViewController: UIViewController {
    var customProperty: String = ""
}

extension BaseViewController {
    func setupUI() {
        view.backgroundColor = .white
    }
    
    var isModalPresentation: Bool {
        return presentingViewController != nil
    }
}

class DetailViewController: BaseViewController {
    var detailData: String = ""
}

extension DetailViewController {
    func loadDetailData() {
        detailData = "Loaded detail data"
    }
}