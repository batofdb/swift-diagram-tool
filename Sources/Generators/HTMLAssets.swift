import Foundation

struct HTMLAssets {
    static func generateCSS(theme: HTMLGenerator.GeneratorOptions.Theme) -> String {
        let themeVars = theme == .dark ? darkThemeVars : lightThemeVars
        return """
        \(themeVars)
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            height: 100vh;
            overflow: hidden;
            transition: background-color 0.3s ease, color 0.3s ease;
        }
        
        .container {
            height: 100vh;
            display: flex;
            flex-direction: column;
        }
        
        .header {
            padding: 1rem 2rem;
            border-bottom: 1px solid var(--border-color);
            background-color: var(--header-bg);
            backdrop-filter: blur(10px);
            z-index: 1000;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }
        
        .header h1 {
            margin-bottom: 0.5rem;
            font-size: 1.5rem;
            font-weight: 600;
            color: var(--primary-color);
        }
        
        .controls {
            display: flex;
            gap: 1rem;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .controls button {
            padding: 0.5rem 1rem;
            border: 1px solid var(--border-color);
            background-color: var(--button-bg);
            color: var(--text-color);
            cursor: pointer;
            border-radius: 6px;
            font-size: 0.875rem;
            transition: all 0.2s ease;
        }
        
        .controls button:hover {
            background-color: var(--button-hover);
            transform: translateY(-1px);
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
        }
        
        .controls button:active {
            transform: translateY(0);
        }
        
        .controls input[type="text"] {
            padding: 0.5rem 1rem;
            border: 1px solid var(--border-color);
            background-color: var(--input-bg);
            color: var(--text-color);
            border-radius: 6px;
            font-size: 0.875rem;
            min-width: 200px;
            transition: border-color 0.2s ease;
        }
        
        .controls input[type="text"]:focus {
            outline: none;
            border-color: var(--primary-color);
            box-shadow: 0 0 0 2px rgba(52, 152, 219, 0.2);
        }
        
        .filter-group {
            display: flex;
            gap: 1rem;
            margin-left: 1rem;
        }
        
        .filter-group label {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            cursor: pointer;
            font-size: 0.875rem;
        }
        
        .filter-group input[type="checkbox"] {
            width: 16px;
            height: 16px;
            accent-color: var(--primary-color);
        }
        
        .main-content {
            flex: 1;
            display: flex;
            overflow: hidden;
        }
        
        .sidebar {
            width: 320px;
            padding: 1.5rem;
            border-right: 1px solid var(--border-color);
            background-color: var(--sidebar-bg);
            overflow-y: auto;
            backdrop-filter: blur(10px);
        }
        
        .sidebar h3 {
            margin-bottom: 1rem;
            font-size: 1.1rem;
            font-weight: 600;
            color: var(--primary-color);
        }
        
        .diagram-container {
            flex: 1;
            position: relative;
            background: linear-gradient(135deg, var(--diagram-bg-start), var(--diagram-bg-end));
        }
        
        #diagram {
            width: 100%;
            height: 100%;
        }
        
        .legend {
            position: absolute;
            bottom: 1.5rem;
            left: 1.5rem;
            background-color: var(--legend-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 1rem;
            display: flex;
            gap: 1.5rem;
            z-index: 1000;
            backdrop-filter: blur(10px);
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
        }
        
        .legend-item {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.875rem;
        }
        
        .legend-color {
            width: 18px;
            height: 18px;
            border-radius: 4px;
            border: 1px solid var(--border-color);
        }
        
        .class-color { background-color: var(--node-class); }
        .struct-color { background-color: var(--node-struct); }
        .protocol-color { background-color: var(--node-protocol); }
        .enum-color { background-color: var(--node-enum); }
        .actor-color { background-color: var(--node-actor); }
        
        .node {
            stroke: var(--node-border);
            stroke-width: 2;
            cursor: pointer;
            transition: all 0.2s ease;
            filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.1));
        }
        
        .node:hover {
            stroke: var(--node-hover);
            stroke-width: 3;
            filter: drop-shadow(0 4px 8px rgba(0, 0, 0, 0.2));
        }
        
        .node.selected {
            stroke: var(--node-selected);
            stroke-width: 3;
            filter: drop-shadow(0 4px 12px rgba(231, 76, 60, 0.3));
        }
        
        .node-text {
            font-size: 12px;
            font-weight: 500;
            text-anchor: middle;
            dominant-baseline: middle;
            fill: var(--text-color);
            pointer-events: none;
        }
        
        .node-title {
            font-size: 14px;
            font-weight: 600;
        }
        
        .node-type {
            font-size: 10px;
            font-weight: 400;
            opacity: 0.8;
        }
        
        .node-details {
            font-size: 9px;
            font-weight: 400;
            opacity: 0.7;
        }
        
        .link {
            stroke: var(--link-color);
            stroke-width: 2;
            fill: none;
            marker-end: url(#arrowhead);
            transition: all 0.2s ease;
        }
        
        .link:hover {
            stroke-width: 3;
            stroke: var(--link-hover);
        }
        
        .link.inheritance {
            stroke-dasharray: none;
            stroke-width: 2.5;
        }
        
        .link.conformance {
            stroke-dasharray: 5,5;
        }
        
        .link.composition {
            stroke-width: 3;
        }
        
        .link.dependency {
            stroke-dasharray: 3,3;
            opacity: 0.7;
        }
        
        .type-item {
            padding: 0.75rem;
            margin-bottom: 0.5rem;
            border: 1px solid var(--border-color);
            border-radius: 6px;
            cursor: pointer;
            transition: all 0.2s ease;
            background-color: var(--type-item-bg);
        }
        
        .type-item:hover {
            background-color: var(--type-item-hover);
            transform: translateX(2px);
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }
        
        .type-item.selected {
            background-color: var(--type-item-selected);
            color: white;
            border-color: var(--primary-color);
        }
        
        .type-item-name {
            font-weight: 600;
            margin-bottom: 0.25rem;
        }
        
        .type-item-kind {
            font-size: 0.75rem;
            opacity: 0.8;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .type-details {
            margin-top: 1.5rem;
            padding: 1rem;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            background-color: var(--details-bg);
            max-height: 400px;
            overflow-y: auto;
        }
        
        .type-details h4 {
            margin-bottom: 0.75rem;
            font-size: 1.1rem;
            color: var(--primary-color);
        }
        
        .type-details h5 {
            margin-top: 1rem;
            margin-bottom: 0.5rem;
            font-size: 0.9rem;
            color: var(--secondary-color);
        }
        
        .type-details ul {
            list-style: none;
            margin-left: 0;
        }
        
        .type-details li {
            margin-bottom: 0.375rem;
            padding: 0.25rem 0.5rem;
            border-radius: 4px;
            background-color: var(--code-bg);
            font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
            font-size: 0.8rem;
        }
        
        .access-level {
            display: inline-block;
            padding: 0.125rem 0.375rem;
            border-radius: 3px;
            font-size: 0.7rem;
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 0.5rem;
        }
        
        .access-level.public { background-color: var(--access-public); }
        .access-level.internal { background-color: var(--access-internal); }
        .access-level.private { background-color: var(--access-private); }
        
        @media (max-width: 768px) {
            .sidebar {
                width: 280px;
            }
            
            .controls {
                flex-direction: column;
                align-items: flex-start;
                gap: 0.5rem;
            }
            
            .filter-group {
                margin-left: 0;
            }
            
            .legend {
                flex-direction: column;
                gap: 0.5rem;
            }
        }
        """
    }
    
