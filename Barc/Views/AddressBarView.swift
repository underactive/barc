import SwiftUI

struct AddressBarView: View {
    @EnvironmentObject var browserState: BrowserState
    @ObservedObject private var privacySettings = PrivacySettings.shared
    @StateObject private var networkMonitor = NetworkActivityMonitor.shared
    @StateObject private var blockedMonitor = BlockedRequestsMonitor.shared
    @ObservedObject private var soundManager = NetworkSoundManager.shared
    @Environment(\.openSettings) private var openSettings
    @State private var inputText: String = ""
    @State private var isEditing: Bool = false
    @State private var showingPrivacyPopover: Bool = false
    @FocusState private var isFocused: Bool

    private var maxPrivacyScore: Int { 16 }

    private var privacyScore: Int {
        var score = 0
        if privacySettings.nonPersistentStorage { score += 1 }
        if privacySettings.canvasFingerprintProtection { score += 1 }
        if privacySettings.webGLFingerprintProtection { score += 1 }
        if privacySettings.webRTCProtection { score += 1 }
        if privacySettings.trackerBlocking { score += 1 }
        if privacySettings.hardwareFingerprintResistance { score += 1 }
        if privacySettings.fontFingerprintProtection { score += 1 }
        if privacySettings.audioContextFingerprintProtection { score += 1 }
        if privacySettings.batteryAPIBlocking { score += 1 }
        if privacySettings.trackingPixelBlocking { score += 1 }
        if privacySettings.popupBlocking { score += 1 }
        if privacySettings.thirdPartyCookieBlocking { score += 1 }
        if privacySettings.cookieBannerAutoReject { score += 1 }
        if privacySettings.clipboardAccessBlocking { score += 1 }
        if privacySettings.httpsOnlyMode != .off { score += 1 }
        if privacySettings.referrerPolicy != .defaultPolicy { score += 1 }
        return score
    }

    private var privacyScorePercent: Double {
        Double(privacyScore) / Double(maxPrivacyScore)
    }

