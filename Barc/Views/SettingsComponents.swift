import SwiftUI

enum SettingsTab: Int {
    case general = 0
    case privacy = 1
}

final class SettingsState: ObservableObject {
    static let shared = SettingsState()
    @Published var selectedTab: SettingsTab = .general

    func openPrivacySettings() {
        selectedTab = .privacy
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

