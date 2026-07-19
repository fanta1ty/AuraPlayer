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
}
