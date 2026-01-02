import Foundation

enum SpoofedLanguage: String, CaseIterable, Identifiable {
    case auto = "auto"
    case enUS = "en-US"
    case enGB = "en-GB"
    case es = "es"
    case fr = "fr"
    case de = "de"
    case pt = "pt"
    case ja = "ja"
    case zhCN = "zh-CN"
    case ko = "ko"
    case ru = "ru"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto (avoid system language)"
        case .enUS: return "English (US)"
        case .enGB: return "English (UK)"
        case .es: return "Spanish"
        case .fr: return "French"
        case .de: return "German"
        case .pt: return "Portuguese"
        case .ja: return "Japanese"
        case .zhCN: return "Chinese (Simplified)"
        case .ko: return "Korean"
        case .ru: return "Russian"
        }
    }

    var languageCode: String {
        switch self {
        case .auto: return "en-US" // Default fallback, actual logic handled in JS
        case .enUS: return "en-US"
        case .enGB: return "en-GB"
        case .es: return "es-ES"
        case .fr: return "fr-FR"
        case .de: return "de-DE"
        case .pt: return "pt-BR"
        case .ja: return "ja-JP"
        case .zhCN: return "zh-CN"
        case .ko: return "ko-KR"
        case .ru: return "ru-RU"
        }
    }

    var languages: [String] {
        switch self {
        case .auto: return ["en-US", "en"] // Default fallback
        case .enUS: return ["en-US", "en"]
        case .enGB: return ["en-GB", "en"]
        case .es: return ["es-ES", "es"]
        case .fr: return ["fr-FR", "fr"]
        case .de: return ["de-DE", "de"]
        case .pt: return ["pt-BR", "pt"]
        case .ja: return ["ja-JP", "ja"]
        case .zhCN: return ["zh-CN", "zh"]
        case .ko: return ["ko-KR", "ko"]
        case .ru: return ["ru-RU", "ru"]
        }
    }
}