    private static let lightThemeVars = """
        :root {
            --bg-color: #ffffff;
            --text-color: #2c3e50;
            --primary-color: #3498db;
            --secondary-color: #7f8c8d;
            --border-color: #e1e5e9;
            --header-bg: rgba(255, 255, 255, 0.9);
            --sidebar-bg: rgba(248, 249, 250, 0.9);
            --button-bg: #ffffff;
            --button-hover: #f8f9fa;
            --input-bg: #ffffff;
            --legend-bg: rgba(255, 255, 255, 0.95);
            --type-item-bg: #ffffff;
            --type-item-hover: #f8f9fa;
            --type-item-selected: #3498db;
            --details-bg: #ffffff;
            --code-bg: #f8f9fa;
            --diagram-bg-start: #f8f9fa;
            --diagram-bg-end: #ffffff;
            
            --node-class: #e3f2fd;
            --node-struct: #fff3e0;
            --node-protocol: #f3e5f5;
            --node-enum: #e8f5e9;
            --node-actor: #fce4ec;
            --node-border: #90a4ae;
            --node-hover: #3498db;
            --node-selected: #e74c3c;
            
            --link-color: #7f8c8d;
            --link-hover: #3498db;
            
            --access-public: #e8f5e9;
            --access-internal: #fff3e0;
            --access-private: #ffebee;
        }
        """
    
