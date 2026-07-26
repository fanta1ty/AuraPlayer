//
//  BackupView.swift
//  AuraPlayer
//
//  Export and restore everything the app knows about your library.
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var showPicker = false
    @State private var pendingRestore: LibraryBackup?
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        List {
            Section {
                Button {
                    exportBackup()
                } label: {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Color.accent)
                }
                .listRowBackground(Color.surface)

                Button {
                    showPicker = true
                } label: {
                    Label("Restore from File", systemImage: "square.and.arrow.down")
                        .foregroundStyle(Color.accent)
                }
                .listRowBackground(Color.surface)
            } footer: {
                Text("Backs up ratings, play counts, playlists, smart playlists, metadata edits and EQ presets. Audio files are not included — those stay on your device or can be re-added.")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textTertiary)
            }

            if let message {
                Section {
                    Text(message)
                        .font(.auraCaption)
                        .foregroundStyle(isError ? Color.error : Color.success)
                        .listRowBackground(Color.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { exportURL.map(ShareItem.init) },
            set: { _ in exportURL = nil }
        )) { item in
            ShareSheet(url: item.url)
        }
        .fileImporter(isPresented: $showPicker,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert("Restore Backup?", isPresented: Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil } }
        )) {
            Button("Restore", role: .destructive) {
                if let backup = pendingRestore {
                    BackupService.restore(backup)
                    show("Restored. Relaunch the app to see everything.", error: false)
                }
                pendingRestore = nil
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text(pendingRestore.map {
                "This replaces your current ratings, playlists and presets with:\n\n\($0.summary)"
            } ?? "")
        }
    }

    // MARK: - Actions

    private func exportBackup() {
        if let url = BackupService.export() {
            exportURL = url
        } else {
            show("Couldn't create the backup file.", error: true)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if let backup = BackupService.read(from: url) {
                pendingRestore = backup
            } else {
                show("That file isn't a valid AuraPlayer backup.", error: true)
            }
        case .failure(let error):
            show(error.localizedDescription, error: true)
        }
    }

    private func show(_ text: String, error: Bool) {
        message = text
        isError = error
    }
}

/// Wrapper so a URL can drive a `sheet(item:)`.
private struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
