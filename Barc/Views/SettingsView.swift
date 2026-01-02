import SwiftUI

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

// MARK: - Privacy Settings (Barc-specific)

struct PrivacySettingsView: View {
    @EnvironmentObject private var settings: PrivacySettings
    @State private var showingResetConfirmation = false
    @State private var newWhitelistDomain: String = ""
    @State private var newBlockedDomain: String = ""
    @State private var showingClearDataConfirmation = false
    @State private var showingFingerprintWarning = false
    @State private var dontShowAgainChecked = false
    @State private var showingHTTPSInfo = false
    @State private var showingReferrerInfo = false

    // MARK: - Computed Properties (Performance Optimization)
    
    /// Privacy score values (cached from settings)
    private var maxPrivacyScore: Int { PrivacySettings.maxPrivacyScore }
    private var privacyScore: Int { settings.privacyScore }
    private var privacyScoreDescription: String { settings.privacyScoreDescription }
    
    /// Overview section view (extracted for performance)
    private var overviewSection: some View {
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
                        .equatable()
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
    
    /// Fingerprinting protection section view (extracted for performance)
    private var fingerprintingSection: some View {
        Section {
            CanvasFingerprintRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)

            WebGLFingerprintRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)

            WebRTCProtectionRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)

            HardwareFingerprintRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)

            FontFingerprintRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)

            AudioContextFingerprintRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)

            BatteryAPIBlockingRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)

            LanguageSpoofingRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)

            TimezoneSpoofingRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)

            ScreenResolutionSpoofingRow(settings: settings, showWarning: showFingerprintWarningIfNeeded)
        } header: {
            Label("Fingerprinting Protection", systemImage: "hand.raised")
                .font(.headline)
        }
    }
    
    /// Content blocking section view (extracted for performance)
    private var contentBlockingSection: some View {
        Section {
            JavaScriptToggleRow(settings: settings)

            MediaAutoplayRow(settings: settings)

            TrackerBlockingRow(settings: settings)

            TrackingPixelRow(settings: settings)

            PopupBlockingRow(settings: settings)

            ThirdPartyCookieRow(settings: settings)

            CrossSiteTrackingRow(settings: settings)

            SocialWidgetBlockingRow(settings: settings)

            CookieBannerRow(settings: settings)

            ClipboardBlockingRow(settings: settings)

            CryptoMinerBlockingRow(settings: settings)

            YouTubeShortsBlockingRow(settings: settings)

            // Custom Blocklist
            CustomBlocklistView(settings: settings, newDomain: $newBlockedDomain)
        } header: {
            Label("Content Blocking", systemImage: "shield.lefthalf.filled")
                .font(.headline)
        }
    }
    
    /// Network privacy section view (extracted for performance)
    private var networkPrivacySection: some View {
        Section {
            // HTTPS-Only Mode
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 16))
                        .foregroundColor(settings.httpsOnlyMode != .off ? .accentColor : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("HTTPS-Only Mode")
                                .font(.system(size: 13, weight: .medium))
                            Button(action: { showingHTTPSInfo = true }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("More info")
                        }
                        Text("Control how the browser handles insecure HTTP connections.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
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
            .popover(isPresented: $showingHTTPSInfo, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                        Text("How It Works")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    Text("HTTPS-Only Mode automatically upgrades insecure HTTP connections to secure HTTPS when possible. This protects you from man-in-the-middle attacks and ensures encrypted communication with websites.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                        Text("Modes")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(
                            icon: "chevron.right",
                            text: "Off: Allow HTTP connections"
                        )
                        InfoRow(
                            icon: "chevron.right",
                            text: "Private Windows: Upgrade HTTP in private windows only"
                        )
                        InfoRow(
                            icon: "chevron.right",
                            text: "All Windows: Upgrade HTTP in all windows"
                        )
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upgrade Behavior")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text("When a site doesn't support HTTPS, you'll see a warning page. You can choose to continue to the HTTP site if needed, but it's not recommended for security.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(width: 300)
            }

            // Referrer Policy
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16))
                        .foregroundColor(settings.referrerPolicy != .defaultPolicy ? .accentColor : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Referrer Policy")
                                .font(.system(size: 13, weight: .medium))
                            Button(action: { showingReferrerInfo = true }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("More info")
                        }
                        Text("Control what information is sent about your previous page when navigating.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
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
            .popover(isPresented: $showingReferrerInfo, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                        Text("How It Works")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    Text("The referrer header tells websites which page you came from. This can reveal your browsing history and be used for tracking. The referrer policy controls how much of this information is sent.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                        Text("Policy Options")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(
                            icon: "chevron.right",
                            text: "Default: Send full referrer (same-origin only)"
                        )
                        InfoRow(
                            icon: "chevron.right",
                            text: "No Referrer: Never send referrer"
                        )
                        InfoRow(
                            icon: "chevron.right",
                            text: "Same Origin: Send referrer only for same-origin requests"
                        )
                        InfoRow(
                            icon: "chevron.right",
                            text: "Strict Origin: Send origin only, not full URL"
                        )
                        InfoRow(
                            icon: "chevron.right",
                            text: "Strict Origin When Cross-Origin: Full referrer for same-origin, origin only for cross-origin"
                        )
                    }

                    Divider()

                    Text("Note: Some websites may break if they rely on referrer information for functionality (e.g., image hotlinking protection).")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(width: 320)
            }
        } header: {
            Label("Network Privacy", systemImage: "network.badge.shield.half.filled")
                .font(.headline)
        }
    }
    
    /// Storage section view (extracted for performance)
    private var storageSection: some View {
        Section {
            NonPersistentStorageRow(settings: settings)

            // Storage Whitelist
            StorageWhitelistView(settings: settings, newDomain: $newWhitelistDomain)
        } header: {
            Label("Storage", systemImage: "internaldrive")
                .font(.headline)
        }
    }

    var body: some View {
        Form {
            overviewSection
            fingerprintingSection
            contentBlockingSection
            networkPrivacySection
            storageSection
        }
        .formStyle(.grouped)
        .environment(\.layoutDirection, .leftToRight)
        .padding()
        .sheet(isPresented: $showingFingerprintWarning) {
            FingerprintWarningDialog(
                isPresented: $showingFingerprintWarning,
                dontShowAgain: $dontShowAgainChecked,
                onDismiss: {
                    if dontShowAgainChecked {
                        settings.suppressFingerprintWarning = true
                    }
                    dontShowAgainChecked = false
                }
            )
        }
    }

    func showFingerprintWarningIfNeeded() {
        if !settings.suppressFingerprintWarning {
            showingFingerprintWarning = true
        }
    }
}