    private static let darkThemeVars = """
        :root {
            --bg-color: #1a1a1a;
            --text-color: #e1e5e9;
            --primary-color: #3498db;
            --secondary-color: #bdc3c7;
            --border-color: #34495e;
            --header-bg: rgba(26, 26, 26, 0.9);
            --sidebar-bg: rgba(22, 22, 22, 0.9);
            --button-bg: #2c3e50;
            --button-hover: #34495e;
            --input-bg: #2c3e50;
            --legend-bg: rgba(22, 22, 22, 0.95);
            --type-item-bg: #2c3e50;
            --type-item-hover: #34495e;
            --type-item-selected: #3498db;
            --details-bg: #2c3e50;
            --code-bg: #34495e;
            --diagram-bg-start: #1a1a1a;
            --diagram-bg-end: #2c3e50;
            
            --node-class: #2c3e50;
            --node-struct: #8e44ad;
            --node-protocol: #e74c3c;
            --node-enum: #27ae60;
            --node-actor: #f39c12;
            --node-border: #7f8c8d;
            --node-hover: #3498db;
            --node-selected: #e74c3c;
            
            --link-color: #bdc3c7;
            --link-hover: #3498db;
            
            --access-public: #27ae60;
            --access-internal: #f39c12;
            --access-private: #e74c3c;
        }
        """
    
