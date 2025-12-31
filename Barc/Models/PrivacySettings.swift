import Foundation
import SwiftUI
import WebKit

class PrivacySettings: ObservableObject {
    static let shared = PrivacySettings()

    private let whitelistKey = "privacy.storageWhitelist"
    private let customBlocklistKey = "privacy.customBlocklist"

    // MARK: - Privacy Toggles

    @AppStorage("privacy.nonPersistentStorage") var nonPersistentStorage: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - Storage Whitelist

    @Published var whitelistedDomains: [String] = [] {
        didSet {
            saveWhitelist()
            objectWillChange.send()
        }
    }

    // MARK: - Custom Blocklist

    @AppStorage("privacy.customBlocklistEnabled") var customBlocklistEnabled: Bool = false {
        didSet { objectWillChange.send() }
    }

    @Published var customBlockedDomains: [String] = [] {
        didSet {
            saveCustomBlocklist()
            objectWillChange.send()
        }
    }

    private init() {
        loadWhitelist()
        loadCustomBlocklist()
    }

    private func loadWhitelist() {
        if let data = UserDefaults.standard.data(forKey: whitelistKey),
           let domains = try? JSONDecoder().decode([String].self, from: data) {
            whitelistedDomains = domains
        }
    }

    private func saveWhitelist() {
        if let data = try? JSONEncoder().encode(whitelistedDomains) {
            UserDefaults.standard.set(data, forKey: whitelistKey)
        }
    }

    func addWhitelistedDomain(_ domain: String) {
        let normalized = normalizeDomain(domain)
        guard !normalized.isEmpty, !whitelistedDomains.contains(normalized) else { return }
        whitelistedDomains.append(normalized)
    }

    func removeWhitelistedDomain(_ domain: String) {
        whitelistedDomains.removeAll { $0 == domain }
    }

    func isDomainWhitelisted(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return whitelistedDomains.contains { whitelisted in
            host == whitelisted || host.hasSuffix(".\(whitelisted)")
        }
    }

    // MARK: - Custom Blocklist Management

    private func loadCustomBlocklist() {
        if let data = UserDefaults.standard.data(forKey: customBlocklistKey),
           let domains = try? JSONDecoder().decode([String].self, from: data) {
            customBlockedDomains = domains
        }
    }

    private func saveCustomBlocklist() {
        if let data = try? JSONEncoder().encode(customBlockedDomains) {
            UserDefaults.standard.set(data, forKey: customBlocklistKey)
        }
    }

    func addCustomBlockedDomain(_ domain: String) {
        let normalized = normalizeDomain(domain)
        guard !normalized.isEmpty, !customBlockedDomains.contains(normalized) else { return }
        customBlockedDomains.append(normalized)
    }

    func removeCustomBlockedDomain(_ domain: String) {
        customBlockedDomains.removeAll { $0 == domain }
    }

    func isDomainCustomBlocked(_ url: URL?) -> Bool {
        guard customBlocklistEnabled, let host = url?.host?.lowercased() else { return false }
        return customBlockedDomains.contains { blocked in
            host == blocked || host.hasSuffix(".\(blocked)")
        }
    }

