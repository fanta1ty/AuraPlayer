//
//  TrackInfoView.swift
//  AuraPlayer
//
//  Read-only detail sheet: tags, audio format, listening stats and file info.
//

import SwiftUI

struct TrackInfoView: View {
    let track: Track

    @EnvironmentObject var stats: TrackStatsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var info: AudioFileInfo?
    @State private var replayGain: Float?

    var body: some View {
        NavigationStack {
            List {
                header

                Section {
                    row("Title", track.title)
                    row("Artist", track.artist)
                    row("Album", track.album)
                    if let genre = track.genre, !genre.isEmpty { row("Genre", genre) }
                    if let year = track.year, !year.isEmpty { row("Year", year) }
                    row("Duration", TrackRow.durationString(track.duration))
                } header: {
                    sectionTitle("Tags")
                }

                Section {
                    if let info {
                        row("Format", info.format)
                        if info.isLossless {
                            row("Quality", "Lossless", highlighted: true)
                        }
                        row("Sample Rate", info.sampleRateText)
                        if let depth = info.bitDepthText { row("Bit Depth", depth) }
                        row("Channels", info.channelsText)
                        if let bitrate = info.bitrateText { row("Bitrate", bitrate) }
                    } else {
                        HStack {
                            Spacer()
                            ProgressView().tint(Color.accent)
                            Spacer()
                        }
                        .listRowBackground(Color.surface)
                    }
                } header: {
                    sectionTitle("Audio")
                }

                Section {
                    row("Plays", "\(stats.playCount(for: track.url))")
                    HStack {
                        Text("Rating")
                            .font(.auraBody)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        StarRatingView(rating: stats.rating(for: track.url), size: 12)
                    }
                    .listRowBackground(Color.surface)

                    if let replayGain {
                        row("Volume Adjustment", String(format: "%+.1f dB", replayGain))
                    }
                } header: {
                    sectionTitle("Listening")
                }

                Section {
                    row("File", track.url.lastPathComponent)
                    if let info { row("Size", info.fileSizeText) }
                    row("Added", track.dateAdded.formatted(date: .abbreviated, time: .shortened))
                } header: {
                    sectionTitle("File")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accent)
                }
            }
            .task { await load() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: AuraSpacing.sm) {
                Group {
                    if let data = track.artworkData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Color.surfaceElevated
                            .overlay(Image(systemName: "music.note").font(.system(size: 32))
                                .foregroundStyle(Color.accent))
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
                .cardShadow()

                if let info {
                    Text(info.summary)
                        .font(.auraCaption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, AuraSpacing.sm)
        .listRowBackground(Color.background)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.auraCaption)
            .foregroundStyle(Color.textSecondary)
    }

    private func row(_ label: String, _ value: String, highlighted: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.auraBody)
                .foregroundStyle(Color.textSecondary)
            Spacer(minLength: AuraSpacing.md)
            Text(value)
                .font(.auraBody)
                .foregroundStyle(highlighted ? Color.accent : Color.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .listRowBackground(Color.surface)
    }

    // MARK: - Loading

    private func load() async {
        info = await AudioFileInfo.load(for: track.url)
        // Only show a gain figure if this track has already been analysed.
        replayGain = await LoudnessAnalyzer.gain(for: track.url)
    }
}
