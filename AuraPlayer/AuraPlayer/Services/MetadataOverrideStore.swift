//
//  MetadataOverrideStore.swift
//  AuraPlayer
//
//  Persists user metadata edits as JSON, plus any replacement artwork.
//

import Foundation

enum MetadataOverrideStore {

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("metadata-overrides.json")
    }

    /// Replacement cover images live alongside the JSON.
    static var artworkDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("CustomArtwork", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Load / save

    static func load() -> [String: TrackOverride] {
        JSONFileStore.load([String: TrackOverride].self, from: fileURL) ?? [:]
    }

    /// Returns false if the write failed (logged by JSONFileStore).
    @discardableResult
    static func save(_ overrides: [String: TrackOverride]) -> Bool {
        JSONFileStore.save(overrides, to: fileURL)
    }

    // MARK: - Artwork

    /// Writes new cover art and returns the stored filename.
    static func storeArtwork(_ data: Data, for key: String) -> String {
        let filename = "\(key)-\(UUID().uuidString.prefix(6)).jpg"
        let url = artworkDirectory.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return filename
    }

    static func artworkData(named filename: String) -> Data? {
        try? Data(contentsOf: artworkDirectory.appendingPathComponent(filename))
    }

    static func deleteArtwork(named filename: String) {
        try? FileManager.default.removeItem(at: artworkDirectory.appendingPathComponent(filename))
    }
}
