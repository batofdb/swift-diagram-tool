import Foundation

// MARK: - Main Type Information

public struct TypeInfo: Codable, Equatable {
    public let name: String
    public let kind: TypeKind
    public let moduleName: String?
    public let accessLevel: AccessLevel
    public let inheritedTypes: Set<String>
    public let conformedProtocols: Set<String>
    public let properties: [PropertyInfo]
    public let methods: [MethodInfo]
    public let initializers: [InitializerInfo]
    public let subscripts: [SubscriptInfo]
    public let typeAliases: [TypeAliasInfo]
    public let nestedTypes: [NestedTypeInfo]
    public let associatedTypes: [AssociatedTypeInfo]
    public let protocolRequirements: [ProtocolRequirement]
    public let genericParameters: [GenericParameterInfo]
    public let genericConstraints: [GenericConstraintInfo]
    public let attributes: [AttributeInfo]
    public let location: SourceLocation
    public let isPhantom: Bool

    public init(
        name: String,
        kind: TypeKind,
        moduleName: String? = nil,
        accessLevel: AccessLevel = .internal,
        inheritedTypes: Set<String> = [],
        conformedProtocols: Set<String> = [],
        properties: [PropertyInfo] = [],
        methods: [MethodInfo] = [],
        initializers: [InitializerInfo] = [],
        subscripts: [SubscriptInfo] = [],
        typeAliases: [TypeAliasInfo] = [],
        nestedTypes: [NestedTypeInfo] = [],
        associatedTypes: [AssociatedTypeInfo] = [],
        protocolRequirements: [ProtocolRequirement] = [],
        genericParameters: [GenericParameterInfo] = [],
        genericConstraints: [GenericConstraintInfo] = [],
        attributes: [AttributeInfo] = [],
        location: SourceLocation,
        isPhantom: Bool = false
    ) {
        self.name = name
        self.kind = kind
        self.moduleName = moduleName
        self.accessLevel = accessLevel
        self.inheritedTypes = inheritedTypes
        self.conformedProtocols = conformedProtocols
        self.properties = properties
        self.methods = methods
        self.initializers = initializers
        self.subscripts = subscripts
        self.typeAliases = typeAliases
        self.nestedTypes = nestedTypes
        self.associatedTypes = associatedTypes
        self.protocolRequirements = protocolRequirements
        self.genericParameters = genericParameters
        self.genericConstraints = genericConstraints
        self.attributes = attributes
        self.location = location
        self.isPhantom = isPhantom
    }
}

// MARK: - Enums

public enum TypeKind: String, CaseIterable, Codable {
    case `class`
    case `struct`
    case `protocol`
    case `enum`
    case `actor`
    case `extension`
}

public enum AccessLevel: String, CaseIterable, Codable {
    case `private`
    case `fileprivate`
    case `internal`
    case `public`
    case `open`
}

public enum RequirementKind: String, Codable {
    case property
    case method
    case initializer
    case `subscript`
    case associatedType
}

// MARK: - Property Information

public struct PropertyInfo: Codable, Equatable {
    public let name: String
    public let typeName: String
    public let accessLevel: AccessLevel
    public let isStatic: Bool
    public let isLet: Bool
    public let isComputed: Bool
    public let isLazy: Bool
    public let isWeak: Bool
    public let isUnowned: Bool
    public let hasGetter: Bool
    public let hasSetter: Bool
    public let getterAccessLevel: AccessLevel?
    public let setterAccessLevel: AccessLevel?
    public let hasWillSet: Bool
    public let hasDidSet: Bool
    public let defaultValue: String?
    public let attributes: [AttributeInfo]

    public init(
        name: String,
        typeName: String,
        accessLevel: AccessLevel = .internal,
        isStatic: Bool = false,
        isLet: Bool = false,
        isComputed: Bool = false,
        isLazy: Bool = false,
        isWeak: Bool = false,
        isUnowned: Bool = false,
        hasGetter: Bool = true,
        hasSetter: Bool = false,
        getterAccessLevel: AccessLevel? = nil,
        setterAccessLevel: AccessLevel? = nil,
        hasWillSet: Bool = false,
        hasDidSet: Bool = false,
        defaultValue: String? = nil,
        attributes: [AttributeInfo] = []
    ) {
        self.name = name
        self.typeName = typeName
        self.accessLevel = accessLevel
        self.isStatic = isStatic
        self.isLet = isLet
        self.isComputed = isComputed
        self.isLazy = isLazy
        self.isWeak = isWeak
        self.isUnowned = isUnowned
        self.hasGetter = hasGetter
        self.hasSetter = hasSetter
        self.getterAccessLevel = getterAccessLevel
        self.setterAccessLevel = setterAccessLevel
        self.hasWillSet = hasWillSet
        self.hasDidSet = hasDidSet
        self.defaultValue = defaultValue
        self.attributes = attributes
    }
}

