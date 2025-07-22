import Foundation

public class HTMLGenerator {
    private let graph: RelationshipGraph
    private let options: GeneratorOptions
    
    public struct GeneratorOptions {
        public let includePrivate: Bool
        public let includeProperties: Bool
        public let includeMethods: Bool
        public let includeExtensions: Bool
        public let focusType: String?
        public let maxDepth: Int
        public let title: String
        public let theme: Theme
        
        public enum Theme: String, CaseIterable {
            case light = "light"
            case dark = "dark"
        }
        
        public init(
            includePrivate: Bool = false,
            includeProperties: Bool = true,
            includeMethods: Bool = true,
            includeExtensions: Bool = false,
            focusType: String? = nil,
            maxDepth: Int = 3,
            title: String = "Swift Architecture Diagram",
            theme: Theme = .light
        ) {
            self.includePrivate = includePrivate
            self.includeProperties = includeProperties
            self.includeMethods = includeMethods
            self.includeExtensions = includeExtensions
            self.focusType = focusType
            self.maxDepth = maxDepth
            self.title = title
            self.theme = theme
        }
    }
    
    public init(graph: RelationshipGraph, options: GeneratorOptions = GeneratorOptions()) {
        self.graph = graph
        self.options = options
    }
    
    public func generate() throws -> String {
        // Generate JSON data for the visualization
        let jsonGraph = graph.toJSONGraph()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let jsonData = String(data: try encoder.encode(jsonGraph), encoding: .utf8)!
        
        return generateHTMLTemplate(with: jsonData)
    }
    
    private func generateHTMLTemplate(with jsonData: String) -> String {
        let themeClass = options.theme == .dark ? "dark-theme" : "light-theme"
        let cssContent = HTMLAssets.generateCSS(theme: options.theme)
        let jsContent = HTMLAssets.generateJavaScript()
        
        return """
        <!DOCTYPE html>
        <html lang="en" class="\(themeClass)">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(options.title)</title>
            <script src="https://d3js.org/d3.v7.min.js"></script>
            <style>
                \(cssContent)
            </style>
        </head>
        <body>
            <div class="container">
                <header class="header">
                    <h1>\(options.title)</h1>
                    <div class="controls">
                        <button id="reset-zoom">Reset Zoom</button>
                        <button id="toggle-theme">Toggle Theme</button>
                        <input type="text" id="search-input" placeholder="Search types...">
                        <div class="filter-group">
                            <label><input type="checkbox" id="show-properties" checked> Properties</label>
                            <label><input type="checkbox" id="show-methods" checked> Methods</label>
                            <label><input type="checkbox" id="show-initializers" checked> Initializers</label>
                            <label><input type="checkbox" id="show-private"> Private</label>
                        </div>
                    </div>
                </header>
                
                <div class="main-content">
                    <div class="sidebar">
                        <h3>Type Explorer</h3>
                        <div id="type-list"></div>
                        <div id="type-details"></div>
                    </div>
                    
                    <div class="diagram-container">
                        <svg id="diagram"></svg>
                    </div>
                </div>
                
                <div class="legend">
                    <div class="legend-item">
                        <div class="legend-color class-color"></div>
                        <span>Class</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color struct-color"></div>
                        <span>Struct</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color protocol-color"></div>
                        <span>Protocol</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color enum-color"></div>
                        <span>Enum</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color actor-color"></div>
                        <span>Actor</span>
                    </div>
                </div>
            </div>
            
            <script>
                const graphData = \(jsonData);
                \(jsContent)
            </script>
        </body>
        </html>
        """
    }
}