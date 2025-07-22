// UI references
const searchInput = document.getElementById("search");
const resultsContainer = document.getElementById("search-results");

// Create resizable side panel
const sidePanel = document.createElement("div");
sidePanel.id = "side-panel";
Object.assign(sidePanel.style, {
  position: "absolute",
  top: "0",
  right: "0",
  width: "300px",
  height: "100vh",
  backgroundColor: "#f9f9f9",
  borderLeft: "1px solid #ccc",
  overflowY: "auto",
  padding: "10px",
  boxSizing: "border-box",
  zIndex: "1000",
  fontFamily: "Arial, sans-serif",
  fontSize: "14px",
  resize: "horizontal",
  minWidth: "200px",
  maxWidth: "600px",
});
document.body.appendChild(sidePanel);

// Style search results overlay
resultsContainer.style.position = "absolute";
resultsContainer.style.zIndex = "1100";
resultsContainer.style.backgroundColor = "#fff";
resultsContainer.style.border = "1px solid #ccc";
resultsContainer.style.maxHeight = "200px";
resultsContainer.style.overflowY = "auto";
resultsContainer.style.width = "200px";

// Data structures
let cy;
const nodeMap = new Map();
const edgeMap = new Map();
const visitedNodes = new Set();

// Wait for plugin registration before initializing
function initializeGraph() {
  // Check if cola layout is available
  if (typeof cytoscape !== 'undefined' && cytoscape('layout', 'cola')) {
    console.log('Cola layout available, initializing graph...');
    
    // Fetch and initialize graph data with cache-busting
    const cacheBuster = Date.now();
    fetch(`complex_system.json?v=${cacheBuster}`)
      .then((res) => {
        console.log('Fetch response:', {
          status: res.status,
          statusText: res.statusText,
          headers: Object.fromEntries(res.headers.entries())
        });
        
        if (!res.ok) {
          throw new Error(`HTTP error! status: ${res.status}`);
        }
        
        // Check content type
        const contentType = res.headers.get('content-type');
        if (!contentType || !contentType.includes('application/json')) {
          console.warn('Unexpected content type:', contentType);
        }
        
        return res.text(); // Get as text first to debug
      })
      .then((text) => {
        console.log('Raw response (first 200 chars):', text.substring(0, 200));
        
        // Try to parse as JSON
        try {
          const data = JSON.parse(text);
          preprocessGraph(data);
          const seedNodeId = [...nodeMap.keys()][0];
          const initial = expandNode(seedNodeId, 1);
          renderWithCytoscape(initial);
          setupSearch();
        } catch (parseError) {
          console.error('JSON parse error:', parseError);
          console.error('Response was not valid JSON. Full response:', text);
          throw new Error('Server returned invalid JSON');
        }
      })
      .catch((error) => {
        console.error('Error loading graph data:', error);
        alert(`Error loading graph data: ${error.message}\nCheck console for details.`);
      });
  } else {
    console.log('Cola layout not yet available, retrying...');
    setTimeout(initializeGraph, 100);
  }
}

// Start initialization
initializeGraph();

function preprocessGraph(data) {
  data.nodes.forEach((node) => {
    const id = node.type?.name || node.type?.kind || JSON.stringify(node.type);
    nodeMap.set(id, {
      data: { id, label: id, ...node.type, relationships: node.relationships || [] },
      relationships: node.relationships || [],
    });

    (node.relationships || []).forEach((rel) => {
      const edgeId = `${rel.from}->${rel.to}`;
      edgeMap.set(edgeId, {
        data: {
          id: edgeId,
          source: rel.from,
          target: rel.to,
          label: rel.kind,
        },
      });
    });
  });
}

function expandNode(nodeId, depth = 1) {
  const nodes = [];
  const edges = [];
  const queue = [{ id: nodeId, depth }];
  const discovered = new Set();

  while (queue.length > 0) {
    const { id, depth: d } = queue.shift();
    if (visitedNodes.has(id)) continue;

    visitedNodes.add(id);
    discovered.add(id);

    const nodeData = nodeMap.get(id);
    if (!nodeData) {
      nodes.push({ data: { id, label: id } });
      continue;
    }

    nodes.push({ data: nodeData.data });

    if (d > 0) {
      for (const rel of nodeData.relationships) {
        if (!visitedNodes.has(rel.to) && !discovered.has(rel.to)) {
          queue.push({ id: rel.to, depth: d - 1 });
        }
      }
    }
  }

  // Add edges only if both nodes exist in discovered set
  for (const edge of edgeMap.values()) {
    if (discovered.has(edge.data.source) && discovered.has(edge.data.target)) {
      edges.push(edge);
    }
  }

  return { nodes, edges };
}

