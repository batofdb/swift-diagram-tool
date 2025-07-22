import Foundation

public class DOTGenerator {
    private let graph: RelationshipGraph
    private let options: GeneratorOptions
    
    public struct GeneratorOptions {
        public let includePrivate: Bool
        public let includeProperties: Bool
        public let includeMethods: Bool
        public let includeExtensions: Bool
        public let focusType: String?
        public let maxDepth: Int
        
        public init(
            includePrivate: Bool = false,
            includeProperties: Bool = true,
            includeMethods: Bool = true,
            includeExtensions: Bool = false,
            focusType: String? = nil,
            maxDepth: Int = 3
        ) {
            self.includePrivate = includePrivate
            self.includeProperties = includeProperties
            self.includeMethods = includeMethods
            self.includeExtensions = includeExtensions
            self.focusType = focusType
            self.maxDepth = maxDepth
        }
    }
    
    public init(graph: RelationshipGraph, options: GeneratorOptions = GeneratorOptions()) {
        self.graph = graph
        self.options = options
    }
    
    private func escapeDOTLabel(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "<", with: "\\<")
            .replacingOccurrences(of: ">", with: "\\>")
    }
    
    public func generate() -> String {
        var output = "digraph SwiftDiagram {\n"
        output += "    rankdir=TB;\n"
        output += "    node [shape=record, fontname=\"Helvetica\", fontsize=10];\n"
        output += "    edge [fontname=\"Helvetica\", fontsize=9];\n\n"
        
        let nodes: [RelationshipGraph.Node]
        if let focusType = options.focusType {
            nodes = Array(graph.getRelatedNodes(to: focusType, maxDepth: options.maxDepth))
        } else {
            nodes = graph.getAllNodes()
        }
        
        // Generate node definitions
        for node in nodes {
            if !options.includePrivate && node.type.accessLevel == .private {
                continue
            }
            
            output += generateNode(for: node.type)
        }
        
        // Generate relationships
        let relationships = graph.getAllRelationships()
        let nodeNames = Set(nodes.map { $0.type.name })
        
        for relationship in relationships {
            // Only include relationships between visible nodes
            if nodeNames.contains(relationship.from) && nodeNames.contains(relationship.to) {
                output += generateEdge(for: relationship)
            }
        }
        
        output += "}\n"
        return output
    }
    
    private func generateNode(for type: TypeInfo) -> String {
        var node = "    \"\(escapeDOTLabel(type.name))\" [label=\"{"
        
        // Header with type kind and name
        let stereotype = getStereotype(for: type.kind)
        node += "\(escapeDOTLabel(stereotype))\\n\(escapeDOTLabel(type.name))"
        
        // Properties section
        if options.includeProperties && !type.properties.isEmpty {
            node += "|"
            let visibleProperties = type.properties.filter { 
                options.includePrivate || $0.accessLevel != .private 
            }
            
            for (index, property) in visibleProperties.enumerated() {
                if index > 0 { node += "\\n" }
                let accessSymbol = getAccessSymbol(for: property.accessLevel)
                let staticPrefix = property.isStatic ? "static " : ""
                let letPrefix = property.isLet ? "let " : "var "
                node += "\(accessSymbol) \(staticPrefix)\(letPrefix)\(escapeDOTLabel(property.name)): \(escapeDOTLabel(property.typeName))"
            }
        }
        
        // Methods section
        if options.includeMethods && !type.methods.isEmpty {
            node += "|"
            let visibleMethods = type.methods.filter { 
                options.includePrivate || $0.accessLevel != .private 
            }
            
            for (index, method) in visibleMethods.enumerated() {
                if index > 0 { node += "\\n" }
                let accessSymbol = getAccessSymbol(for: method.accessLevel)
                let staticPrefix = method.isStatic ? "static " : ""
                let asyncPrefix = method.isAsync ? "async " : ""
                let throwsPrefix = method.`throws` ? "throws " : ""
                
                var signature = "\(accessSymbol) \(staticPrefix)\(asyncPrefix)\(throwsPrefix)\(escapeDOTLabel(method.name))("
                
                for (paramIndex, param) in method.parameters.enumerated() {
                    if paramIndex > 0 { signature += ", " }
                    if let label = param.label {
                        signature += "\(escapeDOTLabel(label)): \(escapeDOTLabel(param.typeName))"
                    } else {
                        signature += escapeDOTLabel(param.typeName)
                    }
                }
                
                signature += ")"
                
                if let returnType = method.returnType {
                    signature += " → \(escapeDOTLabel(returnType))"
                }
                
                node += signature
            }
        }
        
        node += "}\""
        
        // Add styling based on type kind
        node += ", style=filled, fillcolor=\"\(getColor(for: type.kind))\""
        
        node += "];\n"
        return node
    }
    
    private func generateEdge(for relationship: RelationshipGraph.Relationship) -> String {
        var edge = "    \"\(escapeDOTLabel(relationship.from))\" -> \"\(escapeDOTLabel(relationship.to))\""
        
        switch relationship.kind {
        case .inheritance:
            edge += " [arrowhead=empty, style=solid]"
        case .protocolConformance:
            edge += " [arrowhead=empty, style=dashed]"
        case .composition:
            edge += " [arrowhead=diamond, style=solid]"
        case .aggregation:
            edge += " [arrowhead=odiamond, style=solid]"
        case .dependency:
            edge += " [arrowhead=open, style=dashed]"
        }
        
        if let details = relationship.details {
            edge += " [label=\"\(escapeDOTLabel(details))\"]"
        }
        
        edge += ";\n"
        return edge
    }
    
    private func getStereotype(for kind: TypeKind) -> String {
        switch kind {
        case .class: return "«class»"
        case .struct: return "«struct»"
        case .protocol: return "«protocol»"
        case .enum: return "«enum»"
        case .actor: return "«actor»"
        case .extension: return "«extension»"
        }
    }
    
    private func getColor(for kind: TypeKind) -> String {
        switch kind {
        case .class: return "#E8F4FD"
        case .struct: return "#FFF4E6"
        case .protocol: return "#F3E5F5"
        case .enum: return "#E8F5E9"
        case .actor: return "#FCE4EC"
        case .extension: return "#F0F0F0"
        }
    }
    
    private func getAccessSymbol(for level: AccessLevel) -> String {
        switch level {
        case .private: return "-"
        case .fileprivate: return "~"
        case .internal: return "#"
        case .public: return "+"
        case .open: return "+"
        }
    }
}