import Foundation

enum NetworkSoundScope: String, CaseIterable, Identifiable {
    case allTabs = "allTabs"
    case activeTabOnly = "activeTabOnly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .allTabs: return "All Tabs"
        case .activeTabOnly: return "Active Tab Only"
        }
    }

    var description: String {
        switch self {
        case .allTabs: return "Play sounds for network activity from any tab"
        case .activeTabOnly: return "Only play sounds for the currently visible tab"
        }
    }
}

