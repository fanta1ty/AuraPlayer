//
//  StorageView.swift
//  AuraPlayer
//
//  Shows how much space music files use, largest first, with delete options.
//

import SwiftUI

struct StorageView: View {
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel

    @State private var files: [StoredFile] = []
    @State private var showDeleteAllConfirm = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Used")
                        .font(.auraBody)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(StorageManager.formatted(StorageManager.totalSize(of: files)))
                        .font(.auraTimestamp)
                        .foregroundStyle(Color.accent)
                }
                .listRowBackground(Color.surface)
            }

            Section {
                ForEach(files) { file in
                    HStack(spacing: AuraSpacing.md) {
                        Text(file.name)
                            .font(.auraBody)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(StorageManager.formatted(file.size))
                            .font(.auraTimestamp)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .listRowBackground(Color.background)
                }
                .onDelete(perform: deleteFiles)
            } header: {
                Text("\(files.count) file\(files.count == 1 ? "" : "s")")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
            }

            if !files.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showDeleteAllConfirm = true
                    } label: {
                        Text("Delete All Music")
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if files.isEmpty {
                ContentUnavailableView("No Music Files", systemImage: "internaldrive",
                                       description: Text("Import music to see storage usage."))
            }
        }
        .alert("Delete All Music?", isPresented: $showDeleteAllConfirm) {
            Button("Delete All", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every audio file from AuraPlayer. This can't be undone.")
        }
        .task { reload() }
    }

    private func reload() {
        files = StorageManager.audioFiles()
    }

    private func deleteFiles(at offsets: IndexSet) {
        let targets = offsets.map { files[$0] }
        stopIfPlaying(any: targets)
        targets.forEach { StorageManager.delete($0) }
        refreshAfterDelete()
    }

    private func deleteAll() {
        stopIfPlaying(any: files)
        StorageManager.deleteAll(files)
        refreshAfterDelete()
    }

    /// If we just deleted the track that's playing, stop first.
    private func stopIfPlaying(any targets: [StoredFile]) {
        guard let current = player.currentTrackURL else { return }
        if targets.contains(where: { $0.url == current }) {
            player.stop()
        }
    }

    private func refreshAfterDelete() {
        reload()
        Task { await library.scan() }
    }
}
