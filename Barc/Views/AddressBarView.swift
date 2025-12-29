import SwiftUI

struct AddressBarView: View {
    @EnvironmentObject var browserState: BrowserState
    @ObservedObject private var privacySettings = PrivacySettings.shared
    @StateObject private var networkMonitor = NetworkActivityMonitor.shared
    @Environment(\.openSettings) private var openSettings
    @State private var inputText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool

    private var maxPrivacyScore: Int { 10 }

    private var privacyScore: Int {
        var score = 0
        if privacySettings.nonPersistentStorage { score += 1 }
        if privacySettings.canvasFingerprintProtection { score += 1 }
        if privacySettings.webRTCProtection { score += 1 }
        if privacySettings.trackerBlocking { score += 1 }
        if privacySettings.hardwareFingerprintResistance { score += 1 }
        if privacySettings.trackingPixelBlocking { score += 1 }
        if privacySettings.popupBlocking { score += 1 }
        if privacySettings.thirdPartyCookieBlocking { score += 1 }
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

            // Privacy shield indicator
            Button(action: {
                SettingsState.shared.selectedTab = .privacy
                openSettings()
            }) {
                Image(systemName: privacyScoreIcon)
                    .font(.system(size: 14))
                    .foregroundColor(privacyScoreColor)
            }
            .buttonStyle(.plain)
            .help(privacyScoreDescription)

            // Network activity indicators
            HStack(spacing: 6) {
                NetworkIndicator(label: "Rx", isActive: networkMonitor.isReceiving, activeColor: .green)
                NetworkIndicator(label: "Tx", isActive: networkMonitor.isTransmitting, activeColor: .red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            inputText = browserState.selectedTab?.url?.absoluteString ?? ""
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
