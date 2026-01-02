import Foundation

enum SearchEngine: String, CaseIterable, Identifiable {
    case kagi = "kagi"
    case duckduckgo = "duckduckgo"
    case google = "google"
    case bing = "bing"
    case startpage = "startpage"
    case brave = "brave"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kagi: return "Kagi"
        case .duckduckgo: return "DuckDuckGo"
        case .google: return "Google"
        case .bing: return "Bing"
        case .startpage: return "Startpage"
        case .brave: return "Brave Search"
        }
    }

    var searchURL: String {
        switch self {
        case .kagi: return "https://kagi.com/search?q="
        case .duckduckgo: return "https://duckduckgo.com/?q="
        case .google: return "https://www.google.com/search?q="
        case .bing: return "https://www.bing.com/search?q="
        case .startpage: return "https://www.startpage.com/sp/search?query="
        case .brave: return "https://search.brave.com/search?q="
        }
    }
}

