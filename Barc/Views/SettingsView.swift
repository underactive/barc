import SwiftUI
import AppKit

// MARK: - Left-Aligned TextField (fixes macOS Form right-alignment issue)

struct LeftAlignedTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont = .systemFont(ofSize: 12)
    var isEnabled: Bool = true
    var onSubmit: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.font = font
        textField.alignment = .left
        textField.bezelStyle = .roundedBezel
        textField.delegate = context.coordinator
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.truncatesLastVisibleLine = true
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.isEnabled = isEnabled
        nsView.alignment = .left
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LeftAlignedTextField

        init(_ parent: LeftAlignedTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            return false
        }
    }
}

enum SettingsTab: Int {
    case general = 0
    case privacy = 1
}

class SettingsState: ObservableObject {
    static let shared = SettingsState()
    @Published var selectedTab: SettingsTab = .general

    func openPrivacySettings() {
        selectedTab = .privacy
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

struct SettingsView: View {
    @StateObject private var settingsState = SettingsState.shared

    var body: some View {
        TabView(selection: $settingsState.selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            PrivacySettingsView()
                .tabItem {
                    Label("Barc Privacy", systemImage: "shield.checkered")
                }
                .tag(SettingsTab.privacy)
        }
        .frame(width: 550, height: 720)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject private var settings = PrivacySettings.shared
    @ObservedObject private var soundManager = NetworkSoundManager.shared
    @ObservedObject private var networkMonitor = NetworkActivityMonitor.shared
    @State private var homePageText: String = ""

    var body: some View {
        Form {
            Section {
                Picker("Search Engine:", selection: $settings.searchEngine) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Home Page:")
                    LeftAlignedTextField(
                        text: $homePageText,
                        placeholder: "https://kagi.com",
                        onSubmit: { settings.homePage = homePageText }
                    )
                    .onAppear { homePageText = settings.homePage }
                    .onChange(of: homePageText) { _, newValue in
                        settings.homePage = newValue
                    }
                }

                Picker("New Tabs Open With:", selection: $settings.newTabBehavior) {
                    ForEach(NewTabBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Label("Search & Home", systemImage: "magnifyingglass")
                    .font(.headline)
            }

            Section {
                HStack {
                    Text("Save Downloaded Files To:")
                    Spacer()
                    Text(settings.downloadLocation)
                        .foregroundColor(.secondary)
                    Button("Change...") {
                        selectDownloadFolder()
                    }
                }
            } header: {
                Label("Downloads", systemImage: "arrow.down.circle")
                    .font(.headline)
            }

            Section {
                Toggle("Warn when visiting a fraudulent website", isOn: $settings.fraudulentWebsiteWarning)
            } header: {
                Label("Security", systemImage: "lock.shield")
                    .font(.headline)
            }

            Section {
                // MARK: Indicator Lights
                Text("Indicator Lights")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Group {
                    Toggle(isOn: $networkMonitor.showURLBarNetworkActivity) {
                        Text("Show URL bar network activity")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)

                    HStack {
                        Text("URL Bar Network Activity For:")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $networkMonitor.indicatorScope) {
                            ForEach(NetworkSoundScope.allCases) { scope in
                                Text(scope.displayName).tag(scope)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    .disabled(!networkMonitor.showURLBarNetworkActivity)
                    .opacity(networkMonitor.showURLBarNetworkActivity ? 1.0 : 0.5)

                    Toggle(isOn: $networkMonitor.showBackgroundTabIndicators) {
                        Text("Show background tab activity")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                }
                .padding(.leading, 12)

                // MARK: Sounds
                Text("Sounds")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.top, 8)

                Group {
                    Toggle(isOn: $soundManager.isEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Play network activity sound effects")
                                .font(.system(size: 13))
                            Text("Play retro modem sounds when transmitting or receiving data.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Slider(value: $soundManager.volume, in: 0...1)
                            .frame(maxWidth: 200)

                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Text("\(Int(soundManager.volume * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .disabled(!soundManager.isEnabled)
                    .opacity(soundManager.isEnabled ? 1.0 : 0.5)

                    Toggle(isOn: $soundManager.rxEnabled) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(soundManager.isEnabled && soundManager.rxEnabled ? .green : .gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                            Text("Rx (Receive) Sound")
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(!soundManager.isEnabled)
                    .opacity(soundManager.isEnabled ? 1.0 : 0.5)

                    Toggle(isOn: $soundManager.txEnabled) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(soundManager.isEnabled && soundManager.txEnabled ? .red : .gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                            Text("Tx (Transmit) Sound")
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(!soundManager.isEnabled)
                    .opacity(soundManager.isEnabled ? 1.0 : 0.5)

                    HStack {
                        Text("Play Sounds For:")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $soundManager.soundScope) {
                            ForEach(NetworkSoundScope.allCases) { scope in
                                Text(scope.displayName).tag(scope)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    .disabled(!soundManager.isEnabled)
                    .opacity(soundManager.isEnabled ? 1.0 : 0.5)
                }
                .padding(.leading, 12)

            } header: {
                Label("Network Activity", systemImage: "network")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .environment(\.layoutDirection, .leftToRight)
        .padding()
    }

    private func selectDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder for downloads"

        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadLocation = url.path
        }
    }
}

// MARK: - Privacy Settings (Barc-specific)

struct PrivacySettingsView: View {
    @ObservedObject private var settings = PrivacySettings.shared
    @State private var showingResetConfirmation = false
    @State private var newWhitelistDomain: String = ""
    @State private var newBlockedDomain: String = ""
    @State private var showingClearDataConfirmation = false

    var body: some View {
        Form {
            Section {
                PrivacyToggleRow(
                    title: "Non-Persistent Storage",
                    description: "Clear non-whitelisted cookies and storage when Barc quits.",
                    systemImage: "clock.badge.xmark",
                    isOn: $settings.nonPersistentStorage
                )

                // Storage Whitelist
                StorageWhitelistView(settings: settings, newDomain: $newWhitelistDomain)

                PrivacyToggleRow(
                    title: "Canvas Fingerprint Protection",
                    description: "Add subtle noise to canvas data to prevent unique browser identification.",
                    systemImage: "hand.raised.fingers.spread",
                    isOn: $settings.canvasFingerprintProtection
                )

                PrivacyToggleRow(
                    title: "WebGL Fingerprint Protection",
                    description: "Mask WebGL renderer and vendor info used for browser identification.",
                    systemImage: "cube.transparent",
                    isOn: $settings.webGLFingerprintProtection
                )

                PrivacyToggleRow(
                    title: "WebRTC IP Leak Protection",
                    description: "Prevent websites from discovering your real IP address through WebRTC.",
                    systemImage: "network.slash",
                    isOn: $settings.webRTCProtection
                )

                PrivacyToggleRow(
                    title: "Hardware Fingerprint Resistance",
                    description: "Spoof hardware info (CPU cores, memory) to reduce fingerprinting accuracy.",
                    systemImage: "cpu",
                    isOn: $settings.hardwareFingerprintResistance
                )

                PrivacyToggleRow(
                    title: "Font Fingerprint Protection",
                    description: "Limit detectable fonts to a common subset to prevent identification.",
                    systemImage: "textformat",
                    isOn: $settings.fontFingerprintProtection
                )
            } header: {
                Label("Fingerprinting Protection", systemImage: "hand.raised")
                    .font(.headline)
            }

            Section {
                TrackerBlockingRow(settings: settings)

                PrivacyToggleRow(
                    title: "Tracking Pixel Blocking",
                    description: "Block invisible 1x1 pixel images used for email and web tracking.",
                    systemImage: "photo.badge.minus",
                    isOn: $settings.trackingPixelBlocking
                )

                PrivacyToggleRow(
                    title: "Popup Blocking",
                    description: "Open popup windows in the current tab instead of new windows.",
                    systemImage: "rectangle.badge.xmark",
                    isOn: $settings.popupBlocking
                )

                PrivacyToggleRow(
                    title: "Third-Party Cookie Blocking",
                    description: "Block cookies from domains other than the site you're visiting.",
                    systemImage: "cookie",
                    isOn: $settings.thirdPartyCookieBlocking
                )

                CookieBannerRow(settings: settings)

                ClipboardBlockingRow(settings: settings)

                // Custom Blocklist
                CustomBlocklistView(settings: settings, newDomain: $newBlockedDomain)
            } header: {
                Label("Content Blocking", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
            }

            Section {
                // HTTPS-Only Mode
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 16))
                            .foregroundColor(settings.httpsOnlyMode != .off ? .accentColor : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("HTTPS-Only Mode")
                                .font(.system(size: 13, weight: .medium))
                            Text("Control how the browser handles insecure HTTP connections.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Picker("", selection: $settings.httpsOnlyMode) {
                            ForEach(HTTPSOnlyMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }

                    Text(settings.httpsOnlyMode.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                }
                .padding(.vertical, 4)

                // Referrer Policy
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(settings.referrerPolicy != .defaultPolicy ? .accentColor : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Referrer Policy")
                                .font(.system(size: 13, weight: .medium))
                            Text("Control what information is sent about your previous page when navigating.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Picker("", selection: $settings.referrerPolicy) {
                            ForEach(ReferrerPolicy.allCases) { policy in
                                Text(policy.displayName).tag(policy)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }

                    Text(settings.referrerPolicy.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                }
                .padding(.vertical, 4)
            } header: {
                Label("Network Privacy", systemImage: "network.badge.shield.half.filled")
                    .font(.headline)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy Score")
                            .font(.system(size: 13, weight: .medium))
                        Text(privacyScoreDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    PrivacyScoreBadge(score: privacyScore, maxScore: maxPrivacyScore)
                }
                .padding(.vertical, 4)

                Button("Reset to Recommended Settings") {
                    showingResetConfirmation = true
                }
                .confirmationDialog(
                    "Reset Privacy Settings?",
                    isPresented: $showingResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        settings.resetToDefaults()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will enable all privacy protections.")
                }
            } header: {
                Label("Overview", systemImage: "chart.bar")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .environment(\.layoutDirection, .leftToRight)
        .padding()
    }

    private var maxPrivacyScore: Int { 14 }

    private var privacyScore: Int {
        var score = 0
        if settings.nonPersistentStorage { score += 1 }
        if settings.canvasFingerprintProtection { score += 1 }
        if settings.webGLFingerprintProtection { score += 1 }
        if settings.webRTCProtection { score += 1 }
        if settings.trackerBlocking { score += 1 }
        if settings.hardwareFingerprintResistance { score += 1 }
        if settings.fontFingerprintProtection { score += 1 }
        if settings.trackingPixelBlocking { score += 1 }
        if settings.popupBlocking { score += 1 }
        if settings.thirdPartyCookieBlocking { score += 1 }
        if settings.cookieBannerAutoReject { score += 1 }
        if settings.clipboardAccessBlocking { score += 1 }
        if settings.httpsOnlyMode != .off { score += 1 }
        if settings.referrerPolicy != .defaultPolicy { score += 1 }
        return score
    }

    private var privacyScorePercent: Double {
        Double(privacyScore) / Double(maxPrivacyScore)
    }

    private var privacyScoreDescription: String {
        switch privacyScorePercent {
        case 1.0: return "Maximum protection enabled"
        case 0.8..<1.0: return "Strong protection"
        case 0.5..<0.8: return "Moderate protection"
        default: return "Limited protection"
        }
    }
}

// MARK: - Components

struct StorageWhitelistView: View {
    @ObservedObject var settings: PrivacySettings
    @Binding var newDomain: String
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "list.badge.ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage Whitelist")
                        .font(.system(size: 13, weight: .medium))
                    Text("Allow these domains to persist cookies, localStorage, and IndexedDB across sessions.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            // Add domain input
            HStack(spacing: 8) {
                LeftAlignedTextField(
                    text: $newDomain,
                    placeholder: "Enter domain (e.g., kagi.com)",
                    onSubmit: { addDomain() }
                )

                Button(action: addDomain) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.leading, 36)

            // Whitelisted domains list
            if !settings.whitelistedDomains.isEmpty {
                VStack(spacing: 4) {
                    ForEach(settings.whitelistedDomains, id: \.self) { domain in
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text(domain)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)

                            Spacer()

                            Button(action: { settings.removeWhitelistedDomain(domain) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .opacity(0.7)
                            .help("Remove \(domain) from whitelist")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }
                }
                .padding(.leading, 36)
            } else {
                Text("No domains whitelisted. Add domains above to persist their data.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)
            }

            // Clear data buttons
            HStack(spacing: 12) {
                Button("Clear Non-Whitelisted Data") {
                    settings.clearNonWhitelistedData()
                }
                .font(.system(size: 11))

                Button("Clear All Data") {
                    showingClearConfirmation = true
                }
                .font(.system(size: 11))
                .foregroundColor(.red)
            }
            .padding(.leading, 36)
            .padding(.top, 4)
            .confirmationDialog(
                "Clear All Website Data?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    settings.clearAllWebsiteData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all cookies, cache, localStorage, and IndexedDB for all websites, including whitelisted domains. You will be logged out of all sites.")
            }
        }
        .padding(.vertical, 4)
    }

    private func addDomain() {
        let trimmed = newDomain.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        settings.addWhitelistedDomain(trimmed)
        newDomain = ""
    }
}

struct TrackerBlockingRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingDomainList = false

    private var blockedDomains: [TrackerDomain] {
        PrivacySettings.builtInTrackerDomains
    }

    var body: some View {
        Toggle(isOn: $settings.trackerBlocking) {
            HStack(spacing: 12) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 16))
                    .foregroundColor(settings.trackerBlocking ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tracker Blocking")
                        .font(.system(size: 13, weight: .medium))
                    HStack(spacing: 0) {
                        Text("Block requests to known advertising and analytics domains. ")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Button("View list") {
                            showingDomainList = true
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingDomainList, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Blocked Tracker Domains")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(blockedDomains.count) domains")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(blockedDomains) { tracker in
                            HStack {
                                Image(systemName: "xmark.shield")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red.opacity(0.7))
                                    .frame(width: 16)

                                Text(tracker.domain)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text(tracker.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)

                            if tracker.domain != blockedDomains.last?.domain {
                                Divider()
                                    .padding(.leading, 28)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .frame(width: 380)
        }
    }
}

struct CookieBannerRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    private let supportedProviders = [
        "OneTrust", "Cookiebot", "Quantcast", "TrustArc", "Didomi",
        "Klaro", "Complianz", "CookieYes", "Iubenda", "Borlabs Cookie"
    ]

    var body: some View {
        Toggle(isOn: $settings.cookieBannerAutoReject) {
            HStack(spacing: 12) {
                Image(systemName: "xmark.rectangle")
                    .font(.system(size: 16))
                    .foregroundColor(settings.cookieBannerAutoReject ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cookie Banner Auto-Reject")
                        .font(.system(size: 13, weight: .medium))
                    HStack(spacing: 0) {
                        Text("Automatically dismiss cookie consent popups. ")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Button("More info") {
                            showingInfo = true
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "xmark.rectangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "eye",
                        text: "Detects cookie consent banners from major providers"
                    )
                    InfoRow(
                        icon: "cursorarrow.click.2",
                        text: "Searches for reject/decline buttons using selectors and text patterns"
                    )
                    InfoRow(
                        icon: "hand.tap",
                        text: "Clicks the reject button automatically when detected"
                    )
                    InfoRow(
                        icon: "arrow.triangle.2.circlepath",
                        text: "Uses MutationObserver to handle dynamically loaded banners"
                    )
                    InfoRow(
                        icon: "timer",
                        text: "Disconnects observer after 10 seconds to save resources"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Supported Providers")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(supportedProviders.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(width: 300)
        }
    }
}

struct ClipboardBlockingRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: $settings.clipboardAccessBlocking) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 16))
                    .foregroundColor(settings.clipboardAccessBlocking ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Clipboard Access Blocking")
                        .font(.system(size: 13, weight: .medium))
                    HStack(spacing: 0) {
                        Text("Prevent sites from silently reading your clipboard. ")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Button("More info") {
                            showingInfo = true
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Blocked")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Blocks navigator.clipboard.readText() and read()"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Blocks document.execCommand('paste')"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Blocks paste events from exposing clipboard data to scripts"
                    )
                }

                Divider()

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("What's Allowed")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "checkmark",
                        text: "Pasting in input fields and text areas (user-initiated)"
                    )
                    InfoRow(
                        icon: "checkmark",
                        text: "Copy actions (writeText and write)"
                    )
                }
            }
            .padding(12)
            .frame(width: 300)
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CustomBlocklistView: View {
    @ObservedObject var settings: PrivacySettings
    @Binding var newDomain: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Toggle and description
            Toggle(isOn: $settings.customBlocklistEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 16))
                        .foregroundColor(settings.customBlocklistEnabled ? .accentColor : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Blocklist")
                            .font(.system(size: 13, weight: .medium))
                        Text("Block requests to your own list of domains.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .toggleStyle(.switch)

            // Add domain input
            HStack(spacing: 8) {
                LeftAlignedTextField(
                    text: $newDomain,
                    placeholder: "e.g., ads.example.com",
                    isEnabled: settings.customBlocklistEnabled,
                    onSubmit: { addDomain() }
                )

                Button(action: addDomain) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty || !settings.customBlocklistEnabled)
            }
            .padding(.leading, 36)
            .opacity(settings.customBlocklistEnabled ? 1.0 : 0.5)

            // Blocked domains list
            if !settings.customBlockedDomains.isEmpty {
                VStack(spacing: 4) {
                    ForEach(settings.customBlockedDomains, id: \.self) { domain in
                        HStack {
                            Image(systemName: "xmark.shield")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.7))

                            Text(domain)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)

                            Spacer()

                            Button(action: { settings.removeCustomBlockedDomain(domain) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .opacity(0.7)
                            .help("Remove \(domain) from blocklist")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }
                }
                .padding(.leading, 36)
                .opacity(settings.customBlocklistEnabled ? 1.0 : 0.5)
            } else if settings.customBlocklistEnabled {
                Text("No domains blocked. Add domains above to block them.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)
            }
        }
        .padding(.vertical, 4)
    }

    private func addDomain() {
        let trimmed = newDomain.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        settings.addCustomBlockedDomain(trimmed)
        newDomain = ""
    }
}

struct PrivacyToggleRow: View {
    let title: String
    let description: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(isOn ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
    }
}

struct PrivacyScoreBadge: View {
    let score: Int
    let maxScore: Int

    private var percent: Double {
        Double(score) / Double(maxScore)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(score)/\(maxScore)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(scoreColor)
            Image(systemName: scoreIcon)
                .font(.system(size: 14))
                .foregroundColor(scoreColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(scoreColor.opacity(0.15))
        )
    }

    private var scoreColor: Color {
        switch percent {
        case 1.0: return .green
        case 0.8..<1.0: return .blue
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    private var scoreIcon: String {
        switch percent {
        case 1.0: return "shield.checkered"
        case 0.8..<1.0: return "shield.lefthalf.filled"
        case 0.5..<0.8: return "shield"
        default: return "shield.slash"
        }
    }
}

#Preview {
    SettingsView()
}
