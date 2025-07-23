import ArgumentParser
import Foundation

struct ValidationError: Error, LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        return message
    }
}

@main
struct SwiftDiagramTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-diagram-tool",
        abstract: "A static analysis tool for generating system-level diagrams from Swift code",
        version: "0.1.0",
        subcommands: [Analyze.self, ListTypes.self],
        defaultSubcommand: Analyze.self
    )
}

struct Analyze: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze Swift code and generate diagrams"
    )

    @Argument(help: "Path to the Swift project or file to analyze")
    var path: String

    @Option(name: [.customShort("f"), .long], help: "Focus on a specific type (class, struct, protocol, or enum)")
    var focus: String?

    @Option(name: .shortAndLong, help: "Maximum depth of relationships to include (default: 3)")
    var depth: Int = 3

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "diagram.dot"

    @Option(name: [.customShort("F"), .long], help: "Output format: dot, plantuml, mermaid, json")
    var format: OutputFormat = .dot

    @Flag(name: .long, help: "Include private members in the diagram")
    var includePrivate = false

    @Flag(name: .long, help: "Include extensions in the diagram")
    var includeExtensions = false

    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose = false

    @Flag(name: .long, help: "Disable recursive directory search (default: enabled)")
    var noRecursive = false

    @Option(name: .long, help: "Maximum recursion depth for directory search (default: 10)")
    var maxDepth: Int = 10

    @Option(name: .long, help: "Exclude directories from recursive search (comma-separated)")
    var excludeDirectories: String?

    mutating func run() throws {
        if verbose {
            print("Analyzing Swift code at: \(path)")
            if let focus = focus {
                print("Focusing on: \(focus) with depth: \(depth)")
            }
        }

        let analyzer = SwiftAnalyzer()
        let graph = RelationshipGraph()

        let types: [TypeInfo]
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw ValidationError("Path does not exist: \(path)")
        }

        if isDirectory.boolValue {
            if verbose { print("Analyzing directory: \(path)") }

            var excludedDirs: Set<String> = [
                ".git", ".build", ".swiftpm", "DerivedData", "build",
                "Pods", "Carthage", "node_modules", ".DS_Store"
            ]

            if let excludeDirectories = excludeDirectories {
                let customExcludes = excludeDirectories.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                excludedDirs.formUnion(customExcludes)
            }

            let analysisOptions = SwiftAnalyzer.AnalysisOptions(
                recursive: !noRecursive,
                maxDepth: maxDepth,
                excludedDirectories: excludedDirs,
                verbose: verbose
            )

            types = try analyzer.analyzeDirectory(at: path, options: analysisOptions)
        } else {
            if verbose { print("Analyzing file: \(path)") }
            types = try analyzer.analyzeFile(at: path)
        }

        if verbose { print("Found \(types.count) types") }

        for type in types {
            graph.addType(type)
        }
        
        // Analyze protocol relationships after all types are added
        graph.analyzeProtocolRelationships()
        
        // Analyze deep type relationships (generics, collections, wrappers)
        graph.analyzeDeepTypeRelationships()
        
        // Analyze protocol internal structure (associated types, requirements)
        graph.analyzeProtocolInternalStructure()

        let generator: String
        switch format {
        case .dot:
            let dotGen = DOTGenerator(graph: graph, options: .init(
                includePrivate: includePrivate,
                includeProperties: true,
                includeMethods: true,
                includeExtensions: includeExtensions,
                focusType: focus,
                maxDepth: depth
            ))
            generator = dotGen.generate()

        case .json:
            let jsonGen = JSONGenerator(mode: .graph(graph))
            generator = try jsonGen.generate()

        case .plantuml, .mermaid:
            print("\(format.rawValue.capitalized) format not implemented yet, using DOT format")
            let dotGen = DOTGenerator(graph: graph, options: .init(
                includePrivate: includePrivate,
                includeProperties: true,
                includeMethods: true,
                includeExtensions: includeExtensions,
                focusType: focus,
                maxDepth: depth
            ))
            generator = dotGen.generate()
        }

        try generator.write(toFile: output, atomically: true, encoding: .utf8)
        print("Diagram generated: \(output)")
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case dot
    case plantuml
    case mermaid
    case json
}
