import Foundation
import SwiftUI
import WebKit

class PrivacySettings: ObservableObject {
    static let shared = PrivacySettings()

    private let whitelistKey = "privacy.storageWhitelist"

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

    private init() {
        loadWhitelist()
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

    @AppStorage("privacy.webRTCProtection") var webRTCProtection: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.trackerBlocking") var trackerBlocking: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.hardwareFingerprintResistance") var hardwareFingerprintResistance: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.trackingPixelBlocking") var trackingPixelBlocking: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.popupBlocking") var popupBlocking: Bool = true {
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

    // MARK: - Blocked Domains

    var blockedDomains: [String] {
        guard trackerBlocking else { return [] }
        return [
            "doubleclick.net",
            "googleadservices.com",
            "googlesyndication.com",
            "google-analytics.com",
            "facebook.net",
            "connect.facebook.com",
            "facebook.com/tr",
            "amazon-adsystem.com",
            "adnxs.com",
            "adsrvr.org",
            "criteo.com",
            "criteo.net",
            "outbrain.com",
            "taboola.com",
            "scorecardresearch.com",
            "quantserve.com",
            "rubiconproject.com",
            "pubmatic.com",
            "openx.net",
            "casalemedia.com",
            "advertising.com",
            "bluekai.com",
            "exelator.com",
            "turn.com",
            "everesttech.net"
        ]
    }

    var searchEngineURL: String {
        searchEngine.searchURL
    }

    // MARK: - Reset

    func resetToDefaults() {
        nonPersistentStorage = true
        canvasFingerprintProtection = true
        webRTCProtection = true
        trackerBlocking = true
        hardwareFingerprintResistance = true
        trackingPixelBlocking = true
        popupBlocking = true
        fraudulentWebsiteWarning = true
        httpsOnlyMode = .upgrade
        referrerPolicy = .strictOrigin
        searchEngine = .kagi
        homePage = "https://kagi.com"
        newTabBehavior = .homePage
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
