//
//  DownloadRowView.swift
//  Barc
//
//  Individual download item view for sidebar
//

import SwiftUI

struct DownloadRowView: View {
    @ObservedObject var download: Download
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // Status icon
                statusIcon
                    .frame(width: 14, height: 14)

                // Title
                Text(download.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Action buttons on hover
                if isHovered {
                    actionButtons
                }
            }

            // Progress bar (only when downloading)
            if download.status == .downloading {
                ProgressView(value: download.progress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)

                HStack {
                    if let speed = download.speed {
                        Text(speed)
                    }
                    Spacer()
                    if let eta = download.eta, eta != "Unknown" {
                        Text(eta)
                    }
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            }

            // Error message
            if download.status == .failed, let error = download.errorMessage {
                Text("ERROR: \(error)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.red)
                    .lineLimit(nil)  // Show full error
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovered ? Color.gray.opacity(0.1) : .clear)
        .cornerRadius(4)
        .onHover { isHovered = $0 }
        .contextMenu {
            contextMenuItems
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch download.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.secondary)
        case .downloading:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 14, height: 14)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        case .cancelled:
            Image(systemName: "xmark.circle")
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 4) {
            switch download.status {
            case .downloading:
                Button {
                    DownloadManager.shared.cancelDownload(download)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Cancel download")

            case .failed:
                Button {
                    DownloadManager.shared.retryDownload(download)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Retry download")

            case .completed:
                if download.filePath != nil {
                    Button {
                        DownloadManager.shared.revealInFinder(download)
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }

            default:
                EmptyView()
            }

            Button {
                DownloadManager.shared.removeDownload(download)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help("Remove from list")
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if download.status == .downloading {
            Button("Cancel Download") {
                DownloadManager.shared.cancelDownload(download)
            }
        }

        if download.status == .failed {
            Button("Retry Download") {
                DownloadManager.shared.retryDownload(download)
            }
        }

        if download.status == .completed, download.filePath != nil {
            Button("Show in Finder") {
                DownloadManager.shared.revealInFinder(download)
            }
        }

        Divider()

        Button("Copy URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(download.url.absoluteString, forType: .string)
        }

        Divider()

        Button("Remove from List") {
            DownloadManager.shared.removeDownload(download)
        }
    }
}