// MARK: - Method Information

public struct MethodInfo: Codable, Equatable {
    public let name: String
    public let parameters: [ParameterInfo]
    public let returnType: String?
    public let accessLevel: AccessLevel
    public let isStatic: Bool
    public let isClass: Bool
    public let isAsync: Bool
    public let `throws`: Bool
    public let `rethrows`: Bool
    public let isMutating: Bool
    public let isNonMutating: Bool
    public let isOptional: Bool
    public let isFinal: Bool
    public let isOverride: Bool
    public let genericParameters: [GenericParameterInfo]
    public let genericConstraints: [GenericConstraintInfo]
    public let whereClause: String?
    public let attributes: [AttributeInfo]

    public init(
        name: String,
        parameters: [ParameterInfo] = [],
        returnType: String? = nil,
        accessLevel: AccessLevel = .internal,
        isStatic: Bool = false,
        isClass: Bool = false,
        isAsync: Bool = false,
        throws: Bool = false,
        rethrows: Bool = false,
        isMutating: Bool = false,
        isNonMutating: Bool = false,
        isOptional: Bool = false,
        isFinal: Bool = false,
        isOverride: Bool = false,
        genericParameters: [GenericParameterInfo] = [],
        genericConstraints: [GenericConstraintInfo] = [],
        whereClause: String? = nil,
        attributes: [AttributeInfo] = []
    ) {
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
        self.accessLevel = accessLevel
        self.isStatic = isStatic
        self.isClass = isClass
        self.isAsync = isAsync
        self.`throws` = `throws`
        self.`rethrows` = `rethrows`
        self.isMutating = isMutating
        self.isNonMutating = isNonMutating
        self.isOptional = isOptional
        self.isFinal = isFinal
        self.isOverride = isOverride
        self.genericParameters = genericParameters
        self.genericConstraints = genericConstraints
        self.whereClause = whereClause
        self.attributes = attributes
    }
}

// MARK: - Initializer Information

public struct InitializerInfo: Codable, Equatable {
    public let parameters: [ParameterInfo]
    public let accessLevel: AccessLevel
    public let isFailable: Bool
    public let isConvenience: Bool
    public let isRequired: Bool
    public let `throws`: Bool
    public let isAsync: Bool
    public let genericParameters: [GenericParameterInfo]
    public let genericConstraints: [GenericConstraintInfo]
    public let whereClause: String?
    public let attributes: [AttributeInfo]

    public init(
        parameters: [ParameterInfo] = [],
        accessLevel: AccessLevel = .internal,
        isFailable: Bool = false,
        isConvenience: Bool = false,
        isRequired: Bool = false,
        throws: Bool = false,
        isAsync: Bool = false,
        genericParameters: [GenericParameterInfo] = [],
        genericConstraints: [GenericConstraintInfo] = [],
        whereClause: String? = nil,
        attributes: [AttributeInfo] = []
    ) {
        self.parameters = parameters
        self.accessLevel = accessLevel
        self.isFailable = isFailable
        self.isConvenience = isConvenience
        self.isRequired = isRequired
        self.`throws` = `throws`
        self.isAsync = isAsync
        self.genericParameters = genericParameters
        self.genericConstraints = genericConstraints
        self.whereClause = whereClause
        self.attributes = attributes
    }
}

// MARK: - Parameter Information

public struct ParameterInfo: Codable, Equatable {
    public let label: String?
    public let name: String
    public let typeName: String
    public let defaultValue: String?
    public let isInout: Bool
    public let isVariadic: Bool
    public let attributes: [String]
    public let typeAttributes: [String]

    public init(
        label: String? = nil,
        name: String,
        typeName: String,
        defaultValue: String? = nil,
        isInout: Bool = false,
        isVariadic: Bool = false,
        attributes: [String] = [],
        typeAttributes: [String] = []
    ) {
        self.label = label
        self.name = name
        self.typeName = typeName
        self.defaultValue = defaultValue
        self.isInout = isInout
        self.isVariadic = isVariadic
        self.attributes = attributes
        self.typeAttributes = typeAttributes
    }
}

// MARK: - Subscript Information

public struct SubscriptInfo: Codable, Equatable {
    public let parameters: [ParameterInfo]
    public let returnType: String
    public let accessLevel: AccessLevel
    public let isStatic: Bool
    public let hasGetter: Bool
    public let hasSetter: Bool
    public let getterAccessLevel: AccessLevel?
    public let setterAccessLevel: AccessLevel?
    public let getterEffects: EffectSpecifiers
    public let setterEffects: EffectSpecifiers
    public let genericParameters: [GenericParameterInfo]
    public let genericConstraints: [GenericConstraintInfo]
    public let whereClause: String?
    public let attributes: [AttributeInfo]

