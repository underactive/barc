# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Build the project
xcodebuild -project Barc.xcodeproj -scheme Barc -configuration Debug build

# Run the app (after building)
open ~/Library/Developer/Xcode/DerivedData/Barc-*/Build/Products/Debug/Barc.app

# Build and run in one step
xcodebuild -project Barc.xcodeproj -scheme Barc -configuration Debug build && \
open ~/Library/Developer/Xcode/DerivedData/Barc-gvqalylbyxzpsfafrimmjydxeokq/Build/Products/Debug/Barc.app
```

**Note:** The app sandbox is **disabled** (`com.apple.security.app-sandbox = false` in entitlements) because yt-dlp is a PyInstaller binary that cannot run in a sandboxed environment.

## Code Style & Standards

**CRITICAL:** All code changes must follow the Swift and SwiftUI best practices defined in `.cursorrules`. Key requirements:

### Swift Language Standards
- Prefer `let` over `var` unless mutation is required
- Use `guard` for early returns and unwrapping optionals
- Never force unwrap (`!`) unless absolutely certain of non-nil value
- Use `private` access control by default, escalate only when needed
- Mark classes as `final` unless subclassing is intended
- Group code with `// MARK: -` comments

### Memory Management (Critical for This App)
- Use `[weak self]` in closures that capture `self` to avoid retain cycles
- Use `@StateObject` for view-owned ObservableObjects
- Use `@ObservedObject` for externally-owned ObservableObjects (like singletons)
- Use `@EnvironmentObject` for shared state across view hierarchy
- **Never create ObservableObjects in view body** - use `@StateObject` instead

### SwiftUI Patterns
- Keep view bodies pure - no side effects
- Perform side effects in `.onAppear`, `.onChange`, or `.task`
- Break down large views into smaller, reusable components
- Extract view modifiers into reusable extensions
- Use `LazyVStack`/`LazyHStack` for large lists

### Property Organization in Views
Follow this order consistently:
```swift
struct MyView: View {
    // 1. Environment objects
    @EnvironmentObject var browserState: BrowserState

    // 2. State objects (owned by view)
    @StateObject private var monitor = NetworkActivityMonitor.shared

    // 3. Observed objects (externally owned)
    @ObservedObject private var settings = PrivacySettings.shared

    // 4. State properties
    @State private var isExpanded = false

    // 5. Regular properties
    let title: String

    // 6. Body
    var body: some View { ... }

    // 7. Computed properties
    private var subtitle: String { ... }

    // 8. Methods
    private func handleTap() { ... }
}
```

### Common Pitfalls to Avoid
- Don't update UI from background threads - use `@MainActor` or `DispatchQueue.main.async`
- Don't perform heavy work on main thread - use `Task` for async work
- Don't ignore errors - handle them appropriately with `do-catch` or `Result`
- Don't create retain cycles - use `weak` or `unowned` references in closures
- Don't create views conditionally without proper `id()` for stable identity

**See `.cursorrules` for the complete Swift/SwiftUI style guide.**

## Architecture Overview

### State Management Pattern

Barc uses a **singleton + ObservableObject** pattern for cross-cutting concerns:

```
BarcApp (Root)
├── BrowserState (tabs, navigation) - @StateObject in app, @EnvironmentObject in views
├── PrivacySettings.shared - Singleton with @AppStorage persistence
├── NetworkActivityMonitor.shared - Singleton tracking Rx/Tx per tab
├── NetworkSoundManager.shared - Singleton for modem sounds (AVAudioEngine)
├── BlockedRequestsMonitor.shared - Singleton tracking blocked requests per tab
├── DownloadManager.shared - Singleton managing yt-dlp downloads
└── SettingsState.shared - Singleton for settings window tab navigation
```

**Key principle:** Singletons (`*.shared`) are used for app-wide state that needs to be accessed from multiple disconnected parts of the UI (e.g., address bar, settings, sidebar). Tab-specific state lives in `Tab` model, browser-wide state lives in `BrowserState`.

### JavaScript Injection Architecture

Privacy protections are implemented via JavaScript injection in `WebView.swift`:

1. **Network monitoring script** - Injected FIRST (before privacy scripts) using `.atDocumentStart` to intercept fetch/XHR/WebSocket/EventSource/media/sendBeacon/Image operations
2. **Privacy protection scripts** - Injected after network monitoring to spoof canvas/WebGL/fonts/hardware/AudioContext/battery/language/timezone/screen
3. **Message handlers** - `WKScriptMessageHandler` receives messages from injected JS via `window.webkit.messageHandlers.X.postMessage()`

**Critical ordering:** Network monitoring must inject before privacy scripts to capture all activity before modifications.

### Privacy Settings Storage

All privacy settings use `@AppStorage` for automatic UserDefaults persistence:

```swift
@AppStorage("privacy.canvasFingerprintProtection") var canvasFingerprintProtection: Bool = true
```

Settings are read from `PrivacySettings.shared` singleton in `WebView.swift` when creating `WKWebViewConfiguration` for each tab. **Changes take effect for new tabs only** - existing tabs keep their configuration until reload/recreate.

### Data Flow: Network Activity Indicators

Complex flow showing how network activity is monitored and displayed:

```
WebView JS injection → intercepts fetch/XHR/etc
    ↓
WKScriptMessageHandler receives message with action: "networkActivity"
    ↓
NetworkActivityMonitor.shared updates state:
    - isTransmitting/isReceiving (booleans)
    - transmittingTabIds/receivingTabIds (Sets for per-tab tracking)
    - lastTransmitWasActiveTab/lastReceiveWasActiveTab (for scope filtering)
    ↓
UI observes NetworkActivityMonitor via @ObservedObject/@StateObject:
    - AddressBarView shows SD/RD indicators (filtered by indicatorScope)
    - SidebarView shows red/green dots on background tabs
    - NetworkSoundManager plays sounds (filtered by soundScope)
```

**Scope settings:** URL bar indicators and sounds have **separate** scope controls (All Tabs vs Active Tab Only). Indicators use `NetworkActivityMonitor.indicatorScope`, sounds use `NetworkSoundManager.soundScope`.

## Key Implementation Details

### Storage Whitelist System

Initially used `WKWebsiteDataStore.nonPersistent()` but switched to always use `.default()` (persistent) with selective clearing via `AppDelegate`:

- `clearNonWhitelistedData()` - Called on app launch and quit
- Whitelisted domains (e.g., kagi.com) retain cookies/storage
- Non-whitelisted data is cleared using `WKWebsiteDataStore.default().removeData()`

### Video Download (yt-dlp Integration)

- yt-dlp binary is a **universal binary** (arm64 + x86_64) bundled in `Barc/Resources/`
- JavaScript injection detects videos on YouTube, Vimeo, Twitter, TikTok, Twitch, Reddit, Instagram, Facebook, etc.
- Uses `MutationObserver` for SPA URL changes and multiple delayed checks for dynamic content
- `Tab.hasDownloadableVideo` controls address bar button state
- Max 3 concurrent downloads, pending queue for additional requests
- Parses yt-dlp stdout for progress/speed/ETA using regex

### Element Picker (xkill mode)

JavaScript injection creates overlay on element hover:

1. Inject CSS and event listeners via `injectElementPickerScript()`
2. User clicks element → JS sends message with element selector
3. Swift receives message, calls `removeElementFromPage()` to execute removal
4. ESC key or clicking hammer icon exits picker mode

### Network Activity Sounds

Retro dialup modem sounds generated programmatically using `AVAudioEngine`:

- **Tx sound:** 2400 Hz carrier with harmonics and noise (higher pitch)
- **Rx sound:** 1200 Hz carrier with harmonics and noise (lower pitch)
- Sounds fade in/out over 0.1s for smooth playback
- `NetworkSoundManager` observes `NetworkActivityMonitor` to trigger sounds

### Privacy Score Calculation

Uses percentage-based thresholds for color/icon selection:

```swift
var privacyScore: Int {
    var score = 0
    if nonPersistentStorage { score += 1 }
    if canvasFingerprintProtection { score += 1 }
    // ... +1 for each enabled feature
    return score
}

var privacyScorePercent: Double {
    Double(privacyScore) / Double(maxPrivacyScore)
}

var privacyScoreColor: Color {
    switch privacyScorePercent {
    case 1.0: return .green           // 100%
    case 0.8..<1.0: return .blue      // 80-99%
    case 0.5..<0.8: return .orange    // 50-79%
    default: return .red              // 0-49%
    }
}
```

