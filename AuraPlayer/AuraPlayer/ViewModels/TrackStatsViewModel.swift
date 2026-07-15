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
        stats[url.lastPathComponent] = e
        persist()
    }

    private func persist() { TrackStatsStore.save(stats) }
}
