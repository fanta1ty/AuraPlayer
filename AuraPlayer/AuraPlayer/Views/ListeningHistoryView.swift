//
//  ListeningHistoryView.swift
//  AuraPlayer
//
//  Recently played and most played, derived from the play counts we already
//  collect. Nothing is tracked that wasn't already being recorded.
//

import SwiftUI

struct ListeningHistoryView: View {
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var stats: TrackStatsViewModel

    enum Mode: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case most = "Most Played"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .recent

    private var tracks: [Track] {
        switch mode {
        case .recent: return stats.recentlyPlayed(from: library.tracks)
        case .most:   return stats.mostPlayed(from: library.tracks)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(AuraSpacing.md)

            if tracks.isEmpty {
                ContentUnavailableView(
                    "Nothing Yet",
                    systemImage: "clock",
                    description: Text("Play a track for 30 seconds and it will show up here.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: AuraSpacing.md) {
                            TrackRow(track: track,
                                     isPlaying: player.currentTrackURL == track.url,
                                     rating: stats.rating(for: track.url),
                                 isPaused: !player.isPlaying)

                            if mode == .most {
                                Text("\(stats.playCount(for: track.url))×")
                                    .font(.auraTimestamp)
                                    .foregroundStyle(Color.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { player.load(tracks: tracks, startAt: index) }
                        .listRowBackground(Color.background)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaPadding(.bottom, AuraLayout.miniPlayerClearance)
            }
        }
        .background(Color.background)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
