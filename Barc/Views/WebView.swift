import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    @ObservedObject var tab: Tab
    @EnvironmentObject var browserState: BrowserState
    private let settings = PrivacySettings.shared

    static let networkMessageHandler = "barcNetwork"

    func makeNSView(context: Context) -> WKWebView {
        let configuration = createPrivacyConfiguration(coordinator: context.coordinator)
        let webView = WKWebView(frame: .zero, configuration: configuration)

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        context.coordinator.setupObservers(for: webView)
        tab.webView = webView

        if let url = tab.url {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only load if URL changed externally
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, settings: settings)
    }

    private func createPrivacyConfiguration(coordinator: Coordinator) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()

        // Always use persistent storage to support whitelist
        configuration.websiteDataStore = .default()

        // Privacy: Disable telemetry and tracking
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // Content controller with message handler and scripts
        let contentController = WKUserContentController()

        // Add message handler for network activity reporting
        contentController.add(coordinator, name: Self.networkMessageHandler)

        // Inject network monitoring script (must be first, before privacy scripts)
        injectNetworkMonitoringScript(into: contentController)

        // Inject privacy scripts
        injectPrivacyScripts(into: contentController)

        configuration.userContentController = contentController

        // Privacy: Fraudulent website warning
        configuration.preferences.isFraudulentWebsiteWarningEnabled = settings.fraudulentWebsiteWarning

        // Privacy: Third-party cookie blocking using content rules
        if settings.thirdPartyCookieBlocking {
            let blockCookiesRule = """
            [{
                "trigger": {
                    "url-filter": ".*",
                    "load-type": ["third-party"]
                },
                "action": {
                    "type": "block-cookies"
                }
            }]
            """

            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "blockThirdPartyCookies",
                encodedContentRuleList: blockCookiesRule
            ) { ruleList, error in
                if let ruleList = ruleList {
                    DispatchQueue.main.async {
                        configuration.userContentController.add(ruleList)
                    }
                } else if let error = error {
                    print("[Barc] Failed to compile cookie blocking rules: \(error)")
                }
            }
        }

        return configuration
    }

    private func injectNetworkMonitoringScript(into controller: WKUserContentController) {
        let script = """
        (function() {
            if (window.__barcNetworkMonitorInstalled) return;
            window.__barcNetworkMonitorInstalled = true;

            const reportTx = () => {
                try {
                    window.webkit.messageHandlers.\(Self.networkMessageHandler).postMessage({type: 'tx'});
                } catch(e) {}
            };

            const reportRx = () => {
                try {
                    window.webkit.messageHandlers.\(Self.networkMessageHandler).postMessage({type: 'rx'});
                } catch(e) {}
            };

            // Intercept fetch()
            const originalFetch = window.fetch;
            window.fetch = function(...args) {
                reportTx();
                return originalFetch.apply(this, args).then(response => {
                    reportRx();
                    return response;
                }).catch(err => {
                    reportRx();
                    throw err;
                });
            };

            // Intercept XMLHttpRequest
            const originalXHROpen = XMLHttpRequest.prototype.open;
            const originalXHRSend = XMLHttpRequest.prototype.send;

            XMLHttpRequest.prototype.open = function(...args) {
                this.__barcMethod = args[0];
                this.__barcUrl = args[1];
                return originalXHROpen.apply(this, args);
            };

            XMLHttpRequest.prototype.send = function(...args) {
                reportTx();

                const xhr = this;
                const originalOnReadyStateChange = xhr.onreadystatechange;

                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 2) { // Headers received
                        reportRx();
                    } else if (xhr.readyState === 3) { // Loading (receiving data)
                        reportRx();
                    } else if (xhr.readyState === 4) { // Done
                        reportRx();
                    }
                    if (originalOnReadyStateChange) {
                        originalOnReadyStateChange.apply(this, arguments);
                    }
                };

                // Also listen to progress events for chunked responses
                xhr.addEventListener('progress', () => reportRx());

                return originalXHRSend.apply(this, args);
            };

            // Intercept WebSocket
            const OriginalWebSocket = window.WebSocket;
            window.WebSocket = function(...args) {
                const ws = new OriginalWebSocket(...args);

                ws.addEventListener('open', () => reportTx());
                ws.addEventListener('message', () => reportRx());

                const originalSend = ws.send.bind(ws);
                ws.send = function(data) {
                    reportTx();
                    return originalSend(data);
                };

                return ws;
            };
            window.WebSocket.prototype = OriginalWebSocket.prototype;
            window.WebSocket.CONNECTING = OriginalWebSocket.CONNECTING;
            window.WebSocket.OPEN = OriginalWebSocket.OPEN;
            window.WebSocket.CLOSING = OriginalWebSocket.CLOSING;
            window.WebSocket.CLOSED = OriginalWebSocket.CLOSED;

            // Intercept EventSource (Server-Sent Events)
            if (window.EventSource) {
                const OriginalEventSource = window.EventSource;
                window.EventSource = function(...args) {
                    reportTx();
                    const es = new OriginalEventSource(...args);
                    es.addEventListener('message', () => reportRx());
                    es.addEventListener('open', () => reportRx());
                    return es;
                };
                window.EventSource.prototype = OriginalEventSource.prototype;
            }

            // Monitor video/audio elements for buffering (media streaming)
            const monitorMediaElement = (element) => {
                if (element.__barcMonitored) return;
                element.__barcMonitored = true;

                // Track when actively downloading data
                element.addEventListener('progress', () => {
                    // Progress fires when data is being downloaded
                    if (element.buffered.length > 0) {
                        reportRx();
                    }
                });

                // Also monitor when seeking causes new data fetch
                element.addEventListener('seeking', () => reportTx());
                element.addEventListener('seeked', () => reportRx());
            };

            // Monitor existing media elements
            document.querySelectorAll('video, audio').forEach(monitorMediaElement);

            // Monitor dynamically added media elements
            const observer = new MutationObserver((mutations) => {
                mutations.forEach((mutation) => {
                    mutation.addedNodes.forEach((node) => {
                        if (node.nodeName === 'VIDEO' || node.nodeName === 'AUDIO') {
                            monitorMediaElement(node);
                        }
                        if (node.querySelectorAll) {
                            node.querySelectorAll('video, audio').forEach(monitorMediaElement);
                        }
                    });
                });
            });
            observer.observe(document.documentElement, { childList: true, subtree: true });

            // Intercept sendBeacon
            if (navigator.sendBeacon) {
                const originalSendBeacon = navigator.sendBeacon.bind(navigator);
                navigator.sendBeacon = function(...args) {
                    reportTx();
                    return originalSendBeacon(...args);
                };
            }

            // Intercept Image loading (for tracking pixels and image requests)
            const originalImageSrc = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
            if (originalImageSrc) {
                Object.defineProperty(HTMLImageElement.prototype, 'src', {
                    get: originalImageSrc.get,
                    set: function(value) {
                        if (value && value.length > 0) {
                            reportTx();
                            this.addEventListener('load', () => reportRx(), { once: true });
                            this.addEventListener('error', () => reportRx(), { once: true });
                        }
                        return originalImageSrc.set.call(this, value);
                    },
                    configurable: true
                });
            }

            console.log('[Barc] Network monitoring active');
        })();
        """

        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        controller.addUserScript(userScript)
    }

    private func injectPrivacyScripts(into controller: WKUserContentController) {
        var scriptParts: [String] = []

        scriptParts.append("(function() {")

        // Canvas fingerprint protection
        if settings.canvasFingerprintProtection {
            scriptParts.append("""
                // Spoof canvas fingerprinting
                const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
                HTMLCanvasElement.prototype.toDataURL = function(type) {
                    if (this.width === 0 || this.height === 0) {
                        return originalToDataURL.apply(this, arguments);
                    }
                    const ctx = this.getContext('2d');
                    if (ctx) {
                        try {
                            const imageData = ctx.getImageData(0, 0, this.width, this.height);
                            for (let i = 0; i < imageData.data.length; i += 4) {
                                imageData.data[i] ^= 1;
                            }
                            ctx.putImageData(imageData, 0, 0);
                        } catch(e) {}
                    }
                    return originalToDataURL.apply(this, arguments);
                };

                const originalGetImageData = CanvasRenderingContext2D.prototype.getImageData;
                CanvasRenderingContext2D.prototype.getImageData = function(...args) {
                    const imageData = originalGetImageData.apply(this, args);
                    for (let i = 0; i < imageData.data.length; i += 4) {
                        imageData.data[i] ^= 1;
                    }
                    return imageData;
                };
            """)
        }

        // WebGL fingerprint protection with randomized GPU per tab
        if settings.webGLFingerprintProtection {
            // Common GPU configurations to simulate
            let gpuConfigs: [(vendor: String, renderer: String)] = [
                ("Intel Inc.", "Intel Iris OpenGL Engine"),
                ("Intel Inc.", "Intel HD Graphics 630"),
                ("Intel Inc.", "Intel UHD Graphics 620"),
                ("Intel Inc.", "Intel Iris Plus Graphics 640"),
                ("Intel Inc.", "Intel Iris Pro Graphics 6200"),
                ("Google Inc. (Intel)", "ANGLE (Intel, Intel(R) UHD Graphics 620, OpenGL 4.1)"),
                ("Google Inc. (Intel)", "ANGLE (Intel, Intel(R) Iris Plus Graphics 655, OpenGL 4.1)"),
                ("Google Inc. (AMD)", "ANGLE (AMD, AMD Radeon Pro 5500M, OpenGL 4.1)"),
                ("Google Inc. (NVIDIA)", "ANGLE (NVIDIA, NVIDIA GeForce GTX 1650, OpenGL 4.1)"),
                ("AMD", "AMD Radeon Pro 5300M OpenGL Engine"),
                ("AMD", "AMD Radeon RX 580 OpenGL Engine"),
                ("Apple", "Apple M1"),
                ("Apple", "Apple M2"),
                ("Apple", "Apple M1 Pro"),
            ]

            // Randomly select a GPU configuration for this tab
            let selectedGPU = gpuConfigs.randomElement() ?? gpuConfigs[0]

            scriptParts.append("""
                // Mask WebGL renderer and vendor info (randomized per tab)
                (function() {
                    const spoofedVendor = '\(selectedGPU.vendor)';
                    const spoofedRenderer = '\(selectedGPU.renderer)';

                    const getParameterProxyHandler = {
                        apply: function(target, thisArg, args) {
                            const param = args[0];
                            const gl = thisArg;

                            // UNMASKED_VENDOR_WEBGL
                            if (param === 37445) {
                                return spoofedVendor;
                            }
                            // UNMASKED_RENDERER_WEBGL
                            if (param === 37446) {
                                return spoofedRenderer;
                            }
                            // VENDOR
                            if (param === gl.VENDOR) {
                                return 'WebKit';
                            }
                            // RENDERER
                            if (param === gl.RENDERER) {
                                return 'WebKit WebGL';
                            }
                            // VERSION
                            if (param === gl.VERSION) {
                                return 'WebGL 1.0';
                            }
                            // SHADING_LANGUAGE_VERSION
                            if (param === gl.SHADING_LANGUAGE_VERSION) {
                                return 'WebGL GLSL ES 1.0';
                            }

                            return target.apply(thisArg, args);
                        }
                    };

                    // Override WebGLRenderingContext.getParameter
                    if (window.WebGLRenderingContext) {
                        const originalGetParameter = WebGLRenderingContext.prototype.getParameter;
                        WebGLRenderingContext.prototype.getParameter = new Proxy(originalGetParameter, getParameterProxyHandler);
                    }

                    // Override WebGL2RenderingContext.getParameter
                    if (window.WebGL2RenderingContext) {
                        const originalGetParameter2 = WebGL2RenderingContext.prototype.getParameter;
                        WebGL2RenderingContext.prototype.getParameter = new Proxy(originalGetParameter2, getParameterProxyHandler);
                    }

                    // Also mask the debug renderer info extension
                    const originalGetExtension = WebGLRenderingContext.prototype.getExtension;
                    WebGLRenderingContext.prototype.getExtension = function(name) {
                        if (name === 'WEBGL_debug_renderer_info') {
                            return {
                                UNMASKED_VENDOR_WEBGL: 37445,
                                UNMASKED_RENDERER_WEBGL: 37446
                            };
                        }
                        return originalGetExtension.apply(this, arguments);
                    };

                    if (window.WebGL2RenderingContext) {
                        const originalGetExtension2 = WebGL2RenderingContext.prototype.getExtension;
                        WebGL2RenderingContext.prototype.getExtension = function(name) {
                            if (name === 'WEBGL_debug_renderer_info') {
                                return {
                                    UNMASKED_VENDOR_WEBGL: 37445,
                                    UNMASKED_RENDERER_WEBGL: 37446
                                };
                            }
                            return originalGetExtension2.apply(this, arguments);
                        };
                    }

                    console.log('[Barc] WebGL fingerprint protection enabled - spoofing: ' + spoofedVendor + ' / ' + spoofedRenderer);
                })();
            """)
        }

        // WebRTC IP leak protection
        if settings.webRTCProtection {
            scriptParts.append("""
                if (window.RTCPeerConnection) {
                    const originalRTC = window.RTCPeerConnection;
                    window.RTCPeerConnection = function(...args) {
                        const config = args[0] || {};
                        config.iceServers = [];
                        return new originalRTC(config);
                    };
                    window.RTCPeerConnection.prototype = originalRTC.prototype;
                }
                if (window.webkitRTCPeerConnection) {
                    window.webkitRTCPeerConnection = window.RTCPeerConnection;
                }
            """)
        }

        // Hardware fingerprint resistance
        if settings.hardwareFingerprintResistance {
            scriptParts.append("""
                Object.defineProperty(navigator, 'hardwareConcurrency', {
                    get: function() { return 4; },
                    configurable: true
                });
                Object.defineProperty(navigator, 'deviceMemory', {
                    get: function() { return 8; },
                    configurable: true
                });
                Object.defineProperty(screen, 'colorDepth', {
                    get: function() { return 24; },
                    configurable: true
                });
                Object.defineProperty(screen, 'pixelDepth', {
                    get: function() { return 24; },
                    configurable: true
                });
                Object.defineProperty(navigator, 'plugins', {
                    get: function() { return []; },
                    configurable: true
                });
                Object.defineProperty(navigator, 'mimeTypes', {
                    get: function() { return []; },
                    configurable: true
                });
            """)
        }

        // Tracking pixel blocking
        if settings.trackingPixelBlocking {
            scriptParts.append("""
                const blockedPixelDomains = [
                    'facebook.com', 'doubleclick.net', 'google-analytics.com',
                    'googleadservices.com', 'googlesyndication.com', 'amazon-adsystem.com',
                    'pixel.', 'tracking.', 'analytics.', 'beacon.'
                ];
            """)
        }

        // Referrer Policy
        let referrerPolicy = settings.referrerPolicy.webValue
        if !referrerPolicy.isEmpty {
            scriptParts.append("""
                // Set referrer policy
                (function() {
                    // Set meta tag for referrer policy
                    const meta = document.createElement('meta');
                    meta.name = 'referrer';
                    meta.content = '\(referrerPolicy)';
                    document.head.appendChild(meta);

                    // Override document.referrer if no-referrer
                    if ('\(referrerPolicy)' === 'no-referrer') {
                        Object.defineProperty(document, 'referrer', {
                            get: function() { return ''; },
                            configurable: true
                        });
                    }

                    console.log('[Barc] Referrer policy set to: \(referrerPolicy)');
                })();
            """)
        }

        // Cookie Banner Auto-Reject
        if settings.cookieBannerAutoReject {
            scriptParts.append("""
                // Cookie Banner Auto-Reject
                (function() {
                    if (window.__barcCookieBannerHandled) return;
                    window.__barcCookieBannerHandled = true;

                    const rejectSelectors = [
                        // OneTrust
                        '#onetrust-reject-all-handler',
                        '.onetrust-close-btn-handler',
                        '#onetrust-pc-btn-handler',
                        // Cookiebot
                        '#CybotCookiebotDialogBodyButtonDecline',
                        '#CybotCookiebotDialogBodyLevelButtonLevelOptinDeclineAll',
                        // Quantcast
                        '.qc-cmp2-summary-buttons button[mode="secondary"]',
                        '.qc-cmp-button[onclick*="reject"]',
                        // TrustArc / TrustE
                        '.trustarc-agree-btn',
                        '#truste-consent-required',
                        // Didomi
                        '#didomi-notice-disagree-button',
                        '.didomi-continue-without-agreeing',
                        // Axeptio
                        '[data-consent="deny"]',
                        // Klaro
                        '.cm-btn-decline',
                        '.klaro .cn-decline',
                        // Complianz
                        '.cmplz-deny',
                        // CookieYes
                        '.cky-btn-reject',
                        // Iubenda
                        '.iubenda-cs-reject-btn',
                        // GDPR Cookie Compliance
                        '.moove-gdpr-infobar-reject-btn',
                        // Borlabs Cookie
                        '[data-cookie-refuse]',
                        // Generic patterns
                        '[aria-label*="reject" i]',
                        '[aria-label*="decline" i]',
                        '[aria-label*="deny" i]',
                        'button[data-testid*="reject" i]',
                        'button[data-testid*="decline" i]'
                    ];

                    const rejectTextPatterns = [
                        /^reject\\s*(all)?$/i,
                        /^decline\\s*(all)?$/i,
                        /^deny\\s*(all)?$/i,
                        /^refuse\\s*(all)?$/i,
                        /^only\\s*(essential|necessary|required)/i,
                        /^necessary\\s*only$/i,
                        /^essential\\s*only$/i,
                        /^use\\s*necessary\\s*(cookies)?\\s*only$/i,
                        /^accept\\s*necessary$/i,
                        /^no,?\\s*thanks?$/i,
                        /^disagree$/i,
                        /^opt[\\s-]*out$/i
                    ];

                    const bannerSelectors = [
                        '#onetrust-banner-sdk',
                        '#CybotCookiebotDialog',
                        '.qc-cmp2-container',
                        '#truste-consent-track',
                        '#didomi-host',
                        '.klaro',
                        '.cmplz-cookiebanner',
                        '.cky-consent-container',
                        '#iubenda-cs-banner',
                        '.moove-gdpr-info-bar-container',
                        '[class*="cookie-banner"]',
                        '[class*="cookie-consent"]',
                        '[class*="cookie-notice"]',
                        '[class*="gdpr-banner"]',
                        '[id*="cookie-banner"]',
                        '[id*="cookie-consent"]',
                        '[id*="cookie-notice"]',
                        '[id*="gdpr-banner"]'
                    ];

                    function findRejectButton() {
                        // Try specific selectors first
                        for (const selector of rejectSelectors) {
                            try {
                                const el = document.querySelector(selector);
                                if (el && isVisible(el)) {
                                    return el;
                                }
                            } catch(e) {}
                        }

                        // Search for buttons with reject text
                        const buttons = document.querySelectorAll('button, a[role="button"], [class*="btn"], [class*="button"]');
                        for (const btn of buttons) {
                            const text = (btn.textContent || btn.innerText || '').trim();
                            if (text.length > 0 && text.length < 50) {
                                for (const pattern of rejectTextPatterns) {
                                    if (pattern.test(text) && isVisible(btn)) {
                                        return btn;
                                    }
                                }
                            }
                        }
                        return null;
                    }

                    function isVisible(el) {
                        if (!el) return false;
                        const style = window.getComputedStyle(el);
                        return style.display !== 'none' &&
                               style.visibility !== 'hidden' &&
                               style.opacity !== '0' &&
                               el.offsetParent !== null;
                    }

                    function isBannerVisible() {
                        for (const selector of bannerSelectors) {
                            try {
                                const el = document.querySelector(selector);
                                if (el && isVisible(el)) {
                                    return true;
                                }
                            } catch(e) {}
                        }
                        return false;
                    }

                    function tryReject() {
                        if (!isBannerVisible()) return false;

                        const btn = findRejectButton();
                        if (btn) {
                            console.log('[Barc] Auto-rejecting cookie banner');
                            btn.click();
                            return true;
                        }
                        return false;
                    }

                    // Try immediately
                    if (document.readyState === 'complete' || document.readyState === 'interactive') {
                        setTimeout(tryReject, 100);
                    }

                    // Try on DOMContentLoaded
                    document.addEventListener('DOMContentLoaded', () => {
                        setTimeout(tryReject, 100);
                        setTimeout(tryReject, 500);
                        setTimeout(tryReject, 1500);
                    });

                    // Watch for dynamically added banners
                    const observer = new MutationObserver((mutations) => {
                        if (isBannerVisible()) {
                            setTimeout(tryReject, 100);
                        }
                    });

                    if (document.body) {
                        observer.observe(document.body, { childList: true, subtree: true });
                    } else {
                        document.addEventListener('DOMContentLoaded', () => {
                            observer.observe(document.body, { childList: true, subtree: true });
                        });
                    }

                    // Stop observing after 10 seconds to save resources
                    setTimeout(() => observer.disconnect(), 10000);
                })();
            """)
        }

        scriptParts.append("})();")

        let fullScript = scriptParts.joined(separator: "\n")

        let script = WKUserScript(
            source: fullScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        controller.addUserScript(script)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let tab: Tab
        let settings: PrivacySettings
        let networkMonitor = NetworkActivityMonitor.shared
        let blockedRequestsMonitor = BlockedRequestsMonitor.shared
        private var observations: [NSKeyValueObservation] = []

        init(tab: Tab, settings: PrivacySettings) {
            self.tab = tab
            self.settings = settings
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == WebView.networkMessageHandler,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                return
            }

            switch type {
            case "tx":
                networkMonitor.reportTransmit(tabId: tab.id)
            case "rx":
                networkMonitor.reportReceive(tabId: tab.id)
            default:
                break
            }
        }

        func setupObservers(for webView: WKWebView) {
            observations = [
                webView.observe(\.title) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.tab.title = webView.title ?? "New Tab"
                    }
                },
                webView.observe(\.url) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.tab.url = webView.url
                    }
                },
                webView.observe(\.isLoading) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.tab.isLoading = webView.isLoading
                    }
                },
                webView.observe(\.canGoBack) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.tab.canGoBack = webView.canGoBack
                    }
                },
                webView.observe(\.canGoForward) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.tab.canGoForward = webView.canGoForward
                    }
                },
                webView.observe(\.estimatedProgress) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.tab.estimatedProgress = webView.estimatedProgress
                    }
                }
            ]
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            networkMonitor.reportTransmit(tabId: tab.id)

            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // HTTPS-Only Mode handling
            if url.scheme == "http" {
                switch settings.httpsOnlyMode {
                case .upgrade:
                    // Upgrade HTTP to HTTPS
                    if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                        components.scheme = "https"
                        if let httpsURL = components.url {
                            print("[Barc] Upgrading to HTTPS: \(httpsURL)")
                            decisionHandler(.cancel)
                            webView.load(URLRequest(url: httpsURL))
                            return
                        }
                    }
                case .strict:
                    // Block HTTP entirely
                    print("[Barc] Blocked insecure HTTP connection: \(url)")
                    decisionHandler(.cancel)
                    // Show error page
                    let errorHTML = """
                    <html>
                    <head>
                        <style>
                            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 40px; text-align: center; background: #1a1a1a; color: #fff; }
                            h1 { color: #ff6b6b; }
                            .shield { font-size: 64px; margin-bottom: 20px; }
                            p { color: #888; max-width: 400px; margin: 20px auto; }
                            a { color: #4dabf7; }
                        </style>
                    </head>
                    <body>
                        <div class="shield">🛡️</div>
                        <h1>Connection Not Secure</h1>
                        <p>Barc blocked this connection because it uses HTTP instead of HTTPS.</p>
                        <p>HTTPS-Only Mode is enabled to protect your privacy.</p>
                        <p><small>Attempted URL: \(url.absoluteString)</small></p>
                    </body>
                    </html>
                    """
                    webView.loadHTMLString(errorHTML, baseURL: nil)
                    return
                case .off:
                    break
                }
            }

            // Tracker blocking and custom blocklist
            let blockedDomains = settings.blockedDomains
            if let host = url.host, blockedDomains.contains(where: { host.contains($0) }) {
                // Determine if it was blocked by built-in trackers or custom blocklist
                let builtInDomains = PrivacySettings.builtInTrackerDomains.map { $0.domain }
                let isBuiltInTracker = builtInDomains.contains(where: { host.contains($0) })
                let reason: BlockedRequestsMonitor.BlockedRequest.BlockReason = isBuiltInTracker ? .tracker : .customBlocklist

                print("[Barc] Blocked \(reason.rawValue.lowercased()): \(host)")
                blockedRequestsMonitor.reportBlocked(
                    domain: host,
                    url: url.absoluteString,
                    tabId: tab.id,
                    reason: reason
                )
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            networkMonitor.reportReceive(tabId: tab.id)
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            tab.isLoading = true
            networkMonitor.reportTransmit(tabId: tab.id)
            // Clear blocked requests for this tab when navigating to a new page
            blockedRequestsMonitor.clearBlocked(for: tab.id)
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            networkMonitor.reportActivity(tabId: tab.id, tx: true, rx: true)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            networkMonitor.reportReceive(tabId: tab.id)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab.isLoading = false
            tab.updateFromWebView(webView)
            networkMonitor.reportReceive(tabId: tab.id)
            fetchFavicon(for: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            tab.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            tab.isLoading = false
        }

        // MARK: - WKUIDelegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if settings.popupBlocking {
                if let url = navigationAction.request.url {
                    webView.load(URLRequest(url: url))
                }
                return nil
            }
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        // MARK: - Favicon

        private func fetchFavicon(for webView: WKWebView) {
            guard let url = webView.url, let host = url.host else { return }

            let faviconURL = URL(string: "https://\(host)/favicon.ico")
            guard let faviconURL else { return }

            networkMonitor.reportTransmit(tabId: tab.id)

            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: faviconURL)
                    networkMonitor.reportReceive(tabId: tab.id)
                    if let image = NSImage(data: data) {
                        await MainActor.run {
                            self.tab.favicon = image
                        }
                    }
                } catch {
                    networkMonitor.reportReceive(tabId: tab.id)
                }
            }
        }
    }
}
