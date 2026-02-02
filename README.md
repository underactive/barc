# Barc

A privacy-focused macOS browser built with SwiftUI and WebKit.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### Privacy Protection

Barc includes **23 privacy protections** that can be individually toggled:

**Fingerprinting Resistance**
- Canvas fingerprint protection
- WebGL fingerprint protection
- Font fingerprint protection
- Hardware fingerprint resistance
- AudioContext fingerprint protection
- Screen resolution spoofing (10 presets)
- Language spoofing (11 languages)
- Timezone spoofing (12 timezones)

**Tracking Prevention**
- Built-in tracker blocking (25+ domains)
- Tracking pixel blocking
- Third-party cookie blocking
- Crypto miner blocking (45+ domains)
- Social widget blocking
- WebRTC IP leak protection
- Battery API blocking
- Clipboard access blocking

**Network Privacy**
- HTTPS-only mode (Off / Upgrade / Strict)
- Referrer policy control (6 levels)
- Non-persistent storage with domain whitelist
- Custom domain blocklist

**Content Control**
- JavaScript toggle (for maximum privacy)
- Cookie banner auto-reject
- Popup blocking
- YouTube Shorts blocking

### Browser Features

**Tab Management**
- Arc-style vertical sidebar tabs
- Drag-to-reorder tabs
- Tab context menus (duplicate, close others)
- Keyboard shortcuts for tab switching

**Navigation**
- Smart address bar (auto-detects URLs vs searches)
- 6 search engines (Kagi default, DuckDuckGo, Google, Bing, Startpage, Brave)
- Configurable homepage
- Back/forward gesture support

**Video Downloads**
- Download videos from YouTube, Vimeo, Twitter, TikTok, Reddit, and 1000+ sites
- Format selection (Best, MP4, 720p, 480p, Audio Only)
- Download queue with progress tracking
- Powered by bundled yt-dlp

**Element Picker**
- Click-to-remove any page element
- Visual overlay highlighting
- Particle disintegration effect

**Page Tools**
- View page source with syntax highlighting
- Save page as Web Archive, HTML, or full-page PNG screenshot

### Unique Features

**Privacy Score**
- Real-time score (0-23) based on enabled protections
- Color-coded indicator in address bar
- Click to open privacy settings

**Network Activity Monitor**
- Real-time Tx/Rx indicators in address bar
- Background tab activity dots
- Retro dialup modem sound effects (optional)
- Per-tab network tracking

**Blocked Requests Dashboard**
- See what's being blocked on each page
- Organized by domain and category
- Request count badge

**Retro Touches**
- Animated Netscape-style loading throbber
- Configurable size (Small/Medium/Large)
- Dialup modem sounds for network activity

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘T | New Tab |
| ⌘W | Close Tab |
| ⌘R | Reload |
| ⌘[ | Back |
| ⌘] | Forward |
| ⌘1-9 | Switch to Tab |
| ⌘⇧[ | Previous Tab |
| ⌘⇧] | Next Tab |
| ⌘⇧S | Toggle Sidebar |
| Esc | Exit Element Picker |

## Installation

1. Download the latest `.dmg` from [Releases](https://github.com/underactive/barc/releases)
2. Open the DMG and drag **Barc** to **Applications**
3. **First launch:** Right-click → Open (to bypass Gatekeeper)

After the first launch, the app opens normally with a double-click.

## Building from Source

Requires Xcode 15+ and macOS 14+.

```bash
# Clone the repo
git clone https://github.com/underactive/barc.git
cd barc

# Build
xcodebuild -project Barc.xcodeproj -scheme Barc -configuration Release build

# Run
open .build/Build/Products/Release/Barc.app
```

Or use the build script:

```bash
./scripts/build-dmg.sh
```

## Tech Stack

- **SwiftUI** - UI framework
- **WebKit/WKWebView** - Browser engine
- **AVAudioEngine** - Retro modem sounds
- **yt-dlp** - Video downloads (bundled universal binary)

## License

MIT