    private func normalizeDomain(_ domain: String) -> String {
        var normalized = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove protocol if present
        if let range = normalized.range(of: "://") {
            normalized = String(normalized[range.upperBound...])
        }
        // Remove path if present
        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<slashIndex])
        }
        // Remove www. prefix
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }
        return normalized
    }

    // MARK: - Website Data Management

    /// Clears website data for all non-whitelisted domains
    func clearNonWhitelistedData() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: dataTypes) { [weak self] records in
            guard let self = self else { return }

            let recordsToDelete = records.filter { record in
                !self.whitelistedDomains.contains { whitelisted in
                    record.displayName.lowercased() == whitelisted ||
                    record.displayName.lowercased().hasSuffix(".\(whitelisted)")
                }
            }

            if !recordsToDelete.isEmpty {
                dataStore.removeData(ofTypes: dataTypes, for: recordsToDelete) {
                    print("[Barc] Cleared data for \(recordsToDelete.count) non-whitelisted domains")
                }
            }
        }
    }

    /// Clears all website data including whitelisted domains
    func clearAllWebsiteData() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {
            print("[Barc] Cleared all website data")
        }
    }

    @AppStorage("privacy.canvasFingerprintProtection") var canvasFingerprintProtection: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.webGLFingerprintProtection") var webGLFingerprintProtection: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.webRTCProtection") var webRTCProtection: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.trackerBlocking") var trackerBlocking: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.hardwareFingerprintResistance") var hardwareFingerprintResistance: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.fontFingerprintProtection") var fontFingerprintProtection: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.audioContextFingerprintProtection") var audioContextFingerprintProtection: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.batteryAPIBlocking") var batteryAPIBlocking: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.languageSpoofing") var languageSpoofing: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.spoofedLanguage") var spoofedLanguage: SpoofedLanguage = .auto {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.timezoneSpoofing") var timezoneSpoofing: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.spoofedTimezone") var spoofedTimezone: SpoofedTimezone = .auto {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.screenResolutionSpoofing") var screenResolutionSpoofing: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.spoofedResolution") var spoofedResolution: SpoofedResolution = .auto {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.trackingPixelBlocking") var trackingPixelBlocking: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.popupBlocking") var popupBlocking: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.thirdPartyCookieBlocking") var thirdPartyCookieBlocking: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.cookieBannerAutoReject") var cookieBannerAutoReject: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.clipboardAccessBlocking") var clipboardAccessBlocking: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.javaScriptEnabled") var javaScriptEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.fraudulentWebsiteWarning") var fraudulentWebsiteWarning: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.httpsOnlyMode") var httpsOnlyMode: HTTPSOnlyMode = .upgrade {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.referrerPolicy") var referrerPolicy: ReferrerPolicy = .strictOrigin {
        didSet { objectWillChange.send() }
    }

    // MARK: - UI Preferences

    @AppStorage("privacy.suppressFingerprintWarning") var suppressFingerprintWarning: Bool = false {
        didSet { objectWillChange.send() }
    }

    // MARK: - General Settings

    @AppStorage("general.searchEngine") var searchEngine: SearchEngine = .kagi {
        didSet { objectWillChange.send() }
    }

    @AppStorage("general.homePage") var homePage: String = "https://kagi.com" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("general.newTabBehavior") var newTabBehavior: NewTabBehavior = .homePage {
        didSet { objectWillChange.send() }
    }

    @AppStorage("general.downloadLocation") var downloadLocation: String = "~/Downloads" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("general.showLoadingThrobber") var showLoadingThrobber: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - Blocked Domains

    /// Built-in tracker domains with descriptions (single source of truth)
    static let builtInTrackerDomains: [TrackerDomain] = [
        TrackerDomain("doubleclick.net", "Google advertising"),
        TrackerDomain("googleadservices.com", "Google ads"),
        TrackerDomain("googlesyndication.com", "Google ad syndication"),
        TrackerDomain("google-analytics.com", "Google Analytics"),
        TrackerDomain("facebook.net", "Facebook scripts"),
        TrackerDomain("connect.facebook.com", "Facebook Connect"),
        TrackerDomain("facebook.com/tr", "Facebook tracking pixel"),
        TrackerDomain("amazon-adsystem.com", "Amazon ads"),
        TrackerDomain("adnxs.com", "AppNexus (Microsoft)"),
        TrackerDomain("adsrvr.org", "The Trade Desk"),
        TrackerDomain("criteo.com", "Criteo retargeting"),
        TrackerDomain("criteo.net", "Criteo retargeting"),
        TrackerDomain("outbrain.com", "Outbrain content ads"),
        TrackerDomain("taboola.com", "Taboola content ads"),
        TrackerDomain("scorecardresearch.com", "comScore analytics"),
        TrackerDomain("quantserve.com", "Quantcast"),
        TrackerDomain("rubiconproject.com", "Rubicon Project"),
        TrackerDomain("pubmatic.com", "PubMatic ads"),
        TrackerDomain("openx.net", "OpenX ads"),
        TrackerDomain("casalemedia.com", "Index Exchange"),
        TrackerDomain("advertising.com", "AOL/Verizon advertising"),
        TrackerDomain("bluekai.com", "Oracle Data Cloud"),
        TrackerDomain("exelator.com", "Nielsen eXelate"),
        TrackerDomain("turn.com", "Amobee"),
        TrackerDomain("everesttech.net", "Adobe Advertising Cloud")
    ]

    /// Built-in tracker domain names only (for blocking logic)
    private var builtInBlockedDomains: [String] {
        Self.builtInTrackerDomains.map { $0.domain }
    }

    /// Combined list of all blocked domains (built-in trackers + custom blocklist)
    var blockedDomains: [String] {
        var domains: [String] = []

        // Add built-in tracker domains if tracker blocking is enabled
        if trackerBlocking {
            domains.append(contentsOf: builtInBlockedDomains)
        }

        // Add custom blocked domains if custom blocklist is enabled
        if customBlocklistEnabled {
            domains.append(contentsOf: customBlockedDomains)
        }

        return domains
    }

    var searchEngineURL: String {
        searchEngine.searchURL
    }

    // MARK: - Reset

    func resetToDefaults() {
        nonPersistentStorage = true
        canvasFingerprintProtection = true
        webGLFingerprintProtection = true
        webRTCProtection = true
        trackerBlocking = true
        hardwareFingerprintResistance = true
        fontFingerprintProtection = true
        audioContextFingerprintProtection = true
        batteryAPIBlocking = true
        languageSpoofing = true
        spoofedLanguage = .auto
        timezoneSpoofing = true
        spoofedTimezone = .auto
        screenResolutionSpoofing = true
        spoofedResolution = .auto
        trackingPixelBlocking = true
        popupBlocking = true
        thirdPartyCookieBlocking = true
        cookieBannerAutoReject = true
        clipboardAccessBlocking = true
        javaScriptEnabled = true
        fraudulentWebsiteWarning = true
        httpsOnlyMode = .upgrade
        referrerPolicy = .strictOrigin
        customBlocklistEnabled = false
        searchEngine = .kagi
        homePage = "https://kagi.com"
        newTabBehavior = .homePage
    }
}

// MARK: - TrackerDomain

struct TrackerDomain: Identifiable {
    let domain: String
    let description: String

    var id: String { domain }

    init(_ domain: String, _ description: String) {
        self.domain = domain
        self.description = description
    }
}

// MARK: - Enums

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
