import SwiftSyntax
import SwiftParser
import Foundation

public class SwiftAnalyzer {
    private var discoveredTypes: [TypeInfo] = []
    private var currentFile: String = ""
    
    public struct AnalysisOptions {
        public let recursive: Bool
        public let maxDepth: Int
        public let excludedDirectories: Set<String>
        public let verbose: Bool
        
        public init(
            recursive: Bool = true,
            maxDepth: Int = 10,
            excludedDirectories: Set<String> = [
                ".git", ".build", ".swiftpm", "DerivedData", "build", 
                "Pods", "Carthage", "node_modules", ".DS_Store"
            ],
            verbose: Bool = false
        ) {
            self.recursive = recursive
            self.maxDepth = maxDepth
            self.excludedDirectories = excludedDirectories
            self.verbose = verbose
        }
    }
    
    public init() {}
    
    public func analyzeFile(at path: String) throws -> [TypeInfo] {
        currentFile = path
        
        let sourceFile = try String(contentsOfFile: path, encoding: .utf8)
        let syntax = Parser.parse(source: sourceFile)
        
        let visitor = TypeCollectorVisitor(fileName: path)
        visitor.walk(syntax)
        
        return visitor.collectedTypes
    }
    
    public func analyzeDirectory(at path: String, options: AnalysisOptions = AnalysisOptions()) throws -> [TypeInfo] {
        discoveredTypes = []
        
        if options.recursive {
            try analyzeDirectoryRecursively(at: path, options: options, currentDepth: 0)
        } else {
            try analyzeDirectoryNonRecursively(at: path, options: options)
        }
        
        return discoveredTypes
    }
    
    private func analyzeDirectoryRecursively(at path: String, options: AnalysisOptions, currentDepth: Int) throws {
        guard currentDepth < options.maxDepth else { return }
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        
        for item in contents {
            if options.excludedDirectories.contains(item) {
                continue
            }
            
            let itemPath = "\(path)/\(item)"
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    try analyzeDirectoryRecursively(at: itemPath, options: options, currentDepth: currentDepth + 1)
                } else if itemPath.hasSuffix(".swift") {
                    let types = try analyzeFile(at: itemPath)
                    discoveredTypes.append(contentsOf: types)
                    
                    if options.verbose {
                        print("Analyzed \(itemPath): found \(types.count) types")
                    }
                }
            }
        }
    }
    
    private func analyzeDirectoryNonRecursively(at path: String, options: AnalysisOptions) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        
        for item in contents {
            let itemPath = "\(path)/\(item)"
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                if !isDirectory.boolValue && itemPath.hasSuffix(".swift") {
                    let types = try analyzeFile(at: itemPath)
                    discoveredTypes.append(contentsOf: types)
                    
                    if options.verbose {
                        print("Analyzed \(itemPath): found \(types.count) types")
                    }
                }
            }
        }
    }
}

// MARK: - Type Collector Visitor

class TypeCollectorVisitor: SyntaxVisitor {
    var collectedTypes: [TypeInfo] = []
    let fileName: String
    
