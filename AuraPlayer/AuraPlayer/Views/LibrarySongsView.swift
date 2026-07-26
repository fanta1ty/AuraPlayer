//
//  LibrarySongsView.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  All songs in the library, searchable and sortable. Tap to play
//

import SwiftUI

struct LibrarySongsView: View {
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var playlists: PlaylistViewModel
    @EnvironmentObject var stats: TrackStatsViewModel
    
    @State private var searchText = ""
    @State private var showImporter = false
    @State private var isImporting = false
    @State private var editingTrack: Track?
    @State private var infoTrack: Track?

    @State private var selection = Set<Track.ID>()
    @State private var isSelecting = false
    @State private var showBatchEdit = false
    @State private var showGlobalSearch = false

    private var selectedTracks: [Track] {
        displayedTracks.filter { selection.contains($0.id) }
    }
    @State private var sort: SortOrder = .title
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case title = "A-Z"
        case recentlyAdded = "Recently Added"
        case duration = "Duration"
        var id: String { rawValue }
    }
    
    private var displayedTracks: [Track] {
        var list = library.tracks
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter({
                $0.title
                    .lowercased()
                    .contains(q) || $0.artist
                    .lowercased()
                    .contains(q)
            })
        }
        switch sort {
        case .title:
            list
                .sort {
                    $0.title
                        .localizedCaseInsensitiveCompare(
                            $1.title
                        ) == .orderedAscending
                }
        case .recentlyAdded:
            list.sort { $0.dateAdded > $1.dateAdded }
        case .duration:
            list.sort { $0.duration < $1.duration }
        }
        return list
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if library.isScanning && library.tracks.isEmpty {
                    ProgressView().tint(Color.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.background)
                } else if displayedTracks.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
            .navigationTitle("Songs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showImporter = true
                    } label: {
                        if isImporting {
                            ProgressView().tint(Color.accent)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(Color.accent)
                        }
                    }
                    .disabled(isImporting)
                }
                // While selecting, the edit action sits in the top bar — a
                // .bottomBar item ends up hidden behind the tab bar and
                // mini player.
                if isSelecting {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showBatchEdit = true
                        } label: {
                            Text(selection.isEmpty ? "Edit" : "Edit (\(selection.count))")
                        }
                        .disabled(selection.isEmpty)
                        .foregroundStyle(selection.isEmpty ? Color.textDisabled : Color.accent)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showGlobalSearch = true
                        } label: {
                            Image(systemName: "sparkle.magnifyingglass")
                                .foregroundStyle(Color.accent)
                        }
                        .accessibilityLabel("Search everything")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelecting ? "Done" : "Select") {
                        withAnimation {
                            isSelecting.toggle()
                            if !isSelecting { selection.removeAll() }
                        }
                    }
                    .foregroundStyle(Color.accent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(Color.accent)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search songs or artists")
            .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
            .sheet(isPresented: $showGlobalSearch) {
                GlobalSearchView()
                    .environmentObject(library)
                    .environmentObject(player)
                    .environmentObject(stats)
                    .environmentObject(playlists)
            }
            .sheet(isPresented: $showBatchEdit) {
                BatchEditView(tracks: selectedTracks)
                    .environmentObject(library)
            }
            .sheet(item: $infoTrack) { track in
                TrackInfoView(track: track)
                    .environmentObject(stats)
            }
            .sheet(item: $editingTrack) { track in
                MetadataEditorView(track: track)
                    .environmentObject(library)
            }
            .sheet(isPresented: $showImporter) {
                DocumentPickerView { urls in
                    showImporter = false
                    guard !urls.isEmpty else { return }
                    isImporting = true
                    Task {
                        await handleImport(urls)
                        await library.scan()
                        isImporting = false
                    }
                }
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var songList: some View {
        List(selection: $selection) {
            ForEach(displayedTracks) { track in
                TrackRow(
                    track: track,
                    isPlaying: player.currentTrackURL == track.url,
                    rating: stats.rating(for: track.url),
                    isPaused: !player.isPlaying
                )
                .contentShape(Rectangle())
                // Tap-to-play only outside edit mode; in edit mode taps select.
                .onTapGesture { if !isSelecting { play(track) } }
                .contextMenu {
                    Button {
                        infoTrack = track
                    } label: {
                        Label("Info", systemImage: "info.circle")
                    }

                    Button {
                        editingTrack = track
                    } label: {
                        Label("Edit Info", systemImage: "pencil")
                    }

                    Button {
                        player.playNext(track)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }

                    Button {
                        player.addToQueue(track)
                    } label: {
                        Label("Add to Queue", systemImage: "text.append")
                    }

                    Divider()

                    Menu("Add to Playlist") {
                        ForEach(playlists.playlists) { playlist in
                            Button(playlist.name) {
                                playlists.add(track: track, to: playlist)
                            }
                        }
                    }
                }
                .listRowBackground(Color.background)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .safeAreaPadding(.bottom, AuraLayout.miniPlayerClearance)
        .refreshable { await library.scan() }
    }
    
    /// Route each picked file by type: archives are unpacked, .m3u files
    /// become playlists, everything else is copied in as audio.
    private func handleImport(_ urls: [URL]) async {
        var audio: [URL] = []

        for url in urls {
            switch url.pathExtension.lowercased() {
            case "zip":
                _ = await ZipImporter.importArchive(at: url)

            case "m3u", "m3u8":
                // Resolve against the library as it stands right now.
                if let result = M3UService.importPlaylist(from: url, library: library.tracks),
                   !result.matched.isEmpty {
                    playlists.create(name: result.name)
                    if let created = playlists.playlists.last {
                        for track in result.matched {
                            playlists.add(track: track, to: created)
                        }
                    }
                }

            default:
                audio.append(url)
            }
        }

        if !audio.isEmpty {
            AudioImporter.importFiles(audio)
        }
    }

    private func play(_ track: Track) {
        guard let start = displayedTracks.firstIndex(of: track) else { return }
        player.load(tracks: displayedTracks, startAt: start)
    }
    
    private var emptyState: some View {
        ZStack {
            AuraBackground(intensity: 0.8)

            VStack(spacing: AuraSpacing.lg) {
                AuraLogoMark(size: 84, isAnimating: true)

                VStack(spacing: AuraSpacing.sm) {
                    Text("No songs yet")
                        .font(.auraTitle)
                        .foregroundStyle(Color.textPrimary)
                    Text("Import files, paste a download link, or use Wi-Fi transfer from your computer.")
                        .font(.auraBody)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AuraSpacing.xl)
                }

                AuraButton("Import Music", systemImage: "square.and.arrow.down", variant: .primary) {
                    showImporter = true
                }
                .padding(.horizontal, AuraSpacing.xxl)
                .padding(.top, AuraSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
