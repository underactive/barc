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
9. **HTTPS-Only Mode** - Three modes: Off, Upgrade (auto-upgrade HTTP→HTTPS), Strict (block HTTP)
10. **Referrer Policy Control** - Control what information is sent about previous page (6 policy options)
11. **Third-Party Cookie Blocking** - Block cookies from domains other than the site you're visiting

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
- **URL Bar Indicators**:
  - **Rx indicator** (green) - Lights up when receiving data
  - **Tx indicator** (red) - Lights up when transmitting data
  - Located in **address bar** (right of privacy shield icon)
  - **Clickable popover menu** allows quick toggle of sound settings
  - Can be toggled on/off and scoped to All Tabs or Active Tab Only
- **Background Tab Indicators**:
  - **Red dot** (Tx) on top, **green dot** (Rx) below - stacked vertically
  - Appear on right side of non-active tabs when network activity occurs
  - Instant appear, 0.75s fade-out animation
  - Close button takes precedence when hovering
- Comprehensive JavaScript injection intercepts ALL network activity:
  - `fetch()` API calls
  - `XMLHttpRequest` operations
  - `WebSocket` connections and messages
  - `EventSource` (Server-Sent Events)
  - Video/audio element streaming (`progress` events)
  - `navigator.sendBeacon()`
  - `HTMLImageElement.src` changes (tracking pixels, images)
- Uses `WKScriptMessageHandler` to bridge JS events to Swift

### Privacy Score Indicator (Address Bar)
- **Dynamic icon** in address bar (right side) reflects current Privacy Score:
  - 10/10: `shield.checkered` (green) - Maximum protection
  - 8-9/10: `shield.lefthalf.filled` (blue) - Strong protection
  - 5-7/10: `shield` (orange) - Moderate protection
  - 0-4/10: `shield.slash` (red) - Limited protection
- **Hover tooltip** shows: "Privacy Score: X/10 - [protection level]"
- **Clickable**: Opens Settings window directly to Barc Privacy tab
- Updates in real-time when privacy settings change

### Settings Window
- **General tab**: Homepage URL, default search engine, Network Activity (Indicator Lights + Sounds subsections)
- **Barc Privacy tab**: All privacy feature toggles + storage whitelist management
- `SettingsState.shared` manages selected tab for programmatic navigation

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
│   ├── NetworkActivityMonitor.swift  # Singleton for Rx/Tx state
│   └── NetworkSoundManager.swift     # Modem sounds for network activity (AVAudioEngine)
├── Views/
│   ├── ContentView.swift      # Main layout (sidebar + webview)
│   ├── SidebarView.swift      # Arc-style tabs, network indicators
│   ├── AddressBarView.swift   # URL bar, navigation, privacy score indicator
│   ├── WebView.swift          # WKWebView wrapper, privacy scripts, network monitoring JS
│   └── SettingsView.swift     # Settings window, SettingsState for tab navigation
├── Assets.xcassets/
│   └── AppIcon.appiconset/    # All icon sizes
├── Barc.entitlements          # App entitlements
└── Info.plist
.gitignore                     # Git ignore for macOS/Xcode projects
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
├── NetworkActivityMonitor.shared (singleton for Rx/Tx state)
├── NetworkSoundManager.shared (singleton for modem sounds, observes NetworkActivityMonitor)
└── SettingsState.shared (singleton for settings tab navigation)

ContentView
├── SidebarView (shows tabs)
└── AddressBarView
    ├── Privacy score indicator (reads PrivacySettings, opens Settings on click)
    ├── Network indicators (Rx/Tx) with popover menu
    ├── Loading progress bar (animated)
    ├── Uses NetworkActivityMonitor.shared, NetworkSoundManager.shared
    └── Uses SettingsState.shared + @Environment(\.openSettings)

WebView (per tab)
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
9. **Privacy score indicator**: Dynamic shield icon in address bar reflecting privacy score with color/icon changes, tooltip, and click-to-open settings
10. **HTTPS-Only Mode**: Added three modes (Off, Upgrade, Strict) - auto-upgrades HTTP to HTTPS or blocks HTTP entirely
11. **Referrer Policy Control**: Added 6 referrer policy options to control what information is shared when navigating between pages
12. **Third-Party Cookie Blocking**: Uses WKContentRuleList to block cookies from third-party domains
13. **Network Activity Sounds**: Retro modem-style sounds when transmitting/receiving data (toggleable in Settings > General)
14. **Privacy score refactoring**: Changed to percentage-based thresholds for easier extensibility
15. **Rx/Tx indicators moved**: From sidebar footer to address bar with clickable popover menu
16. **Loading progress bar**: Animated progress indicator in URL field
17. **Sound settings expansion**: Added individual Rx/Tx toggles and volume slider
18. **Address bar autofocus**: URL bar automatically gains focus when opening a new tab (⌘T) for immediate typing
19. **Background tab activity indicators**: Red/green dots on non-active tabs showing Tx/Rx activity
20. **Network Activity settings refactor**: Reorganized into Indicator Lights and Sounds subsections with independent scope controls
21. **Scope settings**: Separate "All Tabs vs Active Tab Only" controls for URL bar indicators and sounds
22. **Default changes**: Sounds enabled by default, scopes default to Active Tab Only

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
- **Toolbar-based address bar**: Use AppKit's NSToolbar for Safari-like unified toolbar (SwiftUI toolbar too compact)

---

*Last updated: December 29, 2024 (Session 2)*

---

## Recent Changes (December 2024)

### HTTPS-Only Mode
- **Off**: Allow all HTTP connections
- **Upgrade** (default): Automatically upgrade HTTP URLs to HTTPS
- **Strict**: Block all non-HTTPS connections, show error page

Implementation: WKNavigationDelegate intercepts navigation requests and either upgrades HTTP→HTTPS or blocks with an error page.