// MARK: - Components

struct FingerprintWarningDialog: View {
    @Binding var isPresented: Bool
    @Binding var dontShowAgain: Bool
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            Text("Fingerprinting Protection")
                .font(.headline)

            Text("This setting will take effect for new tabs. Existing tabs will continue using the previous setting until reloaded.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Don't show this again", isOn: $dontShowAgain)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))

            Button("OK") {
                onDismiss()
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 320)
    }
}

struct FingerprintToggleRow: View {
    let title: String
    let description: String
    let systemImage: String
    @Binding var isOn: Bool
    var showWarning: () -> Void

    var body: some View {
        PrivacyToggleRow(
            title: title,
            description: description,
            systemImage: systemImage,
            isOn: Binding(
                get: { isOn },
                set: { newValue in
                    isOn = newValue
                    showWarning()
                }
            )
        )
    }
}

struct StorageWhitelistView: View {
    @ObservedObject var settings: PrivacySettings
    @Binding var newDomain: String
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
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

struct CrossSiteTrackingRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: $settings.crossSiteTrackingPrevention) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right.circle")
                    .font(.system(size: 16))
                    .foregroundColor(settings.crossSiteTrackingPrevention ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Cross-Site Tracking Prevention")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Block tracking across websites (ITP-style).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("Intelligent Tracking Prevention")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Similar to Safari's ITP, this feature blocks cross-site tracking resources that follow you across different websites to build a profile of your browsing behavior.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("What's Blocked")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Third-party tracking scripts"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Cross-site analytics beacons"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Tracking pixels from other domains"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Data collection endpoints"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Known Trackers Blocked")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Facebook, Google Analytics, DoubleClick, Amazon Ads, Criteo, Outbrain, Taboola, and more")
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

struct SocialWidgetBlockingRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    private let blockedWidgets = [
        "Facebook Like/Share buttons",
        "Twitter/X embeds & widgets",
        "LinkedIn share buttons",
        "Instagram embeds",
        "Pinterest pins",
        "Google+ buttons",
        "AddThis/AddToAny/ShareThis"
    ]

    var body: some View {
        Toggle(isOn: $settings.socialWidgetBlocking) {
            HStack(spacing: 12) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 16))
                    .foregroundColor(settings.socialWidgetBlocking ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Social Widget Blocking")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Block Like buttons, embeds, and share widgets.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("Social Widget Blocking")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Social media widgets like Facebook Like buttons and Twitter embeds can track you across websites, even if you don't click them. Blocking these widgets prevents this passive tracking.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("Blocked Widgets")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(blockedWidgets, id: \.self) { widget in
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.7))
                            Text(widget)
                                .font(.system(size: 11))
                        }
                    }
                }

                Divider()

                Text("Note: This may hide social sharing buttons on some websites. The underlying content will still be accessible by visiting the social media sites directly.")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 300)
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
                    HStack(spacing: 4) {
                        Text("Cookie Banner Auto-Reject")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Automatically dismiss cookie consent popups.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
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

struct JavaScriptToggleRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false
    @State private var showingConfirmation = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { !settings.javaScriptEnabled },
            set: { newValue in
                if newValue {
                    // Show confirmation before disabling JS
                    showingConfirmation = true
                } else {
                    settings.javaScriptEnabled = true
                }
            }
        )) {
            HStack(spacing: 12) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 16))
                    .foregroundColor(!settings.javaScriptEnabled ? .red : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Disable JavaScript")
                            .font(.system(size: 13, weight: .medium))
                        Text("NUCLEAR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.red)
                            )
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Block all JavaScript execution.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .confirmationDialog(
            "Disable JavaScript?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disable JavaScript", role: .destructive) {
                settings.javaScriptEnabled = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will break most websites. Only enable this if you know what you're doing. Changes take effect for new tabs.")
        }
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("Nuclear Option")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Disabling JavaScript provides maximum privacy protection but will break almost all modern websites. Most sites require JavaScript for basic functionality like login forms, navigation menus, and content loading.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("What It Blocks")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "All JavaScript execution"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Tracking scripts and analytics"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Fingerprinting scripts"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Malicious scripts and exploits"
                    )
                }

                Divider()

                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("What Breaks")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Login forms and authentication"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Interactive UI elements"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Single-page applications (SPAs)"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Dynamic content loading"
                    )
                }

                Divider()

                Text("Recommended: Keep JavaScript enabled and use the other privacy features instead for a better balance of privacy and usability.")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 320)
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
                    HStack(spacing: 4) {
                        Text("Clipboard Access Blocking")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Prevent sites from silently reading your clipboard.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
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

struct CryptoMinerBlockingRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: $settings.cryptoMinerBlocking) {
            HStack(spacing: 12) {
                Image(systemName: "bitcoinsign.circle")
                    .font(.system(size: 16))
                    .foregroundColor(settings.cryptoMinerBlocking ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Crypto Miner Blocking")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Block cryptocurrency mining scripts.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Blocked")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Known mining domains (Coinhive, CryptoLoot, etc.)"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Suspicious Web Workers with mining patterns"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Mining script injection attempts"
                    )
                }

                Divider()

                HStack {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("Behavioral Detection")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "waveform.path",
                        text: "Monitors WebAssembly usage patterns"
                    )
                    InfoRow(
                        icon: "cpu",
                        text: "Tracks excessive Worker thread spawning"
                    )
                    InfoRow(
                        icon: "magnifyingglass",
                        text: "Scans for mining-related code patterns"
                    )
                }

                Divider()

                Text("Cryptojacking uses your CPU to mine cryptocurrency without consent, slowing down your device.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(width: 300)
        }
    }
}

struct YouTubeShortsBlockingRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: $settings.blockYouTubeShorts) {
            HStack(spacing: 12) {
                Image(systemName: "video.slash")
                    .font(.system(size: 16))
                    .foregroundColor(settings.blockYouTubeShorts ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Block YouTube Shorts")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Remove Shorts from YouTube homepage and navigation sidebar.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Removed")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Shorts link in left navigation sidebar"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Shorts sections on YouTube homepage"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Shorts content grids and recommendations"
                    )
                }

                Divider()

                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "magnifyingglass",
                        text: "Uses JavaScript to detect and remove Shorts elements"
                    )
                    InfoRow(
                        icon: "arrow.triangle.2.circlepath",
                        text: "Monitors for dynamically loaded content"
                    )
                    InfoRow(
                        icon: "checkmark",
                        text: "Works on YouTube homepage and navigation"
                    )
                }

                Divider()

                Text("This feature requires JavaScript to be enabled. Changes take effect after reloading YouTube pages.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(width: 320)
        }
    }
}

struct BatteryAPIBlockingRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { settings.batteryAPIBlocking },
            set: { newValue in
                settings.batteryAPIBlocking = newValue
                showWarning()
            }
        )) {
            HStack(spacing: 12) {
                Image(systemName: "battery.100")
                    .font(.system(size: 16))
                    .foregroundColor(settings.batteryAPIBlocking ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Battery API Blocking")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Block battery status API (fingerprinting vector).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "battery.100")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("Why Block Battery API?")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Safari/WebKit already doesn't support the Battery API (it was removed from most browsers except Chrome due to privacy concerns), but this ensures it's explicitly blocked if ever re-enabled.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("What's Blocked")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "navigator.getBattery()"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "navigator.battery"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "BatteryManager interface"
                    )
                }
            }
            .padding(12)
            .frame(width: 320)
        }
    }
}

