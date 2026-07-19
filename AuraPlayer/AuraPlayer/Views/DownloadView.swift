//
//  DownloadView.swift
//  AuraPlayer
//
//  Paste a direct audio URL and track download progress.
//

import SwiftUI

struct DownloadView: View {
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel
    @StateObject private var downloads = DownloadManager.shared

    @State private var urlText = ""
    @State private var showInvalidURL = false
    @State private var clipboardHasURL = false

    private var isValidURL: Bool {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme else { return false }
        return scheme.hasPrefix("http") && url.host != nil
    }

    private var active: [DownloadItem] { downloads.items.filter { $0.status.isActive } }
    private var finished: [DownloadItem] { downloads.items.filter { !$0.status.isActive } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: AuraSpacing.sm) {
                    TextField("https://example.com/song.mp3", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.auraBody)
                        .foregroundStyle(Color.textPrimary)

                    if showInvalidURL {
                        Text("Enter a valid http(s) link to an audio file.")
                            .font(.auraCaption)
                            .foregroundStyle(Color.error)
                    }

                    if clipboardHasURL && urlText.isEmpty {
                        AuraButton("Paste & Download", systemImage: "doc.on.clipboard", variant: .primary) {
                            pasteAndDownload()
                        }
                    } else {
                        AuraButton("Download", systemImage: "arrow.down.circle", variant: .primary) {
                            submit()
                        }
                    }
                }
                .padding(.vertical, AuraSpacing.xs)
                .listRowBackground(Color.surface)
            } header: {
                Text("Add Download")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
            }

            if !active.isEmpty {
                Section {
                    ForEach(active) { item in
                        activeRow(item)
                            .listRowBackground(Color.background)
                    }
                } header: {
                    Text("Active")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            if !finished.isEmpty {
                Section {
                    ForEach(finished) { item in
                        finishedRow(item)
                            .listRowBackground(Color.background)
                    }
                } header: {
                    HStack {
                        Text("Completed")
                        Spacer()
                        Button("Clear") { downloads.clearCompleted() }
                            .font(.auraCaption)
                            .foregroundStyle(Color.accent)
                    }
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            downloads.onDownloadFinished = {
                Task { await library.scan() }
            }
            clipboardHasURL = await clipboardLikelyHasURL()
        }
    }

    // MARK: - Rows

    private func activeRow(_ item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: AuraSpacing.xs) {
            Text(item.filename)
                .font(.auraBody)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            ProgressView(value: item.progress)
                .tint(Color.accent)

            HStack {
                Text("\(Int(item.progress * 100))% · \(item.status.label)")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textTertiary)

                if item.status == .downloading, item.speed > 0 {
                    Text("· \(StorageManager.formatted(Int64(item.speed)))/s")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                if item.status == .downloading {
                    Button { downloads.pause(item) } label: {
                        Image(systemName: "pause.circle").foregroundStyle(Color.accent)
                    }
                } else if item.status == .paused {
                    Button { downloads.resume(item) } label: {
                        Image(systemName: "play.circle").foregroundStyle(Color.accent)
                    }
                }

                Button { downloads.cancel(item) } label: {
                    Image(systemName: "xmark.circle").foregroundStyle(Color.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, AuraSpacing.xs)
    }

    private func finishedRow(_ item: DownloadItem) -> some View {
        HStack(spacing: AuraSpacing.md) {
            statusIcon(for: item.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .font(.auraBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(item.status.label)
                    .font(.auraCaption)
                    .foregroundStyle(isFailed(item.status) ? Color.error : Color.textTertiary)
            }

            Spacer()

            if item.status == .finished {
                Button("Play") { playNow(item) }
                    .font(.auraCaption)
                    .foregroundStyle(Color.accent)
                    .buttonStyle(.plain)
            } else if isFailed(item.status) {
                Button("Retry") { downloads.retry(item) }
                    .font(.auraCaption)
                    .foregroundStyle(Color.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, AuraSpacing.xs)
    }

    @ViewBuilder
    private func statusIcon(for status: DownloadStatus) -> some View {
        switch status {
        case .finished:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.success)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.error)
        default:
            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textTertiary)
        }
    }

    private func isFailed(_ status: DownloadStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }

    // MARK: - Actions

    /// Checks whether the clipboard *probably* holds a URL.
    /// This does NOT read the clipboard, so no privacy banner is shown.
    private func clipboardLikelyHasURL() async -> Bool {
        await withCheckedContinuation { continuation in
            UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { result in
                switch result {
                case .success(let patterns):
                    continuation.resume(returning: patterns.contains(.probableWebURL))
                case .failure:
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Reads the clipboard (user-initiated, so the paste banner is expected) and downloads.
    private func pasteAndDownload() {
        guard let pasted = UIPasteboard.general.string else {
            clipboardHasURL = false
            return
        }
        urlText = pasted
        submit()
    }

    private func submit() {
        guard isValidURL else {
            showInvalidURL = true
            return
        }
        showInvalidURL = false
        downloads.enqueue(urlString: urlText)
        urlText = ""
    }

    private func playNow(_ item: DownloadItem) {
        guard let track = library.tracks.first(where: { $0.url.lastPathComponent == item.filename })
        else { return }
        player.load(tracks: [track])
    }
}
