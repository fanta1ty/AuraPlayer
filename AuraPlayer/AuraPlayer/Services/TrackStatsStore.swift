//
//  TrackStatsStore.swift
//  AuraPlayer
//
//  Created by mobile on 16/7/26.
//
//  JSON persistence for per-track ratings and play counts, keyed by filename.
//

import Foundation

enum TrackStatsStore {
    private static var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("trackstats.json")
    }

    static func load() -> [String: TrackStats] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: TrackStats].self, from: data)) ?? [:]
    }

    static func save(_ stats: [String: TrackStats]) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
