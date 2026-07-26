//
//  TrackStatsViewModel.swift
//  AuraPlayer
//
//  Created by mobile on 16/7/26.
//

import Foundation
import Combine

@MainActor
final class TrackStatsViewModel: ObservableObject {
    @Published private(set) var stats: [String: TrackStats] = [:]

    init() {
        stats = TrackStatsStore.load()
    }

    func entry(for url: URL) -> TrackStats {
        stats[url.lastPathComponent] ?? TrackStats()
    }

    func rating(for url: URL) -> Int { entry(for: url).rating }
    func playCount(for url: URL) -> Int { entry(for: url).playCount }

    func setRating(_ rating: Int, for url: URL) {
        var e = entry(for: url)
        e.rating = max(0, min(5, rating))
        stats[url.lastPathComponent] = e
        persist()
    }

    func incrementPlayCount(for url: URL) {
        var e = entry(for: url)
        e.playCount += 1
        e.lastPlayed = .now
        stats[url.lastPathComponent] = e
        persist()
    }

    func lastPlayed(for url: URL) -> Date? { entry(for: url).lastPlayed }

    /// Tracks played at least once, newest first.
    func recentlyPlayed(from tracks: [Track], limit: Int = 50) -> [Track] {
        tracks
            .compactMap { track -> (Track, Date)? in
                guard let date = lastPlayed(for: track.url) else { return nil }
                return (track, date)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    /// Tracks ordered by how often they've been played.
    func mostPlayed(from tracks: [Track], limit: Int = 50) -> [Track] {
        tracks
            .filter { playCount(for: $0.url) > 0 }
            .sorted { playCount(for: $0.url) > playCount(for: $1.url) }
            .prefix(limit)
            .map { $0 }
    }

    private func persist() { TrackStatsStore.save(stats) }
}
