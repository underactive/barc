import Foundation

enum ReferrerPolicy: String, CaseIterable, Identifiable {
    case defaultPolicy = "default"
    case noReferrer = "no-referrer"
    case origin = "origin"
    case sameOrigin = "same-origin"
    case strictOrigin = "strict-origin"
    case strictOriginWhenCrossOrigin = "strict-origin-when-cross-origin"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultPolicy: return "Default"
        case .noReferrer: return "No Referrer"
        case .origin: return "Origin Only"
        case .sameOrigin: return "Same Origin"
        case .strictOrigin: return "Strict Origin"
        case .strictOriginWhenCrossOrigin: return "Strict Origin (Cross-Origin)"
        }
    }

    var description: String {
        switch self {
        case .defaultPolicy: return "Browser default behavior"
        case .noReferrer: return "Never send referrer information"
        case .origin: return "Send only the origin (domain), not the full URL"
        case .sameOrigin: return "Send referrer only for same-origin requests"
        case .strictOrigin: return "Send origin on HTTPS→HTTPS, nothing on HTTPS→HTTP"
        case .strictOriginWhenCrossOrigin: return "Full URL for same-origin, origin only for cross-origin"
        }
    }

    var webValue: String {
        switch self {
        case .defaultPolicy: return ""
        case .noReferrer: return "no-referrer"
        case .origin: return "origin"
        case .sameOrigin: return "same-origin"
        case .strictOrigin: return "strict-origin"
        case .strictOriginWhenCrossOrigin: return "strict-origin-when-cross-origin"
        }
    }
}

