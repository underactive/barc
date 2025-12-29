import SwiftUI

struct AddressBarView: View {
    @EnvironmentObject var browserState: BrowserState
    @ObservedObject private var privacySettings = PrivacySettings.shared
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

#Preview {
    AddressBarView()
        .environmentObject(BrowserState())
        .frame(width: 600)
}
