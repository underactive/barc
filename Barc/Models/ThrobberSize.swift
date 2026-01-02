import Foundation
import SwiftUI

enum ThrobberSize: String, CaseIterable {
    case none = "none"
    case small = "small"
    case medium = "medium"
    case large = "large"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var scale: CGFloat {
        switch self {
        case .none: return 0
        case .small: return 1.0
        case .medium: return 40.0 / 28.0
        case .large: return 2.0
        }
    }

    var isEnabled: Bool {
        self != .none
    }
}

