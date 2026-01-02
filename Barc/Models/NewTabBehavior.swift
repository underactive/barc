import Foundation

enum NewTabBehavior: String, CaseIterable, Identifiable {
    case homePage = "homePage"
    case blankPage = "blankPage"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .homePage: return "Home Page"
        case .blankPage: return "Blank Page"
        }
    }
}