    private var privacyScoreColor: Color {
        switch privacyScorePercent {
        case 1.0: return .green
        case 0.8..<1.0: return .blue
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    private var privacyScoreIcon: String {
        switch privacyScorePercent {
        case 1.0: return "shield.checkered"
        case 0.8..<1.0: return "shield.lefthalf.filled"
        case 0.5..<0.8: return "shield"
        default: return "shield.slash"
        }
    }

    private var privacyScoreDescription: String {
        switch privacyScorePercent {
        case 1.0: return "Privacy Score: \(privacyScore)/\(maxPrivacyScore) - Maximum protection"
        case 0.8..<1.0: return "Privacy Score: \(privacyScore)/\(maxPrivacyScore) - Strong protection"
        case 0.5..<0.8: return "Privacy Score: \(privacyScore)/\(maxPrivacyScore) - Moderate protection"
        default: return "Privacy Score: \(privacyScore)/\(maxPrivacyScore) - Limited protection"
        }
    }

    private var blockedCount: Int {
        guard let tabId = browserState.selectedTabId else { return 0 }
        return blockedMonitor.blockedCount(for: tabId)
    }

    private var blockedRequests: [BlockedRequestsMonitor.BlockedRequest] {
        guard let tabId = browserState.selectedTabId else { return [] }
        return blockedMonitor.blockedRequests(for: tabId)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Navigation buttons
            HStack(spacing: 4) {
                NavigationButton(
                    systemName: "chevron.left",
                    action: browserState.goBack,
                    isEnabled: browserState.selectedTab?.canGoBack ?? false
                )

                NavigationButton(
                    systemName: "chevron.right",
                    action: browserState.goForward,
                    isEnabled: browserState.selectedTab?.canGoForward ?? false
                )

                NavigationButton(
                    systemName: browserState.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise",
                    action: {
                        if browserState.selectedTab?.isLoading == true {
                            browserState.selectedTab?.webView?.stopLoading()
                        } else {
                            browserState.reloadCurrentTab()
                        }
                    },
                    isEnabled: true
                )
            }

            // URL/Search field
            HStack(spacing: 8) {
                // Security indicator
                if let url = browserState.selectedTab?.url {
                    Image(systemName: url.scheme == "https" ? "lock.fill" : "lock.open")
                        .font(.system(size: 10))
                        .foregroundColor(url.scheme == "https" ? .green : .orange)
                }

                TextField("Search with Kagi or enter URL", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .onSubmit {
                        browserState.navigate(to: inputText)
                        isFocused = false
                    }
                    .onChange(of: browserState.selectedTab?.url) { _, newURL in
                        if !isEditing {
                            inputText = newURL?.absoluteString ?? ""
                        }
                    }
                    .onChange(of: isFocused) { _, focused in
                        isEditing = focused
                        if focused {
                            // Select all text when focused
                            DispatchQueue.main.async {
                                if let textField = NSApp.keyWindow?.firstResponder as? NSTextView {
                                    textField.selectAll(nil)
                                }
                            }
                        }
                    }

                // Clear button
                if !inputText.isEmpty && isEditing {
                    Button(action: { inputText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isFocused ? Color.accentColor.opacity(0.5) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .overlay(alignment: .bottom) {
                // Loading progress bar at the bottom of URL field
                if let tab = browserState.selectedTab {
                    LoadingProgressBar(
                        progress: tab.estimatedProgress,
                        isLoading: tab.isLoading
                    )
                    .padding(.horizontal, 1)
                    .offset(y: 1)
                }
            }

            // Privacy shield indicator with blocked count badge
            Button(action: { showingPrivacyPopover.toggle() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: privacyScoreIcon)
                        .font(.system(size: 14))
                        .foregroundColor(privacyScoreColor)

                    // Badge showing blocked count
                    if blockedCount > 0 {
                        Text(blockedCount > 99 ? "99+" : "\(blockedCount)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(blockedCount > 0 ? "\(blockedCount) blocked - \(privacyScoreDescription)" : privacyScoreDescription)
            .popover(isPresented: $showingPrivacyPopover, arrowEdge: .bottom) {
                PrivacyShieldPopover(
                    privacyScore: privacyScore,
                    maxPrivacyScore: maxPrivacyScore,
                    privacyScoreColor: privacyScoreColor,
                    privacyScoreIcon: privacyScoreIcon,
                    blockedRequests: blockedRequests,
                    onOpenSettings: {
                        showingPrivacyPopover = false
                        SettingsState.shared.selectedTab = .privacy
                        openSettings()
                    }
                )
            }

            // Network activity indicators with popover menu
            if networkMonitor.showURLBarNetworkActivity {
                NetworkIndicatorsMenu(
                    networkMonitor: networkMonitor,
                    soundManager: soundManager
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            inputText = browserState.selectedTab?.url?.absoluteString ?? ""
        }
        .onChange(of: browserState.focusAddressBarTrigger) { _, _ in
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .onChange(of: browserState.selectedTabId) { _, _ in
            // Clear focus when switching tabs to allow interactions with other tabs
            isFocused = false
        }
    }
}

struct NavigationButton: View {
    let systemName: String
    let action: () -> Void
    let isEnabled: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.01))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// Progress bar for page loading
struct LoadingProgressBar: View {
    let progress: Double
    let isLoading: Bool

    @State private var displayedProgress: Double = 0
    @State private var isVisible: Bool = false

    var body: some View {
        GeometryReader { geometry in
            if isVisible {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * displayedProgress)
            }
        }
        .frame(height: 2)
        .clipShape(RoundedRectangle(cornerRadius: 1))
        .onChange(of: isLoading) { _, newIsLoading in
            if newIsLoading {
                // Starting to load - show the bar and reset progress
                displayedProgress = 0.05 // Start with a small amount visible
                withAnimation(.easeOut(duration: 0.1)) {
                    isVisible = true
                }
            } else {
                // Finished loading - animate to 100% then hide
                withAnimation(.easeOut(duration: 0.2)) {
                    displayedProgress = 1.0
                }
                // Hide after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    // Reset for next load
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        displayedProgress = 0
                    }
                }
            }
        }
        .onChange(of: progress) { _, newProgress in
            // Only update if we're loading and new progress is higher
            if isLoading && newProgress > displayedProgress {
                withAnimation(.easeOut(duration: 0.15)) {
                    displayedProgress = newProgress
                }
            }
        }
        .onAppear {
            // Initialize state based on current loading status
            if isLoading {
                isVisible = true
                displayedProgress = max(progress, 0.05)
            }
        }
    }
}

// Legacy progress view (unused but kept for reference)
struct LoadingProgressView: View {
    let progress: Double
    let isLoading: Bool

    var body: some View {
        GeometryReader { geometry in
            if isLoading && progress < 1.0 {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: 2)
                    .animation(.easeInOut(duration: 0.2), value: progress)
            }
        }
        .frame(height: 2)
    }
}

// MARK: - Privacy Shield Popover

struct PrivacyShieldPopover: View {
    let privacyScore: Int
    let maxPrivacyScore: Int
    let privacyScoreColor: Color
    let privacyScoreIcon: String
    let blockedRequests: [BlockedRequestsMonitor.BlockedRequest]
    let onOpenSettings: () -> Void

    private var groupedRequests: [(domain: String, count: Int, reasons: Set<BlockedRequestsMonitor.BlockedRequest.BlockReason>)] {
        var domainInfo: [String: (count: Int, reasons: Set<BlockedRequestsMonitor.BlockedRequest.BlockReason>)] = [:]
        for request in blockedRequests {
            if var info = domainInfo[request.domain] {
                info.count += 1
                info.reasons.insert(request.reason)
                domainInfo[request.domain] = info
            } else {
                domainInfo[request.domain] = (count: 1, reasons: [request.reason])
            }
        }
        return domainInfo.map { (domain: $0.key, count: $0.value.count, reasons: $0.value.reasons) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Privacy score header
            HStack {
                Image(systemName: privacyScoreIcon)
                    .font(.system(size: 16))
                    .foregroundColor(privacyScoreColor)
                Text("Privacy Score: \(privacyScore)/\(maxPrivacyScore)")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }

            Divider()

            // Blocked requests section
            if blockedRequests.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("No requests blocked on this page")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blocked Requests (\(blockedRequests.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(groupedRequests, id: \.domain) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.red)

                                    Text(item.domain)
                                        .font(.system(size: 11, design: .monospaced))
                                        .lineLimit(1)

                                    Spacer()

                                    if item.count > 1 {
                                        Text("×\(item.count)")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }

                                    Text(item.reasons.map { $0.rawValue }.joined(separator: ", "))
                                        .font(.system(size: 9))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            Divider()

            // Settings button
            Button(action: onOpenSettings) {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Privacy Settings")
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(12)
        .frame(width: 280)
    }
}

// MARK: - Network Indicators Menu

struct NetworkIndicatorsMenu: View {
    @ObservedObject var networkMonitor: NetworkActivityMonitor
    @ObservedObject var soundManager: NetworkSoundManager
    @State private var showingPopover = false

    // Filter indicator display based on indicatorScope setting
    private var showRxIndicator: Bool {
        networkMonitor.isReceiving &&
        (networkMonitor.indicatorScope == .allTabs || networkMonitor.lastReceiveWasActiveTab)
    }

    private var showTxIndicator: Bool {
        networkMonitor.isTransmitting &&
        (networkMonitor.indicatorScope == .allTabs || networkMonitor.lastTransmitWasActiveTab)
    }

    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            HStack(spacing: 6) {
                NetworkIndicator(label: "Tx", isActive: showTxIndicator, activeColor: .red)
                NetworkIndicator(label: "Rx", isActive: showRxIndicator, activeColor: .green)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Network Sounds", systemImage: soundManager.isEnabled ? "speaker.wave.2" : "speaker.slash")
                        .lineLimit(1)
                    Spacer()
                    Toggle("", isOn: $soundManager.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                Divider()

                HStack {
                    Label("Rx (Receive)", systemImage: "arrow.down.circle")
                        .lineLimit(1)
                    Spacer()
                    Toggle("", isOn: $soundManager.rxEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .disabled(!soundManager.isEnabled)
                }
                .opacity(soundManager.isEnabled ? 1.0 : 0.5)

                HStack {
                    Label("Tx (Transmit)", systemImage: "arrow.up.circle")
                        .lineLimit(1)
                    Spacer()
                    Toggle("", isOn: $soundManager.txEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .disabled(!soundManager.isEnabled)
                }
                .opacity(soundManager.isEnabled ? 1.0 : 0.5)
            }
            .padding(12)
            .fixedSize()
        }
    }
}

// MARK: - Network Activity Indicator

struct NetworkIndicator: View {
    let label: String
    let isActive: Bool
    let activeColor: Color

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isActive ? activeColor : Color.gray.opacity(0.3))
                .frame(width: 6, height: 6)
                .shadow(color: isActive ? activeColor.opacity(0.6) : .clear, radius: 2)
                .animation(.easeInOut(duration: 0.1), value: isActive)

            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(isActive ? activeColor : .secondary.opacity(0.5))
                .animation(.easeInOut(duration: 0.1), value: isActive)
        }
    }
}

#Preview {
    AddressBarView()
        .environmentObject(BrowserState())
        .frame(width: 600)
}
