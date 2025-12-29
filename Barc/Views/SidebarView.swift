import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var browserState: BrowserState
    @StateObject private var networkMonitor = NetworkActivityMonitor.shared
    @State private var hoveredTabId: UUID?

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
                LazyVStack(spacing: 2) {
                    ForEach(browserState.tabs) { tab in
                        TabRowView(
                            tab: tab,
                            isSelected: browserState.selectedTabId == tab.id,
                            isHovered: hoveredTabId == tab.id
                        )
                        .onTapGesture {
                            browserState.selectTab(tab)
                        }
                        .onHover { isHovered in
                            hoveredTabId = isHovered ? tab.id : nil
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

            // Footer with network activity indicators
            HStack(spacing: 6) {
                Spacer()
                NetworkIndicator(label: "Rx", isActive: networkMonitor.isReceiving, activeColor: .green)
                NetworkIndicator(label: "Tx", isActive: networkMonitor.isTransmitting, activeColor: .red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
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

struct TabRowView: View {
    @ObservedObject var tab: Tab
    let isSelected: Bool
    let isHovered: Bool

    @EnvironmentObject var browserState: BrowserState

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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
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

#Preview {
    SidebarView()
        .environmentObject(BrowserState())
}
