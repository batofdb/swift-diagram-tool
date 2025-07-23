import Foundation

// Simple test script to debug the SwiftAnalyzer issue
// This will help us understand what's happening with the MainViewController parsing

let testFilePath = "TestProject/Sources/Views/MainViewController.swift"

do {
    let analyzer = SwiftAnalyzer()
    let types = try analyzer.analyzeFile(at: testFilePath)
    
    print("=== SwiftAnalyzer Debug Results ===")
    print("Total types found: \(types.count)")
    
    for (index, type) in types.enumerated() {
        print("\n--- Type \(index + 1) ---")
        print("Name: \(type.name)")
        print("Kind: \(type.kind)")
        print("Inherited Types: \(type.inheritedTypes)")
        print("Conformed Protocols: \(type.conformedProtocols)")
        print("Properties count: \(type.properties.count)")
        
        if !type.properties.isEmpty {
            print("Properties:")
            for prop in type.properties {
                print("  - \(prop.name): \(prop.typeName)")
            }
        }
        
        print("Methods count: \(type.methods.count)")
        if !type.methods.isEmpty {
            print("Methods:")
            for method in type.methods {
                print("  - \(method.name)")
            }
        }
    }
    
    // Let's also examine the raw JSON output
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonData = try encoder.encode(types)
    let jsonString = String(data: jsonData, encoding: .utf8) ?? "Failed to encode"
    
    print("\n=== JSON Output ===")
    print(jsonString)
    
} catch {
    print("Error analyzing file: \(error)")
}