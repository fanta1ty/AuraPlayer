//
//  LyricsProvider.swift
//  AuraPlayer
//
//  Finds lyrics for a track, in order of preference:
//    1. A sidecar .lrc file next to the audio (synced)
//    2. Lyrics embedded in the file's metadata (usually plain)
//    3. LRCLIB, a free community lyrics API (synced when available)
//
//  Network results are cached on disk so we only fetch once per track.
//

import Foundation
import AVFoundation

enum LyricsProvider {

    // MARK: - Cache

    private static var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("Lyrics", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func cacheURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_") + ".lrc")
    }

    private static let missKey = "lyrics.misses"

    private static func isKnownMiss(_ key: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: missKey) ?? []).contains(key)
    }

    private static func markMiss(_ key: String) {
        var misses = UserDefaults.standard.stringArray(forKey: missKey) ?? []
        guard !misses.contains(key) else { return }
        misses.append(key)
        UserDefaults.standard.set(misses, forKey: missKey)
    }

    private static func clearMiss(_ key: String) {
        let misses = UserDefaults.standard.stringArray(forKey: missKey) ?? []
        guard misses.contains(key) else { return }
        UserDefaults.standard.set(misses.filter { $0 != key }, forKey: missKey)
    }

    // MARK: - Lookup

    static func lyrics(for track: Track) async -> Lyrics {
        let key = track.url.lastPathComponent

        // 1. Sidecar .lrc beside the audio file
        let sidecar = track.url.deletingPathExtension().appendingPathExtension("lrc")
        if let text = try? String(contentsOf: sidecar, encoding: .utf8) {
            return LyricsParser.parse(text)
        }

        // 2. Cached network result
        if let cached = try? String(contentsOf: cacheURL(for: key), encoding: .utf8) {
            return LyricsParser.parse(cached)
        }

        // 3. Embedded metadata
        if let embedded = await embeddedLyrics(for: track.url), !embedded.isEmpty {
            return LyricsParser.parse(embedded)
        }

        // 4. LRCLIB
        guard !isKnownMiss(key) else { return Lyrics(lines: []) }

        if let fetched = await fetchFromLRCLIB(track: track), !fetched.isEmpty {
            try? fetched.write(to: cacheURL(for: key), atomically: true, encoding: .utf8)
            return LyricsParser.parse(fetched)
        }

        markMiss(key)
        return Lyrics(lines: [])
    }

    /// Lyrics stored in the file's own tags (ID3 USLT and friends).
    private static func embeddedLyrics(for url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.metadata) else { return nil }

        for item in items {
            let isLyricsKey = item.commonKey?.rawValue == "lyrics"
                || (item.key as? String)?.uppercased() == "USLT"
                || item.identifier == .id3MetadataUnsynchronizedLyric

            if isLyricsKey, let value = try? await item.load(.stringValue), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    // MARK: - LRCLIB

    private struct LRCLIBResponse: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    private static func fetchFromLRCLIB(track: Track) async -> String? {
        guard var components = URLComponents(string: "https://lrclib.net/api/get") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "duration", value: String(Int(track.duration)))
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("AuraPlayer (iOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(LRCLIBResponse.self, from: data)
            return decoded.syncedLyrics ?? decoded.plainLyrics    // prefer synced
        } catch {
            return nil
        }
    }

    // MARK: - Manual search

    /// LRCLIB's /api/search payload. Every field is optional because the
    /// database is community-maintained and rows are often incomplete.
    private struct LRCLIBSearchItem: Decodable {
        let id: Int
        let trackName: String?
        let artistName: String?
        let albumName: String?
        let duration: Double?
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    /// Search the LRCLIB catalogue by hand. Used when the automatic exact
    /// match fails — usually because the file's tags are wrong or missing.
    ///
    /// Passing only `title` performs a loose full-text search; adding
    /// `artist` or `album` narrows it to a field query.
    static func search(title: String, artist: String = "", album: String = "") async -> [LyricsSearchResult] {
        let title = title.trimmingCharacters(in: .whitespaces)
        let artist = artist.trimmingCharacters(in: .whitespaces)
        let album = album.trimmingCharacters(in: .whitespaces)

        guard !title.isEmpty || !artist.isEmpty,
              var components = URLComponents(string: "https://lrclib.net/api/search")
        else { return [] }

        if artist.isEmpty && album.isEmpty {
            components.queryItems = [URLQueryItem(name: "q", value: title)]
        } else {
            var items: [URLQueryItem] = []
            if !title.isEmpty { items.append(URLQueryItem(name: "track_name", value: title)) }
            if !artist.isEmpty { items.append(URLQueryItem(name: "artist_name", value: artist)) }
            if !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
            components.queryItems = items
        }

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("AuraPlayer (iOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

            return try JSONDecoder().decode([LRCLIBSearchItem].self, from: data)
                .map { item in
                    LyricsSearchResult(
                        id: item.id,
                        trackName: item.trackName ?? "Unknown",
                        artistName: item.artistName ?? "Unknown Artist",
                        albumName: item.albumName ?? "",
                        duration: item.duration ?? 0,
                        isInstrumental: item.instrumental ?? false,
                        plainLyrics: item.plainLyrics,
                        syncedLyrics: item.syncedLyrics
                    )
                }
                .filter { $0.content != nil }       // instrumentals carry no text
        } catch {
            return []
        }
    }

    // MARK: - Applying a result

    /// Write lyrics as a sidecar .lrc beside the audio file. That's the
    /// first place `lyrics(for:)` looks, so a manual pick always wins over
    /// embedded tags and anything cached from the network.
    @discardableResult
    static func apply(_ content: String, to track: Track) -> Bool {
        let sidecar = track.url.deletingPathExtension().appendingPathExtension("lrc")
        do {
            try content.write(to: sidecar, atomically: true, encoding: .utf8)
            clearMiss(track.url.lastPathComponent)
            return true
        } catch {
            return false
        }
    }

    /// Forget everything we know about a track's lyrics — the sidecar, the
    /// network cache and the "we already looked and found nothing" flag —
    /// so the next lookup starts clean.
    static func forget(track: Track) {
        let key = track.url.lastPathComponent
        try? FileManager.default.removeItem(at: track.url.deletingPathExtension().appendingPathExtension("lrc"))
        try? FileManager.default.removeItem(at: cacheURL(for: key))
        clearMiss(key)
    }
}
