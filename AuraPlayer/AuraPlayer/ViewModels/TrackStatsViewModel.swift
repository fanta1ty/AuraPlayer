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

    // MARK: - Resume position
    //
    // Only worth remembering for long files — nobody wants a 3-minute song to
    // resume 40 seconds in, but a 90-minute mix absolutely should.

    static let resumeMinimumDuration: TimeInterval = 20 * 60   // 20 minutes
    /// Ignore positions near the very start or end.
    private static let resumeEdgeMargin: TimeInterval = 30

    func resumePosition(for url: URL) -> TimeInterval? {
        entry(for: url).resumePosition
    }

    /// Store where playback stopped, if this file is long enough to warrant it.
    func setResumePosition(_ time: TimeInterval, duration: TimeInterval, for url: URL) {
        guard duration >= Self.resumeMinimumDuration else { return }

        var e = entry(for: url)
        let isNearEdge = time < Self.resumeEdgeMargin
            || time > duration - Self.resumeEdgeMargin
        e.resumePosition = isNearEdge ? nil : time
        stats[url.lastPathComponent] = e
        persist()
    }

    func clearResumePosition(for url: URL) {
        var e = entry(for: url)
        guard e.resumePosition != nil else { return }
        e.resumePosition = nil
        stats[url.lastPathComponent] = e
        persist()
    }

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
