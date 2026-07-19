//
//  SettingsView.swift
//  AuraPlayer
//
//  App settings hub.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DownloadView()
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                            .foregroundStyle(Color.textPrimary)
                    }
                    .listRowBackground(Color.surface)

                    NavigationLink {
                        DownloadHistoryView()
                    } label: {
                        Label("Download History", systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(Color.textPrimary)
                    }
                    .listRowBackground(Color.surface)

                    NavigationLink {
                        StorageView()
                    } label: {
                        Label("Storage", systemImage: "internaldrive")
                            .foregroundStyle(Color.textPrimary)
                    }
                    .listRowBackground(Color.surface)
                } header: {
                    Text("Library")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                }

                Section {
                    Toggle("Crossfade", isOn: $player.crossfadeEnabled)
                        .tint(Color.accent)
                        .foregroundStyle(Color.textPrimary)
                        .listRowBackground(Color.surface)

                    if player.crossfadeEnabled {
                        VStack(alignment: .leading, spacing: AuraSpacing.xs) {
                            HStack {
                                Text("Duration")
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Text("\(Int(player.crossfadeDuration))s")
                                    .font(.auraTimestamp)
                                    .foregroundStyle(Color.accent)
                            }
                            Slider(value: $player.crossfadeDuration, in: 2...12, step: 1)
                                .tint(Color.accent)
                        }
                        .listRowBackground(Color.surface)
                    }
                } header: {
                    Text("Playback")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                } footer: {
                    Text("Tracks overlap when one ends. Manual skips are always instant.")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textTertiary)
                }

                Section {
                    HStack {
                        Text("Tracks")
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text("\(library.tracks.count)")
                            .foregroundStyle(Color.textTertiary)
                    }
                    .listRowBackground(Color.surface)
                } header: {
                    Text("About")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Settings")
        }
        .preferredColorScheme(.dark)
    }
}
