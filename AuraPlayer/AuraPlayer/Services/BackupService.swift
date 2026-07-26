//
//  BackupService.swift
//  AuraPlayer
//
//  Exports everything the app knows that isn't in the audio files themselves:
//  ratings, play counts, playlists, smart playlists, metadata edits and EQ
//  presets. Audio is excluded — a library backup would be gigabytes.
//
//  Tracks are referenced by filename, so a restore reattaches to the same
//  files after a reinstall.
//

import Foundation

struct LibraryBackup: Codable {
    var version: Int = 1
    var createdAt: Date = .now

    var stats: [String: TrackStats]
    var playlists: [Playlist]
    var smartPlaylists: [SmartPlaylist]
    var overrides: [String: TrackOverride]
    var eqPresets: [EQPreset]

    var summary: String {
        "\(stats.count) tracks · \(playlists.count) playlists · \(eqPresets.count) EQ presets"
    }
}

enum BackupService {

    static let filename = "AuraPlayer-Backup.json"

    /// Gather current state into a file in the temporary directory, ready to share.
    @MainActor
    static func export() -> URL? {
        let backup = LibraryBackup(
            stats: TrackStatsStore.load(),
            playlists: PlaylistStore.load(),
            smartPlaylists: SmartPlaylistViewModel.shared.playlists,
            overrides: MetadataOverrideStore.load(),
            eqPresets: EQPresetStore.load()
        )

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard JSONFileStore.save(backup, to: url) else { return nil }
        return url
    }

    @MainActor
    static func read(from url: URL) -> LibraryBackup? {
        // Files chosen from the document picker may sit outside our sandbox.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return JSONFileStore.load(LibraryBackup.self, from: url)
    }

    /// Overwrite current state with a backup. Existing data is replaced, not merged.
    @MainActor
    static func restore(_ backup: LibraryBackup) {
        TrackStatsStore.save(backup.stats)
        PlaylistStore.save(backup.playlists)
        MetadataOverrideStore.save(backup.overrides)
        EQPresetStore.save(backup.eqPresets)
        JSONFileStore.save(backup.smartPlaylists,
                           to: JSONFileStore.documentsURL("smart-playlists.json"))
    }
}
