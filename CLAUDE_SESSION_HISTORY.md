# Barc Browser - Development Session History

This file documents all development work done on Barc with Claude Code, so future sessions can understand the full context.

---

## Project Overview

**Barc** is a privacy-focused macOS web browser built with SwiftUI and WebKit (WKWebView). It features an Arc browser-style vertical sidebar tab system and uses Kagi as the default search engine.

---

## Features Implemented

### Core Browser Features
- **WebKit-based browsing** using WKWebView with NSViewRepresentable
- **Arc-style vertical sidebar tabs** with:
  - Drag-to-reorder support
  - Favicon display
  - Loading indicators
  - Context menus (Close Tab, Duplicate Tab, Close Other Tabs)
  - Hover states and selection highlighting
- **Address bar** with URL display and Kagi search integration
- **Navigation controls**: Back, Forward, Reload
- **Keyboard shortcuts**: ⌘T (new tab), ⌘W (close tab), ⌘R (reload), ⌘[ (back), ⌘] (forward)

### Privacy Features (All Toggleable in Settings)
1. **Non-Persistent Storage** - Clears cookies/storage on app quit (with whitelist support)
2. **Canvas Fingerprint Protection** - Spoofs canvas data to prevent fingerprinting
3. **WebRTC IP Leak Protection** - Disables ICE servers to prevent IP leaks
4. **Tracker Blocking** - Blocks known tracking domains
5. **Hardware Fingerprint Resistance** - Spoofs hardware info (CPU cores, memory, etc.)
6. **Tracking Pixel Blocking** - Blocks common tracking pixel domains
7. **Popup Blocking** - Prevents unwanted popups
8. **Fraudulent Website Warning** - WebKit's built-in protection

### Domain Whitelist for Persistent Storage
- Users can whitelist domains (e.g., kagi.com) to stay logged in
- Whitelisted domains retain cookies/storage across sessions
- Non-whitelisted data is cleared on app launch and quit
- Managed in Settings > Barc Privacy > Storage Whitelist

### Sidebar Toggle
- Default macOS NavigationSplitView sidebar toggle in title bar
- Keyboard shortcut: ⌘⇧S
- Animates sidebar show/hide

### Network Activity Indicators
- **Rx indicator** (green) - Lights up when receiving data
- **Tx indicator** (red) - Lights up when transmitting data
- Located in sidebar footer next to "Privacy Mode" label
- Comprehensive JavaScript injection intercepts ALL network activity:
  - `fetch()` API calls
  - `XMLHttpRequest` operations
  - `WebSocket` connections and messages
  - `EventSource` (Server-Sent Events)
  - Video/audio element streaming (`progress` events)
  - `navigator.sendBeacon()`
  - `HTMLImageElement.src` changes (tracking pixels, images)
- Uses `WKScriptMessageHandler` to bridge JS events to Swift

### Settings Window
- **General tab**: Homepage URL, default search engine
- **Barc Privacy tab**: All privacy feature toggles + storage whitelist management

### App Icon
- Custom icon from `/Users/esison/Downloads/barc_icon.png`
- All sizes generated (16x16 to 1024x1024)
- Located in `Barc/Assets.xcassets/AppIcon.appiconset/`

---

## File Structure

```
Barc/
├── BarcApp.swift              # App entry point, AppDelegate, menu commands
├── Models/
│   ├── Tab.swift              # Tab model (id, url, title, favicon, loading state)
│   ├── BrowserState.swift     # Tab management, navigation state
│   ├── PrivacySettings.swift  # Privacy settings with @AppStorage, whitelist logic
│   └── NetworkActivityMonitor.swift  # Singleton for Rx/Tx state
├── Views/
│   ├── ContentView.swift      # Main layout (sidebar + webview)
│   ├── SidebarView.swift      # Arc-style tabs, network indicators
│   ├── AddressBarView.swift   # URL bar + navigation buttons
│   ├── WebView.swift          # WKWebView wrapper, privacy scripts, network monitoring JS
│   └── SettingsView.swift     # Settings window with General + Privacy tabs
├── Assets.xcassets/
│   └── AppIcon.appiconset/    # All icon sizes
├── Barc.entitlements          # App entitlements
└── Info.plist
CONTRIBUTING.md                # Developer onboarding documentation
CLAUDE_SESSION_HISTORY.md      # This file
```

---

## Key Technical Decisions

### Why JavaScript Injection for Network Monitoring?
WKWebView runs its network stack in a separate process (Web Content process) for security isolation. There's no Swift/ObjC API to observe all network requests. JavaScript injection is the standard and only practical approach to intercept fetch/XHR/WebSocket activity from within the web content.

### Why Persistent Storage with Selective Clearing?
Initially used `WKWebsiteDataStore.nonPersistent()`, but this prevented whitelisting. Changed to always use `.default()` (persistent), then selectively clear non-whitelisted domains on app launch/quit via `AppDelegate`.

### Privacy Script Injection Order
Network monitoring script must be injected BEFORE privacy scripts to ensure it captures all network activity before any modifications.

---

## How Things Connect

```
BarcApp
├── BrowserState (manages tabs)
│   └── Tab[] (each has WebView reference)
├── PrivacySettings.shared (singleton, persisted with @AppStorage)
└── NetworkActivityMonitor.shared (singleton for Rx/Tx)

ContentView
├── SidebarView (shows tabs, network indicators)
│   └── Uses NetworkActivityMonitor.shared
└── WebView (per tab)
    ├── Injects network monitoring JS → posts to Swift via messageHandler
    ├── Injects privacy protection JS
    ├── Coordinator handles WKNavigationDelegate, WKScriptMessageHandler
    └── Reports to NetworkActivityMonitor.shared
```

---

## Build & Run

```bash
# Build
xcodebuild -project Barc.xcodeproj -scheme Barc -configuration Debug build

# Run
open ~/Library/Developer/Xcode/DerivedData/Barc-*/Build/Products/Debug/Barc.app
```

---

## Session Timeline

1. **Initial creation**: Full SwiftUI + WebKit browser with Arc-style tabs, Kagi default
2. **Settings feature**: Added Settings window with privacy toggles
3. **Documentation**: Created CONTRIBUTING.md for developer onboarding
4. **App icon**: Configured custom icon from PNG file
5. **Storage whitelist**: Added domain whitelist for persistent logins (e.g., kagi.com)
6. **Network indicators**: Added Rx/Tx lights in sidebar
7. **Comprehensive network monitoring**: JavaScript injection to capture ALL network activity (fetch, XHR, WebSocket, EventSource, media streaming, sendBeacon, images)
8. **Sidebar toggle**: Using default macOS NavigationSplitView sidebar toggle (⌘⇧S)

---

## Potential Future Work
- Tab groups/spaces (like Arc)
- Bookmarks
- History view
- Find in page
- Downloads manager
- Reader mode
- Extension support
- Sync across devices

---

*Last updated: December 2024*
