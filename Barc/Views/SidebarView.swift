import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var browserState: BrowserState
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header with title
            HStack {
                Text("Barc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { browserState.createNewTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Tab (⌘T)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // Tabs list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(browserState.tabs) { tab in
                        TabRowView(
                            tab: tab,
                            isSelected: browserState.selectedTabId == tab.id
                        )
                        .onTapGesture {
                            browserState.selectTab(tab)
                        }
                        .contextMenu {
                            Button("Close Tab") {
                                browserState.closeTab(tab)
                            }
                            Button("Duplicate Tab") {
                                browserState.createNewTab(url: tab.url)
                            }
                            Divider()
                            Button("Close Other Tabs") {
                                let currentTab = tab
                                browserState.tabs.filter { $0.id != currentTab.id }
                                    .forEach { browserState.closeTab($0) }
                            }
                        }
                    }
                    .onMove { source, destination in
                        browserState.moveTab(from: source, to: destination)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            Spacer()

            // Downloads section (only shown when there are downloads)
            if !downloadManager.downloads.isEmpty {
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                DownloadsSidebarSection()
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

struct TabRowView: View {
    @ObservedObject var tab: Tab
    let isSelected: Bool

    @EnvironmentObject var browserState: BrowserState
    @ObservedObject private var networkMonitor = NetworkActivityMonitor.shared
    @State private var isHovered: Bool = false

    private var isBackgroundTabTransmitting: Bool {
        !isSelected && networkMonitor.transmittingTabIds.contains(tab.id)
    }

    private var isBackgroundTabReceiving: Bool {
        !isSelected && networkMonitor.receivingTabIds.contains(tab.id)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Favicon or loading indicator
            ZStack {
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else if let favicon = tab.favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                }
            }

            // Title
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(isSelected ? .primary : .secondary)

            Spacer()

            // Speaker icon (audio playing indicator)
            if tab.isPlayingAudio {
                AnimatedSpeakerIcon()
                    .padding(.trailing, 4)
            }

            // Close button OR network indicators
            ZStack {
                // Network activity indicators (vertical stack: Tx on top, Rx below)
                // Always rendered but hidden when hovering or selected
                if networkMonitor.showBackgroundTabIndicators {
                    VStack(spacing: 3) {
                        TabNetworkDot(
                            isActive: isBackgroundTabTransmitting && !isHovered && !isSelected,
                            activeColor: .red
                        )
                        TabNetworkDot(
                            isActive: isBackgroundTabReceiving && !isHovered && !isSelected,
                            activeColor: .green
                        )
                    }
                    .opacity(isHovered || isSelected ? 0 : 1)
                }

                // Close button (visible on hover or selection)
                if isHovered || isSelected {
                    Button(action: { browserState.closeTab(tab) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1 : 0.5)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor)
        }
        return .clear
    }
}

struct TabNetworkDot: View {
    let isActive: Bool
    let activeColor: Color

    var body: some View {
        Circle()
            .fill(isActive ? activeColor : Color.gray.opacity(0.3))
            .frame(width: 6, height: 6)
            .shadow(color: isActive ? activeColor.opacity(0.6) : .clear, radius: 2)
            .opacity(isActive ? 1 : 0)
            .animation(isActive ? .none : .easeOut(duration: 0.75), value: isActive)
    }
}

struct AnimatedSpeakerIcon: View {
    @State private var animationPhase: Int = 0
    @State private var animationTimer: Timer?

    var body: some View {
        ZStack {
            switch animationPhase {
            case 0:
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            case 1:
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            default:
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 18, height: 14, alignment: .leading)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }

    private func startAnimation() {
        // Clean up any existing timer first
        stopAnimation()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { timer in
            // Don't use withAnimation - it causes flickering crossfade between icons
            animationPhase = (animationPhase + 1) % 3
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

#Preview {
    SidebarView()
        .environmentObject(BrowserState())
}
