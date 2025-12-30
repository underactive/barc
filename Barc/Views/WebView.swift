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

        // Font fingerprint protection
        if settings.fontFingerprintProtection {
            scriptParts.append("""
                // Limit detectable fonts to a common subset
                (function() {
                    // Common fonts available on most systems (minimal set for privacy)
                    const allowedFonts = new Set([
                        // Web-safe fonts
                        'arial', 'arial black', 'comic sans ms', 'courier new', 'georgia',
                        'impact', 'times new roman', 'trebuchet ms', 'verdana',
                        'helvetica', 'helvetica neue', 'lucida grande', 'tahoma',
                        // Generic families
                        'system-ui', 'sans-serif', 'serif', 'monospace', 'cursive', 'fantasy',
                        '-apple-system', 'blinkmacsystemfont', 'segoe ui'
                    ]);

                    const isAllowedFont = (fontFamily) => {
                        if (!fontFamily) return true;
                        const normalized = fontFamily.toLowerCase().trim().replace(/['"]/g, '');
                        return allowedFonts.has(normalized) ||
                               normalized.startsWith('system') ||
                               normalized === 'sans-serif' ||
                               normalized === 'serif' ||
                               normalized === 'monospace';
                    };

                    // Store baseline dimensions for fallback
                    const baselineWidth = 72.5;
                    const baselineHeight = 18;

                    // Override FontFaceSet.check
                    if (document.fonts && document.fonts.check) {
                        const originalCheck = document.fonts.check.bind(document.fonts);
                        document.fonts.check = function(font, text) {
                            const fontFamily = font.split(/\\s+/).pop().replace(/['"]/g, '');
                            if (!isAllowedFont(fontFamily)) {
                                return false;
                            }
                            return originalCheck(font, text);
                        };
                    }

                    // Track elements being used for font detection
                    const fontProbeElements = new WeakSet();

                    // Intercept createElement to catch font probe elements
                    const originalCreateElement = document.createElement.bind(document);
                    document.createElement = function(tagName, options) {
                        const element = originalCreateElement(tagName, options);
                        if (tagName.toLowerCase() === 'span') {
                            // Mark potential font probe elements
                            setTimeout(() => {
                                if (element.style.fontFamily && !element.textContent?.trim()) {
                                    fontProbeElements.add(element);
                                }
                            }, 0);
                        }
                        return element;
                    };

                    // Override offsetWidth
                    const originalOffsetWidth = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'offsetWidth');
                    Object.defineProperty(HTMLElement.prototype, 'offsetWidth', {
                        get: function() {
                            const value = originalOffsetWidth.get.call(this);
                            if (this.style.fontFamily) {
                                const fontFamily = this.style.fontFamily.split(',')[0];
                                if (!isAllowedFont(fontFamily)) {
                                    return baselineWidth;
                                }
                            }
                            return value;
                        },
                        configurable: true
                    });

                    // Override offsetHeight
                    const originalOffsetHeight = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'offsetHeight');
                    Object.defineProperty(HTMLElement.prototype, 'offsetHeight', {
                        get: function() {
                            const value = originalOffsetHeight.get.call(this);
                            if (this.style.fontFamily) {
                                const fontFamily = this.style.fontFamily.split(',')[0];
                                if (!isAllowedFont(fontFamily)) {
                                    return baselineHeight;
                                }
                            }
                            return value;
                        },
                        configurable: true
                    });

                    // Override getBoundingClientRect
                    const originalGetBoundingClientRect = Element.prototype.getBoundingClientRect;
                    Element.prototype.getBoundingClientRect = function() {
                        const rect = originalGetBoundingClientRect.call(this);
                        if (this.style && this.style.fontFamily) {
                            const fontFamily = this.style.fontFamily.split(',')[0];
                            if (!isAllowedFont(fontFamily)) {
                                return new DOMRect(rect.x, rect.y, baselineWidth, baselineHeight);
                            }
                        }
                        return rect;
                    };

                    // Override getComputedStyle to hide non-allowed fonts
                    const originalGetComputedStyle = window.getComputedStyle;
                    window.getComputedStyle = function(element, pseudoElt) {
                        const style = originalGetComputedStyle.call(this, element, pseudoElt);
                        const originalGetPropertyValue = style.getPropertyValue.bind(style);
                        style.getPropertyValue = function(prop) {
                            if (prop === 'font-family') {
                                const value = originalGetPropertyValue(prop);
                                const fonts = value.split(',').filter(f => isAllowedFont(f.trim()));
                                return fonts.length > 0 ? fonts.join(', ') : 'sans-serif';
                            }
                            return originalGetPropertyValue(prop);
                        };
                        return style;
                    };

                    // Block canvas-based font detection by adding noise when measuring text
                    const originalMeasureText = CanvasRenderingContext2D.prototype.measureText;
                    CanvasRenderingContext2D.prototype.measureText = function(text) {
                        const metrics = originalMeasureText.call(this, text);
                        const font = this.font || '';
                        const fontFamily = font.split(/\\s+/).pop()?.replace(/['"]/g, '') || '';

                        if (!isAllowedFont(fontFamily)) {
                            // Return consistent baseline metrics for non-allowed fonts
                            return {
                                width: text.length * 8,
                                actualBoundingBoxAscent: metrics.actualBoundingBoxAscent,
                                actualBoundingBoxDescent: metrics.actualBoundingBoxDescent,
                                actualBoundingBoxLeft: metrics.actualBoundingBoxLeft,
                                actualBoundingBoxRight: text.length * 8,
                                fontBoundingBoxAscent: metrics.fontBoundingBoxAscent,
                                fontBoundingBoxDescent: metrics.fontBoundingBoxDescent
                            };
                        }
                        return metrics;
                    };

                    console.log('[Barc] Font fingerprint protection enabled (enhanced)');
                })();
            """)
        }

        // AudioContext fingerprint protection
        if settings.audioContextFingerprintProtection {
            scriptParts.append("""
                // Spoof AudioContext fingerprinting
                (function() {
                    // Generate consistent but random-looking noise offset per session
                    const noiseOffset = Math.random() * 0.0001;

                    // Store original constructors
                    const OriginalAudioContext = window.AudioContext || window.webkitAudioContext;
                    const OriginalOfflineAudioContext = window.OfflineAudioContext || window.webkitOfflineAudioContext;

                    if (OriginalAudioContext) {
                        // Wrap AudioContext
                        const wrappedAudioContext = function(...args) {
                            const context = new OriginalAudioContext(...args);

                            // Override createOscillator to add slight variations
                            const originalCreateOscillator = context.createOscillator.bind(context);
                            context.createOscillator = function() {
                                const oscillator = originalCreateOscillator();

                                // Slightly modify the frequency detune to add noise
                                const originalDetune = Object.getOwnPropertyDescriptor(OscillatorNode.prototype, 'detune');
                                if (oscillator.detune && originalDetune) {
                                    const originalDetuneValue = oscillator.detune.value;
                                    Object.defineProperty(oscillator, 'detune', {
                                        get: function() {
                                            const detune = originalDetune.get.call(this);
                                            // Add tiny noise to detune value reads
                                            const originalValue = detune.value;
                                            Object.defineProperty(detune, 'value', {
                                                get: function() { return originalValue + noiseOffset; },
                                                set: function(v) { return v; },
                                                configurable: true
                                            });
                                            return detune;
                                        },
                                        configurable: true
                                    });
                                }
                                return oscillator;
                            };

                            // Override createAnalyser to modify frequency data
                            const originalCreateAnalyser = context.createAnalyser.bind(context);
                            context.createAnalyser = function() {
                                const analyser = originalCreateAnalyser();

                                // Override getFloatFrequencyData
                                const originalGetFloatFrequencyData = analyser.getFloatFrequencyData.bind(analyser);
                                analyser.getFloatFrequencyData = function(array) {
                                    originalGetFloatFrequencyData(array);
                                    // Add small noise to each value
                                    for (let i = 0; i < array.length; i++) {
                                        array[i] += (noiseOffset * (i % 10)) - (noiseOffset * 5);
                                    }
                                };

                                // Override getByteFrequencyData
                                const originalGetByteFrequencyData = analyser.getByteFrequencyData.bind(analyser);
                                analyser.getByteFrequencyData = function(array) {
                                    originalGetByteFrequencyData(array);
                                    // Add small noise to each value
                                    for (let i = 0; i < array.length; i++) {
                                        const noise = Math.floor((noiseOffset * 10000) % 3) - 1;
                                        array[i] = Math.max(0, Math.min(255, array[i] + noise));
                                    }
                                };

                                // Override getFloatTimeDomainData
                                const originalGetFloatTimeDomainData = analyser.getFloatTimeDomainData.bind(analyser);
                                analyser.getFloatTimeDomainData = function(array) {
                                    originalGetFloatTimeDomainData(array);
                                    for (let i = 0; i < array.length; i++) {
                                        array[i] += noiseOffset * ((i % 7) - 3);
                                    }
                                };

                                // Override getByteTimeDomainData
                                const originalGetByteTimeDomainData = analyser.getByteTimeDomainData.bind(analyser);
                                analyser.getByteTimeDomainData = function(array) {
                                    originalGetByteTimeDomainData(array);
                                    for (let i = 0; i < array.length; i++) {
                                        const noise = Math.floor((noiseOffset * 10000) % 2);
                                        array[i] = Math.max(0, Math.min(255, array[i] + noise));
                                    }
                                };

                                return analyser;
                            };

                            // Spoof destination properties
                            const originalDestination = context.destination;
                            Object.defineProperty(context, 'destination', {
                                get: function() {
                                    return originalDestination;
                                },
                                configurable: true
                            });

                            // Spoof sampleRate with slight variation
                            const originalSampleRate = context.sampleRate;
                            Object.defineProperty(context, 'sampleRate', {
                                get: function() {
                                    // Return common sample rates to reduce uniqueness
                                    return 44100;
                                },
                                configurable: true
                            });

                            return context;
                        };

                        wrappedAudioContext.prototype = OriginalAudioContext.prototype;
                        window.AudioContext = wrappedAudioContext;
                        if (window.webkitAudioContext) {
                            window.webkitAudioContext = wrappedAudioContext;
                        }
                    }

                    if (OriginalOfflineAudioContext) {
                        // Wrap OfflineAudioContext
                        const wrappedOfflineAudioContext = function(...args) {
                            const context = new OriginalOfflineAudioContext(...args);

                            // Override renderedBuffer to add noise
                            const originalStartRendering = context.startRendering.bind(context);
                            context.startRendering = function() {
                                return originalStartRendering().then(function(buffer) {
                                    // Add tiny noise to the rendered audio data
                                    for (let channel = 0; channel < buffer.numberOfChannels; channel++) {
                                        const channelData = buffer.getChannelData(channel);
                                        for (let i = 0; i < channelData.length; i++) {
                                            channelData[i] += noiseOffset * ((i % 13) - 6) * 0.00001;
                                        }
                                    }
                                    return buffer;
                                });
                            };

                            return context;
                        };

                        wrappedOfflineAudioContext.prototype = OriginalOfflineAudioContext.prototype;
                        window.OfflineAudioContext = wrappedOfflineAudioContext;
                        if (window.webkitOfflineAudioContext) {
                            window.webkitOfflineAudioContext = wrappedOfflineAudioContext;
                        }
                    }

                    console.log('[Barc] AudioContext fingerprint protection enabled');
                })();
            """)
        }

        // Battery API blocking
        if settings.batteryAPIBlocking {
            scriptParts.append("""
                // Block Battery Status API
                (function() {
                    if (navigator.getBattery) {
                        navigator.getBattery = function() {
                            console.log('[Barc] Blocked Battery API access');
                            return Promise.reject(new DOMException('Battery API blocked by privacy settings', 'NotAllowedError'));
                        };
                    }

                    // Also block the older battery property if it exists
                    if ('battery' in navigator) {
                        Object.defineProperty(navigator, 'battery', {
                            get: function() {
                                console.log('[Barc] Blocked navigator.battery access');
                                return undefined;
                            },
                            configurable: true
                        });
                    }

                    // Block BatteryManager if exposed
                    if (window.BatteryManager) {
                        delete window.BatteryManager;
                    }

                    console.log('[Barc] Battery API blocking enabled');
                })();
            """)
        }

        // Language spoofing
        if settings.languageSpoofing {
            let systemLanguage = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
            let selectedLanguage = settings.spoofedLanguage

            // For auto mode, pick a language different from system language
            let effectiveLanguage: SpoofedLanguage
            if selectedLanguage == .auto {
                // If system is en-US, use en-GB; otherwise use en-US
                if systemLanguage.hasPrefix("en-US") || systemLanguage.hasPrefix("en_US") {
                    effectiveLanguage = .enGB
                } else {
                    effectiveLanguage = .enUS
                }
            } else {
                effectiveLanguage = selectedLanguage
            }

            let langCode = effectiveLanguage.languageCode
            let langArray = effectiveLanguage.languages.map { "\"\($0)\"" }.joined(separator: ", ")

            scriptParts.append("""
                // Spoof navigator.language and navigator.languages
                (function() {
                    const spoofedLanguage = '\(langCode)';
                    const spoofedLanguages = [\(langArray)];

                    Object.defineProperty(navigator, 'language', {
                        get: function() { return spoofedLanguage; },
                        configurable: true
                    });

                    Object.defineProperty(navigator, 'languages', {
                        get: function() { return Object.freeze([...spoofedLanguages]); },
                        configurable: true
                    });

                    // Also spoof Intl.DateTimeFormat resolved locale
                    const originalDateTimeFormat = Intl.DateTimeFormat;
                    Intl.DateTimeFormat = function(...args) {
                        if (args.length === 0 || args[0] === undefined) {
                            args[0] = spoofedLanguage;
                        }
                        return new originalDateTimeFormat(...args);
                    };
                    Intl.DateTimeFormat.prototype = originalDateTimeFormat.prototype;
                    Intl.DateTimeFormat.supportedLocalesOf = originalDateTimeFormat.supportedLocalesOf;

                    // Spoof Intl.NumberFormat
                    const originalNumberFormat = Intl.NumberFormat;
                    Intl.NumberFormat = function(...args) {
                        if (args.length === 0 || args[0] === undefined) {
                            args[0] = spoofedLanguage;
                        }
                        return new originalNumberFormat(...args);
                    };
                    Intl.NumberFormat.prototype = originalNumberFormat.prototype;
                    Intl.NumberFormat.supportedLocalesOf = originalNumberFormat.supportedLocalesOf;

                    console.log('[Barc] Language spoofing enabled: ' + spoofedLanguage);
                })();
            """)
        }

        // Clipboard access blocking
        if settings.clipboardAccessBlocking {
            scriptParts.append("""
                // Block clipboard read access
                (function() {
                    if (navigator.clipboard) {
                        // Block readText
                        const originalReadText = navigator.clipboard.readText;
                        navigator.clipboard.readText = function() {
                            console.log('[Barc] Blocked clipboard read access');
                            return Promise.reject(new DOMException('Clipboard access denied by privacy settings', 'NotAllowedError'));
                        };

                        // Block read (for all clipboard items)
                        const originalRead = navigator.clipboard.read;
                        navigator.clipboard.read = function() {
                            console.log('[Barc] Blocked clipboard read access');
                            return Promise.reject(new DOMException('Clipboard access denied by privacy settings', 'NotAllowedError'));
                        };

                        // Note: writeText and write are still allowed for user-initiated copy actions
                    }

                    // Also block the older execCommand approach for reading
                    const originalExecCommand = document.execCommand;
                    document.execCommand = function(command, ...args) {
                        if (command.toLowerCase() === 'paste') {
                            console.log('[Barc] Blocked paste command');
                            return false;
                        }
                        return originalExecCommand.apply(this, [command, ...args]);
                    };

                    // Block clipboardData on paste events from exposing data to scripts
                    document.addEventListener('paste', function(e) {
                        if (e.clipboardData) {
                            // Only block programmatic access, not user-initiated pastes in input fields
                            const target = e.target;
                            const isInputField = target.tagName === 'INPUT' ||
                                                 target.tagName === 'TEXTAREA' ||
                                                 target.isContentEditable;
                            if (!isInputField) {
                                e.preventDefault();
                                e.stopPropagation();
                                console.log('[Barc] Blocked clipboard data access on paste event');
                            }
                        }
                    }, true);

                    console.log('[Barc] Clipboard access blocking enabled');
                })();
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
