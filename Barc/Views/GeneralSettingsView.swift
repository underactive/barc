import SwiftUI

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: PrivacySettings
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

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Loading throbber")
                                .font(.system(size: 13))
                            Text("Display a retro animated throbber while pages load.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.throbberSize) {
                            ForEach(PrivacySettings.ThrobberSize.allCases, id: \.self) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
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
                            Text("Play retro modem sounds when sending or receiving data.")
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
                            Text("Receive Data Sound")
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
                            Text("Send Data Sound")
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

