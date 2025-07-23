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
        public let inheritanceOnly: Bool
        public let includePhantomNodes: Bool
        public let focusMode: FocusMode
        
        public enum FocusMode {
            case standard        // Include all relationship types
            case inheritance     // Focus on inheritance chains
            case composition     // Focus on composition relationships
            case protocols       // Focus on protocol relationships
        }
        
        public init(
            includePrivate: Bool = false,
            includeProperties: Bool = true,
            includeMethods: Bool = true,
            includeExtensions: Bool = false,
            focusType: String? = nil,
            maxDepth: Int = 3,
            inheritanceOnly: Bool = false,
            includePhantomNodes: Bool = true,
            focusMode: FocusMode = .standard
        ) {
            self.includePrivate = includePrivate
            self.includeProperties = includeProperties
            self.includeMethods = includeMethods
            self.includeExtensions = includeExtensions
            self.focusType = focusType
            self.maxDepth = maxDepth
            self.inheritanceOnly = inheritanceOnly
            self.includePhantomNodes = includePhantomNodes
            self.focusMode = focusMode
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
        
        let nodes: [RelationshipGraph.Node] = getFilteredNodes()
        
        // Generate node definitions
        for node in nodes {
            if !options.includePrivate && node.type.accessLevel == .private {
                continue
            }
            
            // Skip phantom nodes if not requested
            if !options.includePhantomNodes && node.type.isPhantom {
                continue
            }
            
            output += generateNode(for: node.type)
        }
        
        // Generate relationships with filtering
        let relationships = getFilteredRelationships(for: nodes)
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
    
    private func getFilteredNodes() -> [RelationshipGraph.Node] {
        if let focusType = options.focusType {
            // Use focus-specific filtering based on mode
            switch options.focusMode {
            case .standard:
                return Array(graph.getRelatedNodes(to: focusType, maxDepth: options.maxDepth))
            case .inheritance:
                return Array(graph.getInheritanceRelatedNodes(to: focusType, maxDepth: options.maxDepth, includeDescendants: true))
            case .composition:
                return Array(getCompositionRelatedNodes(to: focusType, maxDepth: options.maxDepth))
            case .protocols:
                return Array(getProtocolRelatedNodes(to: focusType, maxDepth: options.maxDepth))
            }
        } else {
            return graph.getAllNodes()
        }
    }
    
    private func getFilteredRelationships(for nodes: [RelationshipGraph.Node]) -> [RelationshipGraph.Relationship] {
        let allRelationships = graph.getAllRelationships()
        let nodeNames = Set(nodes.map { $0.type.name })
        
        var filteredRelationships: [RelationshipGraph.Relationship] = []
        
        for relationship in allRelationships {
            // Skip relationships where nodes aren't in the filtered set
            guard nodeNames.contains(relationship.from) && nodeNames.contains(relationship.to) else { continue }
            
            // Apply relationship type filtering based on mode
            if shouldIncludeRelationship(relationship, mode: options.focusMode) {
                filteredRelationships.append(relationship)
            }
        }
        
        return filteredRelationships
    }
    
    private func shouldIncludeRelationship(_ relationship: RelationshipGraph.Relationship, mode: GeneratorOptions.FocusMode) -> Bool {
        switch mode {
        case .standard:
            return true // Include all relationships
        case .inheritance:
            return isInheritanceRelationship(relationship.kind)
        case .composition:
            return isCompositionRelationship(relationship.kind)
        case .protocols:
            return isProtocolRelationship(relationship.kind)
        }
    }
    
    private func isInheritanceRelationship(_ kind: RelationshipGraph.Relationship.Kind) -> Bool {
        switch kind {
        case .inheritance, .protocolInheritance:
            return true
        default:
            return false
        }
    }
    
    private func isCompositionRelationship(_ kind: RelationshipGraph.Relationship.Kind) -> Bool {
        switch kind {
        case .composition, .aggregation, .dependency:
            return true
        default:
            return false
        }
    }
    
    private func isProtocolRelationship(_ kind: RelationshipGraph.Relationship.Kind) -> Bool {
        switch kind {
        case .protocolConformance, .implements, .protocolInheritance, .associatedType, 
             .methodRequirement, .propertyRequirement, .fulfillsRequirement, .resolveAssociatedType:
            return true
        default:
            return false
        }
    }
    
    private func getCompositionRelatedNodes(to typeName: String, maxDepth: Int) -> Set<RelationshipGraph.Node> {
        var visited = Set<String>()
        var result = Set<RelationshipGraph.Node>()
        
        func traverseComposition(from: String, depth: Int) {
            guard depth > 0, !visited.contains(from) else { return }
            visited.insert(from)
            
            if let node = graph.getNode(for: from) {
                result.insert(node)
            }
            
            // Find composition relationships
            for relationship in graph.getAllRelationships() {
                guard isCompositionRelationship(relationship.kind) else { continue }
                
                if relationship.from == from {
                    traverseComposition(from: relationship.to, depth: depth - 1)
                } else if relationship.to == from {
                    traverseComposition(from: relationship.from, depth: depth - 1)
                }
            }
        }
        
        traverseComposition(from: typeName, depth: maxDepth)
        return result
    }
    
    private func getProtocolRelatedNodes(to typeName: String, maxDepth: Int) -> Set<RelationshipGraph.Node> {
        var visited = Set<String>()
        var result = Set<RelationshipGraph.Node>()
        
        func traverseProtocol(from: String, depth: Int) {
            guard depth > 0, !visited.contains(from) else { return }
            visited.insert(from)
            
            if let node = graph.getNode(for: from) {
                result.insert(node)
            }
            
            // Find protocol relationships
            for relationship in graph.getAllRelationships() {
                guard isProtocolRelationship(relationship.kind) else { continue }
                
                if relationship.from == from {
                    traverseProtocol(from: relationship.to, depth: depth - 1)
                } else if relationship.to == from {
                    traverseProtocol(from: relationship.from, depth: depth - 1)
                }
            }
        }
        
        traverseProtocol(from: typeName, depth: maxDepth)
        return result
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
        case .implements:
            edge += " [arrowhead=empty, style=dashed, color=blue]"
        case .protocolInheritance:
            edge += " [arrowhead=empty, style=solid, color=purple]"
        case .injection:
            edge += " [arrowhead=open, style=dotted, color=green]"
        case .fulfillsRequirement:
            edge += " [arrowhead=normal, style=solid, color=orange]"
        case .genericParameter:
            edge += " [arrowhead=diamond, style=solid, color=red]"
        case .genericConstraint:
            edge += " [arrowhead=open, style=dashed, color=red]"
        case .wrappedBy:
            edge += " [arrowhead=box, style=solid, color=magenta]"
        case .elementType:
            edge += " [arrowhead=normal, style=solid, color=cyan]"
        case .associatedType:
            edge += " [arrowhead=open, style=dashed, color=purple]"
        case .typeConstraint:
            edge += " [arrowhead=normal, style=dotted, color=purple]"
        case .methodRequirement:
            edge += " [arrowhead=open, style=solid, color=brown]"
        case .propertyRequirement:
            edge += " [arrowhead=diamond, style=solid, color=brown]"
        case .resolveAssociatedType:
            edge += " [arrowhead=normal, style=dashed, color=gold]"
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