**Why percentage-based:** Makes it easy to add new privacy features without updating threshold logic. Just add the toggle and increment counter.

## Common Development Patterns

### Adding a New Privacy Feature

1. Add `@AppStorage` property to `PrivacySettings.swift`:
   ```swift
   @AppStorage("privacy.myFeature") var myFeature: Bool = true
   ```

2. Add to privacy score calculation in `privacyScore` computed property

3. Add UI in `SettingsView.swift` under appropriate section:
   ```swift
   PrivacyToggleRow(
       title: "My Feature",
       description: "What it does",
       systemImage: "icon.name",
       isOn: $settings.myFeature
   )
   ```

4. Implement protection in `WebView.swift`:
   - **JavaScript injection:** Add to `injectPrivacyScripts()` method
   - **Network blocking:** Add to `webView(_:decidePolicyFor:)` navigation delegate
   - **Configuration:** Add to `createPrivacyConfiguration()` method

### Adding Network Activity Indicators

If adding new UI that shows network activity:

1. Add `@StateObject private var networkMonitor = NetworkActivityMonitor.shared`
2. Observe `networkMonitor.isTransmitting` / `networkMonitor.isReceiving` booleans
3. For per-tab tracking, check if tab ID is in `networkMonitor.transmittingTabIds` / `receivingTabIds` Sets
4. Respect `networkMonitor.indicatorScope` setting (All Tabs vs Active Tab Only)

### Working with Tab-Specific State

Tab model is observable and syncs with WebView via KVO:

```swift
// In WebView Coordinator
webView.observe(\.title) { [weak self] webView, _ in
    self?.parent.tab.title = webView.title ?? "New Tab"
}

webView.observe(\.isLoading) { [weak self] webView, _ in
    self?.parent.tab.isLoading = webView.isLoading
}
```

**Pattern:** WebView is source of truth → KVO updates Tab model → SwiftUI observes Tab → UI updates

## Important Constraints

### Fingerprinting Changes Require New Tabs

All fingerprinting protection settings (canvas, WebGL, fonts, etc.) inject JavaScript at `WKUserScriptInjectionTime.atDocumentStart`. This means:

- Changes only apply to **new tabs** or **reloaded pages**
- Existing tabs continue using previous script injections
- Settings UI shows warning dialog on toggle (can be suppressed via `suppressFingerprintWarning`)

**Why:** JavaScript is injected when `WKWebView` is created. Cannot re-inject into existing page without reload.

### JavaScript Toggle is "Nuclear Option"

The JavaScript disable toggle:

- Uses `WKWebpagePreferences.allowsContentJavaScript = false`
- Shows confirmation dialog with red "NUCLEAR" badge
- Breaks most modern websites (login, navigation, content loading)
- Adds +1 to privacy score when disabled
- Recommended to keep enabled and use other privacy features instead

### HTTPS-Only Mode Implementation

Uses `WKNavigationDelegate` to intercept requests:

- **Off:** Allow all HTTP
- **Upgrade:** Rewrite `http://` → `https://` in navigation requests
- **Strict:** Block HTTP entirely with custom error page

Pattern: `webView(_:decidePolicyFor:)` checks scheme and either allows, rewrites URL, or cancels with error.

## File Locations Reference

When making UI changes:

- **Toolbar labels (SD/RD):** `AddressBarView.swift` → `NetworkIndicatorsMenu` → `NetworkIndicator` component
- **Settings labels:** `SettingsView.swift` → `GeneralSettingsView` → Network Activity section
- **Privacy toggles:** `SettingsView.swift` → `PrivacySettingsView` → sections with `PrivacyToggleRow`
- **JavaScript injection:** `WebView.swift` → `injectPrivacyScripts()` and `injectNetworkMonitoringScript()`
- **Tab sidebar:** `SidebarView.swift` → tab list with drag-to-reorder
- **Downloads UI:** `DownloadsSidebarSection.swift` and `DownloadRowView.swift` at bottom of sidebar

## Session History

The `CLAUDE_SESSION_HISTORY.md` file contains comprehensive documentation of all features implemented, technical decisions made, and session timeline. Always consult this file to understand:

- Why certain architectural decisions were made
- How features have evolved over time
- Known issues and workarounds
- Future work items

**Last updated:** Session 6 (January 2, 2025)
