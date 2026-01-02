import Foundation

enum SpoofedTimezone: String, CaseIterable, Identifiable {
    case auto = "auto"
    case utc = "UTC"
    case americaNewYork = "America/New_York"
    case americaLosAngeles = "America/Los_Angeles"
    case americaChicago = "America/Chicago"
    case europeLondon = "Europe/London"
    case europeParis = "Europe/Paris"
    case europeBerlin = "Europe/Berlin"
    case asiaTokyo = "Asia/Tokyo"
    case asiaShanghai = "Asia/Shanghai"
    case asiaKolkata = "Asia/Kolkata"
    case australiaSydney = "Australia/Sydney"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto (avoid system timezone)"
        case .utc: return "UTC (Coordinated Universal Time)"
        case .americaNewYork: return "America/New_York (EST/EDT)"
        case .americaLosAngeles: return "America/Los_Angeles (PST/PDT)"
        case .americaChicago: return "America/Chicago (CST/CDT)"
        case .europeLondon: return "Europe/London (GMT/BST)"
        case .europeParis: return "Europe/Paris (CET/CEST)"
        case .europeBerlin: return "Europe/Berlin (CET/CEST)"
        case .asiaTokyo: return "Asia/Tokyo (JST)"
        case .asiaShanghai: return "Asia/Shanghai (CST)"
        case .asiaKolkata: return "Asia/Kolkata (IST)"
        case .australiaSydney: return "Australia/Sydney (AEST/AEDT)"
        }
    }

    var timezoneIdentifier: String {
        switch self {
        case .auto: return "UTC" // Default fallback
        case .utc: return "UTC"
        case .americaNewYork: return "America/New_York"
        case .americaLosAngeles: return "America/Los_Angeles"
        case .americaChicago: return "America/Chicago"
        case .europeLondon: return "Europe/London"
        case .europeParis: return "Europe/Paris"
        case .europeBerlin: return "Europe/Berlin"
        case .asiaTokyo: return "Asia/Tokyo"
        case .asiaShanghai: return "Asia/Shanghai"
        case .asiaKolkata: return "Asia/Kolkata"
        case .australiaSydney: return "Australia/Sydney"
        }
    }

    /// Returns the UTC offset in minutes for this timezone (approximate, doesn't account for DST dynamically)
    var utcOffsetMinutes: Int {
        switch self {
        case .auto, .utc: return 0
        case .americaNewYork: return -300 // -5 hours (EST), -4 (EDT)
        case .americaLosAngeles: return -480 // -8 hours (PST), -7 (PDT)
        case .americaChicago: return -360 // -6 hours (CST), -5 (CDT)
        case .europeLondon: return 0 // 0 (GMT), +1 (BST)
        case .europeParis, .europeBerlin: return 60 // +1 hour (CET), +2 (CEST)
        case .asiaTokyo: return 540 // +9 hours
        case .asiaShanghai: return 480 // +8 hours
        case .asiaKolkata: return 330 // +5:30
        case .australiaSydney: return 600 // +10 hours (AEST), +11 (AEDT)
        }
    }
}