    init(fileName: String) {
        self.fileName = fileName
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let typeInfo = extractTypeInfo(from: node, kind: .class)
        collectedTypes.append(typeInfo)
        return .visitChildren
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let typeInfo = extractTypeInfo(from: node, kind: .struct)
        collectedTypes.append(typeInfo)
        return .visitChildren
    }
    
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let typeInfo = extractTypeInfo(from: node, kind: .protocol)
        collectedTypes.append(typeInfo)
        return .visitChildren
    }
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let typeInfo = extractTypeInfo(from: node, kind: .enum)
        collectedTypes.append(typeInfo)
        return .visitChildren
    }
    
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        let typeInfo = extractTypeInfo(from: node, kind: .actor)
        collectedTypes.append(typeInfo)
        return .visitChildren
    }
    
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let typeInfo = extractTypeInfo(from: node, kind: .extension)
        collectedTypes.append(typeInfo)
        return .visitChildren
    }
    
    // MARK: - Type Information Extraction
    
    private func extractTypeInfo(from node: some SyntaxProtocol, kind: TypeKind) -> TypeInfo {
        let name = extractName(from: node)
        let modifiers = extractModifiers(from: node)
        let accessLevel = extractAccessLevel(from: modifiers)
        let (inheritedTypes, conformedProtocols) = extractInheritance(from: node)
        let properties = extractProperties(from: node)
        let methods = extractMethods(from: node)
        let initializers = extractInitializers(from: node)
        let subscripts = extractSubscripts(from: node)
        let typeAliases = extractTypeAliases(from: node)
        let nestedTypes = extractNestedTypes(from: node)
        let associatedTypes = extractAssociatedTypes(from: node)
        let protocolRequirements = extractProtocolRequirements(from: node)
        let genericParameters = extractGenericParameters(from: node)
        let genericConstraints = extractGenericConstraints(from: node)
        let attributes = extractAttributes(from: node)
        let location = extractLocation(from: node)
        
        return TypeInfo(
            name: name,
            kind: kind,
            accessLevel: accessLevel,
            inheritedTypes: inheritedTypes,
            conformedProtocols: conformedProtocols,
            properties: properties,
            methods: methods,
            initializers: initializers,
            subscripts: subscripts,
            typeAliases: typeAliases,
            nestedTypes: nestedTypes,
            associatedTypes: associatedTypes,
            protocolRequirements: protocolRequirements,
            genericParameters: genericParameters,
            genericConstraints: genericConstraints,
            attributes: attributes,
            location: location
        )
    }
    
    private func extractName(from node: some SyntaxProtocol) -> String {
        if let classNode = node.as(ClassDeclSyntax.self) {
            return classNode.name.text
        } else if let structNode = node.as(StructDeclSyntax.self) {
            return structNode.name.text
        } else if let protocolNode = node.as(ProtocolDeclSyntax.self) {
            return protocolNode.name.text
        } else if let enumNode = node.as(EnumDeclSyntax.self) {
            return enumNode.name.text
        } else if let actorNode = node.as(ActorDeclSyntax.self) {
            return actorNode.name.text
        } else if let extensionNode = node.as(ExtensionDeclSyntax.self) {
            return extensionNode.extendedType.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Unknown"
    }
    
    private func extractModifiers(from node: some SyntaxProtocol) -> DeclModifierListSyntax? {
        if let classNode = node.as(ClassDeclSyntax.self) {
            return classNode.modifiers
        } else if let structNode = node.as(StructDeclSyntax.self) {
            return structNode.modifiers
        } else if let protocolNode = node.as(ProtocolDeclSyntax.self) {
            return protocolNode.modifiers
        } else if let enumNode = node.as(EnumDeclSyntax.self) {
            return enumNode.modifiers
        } else if let actorNode = node.as(ActorDeclSyntax.self) {
            return actorNode.modifiers
        } else if let extensionNode = node.as(ExtensionDeclSyntax.self) {
            return extensionNode.modifiers
        }
        return nil
    }
    
    private func extractAccessLevel(from modifiers: DeclModifierListSyntax?) -> AccessLevel {
        guard let modifiers = modifiers else { return .internal }
        
        for modifier in modifiers {
            switch modifier.name.text {
            case "private": return .private
            case "fileprivate": return .fileprivate
            case "internal": return .internal
            case "public": return .public
            case "open": return .open
            default: continue
            }
        }
        
        return .internal
    }
    
    private func extractInheritance(from node: some SyntaxProtocol) -> (Set<String>, Set<String>) {
        var inheritedTypes = Set<String>()
        var conformedProtocols = Set<String>()
        
        let inheritanceClause: InheritanceClauseSyntax?
        if let classNode = node.as(ClassDeclSyntax.self) {
            inheritanceClause = classNode.inheritanceClause
        } else if let structNode = node.as(StructDeclSyntax.self) {
            inheritanceClause = structNode.inheritanceClause
        } else if let protocolNode = node.as(ProtocolDeclSyntax.self) {
            inheritanceClause = protocolNode.inheritanceClause
        } else if let enumNode = node.as(EnumDeclSyntax.self) {
            inheritanceClause = enumNode.inheritanceClause
        } else if let actorNode = node.as(ActorDeclSyntax.self) {
            inheritanceClause = actorNode.inheritanceClause
        } else if let extensionNode = node.as(ExtensionDeclSyntax.self) {
            inheritanceClause = extensionNode.inheritanceClause
        } else {
            inheritanceClause = nil
        }
        
        guard let clause = inheritanceClause else {
            return (inheritedTypes, conformedProtocols)
        }
        
        for inheritedType in clause.inheritedTypes {
            let typeName = inheritedType.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Simple heuristic: if it's a known protocol pattern or starts with uppercase, consider it
            // In practice, this would need more sophisticated type resolution
            if typeName.hasSuffix("Protocol") || typeName.hasSuffix("Delegate") || 
               typeName.contains("able") || isKnownProtocol(typeName) {
                conformedProtocols.insert(typeName)
            } else {
                // For classes, the first inherited type is usually the superclass
                inheritedTypes.insert(typeName)
            }
        }
        
        return (inheritedTypes, conformedProtocols)
    }
    
    private func isKnownProtocol(_ name: String) -> Bool {
        let knownProtocols = [
            "Codable", "Equatable", "Hashable", "Comparable", "CustomStringConvertible",
            "ExpressibleByStringLiteral", "ExpressibleByArrayLiteral", "ExpressibleByDictionaryLiteral",
            "Identifiable", "ObservableObject", "Timestampable", "Sendable", "AnyObject"
        ]
        return knownProtocols.contains(name)
    }
    
    // MARK: - Properties Extraction
    
    private func extractProperties(from node: some SyntaxProtocol) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []
        
        let memberBlock = extractMemberBlock(from: node)
        guard let members = memberBlock else { return properties }
        
        for member in members {
            if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in variableDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                        let property = extractPropertyInfo(
                            from: variableDecl,
                            binding: binding,
                            pattern: pattern
                        )
                        properties.append(property)
                    }
                }
            }
        }
        
        return properties
    }
    
    private func extractPropertyInfo(
        from variableDecl: VariableDeclSyntax,
        binding: PatternBindingSyntax,
        pattern: IdentifierPatternSyntax
    ) -> PropertyInfo {
        let name = pattern.identifier.text
        let defaultValue = binding.initializer?.value.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeName = extractTypeName(from: binding.typeAnnotation, inferringFrom: defaultValue)
        let accessLevel = extractAccessLevel(from: variableDecl.modifiers)
        let isStatic = hasModifier(variableDecl.modifiers, named: "static")
        let isLet = variableDecl.bindingSpecifier.text == "let"
        let isLazy = hasModifier(variableDecl.modifiers, named: "lazy")
        let isWeak = hasModifier(variableDecl.modifiers, named: "weak")
        let isUnowned = hasModifier(variableDecl.modifiers, named: "unowned")
        let isComputed = binding.accessorBlock != nil
        
        var hasGetter = true
        var hasSetter = false
        var getterAccessLevel: AccessLevel? = nil
        var setterAccessLevel: AccessLevel? = nil
        var hasWillSet = false
        var hasDidSet = false
        
        if let accessorBlock = binding.accessorBlock {
            switch accessorBlock.accessors {
            case .accessors(let accessors):
                for accessor in accessors {
                    switch accessor.accessorSpecifier.text {
                    case "get":
                        hasGetter = true
                        getterAccessLevel = nil // TODO: Fix accessor modifier extraction
                    case "set":
                        hasSetter = true
                        setterAccessLevel = nil // TODO: Fix accessor modifier extraction
                    case "willSet":
                        hasWillSet = true
                    case "didSet":
                        hasDidSet = true
                    default:
                        break
                    }
                }
            case .getter:
                hasGetter = true
                hasSetter = false
            }
        }
        
        let attributes = extractAttributeInfo(from: variableDecl.attributes)
        
        return PropertyInfo(
            name: name,
            typeName: typeName,
            accessLevel: accessLevel,
            isStatic: isStatic,
            isLet: isLet,
            isComputed: isComputed,
            isLazy: isLazy,
            isWeak: isWeak,
            isUnowned: isUnowned,
            hasGetter: hasGetter,
            hasSetter: hasSetter,
            getterAccessLevel: getterAccessLevel,
            setterAccessLevel: setterAccessLevel,
            hasWillSet: hasWillSet,
            hasDidSet: hasDidSet,
            defaultValue: defaultValue,
            attributes: attributes
        )
    }
    
    // MARK: - Methods Extraction
    
    private func extractMethods(from node: some SyntaxProtocol) -> [MethodInfo] {
        var methods: [MethodInfo] = []
        
        let memberBlock = extractMemberBlock(from: node)
        guard let members = memberBlock else { return methods }
        
        for member in members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                let method = extractMethodInfo(from: functionDecl)
                methods.append(method)
            }
        }
        
        return methods
    }
    
    private func extractMethodInfo(from functionDecl: FunctionDeclSyntax) -> MethodInfo {
        let name = functionDecl.name.text
        let parameters = extractParameters(from: functionDecl.signature.parameterClause)
        let returnType = extractReturnType(from: functionDecl.signature.returnClause)
        let accessLevel = extractAccessLevel(from: functionDecl.modifiers)
        let isStatic = hasModifier(functionDecl.modifiers, named: "static")
        let isClass = hasModifier(functionDecl.modifiers, named: "class")
        let isFinal = hasModifier(functionDecl.modifiers, named: "final")
        let isOverride = hasModifier(functionDecl.modifiers, named: "override")
        let isMutating = hasModifier(functionDecl.modifiers, named: "mutating")
        let isNonMutating = hasModifier(functionDecl.modifiers, named: "nonmutating")
        let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let `throws` = functionDecl.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil
        let `rethrows` = functionDecl.signature.effectSpecifiers?.throwsClause?.throwsSpecifier.text == "rethrows"
        let genericParameters = extractGenericParameters(from: functionDecl.genericParameterClause)
        let genericConstraints = extractGenericConstraints(from: functionDecl.genericWhereClause)
        let whereClause = functionDecl.genericWhereClause?.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let attributes = extractAttributeInfo(from: functionDecl.attributes)
        
        return MethodInfo(
            name: name,
            parameters: parameters,
            returnType: returnType,
            accessLevel: accessLevel,
            isStatic: isStatic,
            isClass: isClass,
            isAsync: isAsync,
            throws: `throws`,
            rethrows: `rethrows`,
            isMutating: isMutating,
            isNonMutating: isNonMutating,
            isOptional: false, // TODO: Extract from protocol context
            isFinal: isFinal,
            isOverride: isOverride,
            genericParameters: genericParameters,
            genericConstraints: genericConstraints,
            whereClause: whereClause,
            attributes: attributes
        )
    }
    
    // MARK: - Initializers Extraction
    
    private func extractInitializers(from node: some SyntaxProtocol) -> [InitializerInfo] {
        var initializers: [InitializerInfo] = []
        
        let memberBlock = extractMemberBlock(from: node)
        guard let members = memberBlock else { return initializers }
        
        for member in members {
            if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                let initializer = extractInitializerInfo(from: initDecl)
                initializers.append(initializer)
            }
        }
        
        return initializers
    }
    
    private func extractInitializerInfo(from initDecl: InitializerDeclSyntax) -> InitializerInfo {
        let parameters = extractParameters(from: initDecl.signature.parameterClause)
        let accessLevel = extractAccessLevel(from: initDecl.modifiers)
        let isFailable = initDecl.optionalMark != nil
        let isConvenience = hasModifier(initDecl.modifiers, named: "convenience")
        let isRequired = hasModifier(initDecl.modifiers, named: "required")
        let isAsync = initDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let `throws` = initDecl.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil
        let genericParameters = extractGenericParameters(from: initDecl.genericParameterClause)
        let genericConstraints = extractGenericConstraints(from: initDecl.genericWhereClause)
        let whereClause = initDecl.genericWhereClause?.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let attributes = extractAttributeInfo(from: initDecl.attributes)
        
        return InitializerInfo(
            parameters: parameters,
            accessLevel: accessLevel,
            isFailable: isFailable,
            isConvenience: isConvenience,
            isRequired: isRequired,
            throws: `throws`,
            isAsync: isAsync,
            genericParameters: genericParameters,
            genericConstraints: genericConstraints,
            whereClause: whereClause,
            attributes: attributes
        )
    }
    
    // MARK: - Subscripts Extraction
    
    private func extractSubscripts(from node: some SyntaxProtocol) -> [SubscriptInfo] {
        var subscripts: [SubscriptInfo] = []
        
        let memberBlock = extractMemberBlock(from: node)
        guard let members = memberBlock else { return subscripts }
        
        for member in members {
            if let subscriptDecl = member.decl.as(SubscriptDeclSyntax.self) {
                let `subscript` = extractSubscriptInfo(from: subscriptDecl)
                subscripts.append(`subscript`)
            }
        }
        
        return subscripts
    }
    
    private func extractSubscriptInfo(from subscriptDecl: SubscriptDeclSyntax) -> SubscriptInfo {
        let parameters = extractParameters(from: subscriptDecl.parameterClause)
        let returnType = extractReturnType(from: subscriptDecl.returnClause) ?? "Any"
        let accessLevel = extractAccessLevel(from: subscriptDecl.modifiers)
        let isStatic = hasModifier(subscriptDecl.modifiers, named: "static")
        let genericParameters = extractGenericParameters(from: subscriptDecl.genericParameterClause)
        let genericConstraints = extractGenericConstraints(from: subscriptDecl.genericWhereClause)
        let whereClause = subscriptDecl.genericWhereClause?.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let attributes = extractAttributeInfo(from: subscriptDecl.attributes)
        
        var hasGetter = true
        var hasSetter = false
        var getterAccessLevel: AccessLevel? = nil
        var setterAccessLevel: AccessLevel? = nil
        var getterEffects = EffectSpecifiers()
        var setterEffects = EffectSpecifiers()
        
        if let accessorBlock = subscriptDecl.accessorBlock {
            switch accessorBlock.accessors {
            case .accessors(let accessors):
                for accessor in accessors {
                    switch accessor.accessorSpecifier.text {
                    case "get":
                        hasGetter = true
                        getterAccessLevel = nil // TODO: Fix accessor modifier extraction
                        getterEffects = extractEffectSpecifiers(from: nil)
                    case "set":
                        hasSetter = true
                        setterAccessLevel = nil // TODO: Fix accessor modifier extraction
                        setterEffects = extractEffectSpecifiers(from: nil)
                    default:
                        break
                    }
                }
            case .getter:
                hasGetter = true
                hasSetter = false
            }
        }
        
        return SubscriptInfo(
            parameters: parameters,
            returnType: returnType,
            accessLevel: accessLevel,
            isStatic: isStatic,
            hasGetter: hasGetter,
            hasSetter: hasSetter,
            getterAccessLevel: getterAccessLevel,
            setterAccessLevel: setterAccessLevel,
            getterEffects: getterEffects,
            setterEffects: setterEffects,
            genericParameters: genericParameters,
            genericConstraints: genericConstraints,
            whereClause: whereClause,
            attributes: attributes
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractMemberBlock(from node: some SyntaxProtocol) -> MemberBlockItemListSyntax? {
        if let classNode = node.as(ClassDeclSyntax.self) {
            return classNode.memberBlock.members
        } else if let structNode = node.as(StructDeclSyntax.self) {
            return structNode.memberBlock.members
        } else if let protocolNode = node.as(ProtocolDeclSyntax.self) {
            return protocolNode.memberBlock.members
        } else if let enumNode = node.as(EnumDeclSyntax.self) {
            return enumNode.memberBlock.members
        } else if let actorNode = node.as(ActorDeclSyntax.self) {
            return actorNode.memberBlock.members
        } else if let extensionNode = node.as(ExtensionDeclSyntax.self) {
            return extensionNode.memberBlock.members
        }
        return nil
    }
    
    private func extractTypeName(from typeAnnotation: TypeAnnotationSyntax?) -> String {
        guard let typeAnnotation = typeAnnotation else { return "Any" }
        let typeDescription = typeAnnotation.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return extractCleanTypeName(typeDescription)
    }
    
    private func extractTypeName(from typeAnnotation: TypeAnnotationSyntax?, inferringFrom defaultValue: String?) -> String {
        // If we have an explicit type annotation, use it
        if let typeAnnotation = typeAnnotation {
            let typeDescription = typeAnnotation.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return extractCleanTypeName(typeDescription)
        }
        
        // If no type annotation, try to infer from default value
        if let defaultValue = defaultValue {
            return inferTypeFromDefaultValue(defaultValue)
        }
        
        // Fallback to Any
        return "Any"
    }
    
    private func inferTypeFromDefaultValue(_ defaultValue: String) -> String {
        let trimmedValue = defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Boolean literals
        if trimmedValue == "true" || trimmedValue == "false" {
            return "Bool"
        }
        
        // Integer literals
        if trimmedValue.allSatisfy({ $0.isNumber }) {
            return "Int"
        }
        
        // Float literals (contains decimal point)
        if trimmedValue.contains(".") && trimmedValue.replacingOccurrences(of: ".", with: "").allSatisfy({ $0.isNumber }) {
            return "Double"
        }
        
        // String literals (wrapped in quotes)
        if (trimmedValue.hasPrefix("\"") && trimmedValue.hasSuffix("\"")) ||
           (trimmedValue.hasPrefix("'") && trimmedValue.hasSuffix("'")) {
            return "String"
        }
        
        // Array literals
        if trimmedValue.hasPrefix("[") && trimmedValue.hasSuffix("]") {
            return "Array"
        }
        
        // Dictionary literals
        if trimmedValue.hasPrefix("{") && trimmedValue.hasSuffix("}") && trimmedValue.contains(":") {
            return "Dictionary"
        }
        
        // Set literals
        if trimmedValue.hasPrefix("Set(") && trimmedValue.hasSuffix(")") {
            return "Set"
        }
        
        // Nil literal
        if trimmedValue == "nil" {
            return "Optional"
        }
        
        // For complex expressions, try to extract constructor calls
        if let constructorType = extractConstructorType(from: trimmedValue) {
            return constructorType
        }
        
        // Fallback
        return "Any"
    }
    
    private func extractConstructorType(from expression: String) -> String? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Type() constructor patterns
        if let parenIndex = trimmed.firstIndex(of: "("), parenIndex > trimmed.startIndex {
            let typeName = String(trimmed[..<parenIndex])
            if typeName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                return typeName
            }
        }
        
        // Static member access like .shared, .default
        if trimmed.hasPrefix(".") {
            // Can't infer the type from static member access alone
            return nil
        }
        
        return nil
    }
    
    private func extractReturnType(from returnClause: ReturnClauseSyntax?) -> String? {
        guard let returnClause = returnClause else { return nil }
        let typeDescription = returnClause.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return extractCleanTypeName(typeDescription)
    }
    
    private func extractParameters(from parameterClause: FunctionParameterClauseSyntax) -> [ParameterInfo] {
        var parameters: [ParameterInfo] = []
        
        for parameter in parameterClause.parameters {
            let label = parameter.firstName.text == "_" ? nil : parameter.firstName.text
            let name = parameter.secondName?.text ?? parameter.firstName.text
            let typeDescription = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let typeName = extractCleanTypeName(typeDescription)
            let defaultValue = parameter.defaultValue?.value.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let isInout = parameter.type.description.contains("inout") // Simple check for inout parameters
            let isVariadic = parameter.ellipsis != nil
            
            let param = ParameterInfo(
                label: label,
                name: name,
                typeName: typeName,
                defaultValue: defaultValue,
                isInout: isInout,
                isVariadic: isVariadic
            )
            parameters.append(param)
        }
        
        return parameters
    }
    
    private func hasModifier(_ modifiers: DeclModifierListSyntax?, named name: String) -> Bool {
        guard let modifiers = modifiers else { return false }
        return modifiers.contains { $0.name.text == name }
    }
    
    private func extractEffectSpecifiers(from effectSpecifiers: AccessorEffectSpecifiersSyntax?) -> EffectSpecifiers {
        let isAsync = effectSpecifiers?.asyncSpecifier != nil
        let `throws` = effectSpecifiers?.throwsClause?.throwsSpecifier != nil
        return EffectSpecifiers(isAsync: isAsync, throws: `throws`)
    }
    
    private func extractAttributeInfo(from attributes: AttributeListSyntax?) -> [AttributeInfo] {
        var attributeInfos: [AttributeInfo] = []
        
        guard let attributes = attributes else { return attributeInfos }
        
        for attribute in attributes {
            if let attr = attribute.as(AttributeSyntax.self) {
                let name = attr.attributeName.description.trimmingCharacters(in: .whitespacesAndNewlines)
                let arguments = attr.arguments?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let attributeInfo = AttributeInfo(
                    name: name,
                    arguments: arguments.isEmpty ? [] : [arguments]
                )
                attributeInfos.append(attributeInfo)
            }
        }
        
        return attributeInfos
    }
    
    private func extractLocation(from node: some SyntaxProtocol) -> SourceLocation {
        let converter = SourceLocationConverter(fileName: fileName, tree: node.root)
        let location = node.startLocation(converter: converter)
        return SourceLocation(
            file: fileName,
            line: location.line,
            column: location.column
        )
    }
    
    // MARK: - Stub implementations for remaining methods
    
    private func extractTypeAliases(from node: some SyntaxProtocol) -> [TypeAliasInfo] {
        // TODO: Implement type alias extraction
        return []
    }
    
    private func extractNestedTypes(from node: some SyntaxProtocol) -> [NestedTypeInfo] {
        // TODO: Implement nested type extraction
        return []
    }
    
    private func extractAssociatedTypes(from node: some SyntaxProtocol) -> [AssociatedTypeInfo] {
        var associatedTypes: [AssociatedTypeInfo] = []
        
        let memberBlock = extractMemberBlock(from: node)
        guard let members = memberBlock else { return associatedTypes }
        
        for member in members {
            if let associatedTypeDecl = member.decl.as(AssociatedTypeDeclSyntax.self) {
                let name = associatedTypeDecl.name.text
                let inheritedType = associatedTypeDecl.inheritanceClause?.inheritedTypes.first?.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
                let defaultType = associatedTypeDecl.initializer?.value.description.trimmingCharacters(in: .whitespacesAndNewlines)
                let whereClause = associatedTypeDecl.genericWhereClause?.description.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let associatedType = AssociatedTypeInfo(
                    name: name,
                    inheritedType: inheritedType,
                    defaultType: defaultType,
                    whereClause: whereClause
                )
                associatedTypes.append(associatedType)
            }
        }
        
        return associatedTypes
    }
    
    private func extractProtocolRequirements(from node: some SyntaxProtocol) -> [ProtocolRequirement] {
        var requirements: [ProtocolRequirement] = []
        
        // Only extract requirements from protocols
        guard node.as(ProtocolDeclSyntax.self) != nil else {
            return requirements
        }
        
        let memberBlock = extractMemberBlock(from: node)
        guard let members = memberBlock else { return requirements }
        
        for member in members {
            // Extract property requirements
            if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in variableDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                        let name = pattern.identifier.text
                        let typeName = extractTypeName(from: binding.typeAnnotation)
                        let signature = "\(name): \(typeName)"
                        
                        let requirement = ProtocolRequirement(
                            kind: .property,
                            name: name,
                            signature: signature
                        )
                        requirements.append(requirement)
                    }
                }
            }
            
            // Extract method requirements
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                let name = functionDecl.name.text
                let parameters = extractParameters(from: functionDecl.signature.parameterClause)
                let returnType = extractReturnType(from: functionDecl.signature.returnClause)
                
                var signature = "\(name)("
                signature += parameters.map { param in
                    let label = param.label ?? "_"
                    return "\(label): \(param.typeName)"
                }.joined(separator: ", ")
                signature += ")"
                
                if let returnType = returnType {
                    signature += " -> \(returnType)"
                }
                
                let requirement = ProtocolRequirement(
                    kind: .method,
                    name: name,
                    signature: signature
                )
                requirements.append(requirement)
            }
            
            // Extract initializer requirements
            if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                let parameters = extractParameters(from: initDecl.signature.parameterClause)
                let name = "init"
                
                var signature = "init("
                signature += parameters.map { param in
                    let label = param.label ?? "_"
                    return "\(label): \(param.typeName)"
                }.joined(separator: ", ")
                signature += ")"
                
                let requirement = ProtocolRequirement(
                    kind: .initializer,
                    name: name,
                    signature: signature
                )
                requirements.append(requirement)
            }
            
            // Extract subscript requirements
            if let subscriptDecl = member.decl.as(SubscriptDeclSyntax.self) {
                let parameters = extractParameters(from: subscriptDecl.parameterClause)
                let returnType = extractReturnType(from: subscriptDecl.returnClause) ?? "Any"
                let name = "subscript"
                
                var signature = "subscript("
                signature += parameters.map { param in
                    let label = param.label ?? "_"
                    return "\(label): \(param.typeName)"
                }.joined(separator: ", ")
                signature += ") -> \(returnType)"
                
                let requirement = ProtocolRequirement(
                    kind: .subscript,
                    name: name,
                    signature: signature
                )
                requirements.append(requirement)
            }
            
            // Extract associated type requirements
            if let associatedTypeDecl = member.decl.as(AssociatedTypeDeclSyntax.self) {
                let name = associatedTypeDecl.name.text
                let signature = "associatedtype \(name)"
                
                let requirement = ProtocolRequirement(
                    kind: .associatedType,
                    name: name,
                    signature: signature
                )
                requirements.append(requirement)
            }
        }
        
        return requirements
    }
    
    private func extractGenericParameters(from node: some SyntaxProtocol) -> [GenericParameterInfo] {
        // TODO: Implement generic parameters extraction
        return []
    }
    
    private func extractGenericParameters(from genericClause: GenericParameterClauseSyntax?) -> [GenericParameterInfo] {
        // TODO: Implement generic parameters extraction from clause
        return []
    }
    
    private func extractGenericConstraints(from node: some SyntaxProtocol) -> [GenericConstraintInfo] {
        // TODO: Implement generic constraints extraction
        return []
    }
    
    private func extractGenericConstraints(from whereClause: GenericWhereClauseSyntax?) -> [GenericConstraintInfo] {
        // TODO: Implement generic constraints extraction from where clause
        return []
    }
    
    private func extractAttributes(from node: some SyntaxProtocol) -> [AttributeInfo] {
        // TODO: Implement full attribute extraction
        return []
    }
    
    // MARK: - Type Annotation Parsing
    
    /// Represents parsed type information with flags
    private struct ParsedTypeInfo {
        let baseTypeName: String
        let isOptional: Bool
        let isArray: Bool
        let genericParameters: [String]
        let fullTypeName: String // Original type name for debugging
        
        init(baseTypeName: String, isOptional: Bool = false, isArray: Bool = false, genericParameters: [String] = [], fullTypeName: String) {
            self.baseTypeName = baseTypeName
            self.isOptional = isOptional
            self.isArray = isArray
            self.genericParameters = genericParameters
            self.fullTypeName = fullTypeName
        }
    }
    
    /// Parse a type annotation and extract clean base type name with flags
    private func parseTypeAnnotation(_ typeDescription: String) -> ParsedTypeInfo {
        let trimmed = typeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle optional types (String?, UIImage?, etc.)
        if trimmed.hasSuffix("?") {
            let baseType = String(trimmed.dropLast())
            let parsed = parseTypeAnnotation(baseType)
            return ParsedTypeInfo(
                baseTypeName: parsed.baseTypeName,
                isOptional: true,
                isArray: parsed.isArray,
                genericParameters: parsed.genericParameters,
                fullTypeName: trimmed
            )
        }
        
        // Handle array types ([String], [UIImage], etc.)
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            let elementType = String(trimmed.dropFirst().dropLast())
            let parsed = parseTypeAnnotation(elementType)
            return ParsedTypeInfo(
                baseTypeName: parsed.baseTypeName,
                isOptional: parsed.isOptional,
                isArray: true,
                genericParameters: parsed.genericParameters,
                fullTypeName: trimmed
            )
        }
        
        // Handle generic types (Array<String>, Dictionary<String, Int>, etc.)
        if let openBracket = trimmed.firstIndex(of: "<"),
           let closeBracket = trimmed.lastIndex(of: ">") {
            let baseType = String(trimmed[..<openBracket])
            let genericPart = String(trimmed[trimmed.index(after: openBracket)..<closeBracket])
            let genericParams = parseGenericParameters(genericPart)
            
            return ParsedTypeInfo(
                baseTypeName: baseType,
                isOptional: false,
                isArray: false,
                genericParameters: genericParams,
                fullTypeName: trimmed
            )
        }
        
        // Simple type (String, Int, CustomClass, etc.)
        return ParsedTypeInfo(
            baseTypeName: trimmed,
            isOptional: false,
            isArray: false,
            genericParameters: [],
            fullTypeName: trimmed
        )
    }
    
    /// Parse generic parameters from a generic clause
    private func parseGenericParameters(_ genericClause: String) -> [String] {
        // Simple comma-separated parsing (could be enhanced for nested generics)
        return genericClause.split(separator: ",").map { 
            $0.trimmingCharacters(in: .whitespacesAndNewlines) 
        }
    }
    
    /// Extract clean base type name from any Swift type annotation
    private func extractCleanTypeName(_ typeDescription: String) -> String {
        let parsed = parseTypeAnnotation(typeDescription)
        return parsed.baseTypeName
    }
    
    /// Check if a type should be treated as optional based on the type annotation
    private func isOptionalType(_ typeDescription: String) -> Bool {
        let parsed = parseTypeAnnotation(typeDescription)
        return parsed.isOptional
    }
}