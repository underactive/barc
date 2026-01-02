import Foundation
import SwiftUI

/// Tracks blocked requests per tab for displaying feedback to users
final class BlockedRequestsMonitor: ObservableObject {
    static let shared = BlockedRequestsMonitor()

    /// Blocked domain info with timestamp
    struct BlockedRequest: Identifiable, Equatable {
        let id = UUID()
        let domain: String
        let url: String
        let timestamp: Date
        let reason: BlockReason

        enum BlockReason: String {
            case tracker = "Tracker"
            case customBlocklist = "Custom Blocklist"
            case trackingPixel = "Tracking Pixel"
            case cryptoMiner = "Crypto Miner"
        }

        static func == (lhs: BlockedRequest, rhs: BlockedRequest) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Blocked requests per tab
    @Published private(set) var blockedRequestsByTab: [UUID: [BlockedRequest]] = [:]

    /// Currently active tab ID (set by BrowserState)
    var activeTabId: UUID?

    private init() {}

    /// Get blocked requests for a specific tab
    func blockedRequests(for tabId: UUID) -> [BlockedRequest] {
        blockedRequestsByTab[tabId] ?? []
    }

    /// Get blocked request count for a specific tab
    func blockedCount(for tabId: UUID) -> Int {
        blockedRequestsByTab[tabId]?.count ?? 0
    }

    /// Get blocked requests for the active tab
    var activeTabBlockedRequests: [BlockedRequest] {
        guard let tabId = activeTabId else { return [] }
        return blockedRequests(for: tabId)
    }

    /// Get blocked count for the active tab
    var activeTabBlockedCount: Int {
        guard let tabId = activeTabId else { return 0 }
        return blockedCount(for: tabId)
    }

    /// Get unique blocked domains for a tab (for summary display)
    func uniqueBlockedDomains(for tabId: UUID) -> [String] {
        let requests = blockedRequests(for: tabId)
        var seen = Set<String>()
        var unique: [String] = []
        for request in requests {
            if !seen.contains(request.domain) {
                seen.insert(request.domain)
                unique.append(request.domain)
            }
        }
        return unique
    }

    /// Report a blocked request
    func reportBlocked(domain: String, url: String, tabId: UUID, reason: BlockedRequest.BlockReason) {
        DispatchQueue.main.async {
            let request = BlockedRequest(
                domain: domain,
                url: url,
                timestamp: Date(),
                reason: reason
            )

            if self.blockedRequestsByTab[tabId] == nil {
                self.blockedRequestsByTab[tabId] = []
            }
            self.blockedRequestsByTab[tabId]?.append(request)
        }
    }

    /// Clear blocked requests for a tab (called on navigation to new page)
    func clearBlocked(for tabId: UUID) {
        DispatchQueue.main.async {
            self.blockedRequestsByTab[tabId] = []
        }
    }

    /// Clear all blocked requests for a tab (called when tab is closed)
    func removeTab(_ tabId: UUID) {
        DispatchQueue.main.async {
            self.blockedRequestsByTab.removeValue(forKey: tabId)
        }
    }
}
