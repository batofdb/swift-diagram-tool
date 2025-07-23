class SwiftDiagramVisualization {
    constructor(data) {
        this.data = data;
        this.svg = d3.select('#diagram');
        this.container = this.svg.append('g');
        this.selectedNode = null;
        this.simulation = null;
        this.currentTheme = 'light';
        
        // Performance optimization properties
        this.renderDebounceTimer = null;
        this.isRendering = false;
        this.pendingRenderRequests = 0;
        this.lastRenderTime = 0;
        this.targetFPS = 60;
        this.frameTime = 1000 / this.targetFPS;
        this.performanceMetrics = {
            renderCount: 0,
            averageRenderTime: 0,
            lastFrameTimes: []
        };
        
        this.zoom = d3.zoom()
            .scaleExtent([0.1, 3])
            .on('zoom', this.handleZoom.bind(this));
        
        this.svg.call(this.zoom);
        this.setupEventListeners();
        this.setupDefinitions();
        this.debouncedRender();
    }
    
    setupEventListeners() {
        d3.select('#reset-zoom').on('click', () => this.resetZoom());
        d3.select('#toggle-theme').on('click', () => this.toggleTheme());
        
        // Original search input (keep for sidebar functionality)
        d3.select('#search-input').on('input', (e) => this.handleSearch(e.target.value));
        
        // New diagram search input
        d3.select('#diagram-search-input').on('input', (e) => this.handleDiagramSearch(e.target.value));
        d3.select('#diagram-search-input').on('focus', () => this.showSearchResults());
        d3.select('#diagram-search-input').on('blur', () => {
            // Delay hiding to allow clicking on results
            setTimeout(() => this.hideSearchResults(), 150);
        });
        
        d3.select('#show-properties').on('change', () => this.debouncedRender());
        d3.select('#show-methods').on('change', () => this.debouncedRender());
        d3.select('#show-initializers').on('change', () => this.debouncedRender());
        d3.select('#show-private').on('change', () => this.debouncedRender());
        
        // Close search results when clicking outside
        d3.select('body').on('click', (event) => {
            if (!event.target.closest('.diagram-search-bar')) {
                this.hideSearchResults();
            }
        });
        
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
                        d3.select('#diagram-search-input').node().focus();
                        break;
                }
            }
            
            // ESC to close search results
            if (event.key === 'Escape') {
                this.hideSearchResults();
                d3.select('#diagram-search-input').node().blur();
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
        
        // Use requestAnimationFrame for smoother UI updates
        requestAnimationFrame(() => {
            this.updateTypeList(filtered);
            
            // Highlight matching nodes in the diagram
            this.container.selectAll('.node')
                .classed('search-highlight', d => 
                    query && filtered.some(f => f.type.name === d.type.name)
                );
        });
    }
    
    handleDiagramSearch(query) {
        if (!query.trim()) {
            requestAnimationFrame(() => {
                this.hideSearchResults();
                // Remove all highlighting
                this.container.selectAll('.node').classed('search-highlight', false);
            });
            return;
        }
        
        const filtered = this.data.nodes.filter(node => 
            node.type.name.toLowerCase().includes(query.toLowerCase()) ||
            node.type.kind.toLowerCase().includes(query.toLowerCase()) ||
            (node.type.properties && node.type.properties.some(prop => 
                prop.name.toLowerCase().includes(query.toLowerCase())
            )) ||
            (node.type.methods && node.type.methods.some(method => 
                method.name.toLowerCase().includes(query.toLowerCase())
            ))
        );
        
        // Use requestAnimationFrame for smoother UI updates
        requestAnimationFrame(() => {
            this.displaySearchResults(filtered, query);
            
            // Highlight matching nodes in the diagram
            this.container.selectAll('.node')
                .classed('search-highlight', d => 
                    filtered.some(f => f.type.name === d.type.name)
                );
        });
    }
    
    displaySearchResults(results, query) {
        const searchResults = d3.select('#search-results');
        
        if (results.length === 0) {
            searchResults.html('<div class="search-result-item"><div class="search-result-description">No results found</div></div>');
            this.showSearchResults();
            return;
        }
        
        const items = searchResults.selectAll('.search-result-item')
            .data(results.slice(0, 10), d => d.type.name); // Show max 10 results
        
        items.exit().remove();
        
        const itemsEnter = items.enter()
            .append('div')
            .attr('class', 'search-result-item')
            .on('click', (event, d) => this.focusOnNode(d));
        
        const itemsUpdate = itemsEnter.merge(items);
        
        itemsUpdate.html(d => {
            const matchingProps = d.type.properties ? d.type.properties.filter(prop => 
                prop.name.toLowerCase().includes(query.toLowerCase())
            ).slice(0, 3) : [];
            
            const matchingMethods = d.type.methods ? d.type.methods.filter(method => 
                method.name.toLowerCase().includes(query.toLowerCase())
            ).slice(0, 3) : [];
            
            let description = '';
            if (matchingProps.length > 0) {
                description += 'Properties: ' + matchingProps.map(p => p.name).join(', ');
            }
            if (matchingMethods.length > 0) {
                if (description) description += ' • ';
                description += 'Methods: ' + matchingMethods.map(m => m.name).join(', ');
            }
            
            return `
                <div class="search-result-type">${d.type.name}</div>
                <div class="search-result-kind">${d.type.kind}</div>
                ${description ? `<div class="search-result-description">${description}</div>` : ''}
            `;
        });
        
        this.showSearchResults();
    }
    
    showSearchResults() {
        d3.select('#search-results').classed('active', true);
    }
    
    hideSearchResults() {
        d3.select('#search-results').classed('active', false);
    }
    
    focusOnNode(nodeData) {
        // Find the node in the diagram and zoom to it
        const node = this.container.select(`.node[data-name="${nodeData.type.name}"]`).node();
        if (node) {
            const bbox = node.getBBox();
            const centerX = bbox.x + bbox.width / 2;
            const centerY = bbox.y + bbox.height / 2;
            
            // Calculate transform to center the node
            const svg = d3.select('#diagram');
            const svgRect = svg.node().getBoundingClientRect();
            const scale = 1.5;
            const translateX = svgRect.width / 2 - centerX * scale;
            const translateY = svgRect.height / 2 - centerY * scale;
            
            // Apply zoom transform
            svg.transition()
                .duration(750)
                .call(this.zoom.transform, d3.zoomIdentity.translate(translateX, translateY).scale(scale));
            
            // Temporarily highlight the focused node
            d3.select(node).classed('focused-node', true);
            setTimeout(() => {
                d3.select(node).classed('focused-node', false);
            }, 2000);
        }
        
        this.hideSearchResults();
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
    
    // Debounced rendering for performance optimization
    debouncedRender(delay = 100) {
        // Cancel any pending render
        if (this.renderDebounceTimer) {
            clearTimeout(this.renderDebounceTimer);
        }
        
        this.pendingRenderRequests++;
        
        this.renderDebounceTimer = setTimeout(() => {
            this.performOptimizedRender();
        }, delay);
    }
    
    performOptimizedRender() {
        // Prevent multiple simultaneous renders
        if (this.isRendering) {
            // Queue another render if needed
            if (this.pendingRenderRequests > 1) {
                this.debouncedRender(50);
            }
            return;
        }
        
        const currentTime = performance.now();
        const timeSinceLastRender = currentTime - this.lastRenderTime;
        
        // Throttle rendering to maintain target FPS
        if (timeSinceLastRender < this.frameTime) {
            setTimeout(() => this.performOptimizedRender(), this.frameTime - timeSinceLastRender);
            return;
        }
        
        this.isRendering = true;
        this.pendingRenderRequests = 0;
        this.lastRenderTime = currentTime;
        
        // Use requestAnimationFrame for smoother rendering
        requestAnimationFrame(() => {
            this.render();
            this.isRendering = false;
            
            // Handle any pending render requests
            if (this.pendingRenderRequests > 0) {
                this.debouncedRender(16); // ~60fps
            }
        });
    }
    
    render() {
        const renderStart = performance.now();
        
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
        
        // Track performance metrics
        const renderTime = performance.now() - renderStart;
        this.updatePerformanceMetrics(renderTime);
    }
    
    updatePerformanceMetrics(renderTime) {
        this.performanceMetrics.renderCount++;
        this.performanceMetrics.lastFrameTimes.push(renderTime);
        
        // Keep only last 60 frame times for rolling average
        if (this.performanceMetrics.lastFrameTimes.length > 60) {
            this.performanceMetrics.lastFrameTimes.shift();
        }
        
        // Calculate rolling average
        const sum = this.performanceMetrics.lastFrameTimes.reduce((a, b) => a + b, 0);
        this.performanceMetrics.averageRenderTime = sum / this.performanceMetrics.lastFrameTimes.length;
        
        // Log performance warnings for slow renders
        if (renderTime > 100) {
            console.warn(`Slow render detected: ${renderTime.toFixed(2)}ms (Average: ${this.performanceMetrics.averageRenderTime.toFixed(2)}ms)`);
        }
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
            .attr('data-name', d => d.type.name)
            .attr('width', d => this.getNodeWidth(d, showProperties, showMethods, showInitializers))
            .attr('height', d => this.getNodeHeight(d, showProperties, showMethods, showInitializers))
            .attr('rx', 8)
            .attr('ry', 8)
            .attr('fill', d => this.getNodeColor(d.type.kind))
            .on('click', (event, d) => this.selectNode(d));
        
        // Add node content
        this.addNodeContent(node, showProperties, showMethods, showInitializers);
        
        // Optimized simulation tick handler with requestAnimationFrame
        let tickRequestId = null;
        this.simulation.on('tick', () => {
            // Cancel previous frame request if still pending
            if (tickRequestId) {
                cancelAnimationFrame(tickRequestId);
            }
            
            // Use requestAnimationFrame for smoother animations
            tickRequestId = requestAnimationFrame(() => {
                link
                    .attr('x1', d => d.source.x + this.getNodeWidth(d.source, showProperties, showMethods, showInitializers) / 2)
                    .attr('y1', d => d.source.y + this.getNodeHeight(d.source, showProperties, showMethods, showInitializers) / 2)
                    .attr('x2', d => d.target.x + this.getNodeWidth(d.target, showProperties, showMethods, showInitializers) / 2)
                    .attr('y2', d => d.target.y + this.getNodeHeight(d.target, showProperties, showMethods, showInitializers) / 2);
                
                node.attr('transform', d => `translate(${d.x},${d.y})`);
                tickRequestId = null;
            });
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