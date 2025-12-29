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

    // Track which tabs are currently transmitting/receiving (for background tab indicators)
    @Published private(set) var transmittingTabIds: Set<UUID> = []
    @Published private(set) var receivingTabIds: Set<UUID> = []
    private var tabTransmitTimers: [UUID: Timer] = [:]
    private var tabReceiveTimers: [UUID: Timer] = [:]

    // Setting for whether to show network activity indicators in the URL bar
    @Published var showURLBarNetworkActivity: Bool {
        didSet {
            UserDefaults.standard.set(showURLBarNetworkActivity, forKey: "network.showURLBarNetworkActivity")
        }
    }

    // Setting for whether indicators show activity from all tabs or just active tab
    @Published var indicatorScope: NetworkSoundScope {
        didSet {
            UserDefaults.standard.set(indicatorScope.rawValue, forKey: "network.indicatorScope")
        }
    }

    // Setting for whether to show activity indicators on background tabs
    @Published var showBackgroundTabIndicators: Bool {
        didSet {
            UserDefaults.standard.set(showBackgroundTabIndicators, forKey: "network.showBackgroundTabIndicators")
        }
    }

    private var rxTimer: Timer?
    private var txTimer: Timer?

    private let activityDuration: TimeInterval = 0.15
    private let tabActivityDuration: TimeInterval = 0.3 // Longer duration for tab border flash

    private init() {
        // Default to showing URL bar network activity
        if UserDefaults.standard.object(forKey: "network.showURLBarNetworkActivity") == nil {
            UserDefaults.standard.set(true, forKey: "network.showURLBarNetworkActivity")
        }
        self.showURLBarNetworkActivity = UserDefaults.standard.bool(forKey: "network.showURLBarNetworkActivity")

        // Default indicator scope to active tab only
        self.indicatorScope = NetworkSoundScope(rawValue: UserDefaults.standard.string(forKey: "network.indicatorScope") ?? "activeTabOnly") ?? .activeTabOnly

        // Default to showing background tab indicators
        if UserDefaults.standard.object(forKey: "network.showBackgroundTabIndicators") == nil {
            UserDefaults.standard.set(true, forKey: "network.showBackgroundTabIndicators")
        }
        self.showBackgroundTabIndicators = UserDefaults.standard.bool(forKey: "network.showBackgroundTabIndicators")
    }

    func reportTransmit(tabId: UUID? = nil) {
        DispatchQueue.main.async {
            self.lastTransmitTabId = tabId

            // Track per-tab transmitting state for background tab indicators
            if let tabId = tabId {
                self.transmittingTabIds.insert(tabId)
                self.tabTransmitTimers[tabId]?.invalidate()
                self.tabTransmitTimers[tabId] = Timer.scheduledTimer(withTimeInterval: self.tabActivityDuration, repeats: false) { [weak self] _ in
                    self?.transmittingTabIds.remove(tabId)
                    self?.tabTransmitTimers.removeValue(forKey: tabId)
                }
            }

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

            // Track per-tab receiving state for background tab indicators
            if let tabId = tabId {
                self.receivingTabIds.insert(tabId)
                self.tabReceiveTimers[tabId]?.invalidate()
                self.tabReceiveTimers[tabId] = Timer.scheduledTimer(withTimeInterval: self.tabActivityDuration, repeats: false) { [weak self] _ in
                    self?.receivingTabIds.remove(tabId)
                    self?.tabReceiveTimers.removeValue(forKey: tabId)
                }
            }

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

    /// Check if a specific tab is currently transmitting
    func isTabTransmitting(_ tabId: UUID) -> Bool {
        transmittingTabIds.contains(tabId)
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
