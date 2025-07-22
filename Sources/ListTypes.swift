import ArgumentParser
import Foundation

struct ListTypes: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List all types found in the Swift project"
    )

    @Argument(help: "Path to the Swift project or file to analyze")
    var path: String

    @Option(name: .shortAndLong, help: "Filter by type: class, struct, protocol, enum, or all")
    var type: TypeFilter = .all

    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose = false

    @Flag(name: .long, help: "Disable recursive directory search (default: enabled)")
    var noRecursive = false

    @Option(name: .long, help: "Maximum recursion depth for directory search (default: 10)")
    var maxDepth: Int = 10

    @Option(name: .long, help: "Exclude directories from recursive search (comma-separated)")
    var excludeDirectories: String?

    func run() throws {
        if verbose {
            print("Listing types in: \(path)")
        }

        let analyzer = SwiftAnalyzer()
        let types: [TypeInfo]
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw ValidationError("Path does not exist: \(path)")
        }

        if isDirectory.boolValue {
            var excludedDirs: Set<String> = [
                ".git", ".build", ".swiftpm", "DerivedData", "build",
                "Pods", "Carthage", "node_modules", ".DS_Store"
            ]

            if let excludeDirectories = excludeDirectories {
                let customExcludes = excludeDirectories.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                excludedDirs.formUnion(customExcludes)
            }

            let options = SwiftAnalyzer.AnalysisOptions(
                recursive: !noRecursive,
                maxDepth: maxDepth,
                excludedDirectories: excludedDirs,
                verbose: verbose
            )

            types = try analyzer.analyzeDirectory(at: path, options: options)
        } else {
            types = try analyzer.analyzeFile(at: path)
        }

        let filteredTypes = types.filter { info in
            switch type {
            case .all: return true
            case .class: return info.kind == .class
            case .struct: return info.kind == .struct
            case .protocol: return info.kind == .protocol
            case .enum: return info.kind == .enum
            }
        }

        if filteredTypes.isEmpty {
            print("No types found.")
            return
        }

        print("Found \(filteredTypes.count) types:\n")
        for info in filteredTypes.sorted(by: { $0.name < $1.name }) {
            let access = symbol(for: info.accessLevel)
            print("\(access) \(info.kind.rawValue) \(info.name)")

            if verbose {
                print("  File: \(info.location.file)")
                if !info.inheritedTypes.isEmpty {
                    print("  Inherits: \(info.inheritedTypes.joined(separator: ", "))")
                }
                if !info.conformedProtocols.isEmpty {
                    print("  Conforms to: \(info.conformedProtocols.joined(separator: ", "))")
                }
                print("")
            }
        }
    }

    private func symbol(for level: AccessLevel) -> String {
        switch level {
        case .private: return "-"
        case .fileprivate: return "~"
        case .internal: return "#"
        case .public, .open: return "+"
        }
    }
}

enum TypeFilter: String, ExpressibleByArgument {
    case all
    case `class`
    case `struct`
    case `protocol`
    case `enum`
}
