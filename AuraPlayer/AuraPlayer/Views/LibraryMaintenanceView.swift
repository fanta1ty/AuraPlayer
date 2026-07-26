//
//  LibraryMaintenanceView.swift
//  AuraPlayer
//
//  Find duplicates, clean up dead playlist entries, and tidy the folder
//  structure. Everything destructive asks first.
//

import SwiftUI

struct LibraryMaintenanceView: View {
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var playlists: PlaylistViewModel
    @EnvironmentObject var player: PlayerViewModel

    @State private var confirmDuplicates = false
    @State private var confirmOrganise = false
    @State private var message: String?

    private var duplicates: [LibraryMaintenance.DuplicateGroup] {
        LibraryMaintenance.duplicates(in: library.tracks)
    }

    private var broken: [LibraryMaintenance.BrokenEntry] {
        LibraryMaintenance.brokenEntries(playlists: playlists.playlists,
                                         tracks: library.tracks)
    }

    private var reclaimable: Int64 {
        duplicates.reduce(0) { $0 + $1.reclaimable }
    }

    var body: some View {
        List {
            if let message {
                Section {
                    Text(message)
                        .font(.auraCaption)
                        .foregroundStyle(Color.success)
                        .listRowBackground(Color.surface)
                }
            }

            duplicatesSection
            brokenSection
            organiseSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("Library Cleanup")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remove Duplicates?", isPresented: $confirmDuplicates) {
            Button("Remove", role: .destructive) { removeDuplicates() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keeps the earliest copy of each track and deletes the rest — freeing \(StorageManager.formatted(reclaimable)).")
        }
        .alert("Organise Files?", isPresented: $confirmOrganise) {
            Button("Organise") { organise() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Moves every track into Music/Artist/Album folders based on its tags. Playback isn't affected.")
        }
    }

    // MARK: - Sections

    @ViewBuilder private var duplicatesSection: some View {
        Section {
            if duplicates.isEmpty {
                Label("No duplicates found", systemImage: "checkmark.circle")
                    .font(.auraCaption)
                    .foregroundStyle(Color.success)
                    .listRowBackground(Color.surface)
            } else {
                ForEach(duplicates) { group in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(.auraBody)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Text("\(group.tracks.count) copies · \(group.artist)")
                            .font(.auraCaption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .listRowBackground(Color.surface)
                }

                Button(role: .destructive) {
                    confirmDuplicates = true
                } label: {
                    Text("Remove \(duplicates.reduce(0) { $0 + $1.redundant.count }) Duplicates")
                }
                .listRowBackground(Color.surface)
            }
        } header: {
            Text("Duplicates")
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
        } footer: {
            if !duplicates.isEmpty {
                Text("Matched on title, artist and length. \(StorageManager.formatted(reclaimable)) can be reclaimed.")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    @ViewBuilder private var brokenSection: some View {
        Section {
            if broken.isEmpty {
                Label("All playlist entries are valid", systemImage: "checkmark.circle")
                    .font(.auraCaption)
                    .foregroundStyle(Color.success)
                    .listRowBackground(Color.surface)
            } else {
                ForEach(broken) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.filename)
                            .font(.auraCaption)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Text("in \(entry.playlistName)")
                            .font(.auraCaption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .listRowBackground(Color.surface)
                }

                Button(role: .destructive) {
                    removeBrokenEntries()
                } label: {
                    Text("Remove \(broken.count) Missing Entries")
                }
                .listRowBackground(Color.surface)
            }
        } header: {
            Text("Missing Files")
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
        } footer: {
            Text("Playlist entries whose audio file has been deleted.")
                .font(.auraCaption)
                .foregroundStyle(Color.textTertiary)
        }
    }

    private var organiseSection: some View {
        Section {
            Button {
                confirmOrganise = true
            } label: {
                Label("Organise into Folders", systemImage: "folder.badge.gearshape")
                    .foregroundStyle(Color.accent)
            }
            .listRowBackground(Color.surface)
        } header: {
            Text("Files")
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
        } footer: {
            Text("Sorts your music into Artist/Album folders using the tags on each track.")
                .font(.auraCaption)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Actions

    private func removeDuplicates() {
        let doomed = duplicates.flatMap(\.redundant)
        // Don't delete the file that's playing.
        let current = player.currentTrackURL
        var removed = 0

        for track in doomed where track.url != current {
            try? FileManager.default.removeItem(at: track.url)
            removed += 1
        }

        message = "Removed \(removed) duplicate\(removed == 1 ? "" : "s")."
        Task { await library.scan() }
    }

    private func removeBrokenEntries() {
        let missingByPlaylist = Dictionary(grouping: broken, by: \.playlistID)

        for (playlistID, entries) in missingByPlaylist {
            guard let playlist = playlists.playlist(id: playlistID) else { continue }
            let names = Set(entries.map(\.filename))
            let offsets = IndexSet(
                playlist.trackFilenames.enumerated()
                    .filter { names.contains($0.element) }
                    .map(\.offset)
            )
            playlists.removeTracks(at: offsets, from: playlistID)
        }
        message = "Cleaned up \(broken.count) missing entr\(broken.count == 1 ? "y" : "ies")."
    }

    private func organise() {
        let result = LibraryMaintenance.organise(library.tracks)
        message = "Moved \(result.moved) file\(result.moved == 1 ? "" : "s")."
        Task { await library.scan() }
    }
}
