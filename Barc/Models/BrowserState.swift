import Foundation
import SwiftUI
import WebKit

class BrowserState: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var selectedTabId: UUID?
    @Published var sidebarCollapsed: Bool = false
    @Published var focusAddressBarTrigger: UUID = UUID()

    private let settings = PrivacySettings.shared

    var selectedTab: Tab? {
        tabs.first { $0.id == selectedTabId }
    }

    var selectedTabIndex: Int? {
        tabs.firstIndex { $0.id == selectedTabId }
    }

    var homePageURL: URL {
        URL(string: settings.homePage) ?? URL(string: "https://kagi.com")!
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
                targetURL = URL(string: "about:blank")!
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
}
