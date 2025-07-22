# Swift Diagram Tool - Complete Usage Guide

## 🔧 Fixed Compilation Issues

The tool is now ready to use! The main issues have been resolved:
- ✅ Removed conflicting `main.swift` file (using `@main` attribute instead)
- ✅ All compilation errors fixed
- ✅ Build successful with Swift 6.0

## 🚀 How to Generate JSON from Any Project

### 1. Build the Tool (One Time Setup)

```bash
swift build -c release
```

### 2. Analyze Different Projects

#### Analyze a Directory
```bash
# Basic analysis - generates JSON output
.build/release/SwiftDiagramTool analyze /path/to/your/swift/project --format json --output your_project.json

# Example: Analyze a local iOS project
.build/release/SwiftDiagramTool analyze ~/Projects/MyiOSApp --format json --output myapp_analysis.json
```

#### Analyze a Single File
```bash
.build/release/SwiftDiagramTool analyze ~/Projects/MyApp/Models/User.swift --format json --output user_model.json
```

#### Advanced Options
```bash
# Include private members and extensions
.build/release/SwiftDiagramTool analyze MyProject --format json --include-private --include-extensions --output detailed_analysis.json

# Focus on specific type with depth limit
.build/release/SwiftDiagramTool analyze MyProject --format json --focus User --depth 2 --output user_focused.json

# Exclude certain directories
.build/release/SwiftDiagramTool analyze MyProject --format json --exclude-directories "Tests,ThirdParty" --output clean_analysis.json

# Verbose output for debugging
.build/release/SwiftDiagramTool analyze MyProject --format json --verbose --output debug_analysis.json
```

### 3. View Results in Web Interface

#### Quick Setup
```bash
# 1. Generate your JSON
.build/release/SwiftDiagramTool analyze YourProject --format json --output analysis.json

# 2. Update web viewer to use your JSON
# Edit Web/viewer.js line 51 to point to your JSON file:
# fetch(`analysis.json?v=${cacheBuster}`)

# 3. Start web server
python3 -m http.server 8000

# 4. Open browser
# http://localhost:8000/Web/svg_graph_viewer.html
```

#### Alternative: Copy Your JSON
```bash
# Copy your generated JSON to match the viewer's expected filename
cp your_project.json example_analysis.json

# No need to edit viewer.js - it will load your data automatically
```

## 📊 Understanding the Output

### JSON Structure
The generated JSON contains nodes representing Swift types and their relationships:

```json
{
  "nodes": [
    {
      "type": {
        "name": "User",
        "kind": "class",
        "accessLevel": "public",
        "location": {"file": "Models/User.swift", "line": 10},
        "properties": [...],
        "methods": [...],
        "conformedProtocols": ["Identifiable", "Codable"]
      },
      "relationships": [
        {"from": "User", "to": "Post", "kind": "contains", "details": "property: posts"},
        {"from": "User", "to": "Identifiable", "kind": "conforms"}
      ]
    }
  ]
}
```

### Relationship Types
- **`contains`** - Property or parameter relationships
- **`inherits`** - Class inheritance
- **`conforms`** - Protocol conformance  
- **`uses`** - Method parameter or return type usage

## 🎯 Real-World Examples

### Example 1: iOS App Analysis
```bash
# Analyze your iOS app's Models directory
.build/release/SwiftDiagramTool analyze ~/MyiOSApp/Models --format json --output models.json

# Focus on a specific model and its relationships
.build/release/SwiftDiagramTool analyze ~/MyiOSApp --format json --focus UserViewModel --depth 3 --output user_vm.json
```

### Example 2: Swift Package Analysis
```bash
# Analyze a Swift package
.build/release/SwiftDiagramTool analyze ~/MySwiftPackage/Sources --format json --include-private --output package_internal.json
```

### Example 3: Large Codebase Analysis
```bash
# Analyze large project with exclusions
.build/release/SwiftDiagramTool analyze ~/LargeProject \
  --format json \
  --exclude-directories "Tests,ThirdParty,Generated,Pods" \
  --max-depth 5 \
  --output large_project.json
```

## 🔍 Troubleshooting

### Build Issues
```bash
# Clean build if you encounter issues
swift package clean
swift build -c release
```

### Permission Issues
```bash
# Make sure the executable is runnable
chmod +x .build/release/SwiftDiagramTool
```

### Large Projects
```bash
# For very large projects, limit depth and exclude unnecessary directories
.build/release/SwiftDiagramTool analyze LargeProject \
  --format json \
  --depth 2 \
  --exclude-directories "Tests,Pods,ThirdParty,Build" \
  --output limited_analysis.json
```

### Web Viewer Issues
1. **JSON not loading**: Check browser console for CORS errors
2. **Start local server**: `python3 -m http.server 8000` 
3. **Update viewer.js**: Change the JSON filename on line 51
4. **Hard refresh**: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)

## 📝 Command Reference

### Basic Commands
```bash
# Analyze directory and generate JSON
.build/release/SwiftDiagramTool analyze <path> --format json --output <filename.json>

# List all types in a project
.build/release/SwiftDiagramTool list-types <path>

# Help
.build/release/SwiftDiagramTool --help
.build/release/SwiftDiagramTool analyze --help
```

### All Options
```bash
.build/release/SwiftDiagramTool analyze <path> \
  --format json \                    # Output format: json, dot
  --output analysis.json \           # Output filename
  --focus ClassName \                # Focus on specific type
  --depth 3 \                       # Relationship depth
  --include-private \                # Include private members
  --include-extensions \             # Include extensions
  --exclude-directories "Tests,Pods" \ # Exclude directories
  --max-depth 10 \                  # Max directory recursion
  --no-recursive \                  # Disable recursion
  --verbose                         # Verbose output
```

## 🎨 Customizing the Web Viewer

### Change Data Source
Edit `Web/viewer.js` line 51:
```javascript
fetch(`your_custom_analysis.json?v=${cacheBuster}`)
```

### Styling
Edit `Web/styles.css` to customize the appearance.

### Layout
The viewer uses Cytoscape.js with the Cola layout engine. You can modify layout parameters in `Web/viewer.js`.

---

Happy analyzing! 🚀