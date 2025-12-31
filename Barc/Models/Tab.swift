import Foundation
import WebKit

class Tab: Identifiable, ObservableObject {
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
