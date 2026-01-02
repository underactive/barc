import Foundation

enum SpoofedResolution: String, CaseIterable, Identifiable {
    case auto = "auto"
    case r1920x1080 = "1920x1080"
    case r1366x768 = "1366x768"
    case r1536x864 = "1536x864"
    case r1440x900 = "1440x900"
    case r1280x720 = "1280x720"
    case r2560x1440 = "2560x1440"
    case r1680x1050 = "1680x1050"
    case r1600x900 = "1600x900"
    case r2560x1600 = "2560x1600"
    case r3840x2160 = "3840x2160"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto (common resolution)"
        case .r1920x1080: return "1920 × 1080 (Full HD)"
        case .r1366x768: return "1366 × 768 (HD)"
        case .r1536x864: return "1536 × 864"
        case .r1440x900: return "1440 × 900"
        case .r1280x720: return "1280 × 720 (720p)"
        case .r2560x1440: return "2560 × 1440 (QHD)"
        case .r1680x1050: return "1680 × 1050"
        case .r1600x900: return "1600 × 900"
        case .r2560x1600: return "2560 × 1600"
        case .r3840x2160: return "3840 × 2160 (4K)"
        }
    }

    var width: Int {
        switch self {
        case .auto, .r1920x1080: return 1920
        case .r1366x768: return 1366
        case .r1536x864: return 1536
        case .r1440x900: return 1440
        case .r1280x720: return 1280
        case .r2560x1440: return 2560
        case .r1680x1050: return 1680
        case .r1600x900: return 1600
        case .r2560x1600: return 2560
        case .r3840x2160: return 3840
        }
    }

    var height: Int {
        switch self {
        case .auto, .r1920x1080: return 1080
        case .r1366x768: return 768
        case .r1536x864: return 864
        case .r1440x900: return 900
        case .r1280x720: return 720
        case .r2560x1440: return 1440
        case .r1680x1050: return 1050
        case .r1600x900: return 900
        case .r2560x1600: return 1600
        case .r3840x2160: return 2160
        }
    }
}