function renderWithCytoscape(graph) {
  cy = cytoscape({
    container: document.getElementById("cy"),
    elements: [...graph.nodes, ...graph.edges],
    style: [
      {
        selector: "node",
        style: {
          "background-color": "#4285F4",
          label: "data(label)",
          color: "white",
          "font-size": 14,
          "text-valign": "center",
          "text-halign": "center",
          shape: "roundrectangle",
          padding: "10px",
          "text-wrap": "wrap",
          "text-max-width": 150,
          width: "label",
          height: "label",
          "min-width": 80,
          "min-height": 40,
          "border-color": "#3367D6",
          "border-width": 2,
        },
      },
      {
        selector: "edge",
        style: {
          width: 2,
          "line-color": "#888",
          "target-arrow-color": "#888",
          "target-arrow-shape": "triangle",
          "curve-style": "bezier",
        },
      },
      {
        selector: ".highlighted",
        style: {
          "background-color": "#EA4335",
          "line-color": "#EA4335",
          "target-arrow-color": "#EA4335",
          color: "yellow",
        },
      },
      {
        selector: ":selected",
        style: {
          "background-color": "#EA4335",
          "line-color": "#EA4335",
          "target-arrow-color": "#EA4335",
          "source-arrow-color": "#EA4335",
        },
      },
    ],
    layout: {
      name: "cola",
      nodeSpacing: 50,
      edgeLengthVal: 150,
      animate: true,
      randomize: false,
      fit: true,
      padding: 30,
    },
    wheelSensitivity: 0.2,
  });

  cy.on("tap", "node", (evt) => {
    const nodeId = evt.target.id();
    const more = expandNode(nodeId, 1);
    cy.batch(() => {
      cy.add([...more.nodes, ...more.edges]);
      cy.layout({ name: "cola", animate: true, randomize: false }).run();
    });
    focusNode(nodeId);
  });

  cy.ready(() => cy.fit());
}

function setupSearch() {
  searchInput.addEventListener("input", () => {
    const query = searchInput.value.toLowerCase();
    resultsContainer.innerHTML = "";

    for (let [id] of nodeMap.entries()) {
      if (id.toLowerCase().includes(query)) {
        const item = document.createElement("div");
        item.textContent = id;
        item.style.cursor = "pointer";
        item.style.padding = "4px 8px";
        item.style.borderBottom = "1px solid #ddd";
        item.addEventListener("click", () => {
          // Add expanded nodes & edges then focus
          const more = expandNode(id, 1);
          cy.batch(() => {
            cy.add([...more.nodes, ...more.edges]);
            cy.layout({ name: "cola", animate: true, randomize: false }).run();
          });
          focusNode(id, { adjustForPanel: true });
          resultsContainer.innerHTML = ""; // Close results on click
          searchInput.value = id; // Update input value
        });
        resultsContainer.appendChild(item);
      }
    }
  });

  searchInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      const firstMatch = resultsContainer.querySelector("div");
      if (firstMatch) {
        const id = firstMatch.textContent;
        const more = expandNode(id, 1);
        cy.batch(() => {
          cy.add([...more.nodes, ...more.edges]);
          cy.layout({ name: "cola", animate: true, randomize: false }).run();
        });
        focusNode(id);
        resultsContainer.innerHTML = "";
      }
    }
  });
}

function focusNode(nodeId, options = {}) {
  const node = cy.getElementById(nodeId);
  if (!node || node.empty()) return;

  cy.elements().removeClass("highlighted");
  node.addClass("highlighted");
  node.connectedEdges().addClass("highlighted");
  node.successors("node").addClass("highlighted");
  node.predecessors("node").addClass("highlighted");

  centerNodeInView(node, options);
  renderSidePanel(node);
}


function centerNodeInView(node, { adjustForPanel = false } = {}) {
  const zoom = 1.5;
  const pos = node.position();

  const container = cy.container();
  const rect = container.getBoundingClientRect();
  const containerWidth = rect.width;
  const containerHeight = rect.height;

  const panelOffset = adjustForPanel ? 150 : 0; // shift center left by half the panel width
  const panX = containerWidth / 2 - pos.x * zoom - panelOffset;
  const panY = containerHeight / 2 - pos.y * zoom;

  console.group("centerNodeInView Debug");
  console.log("Node position:", pos);
  console.log("Container rect:", rect);
  console.log("Adjust for panel:", adjustForPanel);
  console.log("Container width:", containerWidth);
  console.log("Container height:", containerHeight);
  console.log("Zoom:", zoom);
  console.log("Calculated panX:", panX);
  console.log("Calculated panY:", panY);
  console.groupEnd();

  cy.animate({
    pan: { x: panX, y: panY },
    zoom,
    duration: 600
  });
}




