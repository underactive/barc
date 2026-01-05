import SwiftUI
import AppKit

struct TitleBarSetupView: NSViewRepresentable {
    @Binding var sidebarVisibility: NavigationSplitViewVisibility
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var privacySettings: PrivacySettings
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.frame = .zero
        
        DispatchQueue.main.async {
            setupTitleBar(for: view)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-setup if window changes
        DispatchQueue.main.async {
            setupTitleBar(for: nsView)
        }
    }
    
    private func setupTitleBar(for view: NSView) {
        guard let window = view.window else {
            // Wait for window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                setupTitleBar(for: view)
            }
            return
        }
        
        // Remove existing accessories
        window.titlebarAccessoryViewControllers.removeAll()
        
        // Create hosting view with title bar content
        let hostingView = NSHostingView(
            rootView: TitleBarContent(sidebarVisibility: $sidebarVisibility)
                .environmentObject(browserState)
                .environmentObject(privacySettings)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 1000, height: 28)
        
        // Create accessory view controller
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = hostingView
        accessory.layoutAttribute = .leading
        
        window.addTitlebarAccessoryViewController(accessory)
    }
}