struct LanguageSpoofingRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    private var systemLanguage: String {
        Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { settings.languageSpoofing },
                set: { newValue in
                    settings.languageSpoofing = newValue
                    showWarning()
                }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundColor(settings.languageSpoofing ? .accentColor : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Language Spoofing")
                                .font(.system(size: 13, weight: .medium))
                            Button(action: { showingInfo = true }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("More info")
                        }
                        Text("Report a common language to reduce fingerprinting.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)

            // Language picker
            HStack {
                Text("Spoofed Language:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Picker("", selection: $settings.spoofedLanguage) {
                    ForEach(SpoofedLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            .padding(.leading, 36)
            .disabled(!settings.languageSpoofing)
            .opacity(settings.languageSpoofing ? 1.0 : 0.5)

            Text("System language: \(systemLanguage)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.leading, 36)
        }
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Your browser's language settings can be used as part of a fingerprint to identify you. This feature reports a different, common language to make you blend in with more users.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Spoofed")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "chevron.right",
                        text: "navigator.language"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "navigator.languages"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "Intl.DateTimeFormat default locale"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "Intl.NumberFormat default locale"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Mode")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Automatically picks a language different from your system language. If your system is en-US, it uses en-GB; otherwise it uses en-US.")
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

struct TimezoneSpoofingRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    private var systemTimezone: String {
        TimeZone.current.identifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { settings.timezoneSpoofing },
                set: { newValue in
                    settings.timezoneSpoofing = newValue
                    showWarning()
                }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 16))
                        .foregroundColor(settings.timezoneSpoofing ? .accentColor : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Timezone Spoofing")
                                .font(.system(size: 13, weight: .medium))
                            Button(action: { showingInfo = true }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("More info")
                        }
                        Text("Report a common timezone to reduce fingerprinting.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)

            // Timezone picker
            HStack {
                Text("Spoofed Timezone:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Picker("", selection: $settings.spoofedTimezone) {
                    ForEach(SpoofedTimezone.allCases) { tz in
                        Text(tz.displayName).tag(tz)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 250)
            }
            .padding(.leading, 36)
            .disabled(!settings.timezoneSpoofing)
            .opacity(settings.timezoneSpoofing ? 1.0 : 0.5)

            Text("System timezone: \(systemTimezone)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.leading, 36)
        }
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Your timezone can be used to narrow down your location and as part of a fingerprint. This feature reports a different timezone to make you blend in with more users.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Spoofed")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "chevron.right",
                        text: "Date.getTimezoneOffset()"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "Intl.DateTimeFormat timezone"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "Date.toLocaleString() methods"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Mode")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Automatically picks a timezone different from your system timezone. If your system is America/New_York, it uses Europe/London; otherwise it uses America/New_York.")
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

struct ScreenResolutionSpoofingRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    private var systemResolution: String {
        if let screen = NSScreen.main {
            let size = screen.frame.size
            return "\(Int(size.width)) × \(Int(size.height))"
        }
        return "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { settings.screenResolutionSpoofing },
                set: { newValue in
                    settings.screenResolutionSpoofing = newValue
                    showWarning()
                }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: "display")
                        .font(.system(size: 16))
                        .foregroundColor(settings.screenResolutionSpoofing ? .accentColor : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Screen Resolution Spoofing")
                                .font(.system(size: 13, weight: .medium))
                            Button(action: { showingInfo = true }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("More info")
                        }
                        Text("Report common screen dimensions.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)

            // Resolution picker
            HStack {
                Text("Spoofed Resolution:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Picker("", selection: $settings.spoofedResolution) {
                    ForEach(SpoofedResolution.allCases) { res in
                        Text(res.displayName).tag(res)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            .padding(.leading, 36)
            .disabled(!settings.screenResolutionSpoofing)
            .opacity(settings.screenResolutionSpoofing ? 1.0 : 0.5)

            Text("System resolution: \(systemResolution)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.leading, 36)
        }
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "display")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Your screen resolution is a common fingerprinting vector. Unusual resolutions make you more identifiable. This reports a common resolution like 1920×1080 to blend in.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Spoofed")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "chevron.right",
                        text: "screen.width / screen.height"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "screen.availWidth / screen.availHeight"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "window.outerWidth / window.outerHeight"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "window.devicePixelRatio (set to 1)"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Mode")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Uses 1920×1080 (Full HD), the most common screen resolution worldwide.")
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

// MARK: - Fingerprinting Protection Rows

struct CanvasFingerprintRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { settings.canvasFingerprintProtection },
            set: { newValue in
                settings.canvasFingerprintProtection = newValue
                showWarning()
            }
        )) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fingers.spread")
                    .font(.system(size: 16))
                    .foregroundColor(settings.canvasFingerprintProtection ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Canvas Fingerprint Protection")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Add subtle noise to canvas data to prevent unique browser identification.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "hand.raised.fingers.spread.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Canvas fingerprinting extracts unique rendering characteristics from HTML5 canvas elements. Websites can identify you by the subtle differences in how your browser renders graphics. This feature adds imperceptible noise to canvas output to prevent unique identification.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Spoofed")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "chevron.right",
                        text: "canvas.toDataURL() output"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "canvas.getImageData() pixel data"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "Canvas rendering patterns"
                    )
                }
            }
            .padding(12)
            .frame(width: 300)
        }
    }
}

struct WebGLFingerprintRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { settings.webGLFingerprintProtection },
            set: { newValue in
                settings.webGLFingerprintProtection = newValue
                showWarning()
            }
        )) {
            HStack(spacing: 12) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 16))
                    .foregroundColor(settings.webGLFingerprintProtection ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("WebGL Fingerprint Protection")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Mask WebGL renderer and vendor info used for browser identification.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cube.transparent.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("WebGL exposes information about your graphics card and driver, which can be used to create a unique fingerprint. This feature masks the renderer, vendor, and version information to prevent identification.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Masked")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "chevron.right",
                        text: "getParameter(UNMASKED_VENDOR_WEBGL)"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "getParameter(UNMASKED_RENDERER_WEBGL)"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "getExtension() vendor strings"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "getShaderPrecisionFormat() values"
                    )
                }
            }
            .padding(12)
            .frame(width: 300)
        }
    }
}

