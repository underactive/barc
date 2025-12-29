import Foundation
import SwiftUI

class NetworkActivityMonitor: ObservableObject {
    static let shared = NetworkActivityMonitor()

    @Published var isReceiving: Bool = false
    @Published var isTransmitting: Bool = false

    // Track which tab is active and which tab last reported activity
    var activeTabId: UUID?
    @Published private(set) var lastTransmitTabId: UUID?
    @Published private(set) var lastReceiveTabId: UUID?

    // Setting for whether indicators show activity from all tabs or just active tab
    @Published var indicatorScope: NetworkSoundScope {
        didSet {
            UserDefaults.standard.set(indicatorScope.rawValue, forKey: "network.indicatorScope")
        }
    }

    private var rxTimer: Timer?
    private var txTimer: Timer?

    private let activityDuration: TimeInterval = 0.15

    private init() {
        // Default indicator scope to all tabs
        self.indicatorScope = NetworkSoundScope(rawValue: UserDefaults.standard.string(forKey: "network.indicatorScope") ?? "allTabs") ?? .allTabs
    }

    func reportTransmit(tabId: UUID? = nil) {
        DispatchQueue.main.async {
            self.lastTransmitTabId = tabId

            // Check if we should show indicator based on scope
            let shouldShow = self.indicatorScope == .allTabs || self.isTabActive(tabId)
            guard shouldShow else { return }

            self.isTransmitting = true
            self.txTimer?.invalidate()
            self.txTimer = Timer.scheduledTimer(withTimeInterval: self.activityDuration, repeats: false) { [weak self] _ in
                self?.isTransmitting = false
            }
        }
    }

    func reportReceive(tabId: UUID? = nil) {
        DispatchQueue.main.async {
            self.lastReceiveTabId = tabId

            // Check if we should show indicator based on scope
            let shouldShow = self.indicatorScope == .allTabs || self.isTabActive(tabId)
            guard shouldShow else { return }

            self.isReceiving = true
            self.rxTimer?.invalidate()
            self.rxTimer = Timer.scheduledTimer(withTimeInterval: self.activityDuration, repeats: false) { [weak self] _ in
                self?.isReceiving = false
            }
        }
    }

    private func isTabActive(_ tabId: UUID?) -> Bool {
        guard let activeTabId = activeTabId, let tabId = tabId else {
            return true // If we don't have tab info, assume it's active
        }
        return activeTabId == tabId
    }

    func reportActivity(tabId: UUID? = nil, tx: Bool = false, rx: Bool = false) {
        if tx { reportTransmit(tabId: tabId) }
        if rx { reportReceive(tabId: tabId) }
    }

    /// Check if the last transmit came from the active tab
    var lastTransmitWasActiveTab: Bool {
        guard let activeTabId = activeTabId, let lastTransmitTabId = lastTransmitTabId else {
            return true // If we don't have tab info, assume it's active
        }
        return activeTabId == lastTransmitTabId
    }

    /// Check if the last receive came from the active tab
    var lastReceiveWasActiveTab: Bool {
        guard let activeTabId = activeTabId, let lastReceiveTabId = lastReceiveTabId else {
            return true // If we don't have tab info, assume it's active
        }
        return activeTabId == lastReceiveTabId
    }
}
