//
//  SmartPlaylistsView.swift
//  AuraPlayer
//
//  Rule-based playlists that re-evaluate every time they're opened.
//

import SwiftUI

struct SmartPlaylistsView: View {
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var stats: TrackStatsViewModel
    @StateObject private var smart = SmartPlaylistViewModel.shared

    @State private var editing: SmartPlaylist?
    @State private var isCreating = false

    var body: some View {
        Group {
            if smart.playlists.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(smart.playlists) { playlist in
                        NavigationLink {
                            SmartPlaylistDetailView(playlistID: playlist.id)
                        } label: {
                            row(playlist)
                        }
                        .listRowBackground(Color.background)
                        .swipeActions(edge: .trailing) {
                            Button("Edit") { editing = playlist }
                                .tint(Color.accentDim)
                        }
                    }
                    .onDelete { smart.delete(at: $0) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaPadding(.bottom, AuraLayout.miniPlayerClearance)
            }
        }
        .background(Color.background)
        .navigationTitle("Smart Playlists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Image(systemName: "plus").foregroundStyle(Color.accent)
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            SmartPlaylistEditorView(playlist: SmartPlaylist(name: "", rules: [SmartRule()]),
                                    isNew: true)
        }
        .sheet(item: $editing) { playlist in
            SmartPlaylistEditorView(playlist: playlist, isNew: false)
        }
    }

    private func row(_ playlist: SmartPlaylist) -> some View {
        let count = SmartPlaylistEngine.evaluate(playlist,
                                                 tracks: library.tracks,
                                                 stats: stats).count
        return VStack(alignment: .leading, spacing: 2) {
            Text(playlist.name)
                .font(.auraBody)
                .foregroundStyle(Color.textPrimary)
            Text("\(count) track\(count == 1 ? "" : "s") · \(summary(playlist))")
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
    }

    private func summary(_ playlist: SmartPlaylist) -> String {
        playlist.rules.map(SmartPlaylistEngine.describe)
            .joined(separator: playlist.matchAll ? " and " : " or ")
    }

    private var emptyState: some View {
        VStack(spacing: AuraSpacing.lg) {
            ContentUnavailableView(
                "No Smart Playlists",
                systemImage: "wand.and.stars",
                description: Text("Playlists that build themselves from rules — like everything rated 4 stars or higher.")
            )

            AuraButton("Add Suggested Playlists", systemImage: "sparkles", variant: .secondary) {
                smart.addPresets()
            }
            .padding(.horizontal, AuraSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