struct WebRTCProtectionRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { settings.webRTCProtection },
            set: { newValue in
                settings.webRTCProtection = newValue
                showWarning()
            }
        )) {
            HStack(spacing: 12) {
                Image(systemName: "network.slash")
                    .font(.system(size: 16))
                    .foregroundColor(settings.webRTCProtection ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("WebRTC IP Leak Protection")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Prevent websites from discovering your real IP address through WebRTC.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "network.slash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("WebRTC can leak your real IP address even when using a VPN or proxy. Websites can use WebRTC's ICE (Interactive Connectivity Establishment) protocol to discover your local and public IP addresses. This feature blocks WebRTC functionality to prevent IP leaks.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("What's Blocked")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "RTCPeerConnection API"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "ICE candidate gathering"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Local IP address exposure"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "STUN/TURN server requests"
                    )
                }

                Divider()

                Text("Note: This will break websites that require WebRTC for video calls, voice chat, or peer-to-peer connections.")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 320)
        }
    }
}

struct HardwareFingerprintRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { settings.hardwareFingerprintResistance },
            set: { newValue in
                settings.hardwareFingerprintResistance = newValue
                showWarning()
            }
        )) {
            HStack(spacing: 12) {
                Image(systemName: "cpu")
                    .font(.system(size: 16))
                    .foregroundColor(settings.hardwareFingerprintResistance ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Hardware Fingerprint Resistance")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Spoof hardware info (CPU cores, memory) to reduce fingerprinting accuracy.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Hardware characteristics like CPU core count and available memory can be used to identify your device. This feature reports common hardware values to make you blend in with more users.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Spoofed")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "chevron.right",
                        text: "navigator.hardwareConcurrency (CPU cores)"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "navigator.deviceMemory (RAM)"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Common Values")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Reports common hardware configurations (e.g., 4 CPU cores, 8GB RAM) to match the majority of users.")
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

struct FontFingerprintRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { settings.fontFingerprintProtection },
            set: { newValue in
                settings.fontFingerprintProtection = newValue
                showWarning()
            }
        )) {
            HStack(spacing: 12) {
                Image(systemName: "textformat")
                    .font(.system(size: 16))
                    .foregroundColor(settings.fontFingerprintProtection ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Font Fingerprint Protection")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Limit detectable fonts to a common subset to prevent identification.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "textformat")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Websites can detect which fonts you have installed by measuring text rendering. Your unique font collection can identify you. This feature limits detectable fonts to a common subset that most users have.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Limited")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "chevron.right",
                        text: "document.fonts.check() enumeration"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "Font measurement techniques"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "CSS font detection"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Common Font Subset")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Reports only standard system fonts (Arial, Times New Roman, Courier New, etc.) that are available on most systems.")
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

struct AudioContextFingerprintRow: View {
    @ObservedObject var settings: PrivacySettings
    var showWarning: () -> Void
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { settings.audioContextFingerprintProtection },
            set: { newValue in
                settings.audioContextFingerprintProtection = newValue
                showWarning()
            }
        )) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundColor(settings.audioContextFingerprintProtection ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("AudioContext Fingerprint Protection")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Spoof audio processing to prevent audio-based fingerprinting.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "waveform.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Audio fingerprinting analyzes how your audio hardware processes sound signals. Each device has unique audio processing characteristics that can identify you. This feature adds noise to audio processing to prevent unique identification.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Spoofed")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "chevron.right",
                        text: "AudioContext oscillator output"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "AudioBuffer processing patterns"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "Audio processing timing"
                    )
                }
            }
            .padding(12)
            .frame(width: 300)
        }
    }
}

