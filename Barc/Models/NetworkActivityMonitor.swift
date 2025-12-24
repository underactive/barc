import Foundation
import SwiftUI

class NetworkActivityMonitor: ObservableObject {
    static let shared = NetworkActivityMonitor()

    @Published var isReceiving: Bool = false
    @Published var isTransmitting: Bool = false

    private var rxTimer: Timer?
    private var txTimer: Timer?

    private let activityDuration: TimeInterval = 0.15

    private init() {}

    func reportTransmit() {
        DispatchQueue.main.async {
            self.isTransmitting = true
            self.txTimer?.invalidate()
            self.txTimer = Timer.scheduledTimer(withTimeInterval: self.activityDuration, repeats: false) { [weak self] _ in
                self?.isTransmitting = false
            }
        }
    }

    func reportReceive() {
        DispatchQueue.main.async {
            self.isReceiving = true
            self.rxTimer?.invalidate()
            self.rxTimer = Timer.scheduledTimer(withTimeInterval: self.activityDuration, repeats: false) { [weak self] _ in
                self?.isReceiving = false
            }
        }
    }

    func reportActivity(tx: Bool = false, rx: Bool = false) {
        if tx { reportTransmit() }
        if rx { reportReceive() }
    }
}
