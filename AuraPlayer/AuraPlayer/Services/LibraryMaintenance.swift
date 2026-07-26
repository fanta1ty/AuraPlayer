//
//  LibraryMaintenance.swift
//  AuraPlayer
//
//  Housekeeping: find duplicate imports, playlist entries whose files are
//  gone, and file loose tracks into Artist/Album folders.
//

import Foundation

enum LibraryMaintenance {

    // MARK: - Duplicates

    struct DuplicateGroup: Identifiable {
        let id = UUID()
        let title: String
        let artist: String
        /// Same recording, imported more than once. Newest last.
        let tracks: [Track]

        /// Everything except the copy we'd keep (the oldest).
        var redundant: [Track] { Array(tracks.dropFirst()) }
        var reclaimable: Int64 {
            redundant.reduce(0) { total, track in
                let size = (try? track.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return total + Int64(size)
            }
        }
    }

    /// Group tracks that look like the same recording.
    ///
    /// Matching on title + artist + rounded duration catches the common case
    /// (the same song imported twice under different filenames) without
    /// flagging genuinely different versions like a live take.
    static func duplicates(in tracks: [Track]) -> [DuplicateGroup] {
        Dictionary(grouping: tracks) { track in
            let title = track.title.lowercased().trimmingCharacters(in: .whitespaces)
            let artist = track.artist.lowercased().trimmingCharacters(in: .whitespaces)
            let seconds = Int(track.duration.rounded())
            return "\(title)|\(artist)|\(seconds)"
        }
        .filter { $0.value.count > 1 }
        .map { _, group in
            let ordered = group.sorted { $0.dateAdded < $1.dateAdded }
            return DuplicateGroup(title: ordered[0].title,
                                  artist: ordered[0].artist,
                                  tracks: ordered)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Broken playlist entries

    struct BrokenEntry: Identifiable {
        let id = UUID()
        let playlistName: String
        let playlistID: UUID
        let filename: String
    }

    /// Playlist entries whose file no longer exists.
    static func brokenEntries(playlists: [Playlist], tracks: [Track]) -> [BrokenEntry] {
        let known = Set(tracks.map(\.url.lastPathComponent))
        return playlists.flatMap { playlist in
            playlist.trackFilenames
                .filter { !known.contains($0) }
                .map { BrokenEntry(playlistName: playlist.name,
                                   playlistID: playlist.id,
                                   filename: $0) }
        }
    }

    // MARK: - Organise

    struct OrganiseResult {
        var moved: Int
        var skipped: Int
    }

    /// Move files into Music/Artist/Album/ based on their tags.
    /// Tracks already in the right place are left alone.
    static func organise(_ tracks: [Track]) -> OrganiseResult {
        let fm = FileManager.default
        var moved = 0
        var skipped = 0

        for track in tracks {
            let artist = sanitise(track.effectiveAlbumArtist)
            let album = sanitise(track.album)

            let folder = AudioImporter.musicDirectory
                .appendingPathComponent(artist, isDirectory: true)
                .appendingPathComponent(album, isDirectory: true)

            let destination = folder.appendingPathComponent(track.url.lastPathComponent)

            // Already filed correctly.
            if destination.standardizedFileURL == track.url.standardizedFileURL {
                skipped += 1
                continue
            }
            // Don't overwrite something already there.
            guard !fm.fileExists(atPath: destination.path) else {
                skipped += 1
                continue
            }

            do {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                try fm.moveItem(at: track.url, to: destination)
                moved += 1
            } catch {
                skipped += 1
            }
        }
        return OrganiseResult(moved: moved, skipped: skipped)
    }

    /// Strip characters that don't belong in a folder name.
    private static func sanitise(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Unknown" : cleaned
    }
}
