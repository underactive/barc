import SwiftUI

@main
struct BarcApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var browserState = BrowserState()
    @StateObject private var privacySettings = PrivacySettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(browserState)
                .environmentObject(privacySettings)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    browserState.createNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    browserState.closeCurrentTab()
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button("Reload") {
                    browserState.reloadCurrentTab()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Go Back") {
                    browserState.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Go Forward") {
                    browserState.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(privacySettings)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = PrivacySettings.shared
    private let soundManager = NetworkSoundManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize sound manager (it will start observing if enabled)
        _ = soundManager

        // Clear non-whitelisted data on launch if non-persistent storage is enabled
        if settings.nonPersistentStorage {
            settings.clearNonWhitelistedData()
            print("[Barc] Cleared non-whitelisted website data on launch")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clear non-whitelisted data on quit if non-persistent storage is enabled
        if settings.nonPersistentStorage {
            settings.clearNonWhitelistedData()
            print("[Barc] Clearing non-whitelisted website data on quit")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
