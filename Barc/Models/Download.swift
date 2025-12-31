//
//  Download.swift
//  Barc
//
//  Model representing an individual video download
//

import Foundation
import SwiftUI

enum DownloadStatus: String, Codable {
    case pending
    case downloading
    case completed
    case failed
    case cancelled
}

class Download: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL                              // Original video page URL
    let sourceTitle: String                   // Page title when download started
    let startedAt: Date

    @Published var title: String              // Video title (from yt-dlp)
    @Published var filename: String?          // Output filename
    @Published var progress: Double = 0.0     // 0.0 to 1.0
    @Published var status: DownloadStatus = .pending
    @Published var speed: String?             // e.g., "1.5MiB/s"
    @Published var eta: String?               // e.g., "00:02:30"
    @Published var totalSize: String?         // e.g., "150.00MiB"
    @Published var downloadedSize: String?    // e.g., "75.00MiB"
    @Published var errorMessage: String?
    @Published var filePath: URL?             // Final file location

    var completedAt: Date?

    init(url: URL, pageTitle: String) {
        self.url = url
        self.sourceTitle = pageTitle
        self.title = pageTitle  // Will be updated by yt-dlp
        self.startedAt = Date()
    }

    var statusIcon: String {
        switch status {
        case .pending:
            return "clock"
        case .downloading:
            return "arrow.down.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        case .cancelled:
            return "xmark.circle"
        }
    }

    var statusColor: Color {
        switch status {
        case .pending:
            return .secondary
        case .downloading:
            return .accentColor
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .secondary
        }
    }

    var progressText: String {
        if let downloaded = downloadedSize, let total = totalSize {
            return "\(downloaded) / \(total)"
        } else if let downloaded = downloadedSize {
            return downloaded
        }
        return ""
    }
}
