## 🚨 CRITICAL OPERATING RULES (ALWAYS APPLY)

### File Path Management
**CRITICAL**: Always use relative directory paths when working with project files. Do not execute commands that would create duplicate directories or nested structures.

**IMPORTANT**: All file operations (Read, Write, Edit, MultiEdit, LS, Glob, Grep, etc.) MUST use relative paths from the project root `/Users/francisb/Documents/Documents - Francis's MacBook Pro/Develop/ShareFit/`. Never use absolute paths unless absolutely necessary.

Examples:
- ✅ Good: `Sources/Views/Timer/TimerView.swift`
- ❌ Bad: `Sources/Views/Sources/Views/Timer/TimerView.swift`
- ❌ Bad: `/Users/francisb/Documents/Documents - Francis's MacBook Pro/Develop/ShareFit/Sources/Views/Timer/TimerView.swift`
- ✅ Good: `Models/TimerMode.swift`
- ❌ Bad: `Models/Models/TimerMode.swift`

**File Tool Usage Rules:**
- Read tool: `Read("Sources/Views/ExampleView.swift")` ✅
- Write tool: `Write("Sources/Views/NewView.swift", content)` ✅
- Edit tool: `Edit("Models/DataModel.swift", old, new)` ✅
- LS tool: `LS("Sources/Views")` ✅
- Glob tool: `Glob("**/*.swift")` ✅

### File Creation Guidelines
**CRITICAL**: When creating new files, choose the appropriate method based on file type:

✅ **PREFERRED METHOD** - Use Write tool for Swift/code files:
```
Write("path/to/file.swift", content)
```

✅ **ALTERNATIVE METHOD** - Use bash heredoc for shell scripts/config files:
```bash
cat > path/to/file.sh << 'EOF'
file content here
EOF
```

**IMPORTANT FILE CREATION RULES**:
- **Swift files**: Always use Write tool to avoid escape character issues
- **Shell scripts/configs**: Use bash heredoc method
- **NEVER include EOF markers in file content** - they are heredoc delimiters only
- **Verify file creation** with `ls -la` in the target directory

**Why Write tool is preferred for Swift files**:
- Prevents escape character corruption (`\!` instead of `!`)
- Avoids EOF marker pollution in file content
- Maintains proper Swift syntax highlighting and formatting
- Ensures clean, readable code without bash artifacts

**Verification**: Always verify file creation with `ls -la` in the target directory. If the file doesn't appear, it was created in the wrong location.

## 🔧 RelationshipGraph Enhancement TODO

### **Critical Issues Identified in SwiftDiagramTool Analysis**

Based on comprehensive analysis of inheritance connectivity and relationship completeness issues:

### **Phase 1: Phantom Nodes System**
- **Issue**: External types (UIViewController, URLSession, Published, etc.) are referenced in relationships but don't exist as nodes
- **Solution**: Create phantom node generation system
  - Add `createPhantomNode()` method for external type detection
  - Implement framework classification: UIKit (`UI*`), Foundation (`NS*`), SwiftUI (`@Published`, `@State`)
  - Add `isPhantom: Bool` flag to TypeInfo to distinguish external vs user types
  - Infer type kind from usage context (inheritance = class, conformance = protocol)

### **Phase 2: Extension Property Integration**
- **Issue**: Extension properties excluded from merged classes, breaking property relationships
- **Solution**: Fix `mergeExtensionIntoClass()` in RelationshipGraph.swift
  - Remove restriction that excludes extension properties (line 148)
  - Properly combine properties from both class and extensions
  - Ensure computed properties from extensions create relationships

### **Phase 3: Protocol Property Analysis**
- **Issue**: Protocol-typed properties missing implementation relationships
- **Solution**: Add protocol implementation detection
  - Detect when properties are protocol types (ending in "Protocol" or known protocols)
  - Find concrete implementations of protocols in the codebase
  - Add new relationship types: `implements`, `injection`, `protocolInheritance`
  - Map dependency injection patterns with default implementations

### **Phase 4: Deep Nested Type Relationships**
- **Issue**: Complex generic, collection, and property wrapper relationships not captured
- **Solution**: Enhanced type extraction and relationship creation
  - **Generic Parameters**: Parse `PostCache<Post>` → relationships to both PostCache and Post
  - **Collections**: Parse `[NetworkInterceptor]` → relationships to Array and NetworkInterceptor  
  - **Property Wrappers**: Parse `@Published var posts: [Post]` → relationships to Published, Array, and Post
  - **Nested Types**: Handle multi-level generics, closures, tuples, protocol compositions

### **Phase 5: Protocol Internal Structure Analysis**
- **Issue**: Protocols treated as black boxes, missing internal contract details
- **Solution**: Complete protocol relationship analysis
  - **Associated Types**: Extract constraints (`associatedtype Key: Hashable & Sendable`)
  - **Method Requirements**: Analyze protocol method signatures and generic constraints
  - **Property Requirements**: Track required properties and their types
  - **Implementation Mapping**: Connect protocol requirements to concrete implementations
  - **Type Resolution**: Track how associated types are resolved in implementations

### **Enhanced Relationship Types Needed**
```swift
public enum Kind: String, Codable {
    // Existing
    case inheritance = "inherits"
    case protocolConformance = "conforms" 
    case dependency = "uses"
    case composition = "contains"
    case aggregation = "references"
    
    // New Protocol-Specific
    case implements = "implements"
    case protocolInheritance = "extends"
    case injection = "injected"
    case associatedType = "associated_type"
    case typeConstraint = "constrained_by"
    case methodRequirement = "requires_method"
    case propertyRequirement = "requires_property"
    case fulfillsRequirement = "fulfills"
    case resolveAssociatedType = "resolves_type"
    case genericConstraint = "generic_constraint"
}
```

