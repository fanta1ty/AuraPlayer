//
//  M3UService.swift
//  AuraPlayer
//
//  Reads and writes .m3u / .m3u8 playlists — the format every other player
//  understands, so playlists can move in and out of the app.
//
//  Entries are matched by filename rather than path: an .m3u written on a
//  desktop will reference directories that don't exist on the device.
//

import Foundation

enum M3UService {

    // MARK: - Export

    /// Extended M3U with #EXTINF duration/title lines.
    static func export(name: String, tracks: [Track]) -> URL? {
        var lines = ["#EXTM3U"]
        for track in tracks {
            lines.append("#EXTINF:\(Int(track.duration)),\(track.artist) - \(track.title)")
            lines.append(track.url.lastPathComponent)
        }

        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName).m3u8")

        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Import

    struct ImportResult {
        var name: String
        var matched: [Track]
        var missing: [String]
    }

    /// Parse a playlist file and resolve its entries against the library.
    static func importPlaylist(from url: URL, library: [Track]) -> ImportResult? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let raw = try? String(contentsOf: url, encoding: .utf8)
                ?? String(contentsOf: url, encoding: .isoLatin1) else { return nil }

        // Match on filename, case-insensitively.
        var byName: [String: Track] = [:]
        for track in library {
            byName[track.url.lastPathComponent.lowercased()] = track
        }

        var matched: [Track] = []
        var missing: [String] = []

        for line in raw.components(separatedBy: .newlines) {
            let entry = line.trimmingCharacters(in: .whitespaces)
            guard !entry.isEmpty, !entry.hasPrefix("#") else { continue }

            // Entries may be absolute paths, relative paths, or bare filenames.
            let filename = (entry as NSString).lastPathComponent
                .removingPercentEncoding ?? (entry as NSString).lastPathComponent

            if let track = byName[filename.lowercased()] {
                matched.append(track)
            } else {
                missing.append(filename)
            }
        }

        guard !matched.isEmpty || !missing.isEmpty else { return nil }

        return ImportResult(
            name: url.deletingPathExtension().lastPathComponent,
            matched: matched,
            missing: missing
        )
    }
}