    public init(
        parameters: [ParameterInfo],
        returnType: String,
        accessLevel: AccessLevel = .internal,
        isStatic: Bool = false,
        hasGetter: Bool = true,
        hasSetter: Bool = false,
        getterAccessLevel: AccessLevel? = nil,
        setterAccessLevel: AccessLevel? = nil,
        getterEffects: EffectSpecifiers = EffectSpecifiers(),
        setterEffects: EffectSpecifiers = EffectSpecifiers(),
        genericParameters: [GenericParameterInfo] = [],
        genericConstraints: [GenericConstraintInfo] = [],
        whereClause: String? = nil,
        attributes: [AttributeInfo] = []
    ) {
        self.parameters = parameters
        self.returnType = returnType
        self.accessLevel = accessLevel
        self.isStatic = isStatic
        self.hasGetter = hasGetter
        self.hasSetter = hasSetter
        self.getterAccessLevel = getterAccessLevel
        self.setterAccessLevel = setterAccessLevel
        self.getterEffects = getterEffects
        self.setterEffects = setterEffects
        self.genericParameters = genericParameters
        self.genericConstraints = genericConstraints
        self.whereClause = whereClause
        self.attributes = attributes
    }
}

// MARK: - Type Alias Information

public struct TypeAliasInfo: Codable, Equatable {
    public let name: String
    public let aliasedType: String
    public let accessLevel: AccessLevel
    public let genericParameters: [GenericParameterInfo]
    public let genericConstraints: [GenericConstraintInfo]
    public let attributes: [AttributeInfo]

    public init(
        name: String,
        aliasedType: String,
        accessLevel: AccessLevel = .internal,
        genericParameters: [GenericParameterInfo] = [],
        genericConstraints: [GenericConstraintInfo] = [],
        attributes: [AttributeInfo] = []
    ) {
        self.name = name
        self.aliasedType = aliasedType
        self.accessLevel = accessLevel
        self.genericParameters = genericParameters
        self.genericConstraints = genericConstraints
        self.attributes = attributes
    }
}

// MARK: - Nested Type Information

public struct NestedTypeInfo: Codable, Equatable {
    public let typeInfo: TypeInfo
    public let accessLevel: AccessLevel

    public init(typeInfo: TypeInfo, accessLevel: AccessLevel) {
        self.typeInfo = typeInfo
        self.accessLevel = accessLevel
    }
}

// MARK: - Associated Type Information

public struct AssociatedTypeInfo: Codable, Equatable {
    public let name: String
    public let inheritedType: String?
    public let defaultType: String?
    public let whereClause: String?

    public init(
        name: String,
        inheritedType: String? = nil,
        defaultType: String? = nil,
        whereClause: String? = nil
    ) {
        self.name = name
        self.inheritedType = inheritedType
        self.defaultType = defaultType
        self.whereClause = whereClause
    }
}

// MARK: - Protocol Requirement

public struct ProtocolRequirement: Codable, Equatable {
    public let kind: RequirementKind
    public let name: String
    public let signature: String
    public let isOptional: Bool

    public init(
        kind: RequirementKind,
        name: String,
        signature: String,
        isOptional: Bool = false
    ) {
        self.kind = kind
        self.name = name
        self.signature = signature
        self.isOptional = isOptional
    }
}

// MARK: - Generic Information

public struct GenericParameterInfo: Codable, Equatable {
    public let name: String
    public let inheritedType: String?

    public init(name: String, inheritedType: String? = nil) {
        self.name = name
        self.inheritedType = inheritedType
    }
}

public struct GenericConstraintInfo: Codable, Equatable {
    public let type: String
    public let requirement: String

    public init(type: String, requirement: String) {
        self.type = type
        self.requirement = requirement
    }
}

// MARK: - Attribute Information

public struct AttributeInfo: Codable, Equatable {
    public let name: String
    public let arguments: [String]

    public init(name: String, arguments: [String] = []) {
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - Effect Specifiers

public struct EffectSpecifiers: Codable, Equatable {
    public let isAsync: Bool
    public let `throws`: Bool
    public let isMutating: Bool
    public let isNonMutating: Bool

    public init(
        isAsync: Bool = false,
        throws: Bool = false,
        isMutating: Bool = false,
        isNonMutating: Bool = false
    ) {
        self.isAsync = isAsync
        self.`throws` = `throws`
        self.isMutating = isMutating
        self.isNonMutating = isNonMutating
    }
}

// MARK: - Source Location

public struct SourceLocation: Codable, Equatable {
    public let file: String
    public let line: Int
    public let column: Int

    public init(file: String, line: Int, column: Int) {
        self.file = file
        self.line = line
        self.column = column
    }
}