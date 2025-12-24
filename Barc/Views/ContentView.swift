import SwiftUI

struct ContentView: View {
    @EnvironmentObject var browserState: BrowserState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var isSidebarVisible: Bool {
        columnVisibility != .detailOnly
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                // Address bar
                AddressBarView()

                // Loading progress
                if let tab = browserState.selectedTab {
                    LoadingProgressView(
                        progress: tab.estimatedProgress,
                        isLoading: tab.isLoading
                    )
                }

                // Web content
                ZStack {
                    if let tab = browserState.selectedTab {
                        WebView(tab: tab)
                            .id(tab.id)
                    } else {
                        EmptyStateView()
                    }
                }
            }
            .frame(minWidth: 400, minHeight: 300)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            setupKeyboardShortcuts()
        }
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Cmd+L to focus address bar
            if event.modifierFlags.contains(.command) && event.keyCode == 37 {
                // This would need additional implementation
                return nil
            }

            // Cmd+Shift+S for sidebar toggle
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 1 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    columnVisibility = isSidebarVisible ? .detailOnly : .all
                }
                return nil
            }

            // Cmd+Shift+] for next tab
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 30 {
                browserState.selectNextTab()
                return nil
            }

            // Cmd+Shift+[ for previous tab
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 33 {
                browserState.selectPreviousTab()
                return nil
            }

            // Cmd+1-9 for tab switching
            if event.modifierFlags.contains(.command) {
                let keyCode = event.keyCode
                if keyCode >= 18 && keyCode <= 26 {
                    let tabIndex = Int(keyCode - 18)
                    if tabIndex < browserState.tabs.count {
                        browserState.selectedTabId = browserState.tabs[tabIndex].id
                        return nil
                    }
                }
            }

            return event
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var browserState: BrowserState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No tabs open")
                .font(.title2)
                .foregroundColor(.secondary)

            Button("New Tab") {
                browserState.createNewTab()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(BrowserState())
        .frame(width: 1000, height: 700)
}
