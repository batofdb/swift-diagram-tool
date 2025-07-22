import Foundation

public class RelationshipGraph {
    public struct Node: Hashable {
        public let type: TypeInfo
        public var relationships: Set<Relationship> = []
        
        public init(type: TypeInfo) {
            self.type = type
        }
        
        public static func == (lhs: Node, rhs: Node) -> Bool {
            lhs.type.name == rhs.type.name && lhs.type.moduleName == rhs.type.moduleName
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(type.name)
            hasher.combine(type.moduleName)
        }
    }
    
    public struct Relationship: Codable, Hashable {
        public enum Kind: String, Codable {
            case inheritance = "inherits"
            case protocolConformance = "conforms"
            case dependency = "uses"
            case composition = "contains"
            case aggregation = "references"
        }
        
        public let from: String
        public let to: String
        public let kind: Kind
        public let details: String?
        
        public init(from: String, to: String, kind: Kind, details: String? = nil) {
            self.from = from
            self.to = to
            self.kind = kind
            self.details = details
        }
    }
    
    private var nodes: [String: Node] = [:]
    private var relationships: Set<Relationship> = []
    
    public init() {}
    
    public func addType(_ type: TypeInfo) {
        let node = Node(type: type)
        nodes[type.name] = node
        
        // Add inheritance relationships
        for inherited in type.inheritedTypes {
            addRelationship(from: type.name, to: inherited, kind: .inheritance)
        }
        
        // Add protocol conformance relationships
        for protocolName in type.conformedProtocols {
            addRelationship(from: type.name, to: protocolName, kind: .protocolConformance)
        }
        
        // Add dependency relationships based on properties
        for property in type.properties {
            if isCustomType(property.typeName) {
                addRelationship(
                    from: type.name,
                    to: extractTypeName(from: property.typeName),
                    kind: property.isLet ? .aggregation : .composition,
                    details: "property: \(property.name)"
                )
            }
        }
        
        // Add dependency relationships based on method parameters and return types
        for method in type.methods {
            // Check return type
            if let returnType = method.returnType, isCustomType(returnType) {
                addRelationship(
                    from: type.name,
                    to: extractTypeName(from: returnType),
                    kind: .dependency,
                    details: "returns from: \(method.name)"
                )
            }
            
            // Check parameters
            for param in method.parameters {
                if isCustomType(param.typeName) {
                    addRelationship(
                        from: type.name,
                        to: extractTypeName(from: param.typeName),
                        kind: .dependency,
                        details: "parameter in: \(method.name)"
                    )
                }
            }
        }
    }
    
    public func addRelationship(from: String, to: String, kind: Relationship.Kind, details: String? = nil) {
        let relationship = Relationship(from: from, to: to, kind: kind, details: details)
        relationships.insert(relationship)
        
        if var node = nodes[from] {
            node.relationships.insert(relationship)
            nodes[from] = node
        }
    }
    
    public func getNode(for typeName: String) -> Node? {
        return nodes[typeName]
    }
    
    public func getAllNodes() -> [Node] {
        return Array(nodes.values)
    }
    
    public func getAllRelationships() -> Set<Relationship> {
        return relationships
    }
    
    public func getRelatedNodes(to typeName: String, maxDepth: Int = 3) -> Set<Node> {
        var visited = Set<String>()
        var result = Set<Node>()
        
        func traverse(from: String, depth: Int) {
            guard depth > 0, !visited.contains(from) else { return }
            visited.insert(from)
            
            if let node = nodes[from] {
                result.insert(node)
            }
            
            // Find all relationships involving this type
            for relationship in relationships {
                if relationship.from == from {
                    traverse(from: relationship.to, depth: depth - 1)
                } else if relationship.to == from {
                    traverse(from: relationship.from, depth: depth - 1)
                }
            }
        }
        
        traverse(from: typeName, depth: maxDepth)
        return result
    }
    
    // Helper methods
    private func isCustomType(_ typeName: String) -> Bool {
        // Filter out common Swift standard library types
        let standardTypes = [
            "Int", "String", "Bool", "Double", "Float", "Character",
            "Array", "Dictionary", "Set", "Optional", "Result",
            "Data", "Date", "URL", "UUID", "Any", "AnyObject",
            "Void", "Never"
        ]
        
        let cleanType = extractTypeName(from: typeName)
        return !standardTypes.contains(cleanType)
    }
    
    private func extractTypeName(from fullType: String) -> String {
        // Extract base type name from generics, optionals, arrays, etc.
        var type = fullType
        
        // Remove optional markers
        type = type.replacingOccurrences(of: "?", with: "")
        type = type.replacingOccurrences(of: "!", with: "")
        
        // Extract from array notation
        if type.hasPrefix("[") && type.hasSuffix("]") {
            type = String(type.dropFirst().dropLast())
        }
        
        // Extract from generic notation
        if let genericStart = type.firstIndex(of: "<") {
            type = String(type[..<genericStart])
        }
        
        // Extract from module prefix
        if let lastDot = type.lastIndex(of: ".") {
            type = String(type[type.index(after: lastDot)...])
        }
        
        return type.trimmingCharacters(in: .whitespaces)
    }
}
