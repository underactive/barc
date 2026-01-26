import Foundation
import SwiftUI
import WebKit

/// Manages all privacy-related settings and data for the browser.
/// 
/// This singleton class handles:
/// - Storage whitelist management (domains that persist data)
/// - Custom blocklist management (user-defined blocked domains)
/// - Privacy feature toggles (fingerprinting protection, etc.)
/// - Website data clearing operations
/// 
/// All settings are persisted to UserDefaults and automatically synced across the app.
final class PrivacySettings: ObservableObject {
    static let shared = PrivacySettings()

    private let whitelistKey = "privacy.storageWhitelist"
    private let customBlocklistKey = "privacy.customBlocklist"

    // MARK: - Privacy Toggles

    @AppStorage("privacy.nonPersistentStorage") var nonPersistentStorage: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
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
        // Initialize privacy score - @AppStorage properties are already loaded synchronously
        updatePrivacyScore()
    }

    private func loadWhitelist() {
        guard let data = UserDefaults.standard.data(forKey: whitelistKey) else {
            return
        }
        
        do {
            let domains = try JSONDecoder().decode([String].self, from: data)
            whitelistedDomains = domains
        } catch {
            print("[Barc] Failed to decode whitelist: \(error.localizedDescription)")
            // Reset to empty array on decode failure
            whitelistedDomains = []
        }
    }

    private func saveWhitelist() {
        do {
            let data = try JSONEncoder().encode(whitelistedDomains)
            UserDefaults.standard.set(data, forKey: whitelistKey)
        } catch {
            print("[Barc] Failed to encode whitelist: \(error.localizedDescription)")
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
        guard let data = UserDefaults.standard.data(forKey: customBlocklistKey) else {
            return
        }
        
        do {
            let domains = try JSONDecoder().decode([String].self, from: data)
            customBlockedDomains = domains
        } catch {
            print("[Barc] Failed to decode custom blocklist: \(error.localizedDescription)")
            // Reset to empty array on decode failure
            customBlockedDomains = []
        }
    }

    private func saveCustomBlocklist() {
        do {
            let data = try JSONEncoder().encode(customBlockedDomains)
            UserDefaults.standard.set(data, forKey: customBlocklistKey)
        } catch {
            print("[Barc] Failed to encode custom blocklist: \(error.localizedDescription)")
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

    /// Normalizes a domain string by removing protocol, path, and www prefix.
    /// 
    /// This ensures consistent domain matching regardless of how the user enters it.
    /// Examples:
    /// - "https://www.example.com/path" -> "example.com"
    /// - "www.example.com" -> "example.com"
    /// - "example.com" -> "example.com"
    private func normalizeDomain(_ domain: String) -> String {
        var normalized = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove protocol if present (e.g., "https://" or "http://")
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

    /// Clears website data (cookies, localStorage, etc.) for all domains not in the whitelist.
    /// 
    /// This is used when "Non-Persistent Storage" is enabled. It fetches all website data records,
    /// filters out whitelisted domains, and removes data for the remaining domains.
    /// This operation is asynchronous and runs in the background.
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
    /// Clears all website data regardless of whitelist status.
    /// 
    /// This is a destructive operation that removes all cookies, localStorage, and other
    /// website data stored by WebKit. Use with caution.
    func clearAllWebsiteData() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {
            print("[Barc] Cleared all website data")
        }
    }

    @AppStorage("privacy.canvasFingerprintProtection") var canvasFingerprintProtection: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.webGLFingerprintProtection") var webGLFingerprintProtection: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.webRTCProtection") var webRTCProtection: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.trackerBlocking") var trackerBlocking: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.hardwareFingerprintResistance") var hardwareFingerprintResistance: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.fontFingerprintProtection") var fontFingerprintProtection: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.audioContextFingerprintProtection") var audioContextFingerprintProtection: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.batteryAPIBlocking") var batteryAPIBlocking: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.languageSpoofing") var languageSpoofing: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.spoofedLanguage") var spoofedLanguage: SpoofedLanguage = .auto {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.timezoneSpoofing") var timezoneSpoofing: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.spoofedTimezone") var spoofedTimezone: SpoofedTimezone = .auto {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.screenResolutionSpoofing") var screenResolutionSpoofing: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.spoofedResolution") var spoofedResolution: SpoofedResolution = .auto {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.trackingPixelBlocking") var trackingPixelBlocking: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.popupBlocking") var popupBlocking: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.thirdPartyCookieBlocking") var thirdPartyCookieBlocking: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.cookieBannerAutoReject") var cookieBannerAutoReject: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.clipboardAccessBlocking") var clipboardAccessBlocking: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.javaScriptEnabled") var javaScriptEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.blockMediaAutoplay") var blockMediaAutoplay: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.crossSiteTrackingPrevention") var crossSiteTrackingPrevention: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.socialWidgetBlocking") var socialWidgetBlocking: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.cryptoMinerBlocking") var cryptoMinerBlocking: Bool = true {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.fraudulentWebsiteWarning") var fraudulentWebsiteWarning: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.httpsOnlyMode") var httpsOnlyMode: HTTPSOnlyMode = .upgrade {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.referrerPolicy") var referrerPolicy: ReferrerPolicy = .strictOrigin {
        didSet {
            objectWillChange.send()
            updatePrivacyScore()
        }
    }

    @AppStorage("privacy.blockYouTubeShorts") var blockYouTubeShorts: Bool = false {
        didSet {
            objectWillChange.send()
        }
    }

    // MARK: - UI Preferences

    @AppStorage("privacy.suppressFingerprintWarning") var suppressFingerprintWarning: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage("privacy.hasShownYouTubeWhitelistPrompt") var hasShownYouTubeWhitelistPrompt: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Check if youtube.com is in the storage whitelist
    var isYouTubeWhitelisted: Bool {
        whitelistedDomains.contains { domain in
            domain == "youtube.com" || domain == "www.youtube.com"
        }
    }

    /// Add youtube.com to the storage whitelist
    func whitelistYouTube() {
        if !isYouTubeWhitelisted {
            addWhitelistedDomain("youtube.com")
        }
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

    @AppStorage("general.throbberSize") var throbberSize: ThrobberSize = .small {
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

    /// Built-in crypto mining domains (single source of truth)
    static let builtInMiningDomains: [TrackerDomain] = [
        // Major mining services (defunct but may still appear)
        TrackerDomain("coinhive.com", "Coinhive (defunct)"),
        TrackerDomain("coin-hive.com", "Coinhive alternate"),
        TrackerDomain("authedmine.com", "Coinhive AuthedMine"),
        TrackerDomain("crypto-loot.com", "CryptoLoot"),
        TrackerDomain("cryptoloot.pro", "CryptoLoot"),
        TrackerDomain("minero.cc", "Minero"),
        TrackerDomain("webmine.pro", "WebMine"),
        TrackerDomain("webminepool.com", "WebMinePool"),
        TrackerDomain("jsecoin.com", "JSEcoin"),
        TrackerDomain("monerominer.rocks", "Monero Miner"),
        TrackerDomain("2giga.link", "Mining redirector"),
        TrackerDomain("hashforcash.us", "HashForCash"),
        TrackerDomain("coinerra.com", "CoinErra"),
        TrackerDomain("coin-have.com", "CoinHave"),
        TrackerDomain("coinblind.com", "CoinBlind"),
        TrackerDomain("coinnebula.com", "CoinNebula"),
        TrackerDomain("miner.pr0gramm.com", "pr0gramm miner"),
        TrackerDomain("minemytraffic.com", "MineMyTraffic"),
        TrackerDomain("ppoi.org", "PPOI miner"),
        TrackerDomain("projectpoi.com", "Project POI"),
        TrackerDomain("cryptonight.wasm", "CryptoNight WASM"),
        TrackerDomain("papoto.com", "Papoto miner"),
        TrackerDomain("coinlab.biz", "CoinLab"),
        TrackerDomain("ad-miner.com", "Ad-Miner"),
        TrackerDomain("party-nngvitbizn.now.sh", "Party miner"),
        TrackerDomain("webminerpool.com", "WebMinerPool"),
        // Mining pools commonly abused for browser mining
        TrackerDomain("minergate.com", "MinerGate"),
        TrackerDomain("load.jsecoin.com", "JSEcoin loader"),
        TrackerDomain("static.reasedoper.pw", "Reasedoper miner"),
        TrackerDomain("mataharirama.xyz", "Matahari miner"),
        TrackerDomain("listat.biz", "Listat miner"),
        TrackerDomain("lmodr.biz", "Lmodr miner"),
        TrackerDomain("jyhfuqoh.info", "Obfuscated miner"),
        TrackerDomain("gridcash.net", "GridCash"),
        TrackerDomain("coinpot.co", "CoinPot"),
        TrackerDomain("coinpirate.cf", "CoinPirate"),
        TrackerDomain("rocks.io", "Rocks miner"),
        TrackerDomain("cookiescript.info", "CookieScript miner"),
        TrackerDomain("cookiescriptcdn.pro", "CookieScript CDN"),
        TrackerDomain("cryptaloot.pro", "Cryptaloot"),
        TrackerDomain("bjorksta.men", "Bjorksta miner"),
        TrackerDomain("crypto.csgocpu.com", "CSGO CPU miner"),
        TrackerDomain("noblock.pro", "NoBlock miner"),
        TrackerDomain("freecontent.bid", "FreeContent miner"),
        TrackerDomain("freecontent.date", "FreeContent miner"),
        TrackerDomain("freecontent.faith", "FreeContent miner"),
        TrackerDomain("freecontent.party", "FreeContent miner"),
        TrackerDomain("freecontent.science", "FreeContent miner"),
        TrackerDomain("freecontent.stream", "FreeContent miner"),
        TrackerDomain("freecontent.trade", "FreeContent miner"),
        TrackerDomain("freecontent.win", "FreeContent miner")
    ]

    /// Built-in tracker domain names only (for blocking logic)
    private var builtInBlockedDomains: [String] {
        Self.builtInTrackerDomains.map { $0.domain }
    }

    /// Built-in mining domain names only (for blocking logic)
    private var builtInMiningBlockedDomains: [String] {
        Self.builtInMiningDomains.map { $0.domain }
    }

    /// Combined list of all blocked domains (built-in trackers + miners + custom blocklist)
    var blockedDomains: [String] {
        var domains: [String] = []

        // Add built-in tracker domains if tracker blocking is enabled
        if trackerBlocking {
            domains.append(contentsOf: builtInBlockedDomains)
        }

        // Add built-in mining domains if crypto miner blocking is enabled
        if cryptoMinerBlocking {
            domains.append(contentsOf: builtInMiningBlockedDomains)
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

    // MARK: - Privacy Score (Single Source of Truth)

    /// Maximum privacy score (excluding nuclear options like JS disable)
    static let maxPrivacyScore: Int = 23

    /// Current privacy score based on enabled protections (cached for performance)
    /// 
    /// This is a @Published property that automatically updates when any privacy setting changes.
    /// The score is calculated once and cached, avoiding repeated computation on every access.
    @Published private(set) var privacyScore: Int = 0

    /// Calculates and updates the cached privacy score.
    /// 
    /// This method should be called whenever any privacy setting changes to keep the score in sync.
    private func updatePrivacyScore() {
        var score = 0
        if nonPersistentStorage { score += 1 }
        if canvasFingerprintProtection { score += 1 }
        if webGLFingerprintProtection { score += 1 }
        if webRTCProtection { score += 1 }
        if trackerBlocking { score += 1 }
        if hardwareFingerprintResistance { score += 1 }
        if fontFingerprintProtection { score += 1 }
        if audioContextFingerprintProtection { score += 1 }
        if batteryAPIBlocking { score += 1 }
        if languageSpoofing { score += 1 }
        if timezoneSpoofing { score += 1 }
        if screenResolutionSpoofing { score += 1 }
        if trackingPixelBlocking { score += 1 }
        if popupBlocking { score += 1 }
        if thirdPartyCookieBlocking { score += 1 }
        if cookieBannerAutoReject { score += 1 }
        if clipboardAccessBlocking { score += 1 }
        if blockMediaAutoplay { score += 1 }
        if crossSiteTrackingPrevention { score += 1 }
        if socialWidgetBlocking { score += 1 }
        if cryptoMinerBlocking { score += 1 }
        if httpsOnlyMode != .off { score += 1 }
        if referrerPolicy != .defaultPolicy { score += 1 }
        // Note: javaScriptEnabled is intentionally excluded (nuclear option)
        privacyScore = score
    }

    /// Privacy score as a percentage (0.0 to 1.0)
    var privacyScorePercent: Double {
        Double(privacyScore) / Double(Self.maxPrivacyScore)
    }

    /// Color for privacy score display
    var privacyScoreColor: Color {
        switch privacyScorePercent {
        case 1.0: return .green
        case 0.8..<1.0: return .blue
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    /// Icon for privacy score display
    var privacyScoreIcon: String {
        switch privacyScorePercent {
        case 1.0: return "shield.checkered"
        case 0.8..<1.0: return "shield.lefthalf.filled"
        case 0.5..<0.8: return "shield"
        default: return "shield.slash"
        }
    }

    /// Description of current privacy protection level
    var privacyScoreDescription: String {
        switch privacyScorePercent {
        case 1.0: return "Maximum protection"
        case 0.8..<1.0: return "Strong protection"
        case 0.5..<0.8: return "Moderate protection"
        default: return "Limited protection"
        }
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
        blockMediaAutoplay = true
        crossSiteTrackingPrevention = true
        socialWidgetBlocking = true
        cryptoMinerBlocking = true
        fraudulentWebsiteWarning = true
        httpsOnlyMode = .upgrade
        referrerPolicy = .strictOrigin
        blockYouTubeShorts = false
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

