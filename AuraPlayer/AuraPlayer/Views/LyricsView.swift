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

    @EnvironmentObject var library: LibraryViewModel
    @State private var showEditor = false
    @State private var showSearch = false

    private var activeIndex: Int? {
        player.lyrics.activeIndex(at: player.currentTime)
    }

    /// The Track for whatever is playing, needed to write the sidecar file.
    private var currentTrack: Track? {
        guard let url = player.currentTrackURL else { return nil }
        return library.tracks.first { $0.url == url }
    }

    var body: some View {
        NavigationStack {
            Group {
                if player.isLoadingLyrics {
                    ProgressView().tint(Color.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if player.lyrics.isEmpty {
                    emptyState
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
                ToolbarItem(placement: .topBarTrailing) {
                    if currentTrack != nil { actionsMenu }
                }
            }
            .sheet(isPresented: $showEditor) {
                if let track = currentTrack {
                    LyricsEditorView(track: track)
                        .environmentObject(player)
                }
            }
            .sheet(isPresented: $showSearch) {
                if let track = currentTrack {
                    LyricsSearchView(track: track)
                        .environmentObject(player)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var actionsMenu: some View {
        Menu {
            Button {
                showSearch = true
            } label: {
                Label("Search Online", systemImage: "magnifyingglass")
            }

            Button {
                showEditor = true
            } label: {
                Label("Edit Lyrics", systemImage: "pencil")
            }

            if !player.lyrics.isEmpty {
                Divider()

                Button(role: .destructive) {
                    removeLyrics()
                } label: {
                    Label("Remove Lyrics", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(Color.accent)
        }
        .accessibilityLabel("Lyrics options")
    }

    private var emptyState: some View {
        VStack(spacing: AuraSpacing.lg) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 44))
                .foregroundStyle(Color.textTertiary)

            VStack(spacing: AuraSpacing.sm) {
                Text("No Lyrics")
                    .font(.auraTitle)
                    .foregroundStyle(Color.textPrimary)
                Text("Nothing matched this track's tags. Search the online database, or write them yourself.")
                    .font(.auraBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AuraSpacing.xl)
            }

            if currentTrack != nil {
                VStack(spacing: AuraSpacing.sm) {
                    AuraButton("Search Online", systemImage: "magnifyingglass", variant: .primary) {
                        showSearch = true
                    }
                    AuraButton("Write Lyrics", systemImage: "pencil", variant: .secondary) {
                        showEditor = true
                    }
                }
                .padding(.horizontal, AuraSpacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Clear the sidecar, the network cache and the "nothing found" flag so
    /// the next lookup — or a manual search — starts from scratch.
    private func removeLyrics() {
        guard let track = currentTrack else { return }
        LyricsProvider.forget(track: track)
        player.reloadLyrics()
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