// MARK: - Content Blocking Rows

struct MediaAutoplayRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: $settings.blockMediaAutoplay) {
            HStack(spacing: 12) {
                Image(systemName: "play.slash")
                    .font(.system(size: 16))
                    .foregroundColor(settings.blockMediaAutoplay ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Block Media Autoplay")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Prevent videos and audio from playing automatically until you interact.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "play.slash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Media autoplay can be annoying, consume bandwidth, and drain battery. This feature prevents videos and audio from playing automatically until you click play or interact with the page.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("What's Blocked")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "HTML5 video autoplay"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "HTML5 audio autoplay"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Autoplay with sound"
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
                        text: "Muted autoplay (if supported)"
                    )
                    InfoRow(
                        icon: "checkmark",
                        text: "User-initiated playback"
                    )
                }
            }
            .padding(12)
            .frame(width: 300)
        }
    }
}

struct TrackingPixelRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: $settings.trackingPixelBlocking) {
            HStack(spacing: 12) {
                Image(systemName: "eye.slash.circle")
                    .font(.system(size: 16))
                    .foregroundColor(settings.trackingPixelBlocking ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Tracking Pixel Blocking")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Block invisible 1x1 pixel images used for email and web tracking.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "eye.slash.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Tracking pixels are tiny, invisible images (usually 1x1 pixels) embedded in emails and web pages. When loaded, they notify the sender that you've opened the email or visited the page, revealing your IP address and other information.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("What's Blocked")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "1x1 pixel images from tracking domains"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Email tracking pixels"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Web beacon requests"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Detection")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Blocks images matching common tracking pixel patterns (1x1 dimensions, known tracking domains, specific query parameters).")
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

struct PopupBlockingRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: $settings.popupBlocking) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.badge.xmark")
                    .font(.system(size: 16))
                    .foregroundColor(settings.popupBlocking ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Popup Blocking")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Open popup windows in the current tab instead of new windows.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "rectangle.badge.xmark.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Instead of blocking popups entirely (which can break legitimate functionality), this feature redirects popup window requests to open in the current tab. This prevents annoying popups while maintaining website functionality.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("What's Redirected")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "chevron.right",
                        text: "window.open() calls"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "target=\"_blank\" links"
                    )
                    InfoRow(
                        icon: "chevron.right",
                        text: "Popup window requests"
                    )
                }

                Divider()

                Text("Note: User-initiated popups (clicking a link) are still allowed, but automatic popups are redirected to the current tab.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 300)
        }
    }
}

