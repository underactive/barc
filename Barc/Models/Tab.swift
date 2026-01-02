import Foundation
import WebKit

/// Represents a single browser tab with its state and associated WebView.
/// 
/// This class maintains the state for a tab including:
/// - URL, title, and favicon
/// - Loading and navigation state
/// - Progress tracking
/// - Reference to the underlying WKWebView
/// 
/// The WebView reference is weak to avoid retain cycles.
/// 
/// All properties are accessed from the main actor since Tab is used by BrowserState
/// which is @MainActor. However, Tab itself is not @MainActor to allow WebKit
/// delegate callbacks to update it from any thread (they use DispatchQueue.main.async).
@MainActor
final class Tab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String = "New Tab"
    @Published var url: URL?
    @Published var favicon: NSImage?
    @Published var isLoading: Bool = false
    @Published var isRendering: Bool = false  // Tracks rendering phase (for cached pages)
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var hasDownloadableVideo: Bool = false  // True if page has videos that can be downloaded
    @Published var isPlayingAudio: Bool = false  // True if page is playing audio/video

    weak var webView: WKWebView?

    init(url: URL? = nil) {
        self.url = url
    }

    func updateFromWebView(_ webView: WKWebView) {
        self.webView = webView
        self.title = webView.title ?? "New Tab"
        self.url = webView.url
        self.isLoading = webView.isLoading
        self.canGoBack = webView.canGoBack
        self.canGoForward = webView.canGoForward
        self.estimatedProgress = webView.estimatedProgress
    }
}
