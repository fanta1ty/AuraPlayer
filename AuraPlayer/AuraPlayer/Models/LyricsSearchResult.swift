//
//  LyricsSearchResult.swift
//  AuraPlayer
//
//  One candidate returned by an online lyrics search.
//

import Foundation

struct LyricsSearchResult: Identifiable, Hashable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String
    /// Track length the lyrics were timed against — the best signal that
    /// this is the same recording and not a live/remix version.
    let duration: TimeInterval
    let isInstrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?

    var isSynced: Bool { !(syncedLyrics ?? "").isEmpty }

    /// Synced when we have it, plain otherwise. nil means nothing usable.
    var content: String? {
        if let synced = syncedLyrics, !synced.isEmpty { return synced }
        if let plain = plainLyrics, !plain.isEmpty { return plain }
        return nil
    }

    /// A short preview for the results list.
    var snippet: String {
        (plainLyrics ?? LyricsParser.parse(syncedLyrics ?? "").plainText)
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
    }

    /// How far this candidate's length is from the track we're matching.
    func durationDelta(from trackDuration: TimeInterval) -> TimeInterval {
        guard duration > 0, trackDuration > 0 else { return .infinity }
        return abs(duration - trackDuration)
    }
}
