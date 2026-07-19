//
//  ArtworkCache.swift
//  AuraPlayer
//
//  On-disk cache for fetched cover art, keyed by filename. Also remembers
//  lookups that returned nothing so we don't hit the network repeatedly.
//

import Foundation

enum ArtworkCache {

    private static var directory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("Artwork", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func fileURL(for key: String) -> URL {
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent(safe + ".jpg")
    }

    static func data(for key: String) -> Data? {
        try? Data(contentsOf: fileURL(for: key))
    }

    static func store(_ data: Data, for key: String) {
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    // MARK: - Misses

    private static let missKey = "artwork.misses"

    static func isKnownMiss(_ key: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: missKey) ?? []).contains(key)
    }

    static func markMiss(_ key: String) {
        var misses = UserDefaults.standard.stringArray(forKey: missKey) ?? []
        guard !misses.contains(key) else { return }
        misses.append(key)
        UserDefaults.standard.set(misses, forKey: missKey)
    }
}