### Referrer Policy Control
- **Default**: Browser default behavior
- **No Referrer**: Never send referrer information
- **Origin Only**: Send only the domain, not full URL
- **Same Origin**: Send referrer only for same-origin requests
- **Strict Origin** (default): Send origin on HTTPS→HTTPS, nothing on HTTPS→HTTP
- **Strict Origin When Cross-Origin**: Full URL for same-origin, origin only for cross-origin

Implementation: JavaScript injection adds `<meta name="referrer">` tag and optionally overrides `document.referrer` property.

### Third-Party Cookie Blocking
Blocks cookies set by domains other than the site you're visiting. Uses WKContentRuleList with Safari-style content blocking rules:
```json
[{
    "trigger": { "url-filter": ".*", "load-type": ["third-party"] },
    "action": { "type": "block-cookies" }
}]
```
This prevents cross-site tracking while allowing first-party cookies needed for login sessions.

### Network Activity Indicators Moved
Rx/Tx indicators moved from sidebar footer to address bar (right of privacy shield icon).

### Network Activity Sounds
Retro dialup modem-style sounds that play when network activity occurs:
- **Tx sound**: Higher pitch (2400 Hz carrier) - plays on data transmission
- **Rx sound**: Lower pitch (1200 Hz carrier) - plays on data reception
- Sounds are generated programmatically using AVAudioEngine with carrier waves, harmonics, and noise
- **Settings** (Settings > General > Sounds):
  - Master toggle for Network Activity Sounds
  - Individual toggles for Rx and Tx sounds
  - Volume slider (0-100%)
- **Quick access**: Click Rx/Tx indicators in address bar for popover menu
- Disabled by default

### Loading Progress Bar
- Animated progress bar at bottom of URL field
- Shows page load progress (like other browsers)
- Animates to 100% when loading completes, then fades out
- Custom `LoadingProgressBar` component with proper animation lifecycle

### Privacy Score Refactoring
- Privacy score now uses percentage-based thresholds instead of hardcoded values
- Makes it easier to add new privacy features without updating threshold logic
- `maxPrivacyScore` constant defines the denominator
- `privacyScorePercent` computed property used for color/icon selection

### Attempted: Toolbar-Based Address Bar
Attempted to move address bar into macOS toolbar to eliminate whitespace above it:
- `.toolbar` with `.principal` placement - toolbar too compact
- `.toolbarRole(.browser)` - not available on macOS
- `.toolbarTitleDisplayMode(.inline)` - still too small
- NSWindow configuration with `titlebarAppearsTransparent` - didn't help
- **Conclusion**: macOS toolbar has fixed compact height unsuitable for browser address bars. Safari uses AppKit's NSToolbar with custom configuration. Reverted changes.

### Address Bar Autofocus
When creating a new tab (⌘T), the address bar now automatically gains focus for immediate typing:
- Added `shouldFocusAddressBar` published property to `BrowserState`
- Set to `true` in `createNewTab()` method
- `AddressBarView` watches for changes via `.onChange(of: browserState.shouldFocusAddressBar)`
- When triggered, sets `isFocused = true` and resets the flag
- Standard browser UX pattern - new tab → ready to type

### Background Tab Network Activity Indicators
Non-active tabs now show visual indicators when they have network activity:
- **Red dot** (Tx) and **green dot** (Rx) appear vertically stacked on the right side of background tabs
- Dots appear instantly and fade out over 0.75s (easeOut animation)
- When hovering over a tab, the close button takes precedence over indicators
- Controlled by "Show background tab activity" toggle in Settings
- Tracks per-tab activity via `transmittingTabIds` and `receivingTabIds` Sets in `NetworkActivityMonitor`

### Network Activity Settings Refactor
Completely reorganized Settings > General > Network Activity into two subsections:

**Indicator Lights:**
- Show URL bar network activity (default: ON) - toggles Rx/Tx indicators in address bar
- URL Bar Network Activity For: [All Tabs | Active Tab Only] (default: Active Tab Only)
- Show background tab activity (default: ON) - toggles dots on background tabs

**Sounds:**
- Play network activity sound effects (default: ON) - with description text
- Volume slider (default: 50%)
- Rx (Receive) Sound toggle (default: ON)
- Tx (Transmit) Sound toggle (default: ON)
- Play Sounds For: [All Tabs | Active Tab Only] (default: Active Tab Only)

Items under each subsection are indented for visual hierarchy.

### Independent Scope Controls for Indicators vs Sounds
- URL bar indicators and sounds now have **separate** scope settings
- `indicatorScope` in `NetworkActivityMonitor` controls URL bar indicators
- `soundScope` in `NetworkSoundManager` controls sound playback
- Fixed bug where "Play Sounds For: All Tabs" didn't work - sounds now always trigger regardless of indicator scope, with filtering done at the sound level

### New Settings Properties
- `NetworkActivityMonitor.showURLBarNetworkActivity` - toggle URL bar Rx/Tx display
- `NetworkActivityMonitor.indicatorScope` - All Tabs vs Active Tab Only for URL bar
- `NetworkActivityMonitor.showBackgroundTabIndicators` - toggle background tab dots
- `NetworkSoundManager.soundScope` - All Tabs vs Active Tab Only for sounds

### Default Changes
- Network activity sounds now **enabled by default** (was disabled)
- Both indicator and sound scopes default to **Active Tab Only** (was All Tabs)

### NetworkSoundScope Enum
Added `NetworkSoundScope` enum in `PrivacySettings.swift`:
```swift
enum NetworkSoundScope: String, CaseIterable, Identifiable {
    case allTabs = "allTabs"
    case activeTabOnly = "activeTabOnly"
}
```
Used by both indicator scope and sound scope settings.
