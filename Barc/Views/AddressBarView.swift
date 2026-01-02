import SwiftUI

struct AddressBarView: View {
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject private var privacySettings: PrivacySettings
    @StateObject private var networkMonitor = NetworkActivityMonitor.shared
    @StateObject private var blockedMonitor = BlockedRequestsMonitor.shared
    @ObservedObject private var soundManager = NetworkSoundManager.shared
    @Environment(\.openSettings) private var openSettings
    @State private var inputText: String = ""
    @State private var isEditing: Bool = false
    @State private var showingPrivacyPopover: Bool = false
    @State private var showingDownloadPopover: Bool = false
    @FocusState private var isFocused: Bool

    // Privacy score helpers (delegate to PrivacySettings single source of truth)
    private var maxPrivacyScore: Int { PrivacySettings.maxPrivacyScore }
    private var privacyScore: Int { privacySettings.privacyScore }
    private var privacyScorePercent: Double { privacySettings.privacyScorePercent }
    private var privacyScoreColor: Color { privacySettings.privacyScoreColor }
    private var privacyScoreIcon: String { privacySettings.privacyScoreIcon }

    private var privacyScoreDescription: String {
        "Privacy Score: \(privacyScore)/\(maxPrivacyScore) - \(privacySettings.privacyScoreDescription)"
    }

    private var blockedCount: Int {
        guard let tabId = browserState.selectedTabId else { return 0 }
        return blockedMonitor.blockedCount(for: tabId)
    }

    private var blockedRequests: [BlockedRequestsMonitor.BlockedRequest] {
        guard let tabId = browserState.selectedTabId else { return [] }
        return blockedMonitor.blockedRequests(for: tabId)
    }

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
            .overlay(alignment: .bottom) {
                // Loading progress bar at the bottom of URL field
                if let tab = browserState.selectedTab {
                    LoadingProgressBar(
                        progress: tab.estimatedProgress,
                        isLoading: tab.isLoading
                    )
                    .padding(.horizontal, 1)
                    .offset(y: 1)
                }
            }

