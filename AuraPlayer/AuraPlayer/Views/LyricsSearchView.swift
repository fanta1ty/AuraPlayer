//
//  LyricsSearchView.swift
//  AuraPlayer
//
//  Find lyrics online when the automatic match misses — usually because a
//  file's tags are wrong, abbreviated, or in a different script.
//
//  Fields start from the track's own tags so the common case is one tap.
//  Results are ordered by how closely their length matches the track, which
//  is the strongest signal that it's the same recording rather than a live
//  cut or a radio edit.
//
//  Picking a result writes a sidecar .lrc next to the audio file.
//

import SwiftUI

struct LyricsSearchView: View {
    let track: Track

    @EnvironmentObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var artist: String
    @State private var results: [LyricsSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var preview: LyricsSearchResult?

    init(track: Track) {
        self.track = track
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
    }

    private var canSearch: Bool {
        !(title + artist).trimmingCharacters(in: .whitespaces).isEmpty && !isSearching
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                queryFields
                Divider().overlay(Color.surfaceElevated)
                resultsArea
            }
            .background(Color.background)
            .navigationTitle("Find Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .sheet(item: $preview) { result in
                LyricsPreviewView(result: result, track: track) {
                    player.reloadLyrics()
                    dismiss()
                }
            }
            // Kick off a search with the track's own tags right away.
            .task { await runSearch() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Query

    private var queryFields: some View {
        VStack(spacing: AuraSpacing.sm) {
            field("Title", text: $title)
            field("Artist", text: $artist)

            AuraButton("Search", systemImage: "magnifyingglass", variant: .primary) {
                Task { await runSearch() }
            }
            .disabled(!canSearch)
            .opacity(canSearch ? 1 : 0.5)
        }
        .padding(AuraSpacing.md)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .textFieldStyle(.plain)
            .font(.auraBody)
            .foregroundStyle(Color.textPrimary)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .onSubmit { Task { await runSearch() } }
            .padding(AuraSpacing.md)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsArea: some View {
        if isSearching {
            VStack(spacing: AuraSpacing.md) {
                ProgressView().tint(Color.accent)
                Text("Searching LRCLIB…")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            ContentUnavailableView(
                hasSearched ? "No Matches" : "Search for Lyrics",
                systemImage: hasSearched ? "questionmark.text.page" : "text.magnifyingglass",
                description: Text(hasSearched
                    ? "Try just the song title, or drop the artist if it's spelled differently online."
                    : "Results come from LRCLIB, a free community lyrics database.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(results) { result in
                Button {
                    preview = result
                } label: {
                    row(for: result)
                }
                .listRowBackground(Color.background)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func row(for result: LyricsSearchResult) -> some View {
        let delta = result.durationDelta(from: track.duration)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: AuraSpacing.sm) {
                Text(result.trackName)
                    .font(.auraBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                if result.isSynced {
                    Text("SYNCED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            Text(result.albumName.isEmpty
                 ? result.artistName
                 : "\(result.artistName) · \(result.albumName)")
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                // A close length match is the best evidence it's the same cut.
                Image(systemName: delta <= 2 ? "checkmark.circle.fill" : "clock")
                    .font(.system(size: 10))
                Text(durationNote(delta: delta, of: result))
            }
            .font(.auraCaption)
            .foregroundStyle(delta <= 2 ? Color.accent : Color.textTertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func durationNote(delta: TimeInterval, of result: LyricsSearchResult) -> String {
        let length = NowPlayingView.time(result.duration)
        guard delta.isFinite else { return length }
        if delta <= 2 { return "\(length) · length matches" }
        return "\(length) · \(Int(delta))s off"
    }

    // MARK: - Actions

    private func runSearch() async {
        let query = (title, artist)
        guard !(query.0 + query.1).trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        var found = await LyricsProvider.search(title: query.0, artist: query.1)

        // Fall back to a loose title-only search when the field query is
        // too strict — a very common outcome with non-Latin artist names.
        if found.isEmpty, !query.1.isEmpty, !query.0.isEmpty {
            found = await LyricsProvider.search(title: query.0)
        }

        // Closest length first, then prefer synced over plain.
        results = found.sorted {
            let a = $0.durationDelta(from: track.duration)
            let b = $1.durationDelta(from: track.duration)
            if abs(a - b) > 1 { return a < b }
            return $0.isSynced && !$1.isSynced
        }

        hasSearched = true
        isSearching = false
    }
}

// MARK: - Preview & apply

private struct LyricsPreviewView: View {
    let result: LyricsSearchResult
    let track: Track
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showError = false

    private var parsed: Lyrics {
        LyricsParser.parse(result.content ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.md) {
                    ForEach(parsed.lines) { line in
                        HStack(alignment: .top, spacing: AuraSpacing.md) {
                            if let time = line.time {
                                Text(NowPlayingView.time(time))
                                    .font(.auraTimestamp)
                                    .foregroundStyle(Color.textTertiary)
                                    .frame(width: 46, alignment: .leading)
                            }
                            Text(line.text)
                                .font(.auraBody)
                                .foregroundStyle(Color.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(AuraSpacing.lg)
            }
            .background(Color.background)
            .navigationTitle(result.isSynced ? "Preview · Synced" : "Preview")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                AuraButton("Use These Lyrics", systemImage: "checkmark", variant: .primary) {
                    apply()
                }
                .padding(AuraSpacing.md)
                .background(Color.surface)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .alert("Couldn't Save", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The lyrics file couldn't be written next to the audio file.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func apply() {
        guard let content = result.content,
              LyricsProvider.apply(content, to: track)
        else {
            showError = true
            return
        }
        onApply()
        dismiss()
    }
}
