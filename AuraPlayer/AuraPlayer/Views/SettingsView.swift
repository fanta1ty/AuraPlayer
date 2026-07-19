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
    @StateObject private var effects = PlaybackEffects.shared

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
                    Toggle("Volume Normalization", isOn: $player.normalizationEnabled)
                        .tint(Color.accent)
                        .foregroundStyle(Color.textPrimary)
                        .listRowBackground(Color.surface)
                } header: {
                    Text("Playback")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                } footer: {
                    Text("Tracks overlap when one ends. Manual skips are always instant. Normalization evens out loudness between tracks.")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textTertiary)
                }

                Section {
                    VStack(alignment: .leading, spacing: AuraSpacing.xs) {
                        HStack {
                            Text("Pitch")
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(effects.semitones == 0
                                 ? "0"
                                 : String(format: "%+.0f semitones", effects.semitones))
                                .font(.auraTimestamp)
                                .foregroundStyle(effects.semitones == 0 ? Color.textTertiary : Color.accent)
                        }
                        Slider(
                            value: Binding(get: { Double(effects.semitones) },
                                           set: { effects.setSemitones(Float($0)) }),
                            in: Double(PlaybackEffects.minSemitones)...Double(PlaybackEffects.maxSemitones),
                            step: 1
                        )
                        .tint(Color.accent)
                    }
                    .listRowBackground(Color.surface)

                    VStack(alignment: .leading, spacing: AuraSpacing.xs) {
                        HStack {
                            Text("Speed")
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(String(format: "%.2f×", effects.rate))
                                .font(.auraTimestamp)
                                .foregroundStyle(effects.rate == 1 ? Color.textTertiary : Color.accent)
                        }
                        Slider(
                            value: Binding(get: { Double(effects.rate) },
                                           set: { effects.setRate(Float($0)) }),
                            in: Double(PlaybackEffects.minRate)...Double(PlaybackEffects.maxRate),
                            step: 0.05
                        )
                        .tint(Color.accent)
                    }
                    .listRowBackground(Color.surface)

                    if effects.isModified {
                        Button("Reset Pitch & Speed") { effects.reset() }
                            .foregroundStyle(Color.accent)
                            .listRowBackground(Color.surface)
                    }
                } header: {
                    Text("Pitch & Speed")
                        .font(.auraCaption)
                        .foregroundStyle(Color.textSecondary)
                } footer: {
                    Text("Pitch and speed change independently — shift key without changing tempo, or vice versa.")
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
