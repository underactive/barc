import SwiftUI

struct AddressBarView: View {
    @EnvironmentObject var browserState: BrowserState
    @State private var inputText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool

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
            Button(action: {}) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            .help("Privacy protections active")
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
