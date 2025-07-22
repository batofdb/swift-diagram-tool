import Foundation

public struct Tag: Hashable {
    public let name: String
    public let color: String
    
    public init(name: String, color: String = "#000000") {
        self.name = name
        self.color = color
    }
}