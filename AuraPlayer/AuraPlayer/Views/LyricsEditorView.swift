//
//  LyricsEditorView.swift
//  AuraPlayer
//
//  Two-step lyrics authoring:
//   1. Paste or type the plain words, one line each
//   2. Play the track and tap "Set" as each line arrives to stamp its time
//
//  The result is written as a sidecar .lrc next to the audio file, which is
//  the first place LyricsProvider looks.
//

import SwiftUI

struct LyricsEditorView: View {
    let track: Track

    @EnvironmentObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Step { case text, sync }

    @State private var step: Step = .text
    @State private var rawText = ""
    @State private var lines: [EditableLine] = []
    @State private var currentIndex = 0

    private struct EditableLine: Identifiable {
        let id = UUID()
        var text: String
        var time: TimeInterval?
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .text: textStep
                case .sync: syncStep
                }
            }
            .background(Color.background)
            .navigationTitle(step == .text ? "Lyrics Text" : "Set Timings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    switch step {
                    case .text:
                        Button("Next") { beginSync() }
                            .foregroundStyle(hasText ? Color.accent : Color.textDisabled)
                            .disabled(!hasText)
                    case .sync:
                        Button("Save") { save() }.foregroundStyle(Color.accent)
                    }
                }
            }
            .task { loadExisting() }
        }
        .preferredColorScheme(.dark)
    }

    private var hasText: Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Step 1: the words

    private var textStep: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.sm) {
            Text("One line per lyric line. Existing lyrics are loaded if we have them.")
                .font(.auraCaption)
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, AuraSpacing.md)

            TextEditor(text: $rawText)
                .font(.auraBody)
                .foregroundStyle(Color.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
                .padding(.horizontal, AuraSpacing.md)
        }
        .padding(.vertical, AuraSpacing.md)
    }

    // MARK: - Step 2: the timings

    private var syncStep: some View {
        VStack(spacing: 0) {
            transportBar

            ScrollViewReader { proxy in
                List {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        HStack(spacing: AuraSpacing.md) {
                            Text(line.time.map(Self.stamp) ?? "--:--.--")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(line.time == nil ? Color.textDisabled : Color.accent)
                                .frame(width: 72, alignment: .leading)

                            Text(line.text)
                                .font(.auraBody)
                                .foregroundStyle(index == currentIndex ? Color.textPrimary : Color.textSecondary)
                                .lineLimit(2)
                        }
                        .listRowBackground(index == currentIndex ? Color.surfaceElevated : Color.background)
                        .id(index)
                        .contentShape(Rectangle())
                        .onTapGesture { currentIndex = index }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onChange(of: currentIndex) { _, new in
                    withAnimation { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
    }

    private var transportBar: some View {
        VStack(spacing: AuraSpacing.md) {
            HStack {
                Text(NowPlayingView.time(player.currentTime))
                    .font(.auraTimestamp)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("\(taggedCount)/\(lines.count) tagged")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textTertiary)
            }

            HStack(spacing: AuraSpacing.md) {
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.auraHeadline)
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                AuraButton("Set Time", systemImage: "target", variant: .primary) {
                    stampCurrentLine()
                }

                Button {
                    clearCurrentLine()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.auraHeadline)
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(Color.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(AuraSpacing.md)
        .background(Color.surface)
    }

    private var taggedCount: Int {
        lines.filter { $0.time != nil }.count
    }

    // MARK: - Actions

    private func loadExisting() {
        guard rawText.isEmpty else { return }
        rawText = player.lyrics.isEmpty ? "" : player.lyrics.plainText
    }

    private func beginSync() {
        lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { EditableLine(text: $0, time: nil) }
        currentIndex = 0
        step = .sync
    }

    /// Stamp the playhead onto the current line and advance.
    private func stampCurrentLine() {
        guard lines.indices.contains(currentIndex) else { return }
        lines[currentIndex].time = player.currentTime
        if currentIndex < lines.count - 1 { currentIndex += 1 }
    }

    private func clearCurrentLine() {
        guard lines.indices.contains(currentIndex) else { return }
        lines[currentIndex].time = nil
    }

    private func save() {
        let content = lines.map { line -> String in
            guard let time = line.time else { return line.text }
            return "[\(Self.stamp(time))]\(line.text)"
        }.joined(separator: "\n")

        let sidecar = track.url.deletingPathExtension().appendingPathExtension("lrc")
        try? content.write(to: sidecar, atomically: true, encoding: .utf8)

        player.reloadLyrics()
        dismiss()
    }

    /// "01:23.45"
    private static func stamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let hundredths = Int((time - floor(time)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}
