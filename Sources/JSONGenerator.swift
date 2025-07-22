import Foundation

struct JSONGenerator {
    enum OutputMode {
        case types([TypeInfo])
        case graph(RelationshipGraph)
    }

    let mode: OutputMode

    func generate() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        switch mode {
        case .types(let types):
            return try String(data: encoder.encode(types), encoding: .utf8)!
        case .graph(let graph):
            let jsonGraph = graph.toJSONGraph()
            return try String(data: encoder.encode(jsonGraph), encoding: .utf8)!
        }
    }
}

struct JSONGraph: Codable {
    struct JSONNode: Codable {
        let type: TypeInfo
        let relationships: [RelationshipGraph.Relationship]
    }

    let nodes: [JSONNode]
}

extension RelationshipGraph {
    func toJSONGraph() -> JSONGraph {
        let nodes = getAllNodes().map {
            JSONGraph.JSONNode(type: $0.type, relationships: Array($0.relationships))
        }
        return JSONGraph(nodes: nodes)
    }
}
