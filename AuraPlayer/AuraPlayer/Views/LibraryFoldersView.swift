//
//  LibraryFoldersView.swift
//  AuraPlayer
//
//  Browse the library the way it's stored on disk. Many people organise
//  music by folder (Artist/Album/…) and want to navigate that structure
//  rather than trusting tags.
//

import SwiftUI

struct LibraryFoldersView: View {
    @EnvironmentObject var library: LibraryViewModel

    /// Documents is the root of everything the scanner finds.
    private var root: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var body: some View {
        FolderContentsView(directory: root, title: "Files")
    }
}

struct FolderContentsView: View {
    let directory: URL
    let title: String

    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var stats: TrackStatsViewModel

    /// Sub-folders that contain audio somewhere beneath them.
    private var folders: [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return all
            .filter { url in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                else { return false }
                return library.tracks.contains { $0.url.path.hasPrefix(url.path + "/") }
            }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Tracks sitting directly in this folder (not in a sub-folder).
    private var tracks: [Track] {
        library.tracks
            .filter { $0.url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL }
            .sorted { $0.albumSortKey < $1.albumSortKey }
    }

    private var isEmpty: Bool { folders.isEmpty && tracks.isEmpty }

    var body: some View {
        List {
            if !folders.isEmpty {
                Section {
                    ForEach(folders, id: \.path) { folder in
                        NavigationLink {
                            FolderContentsView(directory: folder,
                                               title: folder.lastPathComponent)
                        } label: {
                            Label(folder.lastPathComponent, systemImage: "folder.fill")
                                .foregroundStyle(Color.textPrimary)
                        }
                        .listRowBackground(Color.background)
                    }
                } header: {
                    Text("Folders")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            if !tracks.isEmpty {
                Section {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(track: track,
                                 isPlaying: player.currentTrackURL == track.url,
                                 rating: stats.rating(for: track.url),
                                 isPaused: !player.isPlaying)
                            .contentShape(Rectangle())
                            .onTapGesture { player.load(tracks: tracks, startAt: index) }
                            .listRowBackground(Color.background)
                    }
                } header: {
                    HStack {
                        Text("\(tracks.count) track\(tracks.count == 1 ? "" : "s")")
                        Spacer()
                        Button("Play All") {
                            player.load(tracks: tracks, startAt: 0)
                        }
                        .font(.auraCaption)
                        .foregroundStyle(Color.accent)
                    }
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .safeAreaPadding(.bottom, AuraLayout.miniPlayerClearance)
        .overlay {
            if isEmpty {
                ContentUnavailableView(
                    "Empty",
                    systemImage: "folder",
                    description: Text("No audio files in this folder.")
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
