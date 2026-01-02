//
//  DownloadManager.swift
//  Barc
//
//  Manages video downloads using bundled yt-dlp
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

// MARK: - Video Format Options

enum VideoFormat: String, CaseIterable, Identifiable {
    case best = "best"
    case mp4 = "mp4"
    case quality720p = "720p"
    case quality480p = "480p"
    case audioOnly = "audio"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .best: return "Best Quality"
        case .mp4: return "MP4"
        case .quality720p: return "720p"
        case .quality480p: return "480p"
        case .audioOnly: return "Audio Only"
        }
    }

    var description: String {
        switch self {
        case .best: return "Original format, no re-encoding"
        case .mp4: return "Converts to MP4 for compatibility"
        case .quality720p: return "Smaller file, good for mobile"
        case .quality480p: return "Smallest file, lower quality"
        case .audioOnly: return "Extract audio as MP3"
        }
    }

    var icon: String {
        switch self {
        case .best: return "star.fill"
        case .mp4: return "film"
        case .quality720p: return "rectangle.on.rectangle"
        case .quality480p: return "rectangle"
        case .audioOnly: return "music.note"
        }
    }

    var ytdlpArguments: [String] {
        switch self {
        case .best:
            return []  // Default behavior
        case .mp4:
            return ["-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best", "--merge-output-format", "mp4"]
        case .quality720p:
            return ["-f", "bestvideo[height<=720]+bestaudio/best[height<=720]/best"]
        case .quality480p:
            return ["-f", "bestvideo[height<=480]+bestaudio/best[height<=480]/best"]
        case .audioOnly:
            return ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        }
    }
}

