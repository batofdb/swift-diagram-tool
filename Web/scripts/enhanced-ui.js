// Enhanced UI functionality
class EnhancedUI {
    constructor() {
        this.setupSidebarToggle();
        this.setupFloatingControls();
        this.setupThemeToggle();
        this.setupKeyboardShortcuts();
        this.setupResponsiveFeatures();
    }
    
    setupSidebarToggle() {
        const sidebarToggle = document.querySelector('.sidebar-toggle');
        const sidebar = document.querySelector('.sidebar');
        
        if (sidebarToggle && sidebar) {
            sidebarToggle.addEventListener('click', () => {
                sidebar.classList.toggle('collapsed');
                // Update toggle icon
                sidebarToggle.textContent = sidebar.classList.contains('collapsed') ? '⚆' : '⚇';
            });
        }
        
        // Mobile sidebar toggle
        if (window.innerWidth <= 768) {
            sidebarToggle?.addEventListener('click', () => {
                sidebar?.classList.toggle('open');
            });
        }
    }
    
    setupFloatingControls() {
        const zoomInBtn = document.getElementById('zoom-in');
        const zoomOutBtn = document.getElementById('zoom-out');
        const fitToScreenBtn = document.getElementById('fit-to-screen');
        const resetZoomBtn = document.getElementById('reset-zoom');
        
        // Add click handlers for zoom controls
        zoomInBtn?.addEventListener('click', () => {
            // Trigger zoom in on the diagram
            const event = new CustomEvent('zoom-in');
            document.dispatchEvent(event);
        });
        
        zoomOutBtn?.addEventListener('click', () => {
            const event = new CustomEvent('zoom-out');
            document.dispatchEvent(event);
        });
        
        fitToScreenBtn?.addEventListener('click', () => {
            const event = new CustomEvent('fit-to-screen');
            document.dispatchEvent(event);
        });
        
        resetZoomBtn?.addEventListener('click', () => {
            const event = new CustomEvent('reset-zoom');
            document.dispatchEvent(event);
        });
    }
    
    setupThemeToggle() {
        const themeToggle = document.getElementById('toggle-theme');
        const html = document.documentElement;
        
        // Load saved theme
        const savedTheme = localStorage.getItem('diagram-theme') || 'light';
        html.className = `${savedTheme}-theme`;
        
        themeToggle?.addEventListener('click', () => {
            const currentTheme = html.className.includes('dark') ? 'dark' : 'light';
            const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
            
            html.className = `${newTheme}-theme`;
            localStorage.setItem('diagram-theme', newTheme);
            
            // Update button text
            themeToggle.innerHTML = newTheme === 'dark' ? '☀️ Light Mode' : '🌙 Dark Mode';
        });
        
        // Set initial button text
        if (themeToggle) {
            themeToggle.innerHTML = savedTheme === 'dark' ? '☀️ Light Mode' : '🌙 Dark Mode';
        }
    }
    
    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Ctrl/Cmd + F: Focus search
            if ((e.ctrlKey || e.metaKey) && e.key === 'f') {
                e.preventDefault();
                const searchInput = document.getElementById('diagram-search-input');
                searchInput?.focus();
            }
            
            // R: Reset zoom
            if (e.key === 'r' || e.key === 'R') {
                if (!e.target.matches('input, textarea')) {
                    e.preventDefault();
                    document.dispatchEvent(new CustomEvent('reset-zoom'));
                }
            }
            
            // +/=: Zoom in
            if (e.key === '+' || e.key === '=') {
                if (!e.target.matches('input, textarea')) {
                    e.preventDefault();
                    document.dispatchEvent(new CustomEvent('zoom-in'));
                }
            }
            
            // -: Zoom out
            if (e.key === '-') {
                if (!e.target.matches('input, textarea')) {
                    e.preventDefault();
                    document.dispatchEvent(new CustomEvent('zoom-out'));
                }
            }
            
            // Escape: Clear search
            if (e.key === 'Escape') {
                const searchInputs = document.querySelectorAll('#search-input, #diagram-search-input');
                searchInputs.forEach(input => {
                    input.value = '';
                    input.dispatchEvent(new Event('input'));
                });
            }
            
            // T: Toggle theme
            if (e.key === 't' || e.key === 'T') {
                if (!e.target.matches('input, textarea')) {
                    e.preventDefault();
                    document.getElementById('toggle-theme')?.click();
                }
            }
        });
    }
    
    setupResponsiveFeatures() {
        // Handle window resize
        window.addEventListener('resize', () => {
            const sidebar = document.querySelector('.sidebar');
            const isMobile = window.innerWidth <= 768;
            
            if (isMobile) {
                sidebar?.classList.remove('collapsed');
            } else {
                sidebar?.classList.remove('open');
            }
        });
        
        // Add touch gesture support for mobile
        if ('ontouchstart' in window) {
            this.setupTouchGestures();
        }
    }
    
    setupTouchGestures() {
        const sidebar = document.querySelector('.sidebar');
        const diagramContainer = document.querySelector('.diagram-container');
        let startX, startY;
        
        diagramContainer?.addEventListener('touchstart', (e) => {
            startX = e.touches[0].clientX;
            startY = e.touches[0].clientY;
        });
        
        diagramContainer?.addEventListener('touchend', (e) => {
            if (!startX || !startY) return;
            
            const endX = e.changedTouches[0].clientX;
            const endY = e.changedTouches[0].clientY;
            const deltaX = endX - startX;
            const deltaY = endY - startY;
            
            // Swipe right to open sidebar (mobile)
            if (deltaX > 50 && Math.abs(deltaY) < 100 && window.innerWidth <= 768) {
                sidebar?.classList.add('open');
            }
            
            // Swipe left to close sidebar (mobile)
            if (deltaX < -50 && Math.abs(deltaY) < 100 && window.innerWidth <= 768) {
                sidebar?.classList.remove('open');
            }
            
            startX = startY = null;
        });
    }
}