### **Expected Outcomes**
- **Complete Connectivity**: No orphaned relationships or isolated nodes
- **Full Inheritance Chains**: UIViewController → UIResponder → NSObject chains visible
- **Protocol Architecture**: Interface contracts and implementations clearly mapped
- **Deep Type Relationships**: Generic parameters, collections, property wrappers connected
- **Architectural Insight**: True data flow and dependency patterns revealed

### **Files to Modify**
- `Sources/Models/RelationshipGraph.swift` (main implementation)
- `Sources/Models/TypeInfo.swift` (add isPhantom flag)
- Potentially add `PhantomNodeRegistry.swift` for external type management

## 🔍 Critical Property Detection Failures

### **Real-World Property Examples That Fail**

Analysis of missing properties reveals fundamental SwiftAnalyzer bugs with common Swift property patterns:

```swift
class iosVideoPlayerViewController {
    var playerSkinController: PlayerSkinController?              // Missing: Optional external type
    
    let volumeSidePadding: CGFloat = 10.0                       // Missing: Type + default value
    
    /// Used for mp player info center
    var thumbnail: UIImage?                                     // Missing: Optional UIKit type with docs
    
    // This flag is used to configure the vc according to fullscreen mode
    var isFullscreenModal: Bool = false                         // Missing: Bool with default + comments
    
    /// Property that holds the volume level (1.0 - 0.0)
    var volume: CGFloat?                                        // Missing: Optional Core Graphics type
    
    ///Disables changing the player state when the viewDisappears and reappears
    var shouldDisableAppearDisappearStateChanges = false        // Missing: Type inference + docs
    
    /// Flag that is used to configure vc
    /// When vc is not live tv we can deinit player normally
    var byPassCleanup: Bool = false                            // Missing: Bool with multiline docs
}
```

### **Root Causes for Property Detection Failures**

**1. Default Value + Type Annotation Combination**
- **Pattern**: `let volumeSidePadding: CGFloat = 10.0`
- **Issue**: Parser fails when properties have both `: Type` and `= value`
- **Cause**: `extractPropertyInfo()` cannot handle combined type annotation and initializer

**2. Type Inference Properties**
- **Pattern**: `var shouldDisableAppearDisappearStateChanges = false`
- **Issue**: Properties without explicit type annotations completely skipped
- **Cause**: Logic requires `typeAnnotation` but Swift allows type inference

**3. Optional Type Parsing**
- **Pattern**: `var thumbnail: UIImage?`, `var volume: CGFloat?`
- **Issue**: Optional marker `?` breaks type extraction
- **Cause**: `extractTypeName()` returns `"UIImage?"` instead of `"UIImage"` + optional flag

**4. External Framework Types**
- **Pattern**: `UIImage`, `CGFloat` (UIKit, Core Graphics)
- **Issue**: External framework types not recognized as valid types
- **Cause**: Type relationship creation fails for non-user-defined types

**5. Documentation Comment Interference**
- **Pattern**: Properties with `///` or `//` comments above
- **Issue**: Documentation comments affecting member block parsing
- **Cause**: Syntax tree traversal confused by comment placement

**6. Pattern Recognition Too Narrow**
- **Issue**: `IdentifierPatternSyntax` matching misses real Swift property patterns
- **Cause**: Only handles simplest variable declaration patterns

### **SwiftAnalyzer Bugs Identified**

**In `Sources/Analyzers/SwiftAnalyzer.swift`:**

1. **`extractPropertyInfo()` Method (Lines 324-393)**
   - Cannot handle properties with both type annotation and default value
   - Fails on type inference properties (no explicit type)
   - Pattern binding detection too restrictive

2. **`extractTypeName()` Method (Lines 595-597)**
   - Too simplistic for optional types (`PlayerSkinController?`)
   - Doesn't handle external framework types
   - No complex type annotation parsing

3. **`extractProperties()` Method (Lines 300-322)**
   - Only handles `IdentifierPatternSyntax` patterns
   - Misses type inference variable declarations
   - Documentation comment interference not handled

4. **Pattern Binding Logic (Line 309)**
   - `binding.pattern.as(IdentifierPatternSyntax.self)` too narrow
   - Real Swift property patterns not covered
   - Multiple binding declarations not supported

### **Priority Fixes Needed**

**Immediate (Critical):**
1. **Fix Default Value + Type Annotation Parsing**
   - Handle `let property: Type = value` pattern
   - Extract both type and default value correctly

2. **Add Type Inference Support**
   - Detect properties without explicit type annotations
   - Infer types from default values (`= false` → Bool)

3. **Repair Optional Type Extraction**
   - Extract base type from `UIImage?` → `UIImage`
   - Set optional flag separately
   - Handle nested optionals

**Secondary (Important):**
4. **Handle External Framework Types**
   - Recognize UIKit, Core Graphics, Foundation types
   - Create proper phantom nodes for external types

5. **Improve Pattern Recognition**
   - Support all Swift property declaration patterns
   - Handle complex binding scenarios
   - Remove documentation comment interference

### **Expected Outcomes**
- **Complete Property Coverage**: All real-world Swift property patterns detected
- **Accurate Type Extraction**: Proper handling of optionals, inference, external types
- **Robust Parsing**: Documentation comments and complex patterns don't break detection
- **Framework Type Support**: UIKit, Core Graphics, Foundation types properly recognized

This analysis reveals that property detection is **fundamentally broken** for real-world Swift code, explaining the widespread missing properties in the relationship graph analysis.