final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [Download] = []
    @Published var activeDownloadCount: Int = 0

    private let maxConcurrentDownloads = 3
    private var processes: [UUID: Process] = [:]
    private var pendingQueue: [Download] = []

    // Get yt-dlp path from bundle
    private var ytdlpPath: URL? {
        Bundle.main.url(forResource: "yt-dlp", withExtension: nil)
    }

    private init() {}

    // MARK: - Public Methods

    @discardableResult
    func startDownload(url: URL, pageTitle: String, format: VideoFormat = .best) -> Download {
        let download = Download(url: url, pageTitle: pageTitle, format: format)

        DispatchQueue.main.async {
            self.downloads.insert(download, at: 0)
        }

        if activeDownloadCount < maxConcurrentDownloads {
            runYtdlp(for: download)
        } else {
            download.status = .pending
            pendingQueue.append(download)
        }

        return download
    }

    func cancelDownload(_ download: Download) {
        if let process = processes[download.id] {
            process.terminate()
            processes.removeValue(forKey: download.id)
        }

        DispatchQueue.main.async {
            download.status = .cancelled
            self.activeDownloadCount = max(0, self.activeDownloadCount - 1)
        }

        // Remove from pending queue if present
        pendingQueue.removeAll { $0.id == download.id }

        startNextPending()
    }

    func retryDownload(_ download: Download) {
        download.status = .pending
        download.progress = 0
        download.errorMessage = nil

        if activeDownloadCount < maxConcurrentDownloads {
            runYtdlp(for: download)
        } else {
            pendingQueue.append(download)
        }
    }

    func removeDownload(_ download: Download) {
        cancelDownload(download)

        DispatchQueue.main.async {
            self.downloads.removeAll { $0.id == download.id }
        }
    }

    func clearCompleted() {
        DispatchQueue.main.async {
            self.downloads.removeAll {
                $0.status == .completed || $0.status == .cancelled
            }
        }
    }

    func revealInFinder(_ download: Download) {
        guard let filePath = download.filePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([filePath])
    }

    // MARK: - Private Methods

    private func runYtdlp(for download: Download) {
        guard let ytdlp = ytdlpPath else {
            DispatchQueue.main.async {
                download.status = .failed
                download.errorMessage = "yt-dlp binary not found in app bundle"
            }
            return
        }

        // Verify binary exists and is executable
        let fileManager = FileManager.default
        guard fileManager.isExecutableFile(atPath: ytdlp.path) else {
            DispatchQueue.main.async {
                download.status = .failed
                download.errorMessage = "yt-dlp binary is not executable"
            }
            return
        }

        let process = Process()
        process.executableURL = ytdlp

        // Get download location from settings
        let outputDir = PrivacySettings.shared.downloadLocation
            .replacingOccurrences(of: "~", with: NSHomeDirectory())

        // Create output directory if needed
        try? fileManager.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // yt-dlp arguments for progress tracking
        var arguments = [
            "--no-playlist",  // Only download the single video, not entire playlist
            "--newline",
            "--no-warnings",
            "--progress",
            "-o", "\(outputDir)/%(title)s.%(ext)s",
            "--print", "before_dl:TITLE:%(title)s",
            "--print", "after_video:FILEPATH:%(filepath)s"
        ]

        // Add format-specific arguments
        arguments.append(contentsOf: download.format.ytdlpArguments)

        // Add the URL last
        arguments.append(download.url.absoluteString)

        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var stderrData = Data()

        // Handle stdout for progress
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self, weak download] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let line = String(data: data, encoding: .utf8),
                  let download = download else { return }

            DispatchQueue.main.async {
                self?.parseOutputLine(line, for: download)
            }
        }

        // Collect stderr for error reporting
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                stderrData.append(data)
            }
        }

        process.terminationHandler = { [weak self, weak download] process in
            guard let download = download else { return }

            // Capture stderr message
            let stderrMessage = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            DispatchQueue.main.async {
                if process.terminationStatus != 0 && !stderrMessage.isNilOrEmpty {
                    download.errorMessage = stderrMessage
                    print("[Barc Download] Error: \(stderrMessage ?? "unknown")")
                }
                self?.handleProcessTermination(process, for: download)
            }
        }

        do {
            try process.run()
            processes[download.id] = process

            DispatchQueue.main.async {
                download.status = .downloading
                self.activeDownloadCount += 1
            }
        } catch {
            DispatchQueue.main.async {
                download.status = .failed
                download.errorMessage = error.localizedDescription
            }
        }
    }

    private func parseOutputLine(_ line: String, for download: Download) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for title line (from --print before_dl:TITLE:...)
        if trimmed.hasPrefix("TITLE:") {
            let title = String(trimmed.dropFirst(6))
            download.title = title
            return
        }

        // Check for filepath line (from --print after_video:FILEPATH:...)
        if trimmed.hasPrefix("FILEPATH:") {
            let path = String(trimmed.dropFirst(9))
            download.filePath = URL(fileURLWithPath: path)
            download.filename = URL(fileURLWithPath: path).lastPathComponent
            return
        }

        // Parse standard yt-dlp progress line: "[download]  XX.X% of XXXMiB at XXX/s ETA XX:XX"
        if trimmed.hasPrefix("[download]") {
            // Extract percentage
            if let percentRange = trimmed.range(of: #"(\d+\.?\d*)%"#, options: .regularExpression) {
                let percentStr = trimmed[percentRange].dropLast() // Remove %
                if let percent = Double(percentStr) {
                    download.progress = percent / 100.0
                }
            }

            // Extract speed (XXX/s or XXXMiB/s etc)
            if let speedRange = trimmed.range(of: #"at\s+([\d.]+\s*\w+/s)"#, options: .regularExpression) {
                let match = trimmed[speedRange]
                let speedPart = match.replacingOccurrences(of: "at ", with: "").trimmingCharacters(in: .whitespaces)
                download.speed = speedPart
            }

            // Extract ETA
            if let etaRange = trimmed.range(of: #"ETA\s+([\d:]+|Unknown)"#, options: .regularExpression) {
                let match = trimmed[etaRange]
                let etaPart = match.replacingOccurrences(of: "ETA ", with: "")
                download.eta = etaPart
            }

            // Extract total size
            if let sizeRange = trimmed.range(of: #"of\s+([\d.]+\s*\w+)"#, options: .regularExpression) {
                let match = trimmed[sizeRange]
                let sizePart = match.replacingOccurrences(of: "of ", with: "").trimmingCharacters(in: .whitespaces)
                download.totalSize = sizePart
            }
        }

        // Also parse [Merger] line to know merging is happening
        if trimmed.hasPrefix("[Merger]") {
            download.speed = "Merging..."
            download.eta = nil
        }
    }

    private func handleProcessTermination(_ process: Process, for download: Download) {
        processes.removeValue(forKey: download.id)
        activeDownloadCount = max(0, activeDownloadCount - 1)

        if process.terminationStatus == 0 {
            download.status = .completed
            download.progress = 1.0
            download.completedAt = Date()

            // Send notification
            sendDownloadNotification(for: download)
        } else if download.status != .cancelled {
            download.status = .failed
            if download.errorMessage == nil {
                download.errorMessage = "Download failed with exit code \(process.terminationStatus)"
            }
        }

        startNextPending()
    }

    private func startNextPending() {
        guard activeDownloadCount < maxConcurrentDownloads,
              !pendingQueue.isEmpty else { return }

        let next = pendingQueue.removeFirst()
        runYtdlp(for: next)
    }

    private func sendDownloadNotification(for download: Download) {
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = download.title
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: download.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