struct ThirdPartyCookieRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: $settings.thirdPartyCookieBlocking) {
            HStack(spacing: 12) {
                Image(systemName: "circle.slash")
                    .font(.system(size: 16))
                    .foregroundColor(settings.thirdPartyCookieBlocking ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Third-Party Cookie Blocking")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Block cookies from domains other than the site you're visiting.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "circle.slash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Third-party cookies are set by domains other than the one you're visiting. They're commonly used for tracking across websites. This feature blocks all third-party cookies while allowing first-party cookies for the site you're on.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("What's Blocked")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Cookies from third-party domains"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Cross-site tracking cookies"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Advertising network cookies"
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
                        text: "First-party cookies (same domain)"
                    )
                    InfoRow(
                        icon: "checkmark",
                        text: "Cookies with SameSite=Strict"
                    )
                }

                Divider()

                Text("Note: Some websites may not function correctly without third-party cookies, especially embedded content like videos or social widgets.")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 320)
        }
    }
}

struct NonPersistentStorageRow: View {
    @ObservedObject var settings: PrivacySettings
    @State private var showingInfo = false

    var body: some View {
        Toggle(isOn: $settings.nonPersistentStorage) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 16))
                    .foregroundColor(settings.nonPersistentStorage ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Non-Persistent Storage")
                            .font(.system(size: 13, weight: .medium))
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("More info")
                    }
                    Text("Clear non-whitelisted cookies and storage when Barc quits.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
        .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.badge.xmark.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("How It Works")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("When enabled, all cookies, localStorage, and IndexedDB data from non-whitelisted domains are cleared when you quit Barc. This provides a fresh start each session while allowing you to keep data for trusted sites via the Storage Whitelist.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("What's Cleared")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Cookies from non-whitelisted domains"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "localStorage data"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "IndexedDB databases"
                    )
                    InfoRow(
                        icon: "xmark.circle",
                        text: "Session storage"
                    )
                }

                Divider()

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("What's Preserved")
                        .font(.system(size: 13, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "checkmark",
                        text: "Storage from whitelisted domains"
                    )
                    InfoRow(
                        icon: "checkmark",
                        text: "Browser cache and history"
                    )
                }

                Divider()

                Text("Note: You'll need to log in to non-whitelisted sites each time you launch Barc. Add frequently used sites to the Storage Whitelist to avoid this.")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 320)
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

struct PrivacyScoreBadge: View, Equatable {
    let score: Int
    let maxScore: Int
    
    static func == (lhs: PrivacyScoreBadge, rhs: PrivacyScoreBadge) -> Bool {
        lhs.score == rhs.score && lhs.maxScore == rhs.maxScore
    }

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
