//
//  MetadataOverrideViewModel.swift
//  AuraPlayer
//
//  Owns user metadata edits and applies them on top of scanned tracks.
//

import Foundation
import Combine

@MainActor
final class MetadataOverrideViewModel: ObservableObject {

    static let shared = MetadataOverrideViewModel()

    @Published private(set) var overrides: [String: TrackOverride] = [:]

    private init() {
        overrides = MetadataOverrideStore.load()
    }

    private func key(for url: URL) -> String { url.lastPathComponent }

    func override(for url: URL) -> TrackOverride {
        overrides[key(for: url)] ?? TrackOverride()
    }

    func hasOverride(for url: URL) -> Bool {
        !(overrides[key(for: url)] ?? TrackOverride()).isEmpty
    }

    /// Apply edits on top of a scanned track.
    func applying(_ track: Track) -> Track {
        let edit = override(for: track.url)
        guard !edit.isEmpty else { return track }

        var result = track
        if let title = edit.title, !title.isEmpty { result.title = title }
        if let artist = edit.artist, !artist.isEmpty { result.artist = artist }
        if let album = edit.album, !album.isEmpty { result.album = album }
        if let genre = edit.genre, !genre.isEmpty { result.genre = genre }
        if let year = edit.year, !year.isEmpty { result.year = year }
        if let art = edit.artworkFilename,
           let data = MetadataOverrideStore.artworkData(named: art) {
            result.artworkData = data
        }
        return result
    }

    func applying(_ tracks: [Track]) -> [Track] {
        tracks.map { applying($0) }
    }

    // MARK: - Editing

    func save(_ edit: TrackOverride, for url: URL) {
        let k = key(for: url)
        // Clean up a replaced image so custom art doesn't accumulate.
        if let old = overrides[k]?.artworkFilename, old != edit.artworkFilename {
            MetadataOverrideStore.deleteArtwork(named: old)
        }
        if edit.isEmpty {
            overrides.removeValue(forKey: k)
        } else {
            overrides[k] = edit
        }
        MetadataOverrideStore.save(overrides)
    }

    func setArtwork(_ data: Data, for url: URL) {
        var edit = override(for: url)
        if let old = edit.artworkFilename {
            MetadataOverrideStore.deleteArtwork(named: old)
        }
        edit.artworkFilename = MetadataOverrideStore.storeArtwork(data, for: key(for: url))
        save(edit, for: url)
    }

    func revert(url: URL) {
        let k = key(for: url)
        if let art = overrides[k]?.artworkFilename {
            MetadataOverrideStore.deleteArtwork(named: art)
        }
        overrides.removeValue(forKey: k)
        MetadataOverrideStore.save(overrides)
    }

    /// Apply the same field values to several tracks at once.
    func applyBatch(to urls: [URL],
                    artist: String?,
                    album: String?,
                    genre: String?,
                    year: String?) {
        for url in urls {
            var edit = override(for: url)
            if let artist, !artist.isEmpty { edit.artist = artist }
            if let album, !album.isEmpty { edit.album = album }
            if let genre, !genre.isEmpty { edit.genre = genre }
            if let year, !year.isEmpty { edit.year = year }
            save(edit, for: url)
        }
    }
}