            // Video download button
            Button(action: { showingDownloadPopover.toggle() }) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 14))
                    .foregroundColor(browserState.selectedTab?.hasDownloadableVideo == true ? .accentColor : .secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(browserState.selectedTab?.hasDownloadableVideo != true)
            .help(browserState.selectedTab?.hasDownloadableVideo == true ? "Download video from this page" : "No downloadable video detected")
            .popover(isPresented: $showingDownloadPopover, arrowEdge: .bottom) {
                VideoDownloadMenu(
                    videoTitle: browserState.selectedTab?.title ?? "Video",
                    onDownload: { format in
                        showingDownloadPopover = false
                        guard let tab = browserState.selectedTab,
                              let url = tab.url else { return }
                        DownloadManager.shared.startDownload(url: url, pageTitle: tab.title, format: format)
                    }
                )
            }

            // Element picker (xkill) button
            Button(action: { browserState.toggleElementPicker() }) {
                Image(systemName: "hammer")
                    .font(.system(size: 14))
                    .foregroundColor(browserState.isElementPickerActive ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(browserState.isElementPickerActive ? "Cancel element picker (Esc)" : "Remove page elements")

            // Privacy shield indicator with blocked count badge
            Button(action: { showingPrivacyPopover.toggle() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: privacyScoreIcon)
                        .font(.system(size: 14))
                        .foregroundColor(privacyScoreColor)

                    // Badge showing blocked count
                    if blockedCount > 0 {
                        Text(blockedCount > 99 ? "99+" : "\(blockedCount)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(blockedCount > 0 ? "\(blockedCount) blocked - \(privacyScoreDescription)" : privacyScoreDescription)
            .popover(isPresented: $showingPrivacyPopover, arrowEdge: .bottom) {
                PrivacyShieldPopover(
                    privacyScore: privacyScore,
                    maxPrivacyScore: maxPrivacyScore,
                    privacyScoreColor: privacyScoreColor,
                    privacyScoreIcon: privacyScoreIcon,
                    blockedRequests: blockedRequests,
                    onOpenSettings: {
                        showingPrivacyPopover = false
                        SettingsState.shared.selectedTab = .privacy
                        openSettings()
                    }
                )
            }

            // Network activity indicators with popover menu
            if networkMonitor.showURLBarNetworkActivity {
                NetworkIndicatorsMenu(
                    networkMonitor: networkMonitor,
                    soundManager: soundManager
                )
            }

            // Netscape-style throbber
            if privacySettings.throbberSize.isEnabled {
                let isRendering = browserState.selectedTab?.isRendering ?? false
                let hasNetworkActivity = browserState.selectedTabId.map { networkMonitor.transmittingTabIds.contains($0) || networkMonitor.receivingTabIds.contains($0) } ?? false
                NetscapeThrobberView(
                    hasNetworkActivity: hasNetworkActivity,
                    isRendering: isRendering,
                    scale: privacySettings.throbberSize.scale
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            inputText = browserState.selectedTab?.url?.absoluteString ?? ""
        }
        .onChange(of: browserState.focusAddressBarTrigger) { _, _ in
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .onChange(of: browserState.selectedTabId) { _, _ in
            // Clear focus when switching tabs to allow interactions with other tabs
            isFocused = false
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
struct LoadingProgressBar: View {
    let progress: Double
    let isLoading: Bool

    @State private var displayedProgress: Double = 0
    @State private var isVisible: Bool = false

    var body: some View {
        GeometryReader { geometry in
            if isVisible {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * displayedProgress)
            }
        }
        .frame(height: 2)
        .clipShape(RoundedRectangle(cornerRadius: 1))
        .onChange(of: isLoading) { _, newIsLoading in
            if newIsLoading {
                // Starting to load - show the bar and reset progress
                displayedProgress = 0.05 // Start with a small amount visible
                withAnimation(.easeOut(duration: 0.1)) {
                    isVisible = true
                }
            } else {
                // Finished loading - animate to 100% then hide
                withAnimation(.easeOut(duration: 0.2)) {
                    displayedProgress = 1.0
                }
                // Hide after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    // Reset for next load
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        displayedProgress = 0
                    }
                }
            }
        }
        .onChange(of: progress) { _, newProgress in
            // Only update if we're loading and new progress is higher
            if isLoading && newProgress > displayedProgress {
                withAnimation(.easeOut(duration: 0.15)) {
                    displayedProgress = newProgress
                }
            }
        }
        .onAppear {
            // Initialize state based on current loading status
            if isLoading {
                isVisible = true
                displayedProgress = max(progress, 0.05)
            }
        }
    }
}

// Legacy progress view (unused but kept for reference)
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

// MARK: - Privacy Shield Popover

struct PrivacyShieldPopover: View {
    let privacyScore: Int
    let maxPrivacyScore: Int
    let privacyScoreColor: Color
    let privacyScoreIcon: String
    let blockedRequests: [BlockedRequestsMonitor.BlockedRequest]
    let onOpenSettings: () -> Void

    private var groupedRequests: [(domain: String, count: Int, reasons: Set<BlockedRequestsMonitor.BlockedRequest.BlockReason>)] {
        var domainInfo: [String: (count: Int, reasons: Set<BlockedRequestsMonitor.BlockedRequest.BlockReason>)] = [:]
        for request in blockedRequests {
            if var info = domainInfo[request.domain] {
                info.count += 1
                info.reasons.insert(request.reason)
                domainInfo[request.domain] = info
            } else {
                domainInfo[request.domain] = (count: 1, reasons: [request.reason])
            }
        }
        return domainInfo.map { (domain: $0.key, count: $0.value.count, reasons: $0.value.reasons) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Privacy score header
            HStack {
                Image(systemName: privacyScoreIcon)
                    .font(.system(size: 16))
                    .foregroundColor(privacyScoreColor)
                Text("Privacy Score: \(privacyScore)/\(maxPrivacyScore)")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }

            Divider()

            // Blocked requests section
            if blockedRequests.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("No requests blocked on this page")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blocked Requests (\(blockedRequests.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(groupedRequests, id: \.domain) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.red)

                                    Text(item.domain)
                                        .font(.system(size: 11, design: .monospaced))
                                        .lineLimit(1)

                                    Spacer()

                                    if item.count > 1 {
                                        Text("×\(item.count)")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }

                                    Text(item.reasons.map { $0.rawValue }.joined(separator: ", "))
                                        .font(.system(size: 9))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            Divider()

            // Settings button
            Button(action: onOpenSettings) {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Privacy Settings")
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(12)
        .frame(width: 280)
    }
}

// MARK: - Network Indicators Menu

struct NetworkIndicatorsMenu: View {
    @ObservedObject var networkMonitor: NetworkActivityMonitor
    @ObservedObject var soundManager: NetworkSoundManager
    @State private var showingPopover = false

    // Filter indicator display based on indicatorScope setting
    private var showRxIndicator: Bool {
        networkMonitor.isReceiving &&
        (networkMonitor.indicatorScope == .allTabs || networkMonitor.lastReceiveWasActiveTab)
    }

    private var showTxIndicator: Bool {
        networkMonitor.isTransmitting &&
        (networkMonitor.indicatorScope == .allTabs || networkMonitor.lastTransmitWasActiveTab)
    }

    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            HStack(spacing: 6) {
                NetworkIndicator(label: "SD", isActive: showTxIndicator, activeColor: .red)
                NetworkIndicator(label: "RD", isActive: showRxIndicator, activeColor: .green)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Network Sounds", systemImage: soundManager.isEnabled ? "speaker.wave.2" : "speaker.slash")
                        .lineLimit(1)
                    Spacer()
                    Toggle("", isOn: $soundManager.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                Divider()

                HStack {
                    Label("Receive Data", systemImage: "arrow.down.circle")
                        .lineLimit(1)
                    Spacer()
                    Toggle("", isOn: $soundManager.rxEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .disabled(!soundManager.isEnabled)
                }
                .opacity(soundManager.isEnabled ? 1.0 : 0.5)

                HStack {
                    Label("Send Data", systemImage: "arrow.up.circle")
                        .lineLimit(1)
                    Spacer()
                    Toggle("", isOn: $soundManager.txEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .disabled(!soundManager.isEnabled)
                }
                .opacity(soundManager.isEnabled ? 1.0 : 0.5)
            }
            .padding(12)
            .fixedSize()
        }
    }
}

// MARK: - Netscape-style Throbber

struct NetscapeThrobberView: View {
    let hasNetworkActivity: Bool
    let isRendering: Bool
    
    // Computed property: animation should be active if any trigger is active
    private var shouldBeActive: Bool {
        hasNetworkActivity || isRendering
    }

    // Star positions (x, y as percentages of container)
    private let starPositions: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.15, 0.12, 1.5), (0.85, 0.08, 2.0), (0.25, 0.35, 1.0),
        (0.75, 0.25, 1.5), (0.10, 0.55, 1.0), (0.90, 0.45, 1.5),
        (0.30, 0.75, 2.0), (0.70, 0.85, 1.0), (0.50, 0.15, 1.5),
        (0.20, 0.90, 1.0), (0.80, 0.70, 1.5), (0.45, 0.60, 1.0),
        (0.60, 0.40, 1.0), (0.35, 0.20, 1.5), (0.65, 0.95, 1.0),
    ]

    var scale: CGFloat = 1.0

    // Meteor animation state
    @State private var meteorOffset: CGFloat = -0.3
    @State private var meteor2Offset: CGFloat = -0.5
    @State private var meteor3Offset: CGFloat = -0.7
    @State private var cometOffset: CGFloat = -0.4
    @State private var starTwinkle: [Bool] = Array(repeating: false, count: 15)
    @State private var isAnimating: Bool = false
    @State private var animationStartTime: Date?
    @State private var pendingStopTask: DispatchWorkItem?
    @State private var isTwinkling: Bool = false
    
    // Minimum animation duration (one full loop of longest animation)
    private let minAnimationDuration: TimeInterval = 1.5

    var body: some View {
        ZStack {
            // Dark space background
            RoundedRectangle(cornerRadius: 4 * scale)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.05, blue: 0.15),
                            Color(red: 0.0, green: 0.0, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Stars
            GeometryReader { geo in
                ForEach(0..<starPositions.count, id: \.self) { i in
                    let star = starPositions[i]
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .opacity(starTwinkle[i] ? 1.0 : 0.4)
                        .position(
                            x: geo.size.width * star.x,
                            y: geo.size.height * star.y
                        )
                }
            }

            // Meteors (only visible when animating)
            if isAnimating {
                GeometryReader { geo in
                    // Main meteor
                    MeteorView()
                        .frame(width: 12 * scale, height: 3 * scale)
                        .position(
                            x: geo.size.width * meteorOffset,
                            y: geo.size.height * (0.3 + meteorOffset * 0.4)
                        )

                    // Second meteor (smaller, different path)
                    MeteorView()
                        .frame(width: 8 * scale, height: 2 * scale)
                        .opacity(0.7)
                        .position(
                            x: geo.size.width * meteor2Offset,
                            y: geo.size.height * (0.6 + meteor2Offset * 0.3)
                        )

                    // Third meteor
                    MeteorView()
                        .frame(width: 6 * scale, height: 2 * scale)
                        .opacity(0.5)
                        .position(
                            x: geo.size.width * meteor3Offset,
                            y: geo.size.height * (0.15 + meteor3Offset * 0.5)
                        )
                }
            }

            // The "B" letter
            Text("B")
                .font(.system(size: 16 * scale, weight: .bold, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.7, green: 0.85, blue: 0.95),
                            Color(red: 0.5, green: 0.7, blue: 0.85),
                            Color(red: 0.3, green: 0.5, blue: 0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.cyan.opacity(0.5), radius: 2, x: 0, y: 0)
                .shadow(color: Color.black, radius: 1, x: 1, y: 1)

            // Large comet on top of the B (only visible when animating)
            if isAnimating {
                GeometryReader { geo in
                    CometView()
                        .frame(width: 24 * scale, height: 6 * scale)
                        .position(
                            x: geo.size.width * cometOffset,
                            y: geo.size.height * (0.4 + cometOffset * 0.3)
                        )
                }
            }
        }
        .frame(width: 28 * scale, height: 28 * scale)
        .clipShape(RoundedRectangle(cornerRadius: 4 * scale))
        .overlay(
            RoundedRectangle(cornerRadius: 4 * scale)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
        .onChange(of: hasNetworkActivity) { _, _ in
            handleTriggerChange(shouldBeActive: shouldBeActive)
        }
        .onChange(of: isRendering) { _, _ in
            handleTriggerChange(shouldBeActive: shouldBeActive)
        }
        .onAppear {
            // Start animations if triggers are already active when view appears
            if shouldBeActive {
                handleTriggerChange(shouldBeActive: true)
            }
        }
        .help(shouldBeActive ? "Loading..." : "Click to reload")
    }

    private func startMeteorAnimation() {
        // Reset positions
        meteorOffset = -0.3
        meteor2Offset = -0.5
        meteor3Offset = -0.7
        cometOffset = -0.4

        // Animate meteors continuously
        animateMeteor1()
        animateMeteor2()
        animateMeteor3()
        animateComet()
    }

    private func animateMeteor1() {
        withAnimation(.linear(duration: 0.8)) {
            meteorOffset = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
            if isAnimating {
                meteorOffset = -0.3
                animateMeteor1()
            }
        }
    }

    private func animateMeteor2() {
        withAnimation(.linear(duration: 1.0)) {
            meteor2Offset = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            if isAnimating {
                meteor2Offset = -0.3
                animateMeteor2()
            }
        }
    }

    private func animateMeteor3() {
        withAnimation(.linear(duration: 1.2)) {
            meteor3Offset = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [self] in
            if isAnimating {
                meteor3Offset = -0.3
                animateMeteor3()
            }
        }
    }

    private func animateComet() {
        withAnimation(.linear(duration: 1.5)) {
            cometOffset = 1.4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
            if isAnimating {
                cometOffset = -0.4
                animateComet()
            }
        }
    }

    private func startTwinkleAnimation() {
        // Only start if not already twinkling
        guard !isTwinkling else { return }
        isTwinkling = true
        twinkleRandomStars()
    }

    private func twinkleRandomStars() {
        guard isAnimating else {
            isTwinkling = false
            return
        }

        // Pick random stars to twinkle
        for i in 0..<starPositions.count {
            if Bool.random() {
                withAnimation(.easeInOut(duration: 0.3)) {
                    starTwinkle[i] = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        starTwinkle[i] = false
                    }
                }
            }
        }

        // Continue twinkling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            twinkleRandomStars()
        }
    }

    private func handleTriggerChange(shouldBeActive: Bool) {
        if shouldBeActive {
            // Cancel any pending stop
            pendingStopTask?.cancel()
            pendingStopTask = nil
            
            if !isAnimating {
                // Not already animating - start animations
                animationStartTime = Date()
                isAnimating = true
                startMeteorAnimation()
                startTwinkleAnimation()
            }
            // If already animating, do nothing - animation continues
        } else {
            // Triggers are inactive - schedule stop after minimum duration
            if isAnimating {
                scheduleStopIfNeeded()
            }
        }
    }
    
    private func scheduleStopIfNeeded() {
        // Cancel any existing pending stop
        pendingStopTask?.cancel()
        
        guard let startTime = animationStartTime else {
            // No start time recorded, stop immediately
            stopAnimations()
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed >= minAnimationDuration {
            // Already completed at least one loop, stop immediately
            stopAnimations()
        } else {
            // Wait for at least one full loop to complete
            let remainingTime = minAnimationDuration - elapsed
            let workItem = DispatchWorkItem { [self] in
                // Check if triggers are still inactive before stopping
                if !shouldBeActive {
                    stopAnimations()
                }
            }
            pendingStopTask = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime, execute: workItem)
        }
    }
    
    private func stopAnimations() {
        // Cancel any pending stop task
        pendingStopTask?.cancel()
        pendingStopTask = nil
        
        // Stop animation loops
        isAnimating = false
        isTwinkling = false
        animationStartTime = nil
        
        // Reset to default state
        withAnimation(.easeOut(duration: 0.3)) {
            for i in 0..<starTwinkle.count {
                starTwinkle[i] = false
            }
        }
    }
}

// Meteor/shooting star shape
struct MeteorView: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.8),
                        Color.white
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: geo.size.height, lineCap: .round)
            )
        }
        .rotationEffect(.degrees(35))
    }
}

// Large comet view (appears on top of the B)
struct CometView: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.5),
                        Color.white.opacity(0.9),
                        Color.white
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: geo.size.height, lineCap: .round)
            )
        }
        .rotationEffect(.degrees(25))
        .shadow(color: Color.white.opacity(0.6), radius: 2, x: 0, y: 0)
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

// MARK: - Video Download Menu

struct VideoDownloadMenu: View {
    let videoTitle: String
    let onDownload: (VideoFormat) -> Void

    private var truncatedTitle: String {
        if videoTitle.count > 40 {
            return String(videoTitle.prefix(37)) + "..."
        }
        return videoTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Download")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(truncatedTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider()
                .padding(.horizontal, 8)

            ForEach(VideoFormat.allCases) { format in
                Button(action: { onDownload(format) }) {
                    HStack(spacing: 10) {
                        Image(systemName: format.icon)
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(format.displayName)
                                .font(.system(size: 13))
                            Text(format.description)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.001))
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .frame(width: 260)
    }
}

#Preview {
    AddressBarView()
        .environmentObject(BrowserState())
        .frame(width: 600)
}
