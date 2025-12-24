import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Barc Privacy", systemImage: "shield.checkered")
                }
        }
        .frame(width: 550, height: 580)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject private var settings = PrivacySettings.shared
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
                    TextField("https://kagi.com", text: $homePageText)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { homePageText = settings.homePage }
                        .onSubmit { settings.homePage = homePageText }
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

            Divider()
                .padding(.vertical, 8)

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

            Divider()
                .padding(.vertical, 8)

            Section {
                Toggle("Warn when visiting a fraudulent website", isOn: $settings.fraudulentWebsiteWarning)
            } header: {
                Label("Security", systemImage: "lock.shield")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
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
    @State private var newDomain: String = ""
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
                StorageWhitelistView(settings: settings, newDomain: $newDomain)

                PrivacyToggleRow(
                    title: "Canvas Fingerprint Protection",
                    description: "Add subtle noise to canvas data to prevent unique browser identification.",
                    systemImage: "hand.raised.fingers.spread",
                    isOn: $settings.canvasFingerprintProtection
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
            } header: {
                Label("Fingerprinting Protection", systemImage: "hand.raised")
                    .font(.headline)
            }

            Divider()
                .padding(.vertical, 8)

            Section {
                PrivacyToggleRow(
                    title: "Tracker Blocking",
                    description: "Block requests to known advertising and analytics domains.",
                    systemImage: "eye.slash",
                    isOn: $settings.trackerBlocking
                )

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
            } header: {
                Label("Content Blocking", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
            }

            Divider()
                .padding(.vertical, 8)

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

                    PrivacyScoreBadge(score: privacyScore)
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
        .padding()
    }

    private var privacyScore: Int {
        var score = 0
        if settings.nonPersistentStorage { score += 1 }
        if settings.canvasFingerprintProtection { score += 1 }
        if settings.webRTCProtection { score += 1 }
        if settings.trackerBlocking { score += 1 }
        if settings.hardwareFingerprintResistance { score += 1 }
        if settings.trackingPixelBlocking { score += 1 }
        if settings.popupBlocking { score += 1 }
        return score
    }

    private var privacyScoreDescription: String {
        switch privacyScore {
        case 7: return "Maximum protection enabled"
        case 5...6: return "Strong protection"
        case 3...4: return "Moderate protection"
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
                TextField("Enter domain (e.g., kagi.com)", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        addDomain()
                    }

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

    var body: some View {
        HStack(spacing: 4) {
            Text("\(score)/7")
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
        switch score {
        case 7: return .green
        case 5...6: return .blue
        case 3...4: return .orange
        default: return .red
        }
    }

    private var scoreIcon: String {
        switch score {
        case 7: return "shield.checkered"
        case 5...6: return "shield.lefthalf.filled"
        case 3...4: return "shield"
        default: return "shield.slash"
        }
    }
}

#Preview {
    SettingsView()
}
