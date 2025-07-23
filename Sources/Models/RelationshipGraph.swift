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
            
            // Protocol-specific relationships
            case implements = "implements"
            case protocolInheritance = "extends"
            case injection = "injected"
            case fulfillsRequirement = "fulfills"
            
            // Deep type relationships
            case genericParameter = "generic_param"
            case genericConstraint = "generic_constraint"
            case wrappedBy = "wrapped_by"
            case elementType = "element_type"
            
            // Protocol internal structure
            case associatedType = "associated_type"
            case typeConstraint = "constrained_by"
            case methodRequirement = "requires_method"
            case propertyRequirement = "requires_property"
            case resolveAssociatedType = "resolves_type"
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
        // Handle extension merging into existing types
        if let existingNode = nodes[type.name] {
            if type.kind == .extension && (existingNode.type.kind == .class || existingNode.type.kind == .struct) {
                // Merge extension into existing class/struct
                let mergedType = mergeExtensionIntoType(baseType: existingNode.type, extension: type)
                let mergedNode = Node(type: mergedType)
                nodes[type.name] = mergedNode
                addTypeRelationships(mergedType)
                return
            } else if (type.kind == .class || type.kind == .struct) && existingNode.type.kind == .extension {
                // Merge existing extension into new class/struct
                let mergedType = mergeExtensionIntoType(baseType: type, extension: existingNode.type)
                let mergedNode = Node(type: mergedType)
                nodes[type.name] = mergedNode
                addTypeRelationships(mergedType)
                return
            }
        }
        
        let node = Node(type: type)
        nodes[type.name] = node
        addTypeRelationships(type)
    }
    
    private func addTypeRelationships(_ type: TypeInfo) {
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
    
    private func mergeExtensionIntoType(baseType: TypeInfo, extension extensionType: TypeInfo) -> TypeInfo {
        // Combine protocol conformances
        let combinedProtocols = baseType.conformedProtocols.union(extensionType.conformedProtocols)
        
        // Combine methods (extension methods are added to base type methods)
        let combinedMethods = baseType.methods + extensionType.methods
        
        // Combine properties - extensions can add computed properties
        let combinedProperties = baseType.properties + extensionType.properties
        
        // Combine other arrays
        let combinedInitializers = baseType.initializers + extensionType.initializers
        let combinedSubscripts = baseType.subscripts + extensionType.subscripts
        let combinedTypeAliases = baseType.typeAliases + extensionType.typeAliases
        let combinedNestedTypes = baseType.nestedTypes + extensionType.nestedTypes
        let combinedAssociatedTypes = baseType.associatedTypes + extensionType.associatedTypes
        let combinedProtocolRequirements = baseType.protocolRequirements + extensionType.protocolRequirements
        let combinedGenericParameters = baseType.genericParameters + extensionType.genericParameters
        let combinedGenericConstraints = baseType.genericConstraints + extensionType.genericConstraints
        let combinedAttributes = baseType.attributes + extensionType.attributes
        
        return TypeInfo(
            name: baseType.name,
            kind: baseType.kind, // Keep base type kind (class, struct, etc.)
            moduleName: baseType.moduleName,
            accessLevel: baseType.accessLevel,
            inheritedTypes: baseType.inheritedTypes, // Extensions don't add inheritance
            conformedProtocols: combinedProtocols,
            properties: combinedProperties, // Now includes computed properties from extensions
            methods: combinedMethods,
            initializers: combinedInitializers,
            subscripts: combinedSubscripts,
            typeAliases: combinedTypeAliases,
            nestedTypes: combinedNestedTypes,
            associatedTypes: combinedAssociatedTypes,
            protocolRequirements: combinedProtocolRequirements,
            genericParameters: combinedGenericParameters,
            genericConstraints: combinedGenericConstraints,
            attributes: combinedAttributes,
            location: baseType.location // Keep base type location
        )
    }
    
    public func addRelationship(from: String, to: String, kind: Relationship.Kind, details: String? = nil) {
        let relationship = Relationship(from: from, to: to, kind: kind, details: details)
        relationships.insert(relationship)
        
        // Ensure both 'from' and 'to' nodes exist, create phantom nodes if necessary
        ensureNodeExists(typeName: from, context: .source)
        ensureNodeExists(typeName: to, context: .target, relationshipKind: kind)
        
        if var node = nodes[from] {
            node.relationships.insert(relationship)
            nodes[from] = node
        }
    }
    
    private enum NodeContext {
        case source
        case target
    }
    
    private func ensureNodeExists(typeName: String, context: NodeContext, relationshipKind: Relationship.Kind? = nil) {
        // If node already exists, nothing to do
        if nodes[typeName] != nil {
            return
        }
        
        // For source nodes, we should have the actual type - this might indicate a bug
        if context == .source {
            // Log warning but don't create phantom for source nodes
            return
        }
        
        // For target nodes, create phantom nodes for external types
        if context == .target {
            createPhantomNode(for: typeName, relationshipKind: relationshipKind)
        }
    }
    
    private func createPhantomNode(for typeName: String, relationshipKind: Relationship.Kind? = nil) {
        // Classify the type and create an appropriate phantom node
        let (kind, moduleName) = classifyExternalType(typeName)
        
        let phantomType = TypeInfo(
            name: typeName,
            kind: kind,
            moduleName: moduleName,
            accessLevel: .public, // External types are typically public
            location: SourceLocation(file: "<external>", line: 0, column: 0),
            isPhantom: true
        )
        
        let phantomNode = Node(type: phantomType)
        nodes[typeName] = phantomNode
        
        // Create inheritance chains for framework types
        createFrameworkInheritanceChain(for: typeName, kind: kind, moduleName: moduleName)
    }
    
    private func createFrameworkInheritanceChain(for typeName: String, kind: TypeKind, moduleName: String?) {
        // Create inheritance relationships for well-known framework hierarchies
        guard kind == .class else { return } // Only classes have inheritance
        
        let inheritance = getInheritanceChain(for: typeName)
        for (index, parentType) in inheritance.enumerated() {
            // Create phantom node for parent if it doesn't exist
            if nodes[parentType] == nil {
                let (parentKind, parentModule) = classifyExternalType(parentType)
                let parentPhantomType = TypeInfo(
                    name: parentType,
                    kind: parentKind,
                    moduleName: parentModule,
                    accessLevel: .public,
                    location: SourceLocation(file: "<external>", line: 0, column: 0),
                    isPhantom: true
                )
                let parentPhantomNode = Node(type: parentPhantomType)
                nodes[parentType] = parentPhantomNode
            }
            
            // Create inheritance relationship
            let fromType = index == 0 ? typeName : inheritance[index - 1]
            addRelationship(
                from: fromType,
                to: parentType,
                kind: .inheritance,
                details: "framework inheritance chain"
            )
        }
    }
    
    private func getInheritanceChain(for typeName: String) -> [String] {
        // Define inheritance hierarchies for common framework types
        switch typeName {
        // UIKit View Controller hierarchy
        case "UIViewController":
            return ["UIResponder", "NSObject"]
        case "UINavigationController", "UITabBarController", "UISplitViewController", 
             "UIPageViewController", "UISearchController", "UIAlertController":
            return ["UIViewController", "UIResponder", "NSObject"]
        case "UITableViewController", "UICollectionViewController":
            return ["UIViewController", "UIResponder", "NSObject"]
            
        // UIKit View hierarchy
        case "UIView":
            return ["UIResponder", "NSObject"]
        case "UIScrollView":
            return ["UIView", "UIResponder", "NSObject"]
        case "UITableView", "UICollectionView", "UITextView":
            return ["UIScrollView", "UIView", "UIResponder", "NSObject"]
        case "UIStackView", "UIImageView", "UILabel":
            return ["UIView", "UIResponder", "NSObject"]
            
        // UIKit Control hierarchy
        case "UIControl":
            return ["UIView", "UIResponder", "NSObject"]
        case "UIButton", "UITextField", "UISwitch", "UISlider", "UIProgressView", 
             "UIActivityIndicatorView", "UIPickerView", "UIDatePicker", 
             "UISegmentedControl", "UIStepper":
            return ["UIControl", "UIView", "UIResponder", "NSObject"]
            
        // UIKit Navigation and Bar hierarchy
        case "UINavigationBar", "UITabBar", "UIToolbar", "UISearchBar":
            return ["UIView", "UIResponder", "NSObject"]
            
        // UIKit Application hierarchy
        case "UIApplication":
            return ["UIResponder", "NSObject"]
        case "UIWindow":
            return ["UIView", "UIResponder", "NSObject"]
        case "UIScene", "UIWindowScene":
            return ["UIResponder", "NSObject"]
            
        // UIKit Gesture Recognizers
        case let name where name.contains("GestureRecognizer"):
            return ["NSObject"]
            
        // Foundation NSObject hierarchy
        case let name where name.hasPrefix("NS") && name != "NSObject":
            return ["NSObject"]
            
        // Core Data hierarchy
        case "NSManagedObject":
            return ["NSObject"]
        case "NSManagedObjectContext", "NSPersistentContainer":
            return ["NSObject"]
            
        // Dispatch hierarchy
        case "DispatchQueue", "DispatchGroup", "DispatchSemaphore":
            return ["NSObject"]
            
        // Combine hierarchy
        case "AnyCancellable", "PassthroughSubject", "CurrentValueSubject":
            return ["NSObject"]
            
        default:
            // Default inheritance for unknown classes
            if typeName.hasPrefix("UI") {
                return ["UIResponder", "NSObject"]
            } else if typeName.hasPrefix("NS") && typeName != "NSObject" {
                return ["NSObject"]
            }
            return []
        }
    }
    
    private func classifyExternalType(_ typeName: String) -> (TypeKind, String?) {
        // Framework classification with comprehensive inheritance hierarchies
        switch typeName {
        // UIKit inheritance hierarchies
        case let name where name.hasPrefix("UI"):
            return getUIKitTypeClassification(name)
            
        // Core Graphics types
        case "CGFloat", "CGPoint", "CGSize", "CGRect", "CGColor", "CGPath", "CGImage", "CGContext":
            return (.struct, "CoreGraphics")
            
        // Foundation types with inheritance
        case let name where name.hasPrefix("NS"):
            return getFoundationTypeClassification(name)
        case "Data", "Date", "URL", "UUID", "Bundle", "FileManager", "URLSession", "URLCache":
            return (.struct, "Foundation")
        case "DispatchQueue", "DispatchGroup", "DispatchSemaphore":
            return (.class, "Dispatch")
            
        // Swift Standard Library types
        case "String", "Int", "Double", "Float", "Bool", "Character":
            return (.struct, "Swift")
        case "Array", "Dictionary", "Set", "Optional", "Result":
            return (.struct, "Swift")
            
        // SwiftUI types with more comprehensive coverage
        case "Published", "State", "StateObject", "ObservedObject", "EnvironmentObject", "Binding":
            return (.struct, "SwiftUI")
        case "ObservableObject", "View", "App", "Scene", "PreferenceKey":
            return (.protocol, "SwiftUI")
        case let name where name.hasPrefix("V") && name.contains("Stack"):
            return (.struct, "SwiftUI") // VStack, HStack, ZStack
            
        // Combine types
        case "AnyCancellable", "PassthroughSubject", "CurrentValueSubject":
            return (.class, "Combine")
        case "Publisher", "Subscriber", "Cancellable":
            return (.protocol, "Combine")
            
        // Core Data types
        case let name where name.hasPrefix("NS") && name.contains("Core"):
            return (.class, "CoreData")
        case "NSManagedObject", "NSManagedObjectContext", "NSPersistentContainer":
            return (.class, "CoreData")
            
        // Common protocols
        case "Codable", "Equatable", "Hashable", "Comparable", "CustomStringConvertible":
            return (.protocol, "Swift")
        case "Identifiable", "Sendable", "AnyObject":
            return (.protocol, "Swift")
            
        // Default classification based on naming conventions
        default:
            // If it ends with "Protocol" or "able", likely a protocol
            if typeName.hasSuffix("Protocol") || typeName.hasSuffix("able") || typeName.hasSuffix("Delegate") {
                return (.protocol, nil)
            }
            // If it starts with uppercase, likely a class or struct
            if typeName.first?.isUppercase == true {
                return (.class, nil)
            }
            // Fallback
            return (.struct, nil)
        }
    }
    
    private func getUIKitTypeClassification(_ typeName: String) -> (TypeKind, String?) {
        // Comprehensive UIKit type classification with inheritance awareness
        switch typeName {
        // View Controllers
        case "UIViewController", "UINavigationController", "UITabBarController", 
             "UITableViewController", "UICollectionViewController", "UISplitViewController",
             "UIPageViewController", "UISearchController", "UIAlertController":
            return (.class, "UIKit")
            
        // Views
        case "UIView", "UIScrollView", "UITableView", "UICollectionView", 
             "UIStackView", "UIImageView", "UILabel", "UIButton", "UITextField", 
             "UITextView", "UISwitch", "UISlider", "UIProgressView", "UIActivityIndicatorView",
             "UIPickerView", "UIDatePicker", "UISegmentedControl", "UIStepper":
            return (.class, "UIKit")
            
        // Controls and Bars
        case "UIControl", "UINavigationBar", "UITabBar", "UIToolbar", "UISearchBar":
            return (.class, "UIKit")
            
        // Layout and Constraints
        case "NSLayoutConstraint", "UILayoutGuide":
            return (.class, "UIKit")
            
        // Application and Window
        case "UIApplication", "UIWindow", "UIScene", "UIWindowScene":
            return (.class, "UIKit")
            
        // Gesture Recognizers
        case let name where name.contains("GestureRecognizer"):
            return (.class, "UIKit")
            
        // Data Sources and Delegates (Protocols)
        case let name where name.contains("DataSource") || name.contains("Delegate"):
            return (.protocol, "UIKit")
            
        // Other UIKit classes
        case let name where name.hasPrefix("UI"):
            return (.class, "UIKit")
            
        default:
            return (.class, "UIKit")
        }
    }
    
    private func getFoundationTypeClassification(_ typeName: String) -> (TypeKind, String?) {
        // Comprehensive Foundation type classification
        switch typeName {
        case "NSObject":
            return (.class, "Foundation") // Root class
        case "NSString", "NSArray", "NSDictionary", "NSSet", "NSMutableString", 
             "NSMutableArray", "NSMutableDictionary", "NSMutableSet":
            return (.class, "Foundation")
        case "NSNumber", "NSDecimalNumber", "NSDate", "NSURL", "NSData", "NSMutableData":
            return (.class, "Foundation")
        case "NSNotificationCenter", "NSUserDefaults", "NSBundle", "NSFileManager":
            return (.class, "Foundation")
        case "NSURLSession", "NSURLRequest", "NSMutableURLRequest", "NSURLResponse":
            return (.class, "Foundation")
        case "NSError", "NSException":
            return (.class, "Foundation")
        case "NSThread", "NSOperation", "NSOperationQueue", "NSTimer":
            return (.class, "Foundation")
        case let name where name.hasPrefix("NS"):
            return (.class, "Foundation")
        default:
            return (.class, "Foundation")
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
        
        func traverse(from: String, depth: Int, relationshipPath: [Relationship.Kind] = []) {
            guard depth > 0, !visited.contains(from) else { return }
            visited.insert(from)
            
            if let node = nodes[from] {
                result.insert(node)
            }
            
            // Find all relationships involving this type with priority-based traversal
            let relevantRelationships = getRelevantRelationships(for: from, relationshipPath: relationshipPath)
            
            for (relationship, newDepth) in relevantRelationships {
                let nextType: String
                let newPath: [Relationship.Kind]
                
                if relationship.from == from {
                    nextType = relationship.to
                    newPath = relationshipPath + [relationship.kind]
                } else {
                    nextType = relationship.from
                    newPath = relationshipPath + [relationship.kind]
                }
                
                traverse(from: nextType, depth: newDepth, relationshipPath: newPath)
            }
        }
        
        traverse(from: typeName, depth: maxDepth)
        return result
    }
    
    private func getRelevantRelationships(for typeName: String, relationshipPath: [Relationship.Kind]) -> [(Relationship, Int)] {
        var relevantRelationships: [(Relationship, Int)] = []
        
        for relationship in relationships {
            guard relationship.from == typeName || relationship.to == typeName else { continue }
            
            // Calculate depth consumption based on relationship type and current path
            let depthCost = calculateRelationshipDepthCost(
                relationship.kind,
                currentPath: relationshipPath
            )
            
            relevantRelationships.append((relationship, depthCost))
        }
        
        // Sort by priority to follow inheritance chains first
        relevantRelationships.sort { first, second in
            let firstPriority = getRelationshipPriority(first.0.kind, currentPath: relationshipPath)
            let secondPriority = getRelationshipPriority(second.0.kind, currentPath: relationshipPath)
            return firstPriority > secondPriority
        }
        
        return relevantRelationships
    }
    
    private func calculateRelationshipDepthCost(_ relationshipKind: Relationship.Kind, currentPath: [Relationship.Kind]) -> Int {
        // Inheritance relationships consume less depth to follow complete chains
        switch relationshipKind {
        case .inheritance, .protocolInheritance:
            return 1 // Lower cost for inheritance chains
        case .protocolConformance, .implements:
            return 1 // Protocol relationships are important
        case .genericParameter, .genericConstraint, .associatedType:
            return 1 // Type relationships are important
        case .dependency, .composition, .aggregation:
            return 2 // Composition relationships consume more depth
        case .injection, .wrappedBy, .elementType:
            return 2 // Higher-level relationships
        default:
            return 2 // Default depth cost
        }
    }
    
    private func getRelationshipPriority(_ relationshipKind: Relationship.Kind, currentPath: [Relationship.Kind]) -> Int {
        // Higher priority means it will be followed first
        switch relationshipKind {
        case .inheritance:
            return 100 // Highest priority for inheritance chains
        case .protocolInheritance:
            return 95 // Protocol inheritance
        case .protocolConformance, .implements:
            return 90 // Protocol conformance
        case .associatedType, .resolveAssociatedType:
            return 85 // Associated type relationships
        case .genericParameter, .genericConstraint:
            return 80 // Generic relationships
        case .composition:
            return 70 // Strong composition
        case .aggregation:
            return 65 // Weaker composition
        case .dependency:
            return 60 // Dependencies
        case .injection:
            return 55 // Dependency injection
        case .wrappedBy, .elementType:
            return 50 // Wrapper relationships
        case .typeConstraint, .fulfillsRequirement:
            return 45 // Constraint relationships
        case .methodRequirement, .propertyRequirement:
            return 40 // Protocol requirements
        }
    }
    
    // Enhanced method for inheritance-focused filtering
    public func getInheritanceRelatedNodes(to typeName: String, maxDepth: Int = 3, includeDescendants: Bool = true) -> Set<Node> {
        var visited = Set<String>()
        var result = Set<Node>()
        
        func traverseInheritance(from: String, depth: Int, direction: InheritanceDirection) {
            guard depth > 0, !visited.contains(from) else { return }
            visited.insert(from)
            
            if let node = nodes[from] {
                result.insert(node)
            }
            
            // Find inheritance relationships
            for relationship in relationships {
                guard isInheritanceRelationship(relationship.kind) else { continue }
                
                switch direction {
                case .ancestors:
                    if relationship.from == from {
                        traverseInheritance(from: relationship.to, depth: depth - 1, direction: direction)
                    }
                case .descendants:
                    if relationship.to == from {
                        traverseInheritance(from: relationship.from, depth: depth - 1, direction: direction)
                    }
                case .both:
                    if relationship.from == from {
                        traverseInheritance(from: relationship.to, depth: depth - 1, direction: direction)
                    } else if relationship.to == from {
                        traverseInheritance(from: relationship.from, depth: depth - 1, direction: direction)
                    }
                }
            }
        }
        
        let direction: InheritanceDirection = includeDescendants ? .both : .ancestors
        traverseInheritance(from: typeName, depth: maxDepth, direction: direction)
        return result
    }
    
    private enum InheritanceDirection {
        case ancestors   // Follow inheritance up (parents)
        case descendants // Follow inheritance down (children)
        case both        // Follow both directions
    }
    
    private func isInheritanceRelationship(_ kind: Relationship.Kind) -> Bool {
        switch kind {
        case .inheritance, .protocolInheritance, .protocolConformance, .implements:
            return true
        default:
            return false
        }
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
    
    // MARK: - Protocol Analysis Methods
    
    public func analyzeProtocolRelationships() {
        detectProtocolImplementations()
        analyzeProtocolProperties()
        mapDependencyInjection()
    }
    
    private func detectProtocolImplementations() {
        let protocols = nodes.values.filter { $0.type.kind == .protocol }
        let concreteTypes = nodes.values.filter { $0.type.kind == .class || $0.type.kind == .struct }
        
        for protocolNode in protocols {
            for concreteType in concreteTypes {
                if concreteType.type.conformedProtocols.contains(protocolNode.type.name) {
                    addRelationship(
                        from: concreteType.type.name,
                        to: protocolNode.type.name,
                        kind: .implements,
                        details: "implements protocol"
                    )
                }
            }
        }
    }
    
    private func analyzeProtocolProperties() {
        for node in nodes.values {
            for property in node.type.properties {
                let typeName = extractTypeName(from: property.typeName)
                
                // Check if property type is a protocol
                if isProtocolType(typeName) {
                    // Find concrete implementations of this protocol
                    let implementations = findProtocolImplementations(protocolName: typeName)
                    
                    for implementation in implementations {
                        addRelationship(
                            from: node.type.name,
                            to: implementation,
                            kind: .injection,
                            details: "property \(property.name) injects \(typeName)"
                        )
                    }
                }
            }
        }
    }
    
    private func mapDependencyInjection() {
        // Analyze initializer parameters for dependency injection patterns
        for node in nodes.values {
            for initializer in node.type.initializers {
                for parameter in initializer.parameters {
                    let typeName = extractTypeName(from: parameter.typeName)
                    
                    if isProtocolType(typeName) {
                        let implementations = findProtocolImplementations(protocolName: typeName)
                        
                        for implementation in implementations {
                            addRelationship(
                                from: node.type.name,
                                to: implementation,
                                kind: .injection,
                                details: "initializer parameter \(parameter.name) injects \(typeName)"
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func isProtocolType(_ typeName: String) -> Bool {
        // Check if type exists as a protocol in our graph
        if let node = nodes[typeName], node.type.kind == .protocol {
            return true
        }
        
        // Check against known protocol patterns
        return isKnownProtocol(typeName)
    }
    
    private func isKnownProtocol(_ typeName: String) -> Bool {
        let knownProtocols = [
            // Swift Standard Library Protocols
            "Codable", "Equatable", "Hashable", "Comparable", "CustomStringConvertible",
            "ExpressibleByStringLiteral", "ExpressibleByArrayLiteral", "ExpressibleByDictionaryLiteral",
            "Identifiable", "Sendable", "AnyObject",
            
            // SwiftUI Protocols
            "ObservableObject", "View", "App", "Scene", "PreferenceKey",
            
            // Combine Protocols
            "Publisher", "Subscriber", "Cancellable",
            
            // Common naming patterns
        ]
        
        if knownProtocols.contains(typeName) {
            return true
        }
        
        // Protocol naming conventions
        return typeName.hasSuffix("Protocol") || 
               typeName.hasSuffix("Delegate") || 
               typeName.hasSuffix("DataSource") ||
               typeName.hasSuffix("able") ||
               typeName.hasSuffix("ing")
    }
    
    private func findProtocolImplementations(protocolName: String) -> [String] {
        var implementations: [String] = []
        
        for node in nodes.values {
            if (node.type.kind == .class || node.type.kind == .struct || node.type.kind == .actor) &&
               node.type.conformedProtocols.contains(protocolName) {
                implementations.append(node.type.name)
            }
        }
        
        return implementations
    }
    
    // MARK: - Deep Type Analysis Methods
    
    public func analyzeDeepTypeRelationships() {
        analyzeGenericTypes()
        analyzeCollectionTypes()
        analyzePropertyWrappers()
        analyzeComplexTypes()
    }
    
    private func analyzeGenericTypes() {
        for node in nodes.values {
            // Analyze properties for generic types
            for property in node.type.properties {
                analyzeTypeForGenerics(
                    typeName: property.typeName,
                    fromType: node.type.name,
                    context: "property \(property.name)"
                )
            }
            
            // Analyze method parameters and return types
            for method in node.type.methods {
                for parameter in method.parameters {
                    analyzeTypeForGenerics(
                        typeName: parameter.typeName,
                        fromType: node.type.name,
                        context: "method \(method.name) parameter \(parameter.name)"
                    )
                }
                
                if let returnType = method.returnType {
                    analyzeTypeForGenerics(
                        typeName: returnType,
                        fromType: node.type.name,
                        context: "method \(method.name) return"
                    )
                }
            }
        }
    }
    
    private func analyzeTypeForGenerics(typeName: String, fromType: String, context: String) {
        // Parse generic types like "PostCache<Post>", "Dictionary<String, User>", etc.
        if let genericMatch = parseGenericType(typeName) {
            let baseType = genericMatch.baseType
            let parameters = genericMatch.parameters
            
            // Create relationship to base generic type
            addRelationship(
                from: fromType,
                to: baseType,
                kind: .dependency,
                details: "\(context) uses generic \(baseType)"
            )
            
            // Create relationships to generic parameters
            for (index, parameter) in parameters.enumerated() {
                let cleanParam = extractTypeName(from: parameter)
                if isCustomType(cleanParam) {
                    addRelationship(
                        from: fromType,
                        to: cleanParam,
                        kind: .genericParameter,
                        details: "\(context) generic parameter \(index): \(cleanParam)"
                    )
                }
            }
        }
    }
    
    private func analyzeCollectionTypes() {
        for node in nodes.values {
            for property in node.type.properties {
                analyzeTypeForCollections(
                    typeName: property.typeName,
                    fromType: node.type.name,
                    context: "property \(property.name)"
                )
            }
        }
    }
    
    private func analyzeTypeForCollections(typeName: String, fromType: String, context: String) {
        // Parse collection types like "[Post]", "[String: User]", "Set<Tag>", etc.
        if let collectionMatch = parseCollectionType(typeName) {
            let collectionType = collectionMatch.collectionType
            let elementTypes = collectionMatch.elementTypes
            
            // Create relationship to collection type
            addRelationship(
                from: fromType,
                to: collectionType,
                kind: .dependency,
                details: "\(context) uses collection \(collectionType)"
            )
            
            // Create relationships to element types
            for elementType in elementTypes {
                let cleanElement = extractTypeName(from: elementType)
                if isCustomType(cleanElement) {
                    addRelationship(
                        from: fromType,
                        to: cleanElement,
                        kind: .elementType,
                        details: "\(context) contains \(cleanElement)"
                    )
                }
            }
        }
    }
    
    private func analyzePropertyWrappers() {
        for node in nodes.values {
            for property in node.type.properties {
                analyzePropertyForWrappers(
                    property: property,
                    fromType: node.type.name
                )
            }
        }
    }
    
    private func analyzePropertyForWrappers(property: PropertyInfo, fromType: String) {
        // Analyze property wrapper attributes like @Published, @State, etc.
        for attribute in property.attributes {
            if isPropertyWrapper(attribute.name) {
                // Create wrapper relationship
                addRelationship(
                    from: fromType,
                    to: attribute.name,
                    kind: .wrappedBy,
                    details: "property \(property.name) wrapped by \(attribute.name)"
                )
                
                // Analyze the wrapped type for nested relationships
                analyzeTypeForGenerics(
                    typeName: property.typeName,
                    fromType: fromType,
                    context: "@\(attribute.name) property \(property.name)"
                )
                
                analyzeTypeForCollections(
                    typeName: property.typeName,
                    fromType: fromType,
                    context: "@\(attribute.name) property \(property.name)"
                )
            }
        }
    }
    
    private func analyzeComplexTypes() {
        // Analyze closures, tuples, and other complex type expressions
        for node in nodes.values {
            for method in node.type.methods {
                for parameter in method.parameters {
                    analyzeComplexType(
                        typeName: parameter.typeName,
                        fromType: node.type.name,
                        context: "method \(method.name) parameter \(parameter.name)"
                    )
                }
            }
        }
    }
    
    private func analyzeComplexType(typeName: String, fromType: String, context: String) {
        // Handle closures like "(String) -> User"
        if let closureMatch = parseClosureType(typeName) {
            for paramType in closureMatch.parameterTypes {
                let cleanParam = extractTypeName(from: paramType)
                if isCustomType(cleanParam) {
                    addRelationship(
                        from: fromType,
                        to: cleanParam,
                        kind: .dependency,
                        details: "\(context) closure parameter \(cleanParam)"
                    )
                }
            }
            
            if let returnType = closureMatch.returnType {
                let cleanReturn = extractTypeName(from: returnType)
                if isCustomType(cleanReturn) {
                    addRelationship(
                        from: fromType,
                        to: cleanReturn,
                        kind: .dependency,
                        details: "\(context) closure return \(cleanReturn)"
                    )
                }
            }
        }
    }
    
    // MARK: - Type Parsing Helper Methods
    
    private struct GenericMatch {
        let baseType: String
        let parameters: [String]
    }
    
    private struct CollectionMatch {
        let collectionType: String
        let elementTypes: [String]
    }
    
    private struct ClosureMatch {
        let parameterTypes: [String]
        let returnType: String?
    }
    
    private func parseGenericType(_ typeName: String) -> GenericMatch? {
        // Parse "PostCache<Post>" or "Dictionary<String, User>"
        guard let startIndex = typeName.firstIndex(of: "<"),
              let endIndex = typeName.lastIndex(of: ">") else {
            return nil
        }
        
        let baseType = String(typeName[..<startIndex])
        let parametersString = String(typeName[typeName.index(after: startIndex)..<endIndex])
        let parameters = parseTypeParameters(parametersString)
        
        return GenericMatch(baseType: baseType, parameters: parameters)
    }
    
    private func parseCollectionType(_ typeName: String) -> CollectionMatch? {
        // Parse "[Post]" (Array), "[String: User]" (Dictionary), "Set<Tag>" (Set)
        if typeName.hasPrefix("[") && typeName.hasSuffix("]") {
            // Array syntax [ElementType]
            let inner = String(typeName.dropFirst().dropLast())
            if inner.contains(":") {
                // Dictionary [Key: Value]
                let parts = inner.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                return CollectionMatch(collectionType: "Dictionary", elementTypes: parts)
            } else {
                // Array [Element]
                return CollectionMatch(collectionType: "Array", elementTypes: [inner])
            }
        } else if let genericMatch = parseGenericType(typeName) {
            // Set<Element>, etc.
            let baseType = genericMatch.baseType
            if ["Set", "Array", "Dictionary"].contains(baseType) {
                return CollectionMatch(collectionType: baseType, elementTypes: genericMatch.parameters)
            }
        }
        
        return nil
    }
    
    private func parseClosureType(_ typeName: String) -> ClosureMatch? {
        // Parse "(String, Int) -> User" or "() -> Void"
        guard typeName.contains("->") else {
            return nil
        }
        
        let parts = typeName.split(separator: "->", maxSplits: 1)
        guard parts.count == 2 else {
            return nil
        }
        
        let paramPart = parts[0].trimmingCharacters(in: .whitespaces)
        let returnPart = parts[1].trimmingCharacters(in: .whitespaces)
        
        // Parse parameters "(String, Int)" or "()"
        var parameterTypes: [String] = []
        if paramPart.hasPrefix("(") && paramPart.hasSuffix(")") {
            let inner = String(paramPart.dropFirst().dropLast())
            if !inner.isEmpty {
                parameterTypes = parseTypeParameters(inner)
            }
        }
        
        let returnType = returnPart == "Void" ? nil : returnPart
        
        return ClosureMatch(parameterTypes: parameterTypes, returnType: returnType)
    }
    
    private func parseTypeParameters(_ parametersString: String) -> [String] {
        // Parse "String, User" or "String, Dictionary<String, User>" with proper nesting
        var parameters: [String] = []
        var current = ""
        var depth = 0
        
        for char in parametersString {
            if char == "<" || char == "(" || char == "[" {
                depth += 1
                current.append(char)
            } else if char == ">" || char == ")" || char == "]" {
                depth -= 1
                current.append(char)
            } else if char == "," && depth == 0 {
                parameters.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            parameters.append(current.trimmingCharacters(in: .whitespaces))
        }
        
        return parameters
    }
    
    private func isPropertyWrapper(_ attributeName: String) -> Bool {
        let propertyWrappers = [
            "Published", "State", "StateObject", "ObservedObject", "EnvironmentObject",
            "Binding", "Environment", "AppStorage", "SceneStorage",
            "FetchRequest", "SectionedFetchRequest",
            "GestureState", "FocusState"
        ]
        return propertyWrappers.contains(attributeName)
    }
    
    // MARK: - Protocol Internal Structure Analysis
    
    public func analyzeProtocolInternalStructure() {
        analyzeAssociatedTypes()
        analyzeProtocolRequirements()
        mapProtocolImplementationDetails()
    }
    
    private func analyzeAssociatedTypes() {
        let protocolNodes = nodes.values.filter { $0.type.kind == .protocol }
        
        for protocolNode in protocolNodes {
            for associatedType in protocolNode.type.associatedTypes {
                // Create associated type relationship
                addRelationship(
                    from: protocolNode.type.name,
                    to: associatedType.name,
                    kind: .associatedType,
                    details: "associated type \(associatedType.name)"
                )
                
                // Add type constraints
                if let inheritedType = associatedType.inheritedType {
                    let cleanType = extractTypeName(from: inheritedType)
                    addRelationship(
                        from: associatedType.name,
                        to: cleanType,
                        kind: .typeConstraint,
                        details: "constrained to \(cleanType)"
                    )
                }
                
                // Add default type relationships
                if let defaultType = associatedType.defaultType {
                    let cleanType = extractTypeName(from: defaultType)
                    addRelationship(
                        from: associatedType.name,
                        to: cleanType,
                        kind: .resolveAssociatedType,
                        details: "defaults to \(cleanType)"
                    )
                }
            }
        }
    }
    
    private func analyzeProtocolRequirements() {
        let protocolNodes = nodes.values.filter { $0.type.kind == .protocol }
        
        for protocolNode in protocolNodes {
            // Analyze property requirements
            for property in protocolNode.type.properties {
                addRelationship(
                    from: protocolNode.type.name,
                    to: property.typeName,
                    kind: .propertyRequirement,
                    details: "requires property \(property.name): \(property.typeName)"
                )
            }
            
            // Analyze method requirements
            for method in protocolNode.type.methods {
                // Add relationships for parameter types
                for parameter in method.parameters {
                    let cleanType = extractTypeName(from: parameter.typeName)
                    if isCustomType(cleanType) {
                        addRelationship(
                            from: protocolNode.type.name,
                            to: cleanType,
                            kind: .methodRequirement,
                            details: "method \(method.name) requires \(cleanType)"
                        )
                    }
                }
                
                // Add relationships for return types
                if let returnType = method.returnType {
                    let cleanType = extractTypeName(from: returnType)
                    if isCustomType(cleanType) {
                        addRelationship(
                            from: protocolNode.type.name,
                            to: cleanType,
                            kind: .methodRequirement,
                            details: "method \(method.name) returns \(cleanType)"
                        )
                    }
                }
            }
            
            // Analyze protocol requirements from protocolRequirements array
            for requirement in protocolNode.type.protocolRequirements {
                addRelationship(
                    from: protocolNode.type.name,
                    to: requirement.name,
                    kind: requirement.kind == .property ? .propertyRequirement : .methodRequirement,
                    details: "requires \(requirement.kind.rawValue) \(requirement.name)"
                )
            }
        }
    }
    
    private func mapProtocolImplementationDetails() {
        let protocolNodes = nodes.values.filter { $0.type.kind == .protocol }
        let concreteNodes = nodes.values.filter { $0.type.kind == .class || $0.type.kind == .struct || $0.type.kind == .actor }
        
        for protocolNode in protocolNodes {
            for concreteNode in concreteNodes {
                if concreteNode.type.conformedProtocols.contains(protocolNode.type.name) {
                    // Map how associated types are resolved in implementations
                    mapAssociatedTypeResolutions(
                        protocol: protocolNode.type,
                        implementation: concreteNode.type
                    )
                    
                    // Map how protocol requirements are fulfilled
                    mapRequirementFulfillment(
                        protocol: protocolNode.type,
                        implementation: concreteNode.type
                    )
                }
            }
        }
    }
    
    private func mapAssociatedTypeResolutions(protocol protocolType: TypeInfo, implementation: TypeInfo) {
        // Analyze how associated types are resolved in concrete implementations
        for associatedType in protocolType.associatedTypes {
            // Look for type aliases that resolve associated types
            for typeAlias in implementation.typeAliases {
                if typeAlias.name == associatedType.name {
                    let resolvedType = extractTypeName(from: typeAlias.aliasedType)
                    addRelationship(
                        from: implementation.name,
                        to: resolvedType,
                        kind: .resolveAssociatedType,
                        details: "resolves \(associatedType.name) to \(resolvedType)"
                    )
                }
            }
        }
    }
    
    private func mapRequirementFulfillment(protocol protocolType: TypeInfo, implementation: TypeInfo) {
        // Map how protocol property requirements are fulfilled
        for protocolProperty in protocolType.properties {
            for implProperty in implementation.properties {
                if implProperty.name == protocolProperty.name {
                    addRelationship(
                        from: implementation.name,
                        to: protocolType.name,
                        kind: .fulfillsRequirement,
                        details: "property \(implProperty.name) fulfills \(protocolType.name) requirement"
                    )
                }
            }
        }
        
        // Map how protocol method requirements are fulfilled
        for protocolMethod in protocolType.methods {
            for implMethod in implementation.methods {
                if implMethod.name == protocolMethod.name {
                    addRelationship(
                        from: implementation.name,
                        to: protocolType.name,
                        kind: .fulfillsRequirement,
                        details: "method \(implMethod.name) fulfills \(protocolType.name) requirement"
                    )
                }
            }
        }
    }
}