    static func generateJavaScript() -> String {
        return """
        class SwiftDiagramVisualization {
            constructor(data) {
                this.data = data;
                this.svg = d3.select('#diagram');
                this.container = this.svg.append('g');
                this.selectedNode = null;
                this.simulation = null;
                this.currentTheme = 'light';
                
                this.zoom = d3.zoom()
                    .scaleExtent([0.1, 3])
                    .on('zoom', this.handleZoom.bind(this));
                
                this.svg.call(this.zoom);
                this.setupEventListeners();
                this.setupDefinitions();
                this.render();
            }
            
            setupEventListeners() {
                d3.select('#reset-zoom').on('click', () => this.resetZoom());
                d3.select('#toggle-theme').on('click', () => this.toggleTheme());
                d3.select('#search-input').on('input', (e) => this.handleSearch(e.target.value));
                d3.select('#show-properties').on('change', () => this.render());
                d3.select('#show-methods').on('change', () => this.render());
                d3.select('#show-initializers').on('change', () => this.render());
                d3.select('#show-private').on('change', () => this.render());
                
                // Keyboard shortcuts
                d3.select('body').on('keydown', (event) => {
                    if (event.ctrlKey || event.metaKey) {
                        switch(event.key) {
                            case '0':
                                event.preventDefault();
                                this.resetZoom();
                                break;
                            case 'f':
                                event.preventDefault();
                                d3.select('#search-input').node().focus();
                                break;
                        }
                    }
                });
            }
            
            setupDefinitions() {
                const defs = this.container.append('defs');
                
                // Arrow markers for different relationship types
                const arrowTypes = [
                    { id: 'inheritance', color: '#3498db' },
                    { id: 'conformance', color: '#9b59b6' },
                    { id: 'composition', color: '#e74c3c' },
                    { id: 'dependency', color: '#95a5a6' }
                ];
                
                arrowTypes.forEach(type => {
                    defs.append('marker')
                        .attr('id', `arrowhead-${type.id}`)
                        .attr('viewBox', '0 -5 10 10')
                        .attr('refX', 15)
                        .attr('refY', 0)
                        .attr('markerWidth', 6)
                        .attr('markerHeight', 6)
                        .attr('orient', 'auto')
                        .append('path')
                        .attr('d', 'M0,-5L10,0L0,5')
                        .attr('fill', type.color);
                });
            }
            
            handleZoom(event) {
                this.container.attr('transform', event.transform);
            }
            
            resetZoom() {
                this.svg.transition()
                    .duration(750)
                    .call(this.zoom.transform, d3.zoomIdentity);
            }
            
            toggleTheme() {
                this.currentTheme = this.currentTheme === 'light' ? 'dark' : 'light';
                document.documentElement.className = this.currentTheme + '-theme';
            }
            
            handleSearch(query) {
                const filtered = this.data.nodes.filter(node => 
                    node.type.name.toLowerCase().includes(query.toLowerCase()) ||
                    node.type.kind.toLowerCase().includes(query.toLowerCase())
                );
                this.updateTypeList(filtered);
                
                // Highlight matching nodes in the diagram
                this.container.selectAll('.node')
                    .classed('search-highlight', d => 
                        query && filtered.some(f => f.type.name === d.type.name)
                    );
            }
            
            getNodeColor(kind) {
                const colors = {
                    'class': 'var(--node-class)',
                    'struct': 'var(--node-struct)',
                    'protocol': 'var(--node-protocol)',
                    'enum': 'var(--node-enum)',
                    'actor': 'var(--node-actor)'
                };
                return colors[kind] || 'var(--node-class)';
            }
            
            getRelationshipColor(kind) {
                const colors = {
                    'inherits': '#3498db',
                    'conforms': '#9b59b6',
                    'contains': '#e74c3c',
                    'uses': '#95a5a6'
                };
                return colors[kind] || '#95a5a6';
            }
            
            render() {
                const showProperties = d3.select('#show-properties').property('checked');
                const showMethods = d3.select('#show-methods').property('checked');
                const showInitializers = d3.select('#show-initializers').property('checked');
                const showPrivate = d3.select('#show-private').property('checked');
                
                let filteredNodes = this.data.nodes;
                if (!showPrivate) {
                    filteredNodes = filteredNodes.filter(node => node.type.accessLevel !== 'private');
                }
                
                this.renderDiagram(filteredNodes, showProperties, showMethods, showInitializers);
                this.updateTypeList(filteredNodes);
            }
            
            renderDiagram(nodes, showProperties, showMethods, showInitializers) {
                const links = [];
                // Extract relationships from nodes
                nodes.forEach(node => {
                    node.relationships.forEach(rel => {
                        if (nodes.find(n => n.type.name === rel.to)) {
                            links.push({
                                source: node.type.name,
                                target: rel.to,
                                kind: rel.kind
                            });
                        }
                    });
                });
                
                // Clear existing content
                this.container.selectAll('.diagram-content').remove();
                const diagramGroup = this.container.append('g').attr('class', 'diagram-content');
                
                // Create simulation with enhanced forces
                this.simulation = d3.forceSimulation(nodes)
                    .force('link', d3.forceLink(links).id(d => d.type.name).distance(150).strength(0.1))
                    .force('charge', d3.forceManyBody().strength(-800))
                    .force('center', d3.forceCenter(400, 300))
                    .force('collision', d3.forceCollide().radius(80))
                    .force('x', d3.forceX(400).strength(0.05))
                    .force('y', d3.forceY(300).strength(0.05));
                
                // Create links
                const link = diagramGroup.append('g')
                    .attr('class', 'links')
                    .selectAll('line')
                    .data(links)
                    .join('line')
                    .attr('class', d => `link ${d.kind}`)
                    .attr('stroke', d => this.getRelationshipColor(d.kind))
                    .attr('stroke-width', d => d.kind === 'contains' ? 3 : 2);
                
                // Create nodes
                const node = diagramGroup.append('g')
                    .attr('class', 'nodes')
                    .selectAll('g')
                    .data(nodes)
                    .join('g')
                    .attr('class', 'node-group')
                    .call(d3.drag()
                        .on('start', this.handleDragStart.bind(this))
                        .on('drag', this.handleDrag.bind(this))
                        .on('end', this.handleDragEnd.bind(this)));
                
                // Add rectangles for nodes
                node.append('rect')
                    .attr('class', 'node')
                    .attr('width', d => this.getNodeWidth(d, showProperties, showMethods, showInitializers))
                    .attr('height', d => this.getNodeHeight(d, showProperties, showMethods, showInitializers))
                    .attr('rx', 8)
                    .attr('ry', 8)
                    .attr('fill', d => this.getNodeColor(d.type.kind))
                    .on('click', (event, d) => this.selectNode(d));
                
                // Add node content
                this.addNodeContent(node, showProperties, showMethods, showInitializers);
                
                // Update simulation
                this.simulation.on('tick', () => {
                    link
                        .attr('x1', d => d.source.x + this.getNodeWidth(d.source, showProperties, showMethods, showInitializers) / 2)
                        .attr('y1', d => d.source.y + this.getNodeHeight(d.source, showProperties, showMethods, showInitializers) / 2)
                        .attr('x2', d => d.target.x + this.getNodeWidth(d.target, showProperties, showMethods, showInitializers) / 2)
                        .attr('y2', d => d.target.y + this.getNodeHeight(d.target, showProperties, showMethods, showInitializers) / 2);
                    
                    node.attr('transform', d => `translate(${d.x},${d.y})`);
                });
            }
            
            getNodeWidth(node, showProperties, showMethods, showInitializers) {
                let width = 180;
                if (showProperties && node.type.properties?.length > 0) width += 20;
                if (showMethods && node.type.methods?.length > 0) width += 20;
                if (showInitializers && node.type.initializers?.length > 0) width += 20;
                return Math.max(width, node.type.name.length * 8 + 40);
            }
            
            getNodeHeight(node, showProperties, showMethods, showInitializers) {
                let height = 60;
                if (showProperties && node.type.properties?.length > 0) {
                    height += Math.min(node.type.properties.length * 15, 80);
                }
                if (showMethods && node.type.methods?.length > 0) {
                    height += Math.min(node.type.methods.length * 15, 80);
                }
                if (showInitializers && node.type.initializers?.length > 0) {
                    height += Math.min(node.type.initializers.length * 15, 80);
                }
                return height;
            }
            
            addNodeContent(nodeSelection, showProperties, showMethods, showInitializers) {
                // Add title
                nodeSelection.append('text')
                    .attr('class', 'node-text node-title')
                    .attr('x', d => this.getNodeWidth(d, showProperties, showMethods, showInitializers) / 2)
                    .attr('y', 20)
                    .text(d => d.type.name);
                
                // Add type indicator
                nodeSelection.append('text')
                    .attr('class', 'node-text node-type')
                    .attr('x', d => this.getNodeWidth(d, showProperties, showMethods, showInitializers) / 2)
                    .attr('y', 35)
                    .text(d => `<<${d.type.kind}>>`);
                
                // Add details
                nodeSelection.append('text')
                    .attr('class', 'node-text node-details')
                    .attr('x', d => this.getNodeWidth(d, showProperties, showMethods, showInitializers) / 2)
                    .attr('y', 50)
                    .text(d => {
                        const propCount = d.type.properties?.length || 0;
                        const methodCount = d.type.methods?.length || 0;
                        const initCount = d.type.initializers?.length || 0;
                        return `${propCount}p, ${methodCount}m, ${initCount}i`;
                    });
            }
            
            handleDragStart(event, d) {
                if (!event.active) this.simulation.alphaTarget(0.3).restart();
                d.fx = d.x;
                d.fy = d.y;
            }
            
            handleDrag(event, d) {
                d.fx = event.x;
                d.fy = event.y;
            }
            
            handleDragEnd(event, d) {
                if (!event.active) this.simulation.alphaTarget(0);
                d.fx = null;
                d.fy = null;
            }
            
            selectNode(node) {
                this.selectedNode = node;
                d3.selectAll('.node').classed('selected', false);
                d3.selectAll('.node').filter(d => d.type.name === node.type.name).classed('selected', true);
                this.showTypeDetails(node);
            }
            
            updateTypeList(nodes) {
                const typeList = d3.select('#type-list');
                const items = typeList.selectAll('.type-item')
                    .data(nodes, d => d.type.name);
                
                const itemsEnter = items.enter()
                    .append('div')
                    .attr('class', 'type-item');
                
                itemsEnter.append('div')
                    .attr('class', 'type-item-name');
                
                itemsEnter.append('div')
                    .attr('class', 'type-item-kind');
                
                const itemsUpdate = itemsEnter.merge(items);
                
                itemsUpdate.select('.type-item-name')
                    .text(d => d.type.name);
                
                itemsUpdate.select('.type-item-kind')
                    .text(d => d.type.kind);
                
                itemsUpdate.on('click', (event, d) => this.selectNode(d));
                
                items.exit().remove();
            }
            
            showTypeDetails(node) {
                const details = d3.select('#type-details');
                details.html('');
                
                const container = details.append('div').attr('class', 'type-details');
                
                container.append('h4').text(node.type.name);
                
                container.append('div')
                    .attr('class', `access-level ${node.type.accessLevel}`)
                    .text(node.type.accessLevel);
                
                container.append('p').text(`Type: ${node.type.kind}`);
                
                if (node.type.conformedProtocols?.length > 0) {
                    container.append('h5').text('Conforms to:');
                    const list = container.append('ul');
                    node.type.conformedProtocols.forEach(protocol => {
                        list.append('li').text(protocol);
                    });
                }
                
                if (node.type.initializers?.length > 0) {
                    container.append('h5').text('Initializers:');
                    const list = container.append('ul');
                    node.type.initializers.forEach(init => {
                        const params = init.parameters?.map(p => `${p.name}: ${p.typeName}`).join(', ') || '';
                        const signature = `init(${params})`;
                        list.append('li').text(signature);
                    });
                }
                
                if (node.type.properties?.length > 0) {
                    container.append('h5').text('Properties:');
                    const list = container.append('ul');
                    node.type.properties.forEach(prop => {
                        const propType = prop.isLet ? 'let' : 'var';
                        const propText = `${propType} ${prop.name}: ${prop.typeName}`;
                        list.append('li').text(propText);
                    });
                }
                
                if (node.type.methods?.length > 0) {
                    container.append('h5').text('Methods:');
                    const list = container.append('ul');
                    node.type.methods.forEach(method => {
                        const params = method.parameters?.map(p => `${p.name}: ${p.typeName}`).join(', ') || '';
                        const returnType = method.returnType ? ` -> ${method.returnType}` : '';
                        const signature = `${method.name}(${params})${returnType}`;
                        list.append('li').text(signature);
                    });
                }
            }
        }
        
        // Initialize visualization when DOM is ready
        document.addEventListener('DOMContentLoaded', () => {
            if (typeof graphData !== 'undefined') {
                new SwiftDiagramVisualization(graphData);
            } else {
                console.error('Graph data not found');
            }
        });
        """
    }
}