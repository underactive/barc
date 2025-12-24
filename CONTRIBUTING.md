# Barc Developer Guide

Welcome to Barc! This guide will help you understand the codebase, architecture, and how to contribute to the project.

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Architecture](#architecture)
4. [Project Structure](#project-structure)
5. [Core Components](#core-components)
6. [Feature Set](#feature-set)
7. [Privacy Implementation](#privacy-implementation)
8. [Contributing](#contributing)
9. [Code Style](#code-style)
10. [Testing](#testing)

---

## Overview

Barc is a privacy-focused macOS web browser built with SwiftUI and WebKit. It features an Arc-style vertical sidebar tab system and uses Kagi as the default search engine.

### Key Technologies

- **SwiftUI** - Declarative UI framework for macOS
- **WebKit/WKWebView** - Web rendering engine
- **Combine** - Reactive framework for state management
- **UserDefaults/@AppStorage** - Settings persistence

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later

---

## Getting Started

### Building the Project

```bash
# Clone the repository
git clone <repository-url>
cd barc

# Open in Xcode
open Barc.xcodeproj

# Or build from command line
xcodebuild -project Barc.xcodeproj -scheme Barc -configuration Debug build
```

### Running the App

1. Open `Barc.xcodeproj` in Xcode
2. Select the "Barc" scheme
3. Press `⌘R` to build and run

### Project Configuration

- **Bundle Identifier**: `com.barc.browser`
- **Deployment Target**: macOS 14.0
- **Entitlements**: App Sandbox enabled with network client access

---

## Architecture

Barc follows the **MVVM (Model-View-ViewModel)** pattern with SwiftUI's reactive state management.

```
┌─────────────────────────────────────────────────────────┐
│                      BarcApp                             │
│                    (Entry Point)                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │ BrowserState │◄───│   TabView    │                   │
│  │  (ViewModel) │    │   (Model)    │                   │
│  └──────┬───────┘    └──────────────┘                   │
│         │                                                │
│         ▼                                                │
│  ┌──────────────────────────────────────────────┐       │
│  │              ContentView                      │       │
│  │  ┌────────────┐  ┌─────────────────────────┐ │       │
│  │  │  Sidebar   │  │      Detail View        │ │       │
│  │  │   View     │  │  ┌─────────────────┐   │ │       │
│  │  │            │  │  │  AddressBar     │   │ │       │
│  │  │  [Tab 1]   │  │  ├─────────────────┤   │ │       │
│  │  │  [Tab 2]   │  │  │                 │   │ │       │
│  │  │  [Tab 3]   │  │  │    WebView      │   │ │       │
│  │  │            │  │  │                 │   │ │       │
│  │  └────────────┘  │  └─────────────────┘   │ │       │
│  └──────────────────────────────────────────────┘       │
│                                                          │
│  ┌──────────────────┐                                   │
│  │ PrivacySettings  │ (Singleton - App-wide settings)   │
│  └──────────────────┘                                   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User Action** → View captures interaction
2. **View** → Calls method on `BrowserState` or `PrivacySettings`
3. **State Change** → `@Published` properties trigger UI updates
4. **View Update** → SwiftUI re-renders affected components

---

## Project Structure

```
barc/
├── Barc.xcodeproj/          # Xcode project file
│   └── project.pbxproj      # Project configuration
│
├── Barc/
│   ├── BarcApp.swift        # App entry point, window & menu setup
│   │
│   ├── Models/
│   │   ├── Tab.swift            # Tab model (URL, title, favicon, state)
│   │   ├── BrowserState.swift   # Central state management (tabs, navigation)
│   │   └── PrivacySettings.swift # Privacy settings with persistence
│   │
│   ├── Views/
│   │   ├── ContentView.swift    # Main layout (NavigationSplitView)
│   │   ├── SidebarView.swift    # Arc-style vertical tab sidebar
│   │   ├── AddressBarView.swift # URL bar, navigation buttons
│   │   ├── WebView.swift        # WKWebView wrapper with privacy features
│   │   └── SettingsView.swift   # Settings window (General + Privacy tabs)
│   │
│   ├── Assets.xcassets/     # App icons, colors
│   ├── Info.plist           # App metadata
│   └── Barc.entitlements    # Sandbox permissions
│
└── CONTRIBUTING.md          # This file
```

---

## Core Components

### BarcApp.swift

The app entry point that configures:
- Main window with hidden title bar
- Settings window scene
- Menu bar commands (New Tab, Close Tab, navigation)
- Environment objects for state sharing

```swift
@main
struct BarcApp: App {
    @StateObject private var browserState = BrowserState()
    @StateObject private var privacySettings = PrivacySettings.shared

    var body: some Scene {
        WindowGroup { ... }
        Settings { SettingsView() }
    }
}
```

### Tab.swift

Represents a single browser tab with observable properties:

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `title` | `String` | Page title |
| `url` | `URL?` | Current URL |
| `favicon` | `NSImage?` | Site favicon |
| `isLoading` | `Bool` | Loading state |
| `canGoBack` | `Bool` | Navigation state |
| `canGoForward` | `Bool` | Navigation state |
| `estimatedProgress` | `Double` | Load progress (0-1) |
| `webView` | `WKWebView?` | Weak reference to web view |

### BrowserState.swift

Central state manager for the browser:

**Properties:**
- `tabs: [Tab]` - All open tabs
- `selectedTabId: UUID?` - Currently active tab
- `sidebarCollapsed: Bool` - Sidebar visibility

**Key Methods:**
```swift
func createNewTab(url: URL? = nil)  // Create and select new tab
func closeTab(_ tab: Tab)           // Close specific tab
func navigate(to urlString: String) // Navigate or search
func goBack() / goForward()         // Navigation
func selectNextTab() / selectPreviousTab()  // Tab switching
```

### PrivacySettings.swift

Singleton managing all privacy settings with `@AppStorage` persistence:

**Privacy Toggles:**
- `nonPersistentStorage` - Ephemeral browsing
- `canvasFingerprintProtection` - Canvas API spoofing
- `webRTCProtection` - WebRTC IP leak prevention
- `trackerBlocking` - Domain-level blocking
- `hardwareFingerprintResistance` - Hardware info spoofing
- `trackingPixelBlocking` - Pixel tracker blocking
- `popupBlocking` - Popup handling

**General Settings:**
- `searchEngine` - Search provider (Kagi default)
- `homePage` - Home page URL
- `newTabBehavior` - New tab opens home or blank

### WebView.swift

`NSViewRepresentable` wrapper for `WKWebView` with:

1. **Privacy Configuration** - Creates `WKWebViewConfiguration` based on settings
2. **Script Injection** - Injects JavaScript for fingerprint protection
3. **Navigation Delegate** - Blocks tracker domains
4. **UI Delegate** - Handles popups
5. **KVO Observers** - Syncs WebView state to Tab model

---

## Feature Set

### Tab Management

| Feature | Shortcut | Description |
|---------|----------|-------------|
| New Tab | `⌘T` | Opens new tab with home page |
| Close Tab | `⌘W` | Closes current tab |
| Next Tab | `⌘⇧]` | Switch to next tab |
| Previous Tab | `⌘⇧[` | Switch to previous tab |
| Tab 1-9 | `⌘1-9` | Jump to specific tab |
| Reorder | Drag | Drag tabs to reorder |
| Duplicate | Context Menu | Duplicate current tab |

### Navigation

| Feature | Shortcut | Description |
|---------|----------|-------------|
| Back | `⌘[` | Go back in history |
| Forward | `⌘]` | Go forward in history |
| Reload | `⌘R` | Reload current page |
| Address Bar | Click | Focus URL/search bar |

### Search

- Default search engine: **Kagi**
- Smart URL detection (URLs vs search queries)
- Configurable search engines: Kagi, DuckDuckGo, Google, Bing, Startpage, Brave

### Privacy Features

See [Privacy Implementation](#privacy-implementation) for details.

---

## Privacy Implementation

### Non-Persistent Storage

When enabled, uses `WKWebsiteDataStore.nonPersistent()` which:
- Stores cookies/cache in memory only
- Clears all data when app quits
- Prevents cross-session tracking

```swift
if settings.nonPersistentStorage {
    configuration.websiteDataStore = .nonPersistent()
}
```

### Canvas Fingerprinting Protection

Injects JavaScript to add noise to canvas operations:

```javascript
// Modifies toDataURL and getImageData to add minimal noise
HTMLCanvasElement.prototype.toDataURL = function(type) {
    // XOR pixel data with 1 to create unique but consistent noise
    imageData.data[i] ^= 1;
    // ...
};
```

### WebRTC IP Leak Protection

Prevents real IP discovery through WebRTC:

```javascript
window.RTCPeerConnection = function(...args) {
    const config = args[0] || {};
    config.iceServers = [];  // Remove STUN/TURN servers
    return new originalRTC(config);
};
```

### Hardware Fingerprint Resistance

Spoofs hardware properties to common values:

```javascript
Object.defineProperty(navigator, 'hardwareConcurrency', { value: 4 });
Object.defineProperty(navigator, 'deviceMemory', { value: 8 });
Object.defineProperty(navigator, 'plugins', { value: [] });
```

### Tracker Blocking

Domain-level blocking in `WKNavigationDelegate`:

```swift
func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if settings.trackerBlocking, let url = navigationAction.request.url {
        if blockedDomains.contains(where: { url.host?.contains($0) == true }) {
            decisionHandler(.cancel)
            return
        }
    }
    decisionHandler(.allow)
}
```

**Blocked Domains Include:**
- `doubleclick.net`, `googleadservices.com`, `googlesyndication.com`
- `facebook.net`, `connect.facebook.com`
- `amazon-adsystem.com`, `criteo.com`, `taboola.com`
- And more (see `PrivacySettings.blockedDomains`)

### Tracking Pixel Blocking

JavaScript injection to block 1x1 tracking images:

```javascript
window.Image = function(...args) {
    // Intercept src setter to block known tracking domains
    if (blockedPixelDomains.some(d => url.hostname.includes(d))) {
        console.log('[Barc] Blocked tracking pixel:', url.hostname);
        return;
    }
};
```

---

## Contributing

### Getting Started

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Areas for Contribution

**High Priority:**
- [ ] Bookmarks system
- [ ] History view and management
- [ ] Downloads manager
- [ ] Find in page (`⌘F`)
- [ ] Reader mode

**Medium Priority:**
- [ ] Tab pinning
- [ ] Tab groups/spaces (Arc-style)
- [ ] Extension support
- [ ] Sync across devices
- [ ] Custom themes

**Low Priority:**
- [ ] Picture-in-picture video
- [ ] Web notifications
- [ ] Autofill
- [ ] Password manager integration

### Adding a New Privacy Feature

1. Add toggle to `PrivacySettings.swift`:
```swift
@AppStorage("privacy.myFeature") var myFeature: Bool = true
```

2. Add UI toggle in `SettingsView.swift`:
```swift
PrivacyToggleRow(
    title: "My Feature",
    description: "Description of what it does",
    systemImage: "shield",
    isOn: $settings.myFeature
)
```

3. Implement in `WebView.swift`:
   - For JavaScript injection: Add to `injectPrivacyScripts()`
   - For network blocking: Add to navigation delegate
   - For configuration: Add to `createPrivacyConfiguration()`

4. Update privacy score calculation if applicable

### Adding a New View

1. Create file in `Barc/Views/`
2. Add to Xcode project (drag into Views group)
3. Update `project.pbxproj` if needed
4. Use `@EnvironmentObject` for state access:
```swift
struct MyView: View {
    @EnvironmentObject var browserState: BrowserState
    // ...
}
```

---

## Code Style

### SwiftUI Conventions

```swift
struct MyView: View {
    // 1. Environment objects
    @EnvironmentObject var browserState: BrowserState

    // 2. State properties
    @State private var isExpanded = false

    // 3. Regular properties
    let title: String

    // 4. Body
    var body: some View {
        // ...
    }

    // 5. Computed properties
    private var subtitle: String {
        // ...
    }

    // 6. Methods
    private func handleTap() {
        // ...
    }
}
```

### Naming Conventions

- **Views**: `PascalCase` with `View` suffix (e.g., `SidebarView`)
- **Models**: `PascalCase` (e.g., `Tab`, `BrowserState`)
- **Properties**: `camelCase`
- **Constants**: `camelCase` or `SCREAMING_SNAKE_CASE` for globals
- **Files**: Match the primary type name

### Comments

- Use `// MARK: -` for section headers
- Document public APIs with `///` doc comments
- Explain "why" not "what" in inline comments

---

## Testing

### Manual Testing Checklist

**Tab Management:**
- [ ] Create new tab
- [ ] Close tab (single, multiple, last tab)
- [ ] Switch tabs (click, keyboard)
- [ ] Reorder tabs (drag)
- [ ] Duplicate tab

**Navigation:**
- [ ] Enter URL directly
- [ ] Search query triggers search engine
- [ ] Back/forward navigation
- [ ] Reload page

**Privacy Features:**
- [ ] Toggle each privacy setting
- [ ] Verify non-persistent storage clears on restart
- [ ] Check tracker blocking in console
- [ ] Test on fingerprinting test sites

**Settings:**
- [ ] Change search engine
- [ ] Modify home page
- [ ] Settings persist after restart

### Privacy Test Sites

- [AmIUnique](https://amiunique.org/) - Fingerprint uniqueness
- [BrowserLeaks](https://browserleaks.com/) - WebRTC, Canvas, etc.
- [Cover Your Tracks](https://coveryourtracks.eff.org/) - EFF tracker test
- [CanvasBlocker Test](https://canvasblocker.kkapsner.de/test/) - Canvas protection

---

## Resources

### Documentation

- [WebKit Documentation](https://developer.apple.com/documentation/webkit)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [WKWebView Guide](https://developer.apple.com/documentation/webkit/wkwebview)

### Privacy Research

- [Fingerprinting Guidance](https://privacycg.github.io/nav-tracking-mitigations/)
- [WebRTC IP Leaks](https://www.browserleaks.com/webrtc)
- [Canvas Fingerprinting](https://browserleaks.com/canvas)

---

## Questions?

If you have questions about the codebase or need help contributing, please:

1. Check existing issues and discussions
2. Open a new issue with the "question" label
3. Include relevant code snippets and context

Happy coding!
