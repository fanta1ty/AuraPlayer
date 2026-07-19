//
//  MetadataEnhancer.swift
//  AuraPlayer
//
//  Fills gaps left by the file's own tags. Title/artist fallbacks already
//  happen in LibraryScanner; this adds cover art via cache or network.
//

import Foundation

enum MetadataEnhancer {

    /// Returns the tracks with artwork filled in where it was missing.
    static func enhance(_ tracks: [Track]) async -> [Track] {
        var result = tracks

        for index in result.indices where result[index].artworkData == nil {
            if Task.isCancelled { break }

            let key = result[index].url.lastPathComponent

            if let cached = ArtworkCache.data(for: key) {
                result[index].artworkData = cached
                continue
            }

            // Don't re-query for tracks we already failed to match.
            guard !ArtworkCache.isKnownMiss(key) else { continue }

            if let fetched = await ArtworkFetcher.fetchArtwork(
                title: result[index].title,
                artist: result[index].artist
            ) {
                ArtworkCache.store(fetched, for: key)
                result[index].artworkData = fetched
            } else {
                ArtworkCache.markMiss(key)
            }
        }

        return result
    }
}
