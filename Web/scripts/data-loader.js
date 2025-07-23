// Data loading and management utilities
class DataLoader {
    constructor() {
        this.setupFileUpload();
        this.setupFileSelector();
        this.loadAvailableFiles();
    }
    
    setupFileUpload() {
        const uploadArea = document.getElementById('file-upload-area');
        const fileInput = document.getElementById('file-upload-input');
        
        if (uploadArea && fileInput) {
            // File drop handling
            uploadArea.addEventListener('dragover', (e) => {
                e.preventDefault();
                uploadArea.classList.add('dragover');
            });
            
            uploadArea.addEventListener('dragleave', (e) => {
                e.preventDefault();
                uploadArea.classList.remove('dragover');
            });
            
            uploadArea.addEventListener('drop', (e) => {
                e.preventDefault();
                uploadArea.classList.remove('dragover');
                const files = e.dataTransfer.files;
                if (files.length > 0) {
                    this.handleFileUpload(files[0]);
                }
            });
            
            // Click to upload
            uploadArea.addEventListener('click', () => {
                fileInput.click();
            });
            
            fileInput.addEventListener('change', (e) => {
                if (e.target.files.length > 0) {
                    this.handleFileUpload(e.target.files[0]);
                }
            });
        }
    }
    
    setupFileSelector() {
        const loadButton = document.getElementById('load-json-button');
        
        if (loadButton) {
            loadButton.addEventListener('click', () => {
                const selector = document.getElementById('json-file-selector');
                const selectedFile = selector.value;
                
                if (selectedFile) {
                    this.loadJSONFile(selectedFile);
                }
            });
        }
    }
    
    async loadAvailableFiles() {
        try {
            // Try to load a list of available JSON files
            const availableFiles = [
                'example_analysis.json',
                'extension_test.json',
                'comprehensive_test_analysis.json',
                'testproject_analysis.json',
                'ComprehensiveExample_result.json'
            ];
            
            const selector = document.getElementById('json-file-selector');
            if (selector) {
                selector.innerHTML = '<option value="">Select a JSON file...</option>';
                
                for (const file of availableFiles) {
                    // Check if file exists
                    try {
                        const response = await fetch(file, { method: 'HEAD' });
                        if (response.ok) {
                            const option = document.createElement('option');
                            option.value = file;
                            option.textContent = this.formatFileName(file);
                            selector.appendChild(option);
                        }
                    } catch (e) {
                        // File doesn't exist, skip
                    }
                }
            }
        } catch (error) {
            console.error('Error loading available files:', error);
        }
    }
    
    formatFileName(fileName) {
        return fileName
            .replace('.json', '')
            .replace(/_/g, ' ')
            .replace(/\b\w/g, l => l.toUpperCase());
    }
    
    async handleFileUpload(file) {
        if (!file.name.endsWith('.json')) {
            this.showError('Please select a JSON file.');
            return;
        }
        
        this.showLoading(true);
        
        try {
            const text = await file.text();
            const data = JSON.parse(text);
            this.validateAndLoadData(data);
        } catch (error) {
            this.showError(`Error reading file: ${error.message}`);
        } finally {
            this.showLoading(false);
        }
    }
    
    async loadJSONFile(fileName) {
        this.showLoading(true);
        
        try {
            const response = await fetch(fileName);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            const data = await response.json();
            this.validateAndLoadData(data);
        } catch (error) {
            this.showError(`Error loading ${fileName}: ${error.message}`);
        } finally {
            this.showLoading(false);
        }
    }
    
    validateAndLoadData(data) {
        // Validate data structure
        if (!data || !data.nodes || !Array.isArray(data.nodes)) {
            throw new Error('Invalid data format: Expected object with "nodes" array');
        }
        
        // Basic validation of node structure
        for (const node of data.nodes) {
            if (!node.type || !node.type.name) {
                throw new Error('Invalid node structure: Each node must have type.name');
            }
        }
        
        // Hide upload area and show diagram
        this.hideUploadArea();
        
        // Initialize the diagram with new data
        this.initializeDiagram(data);
    }
    
    hideUploadArea() {
        const uploadArea = document.getElementById('file-upload-area');
        const jsonSelector = document.querySelector('.json-selector');
        
        if (uploadArea) uploadArea.style.display = 'none';
        if (jsonSelector) jsonSelector.style.display = 'none';
    }
    
    showUploadArea() {
        const uploadArea = document.getElementById('file-upload-area');
        const jsonSelector = document.querySelector('.json-selector');
        
        if (uploadArea) uploadArea.style.display = 'block';
        if (jsonSelector) jsonSelector.style.display = 'flex';
    }
    
    initializeDiagram(data) {
        // Initialize enhanced UI features
        if (typeof EnhancedUI !== 'undefined') {
            new EnhancedUI();
        }
        
        // Initialize the main diagram visualization
        if (typeof SwiftDiagramVisualization !== 'undefined') {
            window.diagramVisualization = new SwiftDiagramVisualization(data);
        } else {
            this.showError('Diagram visualization not available');
        }
    }
    
    showError(message) {
        const existingError = document.querySelector('.error-message');
        if (existingError) {
            existingError.remove();
        }
        
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error-message';
        errorDiv.textContent = message;
        
        const container = document.querySelector('.main-content') || document.body;
        container.insertBefore(errorDiv, container.firstChild);
        
        // Auto-hide after 5 seconds
        setTimeout(() => {
            if (errorDiv.parentNode) {
                errorDiv.parentNode.removeChild(errorDiv);
            }
        }, 5000);
    }
    
    showLoading(show) {
        const loadButton = document.getElementById('load-json-button');
        if (loadButton) {
            if (show) {
                loadButton.innerHTML = '<span class="loading-spinner"></span> Loading...';
                loadButton.disabled = true;
            } else {
                loadButton.innerHTML = 'Load JSON';
                loadButton.disabled = false;
            }
        }
    }
    
    // Reset to upload state
    reset() {
        this.showUploadArea();
        
        // Clear existing diagram
        const diagram = document.getElementById('diagram');
        if (diagram) {
            diagram.innerHTML = '';
        }
        
        // Clear sidebar
        const typeList = document.getElementById('type-list');
        const typeDetails = document.getElementById('type-details');
        if (typeList) typeList.innerHTML = '';
        if (typeDetails) typeDetails.innerHTML = '';
    }
}