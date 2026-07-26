//
//  MetadataEnhancer.swift
//  AuraPlayer
//
//  Fills gaps left by the file's own tags. Title/artist fallbacks already
//  happen in LibraryScanner; this adds cover art via cache or network.
//

import Foundation

enum MetadataEnhancer {

    /// How many artwork lookups may be in flight at once. Enough to hide
    /// latency, few enough to stay polite to the API.
    private static let maxConcurrentFetches = 4

    /// Returns the tracks with artwork filled in where it was missing.
    static func enhance(_ tracks: [Track]) async -> [Track] {
        var result = tracks

        // Cache hits are cheap — resolve them synchronously first.
        var needsFetch: [Int] = []
        for index in result.indices where result[index].artworkData == nil {
            let key = result[index].url.lastPathComponent
            if let cached = ArtworkCache.data(for: key) {
                result[index].artworkData = cached
            } else if !ArtworkCache.isKnownMiss(key) {
                needsFetch.append(index)
            }
        }

        guard !needsFetch.isEmpty else { return result }

        // Fetch the remainder in parallel instead of one request at a time.
        let fetched = await withTaskGroup(of: (Int, Data?).self) { group -> [Int: Data] in
            var running = 0
            var iterator = needsFetch.makeIterator()
            var results: [Int: Data] = [:]

            func addTask(_ index: Int) {
                let title = result[index].title
                let artist = result[index].artist
                group.addTask {
                    (index, await ArtworkFetcher.fetchArtwork(title: title, artist: artist))
                }
            }

            while running < maxConcurrentFetches, let next = iterator.next() {
                addTask(next)
                running += 1
            }

            while let (index, data) = await group.next() {
                if Task.isCancelled { group.cancelAll(); break }

                let key = result[index].url.lastPathComponent
                if let data {
                    ArtworkCache.store(data, for: key)
                    results[index] = data
                } else {
                    ArtworkCache.markMiss(key)
                }

                if let next = iterator.next() { addTask(next) }
            }
            return results
        }

        for (index, data) in fetched {
            result[index].artworkData = data
        }
        return result
    }
}
