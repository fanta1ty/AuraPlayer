//
//  LyricsView.swift
//  AuraPlayer
//
//  Synced lyrics that follow playback and scroll themselves.
//  Tap any line to seek to it.
//

import SwiftUI

struct LyricsView: View {
    @EnvironmentObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    private var activeIndex: Int? {
        player.lyrics.activeIndex(at: player.currentTime)
    }

    var body: some View {
        NavigationStack {
            Group {
                if player.isLoadingLyrics {
                    ProgressView().tint(Color.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if player.lyrics.isEmpty {
                    ContentUnavailableView(
                        "No Lyrics",
                        systemImage: "quote.bubble",
                        description: Text("No lyrics found for this track. Drop a matching .lrc file next to the audio file to add your own.")
                    )
                } else {
                    lyricsList
                }
            }
            .background(Color.background)
            .navigationTitle(player.lyrics.isSynced ? "Lyrics · Synced" : "Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var lyricsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AuraSpacing.md) {
                    ForEach(player.lyrics.lines) { line in
                        let isActive = line.id == activeIndex

                        Text(line.text)
                            .font(isActive ? .auraTitle : .auraBody)
                            .foregroundStyle(lineColor(isActive: isActive, hasTime: line.time != nil))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { seek(to: line) }
                            .id(line.id)
                            .animation(.easeOut(duration: 0.2), value: isActive)
                    }
                }
                .padding(.horizontal, AuraSpacing.xl)
                .padding(.vertical, AuraSpacing.xxl)
            }
            .onChange(of: activeIndex) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func lineColor(isActive: Bool, hasTime: Bool) -> Color {
        if isActive { return .accent }
        return hasTime ? .textSecondary : .textPrimary
    }

    private func seek(to line: LyricLine) {
        guard let time = line.time, player.duration > 0 else { return }
        player.seek(toProgress: time / player.duration)
    }
}
