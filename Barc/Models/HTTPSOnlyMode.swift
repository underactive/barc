import Foundation

enum HTTPSOnlyMode: String, CaseIterable, Identifiable {
    case off = "off"
    case upgrade = "upgrade"
    case strict = "strict"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .upgrade: return "Upgrade to HTTPS"
        case .strict: return "Strict (Block HTTP)"
        }
    }

    var description: String {
        switch self {
        case .off: return "Allow all connections"
        case .upgrade: return "Automatically upgrade HTTP to HTTPS"
        case .strict: return "Block all non-HTTPS connections"
        }
    }
}

