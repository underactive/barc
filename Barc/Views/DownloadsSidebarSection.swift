//
//  DownloadsSidebarSection.swift
//  Barc
//
//  Sidebar section displaying video downloads
//

import SwiftUI

struct DownloadsSidebarSection: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(downloadManager.downloads) { download in
                DownloadRowView(download: download)
            }

            if !downloadManager.downloads.isEmpty {
                HStack {
                    Spacer()
                    Button("Clear Completed") {
                        downloadManager.clearCompleted()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("Downloads")
                    .font(.system(size: 11, weight: .medium))

                Spacer()

                if downloadManager.activeDownloadCount > 0 {
                    Text("\(downloadManager.activeDownloadCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