function renderSidePanel(node) {
  sidePanel.innerHTML = "";

  const data = node.data();

  // Title
  const title = document.createElement("h2");
  title.textContent = data.name || data.label || node.id();
  sidePanel.appendChild(title);

  function createSection(titleText) {
    const section = document.createElement("div");
    section.style.marginBottom = "15px";
    const heading = document.createElement("h3");
    heading.textContent = titleText;
    section.appendChild(heading);
    return section;
  }

  sidePanel.style.whiteSpace = "normal";
  sidePanel.style.wordBreak = "break-word";

  // Basic Info
  const basicInfoSection = createSection("Basic Info");
  if (data.accessLevel) {
    const p = document.createElement("p");
    p.textContent = `Access Level: ${data.accessLevel}`;
    basicInfoSection.appendChild(p);
  }
  if (data.kind) {
    const p = document.createElement("p");
    p.textContent = `Kind: ${data.kind}`;
    basicInfoSection.appendChild(p);
  }
  if (data.location) {
    const p = document.createElement("p");
    p.textContent = `Location: ${data.location.file}:${data.location.line}:${data.location.column}`;
    basicInfoSection.appendChild(p);
  }
  sidePanel.appendChild(basicInfoSection);

  // Inheritance
  const inheritanceSection = createSection("Inheritance");
  if (Array.isArray(data.inheritedTypes) && data.inheritedTypes.length > 0) {
    const ul = document.createElement("ul");
    data.inheritedTypes.forEach((type) => {
      const li = document.createElement("li");
      li.textContent = type;
      ul.appendChild(li);
    });
    inheritanceSection.appendChild(ul);
  } else {
    const p = document.createElement("p");
    p.textContent = "None";
    inheritanceSection.appendChild(p);
  }
  sidePanel.appendChild(inheritanceSection);

  // Conformed Protocols
  const protocolsSection = createSection("Conformed Protocols");
  if (Array.isArray(data.conformedProtocols) && data.conformedProtocols.length > 0) {
    const ul = document.createElement("ul");
    data.conformedProtocols.forEach((protocol) => {
      const li = document.createElement("li");
      li.textContent = protocol;
      ul.appendChild(li);
    });
    protocolsSection.appendChild(ul);
  } else {
    const p = document.createElement("p");
    p.textContent = "None";
    protocolsSection.appendChild(p);
  }
  sidePanel.appendChild(protocolsSection);

  // Associated Types
  const associatedTypesSection = createSection("Associated Types");
  if (Array.isArray(data.associatedTypes) && data.associatedTypes.length > 0) {
    const ul = document.createElement("ul");
    data.associatedTypes.forEach((type) => {
      const li = document.createElement("li");
      li.textContent = type;
      ul.appendChild(li);
    });
    associatedTypesSection.appendChild(ul);
  } else {
    const p = document.createElement("p");
    p.textContent = "None";
    associatedTypesSection.appendChild(p);
  }
  sidePanel.appendChild(associatedTypesSection);

  // Properties (name and type)
  const propertiesSection = createSection("Properties");
  if (Array.isArray(data.properties) && data.properties.length > 0) {
    const ul = document.createElement("ul");
    data.properties.forEach((prop) => {
      const li = document.createElement("li");
      li.textContent = `${prop.name}: ${prop.typeName}`;
      ul.appendChild(li);
    });
    propertiesSection.appendChild(ul);
  } else {
    const p = document.createElement("p");
    p.textContent = "None";
    propertiesSection.appendChild(p);
  }
  sidePanel.appendChild(propertiesSection);

  // Methods
  const methodsSection = createSection("Methods");
  if (Array.isArray(data.methods) && data.methods.length > 0) {
    const ul = document.createElement("ul");
    data.methods.forEach((m) => {
      const li = document.createElement("li");
      const params = m.parameters
        ?.map((p) => `${p.name}: ${p.typeName}`)
        .join(", ") || "";
      li.textContent = `${m.accessLevel || "?"} func ${m.name}(${params})${
        m.returnTypeName ? ` -> ${m.returnTypeName}` : ""
      }`;
      ul.appendChild(li);
    });
    methodsSection.appendChild(ul);
  } else {
    const p = document.createElement("p");
    p.textContent = "None";
    methodsSection.appendChild(p);
  }
  sidePanel.appendChild(methodsSection);

  // Relationships (Parents/Children)
  function createRelationshipSection(titleText, neighbors) {
    const section = createSection(titleText);
    if (!neighbors || neighbors.length === 0) {
      const p = document.createElement("p");
      p.textContent = "None";
      section.appendChild(p);
      return section;
    }
    const ul = document.createElement("ul");
    neighbors.forEach((n) => {
      const li = document.createElement("li");
      li.textContent = n.data("label");
      li.style.cursor = "pointer";
      li.style.color = "#3367D6";
      li.addEventListener("click", () => {
        const more = expandNode(n.id(), 1);
        cy.batch(() => {
          cy.add([...more.nodes, ...more.edges]);
          cy.layout({ name: "cola", animate: true, randomize: false }).run();
        });
        focusNode(n.id());
      });
      ul.appendChild(li);
    });
    section.appendChild(ul);
    return section;
  }

  sidePanel.appendChild(createRelationshipSection("Parents", node.predecessors("node")));
  sidePanel.appendChild(createRelationshipSection("Children", node.successors("node")));
}
