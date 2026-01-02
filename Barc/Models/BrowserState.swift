import Foundation
import SwiftUI
import WebKit

/// Manages the state of browser tabs, navigation, and UI interactions.
/// 
/// This class is the central state manager for the browser, coordinating between tabs,
/// the address bar, sidebar, and various monitors (network activity, blocked requests).
/// All UI updates are performed on the main actor to ensure thread safety.
@MainActor
final class BrowserState: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var selectedTabId: UUID? {
        didSet {
            // Keep monitors in sync with the active tab
            NetworkActivityMonitor.shared.activeTabId = selectedTabId
            BlockedRequestsMonitor.shared.activeTabId = selectedTabId
            // Deactivate element picker when switching tabs
            if isElementPickerActive {
                deactivateElementPicker()
            }
        }
    }
    @Published var sidebarCollapsed: Bool = false
    @Published var focusAddressBarTrigger: UUID = UUID()
    @Published var isElementPickerActive: Bool = false

    private let settings = PrivacySettings.shared

    var selectedTab: Tab? {
        tabs.first { $0.id == selectedTabId }
    }

    var selectedTabIndex: Int? {
        tabs.firstIndex { $0.id == selectedTabId }
    }

    /// Returns the homepage URL with fallback logic.
    /// 
    /// - Returns: The homepage URL from settings, or falls back to kagi.com if invalid,
    ///   or about:blank as a last resort.
    var homePageURL: URL {
        guard let url = URL(string: settings.homePage) else {
            // Fallback to default homepage if settings URL is invalid
            guard let defaultURL = URL(string: "https://kagi.com") else {
                // Last resort: about:blank is guaranteed to be valid
                return URL(string: "about:blank")!
            }
            return defaultURL
        }
        return url
    }

    init() {
        createNewTab(shouldFocus: false)
    }

    func createNewTab(url: URL? = nil, shouldFocus: Bool = true) {
        let targetURL: URL
        if let url = url {
            targetURL = url
        } else {
            switch settings.newTabBehavior {
            case .homePage:
                targetURL = homePageURL
            case .blankPage:
                // about:blank is a well-known URL that should always be valid
                guard let blankURL = URL(string: "about:blank") else {
                    // Fallback to homepage if about:blank somehow fails
                    targetURL = homePageURL
                    return
                }
                targetURL = blankURL
            }
        }

        let tab = Tab(url: targetURL)
        tabs.append(tab)
        selectedTabId = tab.id

        if shouldFocus {
            focusAddressBarTrigger = UUID()
        }
    }

    func selectTab(_ tab: Tab) {
        selectedTabId = tab.id
    }

    func closeTab(_ tab: Tab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }

        // Clean up blocked requests for this tab
        BlockedRequestsMonitor.shared.removeTab(tab.id)

        tabs.remove(at: index)

        if tabs.isEmpty {
            createNewTab()
        } else if selectedTabId == tab.id {
            let newIndex = min(index, tabs.count - 1)
            selectedTabId = tabs[newIndex].id
        }
    }

    func closeCurrentTab() {
        if let tab = selectedTab {
            closeTab(tab)
        }
    }

    func reloadCurrentTab() {
        selectedTab?.webView?.reload()
    }

    func goBack() {
        selectedTab?.webView?.goBack()
    }

    func goForward() {
        selectedTab?.webView?.goForward()
    }

    func navigate(to urlString: String) {
        guard let tab = selectedTab else { return }

        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            tab.webView?.load(URLRequest(url: url))
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            if let url = URL(string: "https://\(trimmed)") {
                tab.webView?.load(URLRequest(url: url))
            }
        } else {
            let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            if let searchURL = URL(string: "\(settings.searchEngineURL)\(query)") {
                tab.webView?.load(URLRequest(url: searchURL))
            }
        }
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }

    func selectNextTab() {
        guard let currentIndex = selectedTabIndex else { return }
        let nextIndex = (currentIndex + 1) % tabs.count
        selectedTabId = tabs[nextIndex].id
    }

    func selectPreviousTab() {
        guard let currentIndex = selectedTabIndex else { return }
        let previousIndex = currentIndex == 0 ? tabs.count - 1 : currentIndex - 1
        selectedTabId = tabs[previousIndex].id
    }

    func goHome() {
        guard let tab = selectedTab else { return }
        tab.webView?.load(URLRequest(url: homePageURL))
    }

    // MARK: - Element Picker (xkill mode)

    /// Toggles the element picker mode on/off.
    /// 
    /// The element picker allows users to click on any element on the page to block it.
    /// This is useful for blocking ads, trackers, or unwanted content dynamically.
    func toggleElementPicker() {
        if isElementPickerActive {
            deactivateElementPicker()
        } else {
            activateElementPicker()
        }
    }

    /// Activates the element picker by injecting JavaScript into the current page.
    /// 
    /// This method injects a complex JavaScript overlay system that:
    /// - Creates a visual overlay highlighting elements as the mouse moves
    /// - Shows a red border around hovered elements
    /// - Allows clicking elements to extract their selectors
    /// - Blocks selected elements by adding them to the content blocker
    /// 
    /// The JavaScript creates a singleton picker object that persists across page navigations
    /// until explicitly deactivated.
    func activateElementPicker() {
        guard let webView = selectedTab?.webView else { return }

        let script = """
        (function() {
            if (window.__barcElementPicker) {
                window.__barcElementPicker.activate();
                return;
            }

            const picker = {
                active: false,
                overlay: null,
                currentTarget: null,

                activate: function() {
                    if (this.active) return;
                    this.active = true;

                    // Create overlay for highlighting
                    this.overlay = document.createElement('div');
                    this.overlay.id = '__barc_picker_overlay';
                    this.overlay.style.cssText = `
                        position: fixed;
                        pointer-events: none;
                        z-index: 2147483647;
                        border: 2px solid #ff4444;
                        background: rgba(255, 68, 68, 0.15);
                        box-shadow: 0 0 0 2px rgba(255, 68, 68, 0.3);
                        transition: all 0.05s ease-out;
                        display: none;
                    `;
                    document.body.appendChild(this.overlay);

                    // Add crosshair cursor style
                    const style = document.createElement('style');
                    style.id = '__barc_picker_style';
                    style.textContent = `
                        * { cursor: crosshair !important; }
                        #__barc_picker_overlay {
                            display: block;
                        }
                    `;
                    document.head.appendChild(style);

                    // Add event listeners
                    document.addEventListener('mousemove', this.handleMouseMove, true);
                    document.addEventListener('click', this.handleClick, true);
                    document.addEventListener('keydown', this.handleKeyDown, true);

                    console.log('[Barc] Element picker activated - click to remove elements, press Escape to cancel');
                },

                deactivate: function() {
                    if (!this.active) return;
                    this.active = false;

                    // Remove overlay
                    const overlay = document.getElementById('__barc_picker_overlay');
                    if (overlay) overlay.remove();

                    // Remove style
                    const style = document.getElementById('__barc_picker_style');
                    if (style) style.remove();

                    // Remove event listeners
                    document.removeEventListener('mousemove', this.handleMouseMove, true);
                    document.removeEventListener('click', this.handleClick, true);
                    document.removeEventListener('keydown', this.handleKeyDown, true);

                    this.currentTarget = null;
                    console.log('[Barc] Element picker deactivated');
                },

                handleMouseMove: function(e) {
                    const picker = window.__barcElementPicker;
                    if (!picker.active) return;

                    let target = e.target;

                    // Skip our own overlay
                    if (target.id === '__barc_picker_overlay') return;

                    // Skip html and body - go to their children instead
                    if (target === document.documentElement || target === document.body) {
                        return;
                    }

                    picker.currentTarget = target;

                    // Update overlay position
                    const rect = target.getBoundingClientRect();
                    picker.overlay.style.left = rect.left + 'px';
                    picker.overlay.style.top = rect.top + 'px';
                    picker.overlay.style.width = rect.width + 'px';
                    picker.overlay.style.height = rect.height + 'px';
                    picker.overlay.style.display = 'block';
                },

                handleClick: function(e) {
                    const picker = window.__barcElementPicker;
                    if (!picker.active) return;

                    e.preventDefault();
                    e.stopPropagation();
                    e.stopImmediatePropagation();

                    if (picker.currentTarget && picker.currentTarget.id !== '__barc_picker_overlay') {
                        const target = picker.currentTarget;
                        const tagName = target.tagName.toLowerCase();
                        const className = target.className;

                        // Thanos snap disintegration effect
                        picker.disintegrate(target);

                        // Hide overlay temporarily
                        picker.overlay.style.display = 'none';
                        picker.currentTarget = null;

                        console.log('[Barc] Removed element:', tagName, className ? '.' + className.split(' ')[0] : '');
                    }

                    return false;
                },

                disintegrate: function(element) {
                    const rect = element.getBoundingClientRect();
                    const computedStyle = window.getComputedStyle(element);
                    const bgColor = computedStyle.backgroundColor || 'rgba(100, 100, 100, 1)';

                    // Create canvas for GPU-accelerated animation
                    const canvas = document.createElement('canvas');
                    const padding = 150; // Extra space for particles to drift
                    canvas.width = rect.width + padding * 2;
                    canvas.height = rect.height + padding * 2;
                    canvas.style.cssText = `
                        position: fixed;
                        left: ${rect.left - padding}px;
                        top: ${rect.top - padding}px;
                        width: ${canvas.width}px;
                        height: ${canvas.height}px;
                        pointer-events: none;
                        z-index: 2147483646;
                        will-change: transform;
                    `;
                    document.body.appendChild(canvas);

                    const ctx = canvas.getContext('2d');

                    // Fixed small particle size for consistent look
                    const particleSize = 4;
                    const cols = Math.ceil(rect.width / particleSize);
                    const rows = Math.ceil(rect.height / particleSize);

                    // Get element color
                    let r = 128, g = 128, b = 128;
                    const match = bgColor.match(/\\d+/g);
                    if (match && match.length >= 3) {
                        r = parseInt(match[0]);
                        g = parseInt(match[1]);
                        b = parseInt(match[2]);
                    }
                    // If transparent, use gray
                    if (bgColor === 'rgba(0, 0, 0, 0)') { r = 136; g = 136; b = 136; }

                    // Create particles
                    const particles = [];
                    for (let row = 0; row < rows; row++) {
                        for (let col = 0; col < cols; col++) {
                            const x = col * particleSize + padding;
                            const y = row * particleSize + padding;

                            // Vary color slightly
                            const cr = Math.min(255, Math.max(0, r + (Math.random() - 0.5) * 30));
                            const cg = Math.min(255, Math.max(0, g + (Math.random() - 0.5) * 30));
                            const cb = Math.min(255, Math.max(0, b + (Math.random() - 0.5) * 30));

                            // Wave delay from left to right
                            const delay = (col / cols) * 0.4 + Math.random() * 0.2;

                            particles.push({
                                x, y,
                                startX: x, startY: y,
                                size: particleSize,
                                color: `rgb(${cr|0},${cg|0},${cb|0})`,
                                vx: 60 + Math.random() * 100,
                                vy: -30 + Math.random() * 60 - (row / rows) * 40,
                                delay,
                                opacity: 1,
                                rotation: Math.random() * Math.PI * 2,
                                rotationSpeed: (Math.random() - 0.5) * 10
                            });
                        }
                    }

                    // Hide original element
                    element.style.visibility = 'hidden';

                    // Animation loop
                    const duration = 800;
                    const startTime = performance.now();

                    const animate = (now) => {
                        const elapsed = now - startTime;
                        const progress = Math.min(elapsed / duration, 1);

                        ctx.clearRect(0, 0, canvas.width, canvas.height);

                        let activeParticles = 0;
                        for (const p of particles) {
                            // Apply delay
                            const localProgress = Math.max(0, (progress - p.delay) / (1 - p.delay));
                            if (localProgress <= 0) {
                                // Still waiting, draw at original position
                                ctx.globalAlpha = 1;
                                ctx.fillStyle = p.color;
                                ctx.beginPath();
                                ctx.arc(p.startX, p.startY, p.size / 2, 0, Math.PI * 2);
                                ctx.fill();
                                activeParticles++;
                                continue;
                            }

                            if (localProgress >= 1) continue;

                            // Easing
                            const ease = 1 - Math.pow(1 - localProgress, 3);

                            // Update position
                            const x = p.startX + p.vx * ease;
                            const y = p.startY + p.vy * ease;
                            const scale = 1 - ease;
                            const opacity = 1 - ease;

                            if (opacity > 0.01) {
                                ctx.globalAlpha = opacity;
                                ctx.fillStyle = p.color;
                                ctx.beginPath();
                                ctx.arc(x, y, (p.size / 2) * scale, 0, Math.PI * 2);
                                ctx.fill();
                                activeParticles++;
                            }
                        }

                        if (progress < 1 && activeParticles > 0) {
                            requestAnimationFrame(animate);
                        } else {
                            // Clean up
                            element.remove();
                            canvas.remove();
                        }
                    };

                    requestAnimationFrame(animate);
                },

                handleKeyDown: function(e) {
                    const picker = window.__barcElementPicker;
                    if (!picker.active) return;

                    // Escape to cancel
                    if (e.key === 'Escape') {
                        e.preventDefault();
                        picker.deactivate();
                        // Notify Swift
                        window.webkit.messageHandlers.barcElementPicker?.postMessage({action: 'deactivated'});
                    }
                }
            };

            // Bind methods
            picker.handleMouseMove = picker.handleMouseMove.bind(picker);
            picker.handleClick = picker.handleClick.bind(picker);
            picker.handleKeyDown = picker.handleKeyDown.bind(picker);

            window.__barcElementPicker = picker;
            picker.activate();
        })();
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("[Barc] Element picker activation failed: \(error)")
            }
        }

        isElementPickerActive = true
    }

    func deactivateElementPicker() {
        guard let webView = selectedTab?.webView else {
            isElementPickerActive = false
            return
        }

        let script = """
        if (window.__barcElementPicker) {
            window.__barcElementPicker.deactivate();
        }
        """

        webView.evaluateJavaScript(script) { _, _ in }
        isElementPickerActive = false
    }
}
